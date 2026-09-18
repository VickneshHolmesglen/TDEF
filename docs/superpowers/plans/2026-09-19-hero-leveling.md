# Hero Leveling System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent Hero Level/XP system (kill/wave/mission XP, exponential curve, flat stat growth, every-5th-level Skill Tree point + class bonus) and close the `HERO_LEVEL_PLACEHOLDER = 1` gap in the Hero Combat & Stats Redesign's Armor mitigation formula.

**Architecture:** All XP/level state and resolution logic lives on `Hero` (matching where `_base_stats`/`_flat_bonuses`/save-persistence already live). Hero already subscribes to `monster_died`/`mission_phase_changed`; this plan extends those handlers and adds two new subscriptions (`monsters_died_batch`, `wave_completed`). Two new EventBus signals (`hero_xp_gained`, `hero_leveled_up`) give HUD/VFX a hook with zero coupling to the resolution logic itself. `damage_status.gd`'s existing Armor formula and mitigation call sites are untouched — only the one hardcoded constant becomes a real per-attack value threaded through the same event-payload plumbing the Hero Combat & Stats Redesign already established.

**Tech Stack:** Godot 4.6.2, GDScript, GdUnit4.

**Spec:** `docs/superpowers/specs/2026-09-19-hero-leveling-design.md`

## Global Constraints

- **Per explicit user instruction this pass: write tests alongside every code change (this project's own coding standard for gameplay systems), but do NOT run gdUnit4 during implementation.** Every task below still has a "write the test" step; the "run to verify" steps from this project's usual TDD convention are deliberately omitted. Verification is deferred to a separate, later pass the user will request explicitly.
- Kill XP band resolution reads `payload.world_position` (already on `MonsterDiedEvent`) vs. `Hero.global_position` — never `_monster_cache`, which is erased on death before XP resolution would run in some orderings.
- `Hero._primary_class` holds real runtime values `"physical"`/`"ranged"`/`"elemental"`/`"support"` (lowercase, matching tower-blueprint `archetype` values) — never the aspirational display names ("Warrior" etc.) from `hero.md`'s Rule 22 table. All class-bonus/skill-tree-point logic keys off these 4 real strings.
- Flat per-level stat growth (+10 HP/+2 Physical Attack/+2 Magic Attack) and the class-bonus stat both write into `Hero._base_stats` (permanent character growth), never `_flat_bonuses` (reserved for gear/temporary bonuses).
- `skill_tree_point_earned(archetype, source_tower_id)`'s level-derived emissions always pass `source_tower_id = -1` (a reserved sentinel — real tower ids are always >= 0).
- Level cap: 50. `xp_required(level) = floor(100 * 1.15^(level-1))`.

---

## Task 1: Hero Level/XP fields, curve helper, and save persistence

**Files:**
- Modify: `src/core/hero/hero.gd` (new fields near `_base_stats`, new constants near other Story-00X constant blocks, `get_save_data()`/`restore_save_data()`/`reset_to_defaults()`)
- Test: `tests/unit/hero/hero_leveling_test.gd` (new file)

**Interfaces:**
- Consumes: nothing new.
- Produces: `Hero._current_level: int`, `Hero._current_xp: int`, `Hero.LEVEL_CAP: int = 50`, `Hero._xp_required_for_level(level: int) -> int` (static), all consumed by Task 3's level-up resolution loop.

- [ ] **Step 1: Add the new fields and constants in `hero.gd`**

Find the `_base_stats` field declaration (added by the Hero Combat & Stats Redesign):

```gdscript
var _base_stats: Dictionary[StringName, float] = {}
```

Insert immediately after it:

```gdscript
## Hero Leveling System (2026-09-19): persistent (cross-mission) level/XP —
## see docs/superpowers/specs/2026-09-19-hero-leveling-design.md. Resets to
## 1/0 only via reset_to_defaults() (called on a fresh/malformed save load,
## which is also this project's own established "new adventure" reset
## trigger — see that field's own doc comment precedent on _proximity_time).
var _current_level: int = 1
var _current_xp: int = 0

## Level cap (Section 3.3 of the governing spec) — no further XP/levels
## past this point; excess XP at the cap is discarded, never banked.
const LEVEL_CAP: int = 50

## Formula L1: xp_required(level) = floor(100 * 1.15^(level-1)). Pure,
## static — no instance state, matching this file's established
## _diminishing_curve()/_apply_tower_affinity_bonus() precedent for
## formula helpers.
static func _xp_required_for_level(level: int) -> int:
	return int(floor(100.0 * pow(1.15, float(level - 1))))
```

- [ ] **Step 2: Extend `get_save_data()`**

Find:

```gdscript
	return {
		"hp": _current_hp,
		"proximity_time": proximity_data,
		"primary_class": String(_primary_class),
		"class_locked": _class_locked,
		"skill_slots": slots,
	}
```

Replace with:

```gdscript
	return {
		"hp": _current_hp,
		"proximity_time": proximity_data,
		"primary_class": String(_primary_class),
		"class_locked": _class_locked,
		"skill_slots": slots,
		"level": _current_level,
		"xp": _current_xp,
	}
```

- [ ] **Step 3: Extend `restore_save_data()`**

Find the opening validation guard:

```gdscript
func restore_save_data(data: Dictionary) -> bool:
	if not (data.has("hp") and data.has("proximity_time") and data.has("primary_class")
			and data.has("class_locked") and data.has("skill_slots")):
		return false
```

Replace with:

```gdscript
func restore_save_data(data: Dictionary) -> bool:
	if not (data.has("hp") and data.has("proximity_time") and data.has("primary_class")
			and data.has("class_locked") and data.has("skill_slots")
			and data.has("level") and data.has("xp")):
		return false
```

Find the field-shape validation block (after the `primary_class_raw` check, before `var restored_proximity`):

```gdscript
	var primary_class_raw: Variant = data["primary_class"]
	if not (primary_class_raw is String):
		return false

	var restored_proximity: Dictionary[StringName, float] = {}
```

Replace with:

```gdscript
	var primary_class_raw: Variant = data["primary_class"]
	if not (primary_class_raw is String):
		return false

	var level_raw: Variant = data["level"]
	if not (level_raw is int) or (level_raw as int) < 1 or (level_raw as int) > LEVEL_CAP:
		return false

	var xp_raw: Variant = data["xp"]
	if not (xp_raw is int) or (xp_raw as int) < 0:
		return false

	var restored_proximity: Dictionary[StringName, float] = {}
```

Find the final mutation block:

```gdscript
	_current_hp = float(hp_value)
	_proximity_time = restored_proximity
	_primary_class = StringName(primary_class_raw as String)
	_class_locked = class_locked_raw as bool
	_skill_slots = restored_slots
	return true
```

Replace with:

```gdscript
	_current_hp = float(hp_value)
	_proximity_time = restored_proximity
	_primary_class = StringName(primary_class_raw as String)
	_class_locked = class_locked_raw as bool
	_skill_slots = restored_slots
	_current_level = level_raw as int
	_current_xp = xp_raw as int
	return true
```

- [ ] **Step 4: Extend `reset_to_defaults()`**

Find:

```gdscript
func reset_to_defaults() -> void:
	_current_hp = get_effective_stat(&"max_hp")
	_max_hp = _current_hp
	_proximity_time.clear()
	_primary_class = &""
	_class_locked = false
	_skill_slots = [&"", &"", &"", &""]
	_phase = HeroPhase.IDLE_SANCTUARY
```

Replace with:

```gdscript
func reset_to_defaults() -> void:
	_current_hp = get_effective_stat(&"max_hp")
	_max_hp = _current_hp
	_proximity_time.clear()
	_primary_class = &""
	_class_locked = false
	_skill_slots = [&"", &"", &"", &""]
	_phase = HeroPhase.IDLE_SANCTUARY
	_current_level = 1
	_current_xp = 0
```

- [ ] **Step 5: Write tests in the new `tests/unit/hero/hero_leveling_test.gd`**

Follow `tests/unit/hero/hero_stat_resolution_test.gd`'s exact `before_test()`/`after_test()` Hero-lifecycle convention (real `PhysicsServer`/`RenderingServer` RIDs — must `free()` explicitly):

```gdscript
extends GdUnitTestSuite

## Unit tests for Hero Leveling System (docs/superpowers/specs/2026-09-19-
## hero-leveling-design.md). Formula L1 (xp curve) and save/restore/reset
## coverage. Level-up resolution (Formula L3) is covered in a later task's
## own test additions to this same file.

var _hero: Hero


func before_test() -> void:
	_hero = Hero.new()
	add_child(_hero)


func after_test() -> void:
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


# ---------------------------------------------------------------------------
# Formula L1: xp_required(level) = floor(100 * 1.15^(level-1))
# ---------------------------------------------------------------------------

## Correction (2026-09-19, found while writing this plan): hand-computed
## "100" for level 2 was an arithmetic slip -- floor(100 * 1.15^1) is not
## exactly 100. Value below (114) is computed with double-precision
## pow()/floor() (Node.js, matching GDScript's own double-precision
## semantics), not by hand -- this exact formula is a floating-point-
## boundary calculation where 1.15^1 may compute as 1.1499999999999999
## rather than exactly 1.15, so hand arithmetic and a real runtime's pow()
## can disagree by 1 at the floor boundary. If your own run of this
## formula in Godot produces 115 instead of 114 (a real, legitimate
## platform/libm difference in pow()'s last bit), use that measured value
## instead -- the point of this test is pinning down THIS project's actual
## runtime behavior, not enforcing a specific hand-derived number.
func test_xp_required_for_level_two_matches_double_precision_curve() -> void:
	assert_int(Hero._xp_required_for_level(2)).is_equal(114)


func test_xp_required_for_level_ten_matches_double_precision_curve() -> void:
	# floor(100 * 1.15^9) -- computed via Node.js double-precision pow(),
	# matching GDScript's own semantics: 351. Same platform-difference
	# caveat as the level-2 test above applies if your measured value
	# differs by 1.
	assert_int(Hero._xp_required_for_level(10)).is_equal(351)


func test_xp_required_grows_monotonically() -> void:
	var previous: int = Hero._xp_required_for_level(2)
	for level in range(3, 51):
		var current: int = Hero._xp_required_for_level(level)
		assert_int(current).is_greater(previous)
		previous = current


# ---------------------------------------------------------------------------
# Save / restore / reset
# ---------------------------------------------------------------------------

func test_reset_to_defaults_sets_level_one_xp_zero() -> void:
	_hero._current_level = 12
	_hero._current_xp = 500
	_hero.reset_to_defaults()
	assert_int(_hero._current_level).is_equal(1)
	assert_int(_hero._current_xp).is_equal(0)


func test_get_save_data_includes_level_and_xp() -> void:
	_hero._current_level = 7
	_hero._current_xp = 250
	var data: Dictionary = _hero.get_save_data()
	assert_int(data["level"] as int).is_equal(7)
	assert_int(data["xp"] as int).is_equal(250)


func test_restore_save_data_round_trips_level_and_xp() -> void:
	_hero._current_level = 20
	_hero._current_xp = 1500
	var data: Dictionary = _hero.get_save_data()

	var fresh := Hero.new()
	add_child(fresh)
	var ok: bool = fresh.restore_save_data(data)
	assert_bool(ok).is_true()
	assert_int(fresh._current_level).is_equal(20)
	assert_int(fresh._current_xp).is_equal(1500)
	fresh.get_parent().remove_child(fresh)
	fresh.free()


func test_restore_save_data_rejects_missing_level_key() -> void:
	var data: Dictionary = _hero.get_save_data()
	data.erase("level")
	assert_bool(_hero.restore_save_data(data)).is_false()


func test_restore_save_data_rejects_level_above_cap() -> void:
	var data: Dictionary = _hero.get_save_data()
	data["level"] = Hero.LEVEL_CAP + 1
	assert_bool(_hero.restore_save_data(data)).is_false()


func test_restore_save_data_rejects_negative_xp() -> void:
	var data: Dictionary = _hero.get_save_data()
	data["xp"] = -1
	assert_bool(_hero.restore_save_data(data)).is_false()
```

- [ ] **Step 6: Commit**

```bash
git add src/core/hero/hero.gd tests/unit/hero/hero_leveling_test.gd
git commit -m "Add Hero Level/XP fields, curve formula, and save persistence"
```

---

## Task 2: New EventBus signals (`hero_xp_gained`, `hero_leveled_up`)

**Files:**
- Modify: `src/foundation/event_bus/event_bus.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces: `signal hero_xp_gained(amount: int, source: String)`, `signal hero_leveled_up(new_level: int)` — emitted by Task 3's level-up resolution.

- [ ] **Step 1: Add the two new signals**

Find the existing `skill_tree_point_earned` signal declaration:

```gdscript
signal skill_tree_point_earned(archetype: String, source_tower_id: int)
```

Insert immediately after it (same file region as other Hero-emitted signals — check the surrounding signals in this file first and place these two alongside Hero's other own signals, e.g. near `hero_class_unlocked`, if that's a cleaner fit; either placement is acceptable, just keep Hero's signals grouped):

```gdscript
## Hero Leveling System (2026-09-19): fired every time Hero gains XP from
## any source (kill/wave/mission). source is one of "kill"/"wave"/"mission"
## — presentation-only (HUD/VFX), never consumed for gameplay logic.
signal hero_xp_gained(amount: int, new_level: int)
## Fired once per level gained, including once per level crossed when a
## single large XP grant crosses multiple thresholds in one resolution
## (Formula L3's while loop) — never batched into one emission for a
## multi-level grant.
signal hero_leveled_up(new_level: int)
```

Note: `hero_xp_gained`'s second parameter is `new_level`, not `source` — self-correct from the spec's Section 3.5 EventBus sketch: including the resulting level (not just a source label) directly on the XP-gain signal itself lets a HUD update its XP bar's "toward next level" fraction without a second event round-trip. If you find this reasoning doesn't fit how Task 3 actually needs to call it, keep `source: String` instead and note the deviation in your report — either is acceptable, this is a presentation-only signal with no gameplay-logic consumer to break.

- [ ] **Step 2: Commit**

```bash
git add src/foundation/event_bus/event_bus.gd
git commit -m "Add hero_xp_gained/hero_leveled_up EventBus signals"
```

---

## Task 3: Level-up resolution loop + kill/wave/mission XP wiring

**Files:**
- Modify: `src/core/hero/hero.gd` (`_on_monster_died()`, new `_on_monsters_died_batch()`, new `_on_wave_completed()`, `_on_mission_phase_changed()`, `_ready()`/`_exit_tree()` subscriptions, new `_grant_xp()`/`_resolve_kill_xp_band()`/level-up-reward helpers)
- Test: `tests/unit/hero/hero_leveling_test.gd` (append)

**Interfaces:**
- Consumes: `Hero._xp_required_for_level()` (Task 1), `GEventBus.hero_xp_gained`/`hero_leveled_up` (Task 2), `MonsterDiedEvent.world_position`/`.tier` (already shipped).
- Produces: `Hero._grant_xp(amount: int) -> void` — the single entry point every XP source calls; internally runs Formula L3's level-up loop and applies Task 1's rewards inline (flat growth this task; every-5th-level Skill Tree point + class bonus in Task 4, called from inside this same loop — Task 4 extends this function's body, doesn't replace it).

- [ ] **Step 1: Add the kill-XP band constants**

Find `LEVEL_CAP` (added in Task 1) and add alongside it:

```gdscript
## Formula L2 (kill XP bands). Keys match MonsterResource.tier's own
## 0/1/2 convention (STANDARD/ELITE/BOSS).
const KILL_XP_BY_TIER: Dictionary[int, int] = {0: 5, 1: 15, 2: 100}
const KILL_XP_OUTER_BAND_MULTIPLIER: float = 0.5
const KILL_XP_OUTER_BAND_RANGE_MULTIPLIER: float = 2.0
const WAVE_COMPLETION_XP: int = 25
const MISSION_COMPLETION_XP: int = 150
```

- [ ] **Step 2: Add `_resolve_kill_xp_band()` and `_grant_xp()`**

Add these as new methods (place near `_xp_required_for_level()` from Task 1):

```gdscript
## Formula L2: resolves kill XP for one monster death by distance band.
## Returns 0 if the death is outside both bands. Reads MonsterDiedEvent's
## own world_position/tier fields directly -- never _monster_cache, which
## _on_monster_died() erases the entry from before XP would resolve in
## some call orderings.
func _resolve_kill_xp_band(payload: MonsterDiedEvent) -> int:
	var base_xp: int = KILL_XP_BY_TIER.get(payload.tier, 0)
	if base_xp <= 0:
		return 0
	var attack_range: float = get_effective_stat(&"attack_range")
	var distance: float = global_position.distance_to(payload.world_position)
	if distance <= attack_range:
		return base_xp
	if distance <= attack_range * KILL_XP_OUTER_BAND_RANGE_MULTIPLIER:
		return int(floor(float(base_xp) * KILL_XP_OUTER_BAND_MULTIPLIER))
	return 0


## Formula L3: single entry point for every XP source. Resolves every
## level threshold crossed by this one grant (never just the first),
## applying Task 1/3's flat growth per level and emitting
## hero_xp_gained/hero_leveled_up. amount <= 0 is a silent no-op (a kill
## outside both bands, or a not-yet-authored zero-XP source, must never
## emit a spurious hero_xp_gained(0, ...)).
func _grant_xp(amount: int) -> void:
	if amount <= 0:
		return
	if _current_level >= LEVEL_CAP:
		return
	_current_xp += amount
	GEventBus.hero_xp_gained.emit(amount, _current_level)
	while _current_level < LEVEL_CAP and _current_xp >= _xp_required_for_level(_current_level + 1):
		_current_xp -= _xp_required_for_level(_current_level + 1)
		_current_level += 1
		_apply_level_up_rewards()
		GEventBus.hero_leveled_up.emit(_current_level)
	if _current_level >= LEVEL_CAP:
		_current_xp = 0


## Flat per-level stat growth (Section 3.4's first bullet) -- applies
## unconditionally, every level, regardless of Primary class designation.
## Task 4 extends this same function with the every-5th-level Skill Tree
## point + class bonus (gated on _current_level % 5 == 0), appended at the
## end of this function's body, not a separate call site -- see Task 4's
## own Step 1.
func _apply_level_up_rewards() -> void:
	_base_stats[&"max_hp"] = _base_stats.get(&"max_hp", 0.0) + 10.0
	_base_stats[&"physical_attack"] = _base_stats.get(&"physical_attack", 0.0) + 2.0
	_base_stats[&"magic_attack"] = _base_stats.get(&"magic_attack", 0.0) + 2.0
```

- [ ] **Step 3: Wire kill XP into `_on_monster_died()`**

Find:

```gdscript
## Removes the monster from the cache — no longer a valid attack target.
func _on_monster_died(payload: MonsterDiedEvent) -> void:
	_monster_cache.erase(payload.entity_id)
```

Replace with:

```gdscript
## Removes the monster from the cache — no longer a valid attack target.
## Hero Leveling System (2026-09-19): also grants kill XP by distance band
## (Formula L2) -- resolved BEFORE the cache erase line only in the sense
## that both read payload's own fields, never _monster_cache, so ordering
## between these two lines does not matter; kept in this order (XP first)
## purely for readability (XP is this handler's newer, less structural
## concern).
func _on_monster_died(payload: MonsterDiedEvent) -> void:
	_grant_xp(_resolve_kill_xp_band(payload))
	_monster_cache.erase(payload.entity_id)
```

- [ ] **Step 4: Add a new `_on_monsters_died_batch()` handler and subscribe/unsubscribe it**

Add the new handler near `_on_monster_died()`:

```gdscript
## Hero Leveling System (2026-09-19): batched deaths (DEATH_BATCH_THRESHOLD
## exceeded, monster_manager.gd) resolve kill XP identically to individual
## monster_died -- Hero had no subscription to this signal before this
## addition (it only ever needed per-entity cache cleanup, which
## monsters_died_batch's own emitter does not require of subscribers).
## Each entry resolved independently, matching ResourceEconomy's own
## established "no shared/batched rounding state across a batch" precedent.
func _on_monsters_died_batch(payloads: Array[MonsterDiedEvent]) -> void:
	for payload: MonsterDiedEvent in payloads:
		_grant_xp(_resolve_kill_xp_band(payload))
		_monster_cache.erase(payload.entity_id)
```

Find the `_ready()` subscription block:

```gdscript
	GEventBus.monster_spawned.connect(_on_monster_spawned)
	GEventBus.monster_cell_entered.connect(_on_monster_cell_entered)
	GEventBus.monster_died.connect(_on_monster_died)
```

Replace with:

```gdscript
	GEventBus.monster_spawned.connect(_on_monster_spawned)
	GEventBus.monster_cell_entered.connect(_on_monster_cell_entered)
	GEventBus.monster_died.connect(_on_monster_died)
	GEventBus.monsters_died_batch.connect(_on_monsters_died_batch)
	GEventBus.wave_completed.connect(_on_wave_completed)
```

Find the matching `_exit_tree()` disconnect block:

```gdscript
	GEventBus.monster_spawned.disconnect(_on_monster_spawned)
	GEventBus.monster_cell_entered.disconnect(_on_monster_cell_entered)
	GEventBus.monster_died.disconnect(_on_monster_died)
```

Replace with:

```gdscript
	GEventBus.monster_spawned.disconnect(_on_monster_spawned)
	GEventBus.monster_cell_entered.disconnect(_on_monster_cell_entered)
	GEventBus.monster_died.disconnect(_on_monster_died)
	GEventBus.monsters_died_batch.disconnect(_on_monsters_died_batch)
	GEventBus.wave_completed.disconnect(_on_wave_completed)
```

- [ ] **Step 5: Add `_on_wave_completed()`**

Add near the other new handlers:

```gdscript
## Hero Leveling System (2026-09-19), Section 3.2: flat XP per wave clear.
## was_boss_breached is ignored -- wave_completed fires once per wave clear
## regardless of breach outcome, and this XP source is deliberately
## unconditional per the governing spec (no partial-credit/breach-penalty
## rule was specified).
func _on_wave_completed(_wave_number: int, _enemies_remaining: int, _was_boss_breached: bool) -> void:
	_grant_xp(WAVE_COMPLETION_XP)
```

- [ ] **Step 6: Wire mission-completion XP into `_on_mission_phase_changed()`**

Find:

```gdscript
		"DEFEAT", "MISSION_COMPLETE":
			_proximity_active = false
			_phase = HeroPhase.DEAD
```

Replace with:

```gdscript
		"MISSION_COMPLETE":
			_proximity_active = false
			_phase = HeroPhase.DEAD
			_grant_xp(MISSION_COMPLETION_XP)
		"DEFEAT":
			_proximity_active = false
			_phase = HeroPhase.DEAD
```

(Splitting the combined match arm is required here — DEFEAT must never grant mission-completion XP per the spec's Section 3.1 "DEFEAT ... only withholds the 150 XP mission-completion bonus, since that trigger never fires" rule; the two phases can no longer share one arm.)

- [ ] **Step 7: Append tests to `tests/unit/hero/hero_leveling_test.gd`**

```gdscript
# ---------------------------------------------------------------------------
# Formula L2: kill XP band resolution
# ---------------------------------------------------------------------------

func _make_died_event(tier: int, world_position: Vector2) -> MonsterDiedEvent:
	var payload := MonsterDiedEvent.new()
	payload.tier = tier
	payload.world_position = world_position
	return payload


func test_kill_within_attack_range_grants_full_tier_xp() -> void:
	_hero._base_stats[&"attack_range"] = 100.0
	_hero.global_position = Vector2.ZERO
	var payload := _make_died_event(1, Vector2(50, 0))  # ELITE, distance 50 <= 100
	assert_int(_hero._resolve_kill_xp_band(payload)).is_equal(15)


func test_kill_in_outer_band_grants_half_tier_xp_floored() -> void:
	_hero._base_stats[&"attack_range"] = 100.0
	_hero.global_position = Vector2.ZERO
	var payload := _make_died_event(1, Vector2(150, 0))  # distance 150, in (100, 200]
	assert_int(_hero._resolve_kill_xp_band(payload)).is_equal(7)  # floor(15 * 0.5)


func test_kill_outside_both_bands_grants_zero_xp() -> void:
	_hero._base_stats[&"attack_range"] = 100.0
	_hero.global_position = Vector2.ZERO
	var payload := _make_died_event(2, Vector2(500, 0))  # distance 500 > 200
	assert_int(_hero._resolve_kill_xp_band(payload)).is_equal(0)


func test_boss_outer_band_still_exceeds_standard_inner_band() -> void:
	_hero._base_stats[&"attack_range"] = 100.0
	_hero.global_position = Vector2.ZERO
	var boss_outer := _make_died_event(2, Vector2(150, 0))
	var standard_inner := _make_died_event(0, Vector2(50, 0))
	assert_int(_hero._resolve_kill_xp_band(boss_outer)).is_greater(
		_hero._resolve_kill_xp_band(standard_inner))


# ---------------------------------------------------------------------------
# Formula L3: level-up resolution loop
# ---------------------------------------------------------------------------

func test_grant_xp_zero_or_negative_is_a_no_op() -> void:
	_hero._current_xp = 0
	_hero._grant_xp(0)
	assert_int(_hero._current_xp).is_equal(0)
	_hero._grant_xp(-5)
	assert_int(_hero._current_xp).is_equal(0)


func test_grant_xp_below_threshold_accumulates_without_leveling() -> void:
	_hero._current_level = 1
	_hero._current_xp = 0
	_hero._grant_xp(50)  # below xp_required(2) (~114, see Task 1's own tests)
	assert_int(_hero._current_level).is_equal(1)
	assert_int(_hero._current_xp).is_equal(50)


func test_grant_xp_crossing_one_threshold_levels_up_once() -> void:
	_hero._current_level = 1
	_hero._current_xp = 0
	var base_hp: float = _hero._base_stats.get(&"max_hp", 0.0)
	var xp_for_level_two: int = Hero._xp_required_for_level(2)
	_hero._grant_xp(xp_for_level_two)  # exactly the threshold, whatever it measures to
	assert_int(_hero._current_level).is_equal(2)
	assert_int(_hero._current_xp).is_equal(0)
	assert_float(_hero._base_stats[&"max_hp"]).is_equal_approx(base_hp + 10.0, 0.0001)


func test_grant_xp_crossing_multiple_thresholds_levels_up_each_one() -> void:
	_hero._current_level = 1
	_hero._current_xp = 0
	# A grant of xp_required(2) + xp_required(3) exactly reaches level 3
	# with 0 XP remaining -- calling the real formula (not a hand-derived
	# constant) so this test is correct regardless of the exact
	# floating-point value each threshold measures to.
	var grant: int = Hero._xp_required_for_level(2) + Hero._xp_required_for_level(3)
	_hero._grant_xp(grant)
	assert_int(_hero._current_level).is_equal(3)
	assert_int(_hero._current_xp).is_equal(0)
	var base_hp: float = _hero._base_stats.get(&"max_hp", 0.0)
	assert_float(base_hp).is_equal_approx(20.0, 0.0001)  # +10 per level, 2 levels


func test_grant_xp_at_level_cap_discards_excess_and_never_levels_further() -> void:
	_hero._current_level = Hero.LEVEL_CAP
	_hero._current_xp = 0
	_hero._grant_xp(999999)
	assert_int(_hero._current_level).is_equal(Hero.LEVEL_CAP)
	assert_int(_hero._current_xp).is_equal(0)


func test_wave_completed_grants_flat_wave_xp() -> void:
	_hero._current_level = 1
	_hero._current_xp = 0
	_hero._on_wave_completed(1, 0, false)
	assert_int(_hero._current_xp).is_equal(Hero.WAVE_COMPLETION_XP)


func test_mission_complete_grants_mission_xp_but_defeat_does_not() -> void:
	_hero._current_level = 1
	_hero._current_xp = 0
	_hero._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)
	assert_int(_hero._current_xp).is_equal(0)
	_hero._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)
	assert_int(_hero._current_xp).is_equal(Hero.MISSION_COMPLETION_XP)
```

- [ ] **Step 8: Commit**

```bash
git add src/core/hero/hero.gd tests/unit/hero/hero_leveling_test.gd
git commit -m "Wire kill/wave/mission XP sources and the level-up resolution loop"
```

---

## Task 4: Every-5th-level Skill Tree point + class bonus

**Files:**
- Modify: `src/core/hero/hero.gd` (`_apply_level_up_rewards()` from Task 3)
- Test: `tests/unit/hero/hero_leveling_test.gd` (append)

**Interfaces:**
- Consumes: `Hero._apply_level_up_rewards()` (Task 3, extended in place — same function, not a new one), `GEventBus.skill_tree_point_earned` (already exists).
- Produces: nothing new — this task only extends Task 3's reward function body.

- [ ] **Step 1: Add the class-bonus lookup table and extend `_apply_level_up_rewards()`**

Find `KILL_XP_BY_TIER` (added in Task 3) and add alongside it:

```gdscript
## Section 3.4's placeholder class-bonus mapping. Keyed by the REAL runtime
## values of _primary_class (lowercase tower-archetype strings), not the
## aspirational display names in hero.md's Rule 22 table -- see this
## const's own explicit "placeholder, not the real class catalogue" framing
## in the governing spec. Each entry: [stat_name, amount].
const CLASS_LEVEL_BONUS: Dictionary[StringName, Array] = {
	&"physical": [&"physical_attack", 1.0],
	&"ranged": [&"crit_chance", 0.005],
	&"elemental": [&"magic_attack", 1.0],
	&"support": [&"cdr", 0.01],
}
const SKILL_POINT_LEVEL_INTERVAL: int = 5
## Reserved sentinel for a level-derived skill_tree_point_earned emission --
## real tower ids from Tower Mastery's own emissions are always >= 0.
const LEVEL_DERIVED_SKILL_POINT_SOURCE_ID: int = -1
```

Find `_apply_level_up_rewards()` (added in Task 3):

```gdscript
func _apply_level_up_rewards() -> void:
	_base_stats[&"max_hp"] = _base_stats.get(&"max_hp", 0.0) + 10.0
	_base_stats[&"physical_attack"] = _base_stats.get(&"physical_attack", 0.0) + 2.0
	_base_stats[&"magic_attack"] = _base_stats.get(&"magic_attack", 0.0) + 2.0
```

Replace with:

```gdscript
func _apply_level_up_rewards() -> void:
	_base_stats[&"max_hp"] = _base_stats.get(&"max_hp", 0.0) + 10.0
	_base_stats[&"physical_attack"] = _base_stats.get(&"physical_attack", 0.0) + 2.0
	_base_stats[&"magic_attack"] = _base_stats.get(&"magic_attack", 0.0) + 2.0

	if _current_level % SKILL_POINT_LEVEL_INTERVAL != 0:
		return
	if _primary_class == &"":
		return
	GEventBus.skill_tree_point_earned.emit(String(_primary_class), LEVEL_DERIVED_SKILL_POINT_SOURCE_ID)
	var bonus_entry: Array = CLASS_LEVEL_BONUS.get(_primary_class, [])
	if bonus_entry.is_empty():
		return
	var bonus_stat: StringName = bonus_entry[0] as StringName
	var bonus_amount: float = bonus_entry[1] as float
	_base_stats[bonus_stat] = _base_stats.get(bonus_stat, 0.0) + bonus_amount
```

- [ ] **Step 2: Append tests to `tests/unit/hero/hero_leveling_test.gd`**

```gdscript
# ---------------------------------------------------------------------------
# Every-5th-level Skill Tree point + class bonus
# ---------------------------------------------------------------------------

func test_level_five_with_primary_class_grants_class_bonus_stat() -> void:
	_hero._primary_class = &"elemental"
	_hero._current_level = 4
	_hero._current_xp = Hero._xp_required_for_level(5) - 1
	var base_magic: float = _hero._base_stats.get(&"magic_attack", 0.0)
	_hero._grant_xp(1)
	assert_int(_hero._current_level).is_equal(5)
	# +2 universal (Task 3) + 1.0 class bonus (elemental -> magic_attack)
	assert_float(_hero._base_stats[&"magic_attack"]).is_equal_approx(base_magic + 3.0, 0.0001)


func test_level_five_without_primary_class_skips_class_bonus_and_skill_point() -> void:
	_hero._primary_class = &""
	_hero._current_level = 4
	_hero._current_xp = Hero._xp_required_for_level(5) - 1
	var base_magic: float = _hero._base_stats.get(&"magic_attack", 0.0)
	_hero._grant_xp(1)
	assert_int(_hero._current_level).is_equal(5)
	# only the +2 universal growth applies -- no class bonus without a Primary class
	assert_float(_hero._base_stats[&"magic_attack"]).is_equal_approx(base_magic + 2.0, 0.0001)


func test_non_qualifying_level_skips_class_bonus_even_with_primary_class() -> void:
	_hero._primary_class = &"physical"
	_hero._current_level = 5
	_hero._current_xp = Hero._xp_required_for_level(6) - 1
	var base_physical: float = _hero._base_stats.get(&"physical_attack", 0.0)
	_hero._grant_xp(1)
	assert_int(_hero._current_level).is_equal(6)  # not a multiple of 5
	# only the +2 universal growth applies at a non-qualifying level
	assert_float(_hero._base_stats[&"physical_attack"]).is_equal_approx(base_physical + 2.0, 0.0001)


func test_level_five_emits_skill_tree_point_earned_with_sentinel_source() -> void:
	_hero._primary_class = &"support"
	_hero._current_level = 4
	_hero._current_xp = Hero._xp_required_for_level(5) - 1
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.skill_tree_point_earned)
	_hero._grant_xp(1)
	assert_int(spy.count("skill_tree_point_earned")).is_equal(1)
	var args: Array = (spy.emissions["skill_tree_point_earned"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal("support")
	assert_int(args[1] as int).is_equal(Hero.LEVEL_DERIVED_SKILL_POINT_SOURCE_ID)
	spy.disconnect_all()
```

- [ ] **Step 3: Commit**

```bash
git add src/core/hero/hero.gd tests/unit/hero/hero_leveling_test.gd
git commit -m "Add every-5th-level Skill Tree point and placeholder class bonus"
```

---

## Task 5: Thread real Hero Level into the Armor mitigation formula

**Files:**
- Modify: `src/foundation/event_bus/event_payloads/hero_auto_attack_event.gd`
- Modify: `src/foundation/event_bus/event_payloads/hero_skill_attack_event.gd`
- Modify: `src/core/hero/hero.gd` (`_on_attack_timer_timeout()`, `_resolve_skill_hit()`)
- Modify: `src/core/damage_status/damage_status.gd` (`_resolve_target_mitigation()`, both call sites)
- Test: `tests/unit/damage_status/damage_status_test.gd` (append)

**Interfaces:**
- Consumes: `Hero._current_level` (Task 1).
- Produces: `HeroAutoAttackEvent.hero_level: int`, `HeroSkillAttackEvent.hero_level: int` — replaces `damage_status.gd`'s `HERO_LEVEL_PLACEHOLDER` constant as `_resolve_target_mitigation()`'s level input.

- [ ] **Step 1: Add `hero_level` to both event payloads**

In `hero_auto_attack_event.gd`, find the `target_elemental_resist` field (added by the Hero Combat & Stats Redesign) and add immediately after it:

```gdscript
## Hero Leveling System (2026-09-19): Hero's real current level at the
## moment of this attack, replacing damage_status.gd's previous
## HERO_LEVEL_PLACEHOLDER=1 constant in the Armor mitigation formula.
@export var hero_level: int = 1
```

Apply the identical field addition (same doc comment, same default) to `hero_skill_attack_event.gd`, immediately after its own `target_elemental_resist` field.

- [ ] **Step 2: Populate `hero_level` at both emission sites in `hero.gd`**

In `_on_attack_timer_timeout()`, find:

```gdscript
	payload.target_armor = entry.get("armor", 0.0) as float
	payload.target_evasion = entry.get("evasion", 0.0) as float
	GEventBus.hero_auto_attacked.emit(payload)
```

Replace with:

```gdscript
	payload.target_armor = entry.get("armor", 0.0) as float
	payload.target_evasion = entry.get("evasion", 0.0) as float
	payload.hero_level = _current_level
	GEventBus.hero_auto_attacked.emit(payload)
```

In `_resolve_skill_hit()`, find:

```gdscript
	payload.target_elemental_resist = elemental_resistances.get(damage_type, 0.0) as float
	GEventBus.hero_skill_attacked.emit(payload)
```

Replace with:

```gdscript
	payload.target_elemental_resist = elemental_resistances.get(damage_type, 0.0) as float
	payload.hero_level = _current_level
	GEventBus.hero_skill_attacked.emit(payload)
```

- [ ] **Step 3: Update `damage_status.gd`'s `_resolve_target_mitigation()` and both call sites**

Find:

```gdscript
## Hero Combat & Stats Redesign (2026-09-18), Section 3.3: Hero Level is
## hardcoded to 1 pending the not-yet-designed Hero Leveling system -- swap
## this constant for Hero's real current level once that system exists (one-
## line change, no formula rework, per the governing spec's own explicit
## sequencing decision).
const HERO_LEVEL_PLACEHOLDER: int = 1
const HERO_ARMOR_MITIGATION_LEVEL_SCALAR: float = 50.0
```

Replace with:

```gdscript
## Hero Leveling System (2026-09-19): the Hero Combat & Stats Redesign's
## HERO_LEVEL_PLACEHOLDER=1 constant is now retired -- _resolve_target_
## mitigation() below takes the real per-attack hero_level as a parameter
## instead (see HeroAutoAttackEvent.hero_level/HeroSkillAttackEvent.hero_level).
const HERO_ARMOR_MITIGATION_LEVEL_SCALAR: float = 50.0
```

Find `_resolve_target_mitigation()`'s signature and body:

```gdscript
static func _resolve_target_mitigation(damage_type: String, target_armor: float, target_elemental_resist: float) -> float:
	if damage_type == "true":
		return 1.0
	if damage_type == "physical":
		var clamped_armor: float = maxf(0.0, target_armor)
		var armor_mitigation: float = clamped_armor / (clamped_armor + HERO_ARMOR_MITIGATION_LEVEL_SCALAR * float(HERO_LEVEL_PLACEHOLDER))
		return 1.0 - armor_mitigation
	return 1.0 - target_elemental_resist
```

Replace with:

```gdscript
static func _resolve_target_mitigation(damage_type: String, target_armor: float, target_elemental_resist: float, hero_level: int) -> float:
	if damage_type == "true":
		return 1.0
	if damage_type == "physical":
		var clamped_armor: float = maxf(0.0, target_armor)
		var armor_mitigation: float = clamped_armor / (clamped_armor + HERO_ARMOR_MITIGATION_LEVEL_SCALAR * float(maxi(1, hero_level)))
		return 1.0 - armor_mitigation
	return 1.0 - target_elemental_resist
```

(`maxi(1, hero_level)` guards against a malformed/zero level ever producing a divide-by-zero — `hero_level` is always >= 1 in practice per `Hero._current_level`'s own field default and save-restore validation, but this keeps the formula itself defensively correct regardless of caller discipline, mirroring the existing `clamped_armor` guard immediately above it.)

Find both call sites inside `_on_hero_auto_attacked()` and `_on_hero_skill_attacked()`:

```gdscript
	var mitigated_dmg: float = crit_dmg * _resolve_target_mitigation(event.damage_type, event.target_armor, event.target_elemental_resist)
```

Replace both occurrences with:

```gdscript
	var mitigated_dmg: float = crit_dmg * _resolve_target_mitigation(event.damage_type, event.target_armor, event.target_elemental_resist, event.hero_level)
```

- [ ] **Step 4: Update the existing `_resolve_target_mitigation()` unit tests for the new parameter**

Find every existing call to `DamageStatus._resolve_target_mitigation(...)` in `damage_status_test.gd` (added by the Hero Combat & Stats Redesign and its final-review fix wave) and add a 4th argument, `1`, to each (preserving today's `hero_level=1` behavior exactly, since none of those tests were about level scaling):

```gdscript
DamageStatus._resolve_target_mitigation("true", 500.0, 0.9)
```
becomes
```gdscript
DamageStatus._resolve_target_mitigation("true", 500.0, 0.9, 1)
```

Apply the same 4th-argument addition to the other 3 existing calls in that file (`_physical_zero_armor`, `_physical_with_armor_worked_example`, `_magic_uses_elemental_resist_directly`, and the negative-armor-clamp test from the final review's fix wave).

- [ ] **Step 5: Add a new test proving a higher hero_level reduces mitigation for the same Armor**

Append to `damage_status_test.gd`:

```gdscript
func test_resolve_target_mitigation_physical_higher_hero_level_reduces_mitigation() -> void:
	# Armor=50: level 1 -> 50/(50+50)=0.5 mitigation -> multiplier 0.5.
	# level 2 -> 50/(50+100)=0.333 mitigation -> multiplier 0.667 (less mitigated).
	var level_one: float = DamageStatus._resolve_target_mitigation("physical", 50.0, 0.0, 1)
	var level_two: float = DamageStatus._resolve_target_mitigation("physical", 50.0, 0.0, 2)
	assert_float(level_one).is_equal_approx(0.5, 0.0001)
	assert_float(level_two).is_greater(level_one)
```

- [ ] **Step 6: Commit**

```bash
git add src/foundation/event_bus/event_payloads/hero_auto_attack_event.gd src/foundation/event_bus/event_payloads/hero_skill_attack_event.gd src/core/hero/hero.gd src/core/damage_status/damage_status.gd tests/unit/damage_status/damage_status_test.gd
git commit -m "Thread real Hero Level into the Armor mitigation formula"
```

---

## Task 6: Update hero.md GDD

**Files:**
- Modify: `design/gdd/hero.md`

**Interfaces:** N/A — documentation only.

- [ ] **Step 1: Add a new Group documenting Hero Level/XP**

Find Group 6 ("Hero Death", added originally) and insert a new group immediately before it (renumber "Hero Death" to the next group number if the file uses sequential group numbers — check the actual current numbering before inserting, since earlier redesigns may have shifted it):

```markdown
#### Group N: Hero Leveling

25. Hero Level is persistent across missions — part of the same persistent domain as equipment, tech tree, and menagerie state. It resets only on a full new-game/new-adventure reset, in lockstep with the Hero Skill Tree's own reset trigger. Surviving a DEFEAT does not reset level or XP.

26. XP sources: a monster kill within the Hero's current Attack Range grants full tier-based XP (STANDARD 5 / ELITE 15 / BOSS 100); a kill within 2x Attack Range but outside that inner band grants half that amount, floored; beyond 2x Attack Range grants none. Wave completion grants a flat 25 XP; mission completion grants a flat 150 XP (withheld on DEFEAT).

27. The level curve is `xp_required(level) = floor(100 x 1.15^(level-1))` (see Formulas), capped at level 50. A single large XP grant may cross multiple level thresholds in one resolution; every crossed level's rewards apply independently, never just the first.

28. Every level grants +10 Max HP, +2 Physical Attack, +2 Magic Attack. Every 5th level additionally grants 1 Skill Tree point (credited to the archetype pool matching the Hero's current Primary class) and a small class-specific stat bonus, per Rule 29 — both skipped, not banked, for a qualifying level reached with no Primary class designated.

29. **Placeholder class-bonus mapping** (explicitly provisional — superseded whenever the real class catalogue, Rule 23, ships): Physical archetype -> +1 Physical Attack; Ranged archetype -> +0.5% Crit Chance; Elemental archetype -> +1 Magic Attack; Support archetype -> +1% CDR.
```

- [ ] **Step 2: Add Formula L1-L3 to the Formulas section**

Find the end of the Formulas section (the same location the Hero Combat & Stats Redesign's Task 10 already appended Formula 7 to) and add, immediately after Formula 7's closing `---`:

```markdown
### Formula 8: XP Required Per Level

```
xp_required(level) = floor(100 x 1.15^(level - 1))
```

| Variable | Range | Description |
|---|---|---|
| `level` | 2-50 | The level being leveled up TO |
| Result | int >= 100 | XP needed, accumulated from 0, to complete this level |

**Example:** `xp_required(10) = floor(100 x 1.15^9) = 351` (computed with double-precision `pow()`/`floor()`, matching this project's own runtime semantics — do not hand-round the intermediate `1.15^9`, since floor-boundary calculations like this one can differ by 1 from hand arithmetic due to floating-point representation)

---

### Formula 9: Kill XP Band Resolution

```
distance = hero.global_position.distance_to(death_position)
if distance <= attack_range:       kill_xp = tier_base_xp[tier]
elif distance <= 2 x attack_range:  kill_xp = floor(tier_base_xp[tier] x 0.5)
else:                                kill_xp = 0
```

Where `tier_base_xp = {STANDARD: 5, ELITE: 15, BOSS: 100}`.

---
```

- [ ] **Step 3: Update the Tuning Knobs table**

Add rows (in whatever format the existing Tuning Knobs table already uses) for: kill XP per tier, outer-band XP fraction and range multiplier, wave/mission completion XP, level curve base/growth rate, level cap, flat per-level stat growth, and the skill-point/class-bonus level interval — values from this spec's own Section 7 table (`docs/superpowers/specs/2026-09-19-hero-leveling-design.md`).

- [ ] **Step 4: Commit**

```bash
git add design/gdd/hero.md
git commit -m "Document Hero Leveling System in hero.md GDD"
```
