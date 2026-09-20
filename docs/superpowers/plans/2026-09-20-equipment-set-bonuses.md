# Equipment Set Bonuses Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Equipping several items from one item family grants themed, cumulative stat bonuses (9 sets, data-driven), shown in the Inventory info panel.

**Architecture:** A new `EquipmentSetResource` per set is loaded by `GameDataRegistry`. `EquipmentBonuses.compute()` gains a final step that counts distinct equipped set pieces and folds earned bonuses into the same flat/additive buckets as gear and runes, so Hero, `preview_swap()` and the panel pick them up with no signature changes. The panel gains a Set Bonuses section, a set line on item cards, and a generalized swap preview.

**Tech Stack:** Godot 4.6.2, GDScript, gdUnit4, `.tres` resources.

**Spec:** `docs/superpowers/specs/2026-09-20-equipment-set-bonuses-design.md`

## Global Constraints

- Set values are exactly spec §4. Stat bonuses only; no special effects.
- Piece count = number of DISTINCT equipped `item_id`s in the set (two identical rings count once). Thresholds are cumulative. An item belongs to at most one set.
- Set bonuses are derived, never saved. No Hero code change (Hero already calls `EquipmentBonuses.compute_equipped()`).
- New `class_name` (`EquipmentSetResource`) requires a class-cache rebuild before tests: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --editor --path G:\TDef --quit`. After any `strings.csv` edit run the same command (translation reimport). `strings.csv` uses CRLF line endings: append rows with `printf '%s\r\n'`.
- `.tres` typed containers use the repo's canonical form: `Array[StringName]([&"a", &"b"])` and `Dictionary[int, Dictionary]({2: {&"armor": 8.0}})`. No `#` comments inside `.tres`. Write `.tres` files with quoted heredocs (`<<'EOF'`); never `sed`/`${var//&/}` on text containing `&`.
- Static GDScript functions cannot call `tr()`; use `TranslationServer.translate()` in statics.
- Info-panel direction is conveyed by the `+`/`-` sign, never color alone.
- Test runner: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a <res:// path> --ignoreHeadlessMode`. Run only the targeted suites named here.
- Commit and push after each task's tests pass (standing user rule). After committing verify with `git show --name-only --format= HEAD` that no unrelated files (e.g. the pre-existing modified `addons/`) were included; a non-existent path in `git add` aborts the whole add, so only list files that exist. Messages end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.

## File Structure

- Create `src/core/equipment/equipment_set_resource.gd` — the set resource + `validate()`.
- Modify `src/core/game_data_registry.gd` — directory, loader, getters, `_inject` param.
- Create `assets/data/equipment_sets/set_*.tres` (9).
- Modify `src/core/equipment/equipment_bonuses.gd` — set helpers + `compute()` step + two public helpers.
- Modify `src/gameplay/ui/inventory_screen/equipment_info_panel.gd`, `assets/localization/strings.csv`.
- Create tests: `tests/unit/equipment/equipment_set_resource_test.gd`, `tests/unit/game_data_registry/equipment_sets_registry_test.gd` (+ fixtures under `tests/fixtures/game_data_registry/equipment_sets_*`), `tests/unit/equipment/equipment_set_content_test.gd`, `tests/unit/equipment/equipment_sets_test.gd`, `tests/unit/inventory/equipment_info_panel_sets_test.gd`.
- Modify tests that assumed no sets: `tests/unit/equipment/equipment_bonuses_test.gd`, `tests/unit/inventory/equipment_info_panel_test.gd`.
- Create `design/balance/equipment-set-bonuses.md`; modify `design/gdd/equipment-forge.md`, `production/session-state/active.md`.

---

### Task 1: `EquipmentSetResource` and its validation

**Files:**
- Create: `src/core/equipment/equipment_set_resource.gd`
- Test: `tests/unit/equipment/equipment_set_resource_test.gd`

**Interfaces:**
- Produces: `EquipmentSetResource` with `set_id: StringName`, `display_name: String`, `member_item_ids: Array[StringName]`, `bonuses: Dictionary[int, Dictionary]`, `validate() -> Array[String]`.
- Consumes: `EquipmentBonuses.FAN_OUT_STATS`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GdUnitTestSuite

## Unit tests for EquipmentSetResource.validate() (equipment-set-bonuses spec §3.1, AC-1).


func _valid() -> EquipmentSetResource:
	var s := EquipmentSetResource.new()
	s.set_id = &"set_test"
	s.display_name = "Test"
	s.member_item_ids = [&"a", &"b", &"c"] as Array[StringName]
	s.bonuses = {2: {&"armor": 5.0}, 3: {&"max_hp": 20.0, &"additive_bonus_total": 0.05}}
	return s


func test_valid_set_has_no_errors() -> void:
	assert_array(_valid().validate()).is_empty()


func test_empty_set_id_and_display_name_are_rejected() -> void:
	var s: EquipmentSetResource = _valid()
	s.set_id = &""
	s.display_name = ""
	assert_int(s.validate().size()).is_equal(2)


func test_fewer_than_two_members_is_rejected() -> void:
	var s: EquipmentSetResource = _valid()
	s.member_item_ids = [&"a"] as Array[StringName]
	s.bonuses = {}
	assert_bool(s.validate().size() > 0).is_true()


func test_duplicate_members_are_rejected() -> void:
	var s: EquipmentSetResource = _valid()
	s.member_item_ids = [&"a", &"a", &"c"] as Array[StringName]
	assert_bool(s.validate().size() > 0).is_true()


func test_empty_bonuses_are_rejected() -> void:
	var s: EquipmentSetResource = _valid()
	s.bonuses = {}
	assert_bool(s.validate().size() > 0).is_true()


func test_threshold_below_two_or_above_member_count_is_rejected() -> void:
	var low: EquipmentSetResource = _valid()
	low.bonuses = {1: {&"armor": 5.0}}
	assert_bool(low.validate().size() > 0).is_true()
	var high: EquipmentSetResource = _valid()
	high.bonuses = {4: {&"armor": 5.0}}
	assert_bool(high.validate().size() > 0).is_true()


func test_empty_delta_is_rejected() -> void:
	var s: EquipmentSetResource = _valid()
	s.bonuses = {2: {}}
	assert_bool(s.validate().size() > 0).is_true()


func test_non_positive_value_is_rejected() -> void:
	var s: EquipmentSetResource = _valid()
	s.bonuses = {2: {&"armor": 0.0}}
	assert_bool(s.validate().size() > 0).is_true()


func test_unknown_stat_key_is_rejected() -> void:
	var s: EquipmentSetResource = _valid()
	s.bonuses = {2: {&"typo_stat": 5.0}}
	assert_bool(s.validate().size() > 0).is_true()
```

- [ ] **Step 2: Run to verify it fails**

Rebuild the class cache after creating the file in Step 3 (a missing `class_name` fails to parse). First run `res://tests/unit/equipment/equipment_set_resource_test.gd` before creating the class. Expected: FAIL (`EquipmentSetResource` not found).

- [ ] **Step 3: Implement**

```gdscript
class_name EquipmentSetResource
extends Resource

## One equipment set (equipment-set-bonuses spec §3.1): a family of items whose
## distinct equipped count earns cumulative stat bonuses. `bonuses` maps a
## pieces_required threshold to a stat delta using the same key rules as gear
## and runes -- a named stat is a flat bonus, `additive_bonus_total` fans out
## to every stat's additive bucket (equipment-stats-wiring spec §3.3).

@export var set_id: StringName = &""
@export var display_name: String = ""
@export var member_item_ids: Array[StringName] = []
@export var bonuses: Dictionary[int, Dictionary] = {}


## Load-time validation (registry convention: returns error strings).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if set_id == &"":
		errors.append("set_id must not be empty")
	if display_name == "":
		errors.append("display_name must not be empty")
	var unique: Dictionary = {}
	for item_id: StringName in member_item_ids:
		unique[item_id] = true
	if unique.size() < 2:
		errors.append("must have at least 2 unique member_item_ids (has %d)" % unique.size())
	if unique.size() != member_item_ids.size():
		errors.append("member_item_ids contains duplicates")
	if bonuses.is_empty():
		errors.append("bonuses must not be empty")
	for threshold: int in bonuses:
		if threshold < 2 or threshold > unique.size():
			errors.append("threshold %d must be between 2 and %d" % [threshold, unique.size()])
		var delta: Dictionary = bonuses[threshold]
		if delta.is_empty():
			errors.append("threshold %d has an empty delta" % threshold)
		for stat: Variant in delta:
			var key: StringName = StringName(stat)
			if key != &"additive_bonus_total" and not EquipmentBonuses.FAN_OUT_STATS.has(key):
				errors.append("threshold %d: unknown stat key '%s'" % [threshold, key])
			if float(delta[stat]) <= 0.0:
				errors.append("threshold %d: value for '%s' must be > 0" % [threshold, key])
	return errors
```

- [ ] **Step 4: Rebuild class cache, run the test**

Run the class-cache command, then `res://tests/unit/equipment/equipment_set_resource_test.gd`. Expected: PASS (9 tests).

- [ ] **Step 5: Commit and push**

```bash
git add src/core/equipment/equipment_set_resource.gd src/core/equipment/equipment_set_resource.gd.uid tests/unit/equipment/equipment_set_resource_test.gd tests/unit/equipment/equipment_set_resource_test.gd.uid
git commit -m "Add EquipmentSetResource with validation

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
git show --name-only --format= HEAD
```

---

### Task 2: Registry loading

**Files:**
- Modify: `src/core/game_data_registry.gd` (constants ~line 100; fields ~line 115/135; the `_ready()` load sequence ~line 165; `_inject` ~lines 172-197; getters after `get_all_sacrifice_recipes()` ~line 461; loader after `_load_sacrifice_recipes()` ~line 898)
- Create: `tests/fixtures/game_data_registry/equipment_sets_valid/set_test_a.tres`, `.../equipment_sets_invalid/set_bad.tres`, `.../equipment_sets_duplicate/set_dup_1.tres` and `set_dup_2.tres`
- Test: `tests/unit/game_data_registry/equipment_sets_registry_test.gd`

**Interfaces:**
- Produces: `GameDataRegistry.get_equipment_set(set_id: StringName) -> EquipmentSetResource`; `get_all_equipment_sets() -> Dictionary[StringName, EquipmentSetResource]` (shallow copy); `_load_equipment_sets() -> void`; const `DEFAULT_EQUIPMENT_SETS_DIR`; field `_equipment_sets_dir`; one new trailing optional `equipment_sets_dir` parameter on `_inject()`.

- [ ] **Step 1: Write fixtures and the failing test**

`tests/fixtures/game_data_registry/equipment_sets_valid/set_test_a.tres`:

```
[gd_resource type="Resource" script_class="EquipmentSetResource" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/core/equipment/equipment_set_resource.gd" id="1"]

[resource]
script = ExtResource("1")
set_id = &"set_test_a"
display_name = "Test A"
member_item_ids = Array[StringName]([&"iron_sword", &"iron_helm", &"iron_greaves"])
bonuses = Dictionary[int, Dictionary]({
2: {&"armor": 5.0},
3: {&"max_hp": 20.0, &"additive_bonus_total": 0.05}
})
```

`.../equipment_sets_invalid/set_bad.tres` (same layout, `set_id = &"set_bad"`, `member_item_ids = Array[StringName]([&"iron_sword", &"iron_helm"])`, `bonuses = Dictionary[int, Dictionary]({1: {&"armor": 5.0}})`, threshold 1 is invalid).

`.../equipment_sets_duplicate/set_dup_1.tres` and `set_dup_2.tres`: both valid, both `set_id = &"set_dup"`, different `display_name` ("First"/"Second").

Test (`equipment_sets_registry_test.gd`; loaders are exercised by setting the directory field and calling the loader directly, since `_inject()`'s positional list is long and the private-field pattern keeps the test focused):

```gdscript
extends GdUnitTestSuite

## Unit tests for GameDataRegistry's equipment-set loading (equipment-set-
## bonuses spec §3.2, AC-2).

const VALID_DIR: String = "res://tests/fixtures/game_data_registry/equipment_sets_valid/"
const INVALID_DIR: String = "res://tests/fixtures/game_data_registry/equipment_sets_invalid/"
const DUPLICATE_DIR: String = "res://tests/fixtures/game_data_registry/equipment_sets_duplicate/"
const MISSING_DIR: String = "res://tests/fixtures/game_data_registry/equipment_sets_does_not_exist/"

var _registry: GameDataRegistry


func before_test() -> void:
	_registry = GameDataRegistry.new()


func after_test() -> void:
	if _registry != null and is_instance_valid(_registry):
		_registry.free()
	_registry = null


func _load(dir: String) -> void:
	_registry._equipment_sets_dir = dir
	_registry._load_equipment_sets()


func test_valid_directory_loads_the_set_keyed_by_id() -> void:
	_load(VALID_DIR)
	var s: EquipmentSetResource = _registry.get_equipment_set(&"set_test_a")
	assert_object(s).is_not_null()
	assert_str(s.display_name).is_equal("Test A")
	assert_int(s.member_item_ids.size()).is_equal(3)
	assert_float(float(s.bonuses[2][&"armor"])).is_equal_approx(5.0, 0.0001)
	assert_float(float(s.bonuses[3][&"additive_bonus_total"])).is_equal_approx(0.05, 0.0001)


func test_unknown_set_returns_null() -> void:
	_load(VALID_DIR)
	assert_object(_registry.get_equipment_set(&"nope")).is_null()


func test_get_all_returns_a_copy() -> void:
	_load(VALID_DIR)
	var all: Dictionary = _registry.get_all_equipment_sets()
	all.clear()
	assert_int(_registry.get_all_equipment_sets().size()).is_equal(1)


func test_invalid_set_is_still_cached_and_validate_flags_it() -> void:
	_load(INVALID_DIR)
	var s: EquipmentSetResource = _registry.get_equipment_set(&"set_bad")
	assert_object(s).is_not_null()
	assert_bool(s.validate().size() > 0).is_true()


func test_duplicate_set_id_does_not_crash_and_keeps_one_entry() -> void:
	_load(DUPLICATE_DIR)
	assert_int(_registry.get_all_equipment_sets().size()).is_equal(1)
	assert_object(_registry.get_equipment_set(&"set_dup")).is_not_null()


func test_missing_directory_yields_no_sets_without_crashing() -> void:
	_load(MISSING_DIR)
	assert_int(_registry.get_all_equipment_sets().size()).is_equal(0)
```

- [ ] **Step 2: Run to verify it fails**

Run `res://tests/unit/game_data_registry/equipment_sets_registry_test.gd`. Expected: FAIL (`_equipment_sets_dir` / `_load_equipment_sets` not found).

- [ ] **Step 3: Implement**

In `game_data_registry.gd`:

- After `const DEFAULT_SACRIFICE_RECIPES_DIR ...` add: `const DEFAULT_EQUIPMENT_SETS_DIR: String = "res://assets/data/equipment_sets/"`.
- After `var _sacrifice_recipes_dir ...` add: `var _equipment_sets_dir: String = DEFAULT_EQUIPMENT_SETS_DIR`.
- After `var _sacrifice_recipes: Dictionary[...] = {}` add: `var _equipment_sets: Dictionary[StringName, EquipmentSetResource] = {}`.
- In the `_ready()` load sequence, after `_load_sacrifice_recipes()` add `_load_equipment_sets()`.
- In `_inject(...)`: append a final parameter `, equipment_sets_dir: String = DEFAULT_EQUIPMENT_SETS_DIR` after `creature_atlases_dir`, and after `_creature_atlases_dir = creature_atlases_dir` add `_equipment_sets_dir = equipment_sets_dir`.
- After `get_all_sacrifice_recipes()` add:

```gdscript
## Returns the EquipmentSetResource for set_id, or null if not found/loaded
## (equipment-set-bonuses spec §3.2). O(1) Dictionary lookup.
func get_equipment_set(set_id: StringName) -> EquipmentSetResource:
	return _equipment_sets.get(set_id, null)


## Returns a shallow copy of the set_id -> EquipmentSetResource cache. A copy,
## not the registry's live Dictionary -- same isolation rationale as
## get_all_sacrifice_recipes().
func get_all_equipment_sets() -> Dictionary[StringName, EquipmentSetResource]:
	return _equipment_sets.duplicate()
```

- After `_load_sacrifice_recipes()` add:

```gdscript
func _load_equipment_sets() -> void:
	if not DirAccess.dir_exists_absolute(_equipment_sets_dir):
		push_error("[GameDataRegistry] Equipment sets directory does not exist: %s" % _equipment_sets_dir)
		return
	for raw_file_name: String in DirAccess.get_files_at(_equipment_sets_dir):
		var file_name: String = _strip_export_remap_suffix(raw_file_name)
		if not file_name.ends_with(".tres"):
			continue
		var set_res: EquipmentSetResource = ResourceLoader.load(_equipment_sets_dir + file_name) as EquipmentSetResource
		if set_res == null:
			push_error("[GameDataRegistry] %s: failed to load as EquipmentSetResource." % file_name)
			continue
		var errors: Array[String] = set_res.validate()
		for err: String in errors:
			push_error("[GameDataRegistry] %s: %s" % [file_name, err])
		if _equipment_sets.has(set_res.set_id):
			push_error("[GameDataRegistry] %s: duplicate set_id '%s' — overwriting previous entry." % [file_name, set_res.set_id])
		_equipment_sets[set_res.set_id] = set_res
```

The real `assets/data/equipment_sets/` directory does not exist until Task 3, so `_ready()` will log the directory-missing `push_error` once until then (same convention as every other directory; no crash).

- [ ] **Step 4: Run tests**

Run the class-cache rebuild, then `res://tests/unit/game_data_registry` (whole directory: confirms the existing registry tests, including any positional `_inject` callers, still pass) and the new file. Expected: all PASS. `push_error` lines from the invalid/duplicate/missing cases are expected output, not failures.

- [ ] **Step 5: Commit and push**

```bash
git add src/core/game_data_registry.gd tests/unit/game_data_registry/equipment_sets_registry_test.gd tests/unit/game_data_registry/equipment_sets_registry_test.gd.uid tests/fixtures/game_data_registry/equipment_sets_valid tests/fixtures/game_data_registry/equipment_sets_invalid tests/fixtures/game_data_registry/equipment_sets_duplicate
git commit -m "Load equipment sets in GameDataRegistry

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
git show --name-only --format= HEAD
```

---

### Task 3: Author the nine sets + content test

**Files:**
- Create: `assets/data/equipment_sets/set_{iron,leather,reinforced,goblin,brute,sentinel,troll,warlord,lurker}.tres`
- Test: `tests/unit/equipment/equipment_set_content_test.gd`

- [ ] **Step 1: Write the failing content test**

```gdscript
extends GdUnitTestSuite

## Content-integrity tests for the nine authored equipment sets (equipment-
## set-bonuses spec §3.7/§4, AC-8). EXPECTED is the spec's authoritative table;
## editing a set in data must be a deliberate edit here too.

const EXPECTED: Dictionary[StringName, Dictionary] = {
	&"set_iron": {"members": [&"iron_sword", &"iron_helm", &"iron_greaves", &"iron_buckler", &"iron_band"],
		"bonuses": {2: {&"armor": 8.0}, 4: {&"max_hp": 50.0, &"physical_attack": 3.0}}},
	&"set_leather": {"members": [&"leather_gloves", &"leather_jerkin", &"leather_leggings"],
		"bonuses": {2: {&"move_speed": 8.0}, 3: {&"luck": 0.03}}},
	&"set_reinforced": {"members": [&"reinforced_helm", &"reinforced_plate", &"reinforced_boots", &"reinforced_gauntlets"],
		"bonuses": {2: {&"max_hp": 40.0}, 4: {&"armor": 12.0, &"physical_attack": 4.0}}},
	&"set_goblin": {"members": [&"goblin_fang_circlet", &"goblin_claw_gauntlets", &"goblin_raider_leggings", &"goblin_signet"],
		"bonuses": {2: {&"luck": 0.04}, 4: {&"crit_chance": 0.06, &"move_speed": 15.0}}},
	&"set_brute": {"members": [&"brutes_war_helm", &"brutes_bulwark_plate", &"brute_gauntlets", &"brute_legguards", &"brute_core_band"],
		"bonuses": {2: {&"max_hp": 60.0}, 4: {&"armor": 25.0}, 5: {&"max_hp": 100.0}}},
	&"set_sentinel": {"members": [&"sentinel_visor", &"sentinel_ward", &"sentinels_aegis", &"sentinels_lance", &"sentinels_striders"],
		"bonuses": {2: {&"attack_range": 16.0}, 4: {&"cdr": 0.05, &"elemental_resist_fire": 0.06, &"elemental_resist_frost": 0.06}}},
	&"set_troll": {"members": [&"troll_hide_mantle", &"trollhide_buckler", &"trollhide_striders", &"trollmarrow_band"],
		"bonuses": {2: {&"max_hp": 60.0}, 4: {&"lifesteal": 0.02, &"max_hp": 80.0}}},
	&"set_warlord": {"members": [&"warlords_battleplate", &"warlords_greatblade", &"warlords_greaves", &"warlords_legguards", &"warlords_standard_amulet"],
		"bonuses": {2: {&"physical_attack": 5.0}, 4: {&"max_hp": 80.0, &"armor": 15.0}, 5: {&"additive_bonus_total": 0.05}}},
	&"set_lurker": {"members": [&"lurker_claw_gauntlets", &"lurker_fang_blade"],
		"bonuses": {2: {&"crit_chance": 0.05, &"lifesteal": 0.015}}},
}


func test_exactly_the_nine_expected_sets_exist() -> void:
	var all: Dictionary = GGameDataRegistry.get_all_equipment_sets()
	assert_int(all.size()).is_equal(9)
	for set_id: StringName in EXPECTED:
		assert_bool(all.has(set_id)).override_failure_message("%s missing" % set_id).is_true()


func test_every_set_passes_validate() -> void:
	for set_res: EquipmentSetResource in GGameDataRegistry.get_all_equipment_sets().values():
		assert_array(set_res.validate()).override_failure_message(String(set_res.set_id)).is_empty()


func test_members_and_bonuses_match_the_spec_table_exactly() -> void:
	for set_id: StringName in EXPECTED:
		var set_res: EquipmentSetResource = GGameDataRegistry.get_equipment_set(set_id)
		var expected: Dictionary = EXPECTED[set_id]
		assert_int(set_res.member_item_ids.size()).override_failure_message("%s member count" % set_id).is_equal((expected["members"] as Array).size())
		for member: StringName in expected["members"]:
			assert_bool(set_res.member_item_ids.has(member)).override_failure_message("%s missing member %s" % [set_id, member]).is_true()
		var exp_bonuses: Dictionary = expected["bonuses"]
		assert_int(set_res.bonuses.size()).override_failure_message("%s threshold count" % set_id).is_equal(exp_bonuses.size())
		for threshold: int in exp_bonuses:
			assert_bool(set_res.bonuses.has(threshold)).override_failure_message("%s missing threshold %d" % [set_id, threshold]).is_true()
			var exp_delta: Dictionary = exp_bonuses[threshold]
			var got: Dictionary = set_res.bonuses[threshold]
			assert_int(got.size()).override_failure_message("%s@%d key count" % [set_id, threshold]).is_equal(exp_delta.size())
			for stat: StringName in exp_delta:
				assert_float(float(got[stat])).override_failure_message("%s@%d.%s" % [set_id, threshold, stat]).is_equal_approx(float(exp_delta[stat]), 0.0001)


func test_every_member_is_a_real_equipment_item_and_no_item_is_in_two_sets() -> void:
	var seen: Dictionary = {}
	for set_res: EquipmentSetResource in GGameDataRegistry.get_all_equipment_sets().values():
		for member: StringName in set_res.member_item_ids:
			var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(member)
			assert_object(def).override_failure_message("%s: unknown item %s" % [set_res.set_id, member]).is_not_null()
			assert_str(def.equipment_category).override_failure_message("%s is not equipment" % member).is_not_empty()
			assert_bool(seen.has(member)).override_failure_message("%s is in two sets" % member).is_false()
			seen[member] = set_res.set_id
```

- [ ] **Step 2: Run to verify it fails**

Run `res://tests/unit/equipment/equipment_set_content_test.gd`. Expected: FAIL (no sets exist yet).

- [ ] **Step 3: Author the nine `.tres` files**

Create the directory, then write each file with a quoted heredoc (values from spec §4). Shape (shown for `set_brute`; the other eight follow the identical layout with their own `set_id`, `display_name`, members, and bonuses):

```bash
mkdir -p assets/data/equipment_sets
cat > assets/data/equipment_sets/set_brute.tres <<'EOF'
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
EOF
```

The other eight files, with these exact `set_id` / `display_name` / `member_item_ids` / `bonuses` lines:

- `set_iron.tres`: `set_iron` / `Iron` / `[&"iron_sword", &"iron_helm", &"iron_greaves", &"iron_buckler", &"iron_band"]` / `2: {&"armor": 8.0}`, `4: {&"max_hp": 50.0, &"physical_attack": 3.0}`
- `set_leather.tres`: `set_leather` / `Leather` / `[&"leather_gloves", &"leather_jerkin", &"leather_leggings"]` / `2: {&"move_speed": 8.0}`, `3: {&"luck": 0.03}`
- `set_reinforced.tres`: `set_reinforced` / `Reinforced` / `[&"reinforced_helm", &"reinforced_plate", &"reinforced_boots", &"reinforced_gauntlets"]` / `2: {&"max_hp": 40.0}`, `4: {&"armor": 12.0, &"physical_attack": 4.0}`
- `set_goblin.tres`: `set_goblin` / `Goblin` / `[&"goblin_fang_circlet", &"goblin_claw_gauntlets", &"goblin_raider_leggings", &"goblin_signet"]` / `2: {&"luck": 0.04}`, `4: {&"crit_chance": 0.06, &"move_speed": 15.0}`
- `set_sentinel.tres`: `set_sentinel` / `Sentinel` / `[&"sentinel_visor", &"sentinel_ward", &"sentinels_aegis", &"sentinels_lance", &"sentinels_striders"]` / `2: {&"attack_range": 16.0}`, `4: {&"cdr": 0.05, &"elemental_resist_fire": 0.06, &"elemental_resist_frost": 0.06}`
- `set_troll.tres`: `set_troll` / `Troll` / `[&"troll_hide_mantle", &"trollhide_buckler", &"trollhide_striders", &"trollmarrow_band"]` / `2: {&"max_hp": 60.0}`, `4: {&"lifesteal": 0.02, &"max_hp": 80.0}`
- `set_warlord.tres`: `set_warlord` / `Warlord` / `[&"warlords_battleplate", &"warlords_greatblade", &"warlords_greaves", &"warlords_legguards", &"warlords_standard_amulet"]` / `2: {&"physical_attack": 5.0}`, `4: {&"max_hp": 80.0, &"armor": 15.0}`, `5: {&"additive_bonus_total": 0.05}`
- `set_lurker.tres`: `set_lurker` / `Lurker` / `[&"lurker_claw_gauntlets", &"lurker_fang_blade"]` / `2: {&"crit_chance": 0.05, &"lifesteal": 0.015}`

Confirm with `ls assets/data/equipment_sets | wc -l` (9) and `grep -c '^bonuses' assets/data/equipment_sets/*.tres` (each 1).

- [ ] **Step 4: Import and run tests**

Run the editor-mode import (class-cache command). Run `res://tests/unit/equipment/equipment_set_content_test.gd` and `res://tests/unit/game_data_registry`. Expected: PASS. If the first run reports the typed-container `.tres` form fails to load, print the load error and fix the file form (the Task 2 fixtures use the same form, so a failure would already have shown there).

- [ ] **Step 5: Commit and push**

```bash
git add assets/data/equipment_sets tests/unit/equipment/equipment_set_content_test.gd tests/unit/equipment/equipment_set_content_test.gd.uid
git commit -m "Author the nine equipment sets

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
git show --name-only --format= HEAD
```

---

### Task 4: Set bonuses in `EquipmentBonuses`

**Files:**
- Modify: `src/core/equipment/equipment_bonuses.gd` (new statics; `compute()`; expose `equipped_contents()` and `swapped_contents()`)
- Modify tests: `tests/unit/equipment/equipment_bonuses_test.gd` (one fixture)
- Test: `tests/unit/equipment/equipment_sets_test.gd`

**Interfaces:**
- Produces (all static on `EquipmentBonuses`): `set_id_for_item(item_id: StringName) -> StringName`; `set_piece_counts(slot_contents: Array[Dictionary]) -> Dictionary` (`{set_id: int}`); `set_bonuses(slot_contents: Array[Dictionary]) -> Dictionary` (`{"flat","additive"}`); `equipped_contents() -> Array[Dictionary]` (public form of the existing private `_equipped_contents()`); `swapped_contents(slot_name: String, candidate_contents: Dictionary) -> Array[Dictionary]`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GdUnitTestSuite

## Unit tests for equipment set counting and bonuses (equipment-set-bonuses
## spec §3.3/§3.4, AC-3..AC-7). Real registry sets and real items.

const BRUTE_HELM: String = "res://assets/data/items/brutes_war_helm.tres"
const BRUTE_PLATE: String = "res://assets/data/items/brutes_bulwark_plate.tres"
const BRUTE_GAUNTLETS: String = "res://assets/data/items/brute_gauntlets.tres"
const BRUTE_LEGGUARDS: String = "res://assets/data/items/brute_legguards.tres"
const BRUTE_BAND: String = "res://assets/data/items/brute_core_band.tres"

var _hero: Hero


func before_test() -> void:
	GInventory.reset_to_defaults()


func after_test() -> void:
	GInventory.reset_to_defaults()
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


func _c(item_id: String) -> Dictionary:
	return {"item_id": item_id, "stat_overrides": {}, "imbued_runes": [], "rune_slot_count": 0}


func _equip(slot: String, path: String) -> void:
	assert_bool(GInventory.equip_item(slot, load(path))).is_true()


func test_set_id_for_item() -> void:
	assert_str(String(EquipmentBonuses.set_id_for_item(&"brutes_war_helm"))).is_equal("set_brute")
	assert_str(String(EquipmentBonuses.set_id_for_item(&"lucky_charm_trinket"))).is_equal("")


func test_piece_counts_are_distinct_per_set_and_omit_empty_sets() -> void:
	var counts: Dictionary = EquipmentBonuses.set_piece_counts([_c("brutes_war_helm"), _c("brute_gauntlets"), _c("iron_helm")])
	assert_int(counts[&"set_brute"]).is_equal(2)
	assert_int(counts[&"set_iron"]).is_equal(1)
	assert_bool(counts.has(&"set_warlord")).is_false()


func test_two_copies_of_the_same_item_count_once() -> void:
	var counts: Dictionary = EquipmentBonuses.set_piece_counts([_c("goblin_signet"), _c("goblin_signet")])
	assert_int(counts[&"set_goblin"]).is_equal(1)


func test_unregistered_items_are_not_counted() -> void:
	assert_bool(EquipmentBonuses.set_piece_counts([_c("no_such_item")]).is_empty()).is_true()


func test_below_two_pieces_grants_nothing() -> void:
	var r: Dictionary = EquipmentBonuses.set_bonuses([_c("brutes_war_helm")])
	assert_bool((r["flat"] as Dictionary).is_empty()).is_true()
	assert_bool((r["additive"] as Dictionary).is_empty()).is_true()


func test_two_pieces_grants_only_the_two_piece_bonus() -> void:
	var r: Dictionary = EquipmentBonuses.set_bonuses([_c("brutes_war_helm"), _c("brute_gauntlets")])
	assert_float(r["flat"][&"max_hp"]).is_equal_approx(60.0, 0.0001)
	assert_bool((r["flat"] as Dictionary).has(&"armor")).is_false()


func test_bonuses_are_cumulative_at_four_pieces() -> void:
	var r: Dictionary = EquipmentBonuses.set_bonuses([_c("brutes_war_helm"), _c("brute_gauntlets"), _c("brutes_bulwark_plate"), _c("brute_legguards")])
	assert_float(r["flat"][&"max_hp"]).is_equal_approx(60.0, 0.0001)
	assert_float(r["flat"][&"armor"]).is_equal_approx(25.0, 0.0001)


func test_five_pieces_adds_the_capstone_on_top() -> void:
	var five: Array[Dictionary] = [_c("brutes_war_helm"), _c("brute_gauntlets"), _c("brutes_bulwark_plate"), _c("brute_legguards"), _c("brute_core_band")]
	var r: Dictionary = EquipmentBonuses.set_bonuses(five)
	assert_float(r["flat"][&"max_hp"]).is_equal_approx(160.0, 0.0001)
	assert_float(r["flat"][&"armor"]).is_equal_approx(25.0, 0.0001)


func test_warlord_capstone_fans_out_to_every_additive_bucket() -> void:
	var five: Array[Dictionary] = [_c("warlords_battleplate"), _c("warlords_greatblade"), _c("warlords_greaves"), _c("warlords_legguards"), _c("warlords_standard_amulet")]
	var r: Dictionary = EquipmentBonuses.set_bonuses(five)
	assert_int((r["additive"] as Dictionary).size()).is_equal(14)
	assert_float(r["additive"][&"luck"]).is_equal_approx(0.05, 0.0001)
	assert_bool((r["flat"] as Dictionary).has(&"additive_bonus_total")).is_false()


func test_compute_includes_set_bonuses_on_top_of_item_stats() -> void:
	var list: Array[Dictionary] = [_c("brutes_war_helm"), _c("brute_gauntlets")]
	var items_only_hp: float = 0.0
	for contents: Dictionary in list:
		items_only_hp += EquipmentBonuses.item_stats(contents).get(&"max_hp", 0.0)
	var r: Dictionary = EquipmentBonuses.compute(list)
	assert_float(r["flat"][&"max_hp"]).is_equal_approx(items_only_hp + 60.0, 0.0001)


func test_hero_effective_stat_reflects_the_set_bonus() -> void:
	_equip("helmet", BRUTE_HELM)
	_equip("gloves", BRUTE_GAUNTLETS)
	_hero = Hero.new()
	add_child(_hero)
	var items_only_hp: float = 0.0
	for slot: String in ["helmet", "gloves"]:
		items_only_hp += EquipmentBonuses.item_stats(GInventory.get_equipped_item(slot)).get(&"max_hp", 0.0)
	assert_float(_hero.get_effective_stat(&"max_hp")).is_equal_approx(items_only_hp + 60.0, 0.0001)


func test_preview_swap_reflects_a_threshold_being_completed() -> void:
	_equip("helmet", BRUTE_HELM)
	_equip("chest", BRUTE_PLATE)
	_equip("gloves", BRUTE_GAUNTLETS)
	var candidate: Dictionary = GInventory.get_equipped_item("gloves")
	candidate = _c("brute_legguards")
	var own_armor: float = EquipmentBonuses.item_stats(candidate).get(&"armor", 0.0)
	var d: Dictionary = EquipmentBonuses.preview_swap("pants", candidate)
	assert_float(d["flat"][&"armor"]).is_equal_approx(own_armor + 25.0, 0.0001)


func test_swapped_contents_replaces_only_the_named_slot() -> void:
	_equip("helmet", BRUTE_HELM)
	var swapped: Array[Dictionary] = EquipmentBonuses.swapped_contents("helmet", _c("iron_helm"))
	var ids: Array[String] = []
	for contents: Dictionary in swapped:
		if not contents.is_empty():
			ids.append(contents["item_id"] as String)
	assert_array(ids).is_equal(["iron_helm"])
```

In `tests/unit/equipment/equipment_bonuses_test.gd`, `test_compute_sums_two_items_sharing_a_stat` builds `b` from `iron_sword`, which now forms an Iron-set pair with `iron_helm` (adds `armor +8`). Change that fixture's `b` to `_contents("lucky_charm_trinket", {&"physical_attack": 6.0, &"armor": 3.0})` (not in any set) so the test keeps isolating item-stat summing. Its assertions stay unchanged.

- [ ] **Step 2: Run to verify it fails**

Run `res://tests/unit/equipment/equipment_sets_test.gd`. Expected: FAIL (`set_id_for_item` etc. not found).

- [ ] **Step 3: Implement**

In `src/core/equipment/equipment_bonuses.gd`:

Add after `compute_equipped()`:

```gdscript
## Public form of the equipped-slot list (10 entries in EQUIPMENT_SLOT_NAMES
## order, {} for empty slots).
static func equipped_contents() -> Array[Dictionary]:
	return _equipped_contents()


## The equipped list with `slot_name`'s entry replaced by `candidate_contents`
## (used by preview_swap() and by the panel's would-be set counts).
static func swapped_contents(slot_name: String, candidate_contents: Dictionary) -> Array[Dictionary]:
	var current: Array[Dictionary] = _equipped_contents()
	var swapped: Array[Dictionary] = []
	for i: int in range(Inventory.EQUIPMENT_SLOT_NAMES.size()):
		swapped.append(candidate_contents if Inventory.EQUIPMENT_SLOT_NAMES[i] == slot_name else current[i])
	return swapped


## Which set an item belongs to, or &"" (equipment-set-bonuses spec §3.4).
static func set_id_for_item(item_id: StringName) -> StringName:
	for set_res: EquipmentSetResource in GGameDataRegistry.get_all_equipment_sets().values():
		if set_res.member_item_ids.has(item_id):
			return set_res.set_id
	return &""


## {set_id: distinct equipped piece count} for sets with at least one piece
## equipped. Two copies of the same item count once; items with no registered
## definition are skipped, matching compute().
static func set_piece_counts(slot_contents: Array[Dictionary]) -> Dictionary:
	var equipped_ids: Dictionary = {}
	for contents: Dictionary in slot_contents:
		if contents.is_empty() or _definition_for(contents) == null:
			continue
		equipped_ids[StringName(contents.get("item_id", "") as String)] = true
	var counts: Dictionary = {}
	for set_res: EquipmentSetResource in GGameDataRegistry.get_all_equipment_sets().values():
		var n: int = 0
		for member: StringName in set_res.member_item_ids:
			if equipped_ids.has(member):
				n += 1
		if n > 0:
			counts[set_res.set_id] = n
	return counts


## Every earned set bonus (cumulative thresholds), folded with fold_stat_entry()
## so additive_bonus_total fans out like every other source. Returns the same
## {"flat","additive"} shape as compute().
static func set_bonuses(slot_contents: Array[Dictionary]) -> Dictionary:
	var flat: Dictionary[StringName, float] = {}
	var additive: Dictionary[StringName, float] = {}
	var counts: Dictionary = set_piece_counts(slot_contents)
	for set_id: StringName in counts:
		var set_res: EquipmentSetResource = GGameDataRegistry.get_equipment_set(set_id)
		if set_res == null:
			continue
		for threshold: int in set_res.bonuses:
			if (counts[set_id] as int) < threshold:
				continue
			var delta: Dictionary = set_res.bonuses[threshold]
			for stat: Variant in delta:
				fold_stat_entry(StringName(stat), float(delta[stat]), flat, additive)
	return {"flat": flat, "additive": additive}
```

In `compute()`, just before `return {"flat": flat, "additive": additive}` add:

```gdscript
	var sets: Dictionary = set_bonuses(slot_contents)
	for stat: StringName in sets["flat"]:
		flat[stat] = flat.get(stat, 0.0) + sets["flat"][stat]
	for stat: StringName in sets["additive"]:
		additive[stat] = additive.get(stat, 0.0) + sets["additive"][stat]
```

Rewrite `preview_swap()`'s list construction to use the new helper (behavior unchanged):

```gdscript
static func preview_swap(slot_name: String, candidate_contents: Dictionary) -> Dictionary:
	var before: Dictionary = compute(_equipped_contents())
	var after: Dictionary = compute(swapped_contents(slot_name, candidate_contents))
	return {
		"flat": _diff(after["flat"], before["flat"]),
		"additive": _diff(after["additive"], before["additive"]),
	}
```

- [ ] **Step 4: Run tests**

Rebuild the class cache, then run: `res://tests/unit/equipment` (whole dir), `res://tests/unit/hero`, `res://tests/unit/equipment_forge`, `res://tests/unit/inventory`, `res://tests/integration/inventory-screen`. Expected: all PASS. If any other existing test equips two members of one set and asserts an exact total (e.g. two Iron pieces), update ONLY that expectation to include the set bonus and mention it in the commit message.

- [ ] **Step 5: Commit and push**

```bash
git add src/core/equipment/equipment_bonuses.gd tests/unit/equipment/equipment_sets_test.gd tests/unit/equipment/equipment_sets_test.gd.uid tests/unit/equipment/equipment_bonuses_test.gd
git commit -m "Fold equipment set bonuses into EquipmentBonuses.compute()

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
git show --name-only --format= HEAD
```

---

### Task 5: Info panel UI, strings, docs

**Files:**
- Modify: `src/gameplay/ui/inventory_screen/equipment_info_panel.gd`, `assets/localization/strings.csv`
- Modify tests: `tests/unit/inventory/equipment_info_panel_test.gd` (one assertion)
- Test: `tests/unit/inventory/equipment_info_panel_sets_test.gd`
- Create: `design/balance/equipment-set-bonuses.md`; modify `design/gdd/equipment-forge.md`, `production/session-state/active.md`

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GdUnitTestSuite

## Panel tests for equipment sets (equipment-set-bonuses spec §3.5, AC-9/AC-10).
## Label assertions use tr() / the panel's own helpers so they hold whether or
## not the translation is loaded.

const PanelScript := preload("res://src/gameplay/ui/inventory_screen/equipment_info_panel.gd")

var _panel: PanelContainer


func before_test() -> void:
	GInventory.reset_to_defaults()
	_panel = PanelScript.new()
	add_child(_panel)


func after_test() -> void:
	GInventory.reset_to_defaults()
	if _panel != null and is_instance_valid(_panel):
		remove_child(_panel)
		_panel.free()
	_panel = null


func _equip(slot: String, item_id: String) -> void:
	assert_bool(GInventory.equip_item(slot, load("res://assets/data/items/%s.tres" % item_id))).is_true()


func _c(item_id: String) -> Dictionary:
	return {"item_id": item_id, "stat_overrides": {}, "imbued_runes": [], "rune_slot_count": 0}


func test_bonuses_state_omits_the_set_section_when_no_set_piece_is_equipped() -> void:
	_panel.show_bonuses()
	assert_str(_panel.get_body_text()).not_contains(tr("INVENTORY_INFO_SET_BONUSES_HEADER"))


func test_bonuses_state_lists_a_partially_equipped_set_with_progress_and_thresholds() -> void:
	_equip("helmet", "brutes_war_helm")
	_equip("gloves", "brute_gauntlets")
	_panel.show_bonuses()
	var text: String = _panel.get_body_text()
	assert_str(text).contains(tr("INVENTORY_INFO_SET_BONUSES_HEADER"))
	assert_str(text).contains("Brute")
	assert_str(text).contains("2/5")
	assert_str(text).contains(tr("INVENTORY_INFO_SET_THRESHOLD") % 2)
	assert_str(text).contains(tr("INVENTORY_INFO_SET_THRESHOLD") % 4)
	assert_str(text).contains("+60")


func test_item_card_shows_the_set_line_with_the_would_be_count() -> void:
	_equip("helmet", "brutes_war_helm")
	_panel.show_item(_c("brute_gauntlets"), "")
	assert_str(_panel.get_body_text()).contains(tr("INVENTORY_INFO_SET_LINE") % ["Brute", 2, 5])


func test_item_card_for_an_equipped_piece_shows_the_current_count() -> void:
	_equip("helmet", "brutes_war_helm")
	_panel.show_item(GInventory.get_equipped_item("helmet"), "helmet")
	assert_str(_panel.get_body_text()).contains(tr("INVENTORY_INFO_SET_LINE") % ["Brute", 1, 5])


func test_item_card_for_a_non_set_item_has_no_set_line() -> void:
	_panel.show_item(_c("lucky_charm_trinket"), "")
	assert_str(_panel.get_body_text()).not_contains(tr("INVENTORY_INFO_SET_LINE") % ["", 0, 0])
	assert_str(_panel.get_body_text()).not_contains("Set:")


func test_swap_preview_lists_set_induced_stats_not_on_the_item_itself() -> void:
	_equip("offhand", "sentinel_ward")
	_equip("main_hand", "sentinels_lance")
	_equip("boots", "sentinels_striders")
	# sentinel_visor's own stats are max_hp / attack_range / crit_chance; the
	# 4-piece bonus adds cdr and fire/frost resist, which are NOT on the visor.
	_panel.show_item(_c("sentinel_visor"), "")
	var text: String = _panel.get_body_text()
	assert_str(text).contains(PanelScript.stat_label(&"elemental_resist_fire"))
	assert_str(text).contains("+6.0%")


func test_swap_preview_shows_a_lost_set_bonus_as_a_negative_row() -> void:
	_equip("helmet", "brutes_war_helm")
	_equip("gloves", "brute_gauntlets")
	# Swapping the equipped helmet for a non-set helmet breaks the 2-piece bonus (-60 max_hp beyond stat swap).
	_panel.show_item(_c("iron_helm"), "")
	assert_str(_panel.get_body_text()).contains("-")
```

In `tests/unit/inventory/equipment_info_panel_test.gd`, `test_card_for_equipped_item_shows_name_stats_and_no_delta` asserts `not_contains("(")` to mean "no swap delta"; the new set line contains parentheses (`Set: Iron (1/5)`). Change that one assertion to `assert_str(text).not_contains("(+")` and `assert_str(text).not_contains("(-")`.

- [ ] **Step 2: Run to verify it fails**

Run `res://tests/unit/inventory/equipment_info_panel_sets_test.gd`. Expected: FAIL.

- [ ] **Step 3: Implement**

Append localization rows (CRLF; values contain no commas):

```bash
for row in \
  'INVENTORY_INFO_SET_BONUSES_HEADER,Set Bonuses' \
  'INVENTORY_INFO_SET_LINE,Set: %s (%d/%d)' \
  'INVENTORY_INFO_SET_HEADER_LINE,%s (%d/%d)' \
  'INVENTORY_INFO_SET_THRESHOLD,%d pieces:'; do printf '%s\r\n' "$row" >> assets/localization/strings.csv; done
```
Then run the class-cache/reimport command.

In `equipment_info_panel.gd`:

Add a static helper (after `_stat_line`):

```gdscript
## "Max HP +60, Armor +25" style text for a stat delta; additive_bonus_total
## renders as "All stats +X%". Static, so it uses TranslationServer, not tr().
static func _delta_text(delta: Dictionary) -> String:
	var parts: Array[String] = []
	for stat: StringName in ordered_stats(delta):
		if stat == &"additive_bonus_total":
			parts.append("%s +%.1f%%" % [TranslationServer.translate("INVENTORY_INFO_ALL_STATS"), float(delta[stat]) * 100.0])
		else:
			parts.append(_stat_line(stat, float(delta[stat])))
	return ", ".join(parts)
```

`ordered_stats()` lists known stats in display order then unknown keys, and `additive_bonus_total` is not in `STAT_DISPLAY_ORDER`, so it lands in the "unknown keys" tail, which is acceptable for this label.

In `show_bonuses()`, replace the final `if lines.is_empty(): ...` block with the following (the "No equipment bonuses" line now requires no stat rows AND no set rows):

```gdscript
	var set_lines: Array[String] = _set_section_lines()
	lines.append_array(set_lines)
	if lines.is_empty():
		lines.append(_colored(tr("INVENTORY_INFO_NO_BONUSES"), COLOR_MUTED))
```

Add the section builder:

```gdscript
## Set Bonuses section (spec §3.5): one header line per partially/fully
## equipped set, then one line per threshold, earned thresholds normal and
## unearned ones muted. Empty when no set piece is equipped.
func _set_section_lines() -> Array[String]:
	var lines: Array[String] = []
	var counts: Dictionary = EquipmentBonuses.set_piece_counts(EquipmentBonuses.equipped_contents())
	if counts.is_empty():
		return lines
	lines.append("")
	lines.append(tr("INVENTORY_INFO_SET_BONUSES_HEADER"))
	var ids: Array = counts.keys()
	ids.sort()
	for set_id: StringName in ids:
		var set_res: EquipmentSetResource = GGameDataRegistry.get_equipment_set(set_id)
		if set_res == null:
			continue
		var count: int = counts[set_id] as int
		lines.append(tr("INVENTORY_INFO_SET_HEADER_LINE") % [set_res.display_name, count, set_res.member_item_ids.size()])
		var thresholds: Array = set_res.bonuses.keys()
		thresholds.sort()
		for threshold: int in thresholds:
			var text: String = "  %s %s" % [tr("INVENTORY_INFO_SET_THRESHOLD") % threshold, _delta_text(set_res.bonuses[threshold])]
			lines.append(text if count >= threshold else _colored(text, COLOR_MUTED))
	return lines
```

In `show_item()`:

- After the category line block and before computing `own`, add the set line:

```gdscript
	var set_id: StringName = EquipmentBonuses.set_id_for_item(StringName(item_id))
	if set_id != &"":
		var set_res: EquipmentSetResource = GGameDataRegistry.get_equipment_set(set_id)
		var would_be: Array[Dictionary]
		var target_slot: String = "" if definition == null else EquipmentBonuses.target_slot_for(definition.equipment_category)
		if equipped_slot == "" and target_slot != "":
			would_be = EquipmentBonuses.swapped_contents(target_slot, contents)
		else:
			would_be = EquipmentBonuses.equipped_contents()
		var count: int = EquipmentBonuses.set_piece_counts(would_be).get(set_id, 0) as int
		lines.append(tr("INVENTORY_INFO_SET_LINE") % [set_res.display_name, count, set_res.member_item_ids.size()])
```

- Generalize the removed-stats loop to any preview stat absent from the item's own stats (gain or loss). Replace the existing loop:

```gdscript
	# Stats the swap would REMOVE: a loss in the preview that the candidate itself lacks.
	for stat: StringName in ordered_stats(preview["flat"]):
		if not own.has(stat) and preview["flat"][stat] < 0.0:
			lines.append(_colored(_stat_line(stat, preview["flat"][stat]), COLOR_LOSS))
```

with:

```gdscript
	# Stats the swap changes that the candidate itself lacks (a removed item's
	# stat, or a set bonus completed/broken by the swap): gains and losses,
	# signed, never color alone.
	for stat: StringName in ordered_stats(preview["flat"]):
		if not own.has(stat) and absf(preview["flat"][stat]) > 0.00001:
			var change: float = preview["flat"][stat]
			lines.append(_colored(_stat_line(stat, change), COLOR_GAIN if change > 0.0 else COLOR_LOSS))
	var additive_change: float = 0.0
	for stat: Variant in preview["additive"]:
		additive_change = maxf(additive_change, absf(float(preview["additive"][stat])))
	if additive_change > 0.00001:
		var sign_char: String = "+" if _additive_gain(preview["additive"]) else "-"
		lines.append(_colored("%s %s%.1f%%" % [tr("INVENTORY_INFO_ALL_STATS"), sign_char, additive_change * 100.0], COLOR_GAIN if sign_char == "+" else COLOR_LOSS))
```

and add the tiny helper:

```gdscript
static func _additive_gain(additive_delta: Dictionary) -> bool:
	for stat: Variant in additive_delta:
		return float(additive_delta[stat]) > 0.0
	return false
```

(An additive change from sets/runes is uniform across all 14 stats, so the first entry's sign is the direction; an empty dict never reaches here.)

- [ ] **Step 4: Run tests**

Run the reimport command, then `res://tests/unit/inventory/equipment_info_panel_sets_test.gd`, `res://tests/unit/inventory/equipment_info_panel_test.gd`, `res://tests/integration/inventory-screen`, `res://tests/unit/equipment`. Expected: all PASS. If a swap-preview test fails on exact text, print `_panel.get_body_text()` and reconcile the assertion with the real format (the panel's format helpers are authoritative), without weakening what it checks.

- [ ] **Step 5: Docs and session state**

Create `design/balance/equipment-set-bonuses.md`: a short header (authored 2026-09-20, first-pass unplaytested, link to the spec and `equipment-base-stats.md`), the spec §4 table verbatim, and the two open questions (cross-set stacking; Sentinel's dual offhands). Add one blockquote line under a suitable heading in `design/gdd/equipment-forge.md` (use awk with `ENVIRON`, no `sed` with `&`): "> **Update 2026-09-20:** equipment now has set bonuses (nine item-family sets earning cumulative stat bonuses) — see `docs/superpowers/specs/2026-09-20-equipment-set-bonuses-design.md`." Append an "Equipment set bonuses shipped" extract to `production/session-state/active.md` (nine sets, the distinct-piece counting rule, the `compute()` integration and why Hero needed no change, the panel additions, that live verification is still deferred, and the two open questions).

- [ ] **Step 6: Commit and push**

```bash
git add src/gameplay/ui/inventory_screen/equipment_info_panel.gd assets/localization/strings.csv tests/unit/inventory/equipment_info_panel_sets_test.gd tests/unit/inventory/equipment_info_panel_sets_test.gd.uid tests/unit/inventory/equipment_info_panel_test.gd design/balance/equipment-set-bonuses.md design/gdd/equipment-forge.md production/session-state/active.md docs/superpowers/plans/2026-09-20-equipment-set-bonuses.md
git commit -m "Show set bonuses in the equipment info panel

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
git show --name-only --format= HEAD
```

---

## Self-Review

- **Spec coverage:** §3.1 resource + validate -> Task 1 (AC-1); §3.2 registry -> Task 2 (AC-2); §3.3 counting/cumulative + §3.4 integration -> Task 4 (AC-3, AC-4, AC-5, AC-6, AC-7); §3.5 UI (Bonuses section, item-card line, swap-preview generalization, strings) -> Task 5 (AC-9, AC-10); §3.6 no persistence -> nothing to build; §3.7 + §4 values -> Task 3 content test (AC-8); AC-11 regression -> the wide suite runs in Tasks 2, 4 and 5 plus the two named existing-test edits; docs (§7) -> Task 5 Step 5.
- **Placeholders:** none. The only conditional instructions (update an existing exact-total test; reconcile swap-preview text) are bounded and name the rule.
- **Type/name consistency:** `set_id_for_item`, `set_piece_counts`, `set_bonuses`, `equipped_contents`, `swapped_contents`, `get_equipment_set`, `get_all_equipment_sets`, `_load_equipment_sets`, `_equipment_sets_dir`, `EquipmentSetResource` fields, and string keys are identical across tasks; set ids/values match spec §4 and the content test's `EXPECTED`.
