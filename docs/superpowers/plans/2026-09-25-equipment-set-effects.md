# Equipment Set Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each of the nine equipment sets gains one capstone effect at its top threshold (five effect types), running live in combat and shown in the Inventory info panel.

**Architecture:** `EquipmentSetResource` gains an `effects` map (validated at boot). A pure `SetEffectResolver` answers "which effects are active for this equipment". A `SetEffectController` node under Hero subscribes to existing EventBus signals and drives the effects through a new transient modifier layer on Hero and a public DoT entry on MonsterManager. No new EventBus events; nothing is saved.

**Tech Stack:** Godot 4.6.2, GDScript, gdUnit4, `.tres` resources.

**Spec:** `docs/superpowers/specs/2026-09-25-equipment-set-effects-design.md`

## Global Constraints

- Exactly five effect types: `on_kill_stack_buff`, `on_crit_status`, `on_wave_start_buff`, `on_skill_cast_buff`, `phase_state`. Capstone values are exactly spec §4. One capstone per set, at the set's highest `bonuses` threshold.
- Every `stats` value is an additive fraction (`0.20` = +20%) folded into Hero's additive bucket; keys must be in `EquipmentBonuses.FAN_OUT_STATS` (`additive_bonus_total` is NOT allowed in effects).
- No new EventBus signals. `SetEffectController` emits no EventBus signals (verified by a `grep -c "\.emit"` check in Task 8). Every subscription is disconnected in `_exit_tree()` (ADR-0001 Rules 6/7). Cascade depth cap is 2 (Rule 4).
- Effects and their runtime state are derived and never saved. Hero's modifier layer is absent from `get_save_data()`/`restore_save_data()`.
- Phase names are the `WaveManager.Phase` enum keys: `IDLE, SCOUT, PRE_WAVE, WAVE_ACTIVE, INTERMISSION, MISSION_COMPLETE, DEFEAT`.
- Dictionary keys inside an effect are ALWAYS `StringName` (`&"name"`, `&"type"`, `&"params"`, `&"stats"`, ...), in `.tres` files, code and tests alike (a `String`/`StringName` key mismatch silently misses).
- New `class_name`s (`SetEffectResolver`, `SetEffectController`) and new `.gd` files need a class-cache rebuild before tests: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --editor --path G:\TDef --quit`. Run the same command after any `strings.csv` edit (translation reimport). It also generates the `.gd.uid` files, which are tracked in git: `git add` each new `.gd` together with its `.gd.uid`.
- `strings.csv` uses CRLF line endings: append rows with `printf '%s\r\n'`. Row text must not contain commas (or must be quoted).
- `.tres` typed containers use the repo's canonical form: `Dictionary[int, Dictionary]({...})`. No `#` comments inside `.tres`/`.tscn` node or resource blocks. **Write `.tres`/`.tscn` files with the Write tool** (a long shell heredoc containing quotes can fail to parse).
- Static GDScript functions cannot call `tr()`; use `TranslationServer.translate()` in statics.
- Test runner: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a <res:// path> --ignoreHeadlessMode`. Run only the targeted suites named in each task; do NOT run the full suite.
- Controller tests call handlers directly (`_ctl._on_wave_started(...)`) instead of emitting on the global `GEventBus`, because autoload subscribers (economy, audio, Hero itself) also react to those signals.
- Commit and push after each task's tests pass (standing user rule). After every commit verify with `git show --name-only --format= HEAD` that no unrelated files (e.g. the pre-existing modified `addons/`) were included; a non-existent path in `git add` aborts the whole add, so list only files that exist. Commit messages end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.

## Deviations from the spec (decided while planning; the spec is updated to match in Task 11)

1. `describe` lives on the info panel (`EquipmentInfoPanel.describe_effect`), not on `SetEffectResolver`: the description needs `stat_label()`/`format`-style helpers that already live in the panel (UI layer), and core code must not depend on UI.
2. MonsterManager is a scene child (not an autoload), so the controller reaches it through a group: `MonsterManager` joins group `&"monster_manager"` in `_ready()`; the controller resolves it lazily and also exposes a `monster_manager` field as a test seam.
3. `Hero.is_direct_kill()` replaces only the inner-band comparison in `_resolve_kill_xp_band()`; the early `wave_end` return stays (the outer band still needs it).

## File Structure

- Modify `src/core/equipment/equipment_set_resource.gd`: `effects` map + validation.
- Modify `assets/data/equipment_sets/set_*.tres` (9): add each capstone.
- Modify `src/core/hero/hero.gd`: transient modifier layer, `is_direct_kill()`.
- Modify `src/core/monster/monster_manager.gd`: `GROUP_NAME`, group join, `apply_dot()`.
- Create `src/core/equipment/set_effect_resolver.gd`: pure `active_effects()` / `effects_for_set()` / `effect_key()`.
- Create `src/core/equipment/set_effect_controller.gd`: the runtime node.
- Modify `src/core/hero/Hero.tscn`: add the `SetEffectController` child.
- Modify `src/gameplay/ui/inventory_screen/equipment_info_panel.gd`, `assets/localization/strings.csv`: capstone lines.
- Tests (create unless noted): `tests/unit/equipment/equipment_set_resource_test.gd` (modify), `tests/unit/equipment/equipment_set_content_test.gd` (modify), `tests/unit/hero/hero_effect_modifiers_test.gd`, `tests/unit/monster/monster_apply_dot_test.gd`, `tests/unit/equipment/set_effect_resolver_test.gd`, `tests/unit/equipment/set_effect_controller_test.gd`, `tests/unit/equipment/set_effect_wiring_test.gd`, `tests/unit/inventory/equipment_info_panel_sets_test.gd` (modify).
- Create `design/balance/equipment-set-effects.md`; modify the spec, `design/gdd/equipment-forge.md`, `production/session-state/active.md`.

---

### Task 1: `effects` on `EquipmentSetResource` and its validation

**Files:**
- Modify: `src/core/equipment/equipment_set_resource.gd`
- Test: `tests/unit/equipment/equipment_set_resource_test.gd`

**Interfaces:**
- Produces: `EquipmentSetResource.effects: Dictionary[int, Dictionary]` (`threshold -> {&"name": String, &"type": StringName, &"params": Dictionary}`); constants `EFFECT_TYPES: Array[StringName]`, `KNOWN_PHASES: Array[String]`, `CRIT_STATUS_EFFECT_TYPES: Array[String]`, `REQUIRED_PARAMS: Dictionary`; `validate()` now also checks `effects`.
- Consumes: `EquipmentBonuses.FAN_OUT_STATS`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/equipment/equipment_set_resource_test.gd`:

```gdscript
# ---------------------------------------------------------------------------
# Capstone effects (equipment-set-effects spec §3.2, AC-1)
# ---------------------------------------------------------------------------

func _params(type: StringName) -> Dictionary:
	match type:
		&"on_kill_stack_buff":
			return {&"stats": {&"physical_attack": 0.03}, &"max_stacks": 10, &"duration": 6.0}
		&"on_crit_status":
			return {&"effect_type": "poison", &"effect_value": 0.06, &"effect_duration": 4.0}
		&"on_wave_start_buff":
			return {&"stats": {&"physical_attack": 0.35}, &"duration": 10.0}
		&"on_skill_cast_buff":
			return {&"stats": {&"attack_range": 0.2}, &"duration": 5.0}
		&"phase_state":
			return {&"stats": {&"attack_range": 0.2}, &"phases": ["WAVE_ACTIVE"]}
	return {}


func _with_effect(threshold: int, type: StringName, params: Dictionary) -> EquipmentSetResource:
	var s: EquipmentSetResource = _valid()
	s.effects = {threshold: {&"name": "Test Effect", &"type": type, &"params": params}}
	return s


func _assert_rejected(s: EquipmentSetResource) -> void:
	assert_bool(s.validate().size() > 0).is_true()


func test_set_without_effects_is_still_valid() -> void:
	assert_array(_valid().validate()).is_empty()


func test_each_effect_type_with_valid_params_has_no_errors() -> void:
	for type: StringName in EquipmentSetResource.EFFECT_TYPES:
		var errors: Array[String] = _with_effect(3, type, _params(type)).validate()
		assert_array(errors).override_failure_message(String(type)).is_empty()


func test_effect_threshold_out_of_range_is_rejected() -> void:
	_assert_rejected(_with_effect(1, &"phase_state", _params(&"phase_state")))
	_assert_rejected(_with_effect(4, &"phase_state", _params(&"phase_state")))


func test_effect_with_empty_name_is_rejected() -> void:
	var s: EquipmentSetResource = _with_effect(3, &"phase_state", _params(&"phase_state"))
	s.effects[3][&"name"] = ""
	_assert_rejected(s)


func test_unknown_effect_type_is_rejected() -> void:
	_assert_rejected(_with_effect(3, &"on_hurt_shield", {&"stats": {&"armor": 0.1}, &"duration": 5.0}))


func test_missing_required_param_is_rejected() -> void:
	var params: Dictionary = _params(&"on_wave_start_buff")
	params.erase(&"duration")
	_assert_rejected(_with_effect(3, &"on_wave_start_buff", params))


func test_unknown_extra_param_is_rejected() -> void:
	var params: Dictionary = _params(&"on_wave_start_buff")
	params[&"typo"] = 1.0
	_assert_rejected(_with_effect(3, &"on_wave_start_buff", params))


func test_non_positive_duration_is_rejected() -> void:
	var params: Dictionary = _params(&"on_wave_start_buff")
	params[&"duration"] = 0.0
	_assert_rejected(_with_effect(3, &"on_wave_start_buff", params))


func test_bad_stats_are_rejected() -> void:
	for bad: Dictionary in [{}, {&"typo_stat": 0.1}, {&"additive_bonus_total": 0.1}, {&"armor": 0.0}, {&"armor": -0.1}]:
		var params: Dictionary = _params(&"on_wave_start_buff")
		params[&"stats"] = bad
		_assert_rejected(_with_effect(3, &"on_wave_start_buff", params))


func test_max_stacks_must_be_an_int_of_at_least_one() -> void:
	for bad: Variant in [10.0, 0, -2]:
		var params: Dictionary = _params(&"on_kill_stack_buff")
		params[&"max_stacks"] = bad
		_assert_rejected(_with_effect(3, &"on_kill_stack_buff", params))


func test_crit_status_effect_type_must_be_burn_or_poison() -> void:
	var params: Dictionary = _params(&"on_crit_status")
	params[&"effect_type"] = "bleed"
	_assert_rejected(_with_effect(3, &"on_crit_status", params))


func test_phase_state_phases_must_be_non_empty_and_known() -> void:
	for bad: Array in [[], ["NOT_A_PHASE"]]:
		var params: Dictionary = _params(&"phase_state")
		params[&"phases"] = bad
		_assert_rejected(_with_effect(3, &"phase_state", params))


func test_known_phases_match_the_wave_manager_enum() -> void:
	var real: Array = WaveManager.Phase.keys()
	assert_int(EquipmentSetResource.KNOWN_PHASES.size()).is_equal(real.size())
	for phase: String in real:
		assert_bool(EquipmentSetResource.KNOWN_PHASES.has(phase)).override_failure_message(phase).is_true()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/equipment/equipment_set_resource_test.gd --ignoreHeadlessMode`
Expected: FAIL (parse/runtime errors: `effects`, `EFFECT_TYPES`, `KNOWN_PHASES` not defined).

- [ ] **Step 3: Implement**

In `src/core/equipment/equipment_set_resource.gd`, add these constants and the export directly under the `bonuses` export, and update the class doc comment's first paragraph by appending "A set may also carry capstone `effects` (equipment-set-effects spec §3.2)."

```gdscript
const EFFECT_TYPES: Array[StringName] = [
	&"on_kill_stack_buff", &"on_crit_status", &"on_wave_start_buff",
	&"on_skill_cast_buff", &"phase_state",
]
## MAINTENANCE POINT: must equal WaveManager.Phase.keys(); a test enforces it.
## Kept here (not read from WaveManager) so core data never depends on gameplay code.
const KNOWN_PHASES: Array[String] = [
	"IDLE", "SCOUT", "PRE_WAVE", "WAVE_ACTIVE", "INTERMISSION", "MISSION_COMPLETE", "DEFEAT",
]
const CRIT_STATUS_EFFECT_TYPES: Array[String] = ["burn", "poison"]
const REQUIRED_PARAMS: Dictionary = {
	&"on_kill_stack_buff": [&"stats", &"max_stacks", &"duration"],
	&"on_crit_status": [&"effect_type", &"effect_value", &"effect_duration"],
	&"on_wave_start_buff": [&"stats", &"duration"],
	&"on_skill_cast_buff": [&"stats", &"duration"],
	&"phase_state": [&"stats", &"phases"],
}

## Capstone effects: pieces_required -> {&"name": String, &"type": StringName,
## &"params": Dictionary}. Empty is valid (a set with no capstone).
@export var effects: Dictionary[int, Dictionary] = {}
```

In `validate()`, add this block immediately before `return errors`:

```gdscript
	for threshold: int in effects:
		if threshold < 2 or threshold > unique.size():
			errors.append("effect threshold %d must be between 2 and %d" % [threshold, unique.size()])
		errors.append_array(_validate_effect(threshold, effects[threshold]))
```

Add these methods at the end of the file:

```gdscript
static func _is_positive_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and float(value) > 0.0


static func _validate_effect(threshold: int, effect: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix: String = "effect %d: " % threshold
	if String(effect.get(&"name", "")) == "":
		errors.append(prefix + "name must not be empty")
	var type: StringName = StringName(effect.get(&"type", &""))
	if not EFFECT_TYPES.has(type):
		errors.append(prefix + "unknown type '%s'" % type)
		return errors
	var raw_params: Variant = effect.get(&"params", null)
	if not raw_params is Dictionary:
		errors.append(prefix + "params must be a Dictionary")
		return errors
	var params: Dictionary = raw_params
	var required: Array = REQUIRED_PARAMS[type]
	for key: StringName in required:
		if not params.has(key):
			errors.append(prefix + "missing param '%s'" % key)
	for key: Variant in params:
		if not required.has(StringName(key)):
			errors.append(prefix + "unknown param '%s'" % key)
	if params.has(&"stats"):
		errors.append_array(_validate_stats(prefix, params[&"stats"]))
	if params.has(&"max_stacks"):
		var stacks: Variant = params[&"max_stacks"]
		if typeof(stacks) != TYPE_INT or int(stacks) < 1:
			errors.append(prefix + "max_stacks must be an int >= 1")
	for key: StringName in [&"duration", &"effect_value", &"effect_duration"]:
		if params.has(key) and not _is_positive_number(params[key]):
			errors.append(prefix + "%s must be a number > 0" % key)
	if params.has(&"effect_type") and not CRIT_STATUS_EFFECT_TYPES.has(String(params[&"effect_type"])):
		errors.append(prefix + "effect_type must be burn or poison")
	if params.has(&"phases"):
		errors.append_array(_validate_phases(prefix, params[&"phases"]))
	return errors


static func _validate_stats(prefix: String, stats: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not stats is Dictionary or (stats as Dictionary).is_empty():
		errors.append(prefix + "stats must be a non-empty Dictionary")
		return errors
	for stat: Variant in (stats as Dictionary):
		var key: StringName = StringName(stat)
		if not EquipmentBonuses.FAN_OUT_STATS.has(key):
			errors.append(prefix + "unknown stat key '%s'" % key)
		if not _is_positive_number((stats as Dictionary)[stat]):
			errors.append(prefix + "stat '%s' must be a number > 0" % key)
	return errors


static func _validate_phases(prefix: String, phases: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not phases is Array or (phases as Array).is_empty():
		errors.append(prefix + "phases must be a non-empty Array")
		return errors
	for phase: Variant in (phases as Array):
		if not KNOWN_PHASES.has(String(phase)):
			errors.append(prefix + "unknown phase '%s'" % phase)
	return errors
```

- [ ] **Step 4: Run tests to verify they pass**

Run the Step 2 command. Expected: PASS (all old + new tests in `equipment_set_resource_test.gd`).

- [ ] **Step 5: Commit**

```bash
git add src/core/equipment/equipment_set_resource.gd tests/unit/equipment/equipment_set_resource_test.gd
git commit -m "Add validated capstone effects map to EquipmentSetResource

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 2: Author the nine capstones and lock them with a content test

**Files:**
- Modify (full rewrite with the Write tool): `assets/data/equipment_sets/set_iron.tres`, `set_leather.tres`, `set_reinforced.tres`, `set_goblin.tres`, `set_brute.tres`, `set_sentinel.tres`, `set_troll.tres`, `set_warlord.tres`, `set_lurker.tres`
- Test: `tests/unit/equipment/equipment_set_content_test.gd`

**Interfaces:**
- Consumes: `EquipmentSetResource.effects` (Task 1).
- Produces: nine authored capstones readable via `GGameDataRegistry.get_equipment_set(id).effects`.

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/equipment/equipment_set_content_test.gd`:

```gdscript
# ---------------------------------------------------------------------------
# Capstone effects (equipment-set-effects spec §3.9/§4, AC-14)
# ---------------------------------------------------------------------------

const EXPECTED_EFFECTS: Dictionary[StringName, Dictionary] = {
	&"set_troll": {"threshold": 4, "name": "Troll's Frenzy", "type": &"on_kill_stack_buff",
		"params": {&"stats": {&"physical_attack": 0.03}, &"max_stacks": 10, &"duration": 6.0}},
	&"set_lurker": {"threshold": 2, "name": "Venom Strike", "type": &"on_crit_status",
		"params": {&"effect_type": "poison", &"effect_value": 0.06, &"effect_duration": 4.0}},
	&"set_goblin": {"threshold": 4, "name": "Ember Raid", "type": &"on_crit_status",
		"params": {&"effect_type": "burn", &"effect_value": 0.08, &"effect_duration": 3.0}},
	&"set_brute": {"threshold": 5, "name": "Juggernaut", "type": &"on_wave_start_buff",
		"params": {&"stats": {&"physical_attack": 0.35, &"attack_range": 0.15}, &"duration": 10.0}},
	&"set_warlord": {"threshold": 5, "name": "Battle Cry", "type": &"on_wave_start_buff",
		"params": {&"stats": {&"physical_attack": 0.20, &"magic_attack": 0.20}, &"duration": 15.0}},
	&"set_iron": {"threshold": 4, "name": "Steel Reflex", "type": &"on_skill_cast_buff",
		"params": {&"stats": {&"physical_attack": 0.15}, &"duration": 5.0}},
	&"set_reinforced": {"threshold": 4, "name": "Braced Stance", "type": &"on_skill_cast_buff",
		"params": {&"stats": {&"attack_range": 0.20}, &"duration": 6.0}},
	&"set_sentinel": {"threshold": 4, "name": "Overwatch", "type": &"phase_state",
		"params": {&"stats": {&"attack_range": 0.20}, &"phases": ["WAVE_ACTIVE"]}},
	&"set_leather": {"threshold": 3, "name": "Fleet-Footed", "type": &"phase_state",
		"params": {&"stats": {&"move_speed": 0.30}, &"phases": ["SCOUT", "INTERMISSION"]}},
}


func test_every_set_has_exactly_one_capstone_at_its_top_threshold() -> void:
	for set_res: EquipmentSetResource in GGameDataRegistry.get_all_equipment_sets().values():
		var sid: String = String(set_res.set_id)
		assert_int(set_res.effects.size()).override_failure_message("%s effect count" % sid).is_equal(1)
		var top: int = 0
		for threshold: int in set_res.bonuses:
			top = maxi(top, threshold)
		assert_bool(set_res.effects.has(top)).override_failure_message("%s capstone not at top threshold %d" % [sid, top]).is_true()


func test_capstones_match_the_spec_table_exactly() -> void:
	assert_int(EXPECTED_EFFECTS.size()).is_equal(9)
	for set_id: StringName in EXPECTED_EFFECTS:
		var set_res: EquipmentSetResource = GGameDataRegistry.get_equipment_set(set_id)
		var expected: Dictionary = EXPECTED_EFFECTS[set_id]
		var threshold: int = expected["threshold"]
		assert_bool(set_res.effects.has(threshold)).override_failure_message("%s threshold" % set_id).is_true()
		var actual: Dictionary = set_res.effects[threshold]
		assert_str(String(actual[&"name"])).override_failure_message("%s name" % set_id).is_equal(expected["name"])
		assert_bool(actual[&"type"] == expected["type"]).override_failure_message("%s type" % set_id).is_true()
		assert_bool(actual[&"params"] == expected["params"]).override_failure_message("%s params" % set_id).is_true()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/equipment/equipment_set_content_test.gd --ignoreHeadlessMode`
Expected: FAIL (sets have no effects yet).

- [ ] **Step 3: Author the nine `.tres` files**

Use the Write tool to overwrite each file with exactly the content below (members and stat bonuses are unchanged from the existing files; only the `effects` block is new).

`assets/data/equipment_sets/set_iron.tres`:

```
[gd_resource type="Resource" script_class="EquipmentSetResource" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/core/equipment/equipment_set_resource.gd" id="1"]

[resource]
script = ExtResource("1")
set_id = &"set_iron"
display_name = "Iron"
member_item_ids = Array[StringName]([&"iron_sword", &"iron_helm", &"iron_greaves", &"iron_buckler", &"iron_band"])
bonuses = Dictionary[int, Dictionary]({
2: {&"armor": 8.0},
4: {&"max_hp": 50.0, &"physical_attack": 3.0}
})
effects = Dictionary[int, Dictionary]({
4: {
&"name": "Steel Reflex",
&"type": &"on_skill_cast_buff",
&"params": {
&"stats": {&"physical_attack": 0.15},
&"duration": 5.0
}
}
})
```

`set_leather.tres`:

```
[gd_resource type="Resource" script_class="EquipmentSetResource" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/core/equipment/equipment_set_resource.gd" id="1"]

[resource]
script = ExtResource("1")
set_id = &"set_leather"
display_name = "Leather"
member_item_ids = Array[StringName]([&"leather_gloves", &"leather_jerkin", &"leather_leggings"])
bonuses = Dictionary[int, Dictionary]({
2: {&"move_speed": 8.0},
3: {&"luck": 0.03}
})
effects = Dictionary[int, Dictionary]({
3: {
&"name": "Fleet-Footed",
&"type": &"phase_state",
&"params": {
&"stats": {&"move_speed": 0.3},
&"phases": ["SCOUT", "INTERMISSION"]
}
}
})
```

`set_reinforced.tres`:

```
[gd_resource type="Resource" script_class="EquipmentSetResource" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/core/equipment/equipment_set_resource.gd" id="1"]

[resource]
script = ExtResource("1")
set_id = &"set_reinforced"
display_name = "Reinforced"
member_item_ids = Array[StringName]([&"reinforced_helm", &"reinforced_plate", &"reinforced_boots", &"reinforced_gauntlets"])
bonuses = Dictionary[int, Dictionary]({
2: {&"max_hp": 40.0},
4: {&"armor": 12.0, &"physical_attack": 4.0}
})
effects = Dictionary[int, Dictionary]({
4: {
&"name": "Braced Stance",
&"type": &"on_skill_cast_buff",
&"params": {
&"stats": {&"attack_range": 0.2},
&"duration": 6.0
}
}
})
```

`set_goblin.tres`:

```
[gd_resource type="Resource" script_class="EquipmentSetResource" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/core/equipment/equipment_set_resource.gd" id="1"]

[resource]
script = ExtResource("1")
set_id = &"set_goblin"
display_name = "Goblin"
member_item_ids = Array[StringName]([&"goblin_fang_circlet", &"goblin_claw_gauntlets", &"goblin_raider_leggings", &"goblin_signet"])
bonuses = Dictionary[int, Dictionary]({
2: {&"luck": 0.04},
4: {&"crit_chance": 0.06, &"move_speed": 15.0}
})
effects = Dictionary[int, Dictionary]({
4: {
&"name": "Ember Raid",
&"type": &"on_crit_status",
&"params": {
&"effect_type": "burn",
&"effect_value": 0.08,
&"effect_duration": 3.0
}
}
})
```

`set_brute.tres`:

```
[gd_resource type="Resource" script_class="EquipmentSetResource" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/core/equipment/equipment_set_resource.gd" id="1"]

[resource]
script = ExtResource("1")
set_id = &"set_brute"
display_name = "Brute"
member_item_ids = Array[StringName]([&"brutes_war_helm", &"brutes_bulwark_plate", &"brute_gauntlets", &"brute_legguards", &"brute_core_band"])
bonuses = Dictionary[int, Dictionary]({
2: {&"max_hp": 60.0},
4: {&"armor": 25.0},
5: {&"max_hp": 100.0}
})
effects = Dictionary[int, Dictionary]({
5: {
&"name": "Juggernaut",
&"type": &"on_wave_start_buff",
&"params": {
&"stats": {&"physical_attack": 0.35, &"attack_range": 0.15},
&"duration": 10.0
}
}
})
```

`set_sentinel.tres`:

```
[gd_resource type="Resource" script_class="EquipmentSetResource" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/core/equipment/equipment_set_resource.gd" id="1"]

[resource]
script = ExtResource("1")
set_id = &"set_sentinel"
display_name = "Sentinel"
member_item_ids = Array[StringName]([&"sentinel_visor", &"sentinel_ward", &"sentinels_aegis", &"sentinels_lance", &"sentinels_striders"])
bonuses = Dictionary[int, Dictionary]({
2: {&"attack_range": 16.0},
4: {&"cdr": 0.05, &"elemental_resist_fire": 0.06, &"elemental_resist_frost": 0.06}
})
effects = Dictionary[int, Dictionary]({
4: {
&"name": "Overwatch",
&"type": &"phase_state",
&"params": {
&"stats": {&"attack_range": 0.2},
&"phases": ["WAVE_ACTIVE"]
}
}
})
```

`set_troll.tres`:

```
[gd_resource type="Resource" script_class="EquipmentSetResource" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/core/equipment/equipment_set_resource.gd" id="1"]

[resource]
script = ExtResource("1")
set_id = &"set_troll"
display_name = "Troll"
member_item_ids = Array[StringName]([&"troll_hide_mantle", &"trollhide_buckler", &"trollhide_striders", &"trollmarrow_band"])
bonuses = Dictionary[int, Dictionary]({
2: {&"max_hp": 60.0},
4: {&"lifesteal": 0.02, &"max_hp": 80.0}
})
effects = Dictionary[int, Dictionary]({
4: {
&"name": "Troll's Frenzy",
&"type": &"on_kill_stack_buff",
&"params": {
&"stats": {&"physical_attack": 0.03},
&"max_stacks": 10,
&"duration": 6.0
}
}
})
```

`set_warlord.tres`:

```
[gd_resource type="Resource" script_class="EquipmentSetResource" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/core/equipment/equipment_set_resource.gd" id="1"]

[resource]
script = ExtResource("1")
set_id = &"set_warlord"
display_name = "Warlord"
member_item_ids = Array[StringName]([&"warlords_battleplate", &"warlords_greatblade", &"warlords_greaves", &"warlords_legguards", &"warlords_standard_amulet"])
bonuses = Dictionary[int, Dictionary]({
2: {&"physical_attack": 5.0},
4: {&"max_hp": 80.0, &"armor": 15.0},
5: {&"additive_bonus_total": 0.05}
})
effects = Dictionary[int, Dictionary]({
5: {
&"name": "Battle Cry",
&"type": &"on_wave_start_buff",
&"params": {
&"stats": {&"physical_attack": 0.2, &"magic_attack": 0.2},
&"duration": 15.0
}
}
})
```

`set_lurker.tres`:

```
[gd_resource type="Resource" script_class="EquipmentSetResource" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/core/equipment/equipment_set_resource.gd" id="1"]

[resource]
script = ExtResource("1")
set_id = &"set_lurker"
display_name = "Lurker"
member_item_ids = Array[StringName]([&"lurker_claw_gauntlets", &"lurker_fang_blade"])
bonuses = Dictionary[int, Dictionary]({
2: {&"crit_chance": 0.05, &"lifesteal": 0.015}
})
effects = Dictionary[int, Dictionary]({
2: {
&"name": "Venom Strike",
&"type": &"on_crit_status",
&"params": {
&"effect_type": "poison",
&"effect_value": 0.06,
&"effect_duration": 4.0
}
}
})
```

- [ ] **Step 4: Run tests to verify they pass**

Run the Step 2 command. Expected: PASS, including the pre-existing `test_members_and_bonuses_match_the_spec_table_exactly` (proves the stat bonuses were not disturbed) and `test_every_set_passes_validate` (proves every capstone validates).

- [ ] **Step 5: Commit**

```bash
git add assets/data/equipment_sets tests/unit/equipment/equipment_set_content_test.gd
git commit -m "Author the nine set capstone effects

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 3: Hero transient modifier layer and `is_direct_kill()`

**Files:**
- Modify: `src/core/hero/hero.gd` (fields after `_additive_bonuses` ~line 375; `get_effective_stat` ~line 518; `reset_to_defaults` ~line 1477; `_resolve_kill_xp_band` ~line 252)
- Test: `tests/unit/hero/hero_effect_modifiers_test.gd`

**Interfaces:**
- Produces on `Hero`: `set_effect_modifier(source_key: StringName, stat_additive: Dictionary) -> void`, `clear_effect_modifier(source_key: StringName) -> void`, `clear_all_effect_modifiers() -> void`, `is_direct_kill(payload: MonsterDiedEvent) -> bool`.
- Behaviour: modifiers fold into the additive bucket inside `get_effective_stat()`; `reset_to_defaults()` clears them; never saved.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/hero/hero_effect_modifiers_test.gd`:

```gdscript
extends GdUnitTestSuite

## Unit tests for Hero's transient effect-modifier layer and is_direct_kill()
## (equipment-set-effects spec §3.4/§3.5, AC-9/AC-10).

var _hero: Hero


func before_test() -> void:
	GInventory.reset_to_defaults()
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[&"physical_attack"] = 100.0
	_hero._base_stats[&"attack_range"] = 200.0
	_hero.global_position = Vector2.ZERO


func after_test() -> void:
	GInventory.reset_to_defaults()
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


func _kill(x: float, source: String = "") -> MonsterDiedEvent:
	var payload := MonsterDiedEvent.new()
	payload.world_position = Vector2(x, 0.0)
	payload.kill_source = source
	return payload


func test_modifier_raises_the_effective_stat_as_a_percentage() -> void:
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.25})
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(125.0, 0.0001)


func test_two_sources_sum_and_clear_independently() -> void:
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.25})
	_hero.set_effect_modifier(&"b", {&"physical_attack": 0.10})
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(135.0, 0.0001)
	_hero.clear_effect_modifier(&"a")
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(110.0, 0.0001)
	_hero.clear_effect_modifier(&"b")
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(100.0, 0.0001)


func test_setting_the_same_source_again_replaces_it() -> void:
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.25})
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.10})
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(110.0, 0.0001)


func test_clear_all_removes_every_source() -> void:
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.25})
	_hero.set_effect_modifier(&"b", {&"attack_range": 0.5})
	_hero.clear_all_effect_modifiers()
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(100.0, 0.0001)
	assert_float(_hero.get_effective_stat(&"attack_range")).is_equal_approx(200.0, 0.0001)


func test_clearing_an_unknown_source_is_a_no_op() -> void:
	_hero.clear_effect_modifier(&"nope")
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(100.0, 0.0001)


func test_modifier_is_bounded_by_the_existing_additive_cap() -> void:
	_hero.set_effect_modifier(&"a", {&"physical_attack": 5.0})
	# ADDITIVE_BONUS_CAP is 3.0 -> multiplier 4.0
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(400.0, 0.0001)


func test_equipment_recompute_does_not_wipe_a_live_modifier() -> void:
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.25})
	_hero._recompute_equipment_bonuses()
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(125.0, 0.0001)


func test_reset_to_defaults_clears_modifiers() -> void:
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.25})
	_hero.reset_to_defaults()
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(100.0, 0.0001)


func test_modifiers_are_not_part_of_the_save_data() -> void:
	var before: Dictionary = _hero.get_save_data()
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.25})
	assert_bool(_hero.get_save_data() == before).is_true()


func test_is_direct_kill_true_inside_attack_range() -> void:
	assert_bool(_hero.is_direct_kill(_kill(150.0))).is_true()


func test_is_direct_kill_false_outside_attack_range() -> void:
	assert_bool(_hero.is_direct_kill(_kill(250.0))).is_false()


func test_is_direct_kill_false_for_wave_end_despawns() -> void:
	assert_bool(_hero.is_direct_kill(_kill(10.0, "wave_end"))).is_false()


func test_is_direct_kill_follows_a_range_modifier() -> void:
	_hero.set_effect_modifier(&"a", {&"attack_range": 0.5})
	assert_bool(_hero.is_direct_kill(_kill(250.0))).is_true()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/hero/hero_effect_modifiers_test.gd --ignoreHeadlessMode`
Expected: FAIL (`set_effect_modifier` / `is_direct_kill` not defined).

- [ ] **Step 3: Implement**

Edit 1, in `src/core/hero/hero.gd`, directly after the line `var _additive_bonuses: Dictionary[StringName, float] = {}` (and its doc comment) add:

```gdscript

## Equipment-set-effects spec §3.5: transient stat modifiers set by
## SetEffectController (source key -> {stat: additive fraction}). Kept
## separate from _additive_bonuses so _recompute_equipment_bonuses() (which
## rebuilds that bucket wholesale) can never wipe a live buff. Never saved.
var _effect_modifiers: Dictionary[StringName, Dictionary] = {}

## Cached per-stat sum of _effect_modifiers, refolded only on set/clear.
var _effect_additive: Dictionary[StringName, float] = {}
```

Edit 2, in `get_effective_stat()`, replace

```gdscript
	var additive: float = _additive_bonuses.get(stat_name, 0.0)
```

with

```gdscript
	var additive: float = _additive_bonuses.get(stat_name, 0.0) + _effect_additive.get(stat_name, 0.0)
```

Edit 3, add these methods immediately after `get_effective_stat()`:

```gdscript
## Equipment-set-effects spec §3.5. Replaces any modifier previously set under
## `source_key`. `stat_additive` values are additive fractions (0.25 = +25%),
## folded into the same clamp(1 + additive, floor, cap) as gear bonuses.
func set_effect_modifier(source_key: StringName, stat_additive: Dictionary) -> void:
	_effect_modifiers[source_key] = stat_additive.duplicate()
	_refold_effect_modifiers()


func clear_effect_modifier(source_key: StringName) -> void:
	if _effect_modifiers.erase(source_key):
		_refold_effect_modifiers()


func clear_all_effect_modifiers() -> void:
	if _effect_modifiers.is_empty():
		return
	_effect_modifiers.clear()
	_refold_effect_modifiers()


func _refold_effect_modifiers() -> void:
	_effect_additive.clear()
	for source_key: StringName in _effect_modifiers:
		var modifier: Dictionary = _effect_modifiers[source_key]
		for stat: Variant in modifier:
			var key: StringName = StringName(stat)
			_effect_additive[key] = _effect_additive.get(key, 0.0) + float(modifier[stat])


## Equipment-set-effects spec §3.4: a kill counts as a "direct kill" when it is
## a real kill (not a wave-end force-clear) inside Hero's effective attack
## range -- the same inner band kill XP uses. One rule, two consumers.
func is_direct_kill(payload: MonsterDiedEvent) -> bool:
	if payload.kill_source == "wave_end":
		return false
	return global_position.distance_to(payload.world_position) <= get_effective_stat(&"attack_range")
```

Edit 4, in `reset_to_defaults()`, add `clear_all_effect_modifiers()` as the last statement (after `_accumulated_class_bonuses.clear()`).

Edit 5, in `_resolve_kill_xp_band()`, replace the block

```gdscript
	var attack_range: float = get_effective_stat(&"attack_range")
	var distance: float = global_position.distance_to(payload.world_position)
	if distance <= attack_range:
		return base_xp
	if distance <= attack_range * KILL_XP_OUTER_BAND_RANGE_MULTIPLIER:
```

with

```gdscript
	if is_direct_kill(payload):
		return base_xp
	var attack_range: float = get_effective_stat(&"attack_range")
	var distance: float = global_position.distance_to(payload.world_position)
	if distance <= attack_range * KILL_XP_OUTER_BAND_RANGE_MULTIPLIER:
```

(The early `if payload.kill_source == "wave_end": return 0` and the `base_xp <= 0` return stay unchanged.)

- [ ] **Step 4: Run tests to verify they pass, and prove XP is unchanged**

Run: `... -a res://tests/unit/hero/hero_effect_modifiers_test.gd ...` Expected: PASS.
Run: `... -a res://tests/unit/hero/hero_leveling_test.gd ...` and `... -a res://tests/unit/hero/hero_stat_resolution_test.gd ...` and `... -a res://tests/unit/hero/hero_equipment_stats_test.gd ...` Expected: PASS, unchanged (AC-10).

- [ ] **Step 5: Commit**

```bash
git add src/core/hero/hero.gd tests/unit/hero/hero_effect_modifiers_test.gd tests/unit/hero/hero_effect_modifiers_test.gd.uid
git commit -m "Add Hero transient effect-modifier layer and is_direct_kill

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

(Generate the test's `.gd.uid` first with the editor-mode command from Global Constraints; if the `.uid` file does not exist, drop it from `git add`.)

---

### Task 4: `MonsterManager.apply_dot()` and the `monster_manager` group

**Files:**
- Modify: `src/core/monster/monster_manager.gd` (constants near line 61; `_ready` line 129; new method after `_apply_dot_effect` ~line 306)
- Test: `tests/unit/monster/monster_apply_dot_test.gd`

**Interfaces:**
- Produces: `MonsterManager.GROUP_NAME: StringName = &"monster_manager"`; `MonsterManager.apply_dot(target_monster_id: int, effect_type: String, effect_value: float, effect_duration: float) -> void`.
- The manager joins the group in `_ready()`.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/monster/monster_apply_dot_test.gd` (stubs copied from `monster_status_effect_test.gd`):

```gdscript
extends GdUnitTestSuite

## Unit tests for MonsterManager.apply_dot() and its group membership
## (equipment-set-effects spec §3.6, AC-11). Stub/fixture pattern mirrors
## monster_status_effect_test.gd exactly.

class _StubGrid extends RefCounted:
	func get_cell_type(_cell: Vector2i) -> int:
		return Grid.CellType.SPAWN

	func cell_to_world(cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x) * 64.0, float(cell.y) * 64.0)

	func world_to_cell(pos: Vector2) -> Vector2i:
		return Vector2i(int(pos.x / 64.0), int(pos.y / 64.0))

	func get_towers_in_range(_center: Vector2i, _radius: int) -> Array[int]:
		return []


class _StubPathfinding extends RefCounted:
	func find_path(_from: Vector2i, _tier: int) -> Array[Vector2i]:
		return [Vector2i(1, 0), Vector2i(2, 0)]


const SPAWN_CELL := Vector2i(0, 0)

var _mm: MonsterManager


func before_test() -> void:
	_mm = MonsterManager.new()
	add_child(_mm)
	_mm._grid = _StubGrid.new()
	_mm._pathfinding = _StubPathfinding.new()
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	_mm._resource_table = {}
	_mm.set_physics_process(false)


func after_test() -> void:
	for e: MonsterEntity in _mm.active_monsters:
		if is_instance_valid(e):
			e.free()
	remove_child(_mm)
	_mm.free()


func _spawn(base_hp: float) -> MonsterEntity:
	var res := MonsterResource.new()
	res.monster_id = &"goblin"
	res.display_name = "Test Monster"
	res.tier = 0
	res.base_hp = base_hp
	res.base_speed = 1.0
	res.drop_table_id = &"goblin_drops"
	res.menagerie_attraction_drop_chance = 0.05
	_mm._resource_table[&"goblin"] = res
	return _mm.spawn_monster(&"goblin", SPAWN_CELL, 1, 1)


func test_manager_joins_the_monster_manager_group() -> void:
	assert_bool(_mm.is_in_group(MonsterManager.GROUP_NAME)).is_true()
	assert_bool(MonsterManager.GROUP_NAME == &"monster_manager").is_true()


func test_apply_dot_creates_the_same_instance_as_the_tower_path() -> void:
	var via_tower: MonsterEntity = _spawn(200.0)
	_mm._on_tower_attacked_status(1, via_tower.entity_id, 0.0, false, false, "burn", 0.10, 3.0, 0.0, false)
	var via_api: MonsterEntity = _spawn(200.0)
	_mm.apply_dot(via_api.entity_id, "burn", 0.10, 3.0)
	assert_int(via_api.active_status_effects.size()).is_equal(1)
	var expected: ActiveStatusEffect = via_tower.active_status_effects[0]
	var actual: ActiveStatusEffect = via_api.active_status_effects[0]
	assert_str(actual.effect_type).is_equal(expected.effect_type)
	assert_int(actual.ticks_remaining).is_equal(expected.ticks_remaining)
	assert_float(actual.tick_damage).is_equal_approx(expected.tick_damage, 0.0001)


func test_apply_dot_stacks_with_existing_instances() -> void:
	var entity: MonsterEntity = _spawn(200.0)
	_mm.apply_dot(entity.entity_id, "poison", 0.06, 4.0)
	_mm.apply_dot(entity.entity_id, "poison", 0.06, 4.0)
	assert_int(entity.active_status_effects.size()).is_equal(2)


func test_apply_dot_ignores_an_unrecognized_effect_type() -> void:
	var entity: MonsterEntity = _spawn(200.0)
	_mm.apply_dot(entity.entity_id, "nonsense", 0.06, 4.0)
	assert_int(entity.active_status_effects.size()).is_equal(0)


func test_apply_dot_on_an_unknown_target_is_a_no_op() -> void:
	_mm.apply_dot(99999, "burn", 0.10, 3.0)
	assert_int(_mm.active_monsters.size()).is_equal(0)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/monster/monster_apply_dot_test.gd --ignoreHeadlessMode`
Expected: FAIL (`GROUP_NAME` / `apply_dot` not defined).

- [ ] **Step 3: Implement**

In `src/core/monster/monster_manager.gd`, directly above the `const RECOGNIZED_DOT_EFFECTS` line add:

```gdscript
## Equipment-set-effects spec §3.6: MonsterManager is a mission-scene child (not
## an autoload), so SetEffectController finds it via this group.
const GROUP_NAME: StringName = &"monster_manager"
```

In `_ready()`, add as the first statement:

```gdscript
	add_to_group(GROUP_NAME)
```

Directly after `_apply_dot_effect()` add:

```gdscript
## Public DoT entry for non-tower sources (e.g. equipment-set capstones).
## Same stacking instance as a tower hit; unrecognized types are ignored.
func apply_dot(target_monster_id: int, effect_type: String, effect_value: float,
		effect_duration: float) -> void:
	if not RECOGNIZED_DOT_EFFECTS.has(effect_type):
		return
	_apply_dot_effect(target_monster_id, effect_type, effect_value, effect_duration)
```

- [ ] **Step 4: Run tests to verify they pass, and prove the tower path is unchanged**

Run the Step 2 command. Expected: PASS.
Run: `... -a res://tests/unit/monster/monster_status_effect_test.gd ...` Expected: PASS, unchanged.

- [ ] **Step 5: Commit**

```bash
git add src/core/monster/monster_manager.gd tests/unit/monster/monster_apply_dot_test.gd tests/unit/monster/monster_apply_dot_test.gd.uid
git commit -m "Expose MonsterManager.apply_dot and join the monster_manager group

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 5: `SetEffectResolver`

**Files:**
- Create: `src/core/equipment/set_effect_resolver.gd`
- Test: `tests/unit/equipment/set_effect_resolver_test.gd`

**Interfaces:**
- Consumes: `EquipmentBonuses.set_piece_counts(slot_contents: Array[Dictionary]) -> Dictionary` (`{set_id: int}`), `GGameDataRegistry.get_equipment_set()`, `EquipmentSetResource.effects` (Tasks 1-2).
- Produces: `SetEffectResolver.effect_key(set_id: StringName, threshold: int) -> StringName` (`&"set_lurker:2"`); `SetEffectResolver.active_effects(slot_contents: Array[Dictionary]) -> Array[Dictionary]` returning entries `{&"key", &"set_id", &"threshold", &"name", &"type", &"params"}` sorted by set_id then threshold; `SetEffectResolver.effects_for_set(set_id: StringName) -> Dictionary` (`threshold -> effect`, `{}` for unknown sets).

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/equipment/set_effect_resolver_test.gd`:

```gdscript
extends GdUnitTestSuite

## Unit tests for SetEffectResolver (equipment-set-effects spec §3.3, AC-2).
## Pure: takes equipped-contents lists, never touches GInventory.


func _c(item_id: String) -> Dictionary:
	return {"item_id": item_id, "stat_overrides": {}, "imbued_runes": [], "rune_slot_count": 0}


func _list(item_ids: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item_id: String in item_ids:
		out.append(_c(item_id))
	return out


func test_no_pieces_yields_no_effects() -> void:
	assert_array(SetEffectResolver.active_effects(_list([]))).is_empty()


func test_below_threshold_yields_no_effect() -> void:
	assert_array(SetEffectResolver.active_effects(_list(["lurker_fang_blade"]))).is_empty()


func test_lurker_capstone_activates_at_two_pieces() -> void:
	var effects: Array[Dictionary] = SetEffectResolver.active_effects(_list(["lurker_claw_gauntlets", "lurker_fang_blade"]))
	assert_int(effects.size()).is_equal(1)
	var effect: Dictionary = effects[0]
	assert_bool(effect[&"key"] == &"set_lurker:2").is_true()
	assert_bool(effect[&"set_id"] == &"set_lurker").is_true()
	assert_int(effect[&"threshold"]).is_equal(2)
	assert_str(String(effect[&"name"])).is_equal("Venom Strike")
	assert_bool(effect[&"type"] == &"on_crit_status").is_true()
	assert_float(float((effect[&"params"] as Dictionary)[&"effect_value"])).is_equal_approx(0.06, 0.0001)


func test_capstone_is_only_at_the_top_threshold() -> void:
	var four: Array[String] = ["brutes_war_helm", "brutes_bulwark_plate", "brute_gauntlets", "brute_legguards"]
	assert_array(SetEffectResolver.active_effects(_list(four))).is_empty()
	var five: Array[String] = four.duplicate()
	five.append("brute_core_band")
	var effects: Array[Dictionary] = SetEffectResolver.active_effects(_list(five))
	assert_int(effects.size()).is_equal(1)
	assert_bool(effects[0][&"key"] == &"set_brute:5").is_true()


func test_identical_items_count_once() -> void:
	assert_array(SetEffectResolver.active_effects(_list(["lurker_fang_blade", "lurker_fang_blade"]))).is_empty()


func test_two_sets_yield_two_effects_sorted_by_set_id() -> void:
	var items: Array[String] = [
		"lurker_claw_gauntlets", "lurker_fang_blade",
		"goblin_fang_circlet", "goblin_claw_gauntlets", "goblin_raider_leggings", "goblin_signet",
	]
	var effects: Array[Dictionary] = SetEffectResolver.active_effects(_list(items))
	assert_int(effects.size()).is_equal(2)
	assert_bool(effects[0][&"set_id"] == &"set_goblin").is_true()
	assert_bool(effects[1][&"set_id"] == &"set_lurker").is_true()


func test_effect_key_format() -> void:
	assert_bool(SetEffectResolver.effect_key(&"set_troll", 4) == &"set_troll:4").is_true()


func test_effects_for_set_returns_declared_effects() -> void:
	var declared: Dictionary = SetEffectResolver.effects_for_set(&"set_brute")
	assert_int(declared.size()).is_equal(1)
	assert_bool(declared.has(5)).is_true()


func test_effects_for_unknown_set_is_empty() -> void:
	assert_bool(SetEffectResolver.effects_for_set(&"set_nope").is_empty()).is_true()
```

- [ ] **Step 2: Run tests to verify they fail**

Run the editor-mode reimport command (new `class_name` is not yet created, so this only regenerates caches), then:
`"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/equipment/set_effect_resolver_test.gd --ignoreHeadlessMode`
Expected: FAIL (`SetEffectResolver` not found).

- [ ] **Step 3: Implement**

Create `src/core/equipment/set_effect_resolver.gd`:

```gdscript
class_name SetEffectResolver
extends RefCounted

## Pure, static answer to "which set capstone effects are active for this
## equipment?" (equipment-set-effects spec §3.3). Same access pattern as
## EquipmentBonuses: reads the registry, holds no state, emits nothing.
## "slot_contents" is the Inventory.get_equipped_item() shape.


static func effect_key(set_id: StringName, threshold: int) -> StringName:
	return StringName("%s:%d" % [set_id, threshold])


## One entry per earned effect: {&"key", &"set_id", &"threshold", &"name",
## &"type", &"params"}, sorted by set_id then threshold. Piece counting reuses
## EquipmentBonuses.set_piece_counts() (distinct item_ids), so the controller
## and the info panel can never disagree.
static func active_effects(slot_contents: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var counts: Dictionary = EquipmentBonuses.set_piece_counts(slot_contents)
	var set_ids: Array = counts.keys()
	set_ids.sort()
	for set_id: StringName in set_ids:
		var set_res: EquipmentSetResource = GGameDataRegistry.get_equipment_set(set_id)
		if set_res == null:
			continue
		var thresholds: Array = set_res.effects.keys()
		thresholds.sort()
		for threshold: int in thresholds:
			if (counts[set_id] as int) < threshold:
				continue
			var effect: Dictionary = set_res.effects[threshold]
			out.append({
				&"key": effect_key(set_id, threshold),
				&"set_id": set_id,
				&"threshold": threshold,
				&"name": effect[&"name"],
				&"type": effect[&"type"],
				&"params": effect[&"params"],
			})
	return out


## The set's declared effects (threshold -> effect), earned or not, for the
## info panel's muted rendering. {} for an unknown set.
static func effects_for_set(set_id: StringName) -> Dictionary:
	var set_res: EquipmentSetResource = GGameDataRegistry.get_equipment_set(set_id)
	if set_res == null:
		return {}
	return set_res.effects.duplicate()
```

- [ ] **Step 4: Run tests to verify they pass**

Run the editor-mode reimport command (registers the new `class_name` and generates the `.uid`), then the Step 2 command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/core/equipment/set_effect_resolver.gd src/core/equipment/set_effect_resolver.gd.uid tests/unit/equipment/set_effect_resolver_test.gd tests/unit/equipment/set_effect_resolver_test.gd.uid
git commit -m "Add SetEffectResolver: pure active-capstone lookup

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 6: `SetEffectController` core and timed buffs

**Files:**
- Create: `src/core/equipment/set_effect_controller.gd`
- Test: `tests/unit/equipment/set_effect_controller_test.gd`

**Interfaces:**
- Consumes: `Hero.set_effect_modifier / clear_effect_modifier / clear_all_effect_modifiers` (Task 3); `SetEffectResolver.active_effects` (Task 5); `EquipmentBonuses.equipped_contents()`.
- Produces: `SetEffectController` (a `Node`, parent must be a `Hero`) with `apply_effects(effects: Array[Dictionary]) -> void` (rebuild body and test seam), handlers `_on_wave_started(_wave_number: int, _total_waves: int, _difficulty: float)`, `_on_hero_skill_activated(_skill_id: String, _target_position: Vector2)`, `_on_hero_died()`, `_on_equipment_slot_changed(_slot: String, _new_item_id: String, _previous_item_id: String)`, `_on_item_rune_imbued(_item_id: String, _rune_id: String, _rune_source: String)`, `_process(delta)`. State fields `_active: Dictionary[StringName, Dictionary]`, `_timers: Dictionary[StringName, float]`, `_stacks: Dictionary[StringName, int]`, `_current_phase: String`. Subscription list via `_subscriptions() -> Array`.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/equipment/set_effect_controller_test.gd`:

```gdscript
extends GdUnitTestSuite

## Unit tests for SetEffectController (equipment-set-effects spec §3.4, AC-5/6/8/12).
## Handlers are called directly (not via GEventBus) so autoload subscribers
## never react. Effects are injected through apply_effects(), isolating the
## controller from inventory content.

var _hero: Hero
var _ctl: SetEffectController


func before_test() -> void:
	GInventory.reset_to_defaults()
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[&"physical_attack"] = 100.0
	_hero._base_stats[&"attack_range"] = 200.0
	_hero.global_position = Vector2.ZERO
	_ctl = SetEffectController.new()
	_hero.add_child(_ctl)


func after_test() -> void:
	GInventory.reset_to_defaults()
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null
	_ctl = null


func _effect(key: String, type: StringName, params: Dictionary) -> Dictionary:
	return {&"key": StringName(key), &"set_id": &"set_test", &"threshold": 2,
		&"name": "Test", &"type": type, &"params": params}


func _wave_buff() -> Dictionary:
	return _effect("set_test:2", &"on_wave_start_buff",
		{&"stats": {&"physical_attack": 0.35}, &"duration": 10.0})


func _skill_buff() -> Dictionary:
	return _effect("set_test2:2", &"on_skill_cast_buff",
		{&"stats": {&"physical_attack": 0.15}, &"duration": 5.0})


func _apply(effects: Array) -> void:
	var typed: Array[Dictionary] = []
	for effect: Dictionary in effects:
		typed.append(effect)
	_ctl.apply_effects(typed)


func _atk() -> float:
	return _hero.get_effective_stat(&"physical_attack")


func test_controller_subscribes_to_every_listed_signal() -> void:
	for pair: Array in _ctl._subscriptions():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		assert_bool(sig.is_connected(handler)).is_true()


func test_controller_disconnects_everything_on_exit() -> void:
	var baseline: int = GEventBus.equipment_slot_changed.get_connections().size()
	_hero.remove_child(_ctl)
	_ctl.free()
	assert_int(GEventBus.equipment_slot_changed.get_connections().size()).is_equal(baseline - 1)
	_ctl = null


func test_wave_start_buff_grants_then_expires() -> void:
	_apply([_wave_buff()])
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)
	_ctl._on_wave_started(1, 5, 1.0)
	assert_float(_atk()).is_equal_approx(135.0, 0.0001)
	_ctl._process(9.9)
	assert_float(_atk()).is_equal_approx(135.0, 0.0001)
	_ctl._process(0.2)
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_wave_start_buff_refreshes_and_never_stacks() -> void:
	_apply([_wave_buff()])
	_ctl._on_wave_started(1, 5, 1.0)
	_ctl._on_wave_started(2, 5, 1.0)
	assert_float(_atk()).is_equal_approx(135.0, 0.0001)
	_ctl._process(6.0)
	_ctl._on_wave_started(3, 5, 1.0)
	_ctl._process(6.0)
	assert_float(_atk()).is_equal_approx(135.0, 0.0001)
	_ctl._process(5.0)
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_skill_cast_buff_grants_and_expires() -> void:
	_apply([_skill_buff()])
	_ctl._on_hero_skill_activated("skill_x", Vector2.ZERO)
	assert_float(_atk()).is_equal_approx(115.0, 0.0001)
	_ctl._process(5.1)
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_a_wave_buff_ignores_skill_casts_and_vice_versa() -> void:
	_apply([_wave_buff()])
	_ctl._on_hero_skill_activated("skill_x", Vector2.ZERO)
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_removing_an_effect_clears_its_modifier_immediately() -> void:
	_apply([_wave_buff()])
	_ctl._on_wave_started(1, 5, 1.0)
	_apply([])
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)
	_ctl._on_wave_started(2, 5, 1.0)
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_unchanged_effect_keeps_its_timer_across_a_rebuild() -> void:
	_apply([_wave_buff()])
	_ctl._on_wave_started(1, 5, 1.0)
	_ctl._process(4.0)
	_apply([_wave_buff()])
	_ctl._process(5.0)
	assert_float(_atk()).is_equal_approx(135.0, 0.0001)
	_ctl._process(2.0)
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_hero_died_clears_every_modifier() -> void:
	_apply([_wave_buff(), _skill_buff()])
	_ctl._on_wave_started(1, 5, 1.0)
	_ctl._on_hero_skill_activated("skill_x", Vector2.ZERO)
	_ctl._on_hero_died()
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_processing_is_only_enabled_while_a_timer_is_live() -> void:
	_apply([_wave_buff()])
	assert_bool(_ctl.is_processing()).is_false()
	_ctl._on_wave_started(1, 5, 1.0)
	assert_bool(_ctl.is_processing()).is_true()
	_ctl._process(11.0)
	assert_bool(_ctl.is_processing()).is_false()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/equipment/set_effect_controller_test.gd --ignoreHeadlessMode`
Expected: FAIL (`SetEffectController` not found).

- [ ] **Step 3: Implement**

Create `src/core/equipment/set_effect_controller.gd`:

```gdscript
class_name SetEffectController
extends Node

## Runs equipment-set capstone effects (equipment-set-effects spec §3.4).
## Lives as a child of Hero. Subscribes to existing EventBus signals only;
## emits none (ADR-0001 Rule 4). All buff durations and kill stacks are owned
## here; Hero only holds the resulting modifiers (Hero.set_effect_modifier).
## Every subscription is disconnected in _exit_tree() (ADR-0001 Rule 6).

var _hero: Hero = null

## Active effects by key (&"<set_id>:<threshold>").
var _active: Dictionary[StringName, Dictionary] = {}

## Remaining seconds for timed effects (wave/skill buffs, kill stacks).
var _timers: Dictionary[StringName, float] = {}

## Current stack count for on_kill_stack_buff effects.
var _stacks: Dictionary[StringName, int] = {}

## Last phase name seen on mission_phase_changed ("" until the first one).
var _current_phase: String = ""


func _ready() -> void:
	_hero = get_parent() as Hero
	if _hero == null:
		push_error("[SetEffectController] must be a direct child of Hero")
		return
	for pair: Array in _subscriptions():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if not sig.is_connected(handler):
			sig.connect(handler)
	set_process(false)
	_rebuild()


func _exit_tree() -> void:
	for pair: Array in _subscriptions():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)
	if _hero != null and is_instance_valid(_hero):
		_hero.clear_all_effect_modifiers()


## Every EventBus subscription this node holds, as [signal, handler] pairs.
## Connected in _ready(), disconnected in _exit_tree(); later tasks add rows.
func _subscriptions() -> Array:
	return [
		[GEventBus.equipment_slot_changed, _on_equipment_slot_changed],
		[GEventBus.item_rune_imbued, _on_item_rune_imbued],
		[GEventBus.wave_started, _on_wave_started],
		[GEventBus.hero_skill_activated, _on_hero_skill_activated],
		[GEventBus.hero_died, _on_hero_died],
	]


func _process(delta: float) -> void:
	for key: StringName in _timers.keys():
		var remaining: float = _timers[key] - delta
		if remaining <= 0.0:
			_expire(key)
		else:
			_timers[key] = remaining
	_update_processing()


# ---------------------------------------------------------------------------
# Rebuild
# ---------------------------------------------------------------------------

func _on_equipment_slot_changed(_slot: String, _new_item_id: String, _previous_item_id: String) -> void:
	_rebuild()


func _on_item_rune_imbued(_item_id: String, _rune_id: String, _rune_source: String) -> void:
	_rebuild()


func _rebuild() -> void:
	apply_effects(SetEffectResolver.active_effects(EquipmentBonuses.equipped_contents()))


## Replaces the active effect set. Effects no longer present are dropped
## (modifier, timer and stacks cleared at once); effects present before and
## after keep their timers and stacks. Also the test seam.
func apply_effects(effects: Array[Dictionary]) -> void:
	var next: Dictionary[StringName, Dictionary] = {}
	for effect: Dictionary in effects:
		next[effect[&"key"]] = effect
	for key: StringName in _active.keys():
		if not next.has(key):
			_drop_effect(key)
	for key: StringName in next:
		if not _active.has(key):
			_active[key] = next[key]
	_update_processing()


func _drop_effect(key: StringName) -> void:
	_active.erase(key)
	_timers.erase(key)
	_stacks.erase(key)
	_hero.clear_effect_modifier(key)


# ---------------------------------------------------------------------------
# Timed buffs: on_wave_start_buff / on_skill_cast_buff
# ---------------------------------------------------------------------------

func _on_wave_started(_wave_number: int, _total_waves: int, _difficulty: float) -> void:
	_grant_timed(&"on_wave_start_buff")


func _on_hero_skill_activated(_skill_id: String, _target_position: Vector2) -> void:
	_grant_timed(&"on_skill_cast_buff")


## Grants (or refreshes -- never stacks) every active effect of `type`.
func _grant_timed(type: StringName) -> void:
	for key: StringName in _active:
		var effect: Dictionary = _active[key]
		if effect[&"type"] != type:
			continue
		var params: Dictionary = effect[&"params"]
		_hero.set_effect_modifier(key, params[&"stats"])
		_timers[key] = float(params[&"duration"])
	_update_processing()


func _expire(key: StringName) -> void:
	_timers.erase(key)
	_stacks.erase(key)
	_hero.clear_effect_modifier(key)


func _on_hero_died() -> void:
	_clear_runtime()


## Drops all timers, stacks and modifiers but keeps the active effect list.
func _clear_runtime() -> void:
	_timers.clear()
	_stacks.clear()
	_hero.clear_all_effect_modifiers()
	_update_processing()


func _update_processing() -> void:
	set_process(not _timers.is_empty())
```

- [ ] **Step 4: Run tests to verify they pass**

Run the editor-mode reimport command (registers `SetEffectController`, generates the `.uid`), then the Step 2 command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/core/equipment/set_effect_controller.gd src/core/equipment/set_effect_controller.gd.uid tests/unit/equipment/set_effect_controller_test.gd tests/unit/equipment/set_effect_controller_test.gd.uid
git commit -m "Add SetEffectController with wave-start and skill-cast buffs

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 7: Controller: `phase_state` and `on_kill_stack_buff`

**Files:**
- Modify: `src/core/equipment/set_effect_controller.gd`
- Test: `tests/unit/equipment/set_effect_controller_test.gd`

**Interfaces:**
- Consumes: `Hero.is_direct_kill` (Task 3); Task 6's state fields and helpers.
- Produces: handlers `_on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float)`, `_on_monster_died(payload: MonsterDiedEvent)`, `_on_monsters_died_batch(payloads: Array[MonsterDiedEvent])`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/equipment/set_effect_controller_test.gd`:

```gdscript
# ---------------------------------------------------------------------------
# phase_state (spec §3.1, AC-7)
# ---------------------------------------------------------------------------

func _phase_effect() -> Dictionary:
	return _effect("set_phase:3", &"phase_state",
		{&"stats": {&"attack_range": 0.20}, &"phases": ["WAVE_ACTIVE"]})


func _range() -> float:
	return _hero.get_effective_stat(&"attack_range")


func test_phase_state_is_active_only_in_listed_phases() -> void:
	_apply([_phase_effect()])
	_ctl._on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)
	assert_float(_range()).is_equal_approx(240.0, 0.0001)
	_ctl._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)
	assert_float(_range()).is_equal_approx(200.0, 0.0001)


func test_phase_state_applies_immediately_when_equipped_mid_phase() -> void:
	_ctl._on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)
	_apply([_phase_effect()])
	assert_float(_range()).is_equal_approx(240.0, 0.0001)


func test_phase_state_is_inactive_before_any_phase_is_seen() -> void:
	_apply([_phase_effect()])
	assert_float(_range()).is_equal_approx(200.0, 0.0001)


func test_removing_a_phase_state_effect_clears_it() -> void:
	_ctl._on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)
	_apply([_phase_effect()])
	_apply([])
	assert_float(_range()).is_equal_approx(200.0, 0.0001)


func test_mission_end_clears_every_modifier_including_timed_buffs() -> void:
	_apply([_phase_effect(), _wave_buff()])
	_ctl._on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)
	_ctl._on_wave_started(1, 5, 1.0)
	_ctl._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)
	assert_float(_range()).is_equal_approx(200.0, 0.0001)
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


# ---------------------------------------------------------------------------
# on_kill_stack_buff (spec §3.1, AC-3)
# ---------------------------------------------------------------------------

func _frenzy() -> Dictionary:
	return _effect("set_frenzy:4", &"on_kill_stack_buff",
		{&"stats": {&"physical_attack": 0.03}, &"max_stacks": 10, &"duration": 6.0})


func _kill(x: float, source: String = "") -> MonsterDiedEvent:
	var payload := MonsterDiedEvent.new()
	payload.world_position = Vector2(x, 0.0)
	payload.kill_source = source
	return payload


func test_a_direct_kill_adds_one_stack() -> void:
	_apply([_frenzy()])
	_ctl._on_monster_died(_kill(50.0))
	assert_float(_atk()).is_equal_approx(103.0, 0.0001)
	_ctl._on_monster_died(_kill(60.0))
	_ctl._on_monster_died(_kill(70.0))
	assert_float(_atk()).is_equal_approx(109.0, 0.0001)


func test_out_of_range_and_wave_end_kills_add_no_stacks() -> void:
	_apply([_frenzy()])
	_ctl._on_monster_died(_kill(900.0))
	_ctl._on_monster_died(_kill(10.0, "wave_end"))
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_a_batch_adds_one_stack_per_qualifying_death() -> void:
	_apply([_frenzy()])
	var batch: Array[MonsterDiedEvent] = [_kill(10.0), _kill(20.0), _kill(900.0), _kill(30.0, "wave_end")]
	_ctl._on_monsters_died_batch(batch)
	assert_float(_atk()).is_equal_approx(106.0, 0.0001)


func test_stacks_are_capped() -> void:
	_apply([_frenzy()])
	var batch: Array[MonsterDiedEvent] = []
	for i: int in range(25):
		batch.append(_kill(10.0))
	_ctl._on_monsters_died_batch(batch)
	assert_float(_atk()).is_equal_approx(130.0, 0.0001)


func test_stacks_expire_after_the_last_kill_and_kills_refresh() -> void:
	_apply([_frenzy()])
	_ctl._on_monster_died(_kill(10.0))
	_ctl._process(5.0)
	_ctl._on_monster_died(_kill(10.0))
	_ctl._process(5.0)
	assert_float(_atk()).is_equal_approx(106.0, 0.0001)
	_ctl._process(1.5)
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_a_new_stack_run_starts_from_zero_after_expiry() -> void:
	_apply([_frenzy()])
	_ctl._on_monster_died(_kill(10.0))
	_ctl._process(7.0)
	_ctl._on_monster_died(_kill(10.0))
	assert_float(_atk()).is_equal_approx(103.0, 0.0001)


func test_kills_do_nothing_when_no_kill_effect_is_active() -> void:
	_ctl._on_monster_died(_kill(10.0))
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/equipment/set_effect_controller_test.gd --ignoreHeadlessMode`
Expected: FAIL (`_on_mission_phase_changed` / `_on_monster_died` / `_on_monsters_died_batch` not defined).

- [ ] **Step 3: Implement**

In `_subscriptions()` add these three rows before the closing `]`:

```gdscript
		[GEventBus.mission_phase_changed, _on_mission_phase_changed],
		[GEventBus.monster_died, _on_monster_died],
		[GEventBus.monsters_died_batch, _on_monsters_died_batch],
```

In `apply_effects()`, replace the second loop

```gdscript
	for key: StringName in next:
		if not _active.has(key):
			_active[key] = next[key]
```

with

```gdscript
	for key: StringName in next:
		if not _active.has(key):
			_active[key] = next[key]
			if next[key][&"type"] == &"phase_state":
				_refresh_phase_state(key)
```

Add these methods after `_on_hero_died()`:

```gdscript
# ---------------------------------------------------------------------------
# phase_state
# ---------------------------------------------------------------------------

func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	_current_phase = new_phase
	if new_phase == "MISSION_COMPLETE" or new_phase == "DEFEAT":
		_clear_runtime()
		return
	for key: StringName in _active:
		if _active[key][&"type"] == &"phase_state":
			_refresh_phase_state(key)


func _refresh_phase_state(key: StringName) -> void:
	var params: Dictionary = _active[key][&"params"]
	if (params[&"phases"] as Array).has(_current_phase):
		_hero.set_effect_modifier(key, params[&"stats"])
	else:
		_hero.clear_effect_modifier(key)


# ---------------------------------------------------------------------------
# on_kill_stack_buff
# ---------------------------------------------------------------------------

func _on_monster_died(payload: MonsterDiedEvent) -> void:
	if not _has_active(&"on_kill_stack_buff"):
		return
	_register_kills(1 if _hero.is_direct_kill(payload) else 0)


## ADR-0001 Rule 5: large waves arrive batched, so this must count each entry.
func _on_monsters_died_batch(payloads: Array[MonsterDiedEvent]) -> void:
	if not _has_active(&"on_kill_stack_buff"):
		return
	var qualifying: int = 0
	for payload: MonsterDiedEvent in payloads:
		if _hero.is_direct_kill(payload):
			qualifying += 1
	_register_kills(qualifying)


func _register_kills(count: int) -> void:
	if count <= 0:
		return
	for key: StringName in _active:
		var effect: Dictionary = _active[key]
		if effect[&"type"] != &"on_kill_stack_buff":
			continue
		var params: Dictionary = effect[&"params"]
		var stacks: int = mini(int(params[&"max_stacks"]), int(_stacks.get(key, 0)) + count)
		_stacks[key] = stacks
		_timers[key] = float(params[&"duration"])
		_hero.set_effect_modifier(key, _scaled(params[&"stats"], stacks))
	_update_processing()


func _has_active(type: StringName) -> bool:
	for key: StringName in _active:
		if _active[key][&"type"] == type:
			return true
	return false


static func _scaled(stats: Dictionary, factor: int) -> Dictionary:
	var out: Dictionary = {}
	for stat: Variant in stats:
		out[stat] = float(stats[stat]) * float(factor)
	return out
```

- [ ] **Step 4: Run tests to verify they pass**

Run the Step 2 command. Expected: PASS (Task 6's tests included).

- [ ] **Step 5: Commit**

```bash
git add src/core/equipment/set_effect_controller.gd tests/unit/equipment/set_effect_controller_test.gd
git commit -m "Add phase_state and kill-stack effects to SetEffectController

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 8: Controller: `on_crit_status`

**Files:**
- Modify: `src/core/equipment/set_effect_controller.gd`
- Test: `tests/unit/equipment/set_effect_controller_test.gd`

**Interfaces:**
- Consumes: `MonsterManager.GROUP_NAME` and `apply_dot(target_id: int, effect_type: String, effect_value: float, effect_duration: float)` (Task 4).
- Produces: `var monster_manager: Node = null` (test seam), handlers `_on_hero_auto_attacked(payload: HeroAutoAttackEvent)`, `_on_hero_skill_attacked(payload: HeroSkillAttackEvent)`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/equipment/set_effect_controller_test.gd`:

```gdscript
# ---------------------------------------------------------------------------
# on_crit_status (spec §3.1, AC-4)
# ---------------------------------------------------------------------------

class _StubMonsterManager extends Node:
	var calls: Array[Array] = []

	func apply_dot(target_id: int, effect_type: String, value: float, duration: float) -> void:
		calls.append([target_id, effect_type, value, duration])


var _stub: _StubMonsterManager


func _install_stub() -> void:
	_stub = _StubMonsterManager.new()
	_ctl.monster_manager = _stub


func _venom() -> Dictionary:
	return _effect("set_venom:2", &"on_crit_status",
		{&"effect_type": "poison", &"effect_value": 0.06, &"effect_duration": 4.0})


func _ember() -> Dictionary:
	return _effect("set_ember:4", &"on_crit_status",
		{&"effect_type": "burn", &"effect_value": 0.08, &"effect_duration": 3.0})


func _auto(is_crit: bool, target_id: int = 7) -> HeroAutoAttackEvent:
	var payload := HeroAutoAttackEvent.new()
	payload.is_crit = is_crit
	payload.target_id = target_id
	return payload


func _skill_hit(is_crit: bool, target_id: int = 9) -> HeroSkillAttackEvent:
	var payload := HeroSkillAttackEvent.new()
	payload.is_crit = is_crit
	payload.target_id = target_id
	return payload


func test_crit_auto_attack_applies_the_configured_dot() -> void:
	_install_stub()
	_apply([_venom()])
	_ctl._on_hero_auto_attacked(_auto(true))
	assert_int(_stub.calls.size()).is_equal(1)
	assert_int(_stub.calls[0][0]).is_equal(7)
	assert_str(_stub.calls[0][1]).is_equal("poison")
	assert_float(_stub.calls[0][2]).is_equal_approx(0.06, 0.0001)
	assert_float(_stub.calls[0][3]).is_equal_approx(4.0, 0.0001)
	_stub.free()


func test_crit_skill_hit_applies_the_configured_dot() -> void:
	_install_stub()
	_apply([_venom()])
	_ctl._on_hero_skill_attacked(_skill_hit(true))
	assert_int(_stub.calls.size()).is_equal(1)
	assert_int(_stub.calls[0][0]).is_equal(9)
	_stub.free()


func test_a_non_crit_applies_nothing() -> void:
	_install_stub()
	_apply([_venom()])
	_ctl._on_hero_auto_attacked(_auto(false))
	_ctl._on_hero_skill_attacked(_skill_hit(false))
	assert_int(_stub.calls.size()).is_equal(0)
	_stub.free()


func test_two_crit_effects_each_apply_their_own_dot() -> void:
	_install_stub()
	_apply([_venom(), _ember()])
	_ctl._on_hero_auto_attacked(_auto(true))
	assert_int(_stub.calls.size()).is_equal(2)
	_stub.free()


func test_no_crit_effect_active_means_no_dot() -> void:
	_install_stub()
	_apply([_wave_buff()])
	_ctl._on_hero_auto_attacked(_auto(true))
	assert_int(_stub.calls.size()).is_equal(0)
	_stub.free()


func test_falls_back_to_the_monster_manager_group() -> void:
	_stub = _StubMonsterManager.new()
	add_child(_stub)
	_stub.add_to_group(MonsterManager.GROUP_NAME)
	_apply([_venom()])
	_ctl._on_hero_auto_attacked(_auto(true))
	assert_int(_stub.calls.size()).is_equal(1)
	remove_child(_stub)
	_stub.free()


func test_crit_with_no_monster_manager_available_is_a_safe_no_op() -> void:
	_apply([_venom()])
	_ctl._on_hero_auto_attacked(_auto(true))
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/equipment/set_effect_controller_test.gd --ignoreHeadlessMode`
Expected: FAIL (`monster_manager` field / `_on_hero_auto_attacked` not defined).

- [ ] **Step 3: Implement**

Add the field under `var _current_phase: String = ""`:

```gdscript

## Test seam. In production leave null: the controller finds MonsterManager
## through its group (MonsterManager.GROUP_NAME) because it is a scene child,
## not an autoload. Typed as Node so tests can inject a recording stub.
var monster_manager: Node = null
```

In `_subscriptions()` add before the closing `]`:

```gdscript
		[GEventBus.hero_auto_attacked, _on_hero_auto_attacked],
		[GEventBus.hero_skill_attacked, _on_hero_skill_attacked],
```

Add these methods at the end of the file:

```gdscript
# ---------------------------------------------------------------------------
# on_crit_status
# ---------------------------------------------------------------------------

## Keys off the crit flag on the emitted event, i.e. before Damage & Status
## rolls evasion (spec §11: an evaded crit can still proc).
func _on_hero_auto_attacked(payload: HeroAutoAttackEvent) -> void:
	if payload.is_crit:
		_apply_crit_status(payload.target_id)


func _on_hero_skill_attacked(payload: HeroSkillAttackEvent) -> void:
	if payload.is_crit:
		_apply_crit_status(payload.target_id)


func _apply_crit_status(target_id: int) -> void:
	if not _has_active(&"on_crit_status"):
		return
	var manager: Node = _resolve_monster_manager()
	if manager == null or not manager.has_method(&"apply_dot"):
		return
	for key: StringName in _active:
		var effect: Dictionary = _active[key]
		if effect[&"type"] != &"on_crit_status":
			continue
		var params: Dictionary = effect[&"params"]
		manager.apply_dot(target_id, String(params[&"effect_type"]),
				float(params[&"effect_value"]), float(params[&"effect_duration"]))


func _resolve_monster_manager() -> Node:
	if monster_manager != null and is_instance_valid(monster_manager):
		return monster_manager
	return get_tree().get_first_node_in_group(MonsterManager.GROUP_NAME)
```

- [ ] **Step 4: Run tests to verify they pass, and check the no-emit rule**

Run the Step 2 command. Expected: PASS (Tasks 6-7 tests included).
Run: `grep -c "\.emit" src/core/equipment/set_effect_controller.gd`
Expected: `0` (the controller emits no EventBus signals; spec AC-12).

- [ ] **Step 5: Commit**

```bash
git add src/core/equipment/set_effect_controller.gd tests/unit/equipment/set_effect_controller_test.gd
git commit -m "Add crit-status DoT effect to SetEffectController

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 9: Wire the controller into `Hero.tscn` and prove it end to end

**Files:**
- Modify (full rewrite with the Write tool): `src/core/hero/Hero.tscn`
- Test: `tests/unit/equipment/set_effect_wiring_test.gd`

**Interfaces:**
- Consumes: `SetEffectController` (Tasks 6-8), real `GInventory` equip flow, the authored Lurker capstone (Task 2).
- Produces: every Hero instanced from `Hero.tscn` (both mission scenes) owns a `SetEffectController` child named `SetEffectController`.

- [ ] **Step 1: Write the failing test**

Create `tests/unit/equipment/set_effect_wiring_test.gd`:

```gdscript
extends GdUnitTestSuite

## End-to-end wiring for set capstones: Hero.tscn owns the controller, and a
## real equip -> rebuild -> proc -> unequip cycle works
## (equipment-set-effects spec §3.4, AC-8/AC-12).

const HERO_SCENE: String = "res://src/core/hero/Hero.tscn"
const GAUNTLETS: String = "res://assets/data/items/lurker_claw_gauntlets.tres"
const BLADE: String = "res://assets/data/items/lurker_fang_blade.tres"

class _StubMonsterManager extends Node:
	var calls: Array[Array] = []

	func apply_dot(target_id: int, effect_type: String, value: float, duration: float) -> void:
		calls.append([target_id, effect_type, value, duration])


var _hero: Hero
var _ctl: SetEffectController
var _stub: _StubMonsterManager


func before_test() -> void:
	GInventory.reset_to_defaults()
	_hero = (load(HERO_SCENE) as PackedScene).instantiate() as Hero
	add_child(_hero)
	_ctl = _hero.get_node_or_null("SetEffectController") as SetEffectController
	_stub = _StubMonsterManager.new()


func after_test() -> void:
	GInventory.reset_to_defaults()
	if _stub != null and is_instance_valid(_stub):
		_stub.free()
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null
	_ctl = null


func test_hero_scene_owns_a_set_effect_controller() -> void:
	assert_object(_ctl).is_not_null()


func test_equipping_a_set_activates_its_capstone_and_unequipping_removes_it() -> void:
	assert_bool(GInventory.equip_item("gloves", load(GAUNTLETS))).is_true()
	assert_bool(_ctl._active.is_empty()).is_true()
	assert_bool(GInventory.equip_item("main_hand", load(BLADE))).is_true()
	assert_bool(_ctl._active.has(&"set_lurker:2")).is_true()
	GInventory.unequip_item("gloves")
	assert_bool(_ctl._active.is_empty()).is_true()
	GInventory.unequip_item("main_hand")


func test_a_crit_procs_the_equipped_capstone() -> void:
	_ctl.monster_manager = _stub
	GInventory.equip_item("gloves", load(GAUNTLETS))
	GInventory.equip_item("main_hand", load(BLADE))
	var payload := HeroAutoAttackEvent.new()
	payload.is_crit = true
	payload.target_id = 3
	_ctl._on_hero_auto_attacked(payload)
	assert_int(_stub.calls.size()).is_equal(1)
	assert_str(_stub.calls[0][1]).is_equal("poison")
	GInventory.unequip_item("gloves")
	GInventory.unequip_item("main_hand")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/equipment/set_effect_wiring_test.gd --ignoreHeadlessMode`
Expected: FAIL (`_ctl` is null: the scene has no controller node).

- [ ] **Step 3: Implement**

Overwrite `src/core/hero/Hero.tscn` with the Write tool:

```
[gd_scene load_steps=4 format=3 uid="uid://hero0scene0the0gap"]

[ext_resource type="Script" path="res://src/core/hero/hero.gd" id="1_hero"]
[ext_resource type="Texture2D" path="res://assets/art/characters/hero_warden_smith.png" id="2_hero_sprite"]
[ext_resource type="Script" path="res://src/core/equipment/set_effect_controller.gd" id="3_seteffects"]

[node name="Hero" type="CharacterBody2D"]
script = ExtResource("1_hero")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_hero_sprite")
scale = Vector2(0.052083, 0.052083)

[node name="SetEffectController" type="Node" parent="."]
script = ExtResource("3_seteffects")
```

- [ ] **Step 4: Run tests to verify they pass, plus scene-level regressions**

Run the Step 2 command. Expected: PASS.
Run: `... -a res://tests/unit/hero/hero_equipment_stats_test.gd ...` Expected: PASS (unchanged).
Then boot-check both mission scenes still load a Hero without errors by running one targeted scene-level suite if one exists (`ls tests/unit/missions tests/integration 2>/dev/null | grep -i "the_gap\|mission_scene"`); if none, note "no scene-level suite; covered by the deferred live-verification checklist".

- [ ] **Step 5: Commit**

```bash
git add src/core/hero/Hero.tscn tests/unit/equipment/set_effect_wiring_test.gd tests/unit/equipment/set_effect_wiring_test.gd.uid
git commit -m "Wire SetEffectController into Hero.tscn with an end-to-end test

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 10: Info panel capstone lines and localization

**Files:**
- Modify: `src/gameplay/ui/inventory_screen/equipment_info_panel.gd` (new statics after `_delta_text` ~line 127; `_set_section_lines` ~line 162)
- Modify: `assets/localization/strings.csv`
- Test: `tests/unit/inventory/equipment_info_panel_sets_test.gd`

**Interfaces:**
- Consumes: `SetEffectResolver.effects_for_set()` (Task 5), the panel's `stat_label()`, `ordered_stats()`, `COLOR_MUTED`, `_colored()`.
- Produces: `static func describe_effect(effect: Dictionary) -> String` on the panel script (loaded via `preload`; the script has no `class_name`).

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/inventory/equipment_info_panel_sets_test.gd`:

```gdscript
# ---------------------------------------------------------------------------
# Capstone lines (equipment-set-effects spec §3.7, AC-13)
# ---------------------------------------------------------------------------

func _fx(type: StringName, params: Dictionary) -> Dictionary:
	return {&"name": "Test", &"type": type, &"params": params}


func test_describe_kill_stack_buff_mentions_stat_stacks_and_duration() -> void:
	var text: String = PanelScript.describe_effect(_fx(&"on_kill_stack_buff",
		{&"stats": {&"physical_attack": 0.03}, &"max_stacks": 10, &"duration": 6.0}))
	assert_str(text).contains(PanelScript.stat_label(&"physical_attack"))
	assert_str(text).contains("3%")
	assert_str(text).contains("10")
	assert_str(text).contains("6s")


func test_describe_crit_status_mentions_the_dot_and_its_size() -> void:
	var text: String = PanelScript.describe_effect(_fx(&"on_crit_status",
		{&"effect_type": "poison", &"effect_value": 0.06, &"effect_duration": 4.0}))
	assert_str(text).contains(tr("SET_EFFECT_STATUS_POISON"))
	assert_str(text).contains("6%")
	assert_str(text).contains("4s")


func test_describe_timed_buffs_mention_stats_and_duration() -> void:
	var wave: String = PanelScript.describe_effect(_fx(&"on_wave_start_buff",
		{&"stats": {&"physical_attack": 0.35, &"attack_range": 0.15}, &"duration": 10.0}))
	assert_str(wave).contains("35%")
	assert_str(wave).contains("15%")
	assert_str(wave).contains("10s")
	var skill: String = PanelScript.describe_effect(_fx(&"on_skill_cast_buff",
		{&"stats": {&"attack_range": 0.2}, &"duration": 5.0}))
	assert_str(skill).contains(PanelScript.stat_label(&"attack_range"))
	assert_str(skill).contains("5s")


func test_describe_phase_state_lists_every_phase() -> void:
	var text: String = PanelScript.describe_effect(_fx(&"phase_state",
		{&"stats": {&"move_speed": 0.3}, &"phases": ["SCOUT", "INTERMISSION"]}))
	assert_str(text).contains(tr("SET_EFFECT_PHASE_SCOUT"))
	assert_str(text).contains(tr("SET_EFFECT_PHASE_INTERMISSION"))
	assert_str(text).contains("30%")


## The exact line the panel renders for a set's capstone at `threshold`.
## get_body_text() strips BBCode, so earned/muted styling is asserted on the
## raw RichTextLabel text (_body.text) instead.
func _capstone_line(set_id: StringName, threshold: int) -> String:
	var effect: Dictionary = GGameDataRegistry.get_equipment_set(set_id).effects[threshold]
	return "  " + tr("SET_EFFECT_CAPSTONE_LINE") % [threshold, effect[&"name"], PanelScript.describe_effect(effect)]


func test_bonuses_state_shows_an_earned_capstone_unmuted() -> void:
	_equip("gloves", "lurker_claw_gauntlets")
	_equip("main_hand", "lurker_fang_blade")
	_panel.show_bonuses()
	var line: String = _capstone_line(&"set_lurker", 2)
	assert_str(_panel.get_body_text()).contains("Venom Strike")
	assert_str(_panel._body.text).contains(line)
	assert_str(_panel._body.text).not_contains("[color=%s]%s[/color]" % [PanelScript.COLOR_MUTED, line])


func test_bonuses_state_shows_an_unearned_capstone_muted() -> void:
	_equip("helmet", "brutes_war_helm")
	_equip("gloves", "brute_gauntlets")
	_panel.show_bonuses()
	var line: String = _capstone_line(&"set_brute", 5)
	assert_str(_panel.get_body_text()).contains("Juggernaut")
	assert_str(_panel._body.text).contains("[color=%s]%s[/color]" % [PanelScript.COLOR_MUTED, line])


func test_a_set_with_no_pieces_equipped_shows_no_capstone() -> void:
	_panel.show_bonuses()
	assert_str(_panel.get_body_text()).not_contains("Juggernaut")

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a res://tests/unit/inventory/equipment_info_panel_sets_test.gd --ignoreHeadlessMode`
Expected: FAIL (`describe_effect` not defined).

- [ ] **Step 3: Implement**

Append the rows to `assets/localization/strings.csv` (CRLF, no commas in text):

```bash
printf '%s\r\n' \
  'SET_EFFECT_CAPSTONE_LINE,Capstone (%d pieces): %s - %s' \
  'SET_EFFECT_ON_KILL_STACK_BUFF,Each nearby kill adds a stack of %s (up to %d stacks). Stacks last %s after the last kill.' \
  'SET_EFFECT_ON_CRIT_STATUS,Critical hits inflict %s for %d%% of max HP over %s.' \
  'SET_EFFECT_STATUS_BURN,burn' \
  'SET_EFFECT_STATUS_POISON,poison' \
  'SET_EFFECT_ON_WAVE_START_BUFF,At the start of each wave gain %s for %s.' \
  'SET_EFFECT_ON_SKILL_CAST_BUFF,After casting a skill gain %s for %s.' \
  'SET_EFFECT_PHASE_STATE,During %s: %s.' \
  'SET_EFFECT_PHASE_IDLE,Idle' \
  'SET_EFFECT_PHASE_SCOUT,Scout' \
  'SET_EFFECT_PHASE_PRE_WAVE,Pre-wave' \
  'SET_EFFECT_PHASE_WAVE_ACTIVE,Waves' \
  'SET_EFFECT_PHASE_INTERMISSION,Intermission' \
  'SET_EFFECT_PHASE_MISSION_COMPLETE,Mission complete' \
  'SET_EFFECT_PHASE_DEFEAT,Defeat' \
  >> assets/localization/strings.csv
```

In `equipment_info_panel.gd`, add after `_delta_text()`:

```gdscript
## "Physical Attack +35%, Attack Range +15%" for an effect's additive stats.
static func _effect_stats_text(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for stat: StringName in ordered_stats(stats):
		parts.append("%s +%d%%" % [stat_label(stat), int(roundf(float(stats[stat]) * 100.0))])
	return ", ".join(parts)


static func _seconds_text(seconds: Variant) -> String:
	return "%ss" % String.num(float(seconds))


## Player-facing description of one capstone effect ({&"name", &"type",
## &"params"}). Lives here (UI layer) because it needs stat_label(); static, so
## it uses TranslationServer rather than tr().
static func describe_effect(effect: Dictionary) -> String:
	var params: Dictionary = effect[&"params"]
	match StringName(effect[&"type"]):
		&"on_kill_stack_buff":
			return TranslationServer.translate("SET_EFFECT_ON_KILL_STACK_BUFF") % [
				_effect_stats_text(params[&"stats"]), int(params[&"max_stacks"]), _seconds_text(params[&"duration"])]
		&"on_crit_status":
			var status: String = TranslationServer.translate("SET_EFFECT_STATUS_%s" % String(params[&"effect_type"]).to_upper())
			return TranslationServer.translate("SET_EFFECT_ON_CRIT_STATUS") % [
				status, int(roundf(float(params[&"effect_value"]) * 100.0)), _seconds_text(params[&"effect_duration"])]
		&"on_wave_start_buff":
			return TranslationServer.translate("SET_EFFECT_ON_WAVE_START_BUFF") % [
				_effect_stats_text(params[&"stats"]), _seconds_text(params[&"duration"])]
		&"on_skill_cast_buff":
			return TranslationServer.translate("SET_EFFECT_ON_SKILL_CAST_BUFF") % [
				_effect_stats_text(params[&"stats"]), _seconds_text(params[&"duration"])]
		&"phase_state":
			var names: Array[String] = []
			for phase: Variant in (params[&"phases"] as Array):
				names.append(TranslationServer.translate("SET_EFFECT_PHASE_%s" % String(phase)))
			return TranslationServer.translate("SET_EFFECT_PHASE_STATE") % [
				" / ".join(names), _effect_stats_text(params[&"stats"])]
	return String(effect.get(&"type", ""))
```

In `_set_section_lines()`, add this block after the existing threshold loop (still inside the `for set_id` loop, before the loop ends):

```gdscript
		var effect_thresholds: Array = SetEffectResolver.effects_for_set(set_id).keys()
		effect_thresholds.sort()
		for threshold: int in effect_thresholds:
			var effect: Dictionary = set_res.effects[threshold]
			var capstone: String = tr("SET_EFFECT_CAPSTONE_LINE") % [threshold, effect[&"name"], describe_effect(effect)]
			var line: String = "  " + capstone
			lines.append(line if count >= threshold else _colored(line, COLOR_MUTED))
```

- [ ] **Step 4: Reimport translations, then run tests**

Run the editor-mode reimport command (Global Constraints), then the Step 2 command. Expected: PASS (the pre-existing panel tests in this file included).
Then run: `... -a res://tests/unit/inventory/equipment_info_panel_test.gd ...` and `... -a res://tests/unit/inventory/equipment_info_panel_sets_test.gd ...` Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/gameplay/ui/inventory_screen/equipment_info_panel.gd assets/localization/strings.csv tests/unit/inventory/equipment_info_panel_sets_test.gd
git commit -m "Show set capstones in the equipment info panel

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

### Task 11: Docs, spec reconciliation and session state

**Files:**
- Create: `design/balance/equipment-set-effects.md`
- Modify: `docs/superpowers/specs/2026-09-25-equipment-set-effects-design.md`, `design/gdd/equipment-forge.md` (near line 435), `production/session-state/active.md`

**Interfaces:** none (documentation only).

- [ ] **Step 1: Create the balance mirror**

Write `design/balance/equipment-set-effects.md` with: header (authored 2026-09-25, status first-pass unplaytested, spec link), the rules (five effect types, top-threshold-only, additive fractions, refresh-not-stack, direct-kill = inside attack range and not `wave_end`), the nine-row table copied from spec §4, the DoT scale reference (tower poison 0.08 over 4s, burn 0.10 over 3s), and the open questions from spec §11 (inert defensive stats, evaded crits, controller-created-late `phase_state`, cross-set stacking, all numbers unplaytested).

- [ ] **Step 2: Reconcile the spec with the three plan deviations**

Edit `docs/superpowers/specs/2026-09-25-equipment-set-effects-design.md`:
- §3.3: remove the `describe` bullet from `SetEffectResolver`; add: "The player-facing description is built by `EquipmentInfoPanel.describe_effect()` (UI layer), not the resolver."
- §3.4 Crit status: replace the direct call wording with "resolves MonsterManager through the `monster_manager` group (`MonsterManager.GROUP_NAME`), with a `monster_manager` field as a test seam"; §3.6: add "MonsterManager joins group `monster_manager` in `_ready()`."
- §3.4 Direct kill: replace "for its own first two checks" with "for its inner-band comparison (the early `wave_end` return stays, since the outer band still needs it)".
- §3.7: replace "`SetEffectResolver.describe()`" with "`EquipmentInfoPanel.describe_effect()`".
- Header `Status`: append "Plan: `docs/superpowers/plans/2026-09-25-equipment-set-effects.md`."

- [ ] **Step 3: Cross-reference and session state**

- `design/gdd/equipment-forge.md`: directly after the existing 2026-09-20 set-bonuses update note (~line 435) add: `> **Update 2026-09-25:** each set now also has one capstone effect at its top threshold (five effect types) — see docs/superpowers/specs/2026-09-25-equipment-set-effects-design.md.`
- `production/session-state/active.md`: append a dated extract "Equipment Set Effects" covering: what shipped (capstone data, resolver, controller, Hero modifier layer, `apply_dot`, panel lines), the Troll amendment and why, the three deviations, tests run (targeted list), what is NOT verified (nothing seen in the running game; add checklist items: equip 2 Lurker pieces and crit → poison ticks; Brute 5pc → wave-start buff and its panel line; Sentinel 4pc → range during waves; Troll 4pc → stacks on kills; reimport translation first), and the open items (inert defensive stats needs a hero-damage design decision; cross-set stacking; numbers unplaytested).

- [ ] **Step 4: Commit**

```bash
git add design/balance/equipment-set-effects.md docs/superpowers/specs/2026-09-25-equipment-set-effects-design.md design/gdd/equipment-forge.md production/session-state/active.md docs/superpowers/plans/2026-09-25-equipment-set-effects.md
git commit -m "Document equipment set effects and reconcile the spec with the plan

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git show --name-only --format= HEAD
git push origin main
```

---

## Self-Review

**Spec coverage** (spec section -> task): §3.1 vocabulary -> Tasks 6-8 (five types: timed buffs T6, `phase_state` + kill stacks T7, crit status T8); §3.2 data + validation -> T1, authored values T2; §3.3 resolver -> T5 (description moved to panel, T10, recorded as deviation 1); §3.4 controller lifecycle/rebuild/timers/direct kill/crit/cascade/clearing -> T6-T8 (+ `is_direct_kill` T3, wiring T9); §3.5 Hero layer -> T3; §3.6 `apply_dot` -> T4 (+ group, deviation 2); §3.7 UI + localization -> T10; §3.8 persistence -> T3 test (`get_save_data` unchanged); §3.9 content invariants -> T2; §4 values -> T2 (locked by test); AC-1 -> T1, AC-2 -> T5, AC-3 -> T7, AC-4 -> T8, AC-5/6 -> T6, AC-7 -> T7, AC-8 -> T6/T9, AC-9 -> T3, AC-10 -> T3 (existing XP suites re-run), AC-11 -> T4 (existing status suite re-run), AC-12 -> T6 (disconnect test) + T8 (`grep -c "\.emit"` = 0), AC-13 -> T10, AC-14 -> T2. §10 out-of-scope items are intentionally not built.

**Placeholder scan:** no TBD/TODO; every code step shows code. One step is deliberately conditional on a fact to read at execution time and says exactly what to check: Task 9 Step 4 (whether a scene-level suite exists). Task 11 Step 1 gives the required content of a prose document rather than its full text.

**Type/name consistency:** effect dict keys are always `&"key" &"set_id" &"threshold" &"name" &"type" &"params"` (resolver output = controller input = test fixtures); `stats` sub-dicts are `{StringName: float}`; `apply_effects(effects: Array[Dictionary])` (T6) is called with typed arrays in T6-T9 tests via the `_apply()` helper; handler names/arity in T6-T8 match `_subscriptions()` rows and the signal signatures (`wave_started(int,int,float)`, `hero_skill_activated(String,Vector2)`, `mission_phase_changed(String,String,float)`, `equipment_slot_changed(String,String,String)`, `item_rune_imbued(String,String,String)`, `hero_died()`, `monster_died(payload)`, `monsters_died_batch(Array[MonsterDiedEvent])`, `hero_auto_attacked(payload)`, `hero_skill_attacked(payload)`); `Hero.set_effect_modifier/clear_effect_modifier/clear_all_effect_modifiers/is_direct_kill` (T3) are the exact names used in T6-T8; `MonsterManager.GROUP_NAME`/`apply_dot` (T4) are the exact names used in T8-T9; `SetEffectResolver.effect_key/active_effects/effects_for_set` (T5) match T6 (`active_effects`) and T10 (`effects_for_set`).
