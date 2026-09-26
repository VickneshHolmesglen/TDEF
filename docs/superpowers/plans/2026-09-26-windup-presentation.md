# Wind-up Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make elite/boss attacks on the Hero legible: attacker telegraph (tint, dashed reach outline, progress bar), hit/whiff confirmation, Hero damage feedback, a mute-safe low-HP vignette, and a death sequence with a ~1.5 s hold before leaving the mission.

**Architecture:** Pull-model telegraph: `MonsterManager._pass3c_visual_sync` reads `hero_windup_remaining` each frame and drives the monster's existing 2D `MonsterInstance`. Hero-side feedback is event-driven in one new `HeroFeedback` node that both mission scenes add with one line. `SceneManager` delays its `hero_died` exit. One new gameplay-inert signal `monster_hero_attack_resolved(entity_id, hit)` (deferred) feeds audio.

**Tech Stack:** Godot 4.6.2, GDScript (static typed), gdUnit4, `GEventBus` autoload, Tween-based procedural polish, one small canvas_item shader.

**Spec:** `docs/superpowers/specs/2026-09-26-windup-presentation-design.md` (read it; the plan argues from it). Parent: `docs/superpowers/specs/2026-09-25-hero-damage-design.md`.

## Global Constraints

- Presentation only. Do NOT change attack timing, targeting, damage, `hero_incoming_damage` (stays synchronous), Damage & Status, or any authored data. The only simulation-side addition is the resolve signal + a direct `MonsterInstance` call at the moment a wind-up completes.
- Typed GDScript everywhere; doc comments on public members; constants at the top of the script, not scattered literals. Comment density and naming match the surrounding files.
- ADR-0001: physics-pass emissions of presentation-only signals are `emit.call_deferred(...)`; every `GEventBus` connection made in `_ready`/`_enter_tree` is disconnected in `_exit_tree` (Rule 6, guard with `is_connected`).
- Flash safety: no looping pulse above 2 Hz; damage flashes may restart at most once per `MIN_FLASH_GAP_MSEC = 334` (<= 3 per second).
- No color-only signals: dashed outline + progress bar (telegraph); flash + particles + flinch (damage); vignette + sprite tint (low HP).
- `ReduceMotion.enabled()` (default false) turns big-hit shake off, low-HP pulse steady, telegraph pulse steady, death shockwave off.
- No `#` comment lines inside `.tscn`/`.tres` blocks (VERSION.md: silent corruption). No `Viewport.use_hdr_2d`.
- `.tres` files: create with the Write tool. New `class_name`s or `strings.csv` edits need `Godot.exe --headless --editor --path G:/TDef --quit` before headless tests. Runner: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:/TDef --script tests/gdunit4_runner.gd -- -a <res:// path> --ignoreHeadlessMode` (forward slashes under Git Bash). Run ONLY the targeted suites named per task; never the full suite; no live Godot MCP verification unless the user asks.
- Commit and push to `main` after each task once its targeted tests pass, staging only the files listed; verify with `git show --name-only --format= HEAD`. Commit messages end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.
- Python-based edits must read/write `encoding='utf-8'` (a double-encoded section sign bit this project before).

## Rulings / deviations from the spec (apply these; Task 8 records them in the spec)

1. `ReduceMotion` lives at `src/core/visual_presentation/reduce_motion.gd` (the spec's `src/core/presentation/` directory does not exist).
2. Resolve visual is driven by a DIRECT call `entity.monster_instance.play_windup_resolved(hit)` from `_hero_windup_tick` (synchronous, ordering-safe); the deferred `monster_hero_attack_resolved` signal exists for audio and other subscribers.
3. Hero sprite low-HP treatment uses a steady `modulate` tint (`LOW_HP_SPRITE_TINT`), not a new sprite shader; the screen shader carries the vignette and death desaturation.
4. Audio: the new cues reuse existing Kenney-derived wavs as placeholders (no new assets). The low-HP heartbeat cue and the 40% combat duck on death are DEFERRED (enhancement only; no asset). Visual signals are the primary channel per `hero.md`.
5. SceneManager cancels a pending death exit on any `mission_phase_changed` whose new phase is not `DEFEAT`/`MISSION_COMPLETE` (this is how a Retry, which reuses the scene and never calls `_do_transition`, cancels it).

## File Structure

| File | Responsibility |
|---|---|
| `src/core/visual_presentation/reduce_motion.gd` (new) | `ReduceMotion.enabled()` accessor |
| `src/foundation/event_bus/event_bus.gd` | new signal `monster_hero_attack_resolved` |
| `src/core/monster/monster_manager.gd` | emit resolve, call `play_windup_resolved`, `_sync_windup_telegraph`, boss hint, `get_monster_world_position` |
| `src/core/monster/monster_instance.gd` | telegraph state + drawing + resolve visual |
| `src/core/visual_presentation/hero_feedback.gd` (new) | Hero flash/particles/flinch/shake, vignette, death sequence |
| `src/shaders/hero_screen_fx.gdshader` (new) | full-screen vignette + desaturation |
| `src/core/scene_manager.gd` | death-exit hold |
| `src/core/audio/audio_cue_dispatcher.gd`, `assets/data/audio/cues/*.tres`, `assets/data/audio/audio_cue_map.tres` | 3 new cues |
| `src/scenes/mission_scene.gd`, `src/gameplay/missions/the_gap/the_gap.gd` | add the `HeroFeedback` node |

---

### Task 1: `ReduceMotion` accessor

**Files:**
- Create: `src/core/visual_presentation/reduce_motion.gd`
- Test: `tests/unit/visual_presentation/reduce_motion_test.gd`

**Interfaces:**
- Produces: `ReduceMotion.enabled() -> bool` (static), `ReduceMotion.SETTING_KEY: String = "accessibility/reduce_motion"`.

- [ ] **Step 1: Write the failing test** `tests/unit/visual_presentation/reduce_motion_test.gd`

```gdscript
extends GdUnitTestSuite

## Unit tests for ReduceMotion (wind-up presentation spec §6).

var _original: Variant = null
var _had_setting: bool = false


func before_test() -> void:
	_had_setting = ProjectSettings.has_setting(ReduceMotion.SETTING_KEY)
	_original = ProjectSettings.get_setting(ReduceMotion.SETTING_KEY) if _had_setting else null


func after_test() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, _original if _had_setting else null)


func test_defaults_to_false_when_the_setting_is_absent() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, null)
	assert_bool(ReduceMotion.enabled()).is_false()


func test_reads_true_from_the_project_setting() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, true)
	assert_bool(ReduceMotion.enabled()).is_true()


func test_reads_false_from_the_project_setting() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, false)
	assert_bool(ReduceMotion.enabled()).is_false()
```

- [ ] **Step 2: Run** `res://tests/unit/visual_presentation/reduce_motion_test.gd` — expect FAIL (`ReduceMotion` not found; run the editor-mode reimport first so the new `class_name` registers).

- [ ] **Step 3: Implement** `src/core/visual_presentation/reduce_motion.gd`

```gdscript
class_name ReduceMotion
extends RefCounted

## Single reduced-motion accessor (wind-up presentation spec §6). Backed by a project-setting
## key that defaults to false, so it can be flipped by hand, by a test, or by a future settings
## screen with no code change. No UI and no persistence yet.
##
## Honored by: the big-hit screen shake (skipped), the low-HP vignette pulse (steady), the
## telegraph pulse (steady tint), and the death shockwave ring (skipped).
##
## Usage: if ReduceMotion.enabled(): return

const SETTING_KEY: String = "accessibility/reduce_motion"


## True when the player (or a test) has asked for reduced motion.
static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING_KEY, false))
```

- [ ] **Step 4: Run** the suite again — expect 3 PASS.
- [ ] **Step 5: Commit + push** `git add src/core/visual_presentation/reduce_motion.gd tests/unit/visual_presentation/reduce_motion_test.gd` (plus the generated `.uid` files if the editor pass created them), message `Add ReduceMotion accessor for the wind-up presentation`.

---

### Task 2: `monster_hero_attack_resolved` signal, boss hint, world-position getter

**Files:**
- Modify: `src/foundation/event_bus/event_bus.gd` (after `monster_hero_attack_winding_up`, ~line 485)
- Modify: `src/core/monster/monster_manager.gd` (`_hero_windup_tick` ~line 544; `update_boss` call ~line 764; new getter)
- Modify: `tests/unit/event_bus/event_bus_signals_test.gd` (79 → 80, update the tally comment)
- Test: `tests/unit/monster/monster_hero_attack_test.gd`

**Interfaces:**
- Produces: `GEventBus.monster_hero_attack_resolved(entity_id: int, hit: bool)` emitted DEFERRED once per completed wind-up; `MonsterManager.get_monster_world_position(entity_id: int) -> Vector2` (`Vector2.INF` when unknown).

- [ ] **Step 1: Write failing tests** in `monster_hero_attack_test.gd`. In `before_test` add `_spy.watch(GEventBus.monster_hero_attack_resolved)`. Append:

```gdscript
# --- resolve signal (wind-up presentation spec §4.2) ------------------------

func test_a_completed_windup_that_lands_emits_resolved_with_hit_true() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.5)
	_mm._pass2b_hero_attacks(0.5)
	await get_tree().process_frame  # emitted deferred
	assert_int(_spy.count("monster_hero_attack_resolved")).is_equal(1)
	var args: Array = (_spy.emissions["monster_hero_attack_resolved"] as Array)[0] as Array
	assert_int(args[0]).is_equal(elite.entity_id)
	assert_bool(args[1]).is_true()


func test_a_whiff_emits_resolved_with_hit_false() -> void:
	_elite()
	_mm._pass2b_hero_attacks(0.5)
	_mm._hero_cell = HERO_FAR
	_mm._pass2b_hero_attacks(0.5)
	await get_tree().process_frame
	assert_int(_spy.count("monster_hero_attack_resolved")).is_equal(1)
	assert_bool((_spy.emissions["monster_hero_attack_resolved"] as Array)[0][1]).is_false()


func test_resolved_is_not_emitted_before_the_windup_completes_or_for_a_monster_killed_mid_windup() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.5)
	await get_tree().process_frame
	assert_int(_spy.count("monster_hero_attack_resolved")).is_equal(0)
	elite.lifecycle_state = MonsterEntity.State.DEAD
	_mm._pass2b_hero_attacks(0.6)
	await get_tree().process_frame
	assert_int(_spy.count("monster_hero_attack_resolved")).is_equal(0)


func test_get_monster_world_position_returns_the_entity_position_or_inf() -> void:
	var elite := _elite()
	elite.global_position = Vector2(128.0, 64.0)
	_mm._entity_lookup[elite.entity_id] = elite
	assert_vector(_mm.get_monster_world_position(elite.entity_id)).is_equal(Vector2(128.0, 64.0))
	assert_vector(_mm.get_monster_world_position(99999)).is_equal(Vector2.INF)
```

(If `test_a_monster_killed_mid_windup_never_fires` shows a different way to mark death, mirror it.) Also in `event_bus_signals_test.gd` change `.is_equal(79)` to `.is_equal(80)` and extend the comment: `+ 1 added by wind-up presentation: monster_hero_attack_resolved`.

- [ ] **Step 2: Run** `monster_hero_attack_test.gd` and `event_bus_signals_test.gd` — expect the new tests FAIL.

- [ ] **Step 3: Implement.**

`event_bus.gd`, directly after `monster_hero_attack_winding_up`:

```gdscript
## An ELITE/BOSS Hero wind-up completed (wind-up presentation spec §4.2). `hit` is true when
## `hero_incoming_damage` was emitted, false when the Hero had left range (a whiff). Emitted
## DEFERRED (ADR-0001 Rule 2, physics caller). Announcement only: no simulation code branches on it.
## Subscribers: Audio (whiff cue).
signal monster_hero_attack_resolved(entity_id: int, hit: bool)
```

`monster_manager.gd`, `_hero_windup_tick`: replace the tail

```gdscript
	if not _hero_in_range(entity):
		return
	var ev := HeroIncomingDamageEvent.new()
```
with
```gdscript
	var hit: bool = _hero_in_range(entity)
	GEventBus.monster_hero_attack_resolved.emit.call_deferred(entity.entity_id, hit)
	if not hit:
		return
	var ev := HeroIncomingDamageEvent.new()
```
and extend the function's doc comment: "announces the outcome through the deferred `monster_hero_attack_resolved`".

Boss hint (~line 764): change the `update_boss` last-but-one argument to `entity.boss_attack_prepare_remaining > 0 or entity.hero_windup_remaining > 0.0` and add a one-line comment (Hero wind-ups also drive the existing prepare/attack overlay; wind-up presentation spec §4.3).

Getter (near `_hero_targetable`):

```gdscript
## World position of a live monster, or Vector2.INF when the id is unknown or freed. Lets
## presentation (HeroFeedback) resolve a damage source without touching private state.
func get_monster_world_position(entity_id: int) -> Vector2:
	var entity: MonsterEntity = _entity_lookup.get(entity_id) as MonsterEntity
	if entity == null or not is_instance_valid(entity):
		return Vector2.INF
	return entity.global_position
```

- [ ] **Step 4: Run** `monster_hero_attack_test.gd`, `monster_boss_test.gd`, `event_bus_signals_test.gd` — all PASS. (No test change needed for the boss hint beyond the existing boss tests still passing; the renderer-facing arg is exercised in Task 3's live checklist.)
- [ ] **Step 5: Commit + push** the four files above, message `Add monster_hero_attack_resolved signal, boss Hero-windup hint, monster position getter`.

---

### Task 3: Attacker telegraph on `MonsterInstance` + manager sync

**Files:**
- Modify: `src/core/monster/monster_instance.gd`
- Modify: `src/core/monster/monster_manager.gd` (`_pass3c_visual_sync`; `_hero_windup_tick`)
- Test: `tests/unit/monster/monster_instance_telegraph_test.gd` (new), `tests/unit/monster/monster_hero_attack_test.gd` (one sync test)

**Interfaces:**
- Consumes: Task 1 `ReduceMotion.enabled()`.
- Produces on `MonsterInstance`:
  - `static func windup_progress(remaining: float, total: float) -> float`
  - `static func reach_half_extent(range_cells: int) -> float`
  - `static func pulse_amount(elapsed: float) -> float`
  - `func set_windup_telegraph(progress: float, range_cells: int, center_offset: Vector2, delta: float) -> void`
  - `func clear_windup_telegraph() -> void`
  - `func play_windup_resolved(hit: bool) -> void`
  - `func is_windup_telegraph_active() -> bool`, `func get_windup_progress() -> float`, `func get_resolve_alpha() -> float`

- [ ] **Step 1: Write failing tests** `tests/unit/monster/monster_instance_telegraph_test.gd`

```gdscript
extends GdUnitTestSuite

## Unit tests for MonsterInstance's wind-up telegraph (wind-up presentation spec §4.1/§4.2).

const SCENE: PackedScene = preload("res://src/core/monster/MonsterInstance.tscn")

var _inst: MonsterInstance


func before_test() -> void:
	_inst = SCENE.instantiate() as MonsterInstance
	add_child(_inst)
	_inst.configure(&"forest_troll_elite", 1, "Troll")


func after_test() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, null)
	if is_instance_valid(_inst):
		_inst.free()


func test_progress_is_zero_at_start_one_at_end_and_clamped() -> void:
	assert_float(MonsterInstance.windup_progress(1.0, 1.0)).is_equal(0.0)
	assert_float(MonsterInstance.windup_progress(0.5, 1.0)).is_equal_approx(0.5, 0.0001)
	assert_float(MonsterInstance.windup_progress(0.0, 1.0)).is_equal(1.0)
	assert_float(MonsterInstance.windup_progress(-0.2, 1.0)).is_equal(1.0)
	assert_float(MonsterInstance.windup_progress(2.0, 1.0)).is_equal(0.0)
	assert_float(MonsterInstance.windup_progress(0.5, 0.0)).is_equal(1.0)


func test_reach_half_extent_is_a_square_of_2r_plus_1_cells() -> void:
	assert_float(MonsterInstance.reach_half_extent(2)).is_equal(160.0)  # 5 cells * 64 / 2
	assert_float(MonsterInstance.reach_half_extent(3)).is_equal(224.0)


func test_pulse_amount_stays_in_range_and_completes_two_cycles_per_second() -> void:
	for i in range(0, 100):
		var a: float = MonsterInstance.pulse_amount(float(i) * 0.013)
		assert_bool(a >= 0.0 and a <= 1.0).is_true()
	assert_float(MonsterInstance.pulse_amount(0.0)).is_equal_approx(MonsterInstance.pulse_amount(0.5), 0.0001)


func test_pulse_is_steady_under_reduced_motion() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, true)
	assert_float(MonsterInstance.pulse_amount(0.0)).is_equal(MonsterInstance.pulse_amount(0.13))


func test_set_activates_and_clear_deactivates_the_telegraph() -> void:
	_inst.set_windup_telegraph(0.4, 2, Vector2.ZERO, 0.016)
	assert_bool(_inst.is_windup_telegraph_active()).is_true()
	assert_float(_inst.get_windup_progress()).is_equal_approx(0.4, 0.0001)
	_inst.clear_windup_telegraph()
	assert_bool(_inst.is_windup_telegraph_active()).is_false()


func test_clear_restores_the_sprite_tint() -> void:
	_inst.set_windup_telegraph(0.4, 2, Vector2.ZERO, 0.1)
	_inst.clear_windup_telegraph()
	assert_object(_inst.get_node("Sprite2D").modulate).is_equal(Color.WHITE)


func test_resolved_starts_a_fade_that_a_clear_does_not_cancel() -> void:
	_inst.set_windup_telegraph(1.0, 2, Vector2.ZERO, 0.016)
	_inst.play_windup_resolved(true)
	_inst.clear_windup_telegraph()  # the manager clears in the same frame the wind-up resolves
	assert_float(_inst.get_resolve_alpha()).is_greater(0.0)


func test_a_new_telegraph_cancels_a_running_resolve_fade() -> void:
	_inst.play_windup_resolved(false)
	_inst.set_windup_telegraph(0.1, 2, Vector2.ZERO, 0.016)
	assert_float(_inst.get_resolve_alpha()).is_equal(0.0)


func test_resolve_fade_reaches_zero() -> void:
	_inst.set_windup_telegraph(1.0, 2, Vector2.ZERO, 0.016)
	_inst.play_windup_resolved(false)
	await get_tree().create_timer(MonsterInstance.RESOLVE_WHIFF_DURATION + 0.1).timeout
	assert_float(_inst.get_resolve_alpha()).is_equal(0.0)


func test_freeing_mid_resolve_does_not_error() -> void:
	_inst.play_windup_resolved(true)
	_inst.free()
	_inst = null
	await get_tree().process_frame
	assert_bool(true).is_true()
```

In `monster_hero_attack_test.gd` append:

```gdscript
func test_visual_sync_drives_the_telegraph_from_the_windup_state() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.4)  # starts the 1.0 s wind-up, ticks 0.4
	_mm._pass3c_visual_sync(0.016)
	assert_bool(elite.monster_instance.is_windup_telegraph_active()).is_true()
	assert_float(elite.monster_instance.get_windup_progress()).is_equal_approx(0.4, 0.001)
	_mm._pass2b_hero_attacks(0.7)  # completes
	_mm._pass3c_visual_sync(0.016)
	assert_bool(elite.monster_instance.is_windup_telegraph_active()).is_false()
	assert_float(elite.monster_instance.get_resolve_alpha()).is_greater(0.0)
```

- [ ] **Step 2: Run** both suites — expect FAIL (methods missing).

- [ ] **Step 3: Implement `monster_instance.gd`.** Add constants (after `BOSS_BADGE_COLOR`):

```gdscript
## Wind-up telegraph (wind-up presentation spec §4.1). Mirrors MonsterManager.CELL_SIZE (a direct
## reference would make the two scripts depend on each other at parse time).
const CELL_SIZE: float = 64.0
const TELEGRAPH_COLOR: Color = Color(0.878, 0.267, 0.18)
const TELEGRAPH_PULSE_HZ: float = 2.0  ## at most 2 flashes per second (flash-safety limit is 3)
const TELEGRAPH_TINT_STRENGTH: float = 0.55
const TELEGRAPH_OUTLINE_WIDTH: float = 3.0
const TELEGRAPH_DASH: float = 10.0
const TELEGRAPH_BAR_SIZE: Vector2 = Vector2(40.0, 6.0)
const TELEGRAPH_BAR_GAP: float = 6.0
const RESOLVE_HIT_DURATION: float = 0.15
const RESOLVE_WHIFF_DURATION: float = 0.3
const RESOLVE_WHIFF_COLOR: Color = Color(0.72, 0.72, 0.72)
```

Add state (after `_hit_flash_tween`):

```gdscript
var _telegraph_active: bool = false
var _telegraph_progress: float = 0.0
var _telegraph_range_cells: int = 0
var _telegraph_center_offset: Vector2 = Vector2.ZERO
var _telegraph_time: float = 0.0
var _resolve_alpha: float = 0.0
var _resolve_hit: bool = false
var _resolve_tween: Tween = null
```

Add methods (before `_draw`):

```gdscript
func _exit_tree() -> void:
	_kill_resolve_tween()


## 0 at the start of the wind-up, 1 when it fires. A zero-length wind-up reads as complete.
static func windup_progress(remaining: float, total: float) -> float:
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - remaining / total, 0.0, 1.0)


## Half the side of the reach square: reach is Chebyshev distance, so it is a (2r+1)-cell square.
static func reach_half_extent(range_cells: int) -> float:
	return (float(range_cells) + 0.5) * CELL_SIZE


## 0..1 pulse at TELEGRAPH_PULSE_HZ; a steady 0.5 under reduced motion.
static func pulse_amount(elapsed: float) -> float:
	if ReduceMotion.enabled():
		return 0.5
	return 0.5 + 0.5 * sin(TAU * TELEGRAPH_PULSE_HZ * elapsed)


## Driven every frame by MonsterManager._pass3c_visual_sync while a Hero wind-up is in flight.
## `center_offset` is the vector from this node to the CENTER of the monster's grid cell (the
## Hero-hit range check is made from that cell), so the outline matches what the simulation judges.
func set_windup_telegraph(progress: float, range_cells: int, center_offset: Vector2, delta: float) -> void:
	if not _telegraph_active:
		_telegraph_time = 0.0
	_kill_resolve_tween()
	_resolve_alpha = 0.0
	_telegraph_active = true
	_telegraph_progress = progress
	_telegraph_range_cells = range_cells
	_telegraph_center_offset = center_offset
	_telegraph_time += delta
	_sprite.modulate = Color.WHITE.lerp(TELEGRAPH_COLOR, pulse_amount(_telegraph_time) * TELEGRAPH_TINT_STRENGTH)
	queue_redraw()


## Ends the live telegraph. Deliberately leaves a running resolve fade alone: the wind-up state
## clears in the same frame it resolves, and the hit/whiff confirmation must outlive it.
func clear_windup_telegraph() -> void:
	if not _telegraph_active:
		return
	_telegraph_active = false
	_sprite.modulate = Color.WHITE
	queue_redraw()


## Hit: the outline flashes solid red then clears. Whiff: it fades to neutral grey (the player's
## "I dodged it" confirmation). Reuses the geometry of the last telegraph.
func play_windup_resolved(hit: bool) -> void:
	_kill_resolve_tween()
	_resolve_hit = hit
	_resolve_alpha = 1.0
	var duration: float = RESOLVE_HIT_DURATION if hit else RESOLVE_WHIFF_DURATION
	_resolve_tween = create_tween()
	_resolve_tween.tween_method(_set_resolve_alpha, 1.0, 0.0, duration)
	queue_redraw()


func is_windup_telegraph_active() -> bool:
	return _telegraph_active


func get_windup_progress() -> float:
	return _telegraph_progress


func get_resolve_alpha() -> float:
	return _resolve_alpha


func _set_resolve_alpha(value: float) -> void:
	_resolve_alpha = value
	queue_redraw()


func _kill_resolve_tween() -> void:
	if _resolve_tween != null and _resolve_tween.is_valid():
		_resolve_tween.kill()
	_resolve_tween = null
```

Extend `_draw()`:

```gdscript
func _draw() -> void:
	match _tier:
		1:
			_draw_elite_badge()
		2:
			_draw_boss_badge()
	if _telegraph_active:
		_draw_reach_outline(TELEGRAPH_COLOR, 1.0, true)
		_draw_progress_bar()
	elif _resolve_alpha > 0.0:
		if _resolve_hit:
			_draw_reach_outline(TELEGRAPH_COLOR, _resolve_alpha, false)
		else:
			_draw_reach_outline(RESOLVE_WHIFF_COLOR, _resolve_alpha, true)


## Outline of the reach square. Dashed while a wind-up is live (the shape is the non-color cue);
## solid for the hit flash.
func _draw_reach_outline(color: Color, alpha: float, dashed: bool) -> void:
	var half: float = reach_half_extent(_telegraph_range_cells)
	var c: Vector2 = _telegraph_center_offset
	var corners := PackedVector2Array([
		c + Vector2(-half, -half), c + Vector2(half, -half),
		c + Vector2(half, half), c + Vector2(-half, half),
	])
	var draw_color := Color(color.r, color.g, color.b, alpha)
	for i in range(4):
		var from: Vector2 = corners[i]
		var to: Vector2 = corners[(i + 1) % 4]
		if dashed:
			draw_dashed_line(from, to, draw_color, TELEGRAPH_OUTLINE_WIDTH, TELEGRAPH_DASH)
		else:
			draw_line(from, to, draw_color, TELEGRAPH_OUTLINE_WIDTH)


## Countdown bar under the sprite (the second non-color cue): dark track, red fill, red border.
func _draw_progress_bar() -> void:
	var top_left := Vector2(-TELEGRAPH_BAR_SIZE.x * 0.5, _sprite_half_size.y + TELEGRAPH_BAR_GAP)
	draw_rect(Rect2(top_left, TELEGRAPH_BAR_SIZE), Color(0.14, 0.12, 0.09), true)
	draw_rect(Rect2(top_left, Vector2(TELEGRAPH_BAR_SIZE.x * _telegraph_progress, TELEGRAPH_BAR_SIZE.y)), TELEGRAPH_COLOR, true)
	draw_rect(Rect2(top_left, TELEGRAPH_BAR_SIZE), TELEGRAPH_COLOR, false, 1.0)
```

(The existing `_draw()` match block is replaced by the version above; keep the badge functions unchanged.)

- [ ] **Step 4: Implement `monster_manager.gd`.** In `_pass3c_visual_sync`, as the first statement after the `is_instance_valid` guard (before the `swarm_handle` branch, so it runs regardless of presentation mode):

```gdscript
		_sync_windup_telegraph(entity, delta)
```

Add:

```gdscript
## Wind-up presentation spec §4.1: feeds the monster's 2D visual from the wind-up state each frame
## (pull model: nothing to clean up if the monster dies or is freed mid-wind-up). The reach outline
## is centered on the monster's grid CELL, the cell the Hero-hit range check is measured from.
func _sync_windup_telegraph(entity: MonsterEntity, delta: float) -> void:
	var inst: MonsterInstance = entity.monster_instance
	if inst == null or not is_instance_valid(inst):
		return
	if entity.hero_windup_remaining <= 0.0:
		inst.clear_windup_telegraph()
		return
	var cell: Vector2i = _grid.world_to_cell(entity.global_position)
	var center_offset: Vector2 = _grid.cell_to_world(cell) - entity.global_position
	inst.set_windup_telegraph(
			MonsterInstance.windup_progress(entity.hero_windup_remaining, entity.resource.hero_attack_windup_seconds),
			entity.resource.boss_attack_range_cells, center_offset, delta)
```

In `_hero_windup_tick`, right after computing `hit` (Task 2):

```gdscript
	if entity.monster_instance != null and is_instance_valid(entity.monster_instance):
		entity.monster_instance.play_windup_resolved(hit)
```

- [ ] **Step 5: Run** `monster_instance_telegraph_test.gd`, `monster_hero_attack_test.gd`, `monster_boss_test.gd`, plus any existing `MonsterInstance` tests (`grep -rl "MonsterInstance" tests/unit`) — all PASS.
- [ ] **Step 6: Commit + push** the changed files, message `Add attacker wind-up telegraph: tint, dashed reach outline, progress bar, hit/whiff resolve`.

---

### Task 4: Audio cues (wind-up warning, whiff, Hero death)

**Files:**
- Create: `assets/data/audio/cues/monster_windup_warning.tres`, `monster_attack_whiff.tres`, `hero_died.tres`
- Modify: `assets/data/audio/audio_cue_map.tres`, `src/core/audio/audio_cue_dispatcher.gd`
- Test: `tests/unit/audio/audio_cue_dispatcher_windup_test.gd` (new); update any existing test that counts the real map's entries (`grep -rn "audio_cue_map" tests`).

**Interfaces:**
- Consumes: Task 2 `monster_hero_attack_resolved`.
- Produces: cues `&"monster_windup_warning"`, `&"monster_attack_whiff"`, `&"hero_died"`; `AudioCueDispatcher.WINDUP_WARNING_MIN_GAP_MSEC: int = 250`.

- [ ] **Step 1: Write failing test** (read an existing dispatcher test first for how they inject a fixture map and count plays — mirror it). Cases: (a) `monster_hero_attack_winding_up` emitted twice within 250 ms dispatches `monster_windup_warning` once; after the gap, again; (b) `monster_hero_attack_resolved(id, false)` dispatches `monster_attack_whiff`, `(id, true)` dispatches nothing; (c) `hero_died` dispatches `hero_died`; (d) the real `audio_cue_map.tres` contains all three event names.

- [ ] **Step 2: Run** — FAIL.

- [ ] **Step 3: Implement.** Cue files (Write tool; template from `hero_damage_taken.tres`, single stream, no randomizer). Placeholders per Ruling 4:

`monster_windup_warning.tres`
```
[gd_resource type="Resource" script_class="AudioCueEntry" load_steps=3 format=3]

[ext_resource type="Script" path="res://src/core/audio/audio_cue_entry.gd" id="1"]
[ext_resource type="AudioStream" path="res://assets/audio/sfx/wave_countdown_warning.wav" id="2"]

[resource]
script = ExtResource("1")
event_name = &"monster_windup_warning"
stream = ExtResource("2")
bus = &"SFX"
polyphony_group = &"combat_impact"
volume_db_offset = -6
spatial = false
```
`monster_attack_whiff.tres` — same shape, `event_name = &"monster_attack_whiff"`, stream `tower_attacked_v2.wav`, `volume_db_offset = -9`.
`hero_died.tres` — `event_name = &"hero_died"`, stream `boss_died.wav`, `volume_db_offset = -2`.

Register all three in `audio_cue_map.tres` exactly like `hero_damage_taken` (ext_resource line + entry in the `entries` array; read the file first and keep its id/format conventions).

Dispatcher, in `_connect_all_events()` after the `hero_damage_taken` wiring:

```gdscript
	_wire(GEventBus.monster_hero_attack_winding_up, func(_a: int, _b: float) -> void: _dispatch_windup_warning())
	_wire(GEventBus.monster_hero_attack_resolved, func(_a: int, hit: bool) -> void:
			if not hit:
				dispatch_cue(&"monster_attack_whiff"))
	_wire(GEventBus.hero_died, func() -> void: dispatch_cue(&"hero_died"))
```

and

```gdscript
## A pack of elites can wind up in the same frame; one warning per window keeps it from becoming a
## wall of sound (wind-up presentation spec §7).
const WINDUP_WARNING_MIN_GAP_MSEC: int = 250
var _last_windup_warning_msec: int = -WINDUP_WARNING_MIN_GAP_MSEC


func _dispatch_windup_warning() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_windup_warning_msec < WINDUP_WARNING_MIN_GAP_MSEC:
		return
	_last_windup_warning_msec = now
	dispatch_cue(&"monster_windup_warning")
```

- [ ] **Step 4: Run** the new test, the dispatcher's existing suites (`res://tests/unit/audio`), and any test found by the `audio_cue_map` grep — fix counts that legitimately changed (16→19-style tallies).
- [ ] **Step 5: Commit + push** cue `.tres` files, map, dispatcher, tests, message `Add wind-up warning, whiff and Hero death audio cues`.

---

### Task 5: `HeroFeedback` — damage flash, particles, flinch, big-hit shake

**Files:**
- Create: `src/core/visual_presentation/hero_feedback.gd`
- Test: `tests/unit/visual_presentation/hero_feedback_damage_test.gd`

**Interfaces:**
- Consumes: `ReduceMotion.enabled()`, `MonsterManager.get_monster_world_position` (passed as a Callable), `GEventBus.hero_incoming_damage/hero_damage_taken/hero_health_changed`.
- Produces: `HeroFeedback` (`class_name`, extends `Node`) with
  - `func setup(hero: Node2D, camera: Camera2D, source_position_provider: Callable) -> void` (call BEFORE `add_child` is fine; connections are made in `_ready`)
  - `static func is_big_hit(amount: int, max_hp: float) -> bool` (strictly `> 25%`)
  - `static func is_low_hp(current: float, max_hp: float) -> bool` (Task 6 uses it; define here)
  - `static func flash_frames(big_hit: bool) -> int`
  - `func can_restart_flash(now_msec: int) -> bool`
  - consts `FRAME_SECONDS = 1.0/60.0`, `FLASH_FRAMES = 2`, `BIG_FLASH_FRAMES = 4`, `BIG_HIT_FRACTION = 0.25`, `LOW_HP_FRACTION = 0.20`, `MIN_FLASH_GAP_MSEC = 200`, `PARTICLE_COUNT = 5`, `PARTICLE_LIFETIME = 0.3`, `FLINCH_FRAMES = 3`, `FLINCH_DISTANCE = 4.0`, `SHAKE_MAGNITUDE = 2.0`, `SHAKE_FRAMES = 6`, `FEEDBACK_LAYER = 0`, `DEATH_FLASH_FRAMES = 4`, `DEATH_FADE_FRAMES = 12`, `DEATH_RING_FRAMES = 16`, `DEATH_RING_RADIUS = 128.0`, `DEATH_DESATURATE = 0.4`, `VIGNETTE_MIN = 0.4`, `VIGNETTE_MAX = 0.7`, `VIGNETTE_PERIOD = 1.5`, `VIGNETTE_FADE_SECONDS = 0.3`, `LOW_HP_SPRITE_TINT = Color(1.0, 0.75, 0.75)` (Tasks 6/7 use the vignette/death ones; declare them all now so the constant block is written once).
  - handlers `_on_incoming_damage(payload: HeroIncomingDamageEvent)`, `_on_damage_taken(amount: int, source_type: int)`, `_on_health_changed(current: float, max_hp: float)`.

- [ ] **Step 1: Write failing tests** `hero_feedback_damage_test.gd`. Fixture: a `Node2D` stub Hero with a `Sprite2D` child named `Sprite2D`, a `Camera2D`, an empty parent, `HeroFeedback.new()`; call `setup(hero, camera, provider)` with a provider returning `Vector2.INF` or a fixed point, then `add_child`. Cases:

```gdscript
func test_is_big_hit_is_strictly_greater_than_25_percent() -> void:
	assert_bool(HeroFeedback.is_big_hit(25, 100.0)).is_false()
	assert_bool(HeroFeedback.is_big_hit(26, 100.0)).is_true()
	assert_bool(HeroFeedback.is_big_hit(50, 0.0)).is_false()  # max unknown: never a big hit


func test_flash_frames_are_two_normally_four_for_a_big_hit() -> void:
	assert_int(HeroFeedback.flash_frames(false)).is_equal(2)
	assert_int(HeroFeedback.flash_frames(true)).is_equal(4)


func test_flash_restarts_are_gated_to_one_per_200ms() -> void:
	var fb := HeroFeedback.new()
	auto_free(fb)
	assert_bool(fb.can_restart_flash(1000)).is_true()
	assert_bool(fb.can_restart_flash(1100)).is_false()
	assert_bool(fb.can_restart_flash(1200)).is_true()


func test_a_hit_flashes_the_sprite_and_spawns_particles_toward_the_source() -> void:
	_fb._on_health_changed(200.0, 200.0)
	_fb._on_incoming_damage(_event(7))
	_fb._on_damage_taken(10, 0)
	var mat: ShaderMaterial = _sprite.material as ShaderMaterial
	assert_object(mat).is_not_null()
	assert_float(float(mat.get_shader_parameter("flash_amount"))).is_greater(0.0)
	var bursts: Array = _hero_parent.get_children().filter(func(n: Node) -> bool: return n is CPUParticles2D)
	assert_int(bursts.size()).is_equal(1)
	var p: CPUParticles2D = bursts[0] as CPUParticles2D
	assert_bool(p.emitting).is_true()
	assert_bool(p.one_shot).is_true()
	assert_vector(p.direction).is_equal_approx(Vector2.RIGHT, Vector2(0.01, 0.01))  # source is at +x


func test_a_hit_with_an_unknown_source_still_flashes_and_bursts_without_direction() -> void:
	_fb._on_health_changed(200.0, 200.0)
	_fb._on_incoming_damage(_event(999))  # provider returns Vector2.INF for this id
	_fb._on_damage_taken(10, 0)
	var bursts: Array = _hero_parent.get_children().filter(func(n: Node) -> bool: return n is CPUParticles2D)
	assert_int(bursts.size()).is_equal(1)
	assert_float((bursts[0] as CPUParticles2D).spread).is_equal(180.0)
	assert_float(float((_sprite.material as ShaderMaterial).get_shader_parameter("flash_amount"))).is_greater(0.0)


func test_flinch_moves_the_sprite_away_from_the_source_then_returns_it() -> void:
	_fb._on_incoming_damage(_event(7))
	_fb._on_damage_taken(10, 0)
	await get_tree().create_timer(HeroFeedback.FRAME_SECONDS * 2.0).timeout
	assert_float(_sprite.position.x).is_less(_rest.x)  # source at +x, so recoil is toward -x
	await get_tree().create_timer(0.2).timeout
	assert_vector(_sprite.position).is_equal_approx(_rest, Vector2(0.01, 0.01))


func test_a_big_hit_shakes_the_camera_offset_and_it_settles_to_zero() -> void:
	_fb._on_health_changed(200.0, 200.0)
	_fb._on_damage_taken(60, 0)  # 30% of max
	var moved: bool = false
	for i in range(5):
		await get_tree().process_frame
		if _camera.offset != Vector2.ZERO:
			moved = true
	assert_bool(moved).is_true()
	await get_tree().create_timer(0.25).timeout
	assert_vector(_camera.offset).is_equal(Vector2.ZERO)


func test_a_big_hit_does_not_shake_under_reduced_motion() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, true)
	_fb._on_health_changed(200.0, 200.0)
	_fb._on_damage_taken(60, 0)
	for i in range(5):
		await get_tree().process_frame
		assert_vector(_camera.offset).is_equal(Vector2.ZERO)


func test_a_normal_hit_does_not_shake() -> void:
	_fb._on_health_changed(200.0, 200.0)
	_fb._on_damage_taken(50, 0)  # exactly 25%: not a big hit
	for i in range(5):
		await get_tree().process_frame
		assert_vector(_camera.offset).is_equal(Vector2.ZERO)


func test_signals_are_disconnected_on_exit() -> void:
	remove_child(_fb)
	assert_bool(GEventBus.hero_damage_taken.is_connected(_fb._on_damage_taken)).is_false()
	assert_bool(GEventBus.hero_incoming_damage.is_connected(_fb._on_incoming_damage)).is_false()
	assert_bool(GEventBus.hero_health_changed.is_connected(_fb._on_health_changed)).is_false()
	add_child(_fb)  # after_test frees it through the normal path
```

Shared fixture at the top of the suite (Tasks 6 and 7 copy it into their suites):

```gdscript
extends GdUnitTestSuite

var _hero_parent: Node2D
var _hero: Node2D
var _sprite: Sprite2D
var _camera: Camera2D
var _fb: HeroFeedback
var _rest: Vector2 = Vector2(3.0, 5.0)


func _provider(entity_id: int) -> Vector2:
	return Vector2(100.0, 0.0) if entity_id == 7 else Vector2.INF


func _event(source_entity_id: int) -> HeroIncomingDamageEvent:
	var ev := HeroIncomingDamageEvent.new()
	ev.amount = 10.0
	ev.damage_type = "physical"
	ev.source_type = 0
	ev.source_entity_id = source_entity_id
	return ev


func before_test() -> void:
	_hero_parent = Node2D.new()
	add_child(_hero_parent)
	_hero = Node2D.new()
	_hero_parent.add_child(_hero)
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_sprite.position = _rest
	_hero.add_child(_sprite)
	_camera = Camera2D.new()
	_hero_parent.add_child(_camera)
	_fb = HeroFeedback.new()
	_fb.setup(_hero, _camera, _provider)
	add_child(_fb)


func after_test() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, null)
	if is_instance_valid(_fb):
		_fb.free()
	_hero_parent.free()
```

- [ ] **Step 2: Run** — FAIL (class missing; editor-mode reimport first).

- [ ] **Step 3: Implement** `hero_feedback.gd`:

```gdscript
class_name HeroFeedback
extends Node

## Hero-side combat feedback (wind-up presentation spec §5): damage flash, directional particles,
## flinch, big-hit shake, low-HP vignette and the death sequence. Event-driven and presentation
## only: it never changes Hero state. One instance per mission scene; both mission scenes add it
## with a single call (see Task 8 wiring). Values are design/gdd/hero.md's Event Feedback table.
##
## Usage:
##   var fb := HeroFeedback.new()
##   fb.setup(_hero, _camera, _monster_manager.get_monster_world_position)
##   _gameplay_root.add_child(fb)

const FRAME_SECONDS: float = 1.0 / 60.0
const FLASH_FRAMES: int = 2
const BIG_FLASH_FRAMES: int = 4
const BIG_HIT_FRACTION: float = 0.25
const LOW_HP_FRACTION: float = 0.20
const MIN_FLASH_GAP_MSEC: int = 334
const PARTICLE_COUNT: int = 5
const PARTICLE_LIFETIME: float = 0.3
const PARTICLE_SPEED_MIN: float = 90.0
const PARTICLE_SPEED_MAX: float = 160.0
const FLINCH_FRAMES: int = 3
const FLINCH_DISTANCE: float = 4.0
const SHAKE_MAGNITUDE: float = 2.0
const SHAKE_FRAMES: int = 6
const FEEDBACK_LAYER: int = 0
const DEATH_FLASH_FRAMES: int = 4
const DEATH_FADE_FRAMES: int = 12
const DEATH_RING_FRAMES: int = 16
const DEATH_RING_RADIUS: float = 128.0
const DEATH_DESATURATE: float = 0.4
const VIGNETTE_MIN: float = 0.4
const VIGNETTE_MAX: float = 0.7
const VIGNETTE_PERIOD: float = 1.5
const VIGNETTE_FADE_SECONDS: float = 0.3
const LOW_HP_SPRITE_TINT: Color = Color(1.0, 0.75, 0.75)
const FLASH_TINT: Color = Color(1.0, 0.55, 0.55)
const HIT_FLASH_SHADER: Shader = preload("res://src/shaders/hit_flash.gdshader")

var _hero: Node2D = null
var _camera: Camera2D = null
var _source_position_provider: Callable = Callable()
var _sprite: Sprite2D = null
var _sprite_rest_position: Vector2 = Vector2.ZERO
var _flash_material: ShaderMaterial = null
var _flash_tween: Tween = null
var _flinch_tween: Tween = null
var _shake_tween: Tween = null
var _last_flash_msec: int = -MIN_FLASH_GAP_MSEC
var _last_source_entity_id: int = -1
var _max_hp: float = 0.0


## True when a single hit removed strictly more than 25% of max HP. Unknown max never counts.
static func is_big_hit(amount: int, max_hp: float) -> bool:
	return max_hp > 0.0 and float(amount) > max_hp * BIG_HIT_FRACTION


## True below 20% of max HP (Task 6).
static func is_low_hp(current: float, max_hp: float) -> bool:
	return max_hp > 0.0 and current > 0.0 and current / max_hp < LOW_HP_FRACTION


static func flash_frames(big_hit: bool) -> int:
	return BIG_FLASH_FRAMES if big_hit else FLASH_FRAMES


## Flash restarts are limited to one per MIN_FLASH_GAP_MSEC so overlapping attackers cannot push
## the Hero past the 3-flashes-per-second limit. Records the restart when it returns true.
func can_restart_flash(now_msec: int) -> bool:
	if now_msec - _last_flash_msec < MIN_FLASH_GAP_MSEC:
		return false
	_last_flash_msec = now_msec
	return true


## `source_position_provider(entity_id: int) -> Vector2` returns Vector2.INF for an unknown or
## freed monster (MonsterManager.get_monster_world_position).
func setup(hero: Node2D, camera: Camera2D, source_position_provider: Callable) -> void:
	_hero = hero
	_camera = camera
	_source_position_provider = source_position_provider
	_sprite = hero.get_node_or_null("Sprite2D") as Sprite2D
	if _sprite != null:
		_sprite_rest_position = _sprite.position


func _ready() -> void:
	GEventBus.hero_incoming_damage.connect(_on_incoming_damage)
	GEventBus.hero_damage_taken.connect(_on_damage_taken)
	GEventBus.hero_health_changed.connect(_on_health_changed)


func _exit_tree() -> void:
	if GEventBus.hero_incoming_damage.is_connected(_on_incoming_damage):
		GEventBus.hero_incoming_damage.disconnect(_on_incoming_damage)
	if GEventBus.hero_damage_taken.is_connected(_on_damage_taken):
		GEventBus.hero_damage_taken.disconnect(_on_damage_taken)
	if GEventBus.hero_health_changed.is_connected(_on_health_changed):
		GEventBus.hero_health_changed.disconnect(_on_health_changed)
	_kill_tween(_flash_tween)
	_kill_tween(_flinch_tween)
	_kill_tween(_shake_tween)


func _on_incoming_damage(payload: HeroIncomingDamageEvent) -> void:
	_last_source_entity_id = payload.source_entity_id


func _on_health_changed(_current: float, max_hp: float) -> void:
	_max_hp = max_hp


func _on_damage_taken(amount: int, _source_type: int) -> void:
	if _hero == null or not is_instance_valid(_hero):
		return
	var direction: Vector2 = _direction_to_source()
	var big: bool = is_big_hit(amount, _max_hp)
	if can_restart_flash(Time.get_ticks_msec()):
		_play_flash(flash_frames(big))
	_spawn_particles(direction)
	_play_flinch(direction)
	if big and not ReduceMotion.enabled():
		_play_shake()
	_last_source_entity_id = -1


## Unit vector from the Hero toward the damage source, or ZERO when the source is unknown/gone.
func _direction_to_source() -> Vector2:
	if _last_source_entity_id < 0 or not _source_position_provider.is_valid():
		return Vector2.ZERO
	var source_pos: Vector2 = _source_position_provider.call(_last_source_entity_id)
	if source_pos == Vector2.INF:
		return Vector2.ZERO
	return (source_pos - _hero.global_position).normalized()


func _play_flash(frames: int) -> void:
	if _sprite == null:
		return
	if _flash_material == null:
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = HIT_FLASH_SHADER
		if _sprite.material == null:
			_sprite.material = _flash_material
	_kill_tween(_flash_tween)
	var duration: float = float(frames) * FRAME_SECONDS
	_flash_material.set_shader_parameter("flash_amount", 1.0)
	_sprite.modulate = FLASH_TINT
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(v: float) -> void: _flash_material.set_shader_parameter("flash_amount", v), 1.0, 0.0, duration)
	_flash_tween.parallel().tween_property(_sprite, "modulate", _resting_sprite_modulate(), duration)


## Task 6 overrides the resting tint while the low-HP state is active.
func _resting_sprite_modulate() -> Color:
	return Color.WHITE


func _spawn_particles(direction: Vector2) -> void:
	var parent: Node = _hero.get_parent()
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = PARTICLE_COUNT
	p.lifetime = PARTICLE_LIFETIME
	p.explosiveness = 1.0
	p.initial_velocity_min = PARTICLE_SPEED_MIN
	p.initial_velocity_max = PARTICLE_SPEED_MAX
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(1.0, 0.45, 0.4)
	if direction == Vector2.ZERO:
		p.direction = Vector2.UP
		p.spread = 180.0
	else:
		p.direction = direction
		p.spread = 25.0
	parent.add_child(p)
	p.global_position = _hero.global_position
	p.emitting = true
	p.finished.connect(p.queue_free)


## 3-frame recoil opposite the damage direction, then back to rest. Cosmetic: it moves only the
## sprite, never the Hero body, so movement and auto-attack are unaffected.
func _play_flinch(direction: Vector2) -> void:
	if _sprite == null:
		return
	_kill_tween(_flinch_tween)
	_sprite.position = _sprite_rest_position
	var away: Vector2 = -direction * FLINCH_DISTANCE if direction != Vector2.ZERO else Vector2.ZERO
	var step: float = float(FLINCH_FRAMES) * FRAME_SECONDS
	_flinch_tween = create_tween()
	_flinch_tween.tween_property(_sprite, "position", _sprite_rest_position + away, step * 0.5)
	_flinch_tween.tween_property(_sprite, "position", _sprite_rest_position, step * 0.5)


## 2-pixel, 6-frame decaying-sine shake on Camera2D.offset (the boss-death shake's precedent).
func _play_shake() -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	_kill_tween(_shake_tween)
	_shake_tween = create_tween()
	for i in range(SHAKE_FRAMES):
		var decay: float = 1.0 - float(i) / float(SHAKE_FRAMES)
		var offset := Vector2(sin(float(i) * PI * 0.9) * SHAKE_MAGNITUDE * decay, 0.0)
		_shake_tween.tween_property(_camera, "offset", offset, FRAME_SECONDS)
	_shake_tween.tween_property(_camera, "offset", Vector2.ZERO, FRAME_SECONDS)


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
```

Note for the implementer: `sin(float(i) * PI * 0.9)` for i=0 is 0 (no offset on the first step) which is intended; if the test's "offset non-zero at some point" sample proves flaky, sample after each of the first three frames.

- [ ] **Step 4: Run** `hero_feedback_damage_test.gd` — PASS.
- [ ] **Step 5: Commit + push** `hero_feedback.gd`, its test (and `.uid` files), message `Add HeroFeedback: damage flash, directional particles, flinch, big-hit shake`.

---

### Task 6: Low-HP vignette + screen shader

**Files:**
- Create: `src/shaders/hero_screen_fx.gdshader`
- Modify: `src/core/visual_presentation/hero_feedback.gd`
- Test: `tests/unit/visual_presentation/hero_feedback_vignette_test.gd`

**Interfaces:**
- Consumes: Task 5 constants/`is_low_hp`.
- Produces on `HeroFeedback`: `func is_low_hp_active() -> bool`, `func get_vignette_strength() -> float`, `func get_vignette_fade() -> float`, `func advance(delta: float) -> void` (the body of `_process`, callable from tests), `static func vignette_strength(t: float, reduce: bool) -> float`, `func get_screen_fx_material() -> ShaderMaterial`.

- [ ] **Step 1: Write failing tests:** `is_low_hp(19.9, 100)` true, `(20.0, 100)` false, `(0.0, 100)` false, max 0 false; `_on_health_changed(15, 100)` → `is_low_hp_active()` true and, after `advance(0.3)`, `get_vignette_fade()` ≈ 1; healed `_on_health_changed(60, 100)` → after `advance(0.3)` fade ≈ 0 and the screen rect hidden; `vignette_strength(0.0, false)` is between `VIGNETTE_MIN` and `VIGNETTE_MAX` and `vignette_strength(x, false)` repeats with period 1.5 (`t` and `t + 1.5` equal within tolerance); `vignette_strength(0.4, true)` is the steady 0.55 for any `t`; the sprite `modulate` equals `LOW_HP_SPRITE_TINT` while low and `Color.WHITE` after healing; at full health the screen-fx material's `vignette_strength` parameter is 0.

- [ ] **Step 2: Run** — FAIL.

- [ ] **Step 3: Implement.**

`src/shaders/hero_screen_fx.gdshader`:

```glsl
shader_type canvas_item;

// Wind-up presentation spec §5.2/§5.3: one full-screen pass for the low-HP dark-red vignette and
// the death desaturation. Both uniforms at 0 is the identity (the rect is hidden in that state).
uniform sampler2D screen_tex : hint_screen_texture, filtering_linear, repeat_disable;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.0;
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float inset : hint_range(0.01, 0.5) = 0.15;

void fragment() {
	vec4 base = textureLod(screen_tex, SCREEN_UV, 0.0);
	float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(base.rgb, vec3(lum), desaturate);
	vec2 d = min(UV, 1.0 - UV);
	float edge = 1.0 - smoothstep(0.0, inset, min(d.x, d.y));
	col = mix(col, vec3(0.45, 0.02, 0.02), edge * vignette_strength);
	COLOR = vec4(col, 1.0);
}
```

`hero_feedback.gd` additions: state `_layer: CanvasLayer`, `_screen_rect: ColorRect`, `_screen_material: ShaderMaterial`, `_low_hp: bool`, `_vignette_fade: float`, `_pulse_time: float`, and `var _dead: bool = false` (declared here because `advance()` and `_on_health_changed` read it; Task 7 sets it and must NOT redeclare it). Build them in `_ready()` (after the connects):

```gdscript
	_layer = CanvasLayer.new()
	_layer.layer = FEEDBACK_LAYER
	add_child(_layer)
	_screen_rect = ColorRect.new()
	_screen_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_material = ShaderMaterial.new()
	_screen_material.shader = preload("res://src/shaders/hero_screen_fx.gdshader")
	_screen_rect.material = _screen_material
	_screen_rect.visible = false
	_layer.add_child(_screen_rect)
```

```gdscript
## Pulsing 0.4..0.7 opacity on a 1.5 s sine; a steady midpoint under reduced motion.
static func vignette_strength(t: float, reduce: bool) -> float:
	if reduce:
		return (VIGNETTE_MIN + VIGNETTE_MAX) * 0.5 + 0.0  # 0.55
	var s: float = 0.5 + 0.5 * sin(TAU * t / VIGNETTE_PERIOD)
	return lerpf(VIGNETTE_MIN, VIGNETTE_MAX, s)


func is_low_hp_active() -> bool:
	return _low_hp


func get_vignette_fade() -> float:
	return _vignette_fade


func get_vignette_strength() -> float:
	return float(_screen_material.get_shader_parameter("vignette_strength"))


func get_screen_fx_material() -> ShaderMaterial:
	return _screen_material


func _process(delta: float) -> void:
	advance(delta)


## Advances the vignette pulse and fade. The body of _process so tests can drive time directly.
func advance(delta: float) -> void:
	if _dead:
		return  # Task 7: the vignette freezes at maximum opacity on death
	var target: float = 1.0 if _low_hp else 0.0
	_vignette_fade = move_toward(_vignette_fade, target, delta / VIGNETTE_FADE_SECONDS)
	_pulse_time += delta
	_apply_screen_fx(vignette_strength(_pulse_time, ReduceMotion.enabled()) * _vignette_fade, 0.0)


func _apply_screen_fx(vignette: float, desaturate: float) -> void:
	_screen_material.set_shader_parameter("vignette_strength", vignette)
	_screen_material.set_shader_parameter("desaturate", desaturate)
	_screen_rect.visible = vignette > 0.001 or desaturate > 0.001
```

Simplify the reduced-motion line to `return (VIGNETTE_MIN + VIGNETTE_MAX) * 0.5`. Extend `_on_health_changed`:

```gdscript
func _on_health_changed(current: float, max_hp: float) -> void:
	_max_hp = max_hp
	_low_hp = is_low_hp(current, max_hp)
	if _sprite != null and not _dead:
		_sprite.modulate = _resting_sprite_modulate()
```
and change `_resting_sprite_modulate()` to `return LOW_HP_SPRITE_TINT if _low_hp else Color.WHITE`. In `_exit_tree` nothing extra (children freed with the node).

- [ ] **Step 4: Run** the vignette test and `hero_feedback_damage_test.gd` — PASS.
- [ ] **Step 5: Commit + push** the shader, script, test, message `Add low-HP vignette and screen effect shader to HeroFeedback`.

---

### Task 7: Death sequence + `SceneManager` death hold

**Files:**
- Modify: `src/core/visual_presentation/hero_feedback.gd`, `src/core/scene_manager.gd`
- Modify (test hygiene): `tests/unit/scene_manager/scene_manager_test.gd`, `tests/integration/foundation/scene_manager_transition_test.gd`, and any other test that emits `hero_died` expecting an immediate transition (`grep -rn "hero_died" tests | grep -i "scene"`); set `GSceneManager._death_hold_seconds = 0.0` in their `before_test` and restore in `after_test`.
- Test: `tests/unit/visual_presentation/hero_feedback_death_test.gd` (new), `tests/unit/scene_manager/scene_manager_death_hold_test.gd` (new)

**Interfaces:**
- Produces on `SceneManager`: `const HERO_DEATH_HOLD_SECONDS: float = 1.5`, `var _death_hold_seconds: float = HERO_DEATH_HOLD_SECONDS` (injectable), `var _death_exit_timer: SceneTreeTimer`, `func is_death_exit_pending() -> bool`.
- Produces on `HeroFeedback`: `func is_dead() -> bool`; handles `hero_died` and `wave_started` (reset).

- [ ] **Step 1: Write failing tests.**

`scene_manager_death_hold_test.gd` (same real-autoload injection pattern as `scene_manager_test.gd`; stub scene paths; `_death_hold_seconds = 0.2`; watch `scene_transition_started`):

```gdscript
func test_hero_died_does_not_transition_immediately_but_does_after_the_hold() -> void:
	GEventBus.hero_died.emit()
	assert_int(_spy.count("scene_transition_started")).is_equal(0)
	assert_bool(GSceneManager.is_death_exit_pending()).is_true()
	await get_tree().create_timer(0.35).timeout
	assert_int(_spy.count("scene_transition_started")).is_equal(1)
	assert_bool(GSceneManager.is_death_exit_pending()).is_false()


func test_a_second_hero_died_during_the_hold_does_not_stack_a_second_transition() -> void:
	GEventBus.hero_died.emit()
	GEventBus.hero_died.emit()
	await get_tree().create_timer(0.35).timeout
	assert_int(_spy.count("scene_transition_started")).is_equal(1)


func test_a_retry_phase_change_during_the_hold_cancels_the_exit() -> void:
	GEventBus.hero_died.emit()
	GEventBus.mission_phase_changed.emit("DEFEAT", "COUNTDOWN", 0.0)
	assert_bool(GSceneManager.is_death_exit_pending()).is_false()
	await get_tree().create_timer(0.35).timeout
	assert_int(_spy.count("scene_transition_started")).is_equal(0)


func test_the_defeat_phase_change_does_not_cancel_the_hold() -> void:
	GEventBus.hero_died.emit()
	GEventBus.mission_phase_changed.emit("WAVE", "DEFEAT", 0.0)
	assert_bool(GSceneManager.is_death_exit_pending()).is_true()


func test_mission_complete_during_the_hold_transitions_once_and_cancels_the_pending_exit() -> void:
	GEventBus.hero_died.emit()
	GEventBus.mission_phase_changed.emit("WAVE", "MISSION_COMPLETE", 0.0)
	await get_tree().create_timer(0.35).timeout
	assert_int(_spy.count("scene_transition_started")).is_equal(1)


func test_hero_died_while_a_transition_is_in_flight_starts_no_hold() -> void:
	GSceneManager._transition_in_progress = true
	GEventBus.hero_died.emit()
	assert_bool(GSceneManager.is_death_exit_pending()).is_false()


func test_zero_hold_transitions_immediately() -> void:
	GSceneManager._death_hold_seconds = 0.0
	GEventBus.hero_died.emit()
	assert_int(_spy.count("scene_transition_started")).is_equal(1)
```
(`after_test` must await any in-flight transition and reset `_transition_in_progress`, as in the existing suite.)

`hero_feedback_death_test.gd` (same fixture as Task 5):

```gdscript
func _rings() -> Array:
	# The ring is the only bare Node2D sibling of the Hero (the inner class _DeathRing reports "Node2D").
	return _hero_parent.get_children().filter(func(n: Node) -> bool: return n.get_class() == "Node2D" and n != _hero)


func test_hero_died_marks_dead_and_fades_the_sprite_to_30_percent() -> void:
	GEventBus.hero_died.emit()
	assert_bool(_fb.is_dead()).is_true()
	await get_tree().create_timer(0.45).timeout
	assert_float(_sprite.modulate.a).is_equal_approx(0.3, 0.02)


func test_death_desaturates_the_screen_and_freezes_the_vignette_at_maximum() -> void:
	GEventBus.hero_died.emit()
	await get_tree().create_timer(0.7).timeout
	var mat: ShaderMaterial = _fb.get_screen_fx_material()
	assert_float(float(mat.get_shader_parameter("desaturate"))).is_equal_approx(HeroFeedback.DEATH_DESATURATE, 0.01)
	assert_float(_fb.get_vignette_strength()).is_equal_approx(HeroFeedback.VIGNETTE_MAX, 0.001)
	_fb.advance(1.0)  # frozen: time passing changes nothing
	assert_float(_fb.get_vignette_strength()).is_equal_approx(HeroFeedback.VIGNETTE_MAX, 0.001)


func test_death_spawns_one_shockwave_ring_that_frees_itself() -> void:
	GEventBus.hero_died.emit()
	GEventBus.hero_died.emit()  # idempotent
	assert_int(_rings().size()).is_equal(1)
	await get_tree().create_timer(0.4).timeout
	assert_int(_rings().size()).is_equal(0)


func test_death_skips_the_ring_under_reduced_motion() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, true)
	GEventBus.hero_died.emit()
	assert_int(_rings().size()).is_equal(0)


func test_a_new_wave_clears_the_death_state() -> void:
	GEventBus.hero_died.emit()
	await get_tree().create_timer(0.45).timeout
	GEventBus.wave_started.emit(1, 5, 1.0)
	assert_bool(_fb.is_dead()).is_false()
	assert_float(_sprite.modulate.a).is_equal(1.0)
	assert_float(float(_fb.get_screen_fx_material().get_shader_parameter("desaturate"))).is_equal(0.0)
```

- [ ] **Step 2: Run** — FAIL.

- [ ] **Step 3: Implement `scene_manager.gd`:**

```gdscript
## Wind-up presentation spec §5.4: how long the mission stays up after the Hero dies so the death
## sequence can play before returning to the Sanctuary. Injectable (tests set 0).
const HERO_DEATH_HOLD_SECONDS: float = 1.5
var _death_hold_seconds: float = HERO_DEATH_HOLD_SECONDS
var _death_exit_timer: SceneTreeTimer = null
```

```gdscript
func is_death_exit_pending() -> bool:
	return _death_exit_timer != null


func _on_hero_died() -> void:
	if _transition_in_progress or _death_exit_timer != null:
		return
	if _death_hold_seconds <= 0.0:
		transition_to_sanctuary()
		return
	_death_exit_timer = get_tree().create_timer(_death_hold_seconds)
	_death_exit_timer.timeout.connect(_on_death_hold_elapsed)


func _on_death_hold_elapsed() -> void:
	_death_exit_timer = null
	transition_to_sanctuary()


## SceneTreeTimers cannot be cancelled, so cancelling disconnects the callback and drops the reference.
func _cancel_death_hold() -> void:
	if _death_exit_timer == null:
		return
	if _death_exit_timer.timeout.is_connected(_on_death_hold_elapsed):
		_death_exit_timer.timeout.disconnect(_on_death_hold_elapsed)
	_death_exit_timer = null
```

In `_do_transition`, first line: `_cancel_death_hold()` (before the in-progress guard is fine: any transition supersedes a pending death exit). In `_on_mission_phase_changed`, add before the MISSION_COMPLETE check:

```gdscript
	# A Retry reuses the scene and never calls _do_transition: its phase change out of DEFEAT is
	# what cancels a pending death exit (wind-up presentation spec §5.4, edge case 1).
	if new_phase != "DEFEAT" and new_phase != "MISSION_COMPLETE":
		_cancel_death_hold()
```
In `_exit_tree` call `_cancel_death_hold()` first.

`hero_feedback.gd` additions: connect `GEventBus.hero_died` → `_on_hero_died` and `GEventBus.wave_started` → `_on_wave_started` in `_ready`; disconnect in `_exit_tree` with `is_connected` guards.

```gdscript
var _death_tween: Tween = null  ## `_dead` is declared in Task 6


func is_dead() -> bool:
	return _dead


func _on_hero_died() -> void:
	if _dead:
		return
	_dead = true
	_kill_tween(_flash_tween)
	_kill_tween(_flinch_tween)
	_kill_tween(_shake_tween)
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = Vector2.ZERO
	# The vignette freezes at maximum opacity; desaturation eases in over 0.5 s.
	_apply_screen_fx(VIGNETTE_MAX, 0.0)
	_death_tween = create_tween()
	_death_tween.tween_method(func(v: float) -> void: _apply_screen_fx(VIGNETTE_MAX, v), 0.0, DEATH_DESATURATE, 0.5)
	if _sprite != null:
		_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if _flash_material != null:
			_flash_material.set_shader_parameter("flash_amount", 1.0)
		var flash_time: float = float(DEATH_FLASH_FRAMES) * FRAME_SECONDS
		var fade_time: float = float(DEATH_FADE_FRAMES) * FRAME_SECONDS
		_death_tween.parallel().tween_interval(flash_time)
		var sprite_tween := create_tween()
		sprite_tween.tween_interval(flash_time)
		sprite_tween.tween_callback(func() -> void:
				if _flash_material != null:
					_flash_material.set_shader_parameter("flash_amount", 0.0))
		sprite_tween.tween_property(_sprite, "modulate:a", 0.3, fade_time)
		_flash_tween = sprite_tween  # killed on reset / exit
	if not ReduceMotion.enabled():
		_spawn_death_ring()


func _spawn_death_ring() -> void:
	var parent: Node = _hero.get_parent() if _hero != null else null
	if parent == null:
		return
	var ring := _DeathRing.new()
	ring.radius_target = DEATH_RING_RADIUS
	parent.add_child(ring)
	ring.global_position = _hero.global_position
	var t := ring.create_tween()
	t.tween_property(ring, "progress", 1.0, float(DEATH_RING_FRAMES) * FRAME_SECONDS)
	t.tween_callback(ring.queue_free)


## A new wave (Retry reuses the scene and Hero) clears the death state.
func _on_wave_started(_wave_number: int, _total_waves: int, _wave_difficulty: float) -> void:
	_dead = false
	_low_hp = false
	_vignette_fade = 0.0
	_kill_tween(_death_tween)
	_kill_tween(_flash_tween)
	if _sprite != null:
		_sprite.modulate = Color.WHITE
	if _flash_material != null:
		_flash_material.set_shader_parameter("flash_amount", 0.0)
	_apply_screen_fx(0.0, 0.0)
```

Inner class (end of file):

```gdscript
## Expanding shockwave ring for the death sequence (hero.md: 2x cell_size over 16 frames).
class _DeathRing extends Node2D:
	var progress: float = 0.0:
		set(value):
			progress = value
			queue_redraw()
	var radius_target: float = 128.0

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius_target * progress, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 1.0 - progress), 3.0)
```

- [ ] **Step 4: Run** `hero_feedback_death_test.gd`, `scene_manager_death_hold_test.gd`, `hero_feedback_damage_test.gd`, `hero_feedback_vignette_test.gd`, `scene_manager_test.gd`, `scene_manager_transition_test.gd`, and any other scene-manager-touching suite found by the grep — PASS (fix pre-existing tests by injecting `_death_hold_seconds = 0.0` per the Files note).
- [ ] **Step 5: Commit + push** `hero_feedback.gd`, `scene_manager.gd`, the new and updated tests, message `Add Hero death sequence and 1.5s SceneManager death hold`.

---

### Task 8: Scene wiring + documentation

**Files:**
- Modify: `src/scenes/mission_scene.gd`, `src/gameplay/missions/the_gap/the_gap.gd`
- Test: `tests/integration/hero/hero_feedback_wiring_test.gd` (new)
- Docs: `docs/superpowers/specs/2026-09-26-windup-presentation-design.md`, `docs/superpowers/specs/2026-09-25-hero-damage-design.md` (§10), `design/gdd/hero.md`, `design/gdd/monster.md`, `design/gdd/event-bus.md`, `docs/architecture/adr-0001-eventbus-architecture.md`, `design/accessibility-requirements.md`, `production/session-state/active.md`

**Interfaces:**
- Consumes: Tasks 2/5.

- [ ] **Step 1: Write failing wiring test** (mirror `tests/integration/hero/hero_damage_chain_test.gd`'s scene-boot approach): boot `the_gap.tscn`, assert a `HeroFeedback` node exists, is the child named `HeroFeedback`, and its provider resolves a spawned monster's position (`get_monster_world_position` path); repeat for `MissionScene.tscn` under `GameplayRoot`. Emit `hero_health_changed(10.0, 100.0)` and assert the feedback's `is_low_hp_active()` is true in each scene.

- [ ] **Step 2: Run** — FAIL.

- [ ] **Step 3: Implement.** `mission_scene.gd`, right after the `DamageStatus.set_hero_stats(_hero)` line (~155):

```gdscript
	# Wind-up presentation spec §3: Hero-side combat feedback (flash, vignette, death sequence).
	var hero_feedback := HeroFeedback.new()
	hero_feedback.name = "HeroFeedback"
	hero_feedback.setup(_hero, _camera, _monster_manager.get_monster_world_position)
	_gameplay_root.add_child(hero_feedback)
```
`the_gap.gd`, after its `set_hero_stats` line (~150) the same block with `add_child(hero_feedback)` and the_gap's camera reference (read the file for the Camera2D member name; it has one because it re-asserts `current=true`). Confirm `_camera`/camera field names by reading each file; do not guess.

- [ ] **Step 4: Documentation.**
  - Spec `2026-09-26-windup-presentation-design.md`: status → "Approved; implemented" once done; apply the five Rulings above (ReduceMotion path; direct resolve call; sprite modulate tint instead of shader uniform; heartbeat + 40% duck deferred with reasons; SceneManager cancel-on-phase-change).
  - Hero-damage spec §10: point to this spec as specified and implemented; note the boss hint landed.
  - `hero.md`: Event Feedback rows for damage/low-HP/death marked implemented; note `ReduceMotion`.
  - `monster.md`: document `monster_hero_attack_resolved` and the telegraph presentation.
  - `event-bus.md`: add the `monster_hero_attack_resolved` row in the Monster System table (deferred; subscriber Audio) and update the count note 79 → 80; change the `monster_hero_attack_winding_up` subscriber text to Audio (+ presentation reads state directly).
  - ADR-0001 Rule 2 amendment: add `monster_hero_attack_resolved` alongside `monster_hero_attack_winding_up` as deferred.
  - `accessibility-requirements.md`: record `ReduceMotion` and what honors it.
  - `active.md`: add extract "part 28" for this feature — NOT live-verified; a live checklist: elite pulse/outline/bar visible and outline is a 5x5 square around the attacker's cell; dodge shows the grey fade and whiff cue; hit shows the red flash; damage flash/particles/flinch; big-hit shake; <20% vignette pulses and is visible with sound off; wave-clear heal fades it; death holds ~1.5 s then Sanctuary; Retry during the hold stays in the mission; boss wind-up on the Hero plays the boss prepare overlay only under the 3D path (2D path shows the new telegraph); `FEEDBACK_LAYER = 0` layer ordering versus the HUD and world (vignette must sit over the world and under the HUD; if not, adjust the constant).
- [ ] **Step 5: Run** `hero_feedback_wiring_test.gd`, `hero_damage_chain_test.gd`, plus the existing mission-scene/the_gap suites that boot those scenes (`grep -rln "the_gap.tscn\|MissionScene.tscn" tests`) — PASS.
- [ ] **Step 6: Commit + push** all files above, message `Wire HeroFeedback into both mission scenes; document the wind-up presentation`.

---

## Self-review

**Spec coverage:** §4.1 telegraph (T3), §4.2 resolve (T2 signal, T3 visual), §4.3 boss hint (T2) and 3D parity note (spec only), §5.1 damage feedback (T5), §5.2 vignette (T6), §5.3 death sequence (T7), §5.4 hold + edge cases 1-4 (T7: phase-cancel, double `hero_died`, `MISSION_COMPLETE`, injectable hold), §6 reduced motion (T1, honored in T3/T5/T6/T7), §7 audio (T4; heartbeat and duck deferred by Ruling 4), §8 accessibility (constants + tests), §9 parity (spec only), §10 docs (T8), §11 tests (per task), §12 phasing (T1-T4 = phase 1, T5-T6 = phase 2, T7 = phase 3).

**Placeholders:** none; every test body is written out.

**Type consistency:** `set_windup_telegraph(progress, range_cells, center_offset, delta)` (T3) matches the manager call; `play_windup_resolved(hit)` matches; `get_monster_world_position` (T2) matches the provider passed in T8; `is_low_hp`/constants declared in T5 are consumed in T6/T7; `_dead` is declared once, in T6 (T7 must not redeclare it).
