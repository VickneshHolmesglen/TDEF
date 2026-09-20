# Equipment Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show equipped-gear bonuses and a per-item detail card (with swap preview) on the Inventory screen's Equipment tab.

**Architecture:** Extract Hero's bonus-folding into a shared pure `EquipmentBonuses` class (Hero and the UI both call it). A code-built `EquipmentInfoPanel` (no `class_name`) sits beside the paperdoll and switches between a "Bonuses" state and an item detail card, driven by hover/focus on slot buttons and paperdoll frames.

**Tech Stack:** Godot 4.6.2, GDScript, gdUnit4.

**Spec:** `docs/superpowers/specs/2026-09-20-equipment-display-design.md`

## Global Constraints

- Hero behavior must not change: `hero_equipment_stats_test.gd`, `hero_stat_resolution_test.gd`, `hero_leveling_test.gd` pass UNMODIFIED.
- `Hero.EQUIPMENT_FAN_OUT_STATS` and `Hero._fold_stat_entry` stay (thin alias/wrapper) so existing tests and callers keep working.
- New `class_name` files require a class-cache rebuild before tests/MCP see them: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --editor --path G:\TDef --quit`. After ANY `strings.csv` edit, run the same command (translation reimport).
- `EquipmentInfoPanel` has NO `class_name` (same class-cache-fragility reason as `equipment_paperdoll.gd`); it is loaded via `preload`.
- No hover-only interactions: hover AND focus both drive the panel. Swap-preview direction is conveyed by `+`/`-` sign, never color alone.
- All player-facing text through `tr()` with new `INVENTORY_STAT_*` / `INVENTORY_INFO_*` keys.
- Typed GDScript, snake_case, no `#` comments inside `.tscn`/`.tres` blocks.
- Run only the targeted tests named here. Test runner: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a <res:// path> --ignoreHeadlessMode`.
- Commit and push after each task's tests pass (standing user rule). Commit messages end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.

## File Structure

- Create `src/core/equipment/equipment_bonuses.gd` — pure static calculator.
- Modify `src/core/hero/hero.gd` — delegate to `EquipmentBonuses`.
- Create `src/gameplay/ui/inventory_screen/equipment_info_panel.gd` — panel (formatting statics + two states).
- Modify `src/gameplay/ui/inventory_screen/equipment_paperdoll.gd` — hover signals.
- Modify `src/gameplay/ui/inventory_screen/inventory_screen.gd` — build/mount panel, hover/focus wiring, visibility.
- Modify `assets/localization/strings.csv` — new keys.
- Create `tests/unit/equipment/equipment_bonuses_test.gd`, `tests/unit/inventory/equipment_info_panel_test.gd`, `tests/integration/inventory-screen/equipment-info-panel_test.gd`.

---

### Task 1: `EquipmentBonuses` + Hero delegation

**Files:**
- Create: `src/core/equipment/equipment_bonuses.gd`
- Modify: `src/core/hero/hero.gd` (`EQUIPMENT_FAN_OUT_STATS` const, `_recompute_equipment_bonuses()`, `_fold_stat_entry()` — added in commit 62f1d4a, near lines 349-370 and after `_exit_tree()`)
- Test: `tests/unit/equipment/equipment_bonuses_test.gd`

**Interfaces:**
- Produces (all static on `EquipmentBonuses`):
  - `const FAN_OUT_STATS: Array[StringName]`
  - `fold_stat_entry(stat: StringName, value: float, new_flat: Dictionary[StringName, float], new_additive: Dictionary[StringName, float]) -> void`
  - `item_stats(contents: Dictionary) -> Dictionary[StringName, float]`
  - `rune_stats(contents: Dictionary) -> Dictionary` (`{"flat": Dictionary[StringName,float], "additive": Dictionary[StringName,float]}`)
  - `compute(slot_contents: Array[Dictionary]) -> Dictionary` (same `{"flat","additive"}` shape)
  - `compute_equipped() -> Dictionary`
  - `preview_swap(slot_name: String, candidate_contents: Dictionary) -> Dictionary` (`{"flat","additive"}` of per-stat differences; zero differences omitted)
  - `target_slot_for(category: String) -> String`
- `contents` everywhere is the `Inventory.get_equipped_item()` / `get_slot_contents()` shape: keys `item_id: String`, `stat_overrides: Dictionary`, `imbued_runes: Array[String]`, `rune_slot_count: int`.

- [ ] **Step 1: Write the failing test**

Fixtures: real `iron_sword` (main_hand, base `{physical_attack}`) and `iron_helm` (helmet, base `{max_hp, armor}`), overriding every base key so expected values are exact.

```gdscript
extends GdUnitTestSuite

## Unit tests for EquipmentBonuses (equipment-display spec §3.1-3.2, AC-2..AC-5).

const SWORD: String = "res://assets/data/items/iron_sword.tres"
const HELM: String = "res://assets/data/items/iron_helm.tres"
const RING_A: String = "res://assets/data/items/iron_band.tres"


func before_test() -> void:
	GInventory.reset_to_defaults()


func after_test() -> void:
	GInventory.reset_to_defaults()


func _equip(slot: String, path: String, overrides: Dictionary[StringName, float]) -> void:
	assert_bool(GInventory.equip_item(slot, load(path), overrides)).is_true()


func _contents(item_id: String, overrides: Dictionary, runes: Array[String] = []) -> Dictionary:
	return {"item_id": item_id, "stat_overrides": overrides, "imbued_runes": runes, "rune_slot_count": 2}


func test_fan_out_list_has_14_unique_stats() -> void:
	assert_int(EquipmentBonuses.FAN_OUT_STATS.size()).is_equal(14)
	assert_int(Hero.EQUIPMENT_FAN_OUT_STATS.size()).is_equal(14)


func test_item_stats_override_wins_over_base() -> void:
	var stats: Dictionary = EquipmentBonuses.item_stats(_contents("iron_helm", {&"max_hp": 99.0, &"armor": 9.0}))
	assert_float(stats[&"max_hp"]).is_equal_approx(99.0, 0.0001)
	assert_float(stats[&"armor"]).is_equal_approx(9.0, 0.0001)


func test_item_stats_falls_back_to_base_stats_when_no_override() -> void:
	var base: Dictionary = (load(HELM) as ItemDefinitionResource).base_stats
	var stats: Dictionary = EquipmentBonuses.item_stats(_contents("iron_helm", {}))
	assert_float(stats[&"max_hp"]).is_equal_approx(base[&"max_hp"], 0.0001)


func test_item_stats_unregistered_item_is_empty() -> void:
	assert_dict(EquipmentBonuses.item_stats(_contents("no_such_item", {&"armor": 5.0}))).is_empty()


func test_compute_sums_two_items_sharing_a_stat() -> void:
	var a: Dictionary = _contents("iron_helm", {&"max_hp": 10.0, &"armor": 4.0})
	var b: Dictionary = _contents("iron_sword", {&"physical_attack": 6.0, &"armor": 3.0})
	var r: Dictionary = EquipmentBonuses.compute([a, b])
	assert_float(r["flat"][&"armor"]).is_equal_approx(7.0, 0.0001)
	assert_float(r["flat"][&"max_hp"]).is_equal_approx(10.0, 0.0001)
	assert_bool((r["additive"] as Dictionary).is_empty()).is_true()


func test_compute_constellation_rune_fans_out_additive() -> void:
	var shape_id: String = Constellation.SHAPE_N.keys()[0]
	var c: Dictionary = _contents("iron_helm", {&"max_hp": 10.0, &"armor": 4.0}, ["rune_%s" % shape_id])
	var r: Dictionary = EquipmentBonuses.compute([c])
	assert_int((r["additive"] as Dictionary).size()).is_equal(14)
	assert_float(r["additive"][&"luck"]).is_equal_approx(EquipmentForge.RUNE_ADDITIVE_BONUS, 0.0001)


func test_compute_skips_empty_and_unregistered_entries() -> void:
	var r: Dictionary = EquipmentBonuses.compute([{}, _contents("no_such_item", {&"armor": 5.0})])
	assert_bool((r["flat"] as Dictionary).is_empty()).is_true()


func test_compute_equipped_matches_hero_result() -> void:
	_equip("main_hand", SWORD, {&"physical_attack": 6.0})
	_equip("helmet", HELM, {&"max_hp": 10.0, &"armor": 4.0})
	var r: Dictionary = EquipmentBonuses.compute_equipped()
	var hero: Hero = Hero.new()
	add_child(hero)
	assert_float(hero.get_effective_stat(&"armor") - hero._base_stats[&"armor"]).is_equal_approx(r["flat"][&"armor"], 0.0001)
	remove_child(hero)
	hero.free()


func test_preview_swap_reports_gain_loss_and_omits_zero() -> void:
	_equip("helmet", HELM, {&"max_hp": 10.0, &"armor": 4.0})
	var candidate: Dictionary = _contents("iron_helm", {&"max_hp": 10.0, &"armor": 12.0})
	var d: Dictionary = EquipmentBonuses.preview_swap("helmet", candidate)
	assert_float(d["flat"][&"armor"]).is_equal_approx(8.0, 0.0001)
	assert_bool((d["flat"] as Dictionary).has(&"max_hp")).is_false()


func test_preview_swap_includes_removed_stat_as_negative() -> void:
	_equip("helmet", HELM, {&"max_hp": 10.0, &"armor": 4.0})
	var candidate: Dictionary = _contents("iron_helm", {&"armor": 4.0})
	var base: Dictionary = (load(HELM) as ItemDefinitionResource).base_stats
	var d: Dictionary = EquipmentBonuses.preview_swap("helmet", candidate)
	# candidate still inherits base max_hp (25) since only armor is overridden
	assert_float(d["flat"][&"max_hp"]).is_equal_approx(base[&"max_hp"] - 10.0, 0.0001)


func test_preview_swap_into_empty_slot_equals_full_stats() -> void:
	var candidate: Dictionary = _contents("iron_helm", {&"max_hp": 10.0, &"armor": 4.0})
	var d: Dictionary = EquipmentBonuses.preview_swap("helmet", candidate)
	assert_float(d["flat"][&"armor"]).is_equal_approx(4.0, 0.0001)


func test_target_slot_for_ring_prefers_first_empty() -> void:
	assert_str(EquipmentBonuses.target_slot_for("ring")).is_equal("ring_1")
	_equip("ring_1", RING_A, {&"physical_attack": 1.0, &"crit_chance": 0.01})
	assert_str(EquipmentBonuses.target_slot_for("ring")).is_equal("ring_2")
	_equip("ring_2", RING_A, {&"physical_attack": 1.0, &"crit_chance": 0.01})
	assert_str(EquipmentBonuses.target_slot_for("ring")).is_equal("ring_1")


func test_target_slot_for_unknown_category_is_empty() -> void:
	assert_str(EquipmentBonuses.target_slot_for("banana")).is_equal("")
	assert_str(EquipmentBonuses.target_slot_for("weapon")).is_equal("main_hand")
```

- [ ] **Step 2: Rebuild class cache, run test, verify it fails**

Run the class-cache command from Global Constraints, then run `res://tests/unit/equipment/equipment_bonuses_test.gd`.
Expected: FAIL — `EquipmentBonuses` not found.

- [ ] **Step 3: Implement `EquipmentBonuses`**

```gdscript
class_name EquipmentBonuses
extends RefCounted

## Shared, pure equipment-bonus calculator (equipment-display spec §3.1-3.2).
## Extracted from Hero's private fold (equipment-stats-wiring spec §3.2-3.3)
## so Hero and the Inventory UI can never disagree. Static-only, no state.
## "contents" is the Inventory.get_equipped_item()/get_slot_contents() shape.

## Every real Hero _base_stats key (fan-out target for `additive_bonus_total`).
## MAINTENANCE POINT: add any new Hero stat here too. Hero.EQUIPMENT_FAN_OUT_STATS
## aliases this; hero_equipment_stats_test.gd checks it against PLACEHOLDER_BASE_STATS.
const FAN_OUT_STATS: Array[StringName] = [
	&"max_hp", &"physical_attack", &"move_speed", &"cdr", &"crit_chance",
	&"armor", &"magic_attack", &"attack_range", &"elemental_resist_fire",
	&"elemental_resist_frost", &"lifesteal", &"tower_affinity",
	&"crit_multiplier", &"luck",
]


## `additive_bonus_total` fans out into the additive bucket of every real
## stat; any other key is a flat bonus to that named stat. Unknown stat
## names are stored but never read by Hero (inert).
static func fold_stat_entry(stat: StringName, value: float, new_flat: Dictionary[StringName, float], new_additive: Dictionary[StringName, float]) -> void:
	if stat == &"additive_bonus_total":
		for real_stat: StringName in FAN_OUT_STATS:
			new_additive[real_stat] = new_additive.get(real_stat, 0.0) + value
	else:
		new_flat[stat] = new_flat.get(stat, 0.0) + value


static func _definition_for(contents: Dictionary) -> ItemDefinitionResource:
	var item_id: String = contents.get("item_id", "") as String
	if item_id == "":
		return null
	return GGameDataRegistry.get_item_definition(StringName(item_id))


## One item's own flat stats (no runes): base_stats template overlaid by
## stat_overrides (the real roll). {} if the item has no registered definition.
static func item_stats(contents: Dictionary) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	var definition: ItemDefinitionResource = _definition_for(contents)
	if definition == null:
		return out
	for stat: StringName in definition.base_stats:
		out[stat] = definition.base_stats[stat]
	var overrides: Dictionary = contents.get("stat_overrides", {})
	for stat: Variant in overrides:
		out[StringName(stat)] = float(overrides[stat])
	return out


## The folded contribution of one item's imbued runes, resolved on demand.
static func rune_stats(contents: Dictionary) -> Dictionary:
	var flat: Dictionary[StringName, float] = {}
	var additive: Dictionary[StringName, float] = {}
	for rune_id: String in contents.get("imbued_runes", []):
		var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(StringName(rune_id))
		for stat: Variant in delta:
			fold_stat_entry(StringName(stat), float(delta[stat]), flat, additive)
	return {"flat": flat, "additive": additive}


## Full fold over any list of equipped-slot contents. Empty entries and
## items with no registered definition are skipped entirely (runes included),
## matching Hero's pre-extraction behavior.
static func compute(slot_contents: Array[Dictionary]) -> Dictionary:
	var flat: Dictionary[StringName, float] = {}
	var additive: Dictionary[StringName, float] = {}
	for contents: Dictionary in slot_contents:
		if contents.is_empty() or _definition_for(contents) == null:
			continue
		var stats: Dictionary[StringName, float] = item_stats(contents)
		for stat: StringName in stats:
			fold_stat_entry(stat, stats[stat], flat, additive)
		var runes: Dictionary = rune_stats(contents)
		for stat: StringName in runes["flat"]:
			fold_stat_entry(stat, runes["flat"][stat], flat, additive)
		for stat: StringName in runes["additive"]:
			additive[stat] = additive.get(stat, 0.0) + runes["additive"][stat]
	return {"flat": flat, "additive": additive}


static func _equipped_contents() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_name: String in Inventory.EQUIPMENT_SLOT_NAMES:
		result.append(GInventory.get_equipped_item(slot_name))
	return result


static func compute_equipped() -> Dictionary:
	return compute(_equipped_contents())


static func _diff(after: Dictionary, before: Dictionary) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	var keys: Dictionary = {}
	for k: Variant in after:
		keys[k] = true
	for k: Variant in before:
		keys[k] = true
	for k: Variant in keys:
		var d: float = float(after.get(k, 0.0)) - float(before.get(k, 0.0))
		if absf(d) > 0.00001:
			out[StringName(k)] = d
	return out


## Per-stat change in total equipment bonuses if `candidate_contents` replaced
## whatever is in `slot_name` (positive = gain). Zero differences omitted.
static func preview_swap(slot_name: String, candidate_contents: Dictionary) -> Dictionary:
	var current: Array[Dictionary] = _equipped_contents()
	var swapped: Array[Dictionary] = []
	for i: int in range(Inventory.EQUIPMENT_SLOT_NAMES.size()):
		swapped.append(candidate_contents if Inventory.EQUIPMENT_SLOT_NAMES[i] == slot_name else current[i])
	var before: Dictionary = compute(current)
	var after: Dictionary = compute(swapped)
	return {
		"flat": _diff(after["flat"], before["flat"]),
		"additive": _diff(after["additive"], before["additive"]),
	}


## Which slot an inventory item of `category` would go into: the first empty
## slot of that category, else the first slot of that category; "" if none.
static func target_slot_for(category: String) -> String:
	var first_match: String = ""
	for slot_name: String in Inventory.EQUIPMENT_SLOT_NAMES:
		if Inventory.EQUIPMENT_SLOT_CATEGORY[slot_name] != category:
			continue
		if first_match == "":
			first_match = slot_name
		if GInventory.get_equipped_item(slot_name).is_empty():
			return slot_name
	return first_match
```

- [ ] **Step 4: Refactor Hero to delegate**

In `src/core/hero/hero.gd`, replace the `EQUIPMENT_FAN_OUT_STATS` const body with an alias, and simplify the two methods:

```gdscript
## Alias kept for existing callers/tests; the list lives in EquipmentBonuses.
const EQUIPMENT_FAN_OUT_STATS: Array[StringName] = EquipmentBonuses.FAN_OUT_STATS
```

Keep the existing doc comment above it but trim its maintenance-point text to "see EquipmentBonuses.FAN_OUT_STATS". Replace the body of `_recompute_equipment_bonuses()` (keep its doc comment):

```gdscript
func _recompute_equipment_bonuses() -> void:
	var result: Dictionary = EquipmentBonuses.compute_equipped()
	_flat_bonuses = result["flat"]
	_additive_bonuses = result["additive"]
```

Replace the body of `_fold_stat_entry()` with a delegation (keep signature and static):

```gdscript
static func _fold_stat_entry(stat: StringName, value: float, new_flat: Dictionary[StringName, float], new_additive: Dictionary[StringName, float]) -> void:
	EquipmentBonuses.fold_stat_entry(stat, value, new_flat, new_additive)
```

- [ ] **Step 5: Rebuild class cache, run tests**

Run the class-cache command, then run: `res://tests/unit/equipment/equipment_bonuses_test.gd`, `res://tests/unit/hero`, `res://tests/unit/equipment_forge`, `res://tests/integration/equipment-forge`.
Expected: all PASS, Hero suites unmodified.

- [ ] **Step 6: Commit and push**

```bash
git add src/core/equipment/equipment_bonuses.gd src/core/hero/hero.gd tests/unit/equipment/equipment_bonuses_test.gd
git commit -m "Extract EquipmentBonuses shared calculator from Hero

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
```

---

### Task 2: Localization keys + `EquipmentInfoPanel`

**Files:**
- Modify: `assets/localization/strings.csv` (append rows)
- Create: `src/gameplay/ui/inventory_screen/equipment_info_panel.gd`
- Test: `tests/unit/inventory/equipment_info_panel_test.gd`

**Interfaces:**
- Consumes: `EquipmentBonuses.*` (Task 1), `Inventory.EQUIPMENT_SLOT_CATEGORY`, `ShellChromeStyle.chrome_panel_stylebox() -> StyleBoxFlat`.
- Produces (`equipment_info_panel.gd`, `extends PanelContainer`, no `class_name`):
  - statics: `format_value(stat: StringName, value: float) -> String` (signed), `stat_label(stat: StringName) -> String`, `ordered_stats(stats: Dictionary) -> Array[StringName]`
  - instance: `show_bonuses() -> void`, `show_item(contents: Dictionary, equipped_slot: String = "") -> void`, `refresh() -> void`, `get_body_text() -> String` (plain text of the body, for tests)

- [ ] **Step 1: Append localization rows**

Ensure `strings.csv` ends with a newline, then append (values contain no commas):

```
INVENTORY_STAT_MAX_HP,Max HP
INVENTORY_STAT_ARMOR,Armor
INVENTORY_STAT_PHYSICAL_ATTACK,Physical Attack
INVENTORY_STAT_MAGIC_ATTACK,Magic Attack
INVENTORY_STAT_MOVE_SPEED,Move Speed
INVENTORY_STAT_ATTACK_RANGE,Attack Range
INVENTORY_STAT_CRIT_CHANCE,Crit Chance
INVENTORY_STAT_CRIT_MULTIPLIER,Crit Multiplier
INVENTORY_STAT_LUCK,Luck
INVENTORY_STAT_CDR,Cooldown Reduction
INVENTORY_STAT_LIFESTEAL,Lifesteal
INVENTORY_STAT_ELEMENTAL_RESIST_FIRE,Fire Resist
INVENTORY_STAT_ELEMENTAL_RESIST_FROST,Frost Resist
INVENTORY_INFO_BONUSES_HEADER,Equipment Bonuses
INVENTORY_INFO_NO_BONUSES,No equipment bonuses
INVENTORY_INFO_NO_STATS,No stat bonuses
INVENTORY_INFO_RUNE_SLOTS,Rune slots: %d/%d free
INVENTORY_INFO_UNKNOWN_RUNE,Unknown rune
INVENTORY_INFO_ALL_STATS,All stats
INVENTORY_INFO_RUNE_LINE,Rune
```

Run the reimport command from Global Constraints.

- [ ] **Step 2: Write the failing test**

```gdscript
extends GdUnitTestSuite

## Unit tests for equipment_info_panel.gd (equipment-display spec §3.3, §3.5,
## AC-6..AC-8, AC-10). Label assertions use the panel's own stat_label() so
## they hold whether or not the translation is loaded.

const PanelScript := preload("res://src/gameplay/ui/inventory_screen/equipment_info_panel.gd")
const HELM: String = "res://assets/data/items/iron_helm.tres"
const SWORD: String = "res://assets/data/items/iron_sword.tres"

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


func _contents(item_id: String, overrides: Dictionary, runes: Array[String] = [], rune_slots: int = 2) -> Dictionary:
	return {"item_id": item_id, "stat_overrides": overrides, "imbued_runes": runes, "rune_slot_count": rune_slots}


func test_format_value_uses_integer_decimal_and_percent_forms() -> void:
	assert_str(PanelScript.format_value(&"max_hp", 96.0)).is_equal("+96")
	assert_str(PanelScript.format_value(&"physical_attack", 6.0)).is_equal("+6.0")
	assert_str(PanelScript.format_value(&"crit_chance", 0.056)).is_equal("+5.6%")
	assert_str(PanelScript.format_value(&"armor", -8.0)).is_equal("-8")
	assert_str(PanelScript.format_value(&"some_typo_stat", 2.0)).is_equal("+2.0")


func test_ordered_stats_follow_display_order_and_put_unknown_last() -> void:
	var order: Array[StringName] = PanelScript.ordered_stats({&"typo_stat": 1.0, &"luck": 0.1, &"max_hp": 5.0, &"armor": 2.0})
	assert_array(order).is_equal([&"max_hp", &"armor", &"luck", &"typo_stat"])


func test_bonuses_state_empty_shows_no_bonuses_line() -> void:
	_panel.show_bonuses()
	assert_str(_panel.get_body_text()).contains(tr("INVENTORY_INFO_NO_BONUSES"))


func test_bonuses_state_lists_equipped_totals() -> void:
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 96.0, &"armor": 20.0})
	_panel.show_bonuses()
	var text: String = _panel.get_body_text()
	assert_str(text).contains("+96")
	assert_str(text).contains("+20")
	assert_str(text).contains(PanelScript.stat_label(&"max_hp"))


func test_bonuses_state_shows_all_stats_row_for_fan_out_rune() -> void:
	var shape_id: String = Constellation.SHAPE_N.keys()[0]
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	var slot: Dictionary = GInventory.get_equipped_item("helmet")
	assert_bool(GInventory.apply_rune_to_item(slot["instance_id"], "rune_%s" % shape_id, {})).is_true()
	_panel.show_bonuses()
	assert_str(_panel.get_body_text()).contains(tr("INVENTORY_INFO_ALL_STATS"))
	assert_str(_panel.get_body_text()).contains("+5.0%")


func test_card_for_equipped_item_shows_name_stats_and_rune_slots() -> void:
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	var contents: Dictionary = GInventory.get_equipped_item("helmet")
	_panel.show_item(contents, "helmet")
	var text: String = _panel.get_body_text()
	assert_str(text).contains("Iron Helm")
	assert_str(text).contains("+10")
	assert_str(text).contains("+4")
	assert_str(text).not_contains("(")


func test_card_for_inventory_item_shows_swap_delta_with_sign() -> void:
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	_panel.show_item(_contents("iron_helm", {&"max_hp": 10.0, &"armor": 12.0}), "")
	assert_str(_panel.get_body_text()).contains("(+8)")


func test_card_shows_removed_stat_as_negative_row() -> void:
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	var candidate: Dictionary = _contents("iron_helm", {&"max_hp": 0.0001, &"armor": 4.0})
	_panel.show_item(candidate, "")
	assert_str(_panel.get_body_text()).contains("-10")


func test_card_with_no_stats_shows_no_stat_bonuses() -> void:
	_panel.show_item(_contents("no_such_item", {}), "")
	assert_str(_panel.get_body_text()).contains(tr("INVENTORY_INFO_NO_STATS"))
	assert_str(_panel.get_body_text()).contains("no_such_item")


func test_card_lists_unknown_rune_and_free_rune_slots() -> void:
	_panel.show_item(_contents("iron_helm", {&"max_hp": 10.0, &"armor": 4.0}, ["rune_does_not_exist"], 3), "")
	var text: String = _panel.get_body_text()
	assert_str(text).contains(tr("INVENTORY_INFO_UNKNOWN_RUNE"))
	assert_str(text).contains(tr("INVENTORY_INFO_RUNE_SLOTS") % [2, 3])


func test_unknown_stat_key_is_rendered_not_dropped() -> void:
	_panel.show_item(_contents("iron_helm", {&"max_hp": 10.0, &"armor": 4.0, &"typo_stat": 3.0}), "helmet")
	assert_str(_panel.get_body_text()).contains("typo_stat")


func test_refresh_falls_back_to_bonuses_when_equipped_slot_emptied() -> void:
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	_panel.show_item(GInventory.get_equipped_item("helmet"), "helmet")
	GInventory.unequip_item("helmet")
	_panel.refresh()
	assert_str(_panel.get_body_text()).contains(tr("INVENTORY_INFO_NO_BONUSES"))
```

- [ ] **Step 3: Run test to verify it fails**

Run `res://tests/unit/inventory/equipment_info_panel_test.gd`. Expected: FAIL — script not found.

- [ ] **Step 4: Implement the panel**

```gdscript
extends PanelContainer

## Equipment info panel (equipment-display spec §3.3-3.6). Two states:
## "Equipment Bonuses" (default) and an item detail card with a swap preview.
## No class_name -- same class-cache-fragility reason as equipment_paperdoll.gd;
## inventory_screen.gd loads it via preload().

const STAT_DISPLAY_ORDER: Array[StringName] = [
	&"max_hp", &"armor", &"physical_attack", &"magic_attack", &"move_speed",
	&"attack_range", &"crit_chance", &"crit_multiplier", &"luck", &"cdr",
	&"lifesteal", &"elemental_resist_fire", &"elemental_resist_frost",
]
const INTEGER_STATS: Array[StringName] = [&"max_hp", &"armor", &"move_speed", &"attack_range"]
const DECIMAL_STATS: Array[StringName] = [&"physical_attack", &"magic_attack"]
const PERCENT_STATS: Array[StringName] = [
	&"crit_chance", &"crit_multiplier", &"luck", &"cdr", &"lifesteal",
	&"elemental_resist_fire", &"elemental_resist_frost",
]
const COLOR_GAIN: String = "#5fd35f"
const COLOR_LOSS: String = "#e5534b"
const COLOR_MUTED: String = "#9aa3b2"

enum State { BONUSES, ITEM }

var _state: State = State.BONUSES
var _shown_contents: Dictionary = {}
var _shown_equipped_slot: String = ""
var _header: Label
var _body: RichTextLabel


func _ready() -> void:
	custom_minimum_size = Vector2(260, 0)
	add_theme_stylebox_override("panel", ShellChromeStyle.chrome_panel_stylebox())
	var column := VBoxContainer.new()
	add_child(column)
	_header = Label.new()
	column.add_child(_header)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.custom_minimum_size = Vector2(240, 0)
	column.add_child(_body)
	GEventBus.equipment_slot_changed.connect(_on_equipment_slot_changed)
	GEventBus.item_rune_imbued.connect(_on_item_rune_imbued)
	show_bonuses()


func _exit_tree() -> void:
	if GEventBus.equipment_slot_changed.is_connected(_on_equipment_slot_changed):
		GEventBus.equipment_slot_changed.disconnect(_on_equipment_slot_changed)
	if GEventBus.item_rune_imbued.is_connected(_on_item_rune_imbued):
		GEventBus.item_rune_imbued.disconnect(_on_item_rune_imbued)


func _on_equipment_slot_changed(_slot: String, _new_item_id: String, _previous_item_id: String) -> void:
	refresh()


func _on_item_rune_imbued(_item_id: String, _rune_id: String, _rune_source: String) -> void:
	refresh()


# ---------------------------------------------------------------------------
# Formatting (static, unit-tested directly)
# ---------------------------------------------------------------------------

## Signed display string: integers for HP/armor/speed/range, one decimal for
## attack stats, percent (value x 100, one decimal) for fractional stats.
## Unknown stat keys fall back to one decimal so a content typo is visible.
static func format_value(stat: StringName, value: float) -> String:
	var sign_char: String = "+" if value >= 0.0 else "-"
	var magnitude: float = absf(value)
	if INTEGER_STATS.has(stat):
		return "%s%d" % [sign_char, int(roundf(magnitude))]
	if PERCENT_STATS.has(stat):
		return "%s%.1f%%" % [sign_char, magnitude * 100.0]
	return "%s%.1f" % [sign_char, magnitude]


static func stat_label(stat: StringName) -> String:
	if STAT_DISPLAY_ORDER.has(stat):
		return tr("INVENTORY_STAT_%s" % String(stat).to_upper())
	return String(stat)


## STAT_DISPLAY_ORDER entries present in `stats`, then any other keys sorted.
static func ordered_stats(stats: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for stat: StringName in STAT_DISPLAY_ORDER:
		if stats.has(stat):
			out.append(stat)
	var extras: Array[String] = []
	for key: Variant in stats:
		if not STAT_DISPLAY_ORDER.has(StringName(key)):
			extras.append(String(key))
	extras.sort()
	for extra: String in extras:
		out.append(StringName(extra))
	return out


static func _colored(text: String, color: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]


static func _delta_suffix(stat: StringName, delta: float) -> String:
	if absf(delta) < 0.00001:
		return ""
	return " " + _colored("(%s)" % format_value(stat, delta), COLOR_GAIN if delta > 0.0 else COLOR_LOSS)


static func _stat_line(stat: StringName, value: float, suffix: String = "") -> String:
	return "%s %s%s" % [stat_label(stat), format_value(stat, value), suffix]


# ---------------------------------------------------------------------------
# States
# ---------------------------------------------------------------------------

func show_bonuses() -> void:
	_state = State.BONUSES
	_shown_contents = {}
	_shown_equipped_slot = ""
	_header.text = tr("INVENTORY_INFO_BONUSES_HEADER")
	var result: Dictionary = EquipmentBonuses.compute_equipped()
	var lines: Array[String] = []
	for stat: StringName in ordered_stats(result["flat"]):
		lines.append(_stat_line(stat, result["flat"][stat]))
	var additive_max: float = 0.0
	for stat: Variant in result["additive"]:
		additive_max = maxf(additive_max, float(result["additive"][stat]))
	if additive_max > 0.0:
		lines.append("%s +%.1f%%" % [tr("INVENTORY_INFO_ALL_STATS"), additive_max * 100.0])
	if lines.is_empty():
		lines.append(_colored(tr("INVENTORY_INFO_NO_BONUSES"), COLOR_MUTED))
	_body.text = "\n".join(lines)


## `equipped_slot` non-empty => the item is currently equipped (no swap
## preview); empty => an inventory item (swap preview vs. its target slot).
func show_item(contents: Dictionary, equipped_slot: String = "") -> void:
	_state = State.ITEM
	_shown_contents = contents
	_shown_equipped_slot = equipped_slot
	var item_id: String = contents.get("item_id", "") as String
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))
	_header.text = definition.display_name if definition != null and definition.display_name != "" else item_id

	var lines: Array[String] = []
	if definition != null and definition.equipment_category != "":
		lines.append(_colored(definition.equipment_category.capitalize(), COLOR_MUTED))

	var own: Dictionary[StringName, float] = EquipmentBonuses.item_stats(contents)
	var preview: Dictionary = {"flat": {}, "additive": {}}
	if equipped_slot == "" and definition != null:
		var target: String = EquipmentBonuses.target_slot_for(definition.equipment_category)
		if target != "":
			preview = EquipmentBonuses.preview_swap(target, contents)

	if own.is_empty():
		lines.append(_colored(tr("INVENTORY_INFO_NO_STATS"), COLOR_MUTED))
	for stat: StringName in ordered_stats(own):
		lines.append(_stat_line(stat, own[stat], _delta_suffix(stat, preview["flat"].get(stat, 0.0))))
	# Stats the swap would REMOVE: present in the preview as a loss, absent on the candidate.
	for stat: StringName in ordered_stats(preview["flat"]):
		if not own.has(stat) and preview["flat"][stat] < 0.0:
			lines.append(_colored(_stat_line(stat, preview["flat"][stat]), COLOR_LOSS))

	for rune_id: String in contents.get("imbued_runes", []):
		var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(StringName(rune_id))
		if delta.is_empty():
			lines.append("%s: %s" % [tr("INVENTORY_INFO_RUNE_LINE"), tr("INVENTORY_INFO_UNKNOWN_RUNE")])
			continue
		var parts: Array[String] = []
		for stat: Variant in delta:
			if StringName(stat) == &"additive_bonus_total":
				parts.append("%s +%.1f%%" % [tr("INVENTORY_INFO_ALL_STATS"), float(delta[stat]) * 100.0])
			else:
				parts.append(_stat_line(StringName(stat), float(delta[stat])))
		lines.append("%s: %s" % [tr("INVENTORY_INFO_RUNE_LINE"), ", ".join(parts)])

	var total_slots: int = contents.get("rune_slot_count", 0) as int
	if total_slots > 0:
		var used: int = (contents.get("imbued_runes", []) as Array).size()
		lines.append(_colored(tr("INVENTORY_INFO_RUNE_SLOTS") % [maxi(total_slots - used, 0), total_slots], COLOR_MUTED))
	_body.text = "\n".join(lines)


## Re-render after an equip/unequip/imbue. An equipped-item card is re-read
## from live inventory (falling back to Bonuses if its slot emptied); an
## inventory-item card falls back to Bonuses, since the item it described
## has likely just moved -- the next hover/focus re-shows a fresh card.
func refresh() -> void:
	if _state == State.ITEM and _shown_equipped_slot != "":
		var live: Dictionary = GInventory.get_equipped_item(_shown_equipped_slot)
		if not live.is_empty():
			show_item(live, _shown_equipped_slot)
			return
	show_bonuses()


## Plain (BBCode-stripped) body text, for tests.
func get_body_text() -> String:
	return _body.get_parsed_text()
```

- [ ] **Step 5: Run test to verify it passes**

Run `res://tests/unit/inventory/equipment_info_panel_test.gd`. Expected: PASS (12 tests). If a `tr()`-based assertion fails because the translation isn't loaded, both sides return the raw key, so it should still pass; if a label mismatch appears, re-run the reimport command.


- [ ] **Step 6: Commit and push**

```bash
git add assets/localization/strings.csv src/gameplay/ui/inventory_screen/equipment_info_panel.gd tests/unit/inventory/equipment_info_panel_test.gd
git commit -m "Add EquipmentInfoPanel (bonuses + item detail card with swap preview)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
```

---

### Task 3: Wire the panel into the Inventory screen

**Files:**
- Modify: `src/gameplay/ui/inventory_screen/equipment_paperdoll.gd` (`_build_slot_frame()` ~line 174; add signals near the top of the class)
- Modify: `src/gameplay/ui/inventory_screen/inventory_screen.gd` (`@onready _equipment_paperdoll` ~line 179; `_ready()` ~lines 330-345; `_on_tab_pressed()` ~line 416; `_create_slot_button()` ~line 728)
- Test: `tests/integration/inventory-screen/equipment-info-panel_test.gd`

**Interfaces:**
- Consumes: `EquipmentInfoPanel` API (Task 2), `Inventory.EQUIPMENT_SLOT_INDEX: Dictionary[String, int]`, `inventory.get_slot_contents(index) -> Dictionary`.
- Produces: paperdoll signals `slot_info_requested(slot_name: String)` and `slot_info_cleared()`; `inventory_screen.gd` members `_info_panel`, `_on_slot_info_requested(index: int)`, `_on_slot_info_cleared()`, `_set_equipment_widgets_visible(visible: bool)`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GdUnitTestSuite

## Integration tests for the Equipment tab's info panel wiring (equipment-
## display spec §3.4, AC-6, AC-7, AC-9). Uses the real InventoryScreen scene.

const HELM: String = "res://assets/data/items/iron_helm.tres"

var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	GInventory.reset_to_defaults()
	_runner = scene_runner("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn")
	_screen = _runner.scene() as Control


func after_test() -> void:
	GInventory.reset_to_defaults()


func _panel() -> PanelContainer:
	return _screen.get_node("MainLayout/LeftPanel/EquipmentRow/EquipmentInfoPanel") as PanelContainer


func _slot_button(inventory_index: int) -> Button:
	return _screen.get_node("MainLayout/LeftPanel/SlotGrid/Slot%d" % inventory_index) as Button


func test_panel_exists_and_defaults_to_bonuses() -> void:
	assert_object(_panel()).is_not_null()
	assert_str(_panel().get_body_text()).contains(tr("INVENTORY_INFO_NO_BONUSES"))


func test_paperdoll_still_reachable_inside_row() -> void:
	assert_object(_screen.get_node("MainLayout/LeftPanel/EquipmentRow/EquipmentPaperdoll")).is_not_null()


func test_focus_on_equipped_item_slot_shows_card_and_leaving_restores_bonuses() -> void:
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	var index: int = Inventory.EQUIPMENT_SLOT_INDEX["helmet"]
	var button: Button = _slot_button(index)
	button.focus_entered.emit()
	assert_str(_panel().get_body_text()).contains("+10")
	button.focus_exited.emit()
	assert_str(_panel().get_body_text()).contains("+10")  # bonuses state lists the equipped helm's totals
	assert_str(_panel().get_body_text()).not_contains("(")


func test_hover_on_empty_slot_shows_bonuses_state() -> void:
	var button: Button = _slot_button(0)
	button.mouse_entered.emit()
	assert_str(_panel().get_body_text()).contains(tr("INVENTORY_INFO_NO_BONUSES"))


func test_paperdoll_hover_shows_card_for_equipped_item() -> void:
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	var paperdoll: Control = _screen.get_node("MainLayout/LeftPanel/EquipmentRow/EquipmentPaperdoll")
	paperdoll.emit_signal(&"slot_info_requested", "helmet")
	assert_str(_panel().get_body_text()).contains("+10")
	assert_str(_panel().get_child(0).get_child(0).text).is_equal("Iron Helm")


func test_equip_event_updates_visible_panel_without_tab_switch() -> void:
	assert_str(_panel().get_body_text()).contains(tr("INVENTORY_INFO_NO_BONUSES"))
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	assert_str(_panel().get_body_text()).contains("+10")


func test_panel_visible_only_on_equipment_tab() -> void:
	_screen._on_tab_pressed(&"Equipment")
	assert_bool(_panel().visible).is_true()
	_screen._on_tab_pressed(&"TowerComponent")
	assert_bool(_panel().visible).is_false()
	_screen._on_tab_pressed(&"Equipment")
	assert_bool(_panel().visible).is_true()
```


- [ ] **Step 2: Run to verify it fails**

Run `res://tests/integration/inventory-screen/equipment-info-panel_test.gd`. Expected: FAIL — `EquipmentRow` node not found.

- [ ] **Step 3: Paperdoll hover signals**

In `equipment_paperdoll.gd`, add near the top of the class (after the const block, before `var _slot_frames`):

```gdscript
## Hover only: the frames are non-focusable Panels (existing design). Gamepad/
## keyboard reach the same equipped items through inventory_screen.gd's slot
## grid, whose focus events drive the same info panel.
signal slot_info_requested(slot_name: String)
signal slot_info_cleared()
```

In `_build_slot_frame()`, right after `frame.mouse_filter = Control.MOUSE_FILTER_PASS ...`:

```gdscript
	frame.mouse_entered.connect(_on_frame_mouse_entered.bind(slot_name))
	frame.mouse_exited.connect(_on_frame_mouse_exited)
```

Add the two handlers after `_on_equipment_slot_changed`:

```gdscript
func _on_frame_mouse_entered(slot_name: String) -> void:
	slot_info_requested.emit(slot_name)


func _on_frame_mouse_exited() -> void:
	slot_info_cleared.emit()
```

- [ ] **Step 4: Screen wiring**

In `inventory_screen.gd`:

Add near the other consts/preloads (top of the file's const block):

```gdscript
const EquipmentInfoPanelScript := preload("res://src/gameplay/ui/inventory_screen/equipment_info_panel.gd")
```

Add a member next to `_equipment_paperdoll`:

```gdscript
var _info_panel: PanelContainer
```

In `_ready()`, immediately BEFORE `_build_slot_grid()`:

```gdscript
	_build_equipment_info_panel()
```

Replace both existing lines `_equipment_paperdoll.visible = ...` (in `_ready()` and `_on_tab_pressed()`) with:

```gdscript
	_set_equipment_widgets_visible(_active_tab == &"Equipment")     # in _ready()
	_set_equipment_widgets_visible(tab == &"Equipment")             # in _on_tab_pressed()
```

Add the new methods (after `_on_tab_pressed`):

```gdscript
## Puts the paperdoll and the new info panel side by side in an HBox at the
## paperdoll's old position in LeftPanel (spec §3.3), and forwards the
## paperdoll's hover signals to the panel.
func _build_equipment_info_panel() -> void:
	var left_panel: VBoxContainer = $MainLayout/LeftPanel
	var row := HBoxContainer.new()
	row.name = "EquipmentRow"
	var paperdoll_index: int = _equipment_paperdoll.get_index()
	left_panel.add_child(row)
	left_panel.move_child(row, paperdoll_index)
	_equipment_paperdoll.reparent(row)
	_info_panel = EquipmentInfoPanelScript.new()
	_info_panel.name = "EquipmentInfoPanel"
	row.add_child(_info_panel)
	_equipment_paperdoll.connect(&"slot_info_requested", _on_paperdoll_slot_info_requested)
	_equipment_paperdoll.connect(&"slot_info_cleared", _on_slot_info_cleared)


func _set_equipment_widgets_visible(shown: bool) -> void:
	_equipment_paperdoll.visible = shown
	if _info_panel != null:
		_info_panel.visible = shown


func _on_paperdoll_slot_info_requested(slot_name: String) -> void:
	var contents: Dictionary = GInventory.get_equipped_item(slot_name)
	if contents.is_empty():
		_info_panel.show_bonuses()
		return
	_info_panel.show_item(contents, slot_name)


## Slot-grid button hover/focus. Empty slots and non-equipment items fall
## back to the Bonuses state; an item sitting in one of the 10 equipment
## slot indices is treated as equipped (no swap preview).
func _on_slot_info_requested(index: int) -> void:
	if _info_panel == null:
		return
	var contents: Dictionary = inventory.get_slot_contents(index)
	var item_id: String = contents.get("item_id", "") as String
	if item_id == "":
		_info_panel.show_bonuses()
		return
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))
	if definition == null or definition.equipment_category == "":
		_info_panel.show_bonuses()
		return
	_info_panel.show_item(contents, _equipped_slot_name_for_index(index))


func _on_slot_info_cleared() -> void:
	if _info_panel != null:
		_info_panel.show_bonuses()


func _equipped_slot_name_for_index(index: int) -> String:
	for slot_name: String in Inventory.EQUIPMENT_SLOT_INDEX:
		if Inventory.EQUIPMENT_SLOT_INDEX[slot_name] == index:
			return slot_name
	return ""
```

In `_create_slot_button(index)`, after the existing `focus_exited.connect(...)` line:

```gdscript
	# Equipment info panel (equipment-display spec §3.4): hover AND focus both
	# drive it, so K/M and gamepad share one path.
	button.mouse_entered.connect(_on_slot_info_requested.bind(index))
	button.mouse_exited.connect(_on_slot_info_cleared)
	button.focus_entered.connect(_on_slot_info_requested.bind(index))
	button.focus_exited.connect(_on_slot_info_cleared)
```

Also update the class header comment that says tooltips are deferred (`inventory_screen.gd` ~line 41): append one sentence, "The Equipment tab's item detail is now the fixed EquipmentInfoPanel (equipment-display spec); floating tooltips remain out of scope."

- [ ] **Step 5: Run tests**

Run: `res://tests/integration/inventory-screen` (whole directory — the reparent touches the layout every existing screen test mounts), `res://tests/unit/inventory/equipment_info_panel_test.gd`, `res://tests/unit/equipment/equipment_bonuses_test.gd`.
Expected: all PASS. If an existing screen test fails because it locates the paperdoll by its old path, fix that test's path to `MainLayout/LeftPanel/EquipmentRow/EquipmentPaperdoll` (grep found no such reference at planning time, so this is only a safeguard).

- [ ] **Step 6: Update session state, commit and push**

Append a short "Equipment Display shipped" extract to `production/session-state/active.md` (what was built, that live verification is deferred by user request, the paperdoll-hover-only/grid-focus note, and the inventory-item-card-falls-back-to-Bonuses-on-refresh behavior).

```bash
git add src/gameplay/ui/inventory_screen/equipment_paperdoll.gd src/gameplay/ui/inventory_screen/inventory_screen.gd tests/integration/inventory-screen/equipment-info-panel_test.gd production/session-state/active.md
git commit -m "Wire EquipmentInfoPanel into the Inventory screen's Equipment tab

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
```

---

## Self-Review

- **Spec coverage:** §3.1 → Task 1 (all seven static methods + Hero alias/delegation); §3.2 `preview_swap`/`target_slot_for` → Task 1; §3.3 panel, states, swap preview, removed-stat rows → Task 2; §3.4 wiring, paperdoll signals, event refresh → Tasks 2+3; §3.5 formatting/order/unknown-last → Task 2; §3.6 localization + reimport + sign-not-color → Tasks 2 (keys, `+`/`-` in `format_value`); AC-1 → Task 1 step 5 (Hero suites unmodified); AC-2..5 → Task 1 tests; AC-6 → Task 3 tests (focus + paperdoll hover); AC-7 → Task 3 event test; AC-8 → Task 2 tests; AC-9 → Task 3 visibility test; AC-10 → `format_value` signs + Task 2 tests.
- **Deliberate deviations from the spec (flagged):** (1) Paperdoll frames are hover-only (non-focusable Panels, pre-existing design); gamepad reaches the same items through the slot grid. (2) `refresh()` for an *inventory* item card falls back to Bonuses rather than re-rendering stale contents; equipped-item cards re-read live.
- **Placeholder scan:** none.
- **Type consistency:** `compute`/`compute_equipped`/`preview_swap` all return `{"flat","additive"}`; `show_item(contents, equipped_slot)` signature identical in Tasks 2 and 3; `EquipmentBonuses.FAN_OUT_STATS` aliased by `Hero.EQUIPMENT_FAN_OUT_STATS`.
