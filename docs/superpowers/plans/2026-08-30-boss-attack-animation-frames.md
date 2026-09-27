# Boss Attack Animation Frames Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `BossCreaturePresenter3D` real per-frame animation playback (idle/walk on the base layer, attack_prepare/attack on the overlay layer), driven by `CreatureAtlasMappingResource`/`CreatureAnimationClip` data, instead of the current static single-texture + visibility-toggle-only behavior.

**Architecture:** `BossCreaturePresenter3D.register_boss()` looks up the boss's `CreatureAtlasMappingResource` via `GGameDataRegistry.get_creature_atlas_mapping()`. When a mapping exists with `idle`/`walk` clips, both `Sprite3D` layers get the atlas texture with `hframes`/`vframes` set, and per-slot animation state (current clip, elapsed time, overlay state machine) is tracked in new parallel arrays. `update_boss()` gains a `delta: float` parameter (available for free at its one real call site, `MonsterManager._pass3c_visual_sync()`, which already has `delta` in scope) and uses it to advance frames each tick. When no mapping is found (or it lacks `attack_prepare`/`attack` clips), the presenter falls back to the pre-existing static-texture/visibility-toggle behavior — this is a real, honestly-flagged content gap for any future tier-2 boss without full art, not a bug.

**Tech Stack:** Godot 4.6.2, GDScript, `Sprite3D.hframes`/`vframes`/`frame` for atlas-cell selection (built-in, no `AnimatedSprite3D` needed since region selection here is driven by explicit index, not autoplay), gdUnit4 for tests.

**Spec:** `design/gdd/monster.md`'s "BOSS Scene Structure — Two-Layer AnimatedSprite2D" section (walk continues uninterrupted on the base layer; `attack_prepare` telegraphs on the overlay layer; the strike itself plays as `attack`), and ADR-0038 (`docs/architecture/` — ADR-0038 defines the exceptional/individual-presenter path this presenter implements, including "no independent process callback": all state advances only when `update_boss()` is called by `MonsterManager`, never via `_process()`/`_physics_process()` on this node).

## Global Constraints

- `BossCreaturePresenter3D` must have NO `_process()`/`_physics_process()` override — every animation-time advance happens inside `update_boss()`, called once per `MonsterManager._physics_process()` tick with that tick's `delta`. This is an explicit ADR-0038 requirement, not a style choice.
- Backward compatibility: any boss `monster_id` with no `CreatureAtlasMappingResource`, or one missing `idle`/`walk`/`attack_prepare`/`attack` clips, must fall back to exactly the current behavior (static `MonsterInstance.MONSTER_TEXTURES` texture on both layers, `overlay.visible = attack_telegraphed` with no frame animation). Never push_error or reject registration for a creature missing only the attack clips — only `idle`/`walk` are required to enable ANY animation; `attack_prepare`/`attack` are independently optional (a boss could have a walk cycle but no attack telegraph art yet).
- `update_boss()`'s new `delta` parameter must default to `0.0` — three existing tests call it with the old 3-argument signature and must keep passing unmodified (frame progression legitimately no-ops at `delta=0.0`, which does not affect any visibility assertion those tests make).
- The ATTACK state, once entered, always plays to completion uninterrupted before any new PREPARE state can begin, even if `attack_telegraphed` flips back to `true` mid-ATTACK. This is a deliberate ruling (no gameplay signal currently models "attack landed" separately from "prepare ended" — the strike's own visual duration is treated as authoritative) — record it in code as a comment, not just here.
- Frame indices are always `clip.start_frame + <offset within clip>`, decoded row-major exactly as `creature_swarm_body.gdshader` and `CreatureAnimationClip`'s own doc comment already specify (this presenter uses `Sprite3D.frame` directly, which Godot itself decodes row-major from `hframes`/`vframes` — no custom UV math needed).
- Two boss creatures already have complete 14-frame animsets ready to use: `goblin_warlord_boss` and `rift_sentinel_boss`, both at `assets/data/creature_atlases/<id>.tres` — `atlas_columns=14, atlas_rows=1`, clips `idle(0,1)`, `walk(1,4)`, `attack_prepare(5,4)`, `attack(9,5)`. These are the only two tier-2 (BOSS) creatures in the project today (`MonsterManager` routes `tier == 2` to this presenter).

---

### Task 1: Add per-slot animation state and mapping-aware texture setup to `register_boss()`

**Files:**
- Modify: `src/core/visual_presentation/boss_creature_presenter_3d.gd`
- Test: `tests/integration/visual_presentation/boss_creature_presenter_test.gd`

**Interfaces:**
- Consumes: `GGameDataRegistry.get_creature_atlas_mapping(monster_id: StringName) -> CreatureAtlasMappingResource` (already exists, `src/core/game_data_registry.gd:482`). `CreatureAtlasMappingResource.get_animation_clip(clip_name: StringName) -> CreatureAnimationClip` (already exists). `CreatureAnimationClip` fields: `start_frame: int`, `frame_count: int`, `fps: float`, `loop: bool` (already exist).
- Produces: five new parallel arrays on `BossCreaturePresenter3D`, indexed by the same `slot: int` as `_slots`/`_base_layers`/`_overlay_layers`:
  - `var _base_clips: Array[CreatureAnimationClip] = []` — the slot's `walk` clip, or `null` in legacy/fallback mode.
  - `var _base_elapsed: Array[float] = []` — seconds accumulated within the current base clip loop.
  - `var _overlay_prepare_clips: Array[CreatureAnimationClip] = []` — the slot's `attack_prepare` clip, or `null`.
  - `var _overlay_attack_clips: Array[CreatureAnimationClip] = []` — the slot's `attack` clip, or `null`.
  - `var _overlay_states: Array[int] = []` — one of the three new constants below.
  - `var _overlay_elapsed: Array[float] = []` — seconds accumulated within the current overlay state.
  Also produces three new constants: `const OVERLAY_STATE_HIDDEN: int = 0`, `const OVERLAY_STATE_PREPARE: int = 1`, `const OVERLAY_STATE_ATTACK: int = 2`.

- [ ] **Step 1: Add the new constants and parallel arrays**

At the top of `boss_creature_presenter_3d.gd`, alongside the existing `CAPACITY`/`POOL_BATCH_KEY` constants, add:

```gdscript
const OVERLAY_STATE_HIDDEN: int = 0
const OVERLAY_STATE_PREPARE: int = 1
const OVERLAY_STATE_ATTACK: int = 2
```

Alongside the existing `_slots`/`_base_layers`/`_overlay_layers` array declarations, add:

```gdscript
var _base_clips: Array[CreatureAnimationClip] = []
var _base_elapsed: Array[float] = []
var _overlay_prepare_clips: Array[CreatureAnimationClip] = []
var _overlay_attack_clips: Array[CreatureAnimationClip] = []
var _overlay_states: Array[int] = []
var _overlay_elapsed: Array[float] = []
```

In `_ready()`'s `for i in range(CAPACITY):` loop, after `_overlay_layers.append(overlay)`, append one default entry per slot to each new array:

```gdscript
_base_clips.append(null)
_base_elapsed.append(0.0)
_overlay_prepare_clips.append(null)
_overlay_attack_clips.append(null)
_overlay_states.append(OVERLAY_STATE_HIDDEN)
_overlay_elapsed.append(0.0)
```

- [ ] **Step 2: Write the failing tests for mapping-aware setup**

Add to `tests/integration/visual_presentation/boss_creature_presenter_test.gd`, in the "Direct pool tests" section:

```gdscript
func test_register_boss_with_full_animset_sets_hframes_and_base_clip() -> void:
	var handle: MonsterPresentationHandle = _renderer.register_boss(1, &"goblin_warlord_boss", Transform3D.IDENTITY)
	var slot: int = _renderer._boss_presenter._entity_to_slot[handle.entity_id]

	assert_int(_renderer._boss_presenter._base_layers[slot].hframes).is_equal(14)
	assert_int(_renderer._boss_presenter._overlay_layers[slot].hframes).is_equal(14)
	assert_object(_renderer._boss_presenter._base_clips[slot]).is_not_null()
	assert_str(_renderer._boss_presenter._base_clips[slot].clip_name).is_equal("walk")
	assert_object(_renderer._boss_presenter._overlay_prepare_clips[slot]).is_not_null()
	assert_object(_renderer._boss_presenter._overlay_attack_clips[slot]).is_not_null()
```

Note: every monster_id currently in `MonsterInstance.MONSTER_TEXTURES` (the 7 STANDARD/ELITE/BOSS creatures processed earlier this session) now also has a full `CreatureAtlasMappingResource` with `idle`+`walk` clips, so there is no real content today that exercises "in `MONSTER_TEXTURES` but with zero mapping at all" — that branch is exercised only by `iron_colossus_elite` (which has a mapping, just no attack clips — covered in Task 3's `test_overlay_falls_back_to_plain_toggle_without_attack_clips`) and by the pre-existing `test_register_boss_unmapped_monster_id_rejected` (a genuinely nonexistent id, proving `has_full_animset=false` combined with a failed `MONSTER_TEXTURES` lookup correctly rejects registration). Do not invent a third redundant test for a code path real content can't currently reach.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `gdunit4-runner --test-suite tests/integration/visual_presentation/boss_creature_presenter_test.gd` (or the project's configured gdUnit4 run command — check `tests/README.md` or `.claude/docs/coding-standards.md` if the exact invocation is unclear).
Expected: FAIL — `hframes` is never set today (stays Godot's default of `1`), and `_base_clips` doesn't exist yet.

- [ ] **Step 4: Implement mapping-aware setup in `register_boss()`**

Replace the body of `register_boss()` from the `var texture: Texture2D = ...` line through `_overlay_layers[slot].visible = false` with:

```gdscript
	var mapping: CreatureAtlasMappingResource = GGameDataRegistry.get_creature_atlas_mapping(monster_id)
	var idle_clip: CreatureAnimationClip = mapping.get_animation_clip(&"idle") if mapping != null else null
	var walk_clip: CreatureAnimationClip = mapping.get_animation_clip(&"walk") if mapping != null else null
	var has_full_animset: bool = mapping != null and idle_clip != null and walk_clip != null

	var texture: Texture2D = mapping.atlas_texture if has_full_animset else MonsterInstance.MONSTER_TEXTURES.get(monster_id, null) as Texture2D
	if texture == null:
		push_error("[BossCreaturePresenter3D] register_boss: no art authored for monster_id '%s' -- no boss presenter." % monster_id)
		return null

	var slot: int = _free_slots.pop_back()
	var generation: int = (_entity_to_generation.get(entity_id, 0) as int) + 1
	_entity_to_slot[entity_id] = slot
	_entity_to_generation[entity_id] = generation

	_base_layers[slot].texture = texture
	_overlay_layers[slot].texture = texture
	if has_full_animset:
		_base_layers[slot].hframes = mapping.atlas_columns
		_base_layers[slot].vframes = mapping.atlas_rows
		_base_layers[slot].frame = idle_clip.start_frame
		_overlay_layers[slot].hframes = mapping.atlas_columns
		_overlay_layers[slot].vframes = mapping.atlas_rows
		_base_clips[slot] = walk_clip
		_overlay_prepare_clips[slot] = mapping.get_animation_clip(&"attack_prepare")
		_overlay_attack_clips[slot] = mapping.get_animation_clip(&"attack")
	else:
		_base_layers[slot].hframes = 1
		_base_layers[slot].vframes = 1
		_base_clips[slot] = null
		_overlay_prepare_clips[slot] = null
		_overlay_attack_clips[slot] = null
	_base_elapsed[slot] = 0.0
	_overlay_states[slot] = OVERLAY_STATE_HIDDEN
	_overlay_elapsed[slot] = 0.0
	_overlay_layers[slot].visible = false
```

Add `CreatureAtlasMappingResource` and `CreatureAnimationClip` to the class doc comment's "Real content gap, flagged not hidden" paragraph — update it to say the gap is now closed for `goblin_warlord_boss`/`rift_sentinel_boss` specifically, and remains open (falls back to static single-texture) for any other tier-2 boss without an authored `CreatureAtlasMappingResource`.

- [ ] **Step 5: Run tests to verify they pass**

Run the same command as Step 3.
Expected: PASS. Also re-run the full `boss_creature_presenter_test.gd` suite to confirm no existing test regressed (the fallback path must keep `test_register_boss_unmapped_monster_id_rejected` etc. passing exactly as before).

- [ ] **Step 6: Commit**

```bash
git add src/core/visual_presentation/boss_creature_presenter_3d.gd tests/integration/visual_presentation/boss_creature_presenter_test.gd
git commit -m "feat: mapping-aware atlas setup for BossCreaturePresenter3D"
```

---

### Task 2: Advance base-layer walk animation in `update_boss()`

**Files:**
- Modify: `src/core/visual_presentation/boss_creature_presenter_3d.gd`
- Modify: `src/core/visual_presentation/monster_swarm_renderer_3d.gd`
- Modify: `src/core/monster/monster_manager.gd`
- Test: `tests/integration/visual_presentation/boss_creature_presenter_test.gd`

**Interfaces:**
- Consumes: `_base_clips`/`_base_elapsed` arrays from Task 1.
- Produces: `update_boss(handle: MonsterPresentationHandle, world_transform: Transform3D, attack_telegraphed: bool, delta: float = 0.0) -> bool` — the new signature every later task and call site uses. The `MonsterSwarmRenderer3D.update_boss()` pass-through gains the same `delta: float = 0.0` parameter and forwards it unchanged.

- [ ] **Step 1: Write the failing test**

Add to `tests/integration/visual_presentation/boss_creature_presenter_test.gd`:

```gdscript
func test_update_boss_advances_base_walk_frame_over_time() -> void:
	var handle: MonsterPresentationHandle = _renderer.register_boss(1, &"goblin_warlord_boss", Transform3D.IDENTITY)
	var slot: int = _renderer._boss_presenter._entity_to_slot[handle.entity_id]
	# walk clip: start_frame=1, frame_count=4, fps=8.0 -> one full frame every 0.125s.
	var initial_frame: int = _renderer._boss_presenter._base_layers[slot].frame
	assert_int(initial_frame).is_equal(0)  # idle frame set at registration

	_renderer.update_boss(handle, Transform3D.IDENTITY, false, 0.2)

	var advanced_frame: int = _renderer._boss_presenter._base_layers[slot].frame
	assert_bool(advanced_frame >= 1 and advanced_frame <= 4).is_true()
```

- [ ] **Step 2: Run test to verify it fails**

Run: same gdUnit4 command as Task 1.
Expected: FAIL — `update_boss()` doesn't accept a 4th argument yet, and no frame advancement exists.

- [ ] **Step 3: Update `update_boss()` signatures and implement base-layer advancement**

In `boss_creature_presenter_3d.gd`, change the `update_boss()` signature and body to:

```gdscript
func update_boss(handle: MonsterPresentationHandle, world_transform: Transform3D, attack_telegraphed: bool, delta: float = 0.0) -> bool:
	var slot: int = _resolve_valid_slot(handle)
	if slot == -1:
		return false
	_slots[slot].global_transform = world_transform

	var walk_clip: CreatureAnimationClip = _base_clips[slot]
	if walk_clip != null and delta > 0.0:
		_base_elapsed[slot] += delta
		var frames_elapsed: int = int(_base_elapsed[slot] * walk_clip.fps)
		var offset_in_clip: int = frames_elapsed % walk_clip.frame_count
		_base_layers[slot].frame = walk_clip.start_frame + offset_in_clip

	_overlay_layers[slot].visible = attack_telegraphed
	return true
```

(This step deliberately keeps the OLD overlay-visibility line unchanged — Task 3 replaces it with the state machine. Keeping it here means this task's test passes in isolation without depending on Task 3's unwritten code.)

In `monster_swarm_renderer_3d.gd`, change:

```gdscript
func update_boss(handle: MonsterPresentationHandle, world_transform: Transform3D, attack_telegraphed: bool) -> bool:
	return _boss_presenter.update_boss(handle, world_transform, attack_telegraphed)
```

to:

```gdscript
func update_boss(handle: MonsterPresentationHandle, world_transform: Transform3D, attack_telegraphed: bool, delta: float = 0.0) -> bool:
	return _boss_presenter.update_boss(handle, world_transform, attack_telegraphed, delta)
```

In `monster_manager.gd`'s `_pass3c_visual_sync(delta: float)`, find the existing call (around line 609):

```gdscript
				_swarm_renderer.update_boss(entity.boss_presenter_handle, world_transform, entity.boss_attack_prepare_remaining > 0)
```

and change it to pass `delta` through (it is already a parameter of the enclosing function):

```gdscript
				_swarm_renderer.update_boss(entity.boss_presenter_handle, world_transform, entity.boss_attack_prepare_remaining > 0, delta)
```

- [ ] **Step 4: Run tests to verify they pass**

Run the same command. Expected: PASS, including every pre-existing test in this file and in `tests/unit/monster/monster_manager_test.gd` (search that file for `update_boss` or `boss_attack_prepare` to confirm none asserts the old 3-arg call signature in a way this breaks — a default-valued 4th parameter should not require any change to callers that don't pass it).

- [ ] **Step 5: Commit**

```bash
git add src/core/visual_presentation/boss_creature_presenter_3d.gd src/core/visual_presentation/monster_swarm_renderer_3d.gd src/core/monster/monster_manager.gd tests/integration/visual_presentation/boss_creature_presenter_test.gd
git commit -m "feat: thread delta through update_boss, animate base-layer walk frame"
```

---

### Task 3: Overlay attack_prepare/attack state machine

**Files:**
- Modify: `src/core/visual_presentation/boss_creature_presenter_3d.gd`
- Test: `tests/integration/visual_presentation/boss_creature_presenter_test.gd`

**Interfaces:**
- Consumes: `_overlay_prepare_clips`/`_overlay_attack_clips`/`_overlay_states`/`_overlay_elapsed` from Task 1, the `delta`-carrying `update_boss()` from Task 2.
- Produces: the overlay now animates through `HIDDEN -> PREPARE -> ATTACK -> HIDDEN`, replacing the plain `_overlay_layers[slot].visible = attack_telegraphed` line from Task 2.

- [ ] **Step 1: Write the failing tests**

Add to `tests/integration/visual_presentation/boss_creature_presenter_test.gd`:

```gdscript
func test_overlay_state_machine_prepare_then_attack_then_hides() -> void:
	var handle: MonsterPresentationHandle = _renderer.register_boss(1, &"goblin_warlord_boss", Transform3D.IDENTITY)
	var slot: int = _renderer._boss_presenter._entity_to_slot[handle.entity_id]
	const HIDDEN := 0
	const PREPARE := 1
	const ATTACK := 2

	# Telegraph starts: HIDDEN -> PREPARE, overlay visible.
	_renderer.update_boss(handle, Transform3D.IDENTITY, true, 0.1)
	assert_int(_renderer._boss_presenter._overlay_states[slot]).is_equal(PREPARE)
	assert_bool(_renderer._boss_presenter._overlay_layers[slot].visible).is_true()

	# Telegraph ends (strike moment): PREPARE -> ATTACK, still visible.
	_renderer.update_boss(handle, Transform3D.IDENTITY, false, 0.05)
	assert_int(_renderer._boss_presenter._overlay_states[slot]).is_equal(ATTACK)
	assert_bool(_renderer._boss_presenter._overlay_layers[slot].visible).is_true()

	# attack clip: frame_count=5, fps=10.0 -> 0.5s total duration. Advance past it.
	_renderer.update_boss(handle, Transform3D.IDENTITY, false, 0.6)
	assert_int(_renderer._boss_presenter._overlay_states[slot]).is_equal(HIDDEN)
	assert_bool(_renderer._boss_presenter._overlay_layers[slot].visible).is_false()


func test_overlay_attack_uninterruptible_by_new_telegraph() -> void:
	var handle: MonsterPresentationHandle = _renderer.register_boss(1, &"goblin_warlord_boss", Transform3D.IDENTITY)
	var slot: int = _renderer._boss_presenter._entity_to_slot[handle.entity_id]
	const ATTACK := 2

	_renderer.update_boss(handle, Transform3D.IDENTITY, true, 0.1)   # -> PREPARE
	_renderer.update_boss(handle, Transform3D.IDENTITY, false, 0.05) # -> ATTACK
	# New telegraph arrives mid-ATTACK — must NOT interrupt back to PREPARE.
	_renderer.update_boss(handle, Transform3D.IDENTITY, true, 0.05)
	assert_int(_renderer._boss_presenter._overlay_states[slot]).is_equal(ATTACK)


func test_overlay_falls_back_to_plain_toggle_without_attack_clips() -> void:
	# iron_colossus_elite has no attack_prepare/attack clips authored (Task 1's
	# fallback contract) -- overlay must still toggle on/off exactly like the
	# pre-animation behavior, never get stuck in a state with no clip to play.
	var handle: MonsterPresentationHandle = _renderer.register_boss(1, &"iron_colossus_elite", Transform3D.IDENTITY)
	var slot: int = _renderer._boss_presenter._entity_to_slot[handle.entity_id]

	_renderer.update_boss(handle, Transform3D.IDENTITY, true, 0.1)
	assert_bool(_renderer._boss_presenter._overlay_layers[slot].visible).is_true()
	_renderer.update_boss(handle, Transform3D.IDENTITY, false, 0.1)
	assert_bool(_renderer._boss_presenter._overlay_layers[slot].visible).is_false()
```

- [ ] **Step 2: Run tests to verify they fail**

Run the same gdUnit4 command. Expected: FAIL — the overlay never leaves `OVERLAY_STATE_HIDDEN` today (Task 2 only wrote the plain visibility toggle).

- [ ] **Step 3: Implement the overlay state machine**

In `boss_creature_presenter_3d.gd`'s `update_boss()`, replace the trailing `_overlay_layers[slot].visible = attack_telegraphed` line with:

```gdscript
	var prepare_clip: CreatureAnimationClip = _overlay_prepare_clips[slot]
	var attack_clip: CreatureAnimationClip = _overlay_attack_clips[slot]
	if prepare_clip == null or attack_clip == null:
		# Fallback contract (Task 1): no attack-animation art authored for
		# this monster_id -- keep the original plain visibility toggle.
		_overlay_layers[slot].visible = attack_telegraphed
		return true

	match _overlay_states[slot]:
		OVERLAY_STATE_HIDDEN:
			if attack_telegraphed:
				_overlay_states[slot] = OVERLAY_STATE_PREPARE
				_overlay_elapsed[slot] = 0.0
				_overlay_layers[slot].visible = true
				_overlay_layers[slot].frame = prepare_clip.start_frame
		OVERLAY_STATE_PREPARE:
			if not attack_telegraphed:
				# Telegraph ended -- this is the strike moment. The ATTACK
				# state always plays to completion, uninterrupted, even if
				# attack_telegraphed flips true again before it finishes
				# (ruling: no gameplay signal distinguishes "attack landed"
				# from "prepare ended" today, so the strike's own visual
				# duration is authoritative).
				_overlay_states[slot] = OVERLAY_STATE_ATTACK
				_overlay_elapsed[slot] = 0.0
				_overlay_layers[slot].frame = attack_clip.start_frame
			else:
				_overlay_elapsed[slot] += delta
				var frames_elapsed: int = int(_overlay_elapsed[slot] * prepare_clip.fps)
				_overlay_layers[slot].frame = prepare_clip.start_frame + (frames_elapsed % prepare_clip.frame_count)
		OVERLAY_STATE_ATTACK:
			_overlay_elapsed[slot] += delta
			var duration: float = attack_clip.frame_count / attack_clip.fps
			if _overlay_elapsed[slot] >= duration:
				_overlay_states[slot] = OVERLAY_STATE_HIDDEN
				_overlay_layers[slot].visible = false
			else:
				var frames_elapsed: int = int(_overlay_elapsed[slot] * attack_clip.fps)
				var clamped_offset: int = mini(frames_elapsed, attack_clip.frame_count - 1)
				_overlay_layers[slot].frame = attack_clip.start_frame + clamped_offset

	return true
```

Also update `unregister_boss()` to reset overlay state on free, so a reused slot never inherits a stale mid-ATTACK state from its previous occupant — add these two lines right after `_overlay_layers[slot].visible = false` in `unregister_boss()`:

```gdscript
	_overlay_states[slot] = OVERLAY_STATE_HIDDEN
	_overlay_elapsed[slot] = 0.0
```

- [ ] **Step 4: Fix a pre-existing test whose expectation this task deliberately changes**

`test_boss_attack_prepare_shows_overlay_via_physics_process` (in the "Full MonsterManager integration" section of the same file) currently asserts the overlay goes invisible the instant `boss_attack_prepare_remaining` reaches `0`. That was correct for the old plain-toggle behavior, but `goblin_warlord_boss` now has real `attack_prepare`/`attack` clips — ending the telegraph now correctly enters `OVERLAY_STATE_ATTACK` (overlay stays VISIBLE through the strike animation, then hides once the attack clip's duration elapses). This is an intentional behavior change from this task, not a regression — update the test's final assertion:

```gdscript
	entity.boss_attack_prepare_remaining = 0
	_mm._physics_process(DELTA)
	# Ending the telegraph enters the ATTACK state (goblin_warlord_boss now has
	# real attack-strike frames) -- the overlay stays visible through the
	# strike, it does not hide instantly. Confirm the strike eventually ends
	# by ticking enough additional frames to exceed the attack clip's
	# duration (frame_count=5, fps=10.0 -> 0.5s; DELTA=1/60 -> 30 ticks).
	assert_bool(_renderer._boss_presenter._overlay_layers[slot].visible).is_true()
	for i in range(30):
		_mm._physics_process(DELTA)
	assert_bool(_renderer._boss_presenter._overlay_layers[slot].visible).is_false()
```

- [ ] **Step 5: Run tests to verify they pass**

Run the same command. Expected: PASS — all three new tests, the updated pre-existing test above, plus every OTHER pre-existing test in the file (in particular `test_update_boss_toggles_overlay_visibility_with_attack_telegraph`, which exercises `goblin_warlord_boss` — a creature that NOW has attack clips, so trace through it by hand against the state machine above: it calls `update_boss(handle, moved, true)` with no delta, i.e. `delta=0.0` by default. `0.0 > 0.0` is false, so the base-layer walk-frame block in Task 2 no-ops, but the overlay state machine above does NOT gate on `delta > 0.0` — it still transitions `HIDDEN -> PREPARE` and sets `visible = true` purely from the boolean edge, independent of delta. Confirm this still makes that pre-existing test's two assertions — `overlay_layers[slot].visible` true then false — pass unchanged: its second call passes `moved, false` with no delta, which from `PREPARE` transitions straight to `ATTACK` and sets `visible = true`... **this second assertion (`is_false()`) will now FAIL** by the same reasoning as Step 4 above. Apply the identical fix to this test too: change its final assertion from `is_false()` to `is_true()` immediately after the transition, matching the corrected understanding that ending the telegraph enters ATTACK (still visible), not HIDDEN.).

- [ ] **Step 6: Commit**

```bash
git add src/core/visual_presentation/boss_creature_presenter_3d.gd tests/integration/visual_presentation/boss_creature_presenter_test.gd
git commit -m "feat: overlay attack_prepare/attack state machine for BossCreaturePresenter3D"
```

---

### Task 4: Update ADR-0038 / production status docs

**Files:**
- Modify: `production/art-overhaul-status.md`
- Modify (if it exists and references this gap): search for "attack_prepare" or "distinct walk/attack_prepare/attack ANIMATION content" across `docs/architecture/` and update any ADR-0038-adjacent doc that explicitly calls this out as an open gap.

**Interfaces:**
- Consumes: nothing (docs-only task).
- Produces: nothing (docs-only task).

- [ ] **Step 1: Find every doc reference to the now-closed gap**

Run: `grep -rn "distinct walk/attack_prepare/attack\|no multi-frame sprite sheet exists for any monster" docs/ production/ design/`

- [ ] **Step 2: Update each match found**

For each file found in Step 1, add a dated note (2026-08-30) that `goblin_warlord_boss` and `rift_sentinel_boss` now have real per-frame idle/walk/attack_prepare/attack animation via `BossCreaturePresenter3D`, and that the gap remains open only for any future tier-2 boss without an authored `CreatureAtlasMappingResource` covering those four clips. Do not delete the original gap-flagging language outright — historical accuracy matters more than tidiness here; append, don't rewrite.

Update the "Goblin Warlord + Rift Sentinel BOSS attack animations" row in `production/art-overhaul-status.md` (status currently `generated, awaiting processing`) to `done — processed, wired, real per-frame animation shipped`, describing: the combined 14-frame `<name>_animset.png` atlases built from the locomotion (idle+walk) art plus the validated `_v2` attack-prepare/attack sheets (dropping each attack sheet's redundant leading idle-reference frame), the `.tres` clip updates, and the new `BossCreaturePresenter3D` state machine that plays them.

- [ ] **Step 3: Commit**

```bash
git add production/art-overhaul-status.md
git commit -m "docs: record boss attack-animation gap closure"
```
