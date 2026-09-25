# Hero Damage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ELITE and BOSS monsters can hurt the Hero through a telegraphed, dodgeable attack; Damage & Status mitigates it with armor; the Hero heals a fraction of max HP at each wave clear.

**Architecture:** `MonsterManager` gains a Hero-attack pass (`_pass2b_hero_attacks`) beside the existing boss pass: elites attack the Hero only, bosses attack the closest of Hero or tower. A hit is a new `hero_incoming_damage(HeroIncomingDamageEvent)` event; `DamageStatus` implements Rule V (armor, fire/frost resist) through an injected stat provider and emits the existing `hero_damage_taken`; Hero's existing HP/DEFEAT handling is unchanged, plus a wave-clear heal.

**Tech Stack:** Godot 4.6.2, GDScript, gdUnit4, `.tres` resources.

**Spec:** `docs/superpowers/specs/2026-09-25-hero-damage-design.md`

## Global Constraints

- Scope is the spec's simulation only. The visible wind-up indicator is a separate follow-up; do NOT add presentation. STANDARD monsters never attack. Elites attack the Hero only (never towers); bosses attack the closest of Hero or tower (Hero only when STRICTLY closer; ties go to the tower); bosses keep attacking towers exactly as today.
- A Hero attack has a per-monster wind-up in SECONDS (`hero_attack_windup_seconds`). The target locks at wind-up; the hit lands only if the Hero is still within `boss_attack_range_cells` (Chebyshev, grid cells) of the monster at fire time; otherwise it is a whiff (no damage, no event) and the cooldown is still spent. The boss-to-tower wind-up (`BOSS_ATTACK_PREPARE_FRAMES = 4`) is unchanged.
- A monster has at most ONE wind-up in flight (tower or Hero). Elites and bosses share `boss_attack_cooldown_remaining` and `boss_scan_frames_remaining`; `MonsterEntity.hero_windup_remaining` is the only new entity state; `HERO_TARGET_ID := -2` in `boss_locked_target_id` means the Hero.
- No randomness anywhere in the path: no crit, no variance, no accuracy roll. Damage is the monster's `base_damage` (unscaled), `damage_type "physical"`, `source_type 0`.
- Mitigation (Damage & Status): physical `max(1, floor(amount x 100 / (armor + 100)))`; fire/frost `max(1, floor(amount x (1 - clamp(resist, 0, 0.75))))`; any other type unmitigated, floored at 1. Stats are read at hit time, then the result is emitted one frame later.
- Wave-clear heal: `const WAVE_CLEAR_HEAL_FRACTION: float = 0.25` in `hero.gd`; heals `roundi(_max_hp x 0.25)` through the existing `_on_hero_healed()` (phase guard + overheal clamp); never heals a DEAD Hero.
- First-pass attacker data (exact values): bog_lurker_elite 30 / 2.5 / range 2 / windup 0.9; forest_troll_elite 45 / 3.0 / 2 / 1.0; iron_colossus_elite 70 / 4.0 / 2 / 1.2; goblin_warlord_boss 60 / 3.0 / 3 / 1.0 (damage, interval, range already exist); rift_sentinel_boss 20 / 2.2 / 2 / 0.8.
- The physics-pass emissions (`hero_incoming_damage`, `monster_hero_attack_winding_up`) are synchronous, following the existing precedent of `boss_tower_attack_attempted` in `MonsterManager._pass2_boss_logic`. Every new EventBus subscription is disconnected in `_exit_tree()` (ADR-0001 Rule 6).
- New `class_name` (`HeroIncomingDamageEvent`) and new `.gd` files need a class-cache rebuild before tests: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --editor --path G:/TDef --quit`. It also generates the `.gd.uid` files, which are tracked in git: `git add` each new `.gd` together with its `.gd.uid` (only if the `.uid` exists).
- Test runner: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:/TDef --script tests/gdunit4_runner.gd -- -a <res:// path> --ignoreHeadlessMode`. Under Git Bash pass `--path` as `G:/TDef` (forward slashes). Run only the targeted suites named in each task; do NOT run the full suite.
- `Array[StringName].sort()` is NOT lexical in this engine (use `sort_custom` with a `String(a) < String(b)` compare if ever needed).
- Existing suites that must keep passing unchanged unless a task edits them: `tests/unit/monster/monster_boss_test.gd`, `monster_status_effect_test.gd`, `monster_spawn_test.gd`, `tests/unit/damage_status/damage_status_test.gd`, `tests/unit/hero/hero_leveling_test.gd`, `tests/integration/hero/hero_lifecycle_test.gd`.
- Commit and push after each task's tests pass (standing user rule). After every commit verify with `git show --name-only --format= HEAD` that no unrelated files (the pre-existing modified `addons/` and untracked files) were included; a non-existent path in `git add` aborts the whole add, so list only files that exist. Commit messages end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.

## File Structure

- Modify `src/core/monster/monster_resource.gd`: `hero_attack_windup_seconds` + validation. Modify the five `assets/data/monsters/{bog_lurker_elite,forest_troll_elite,iron_colossus_elite,goblin_warlord_boss,rift_sentinel_boss}.tres`.
- Create `src/foundation/event_bus/event_payloads/hero_incoming_damage_event.gd`. Modify `src/foundation/event_bus/event_bus.gd` (payload on `hero_incoming_damage`, new `monster_hero_attack_winding_up`).
- Modify `src/core/damage_status/damage_status.gd`: Rule V, `set_hero_stats()`.
- Modify `src/core/hero/hero.gd`: wave-clear heal.
- Modify `src/core/monster/monster_entity.gd`, `src/core/monster/monster_manager.gd`: Hero cache, elite Hero attacks, boss targeting.
- Modify `src/gameplay/missions/the_gap/the_gap.gd`, `src/scenes/mission_scene.gd`: one wiring line each.
- Tests: `tests/unit/monster/monster_resource_validate_test.gd` (modify), `tests/unit/event_bus/event_bus_signals_test.gd` (modify), `tests/unit/damage_status/hero_incoming_damage_test.gd` (new), `tests/unit/hero/hero_wave_clear_heal_test.gd` (new), `tests/unit/monster/monster_hero_attack_test.gd` (new), `tests/integration/hero/hero_damage_chain_test.gd` (new).
- Docs: `design/gdd/damage-status.md`, `design/gdd/monster.md`, `design/gdd/hero.md`, `design/gdd/event-bus.md`, the spec status line, `production/session-state/active.md`.

---

### Task 1: `hero_attack_windup_seconds`, validation, and the five attacker data files

**Files:**
- Modify: `src/core/monster/monster_resource.gd`
- Modify: `assets/data/monsters/bog_lurker_elite.tres`, `forest_troll_elite.tres`, `iron_colossus_elite.tres`, `goblin_warlord_boss.tres`, `rift_sentinel_boss.tres`
- Test: `tests/unit/monster/monster_resource_validate_test.gd`

**Interfaces:**
- Produces: `MonsterResource.hero_attack_windup_seconds: float` (default 0.0); `validate()` rules below; the five shipped attackers carry the spec's values.

- [ ] **Step 1: Write the failing tests**

In `tests/unit/monster/monster_resource_validate_test.gd`, first change the existing test `test_validate_fully_valid_boss_tier_returns_empty_array` so the boss carries a wind-up: replace

```gdscript
	res.base_damage = 25.0
	res.base_attack_interval = 2.0
	res.boss_attack_range_cells = 4
	var errors: Array[String] = res.validate()
	assert_array(errors).is_empty()
```

with

```gdscript
	res.base_damage = 25.0
	res.base_attack_interval = 2.0
	res.boss_attack_range_cells = 4
	res.hero_attack_windup_seconds = 1.0
	var errors: Array[String] = res.validate()
	assert_array(errors).is_empty()
```

Then append:

```gdscript
# ---------------------------------------------------------------------------
# Hero attack settings (hero-damage spec §4.1, AC-1)
# ---------------------------------------------------------------------------

func _make_valid_elite_attacker() -> MonsterResource:
	var res := _make_valid_standard()
	res.tier = 1
	res.base_damage = 30.0
	res.base_attack_interval = 2.5
	res.boss_attack_range_cells = 2
	res.hero_attack_windup_seconds = 0.9
	return res


func test_validate_valid_elite_attacker_returns_empty_array() -> void:
	assert_array(_make_valid_elite_attacker().validate()).is_empty()


func test_validate_elite_with_zero_base_damage_is_a_valid_non_attacker() -> void:
	var res := _make_valid_standard()
	res.tier = 1
	assert_array(res.validate()).is_empty()


func test_validate_elite_attacker_requires_interval_range_and_windup() -> void:
	var no_interval := _make_valid_elite_attacker()
	no_interval.base_attack_interval = 0.0
	assert_array(no_interval.validate()).contains("ELITE attacker requires base_attack_interval > 0")
	var no_range := _make_valid_elite_attacker()
	no_range.boss_attack_range_cells = 0
	assert_array(no_range.validate()).contains("ELITE attacker requires boss_attack_range_cells > 0")
	var no_windup := _make_valid_elite_attacker()
	no_windup.hero_attack_windup_seconds = 0.0
	assert_array(no_windup.validate()).contains("ELITE attacker requires hero_attack_windup_seconds > 0")


func test_validate_boss_tier_missing_hero_windup_returns_error() -> void:
	var res := _make_valid_standard()
	res.tier = 2
	res.base_damage = 10.0
	res.base_attack_interval = 1.0
	res.boss_attack_range_cells = 3
	res.hero_attack_windup_seconds = 0.0
	assert_array(res.validate()).contains("BOSS tier requires hero_attack_windup_seconds > 0")


func test_validate_standard_with_base_damage_is_rejected() -> void:
	var res := _make_valid_standard()
	res.base_damage = 5.0
	assert_array(res.validate()).contains("STANDARD tier must have base_damage == 0")


func test_validate_negative_windup_is_rejected() -> void:
	var res := _make_valid_standard()
	res.hero_attack_windup_seconds = -0.5
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("hero_attack_windup_seconds must not be negative"))).is_true()


func test_shipped_monsters_all_validate_and_attackers_carry_the_authored_values() -> void:
	# id -> [tier, base_damage, base_attack_interval, boss_attack_range_cells, hero_attack_windup_seconds]
	var expected: Dictionary = {
		&"bog_lurker_elite": [1, 30.0, 2.5, 2, 0.9],
		&"forest_troll_elite": [1, 45.0, 3.0, 2, 1.0],
		&"iron_colossus_elite": [1, 70.0, 4.0, 2, 1.2],
		&"goblin_warlord_boss": [2, 60.0, 3.0, 3, 1.0],
		&"rift_sentinel_boss": [2, 20.0, 2.2, 2, 0.8],
	}
	var all: Dictionary = GGameDataRegistry.get_all_monster_resources()
	for id: StringName in all:
		var res: MonsterResource = all[id]
		assert_array(res.validate()).override_failure_message(String(id)).is_empty()
		if res.tier == 0:
			assert_float(res.base_damage).override_failure_message("%s standard damage" % id).is_equal(0.0)
	for id: StringName in expected:
		assert_bool(all.has(id)).override_failure_message("%s missing" % id).is_true()
		var res: MonsterResource = all[id]
		var want: Array = expected[id]
		assert_int(res.tier).override_failure_message("%s tier" % id).is_equal(want[0])
		assert_float(res.base_damage).override_failure_message("%s damage" % id).is_equal_approx(want[1], 0.0001)
		assert_float(res.base_attack_interval).override_failure_message("%s interval" % id).is_equal_approx(want[2], 0.0001)
		assert_int(res.boss_attack_range_cells).override_failure_message("%s range" % id).is_equal(want[3])
		assert_float(res.hero_attack_windup_seconds).override_failure_message("%s windup" % id).is_equal_approx(want[4], 0.0001)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:/TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/monster/monster_resource_validate_test.gd --ignoreHeadlessMode`
Expected: FAIL (parse/runtime errors: `hero_attack_windup_seconds` is not a property).

- [ ] **Step 3: Implement the resource change**

In `src/core/monster/monster_resource.gd`:

Replace the header comment line

```gdscript
## base_damage / base_attack_interval / boss_attack_range_cells: BOSS-only; set 0 for others.
```

with

```gdscript
## base_damage / base_attack_interval / boss_attack_range_cells / hero_attack_windup_seconds:
## attack settings for the attack-capable tiers (hero-damage spec §4.1). ELITE attacks the
## Hero only; BOSS attacks towers and the Hero. STANDARD must leave them at 0.
```

Replace the export group block

```gdscript
@export_group("BOSS Settings")
@export var boss_attack_range_cells: int = 0
@export var base_damage: float = 0.0
@export var base_attack_interval: float = 0.0
```

with

```gdscript
@export_group("Attack Settings (ELITE / BOSS)")
@export var boss_attack_range_cells: int = 0
@export var base_damage: float = 0.0
@export var base_attack_interval: float = 0.0
## Seconds between an attacker locking the Hero and the hit resolving (hero-damage spec §4.2).
## The boss-to-tower wind-up is a separate fixed frame count in MonsterManager.
@export var hero_attack_windup_seconds: float = 0.0
```

In `validate()`, replace the BOSS block

```gdscript
	if tier == 2:  # BOSS
		if base_damage <= 0.0:
			errors.append("BOSS tier requires base_damage > 0")
		if base_attack_interval <= 0.0:
			errors.append("BOSS tier requires base_attack_interval > 0")
		if boss_attack_range_cells <= 0:
			errors.append("BOSS tier requires boss_attack_range_cells > 0")
```

with

```gdscript
	if tier == 2:  # BOSS
		if base_damage <= 0.0:
			errors.append("BOSS tier requires base_damage > 0")
		if base_attack_interval <= 0.0:
			errors.append("BOSS tier requires base_attack_interval > 0")
		if boss_attack_range_cells <= 0:
			errors.append("BOSS tier requires boss_attack_range_cells > 0")
		if hero_attack_windup_seconds <= 0.0:
			errors.append("BOSS tier requires hero_attack_windup_seconds > 0")
	if tier == 1 and base_damage > 0.0:  # ELITE attacker (base_damage == 0 is a valid non-attacker)
		if base_attack_interval <= 0.0:
			errors.append("ELITE attacker requires base_attack_interval > 0")
		if boss_attack_range_cells <= 0:
			errors.append("ELITE attacker requires boss_attack_range_cells > 0")
		if hero_attack_windup_seconds <= 0.0:
			errors.append("ELITE attacker requires hero_attack_windup_seconds > 0")
	if tier == 0 and base_damage > 0.0:
		errors.append("STANDARD tier must have base_damage == 0")
	if hero_attack_windup_seconds < 0.0:
		errors.append("hero_attack_windup_seconds must not be negative (got %.2f)" % hero_attack_windup_seconds)
```

- [ ] **Step 4: Author the five data files**

Use the Edit tool on each `.tres` (exact strings; each occurs once in its file).

`assets/data/monsters/bog_lurker_elite.tres`: replace

```
boss_attack_range_cells = 0
base_damage = 0.0
base_attack_interval = 0.0
```

with

```
boss_attack_range_cells = 2
base_damage = 30.0
base_attack_interval = 2.5
hero_attack_windup_seconds = 0.9
```

`forest_troll_elite.tres`: same three lines →

```
boss_attack_range_cells = 2
base_damage = 45.0
base_attack_interval = 3.0
hero_attack_windup_seconds = 1.0
```

`iron_colossus_elite.tres`: same three lines →

```
boss_attack_range_cells = 2
base_damage = 70.0
base_attack_interval = 4.0
hero_attack_windup_seconds = 1.2
```

`goblin_warlord_boss.tres`: replace `base_attack_interval = 3.0` with

```
base_attack_interval = 3.0
hero_attack_windup_seconds = 1.0
```

`rift_sentinel_boss.tres`: replace `base_attack_interval = 2.2` with

```
base_attack_interval = 2.2
hero_attack_windup_seconds = 0.8
```

- [ ] **Step 5: Run tests to verify they pass, and prove the monster suites are unaffected**

Run the Step 2 command. Expected: PASS (all old and new cases).
Run: `... -a res://tests/unit/monster/monster_boss_test.gd ...` and `... -a res://tests/unit/monster/monster_spawn_test.gd ...`. Expected: PASS, unchanged.

- [ ] **Step 6: Commit**

```bash
git add src/core/monster/monster_resource.gd assets/data/monsters/bog_lurker_elite.tres assets/data/monsters/forest_troll_elite.tres assets/data/monsters/iron_colossus_elite.tres assets/data/monsters/goblin_warlord_boss.tres assets/data/monsters/rift_sentinel_boss.tres tests/unit/monster/monster_resource_validate_test.gd
git commit -m "Add hero attack wind-up to MonsterResource and author the five attackers

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 2: `HeroIncomingDamageEvent`, the two EventBus signals, and the signal-mirror test

**Files:**
- Create: `src/foundation/event_bus/event_payloads/hero_incoming_damage_event.gd`
- Modify: `src/foundation/event_bus/event_bus.gd` (~lines 379-386 and 470-480)
- Test: `tests/unit/event_bus/event_bus_signals_test.gd`

**Interfaces:**
- Produces: `HeroIncomingDamageEvent` (`amount: float = 0.0`, `damage_type: String = "physical"`, `source_type: int = 0`, `source_entity_id: int = -1`); `signal hero_incoming_damage(payload: HeroIncomingDamageEvent)`; `signal monster_hero_attack_winding_up(entity_id: int, windup_seconds: float)`.

- [ ] **Step 1: Write the failing tests**

In `tests/unit/event_bus/event_bus_signals_test.gd` make four edits.

(a) In the `_LocalBus` mirror, replace `	signal hero_incoming_damage()` with

```gdscript
	signal hero_incoming_damage(payload: HeroIncomingDamageEvent)
```

(b) In the `_LocalBus` mirror, directly after the line `	signal boss_tower_attack_attempted(boss_entity_id: int, target_tower_id: int, base_damage: float, wave_id: int)` add

```gdscript
	signal monster_hero_attack_winding_up(entity_id: int, windup_seconds: float)
```

(c) Replace the count assertion block

```gdscript
	# Assert: live catalogue has 78 signals (70 original + 6 added during sprint 1
	# UX/system design + 2 added by S4-01: scene_transition_started/completed).
	assert_int(game_signal_count).is_equal(78)
```

with

```gdscript
	# Assert: live catalogue has 79 signals (70 original + 6 added during sprint 1
	# UX/system design + 2 added by S4-01: scene_transition_started/completed +
	# 1 added by hero-damage: monster_hero_attack_winding_up).
	assert_int(game_signal_count).is_equal(79)
```

(d) Replace the whole test `test_hero_incoming_damage_fires_with_no_params` (the function under the banner "No-payload signals compile and emit correctly") with:

```gdscript
func test_hero_incoming_damage_carries_a_resource_payload() -> void:
	# Arrange
	var state := {"got": null}
	var cb := func(p: HeroIncomingDamageEvent) -> void: state.got = p
	_bus.hero_incoming_damage.connect(cb)
	var ev := HeroIncomingDamageEvent.new()
	ev.amount = 45.0
	ev.source_entity_id = 7

	# Act
	_bus.hero_incoming_damage.emit(ev)

	# Assert
	assert_object(state.got).is_not_null()
	assert_float((state.got as HeroIncomingDamageEvent).amount).is_equal(45.0)
	assert_int((state.got as HeroIncomingDamageEvent).source_entity_id).is_equal(7)
	_bus.hero_incoming_damage.disconnect(cb)


func test_monster_hero_attack_winding_up_carries_entity_and_seconds() -> void:
	var state := {"id": -1, "secs": 0.0}
	var cb := func(entity_id: int, windup_seconds: float) -> void:
		state.id = entity_id
		state.secs = windup_seconds
	_bus.monster_hero_attack_winding_up.connect(cb)
	_bus.monster_hero_attack_winding_up.emit(12, 0.9)
	assert_int(state.id).is_equal(12)
	assert_float(state.secs).is_equal_approx(0.9, 0.0001)
	_bus.monster_hero_attack_winding_up.disconnect(cb)


func test_hero_incoming_damage_event_defaults() -> void:
	var ev := HeroIncomingDamageEvent.new()
	assert_float(ev.amount).is_equal(0.0)
	assert_str(ev.damage_type).is_equal("physical")
	assert_int(ev.source_type).is_equal(0)
	assert_int(ev.source_entity_id).is_equal(-1)


## The mirror above must match the REAL autoload; this checks the two changed signals on it.
func test_real_bus_declares_the_hero_damage_signals_with_the_right_arity() -> void:
	var arity: Dictionary = {}
	for sig: Dictionary in GEventBus.get_signal_list():
		arity[sig["name"]] = (sig["args"] as Array).size()
	assert_bool(arity.has("hero_incoming_damage")).is_true()
	assert_int(arity["hero_incoming_damage"]).is_equal(1)
	assert_bool(arity.has("monster_hero_attack_winding_up")).is_true()
	assert_int(arity["monster_hero_attack_winding_up"]).is_equal(2)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:/TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/event_bus/event_bus_signals_test.gd --ignoreHeadlessMode`
Expected: FAIL (`HeroIncomingDamageEvent` not found).

- [ ] **Step 3: Create the payload**

Create `src/foundation/event_bus/event_payloads/hero_incoming_damage_event.gd`:

```gdscript
class_name HeroIncomingDamageEvent
extends Resource

## Event-payload Resource for the hero_incoming_damage EventBus signal
## (hero-damage spec §4.3). Deliberately a Resource even though it has four fields
## (ADR-0001 Rule 3 only requires it at 5+): new fields can be added later without
## changing the signal signature again.
## ADR-0009: Event-payload Resources are short-lived; never saved as .tres files.
##
## Emitted by: Monster System, when an ELITE/BOSS wind-up completes with the Hero
## still in range. Key subscribers: Damage & Status (mitigation, then hero_damage_taken).

## Raw damage BEFORE mitigation.
@export var amount: float = 0.0

## "physical" (armor), "fire" / "frost" (elemental resist), anything else is unmitigated.
@export var damage_type: String = "physical"

## 0 = monster attack. 1 = status effect and 2 = environmental are reserved.
@export var source_type: int = 0

## The attacking monster's entity id, or -1 when not applicable.
@export var source_entity_id: int = -1
```

- [ ] **Step 4: Change the real bus**

In `src/foundation/event_bus/event_bus.gd`:

Replace

```gdscript
## Emitted by any future source that inflicts damage on the hero.
## MVP: no sources exist. Payload TBD — defined by the future system's GDD.
## Key subscribers: Damage & Status.
signal hero_incoming_damage()
```

with

```gdscript
## An attacker's hit lands on the Hero, BEFORE mitigation (hero-damage spec §4.3).
## Resource payload (HeroIncomingDamageEvent). Emitted by Monster System when an
## ELITE/BOSS wind-up completes with the Hero still in range.
## Key subscribers: Damage & Status (armor/resist mitigation, then hero_damage_taken).
signal hero_incoming_damage(payload: HeroIncomingDamageEvent)

## An ELITE/BOSS locked the Hero and began its wind-up (hero-damage spec §4.3).
## No subscriber yet: the wind-up presentation follow-up spec subscribes to this.
signal monster_hero_attack_winding_up(entity_id: int, windup_seconds: float)
```

Replace the doc comment above `hero_damage_taken`

```gdscript
## Deferred one frame from hero_incoming_damage after D4 armor reduction applied.
## MVP: no active attack sources exist — pipeline is scaffolding only.
```

with

```gdscript
## Deferred one frame from hero_incoming_damage after armor/resist mitigation applied.
## Sources: ELITE/BOSS attacks (hero-damage spec); see also the QA-only kill-hero key.
```

- [ ] **Step 5: Reimport and run tests to verify they pass**

Run the editor-mode reimport command from Global Constraints (registers `HeroIncomingDamageEvent`, generates its `.uid`), then the Step 2 command. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/foundation/event_bus/event_payloads/hero_incoming_damage_event.gd src/foundation/event_bus/event_payloads/hero_incoming_damage_event.gd.uid src/foundation/event_bus/event_bus.gd tests/unit/event_bus/event_bus_signals_test.gd
git commit -m "Add HeroIncomingDamageEvent payload and hero attack wind-up signal

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 3: Damage & Status Rule V (armor and resist mitigation)

**Files:**
- Modify: `src/core/damage_status/damage_status.gd` (constants near line 21; `_ready`/`_exit_tree` ~lines 77-92; new methods after `_on_hero_died`)
- Test: `tests/unit/damage_status/hero_incoming_damage_test.gd`

**Interfaces:**
- Consumes: `HeroIncomingDamageEvent` (Task 2), `EventBusSpy` (`tests/helpers/event_bus_spy.gd`).
- Produces: `DamageStatus.set_hero_stats(provider: Object) -> void` (provider exposes `get_effective_stat(stat: StringName) -> float`); `static func DamageStatus.mitigate_hero_incoming(amount: float, damage_type: String, armor: float, resist: float) -> int`; handler `_on_hero_incoming_damage(event: HeroIncomingDamageEvent)`; consts `HERO_INCOMING_ARMOR_COEFFICIENT = 100.0`, `HERO_INCOMING_RESIST_CAP = 0.75`.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/damage_status/hero_incoming_damage_test.gd`:

```gdscript
extends GdUnitTestSuite

## Unit tests for Damage & Status Rule V, the Hero incoming-damage pipeline
## (hero-damage spec §4.4 / §5, AC-6, AC-9).

class _StubHeroStats extends RefCounted:
	var stats: Dictionary = {}

	func get_effective_stat(stat: StringName) -> float:
		return float(stats.get(stat, 0.0))


var _ds: DamageStatus
var _spy: EventBusSpy


func before_test() -> void:
	_ds = DamageStatus.new()
	add_child(_ds)  # Required: the handler awaits get_tree().process_frame
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_damage_taken)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if is_instance_valid(_ds):
		_ds.queue_free()
		await get_tree().process_frame
	_ds = null


func _ev(amount: float, damage_type: String = "physical", source_type: int = 0) -> HeroIncomingDamageEvent:
	var ev := HeroIncomingDamageEvent.new()
	ev.amount = amount
	ev.damage_type = damage_type
	ev.source_type = source_type
	return ev


# --- pure mitigation -------------------------------------------------------

func test_physical_with_no_armor_is_unmitigated() -> void:
	assert_int(DamageStatus.mitigate_hero_incoming(45.0, "physical", 0.0, 0.0)).is_equal(45)


func test_physical_armor_floors_the_result() -> void:
	# floor(45 x 100 / 152) = 29 ; floor(70 x 100 / 152) = 46
	assert_int(DamageStatus.mitigate_hero_incoming(45.0, "physical", 52.0, 0.0)).is_equal(29)
	assert_int(DamageStatus.mitigate_hero_incoming(70.0, "physical", 52.0, 0.0)).is_equal(46)


func test_armor_cannot_reduce_a_hit_below_one() -> void:
	assert_int(DamageStatus.mitigate_hero_incoming(1.0, "physical", 1000.0, 0.0)).is_equal(1)


func test_negative_armor_is_treated_as_zero() -> void:
	assert_int(DamageStatus.mitigate_hero_incoming(45.0, "physical", -50.0, 0.0)).is_equal(45)


func test_fire_and_frost_use_the_resist_fraction() -> void:
	assert_int(DamageStatus.mitigate_hero_incoming(100.0, "fire", 999.0, 0.5)).is_equal(50)
	assert_int(DamageStatus.mitigate_hero_incoming(100.0, "frost", 999.0, 0.2)).is_equal(80)


func test_resist_is_capped_at_seventy_five_percent() -> void:
	assert_int(DamageStatus.mitigate_hero_incoming(100.0, "fire", 0.0, 0.9)).is_equal(25)


func test_unknown_damage_type_is_unmitigated() -> void:
	assert_int(DamageStatus.mitigate_hero_incoming(30.0, "poison", 500.0, 0.75)).is_equal(30)


# --- handler ---------------------------------------------------------------

func test_incoming_damage_is_mitigated_and_emitted_one_frame_later() -> void:
	var stub := _StubHeroStats.new()
	stub.stats[&"armor"] = 52.0
	_ds.set_hero_stats(stub)
	_ds._on_hero_incoming_damage(_ev(45.0, "physical", 0))
	assert_int(_spy.count("hero_damage_taken")).is_equal(0)  # deferred one frame
	await get_tree().process_frame
	assert_int(_spy.count("hero_damage_taken")).is_equal(1)
	var args: Array = (_spy.emissions["hero_damage_taken"] as Array)[0] as Array
	assert_int(args[0]).is_equal(29)
	assert_int(args[1]).is_equal(0)


func test_source_type_is_forwarded() -> void:
	_ds._on_hero_incoming_damage(_ev(10.0, "physical", 1))
	await get_tree().process_frame
	var args: Array = (_spy.emissions["hero_damage_taken"] as Array)[0] as Array
	assert_int(args[1]).is_equal(1)


func test_without_a_stat_provider_armor_and_resists_are_zero() -> void:
	_ds._on_hero_incoming_damage(_ev(45.0, "physical"))
	_ds._on_hero_incoming_damage(_ev(40.0, "fire"))
	await get_tree().process_frame
	var emissions: Array = _spy.emissions["hero_damage_taken"] as Array
	assert_int(emissions.size()).is_equal(2)
	assert_int((emissions[0] as Array)[0]).is_equal(45)
	assert_int((emissions[1] as Array)[0]).is_equal(40)


func test_fire_damage_reads_the_fire_resist_stat() -> void:
	var stub := _StubHeroStats.new()
	stub.stats[&"elemental_resist_fire"] = 0.5
	stub.stats[&"elemental_resist_frost"] = 0.0
	_ds.set_hero_stats(stub)
	_ds._on_hero_incoming_damage(_ev(100.0, "fire"))
	_ds._on_hero_incoming_damage(_ev(100.0, "frost"))
	await get_tree().process_frame
	var emissions: Array = _spy.emissions["hero_damage_taken"] as Array
	assert_int((emissions[0] as Array)[0]).is_equal(50)
	assert_int((emissions[1] as Array)[0]).is_equal(100)


func test_stats_are_read_at_hit_time_not_emit_time() -> void:
	var stub := _StubHeroStats.new()
	stub.stats[&"armor"] = 100.0
	_ds.set_hero_stats(stub)
	_ds._on_hero_incoming_damage(_ev(100.0))
	stub.stats[&"armor"] = 0.0  # changes during the deferral frame
	await get_tree().process_frame
	var args: Array = (_spy.emissions["hero_damage_taken"] as Array)[0] as Array
	assert_int(args[0]).is_equal(50)  # floor(100 x 100 / 200) with the armor at hit time


func test_real_bus_delivers_hero_incoming_damage_to_the_pipeline() -> void:
	GEventBus.hero_incoming_damage.emit(_ev(30.0))
	await get_tree().process_frame
	assert_int(_spy.count("hero_damage_taken")).is_equal(1)


func test_subscription_is_disconnected_on_exit() -> void:
	var baseline: int = GEventBus.hero_incoming_damage.get_connections().size()
	remove_child(_ds)
	_ds.free()
	_ds = null
	assert_int(GEventBus.hero_incoming_damage.get_connections().size()).is_equal(baseline - 1)
```

- [ ] **Step 2: Run tests to verify they fail**

Run the reimport command (so the test file's class references resolve), then: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:/TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/damage_status/hero_incoming_damage_test.gd --ignoreHeadlessMode`
Expected: FAIL (`mitigate_hero_incoming` / `_on_hero_incoming_damage` / `set_hero_stats` not defined).

- [ ] **Step 3: Implement**

In `src/core/damage_status/damage_status.gd`:

After the existing constant `const COMBAT_VARIANCE_MAX: float = 1.05` add:

```gdscript

## Hero-damage spec §4.4 (damage-status.md Rule V): incoming damage to the Hero.
## Physical uses the armor coefficient; fire/frost use the resist stat, capped.
const HERO_INCOMING_ARMOR_COEFFICIENT: float = 100.0
const HERO_INCOMING_RESIST_CAP: float = 0.75
```

After the `_lifesteal_pending` variable declaration add:

```gdscript

## Injected stat provider for Rule V (exposes get_effective_stat(stat: StringName) -> float).
## Set by the mission scene at assembly (same DI pattern as MonsterManager.set_swarm_renderer).
## Null means armor and resists are treated as 0.
var _hero_stats: Object = null
```

In `_ready()` add as the last line:

```gdscript
	GEventBus.hero_incoming_damage.connect(_on_hero_incoming_damage)
```

In `_exit_tree()` add as the last line:

```gdscript
	GEventBus.hero_incoming_damage.disconnect(_on_hero_incoming_damage)
```

Add these methods directly after `_on_hero_died()` (end of the file):

```gdscript


## Hero-damage spec §4.4: DI seam for the Hero's armor and elemental resists.
func set_hero_stats(provider: Object) -> void:
	_hero_stats = provider


func _hero_stat(stat: StringName) -> float:
	if _hero_stats == null or not is_instance_valid(_hero_stats) or not _hero_stats.has_method(&"get_effective_stat"):
		return 0.0
	return float(_hero_stats.call(&"get_effective_stat", stat))


## Pure Rule V mitigation (unit-tested directly). "physical": armor; "fire"/"frost": the
## caller passes the matching resist fraction; any other type is unmitigated. Floored at 1
## so no hit is ever fully negated.
static func mitigate_hero_incoming(amount: float, damage_type: String, armor: float, resist: float) -> int:
	var mitigated: float = amount
	match damage_type:
		"physical":
			mitigated = amount * HERO_INCOMING_ARMOR_COEFFICIENT / (maxf(0.0, armor) + HERO_INCOMING_ARMOR_COEFFICIENT)
		"fire", "frost":
			mitigated = amount * (1.0 - clampf(resist, 0.0, HERO_INCOMING_RESIST_CAP))
	return maxi(1, floori(mitigated))


## Rule V: mitigate using the Hero's stats AT HIT TIME, defer one frame (same cascade budget as
## monster_damage_taken, Rule V.2), then emit hero_damage_taken for Hero to apply. Hero itself owns
## the phase guard (Rule 20) and DEFEAT at 0 HP.
func _on_hero_incoming_damage(event: HeroIncomingDamageEvent) -> void:
	var resist: float = 0.0
	match event.damage_type:
		"fire":
			resist = _hero_stat(&"elemental_resist_fire")
		"frost":
			resist = _hero_stat(&"elemental_resist_frost")
	var effective: int = mitigate_hero_incoming(event.amount, event.damage_type, _hero_stat(&"armor"), resist)
	var source_type: int = event.source_type
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	GEventBus.hero_damage_taken.emit(effective, source_type)
```

- [ ] **Step 4: Run tests to verify they pass, plus the existing D&S suite**

Run the Step 2 command. Expected: PASS.
Run: `... -a res://tests/unit/damage_status/damage_status_test.gd ...`. Expected: PASS, unchanged.

- [ ] **Step 5: Commit**

```bash
git add src/core/damage_status/damage_status.gd tests/unit/damage_status/hero_incoming_damage_test.gd tests/unit/damage_status/hero_incoming_damage_test.gd.uid
git commit -m "Implement Damage & Status Rule V: armor and resist mitigation of Hero damage

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 4: Hero wave-clear heal

**Files:**
- Modify: `src/core/hero/hero.gd` (constants ~line 201; `_on_wave_completed` ~line 1104)
- Test: `tests/unit/hero/hero_wave_clear_heal_test.gd`

**Interfaces:**
- Produces: `Hero.WAVE_CLEAR_HEAL_FRACTION: float = 0.25`; `_on_wave_completed` also heals `roundi(_max_hp x 0.25)` via the existing `_on_hero_healed()`.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/hero/hero_wave_clear_heal_test.gd`:

```gdscript
extends GdUnitTestSuite

## Unit tests for Hero's wave-clear partial heal (hero-damage spec §4.5, AC-7).

var _hero: Hero


func before_test() -> void:
	GInventory.reset_to_defaults()
	_hero = Hero.new()
	add_child(_hero)
	_hero.set_process(false)
	_hero._max_hp = 500.0


func after_test() -> void:
	GInventory.reset_to_defaults()
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


func test_wave_clear_heals_a_quarter_of_max_hp() -> void:
	_hero._phase = Hero.HeroPhase.COMBAT
	_hero._current_hp = 100.0
	_hero._on_wave_completed(1, 0, false)
	assert_float(_hero._current_hp).is_equal_approx(225.0, 0.0001)


func test_wave_clear_heal_is_clamped_to_max_hp() -> void:
	_hero._phase = Hero.HeroPhase.COMBAT
	_hero._current_hp = 450.0
	_hero._on_wave_completed(1, 0, false)
	assert_float(_hero._current_hp).is_equal_approx(500.0, 0.0001)


func test_wave_clear_heal_applies_during_intermission() -> void:
	_hero._phase = Hero.HeroPhase.INTERMISSION
	_hero._current_hp = 100.0
	_hero._on_wave_completed(1, 0, false)
	assert_float(_hero._current_hp).is_equal_approx(225.0, 0.0001)


func test_wave_clear_never_heals_a_dead_hero() -> void:
	_hero._phase = Hero.HeroPhase.DEAD
	_hero._current_hp = 0.0
	_hero._on_wave_completed(1, 0, false)
	assert_float(_hero._current_hp).is_equal_approx(0.0, 0.0001)


func test_wave_clear_heal_emits_hero_health_changed() -> void:
	_hero._phase = Hero.HeroPhase.COMBAT
	_hero._current_hp = 100.0
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.hero_health_changed)
	_hero._on_wave_completed(1, 0, false)
	assert_int(spy.count("hero_health_changed")).is_equal(1)
	spy.disconnect_all()


func test_wave_clear_with_zero_max_hp_is_a_no_op() -> void:
	_hero._max_hp = 0.0
	_hero._phase = Hero.HeroPhase.COMBAT
	_hero._current_hp = 0.0
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.hero_health_changed)
	_hero._on_wave_completed(1, 0, false)
	assert_int(spy.count("hero_health_changed")).is_equal(0)
	spy.disconnect_all()


func test_the_heal_fraction_constant_is_a_quarter() -> void:
	assert_float(Hero.WAVE_CLEAR_HEAL_FRACTION).is_equal_approx(0.25, 0.0001)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:/TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/hero/hero_wave_clear_heal_test.gd --ignoreHeadlessMode`
Expected: FAIL (`WAVE_CLEAR_HEAL_FRACTION` not defined).

- [ ] **Step 3: Implement**

In `src/core/hero/hero.gd`, after the line `const MISSION_COMPLETION_XP: int = 150` add:

```gdscript

## Hero-damage spec §4.5: fraction of max HP recovered at each wave clear (first-pass tuning
## knob, unplaytested). Lifesteal remains the way to sustain beyond this.
const WAVE_CLEAR_HEAL_FRACTION: float = 0.25
```

Replace the body of `_on_wave_completed`:

```gdscript
func _on_wave_completed(_wave_number: int, _enemies_remaining: int, _was_boss_breached: bool) -> void:
	_grant_xp(WAVE_COMPLETION_XP)
```

with

```gdscript
func _on_wave_completed(_wave_number: int, _enemies_remaining: int, _was_boss_breached: bool) -> void:
	_grant_xp(WAVE_COMPLETION_XP)
	# Hero-damage spec §4.5: partial heal through the existing path, so the phase guard
	# (a DEAD Hero is never healed) and the overheal clamp both apply.
	var heal: int = roundi(_max_hp * WAVE_CLEAR_HEAL_FRACTION)
	if heal > 0:
		_on_hero_healed(heal)
```

- [ ] **Step 4: Run tests to verify they pass, plus the neighbouring Hero suites**

Run the Step 2 command. Expected: PASS.
Run: `... -a res://tests/unit/hero/hero_leveling_test.gd ...` and `... -a res://tests/integration/hero/hero_lifecycle_test.gd ...`. Expected: PASS, unchanged.

- [ ] **Step 5: Commit**

```bash
git add src/core/hero/hero.gd tests/unit/hero/hero_wave_clear_heal_test.gd tests/unit/hero/hero_wave_clear_heal_test.gd.uid
git commit -m "Heal the Hero for a quarter of max HP at each wave clear

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 5: MonsterManager: Hero cache and elite Hero attacks

**Files:**
- Modify: `src/core/monster/monster_entity.gd` (~line 129), `src/core/monster/monster_manager.gd` (constants ~line 42; `_ready`/`_exit_tree`; `_physics_process`; `_on_wave_started`; new methods after `_boss_execute_scan`)
- Test: `tests/unit/monster/monster_hero_attack_test.gd`

**Interfaces:**
- Consumes: `HeroIncomingDamageEvent`, the two signals (Task 2); `MonsterResource.hero_attack_windup_seconds` (Task 1).
- Produces: `MonsterEntity.hero_windup_remaining: float`; `MonsterManager.HERO_TARGET_ID := -2`; state `_hero_cell: Vector2i = Vector2i(-1, -1)`, `_hero_alive: bool = false`; `_pass2b_hero_attacks(delta: float)`; helpers `_hero_targetable() -> bool`, `_hero_distance(entity: MonsterEntity) -> int`, `_hero_in_range(entity: MonsterEntity) -> bool`, `_begin_hero_windup(entity: MonsterEntity)`, `_hero_windup_tick(entity: MonsterEntity, delta: float)`, `_elite_scan(entity: MonsterEntity)`; handlers `_on_hero_position_changed(grid_position: Vector2i)`, `_on_hero_died()`.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/monster/monster_hero_attack_test.gd`:

```gdscript
extends GdUnitTestSuite

## Unit tests for MonsterManager's Hero attacks (hero-damage spec §4.2, AC-2/3/5).
## Stub/fixture pattern mirrors monster_boss_test.gd. The grid stub lets each test place
## the monster's cell and towers at chosen Chebyshev distances.

class _StubGrid extends RefCounted:
	var monster_cell: Vector2i = Vector2i(0, 0)
	## tower_id -> Chebyshev distance from the monster; a tower is "in range" of radius r
	## when its distance <= r (matches Grid.get_towers_in_range's semantics).
	var towers_at_distance: Dictionary = {}

	func get_cell_type(_cell: Vector2i) -> int:
		return Grid.CellType.SPAWN

	func cell_to_world(cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x) * 64.0, float(cell.y) * 64.0)

	func world_to_cell(_pos: Vector2) -> Vector2i:
		return monster_cell

	func get_towers_in_range(_center: Vector2i, radius: int) -> Array[int]:
		var out: Array[int] = []
		for id: int in towers_at_distance:
			if int(towers_at_distance[id]) <= radius:
				out.append(id)
		return out


class _StubPathfinding extends RefCounted:
	func find_path(_from: Vector2i, _tier: int) -> Array[Vector2i]:
		return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
				Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0), Vector2i(9, 0)]


const SPAWN_CELL := Vector2i(0, 0)
const HERO_NEAR := Vector2i(1, 0)  # Chebyshev distance 1 from the monster at (0,0)
const HERO_FAR := Vector2i(9, 9)

var _mm: MonsterManager
var _grid: _StubGrid
var _spy: EventBusSpy


func before_test() -> void:
	_grid = _StubGrid.new()
	_mm = MonsterManager.new()
	add_child(_mm)  # BEFORE overriding DI seams (see monster_boss_test.gd)
	_mm._grid = _grid
	_mm._pathfinding = _StubPathfinding.new()
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	_mm._hero_alive = true
	_mm._hero_cell = HERO_NEAR
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_incoming_damage)
	_spy.watch(GEventBus.monster_hero_attack_winding_up)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _mm != null and is_instance_valid(_mm):
		for e: MonsterEntity in _mm.active_monsters:
			if is_instance_valid(e):
				e.free()
		for e: MonsterEntity in _mm.spawning_entities:
			if is_instance_valid(e):
				e.free()
		remove_child(_mm)
		_mm.free()
	_mm = null


func _make_attacker(tier: int, damage: float, interval: float, range_cells: int, windup: float) -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = &"attacker_test"
	res.display_name = "Attacker"
	res.tier = tier
	res.base_hp = 500.0
	res.base_speed = 0.5
	res.base_damage = damage
	res.base_attack_interval = interval
	res.boss_attack_range_cells = range_cells
	res.hero_attack_windup_seconds = windup
	res.drop_table_id = &"goblin_drops"
	return res


func _spawn(res: MonsterResource) -> MonsterEntity:
	_mm._resource_table[res.monster_id] = res
	return _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)


func _elite() -> MonsterEntity:
	return _spawn(_make_attacker(1, 30.0, 2.5, 2, 1.0))


# --- cache and lifecycle ---------------------------------------------------

func test_position_changed_updates_the_hero_cell_cache() -> void:
	_mm._on_hero_position_changed(Vector2i(4, 7))
	assert_bool(_mm._hero_cell == Vector2i(4, 7)).is_true()


func test_wave_started_marks_the_hero_alive() -> void:
	_mm._hero_alive = false
	_mm._on_wave_started(1, 6, 1.0)
	assert_bool(_mm._hero_alive).is_true()


func test_hero_died_clears_windups_and_stops_targeting() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.1)  # starts a wind-up
	assert_float(elite.hero_windup_remaining).is_greater(0.0)
	_mm._on_hero_died()
	assert_bool(_mm._hero_alive).is_false()
	assert_float(elite.hero_windup_remaining).is_equal(0.0)
	assert_int(elite.boss_locked_target_id).is_equal(-1)


func test_new_subscriptions_are_disconnected_on_exit() -> void:
	var pos_baseline: int = GEventBus.hero_position_changed.get_connections().size()
	var died_baseline: int = GEventBus.hero_died.get_connections().size()
	remove_child(_mm)  # _exit_tree disconnects (ADR-0001 Rule 6)
	assert_int(GEventBus.hero_position_changed.get_connections().size()).is_equal(pos_baseline - 1)
	assert_int(GEventBus.hero_died.get_connections().size()).is_equal(died_baseline - 1)
	_mm.free()
	_mm = null  # after_test guards on null (a second _exit_tree would disconnect twice)


# --- elite wind-up ---------------------------------------------------------

func test_elite_with_hero_in_range_starts_a_windup_and_announces_it() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.1)
	assert_float(elite.hero_windup_remaining).is_greater(0.0)
	assert_int(elite.boss_locked_target_id).is_equal(MonsterManager.HERO_TARGET_ID)
	assert_int(_spy.count("monster_hero_attack_winding_up")).is_equal(1)
	var args: Array = (_spy.emissions["monster_hero_attack_winding_up"] as Array)[0] as Array
	assert_int(args[0]).is_equal(elite.entity_id)
	assert_float(args[1]).is_equal_approx(1.0, 0.0001)


func test_elite_does_not_wind_up_when_the_hero_is_out_of_range() -> void:
	var elite := _elite()
	_mm._hero_cell = HERO_FAR
	_mm._pass2b_hero_attacks(0.1)
	assert_float(elite.hero_windup_remaining).is_equal(0.0)
	assert_int(_spy.count("monster_hero_attack_winding_up")).is_equal(0)


func test_elite_does_not_wind_up_when_the_hero_is_dead_or_position_unknown() -> void:
	var elite := _elite()
	_mm._hero_alive = false
	_mm._pass2b_hero_attacks(0.1)
	assert_float(elite.hero_windup_remaining).is_equal(0.0)
	_mm._hero_alive = true
	_mm._hero_cell = Vector2i(-1, -1)
	_mm._pass2b_hero_attacks(0.1)
	assert_float(elite.hero_windup_remaining).is_equal(0.0)


func test_standard_and_zero_damage_elites_never_wind_up() -> void:
	var standard := _spawn(_make_attacker(0, 0.0, 0.0, 0, 0.0))
	_mm._pass2b_hero_attacks(0.1)
	assert_float(standard.hero_windup_remaining).is_equal(0.0)
	var quiet_res := _make_attacker(1, 0.0, 0.0, 0, 0.0)
	quiet_res.monster_id = &"quiet_elite"
	var quiet := _spawn(quiet_res)
	_mm._pass2b_hero_attacks(0.1)
	assert_float(quiet.hero_windup_remaining).is_equal(0.0)
	assert_int(_spy.count("monster_hero_attack_winding_up")).is_equal(0)


# --- fire / whiff ----------------------------------------------------------

func test_elite_fires_exactly_once_when_the_windup_completes() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.5)  # scan + start wind-up (1.0 s), tick 0.5
	assert_int(_spy.count("hero_incoming_damage")).is_equal(0)
	_mm._pass2b_hero_attacks(0.5)  # wind-up reaches 0 -> fires
	assert_int(_spy.count("hero_incoming_damage")).is_equal(1)
	var ev: HeroIncomingDamageEvent = (_spy.emissions["hero_incoming_damage"] as Array)[0][0] as HeroIncomingDamageEvent
	assert_float(ev.amount).is_equal_approx(30.0, 0.0001)
	assert_str(ev.damage_type).is_equal("physical")
	assert_int(ev.source_type).is_equal(0)
	assert_int(ev.source_entity_id).is_equal(elite.entity_id)
	assert_float(elite.hero_windup_remaining).is_equal(0.0)
	assert_int(elite.boss_locked_target_id).is_equal(-1)
	assert_float(elite.boss_attack_cooldown_remaining).is_greater(0.0)


func test_a_hero_who_left_range_during_the_windup_is_a_whiff() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.5)
	_mm._hero_cell = HERO_FAR  # the Hero dodges
	_mm._pass2b_hero_attacks(0.5)
	assert_int(_spy.count("hero_incoming_damage")).is_equal(0)
	assert_float(elite.hero_windup_remaining).is_equal(0.0)
	assert_float(elite.boss_attack_cooldown_remaining).is_greater(0.0)  # the cooldown is still spent


func test_no_new_windup_while_the_cooldown_is_running() -> void:
	var elite := _elite()
	elite.boss_attack_cooldown_remaining = 2.0
	_mm._elite_scan(elite)
	assert_float(elite.hero_windup_remaining).is_equal(0.0)
	elite.boss_attack_cooldown_remaining = 0.0
	_mm._elite_scan(elite)
	assert_float(elite.hero_windup_remaining).is_greater(0.0)


func test_a_monster_killed_mid_windup_never_fires() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.5)
	elite.lifecycle_state = MonsterEntity.State.DEAD
	_mm._pass2b_hero_attacks(0.5)
	assert_int(_spy.count("hero_incoming_damage")).is_equal(0)


func test_the_cooldown_ticks_down_for_elites() -> void:
	var elite := _elite()
	_mm._hero_cell = HERO_FAR
	elite.boss_attack_cooldown_remaining = 2.0
	_mm._pass2b_hero_attacks(0.5)
	assert_float(elite.boss_attack_cooldown_remaining).is_equal_approx(1.5, 0.0001)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:/TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/monster/monster_hero_attack_test.gd --ignoreHeadlessMode`
Expected: FAIL (`_hero_alive`, `_pass2b_hero_attacks` etc. not defined).

- [ ] **Step 3: Implement the entity field**

In `src/core/monster/monster_entity.gd`, directly after the `boss_locked_target_id` declaration (`var boss_locked_target_id: int = -1`) add:

```gdscript

## Seconds remaining in an in-flight Hero-targeted wind-up (hero-damage spec §4.2).
## 0 = no Hero wind-up. A monster has at most one wind-up in flight (tower or Hero);
## boss_locked_target_id holds MonsterManager.HERO_TARGET_ID while this is > 0.
var hero_windup_remaining: float = 0.0
```

- [ ] **Step 4: Implement the manager changes**

In `src/core/monster/monster_manager.gd`:

(a) After `const BOSS_ATTACK_PREPARE_FRAMES := 4` add:

```gdscript
## Hero-damage spec §4.2: boss_locked_target_id sentinel meaning "the Hero" (tower ids are >= 0).
const HERO_TARGET_ID := -2
```

(b) Add the state near the other private state (next to `var _is_wave_active: bool = false`):

```gdscript
## Hero-damage spec §4.2: the Hero's last known grid cell (from hero_position_changed) and
## whether it can be targeted. The cell is deliberately NOT cleared on wave/mission reset:
## Hero emits only when its cell changes, so clearing it would leave it unrefreshed.
var _hero_cell: Vector2i = Vector2i(-1, -1)
var _hero_alive: bool = false
```

(c) In `_ready()` add as the last two lines:

```gdscript
	GEventBus.hero_position_changed.connect(_on_hero_position_changed)
	GEventBus.hero_died.connect(_on_hero_died)
```

In `_exit_tree()` add as the last two lines:

```gdscript
	GEventBus.hero_position_changed.disconnect(_on_hero_position_changed)
	GEventBus.hero_died.disconnect(_on_hero_died)
```

(d) In `_physics_process`, add the new pass directly after `_pass2_boss_logic(delta)`:

```gdscript
	_pass2b_hero_attacks(delta)
```

(e) In `_on_wave_started(...)`, add as its first statement (before `_current_wave_index = wave_number`):

```gdscript
	_hero_alive = true
```

(f) Add these methods directly after `_boss_execute_scan` (before the "Pass 3 — Movement" banner):

```gdscript
# ---------------------------------------------------------------------------
# Pass 2b — Hero attacks (hero-damage spec §4.2)
# ---------------------------------------------------------------------------

func _on_hero_position_changed(grid_position: Vector2i) -> void:
	_hero_cell = grid_position


func _on_hero_died() -> void:
	_hero_alive = false
	# Untyped loop variable on purpose: a typed one errors on an already-freed entity, so the
	# is_instance_valid() guard must run first (same rationale as _pass1b_status_effects).
	for entity in active_monsters:
		if not is_instance_valid(entity):
			continue
		entity.hero_windup_remaining = 0.0
		if entity.boss_locked_target_id == HERO_TARGET_ID:
			entity.boss_locked_target_id = -1


## True when the Hero can currently be targeted: alive and its cell is known.
func _hero_targetable() -> bool:
	return _hero_alive and _hero_cell.x >= 0 and _hero_cell.y >= 0


## Chebyshev distance in grid cells from the monster's current cell to the Hero's cached cell.
func _hero_distance(entity: MonsterEntity) -> int:
	var cell: Vector2i = _grid.world_to_cell(entity.global_position)
	return maxi(absi(cell.x - _hero_cell.x), absi(cell.y - _hero_cell.y))


func _hero_in_range(entity: MonsterEntity) -> bool:
	return _hero_targetable() and _hero_distance(entity) <= entity.resource.boss_attack_range_cells


## Locks the Hero and starts the seconds-based wind-up; announces it for presentation/audio.
func _begin_hero_windup(entity: MonsterEntity) -> void:
	entity.boss_locked_target_id = HERO_TARGET_ID
	entity.hero_windup_remaining = entity.resource.hero_attack_windup_seconds
	GEventBus.monster_hero_attack_winding_up.emit(entity.entity_id, entity.resource.hero_attack_windup_seconds)


## Counts the wind-up down; at 0 the cooldown restarts, the lock clears, and the hit lands only if
## the Hero is STILL in range (otherwise a whiff: no damage, no event, cooldown still spent).
func _hero_windup_tick(entity: MonsterEntity, delta: float) -> void:
	entity.hero_windup_remaining -= delta
	if entity.hero_windup_remaining > 0.0:
		return
	entity.hero_windup_remaining = 0.0
	entity.boss_locked_target_id = -1
	entity.boss_attack_cooldown_remaining = entity.resource.base_attack_interval
	if not _hero_in_range(entity):
		return
	var ev := HeroIncomingDamageEvent.new()
	ev.amount = entity.resource.base_damage
	ev.damage_type = "physical"
	ev.source_type = 0
	ev.source_entity_id = entity.entity_id
	GEventBus.hero_incoming_damage.emit(ev)


## ELITE scan: locks the Hero when the cooldown is clear, no wind-up is in flight, and the Hero is
## in range. Elites never target towers.
func _elite_scan(entity: MonsterEntity) -> void:
	if entity.boss_attack_cooldown_remaining > 0.0 or entity.hero_windup_remaining > 0.0:
		return
	if _hero_in_range(entity):
		_begin_hero_windup(entity)


## Runs after the boss pass. Handles Hero wind-ups for every attack-capable monster and the full
## scan/cooldown loop for ELITEs (bosses scan and tick their cooldown in _pass2_boss_logic).
## Order mirrors the boss pass: scan (elites only, when idle), then tick any wind-up in the SAME
## frame it started, then tick the elite cooldown. Untyped loop variable on purpose (see
## _on_hero_died): the is_instance_valid() guard must run before any member access.
func _pass2b_hero_attacks(delta: float) -> void:
	for entity in active_monsters:
		if not is_instance_valid(entity):
			continue
		if entity.lifecycle_state == MonsterEntity.State.DEAD:
			continue
		if entity.resource.tier < 1 or entity.resource.base_damage <= 0.0:
			continue
		if entity.resource.tier == 1 and entity.hero_windup_remaining <= 0.0:
			if entity.boss_scan_frames_remaining > 0:
				entity.boss_scan_frames_remaining -= 1
			if entity.boss_scan_frames_remaining <= 0:
				_elite_scan(entity)
				entity.boss_scan_frames_remaining = BOSS_SCAN_INTERVAL_FRAMES
		if entity.hero_windup_remaining > 0.0:
			_hero_windup_tick(entity, delta)
		if entity.resource.tier == 1:
			entity.boss_attack_cooldown_remaining = maxf(0.0, entity.boss_attack_cooldown_remaining - delta)
```

- [ ] **Step 5: Run tests to verify they pass, and the boss/spawn suites are unchanged**

Run the Step 2 command. Expected: PASS.
Run: `... -a res://tests/unit/monster/monster_boss_test.gd ...`, `... -a res://tests/unit/monster/monster_spawn_test.gd ...`, `... -a res://tests/unit/monster/monster_status_effect_test.gd ...`. Expected: PASS, unchanged.

- [ ] **Step 6: Commit**

```bash
git add src/core/monster/monster_entity.gd src/core/monster/monster_manager.gd tests/unit/monster/monster_hero_attack_test.gd tests/unit/monster/monster_hero_attack_test.gd.uid
git commit -m "Add elite Hero attacks: telegraphed wind-up, fire-time range check, cooldown

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 6: Boss targeting: closest of Hero or tower

**Files:**
- Modify: `src/core/monster/monster_manager.gd` (`_boss_execute_scan`, ~line 455)
- Test: `tests/unit/monster/monster_hero_attack_test.gd` (append)

**Interfaces:**
- Consumes: Task 5's state and helpers (`_hero_in_range`, `_hero_distance`, `_begin_hero_windup`, `HERO_TARGET_ID`) and the `_StubGrid.towers_at_distance` fixture already in the test file.
- Produces: `_closest_tower_distance(cell: Vector2i, max_range: int) -> int`; `_boss_execute_scan` chooses the Hero only when it is strictly closer than the closest tower, or when no tower is in range.

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/monster/monster_hero_attack_test.gd`:

```gdscript
# ---------------------------------------------------------------------------
# Boss targeting: closest of Hero or tower (spec §3, §4.2, AC-4)
# ---------------------------------------------------------------------------

func _boss() -> MonsterEntity:
	return _spawn(_make_attacker(2, 60.0, 3.0, 3, 1.0))


func test_boss_targets_the_hero_when_strictly_closer_than_the_closest_tower() -> void:
	var boss := _boss()
	_mm._hero_cell = Vector2i(1, 0)          # Hero distance 1
	_grid.towers_at_distance = {42: 2}        # closest tower distance 2
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_locked_target_id).is_equal(MonsterManager.HERO_TARGET_ID)
	assert_float(boss.hero_windup_remaining).is_equal_approx(1.0, 0.0001)
	assert_int(boss.boss_attack_prepare_remaining).is_equal(0)
	assert_int(_spy.count("monster_hero_attack_winding_up")).is_equal(1)


func test_boss_targets_the_tower_when_it_is_closer_than_the_hero() -> void:
	var boss := _boss()
	_mm._hero_cell = Vector2i(2, 0)          # Hero distance 2
	_grid.towers_at_distance = {42: 1}        # tower distance 1
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_locked_target_id).is_equal(42)
	assert_int(boss.boss_attack_prepare_remaining).is_greater(0)
	assert_float(boss.hero_windup_remaining).is_equal(0.0)


func test_a_tie_goes_to_the_tower() -> void:
	var boss := _boss()
	_mm._hero_cell = Vector2i(2, 0)
	_grid.towers_at_distance = {42: 2}
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_locked_target_id).is_equal(42)
	assert_float(boss.hero_windup_remaining).is_equal(0.0)


func test_boss_targets_the_hero_when_no_tower_is_in_range() -> void:
	var boss := _boss()
	_mm._hero_cell = Vector2i(2, 0)
	_grid.towers_at_distance = {}
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_locked_target_id).is_equal(MonsterManager.HERO_TARGET_ID)


func test_boss_targets_the_tower_when_the_hero_is_out_of_range() -> void:
	var boss := _boss()
	_mm._hero_cell = HERO_FAR
	_grid.towers_at_distance = {42: 2}
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_locked_target_id).is_equal(42)
	assert_float(boss.hero_windup_remaining).is_equal(0.0)


func test_boss_ignores_a_dead_or_unknown_hero() -> void:
	var boss := _boss()
	_grid.towers_at_distance = {42: 2}
	_mm._hero_alive = false
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_locked_target_id).is_equal(42)


func test_boss_with_nothing_in_range_does_nothing() -> void:
	var boss := _boss()
	_mm._hero_cell = HERO_FAR
	_grid.towers_at_distance = {}
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_locked_target_id).is_equal(-1)
	assert_float(boss.hero_windup_remaining).is_equal(0.0)
	assert_int(boss.boss_attack_prepare_remaining).is_equal(0)


func test_boss_hero_attack_fires_with_the_boss_damage() -> void:
	var boss := _boss()
	_mm._hero_cell = Vector2i(1, 0)
	_grid.towers_at_distance = {}
	_mm._pass2_boss_logic(1.0 / 60.0)      # scan -> Hero locked
	_mm._pass2b_hero_attacks(1.0)          # wind-up (1.0 s) completes
	assert_int(_spy.count("hero_incoming_damage")).is_equal(1)
	var ev: HeroIncomingDamageEvent = (_spy.emissions["hero_incoming_damage"] as Array)[0][0] as HeroIncomingDamageEvent
	assert_float(ev.amount).is_equal_approx(60.0, 0.0001)
	assert_int(ev.source_entity_id).is_equal(boss.entity_id)
	assert_float(boss.boss_attack_cooldown_remaining).is_greater(0.0)


func test_boss_hero_whiff_when_the_hero_leaves_range() -> void:
	var boss := _boss()
	_mm._hero_cell = Vector2i(1, 0)
	_grid.towers_at_distance = {}
	_mm._pass2_boss_logic(1.0 / 60.0)
	_mm._hero_cell = HERO_FAR
	_mm._pass2b_hero_attacks(1.0)
	assert_int(_spy.count("hero_incoming_damage")).is_equal(0)
	assert_float(boss.boss_attack_cooldown_remaining).is_greater(0.0)


func test_only_one_windup_in_flight_a_hero_windup_blocks_a_tower_prepare() -> void:
	var boss := _boss()
	_mm._hero_cell = Vector2i(1, 0)
	_grid.towers_at_distance = {42: 3}
	_mm._pass2_boss_logic(1.0 / 60.0)      # Hero locked (distance 1 < 3)
	boss.boss_scan_frames_remaining = 0    # force another scan next pass
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_attack_prepare_remaining).is_equal(0)
	assert_int(boss.boss_locked_target_id).is_equal(MonsterManager.HERO_TARGET_ID)


func test_a_tower_prepare_blocks_a_hero_windup() -> void:
	var boss := _boss()
	_mm._hero_cell = HERO_FAR
	_grid.towers_at_distance = {42: 1}
	_mm._pass2_boss_logic(1.0 / 60.0)      # tower prepare starts
	_mm._hero_cell = Vector2i(1, 0)        # Hero now closer than nothing else, but a prepare is in flight
	boss.boss_scan_frames_remaining = 0
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_float(boss.hero_windup_remaining).is_equal(0.0)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:/TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/monster/monster_hero_attack_test.gd --ignoreHeadlessMode`
Expected: FAIL (the new boss tests fail: bosses ignore the Hero). Task 5's tests still pass.

- [ ] **Step 3: Implement**

In `src/core/monster/monster_manager.gd`, replace the whole `_boss_execute_scan` function:

```gdscript
func _boss_execute_scan(entity: MonsterEntity) -> void:
	var boss_cell: Vector2i = _grid.world_to_cell(entity.global_position)
	var towers: Array[int] = _grid.get_towers_in_range(boss_cell, entity.resource.boss_attack_range_cells)
	if towers.is_empty():
		return
	# Only enter prepare phase when cooldown is clear and not already preparing
	if entity.boss_attack_cooldown_remaining > 0.0:
		return
	if entity.boss_attack_prepare_remaining > 0:
		return
	entity.boss_attack_prepare_remaining = BOSS_ATTACK_PREPARE_FRAMES
	entity.boss_locked_target_id = towers[0]
```

with

```gdscript
func _boss_execute_scan(entity: MonsterEntity) -> void:
	var boss_cell: Vector2i = _grid.world_to_cell(entity.global_position)
	var towers: Array[int] = _grid.get_towers_in_range(boss_cell, entity.resource.boss_attack_range_cells)
	var hero_in_range: bool = _hero_in_range(entity)
	if towers.is_empty() and not hero_in_range:
		return
	# Only enter a wind-up when the cooldown is clear and nothing is already in flight
	# (a monster has at most one wind-up, tower or Hero: hero-damage spec §4.2).
	if entity.boss_attack_cooldown_remaining > 0.0:
		return
	if entity.boss_attack_prepare_remaining > 0 or entity.hero_windup_remaining > 0.0:
		return
	# Closest target wins; the Hero only when STRICTLY closer than the closest tower (ties go to
	# the tower), or when no tower is in range at all. With the Hero out of range this is the
	# original tower-only behavior, unchanged.
	if hero_in_range and (towers.is_empty()
			or _hero_distance(entity) < _closest_tower_distance(boss_cell, entity.resource.boss_attack_range_cells)):
		_begin_hero_windup(entity)
		return
	entity.boss_attack_prepare_remaining = BOSS_ATTACK_PREPARE_FRAMES
	entity.boss_locked_target_id = towers[0]


## Smallest Chebyshev radius (0..max_range) at which any tower is in range of `cell`, found with the
## existing Grid API only (no tower-cell lookup exists). max_range + 1 when none is in range.
func _closest_tower_distance(cell: Vector2i, max_range: int) -> int:
	for radius: int in range(0, max_range + 1):
		if not _grid.get_towers_in_range(cell, radius).is_empty():
			return radius
	return max_range + 1
```

- [ ] **Step 4: Run tests to verify they pass, and prove the tower path is unchanged**

Run the Step 2 command. Expected: PASS (all Task 5 and Task 6 cases).
Run: `... -a res://tests/unit/monster/monster_boss_test.gd ...`. Expected: PASS, unchanged (the existing boss tests never set `_hero_alive`, so the Hero is never a candidate).

- [ ] **Step 5: Commit**

```bash
git add src/core/monster/monster_manager.gd tests/unit/monster/monster_hero_attack_test.gd
git commit -m "Let bosses target the Hero when strictly closer than the nearest tower

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 7: Wire Damage & Status to the Hero in both mission scenes, and prove the whole chain

**Files:**
- Modify: `src/gameplay/missions/the_gap/the_gap.gd` (~line 148), `src/scenes/mission_scene.gd` (~line 153)
- Test: `tests/integration/hero/hero_damage_chain_test.gd`

**Interfaces:**
- Consumes: `DamageStatus.set_hero_stats(provider)` (Task 3), the elite attack pass (Task 5), Hero's `hero_damage_taken` handling.
- Produces: both mission roots inject the Hero into their `DamageStatus` at assembly.

- [ ] **Step 1: Write the failing end-to-end test**

Create `tests/integration/hero/hero_damage_chain_test.gd`:

```gdscript
extends GdUnitTestSuite

## End-to-end chain (hero-damage spec §9 AC-3/AC-6/AC-7): elite wind-up -> hero_incoming_damage ->
## DamageStatus mitigation (Hero armor via injection) -> hero_damage_taken -> Hero HP.
## The lethal/DEFEAT branch is already covered by hero_lifecycle_test.gd and is not repeated here
## (it would drive the real WaveManager DEFEAT transition).

class _StubGrid extends RefCounted:
	func get_cell_type(_cell: Vector2i) -> int:
		return Grid.CellType.SPAWN

	func cell_to_world(cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x) * 64.0, float(cell.y) * 64.0)

	func world_to_cell(_pos: Vector2) -> Vector2i:
		return Vector2i(0, 0)

	func get_towers_in_range(_center: Vector2i, _radius: int) -> Array[int]:
		return []


class _StubPathfinding extends RefCounted:
	func find_path(_from: Vector2i, _tier: int) -> Array[Vector2i]:
		return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]


var _hero: Hero
var _ds: DamageStatus
var _mm: MonsterManager


func before_test() -> void:
	GInventory.reset_to_defaults()
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[&"move_speed"] = 0.0
	_hero._base_stats[&"armor"] = 52.0
	_hero.set_process(false)
	# The real Hero would otherwise emit hero_position_changed on its first physics frame and
	# overwrite the MonsterManager's hand-set _hero_cell during the test's awaits.
	_hero.set_physics_process(false)
	_hero._phase = Hero.HeroPhase.COMBAT
	_hero._max_hp = 500.0
	_hero._current_hp = 500.0
	_ds = DamageStatus.new()
	add_child(_ds)
	_ds.set_hero_stats(_hero)
	_mm = MonsterManager.new()
	add_child(_mm)
	_mm._grid = _StubGrid.new()
	_mm._pathfinding = _StubPathfinding.new()
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	_mm._hero_alive = true
	_mm._hero_cell = Vector2i(1, 0)


func after_test() -> void:
	GInventory.reset_to_defaults()
	for e: MonsterEntity in _mm.active_monsters:
		if is_instance_valid(e):
			e.free()
	for e: MonsterEntity in _mm.spawning_entities:
		if is_instance_valid(e):
			e.free()
	remove_child(_mm)
	_mm.free()
	if is_instance_valid(_ds):
		_ds.queue_free()
		await get_tree().process_frame
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


func _spawn_elite(damage: float) -> MonsterEntity:
	var res := MonsterResource.new()
	res.monster_id = &"chain_elite"
	res.display_name = "Chain Elite"
	res.tier = 1
	res.base_hp = 300.0
	res.base_speed = 0.5
	res.base_damage = damage
	res.base_attack_interval = 3.0
	res.boss_attack_range_cells = 2
	res.hero_attack_windup_seconds = 1.0
	res.drop_table_id = &"goblin_drops"
	_mm._resource_table[res.monster_id] = res
	return _mm.spawn_monster(res.monster_id, Vector2i(0, 0), 1, 1)


func test_an_elite_hit_reduces_hero_hp_by_the_armor_mitigated_amount() -> void:
	_spawn_elite(45.0)
	_mm._pass2b_hero_attacks(0.5)  # scan + wind-up starts
	_mm._pass2b_hero_attacks(0.5)  # wind-up completes -> hero_incoming_damage
	await get_tree().process_frame  # D&S defers one frame
	await get_tree().process_frame
	# floor(45 x 100 / (52 + 100)) = 29
	assert_float(_hero._current_hp).is_equal_approx(471.0, 0.0001)


func test_a_dodged_attack_leaves_hero_hp_untouched() -> void:
	_spawn_elite(45.0)
	_mm._pass2b_hero_attacks(0.5)
	_mm._hero_cell = Vector2i(9, 9)  # the Hero steps out of range during the wind-up
	_mm._pass2b_hero_attacks(0.5)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(_hero._current_hp).is_equal_approx(500.0, 0.0001)


func test_the_wave_clear_heal_recovers_part_of_the_damage() -> void:
	_spawn_elite(45.0)
	_mm._pass2b_hero_attacks(0.5)
	_mm._pass2b_hero_attacks(0.5)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(_hero._current_hp).is_equal_approx(471.0, 0.0001)
	_hero._on_wave_completed(1, 0, false)  # +25% of 500 = 125, clamped to max HP
	assert_float(_hero._current_hp).is_equal_approx(500.0, 0.0001)
```

- [ ] **Step 2: Run the test to verify its status**

Run: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:/TDef --script tests/gdunit4_runner.gd -- -a res://tests/integration/hero/hero_damage_chain_test.gd --ignoreHeadlessMode`
Expected: PASS. The chain is complete in code after Tasks 1-6; this test proves it end to end. (If any case fails, that is a real integration defect: report it rather than adjusting the assertions.)

- [ ] **Step 3: Wire the two mission scenes**

In `src/gameplay/missions/the_gap/the_gap.gd`, directly after the line

```gdscript
	_monster_manager.set_swarm_renderer(_monster_swarm_renderer)
```

add

```gdscript
	# Hero-damage spec §4.4: Damage & Status reads the Hero's armor/resists through injection
	# (same pattern as set_swarm_renderer above; no service-locator lookup).
	($DamageStatus as DamageStatus).set_hero_stats(_hero)
```

In `src/scenes/mission_scene.gd`, directly after the line

```gdscript
	_monster_manager.set_swarm_renderer(_monster_swarm_renderer)
```

add

```gdscript
	# Hero-damage spec §4.4: mirrors the_gap.gd's identical injection.
	($GameplayRoot/DamageStatus as DamageStatus).set_hero_stats(_hero)
```

- [ ] **Step 4: Run scene-level regressions**

Run: `find tests -name "mission_scene_the_gap_test.gd" -o -name "mission_scene*_test.gd" | head`, then run each found suite (they load the real mission scenes, so a wiring typo here fails loudly). Also re-run `... -a res://tests/integration/hero/hero_damage_chain_test.gd ...` and `... -a res://tests/unit/monster/monster_hero_attack_test.gd ...`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/gameplay/missions/the_gap/the_gap.gd src/scenes/mission_scene.gd tests/integration/hero/hero_damage_chain_test.gd tests/integration/hero/hero_damage_chain_test.gd.uid
git commit -m "Inject the Hero into Damage & Status in both mission scenes; prove the chain

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 8: Docs, GDD updates, spec status, and session state

**Files:**
- Modify: `design/gdd/damage-status.md`, `design/gdd/monster.md`, `design/gdd/hero.md`, `design/gdd/event-bus.md`, `docs/superpowers/specs/2026-09-25-hero-damage-design.md` (Status line only), `production/session-state/active.md`

**Interfaces:** none (documentation only).

- [ ] **Step 1: Update the four GDDs**

Locate each anchor with `grep -n` and edit in place; keep each doc's existing tone and add one dated note (`> **Update 2026-09-25:** ...`) rather than rewriting history.
- `design/gdd/damage-status.md`: Rule V heading currently reads "(stubbed — no MVP sources)". Update it to live: ELITE/BOSS attacks are the sources (spec link), the pipeline is implemented, the payload is `HeroIncomingDamageEvent` (amount, damage_type, source_type, source_entity_id), physical uses the armor formula, fire/frost use the capped resist (75%), other types are unmitigated (floor 1), and the Hero's stats arrive through `set_hero_stats()` dependency injection. Also fix the Overview and Core Rule 2 sentences that say incoming hero damage "has no active sources at MVP".
- `design/gdd/monster.md`: rules 14/15 (STANDARD/ELITE do not attack) and 16-19 (BOSS attacks towers): record that ELITE attackers (base_damage > 0) attack the Hero only, BOSS attacks the closest of Hero or tower (Hero only when strictly closer; ties go to the tower), the seconds-based Hero wind-up and fire-time range re-check, the whiff rule, "at most one wind-up in flight", and the schema table's attack fields renamed "attack-capable tiers (ELITE, BOSS)" plus the new `hero_attack_windup_seconds`. STANDARD stays non-attacking. Note rule 25 (breach is not a damage event) is unchanged.
- `design/gdd/hero.md`: Group 6 and the incoming-damage formula note: the source now exists (ELITE/BOSS attacks); add the wave-clear heal (`WAVE_CLEAR_HEAL_FRACTION` 0.25 of max HP, through the existing heal path, never for a DEAD Hero) to the recovery section and Tuning Knobs; keep rule 24 (HP 0 = immediate DEFEAT, no revival) unchanged. Update the "Hero base health (TBD at production)" row to note the 500 HP stopgap is still unbalanced.
- `design/gdd/event-bus.md`: `hero_incoming_damage` now carries `HeroIncomingDamageEvent`; add `monster_hero_attack_winding_up(entity_id: int, windup_seconds: float)` (no subscriber yet; presentation follow-up). Update the catalogue total in the header/summary if it states one (78 -> 79 to match `event_bus_signals_test.gd`) and the "Emitted by / Key subscribers" text for `hero_damage_taken`.

- [ ] **Step 2: Update the spec status line**

In `docs/superpowers/specs/2026-09-25-hero-damage-design.md`, replace the `**Status**` line's "pending spec review and implementation plan" with "Implemented (plan: `docs/superpowers/plans/2026-09-25-hero-damage.md`, 8 tasks); live verification pending." Keep the rest of the sentence.

- [ ] **Step 3: Session state**

Read the first ~40 lines of `production/session-state/active.md` to match the format, then add a new top extract `## Session Extract — Hero Damage (telegraphed elite/boss attacks on the Hero), implemented, NOT live-verified, 2026-09-25 (part 28)` (increment the part number if a higher one now exists) covering: spec and plan links; what shipped per task (T1 wind-up field + validation + five attackers, T2 payload + two signals + updated signal-mirror test, T3 D&S Rule V with DI stat provider, T4 wave-clear heal, T5 elite attacks, T6 boss targeting, T7 scene wiring + chain test); the commit SHAs from `git log` for these tasks; that only targeted suites were run; the design decisions (elites hit the Hero only, bosses closest-of, dodge by leaving range, armor live/resists ready, 25% heal); **NOT verified**: nothing seen in the running game. Live-verification checklist: (1) run the editor-mode reimport; (2) in the_gap, an elite (wave 3 gauntlet) with the Hero within 2 cells winds up (watch `monster_hero_attack_winding_up`) and the Hero's HP drops by the armor-mitigated amount; (3) stepping out of range during the wind-up avoids the hit; (4) equipping armor gear visibly reduces the damage; (5) the boss picks the Hero only when strictly closer than a tower; (6) wave clear heals 25% of max HP and never revives a dead Hero; (7) both `the_gap` and `MissionScene` boot with D&S wired (the Hero cell cache is set once the Hero first moves). Open items: the wind-up presentation follow-up spec is REQUIRED before playtesting; all numbers unplaytested; Hero's 500 HP stopgap; kiting margin; the boss-to-tower 4-frame telegraph is unreadable.

- [ ] **Step 4: Commit**

```bash
git add design/gdd/damage-status.md design/gdd/monster.md design/gdd/hero.md design/gdd/event-bus.md docs/superpowers/specs/2026-09-25-hero-damage-design.md docs/superpowers/plans/2026-09-25-hero-damage.md production/session-state/active.md
git commit -m "Document Hero damage: GDD updates, spec status, session state

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

## Self-Review

**Spec coverage** (spec section -> task): §3 decisions -> Global Constraints and Tasks 5-6; §4.1 data and validation -> T1; §4.2 attack flow, cache, one-wind-up rule, fire-time re-check, whiff, `hero_died` clearing, dead-monster skip -> T5, boss targeting and strict-closer rule -> T6; §4.3 payload and both signals -> T2; §4.4 D&S Rule V, DI seam, mitigation table, one-frame deferral -> T3, scene wiring -> T7; §4.5 wave-clear heal -> T4; §5 formulas -> T3/T4 tests; §6 edge cases -> T5/T6/T7 tests (dodge, dead mid-wind-up, tie to tower, unknown type); §7 dependencies/GDDs -> T8; AC-1 -> T1, AC-2/3/5 -> T5, AC-4 -> T6, AC-6 -> T3, AC-7 -> T4 + T7, AC-8 (determinism) -> Global Constraints (no random calls anywhere in the new code), AC-9 -> T3 disconnect test and T5 disconnect test, AC-10 (live check) -> T8's checklist (deliberately not run by the implementers). §10 out-of-scope items are intentionally not built (no presentation, no elemental content, no Hero rebalance).

**Placeholder scan:** none. Task 7 Step 2 states that a failing chain test is a real defect to report, not to silence.

**Type/name consistency:** `HeroIncomingDamageEvent` fields (`amount`, `damage_type`, `source_type`, `source_entity_id`) match across T2, T3, T5, T7; `set_hero_stats` / `mitigate_hero_incoming` / `_on_hero_incoming_damage` match between T3 and T7; `hero_windup_remaining`, `HERO_TARGET_ID`, `_hero_cell`, `_hero_alive`, `_pass2b_hero_attacks`, `_elite_scan`, `_hero_in_range`, `_hero_distance`, `_begin_hero_windup`, `_hero_windup_tick` are defined in T5 and used verbatim in T6/T7 tests; `_closest_tower_distance(cell, max_range)` is defined and used only in T6; `MonsterResource` field names (`base_damage`, `base_attack_interval`, `boss_attack_range_cells`, `hero_attack_windup_seconds`) match T1 data, T5 tests and the payload amount source; signal arities (`hero_incoming_damage(payload)`, `monster_hero_attack_winding_up(entity_id, windup_seconds)`) match T2 declarations, T5 emits and the spy reads.
