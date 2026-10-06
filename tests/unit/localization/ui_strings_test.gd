## Guards the runtime-generated UI strings that were moved into tr() keys:
## each key exists in strings.csv, has a non-empty English value, carries the
## printf placeholder count the call site supplies, and the in-scope scripts no
## longer contain the old hardcoded literals.
extends GdUnitTestSuite

const CSV_PATH: String = "res://assets/localization/strings.csv"

## key -> number of printf placeholders (%d/%s) the call site passes.
const EXPECTED_PLACEHOLDERS: Dictionary = {
	"HUD_TOWER_HP": 3,
	"HUD_HERO_HP": 2,
	"HUD_BOSS_BAR": 3,
	"HUD_BREACHES": 1,
	"HUD_WAVE_PROGRESS": 2,
	"HUD_WAVE_INCOMING": 1,
	"HUD_TOAST_PICKUP_REJECTED": 3,
	"HUD_TOAST_SKILL_LEARNED": 1,
	"SKILL_BUILD_ULTIMATE_NONE": 0,
	"SKILL_BUILD_ULTIMATE": 1,
	"INVENTORY_REPAIR_BUTTON": 0,
	"INVENTORY_REPAIR_COST": 2,
	"MENAGERIE_HAPPINESS_SHORT": 1,
	"MISSION_SELECT_LAUNCH": 0,
	"MISSION_SELECT_CONFIRM_LAUNCH": 0,
	"DIORAMA_HABITAT_COUNT": 1,
	"MAIN_MENU_OVERWRITE_CONFIRM": 1,
	"MAIN_MENU_SLOT_LABEL": 2,
	# 2026-10-04 smoke check: empty states, Lure panel, localized tags.
	"MENAGERIE_ROSTER_EMPTY": 0,
	"MENAGERIE_LURE_HEADER": 0,
	"MENAGERIE_LURE_OWNED": 1,
	"MENAGERIE_LURE_BUTTON": 2,
	"INVENTORY_RECIPES_EMPTY": 0,
	"DEFENSE_ENTRY_FORMAT": 3,
	"DEFENSE_TECH_STATE_UNLOCKED": 0,
	"DEFENSE_TECH_STATE_AVAILABLE": 0,
	"DEFENSE_TECH_STATE_LOCKED": 0,
	"DEFENSE_STRUCTURE_BUILT": 0,
	"DEFENSE_STRUCTURE_UNBUILT": 0,
	"DEFENSE_STRUCTURE_GATE": 1,
	"FORGE_RECIPE_CRAFTABLE": 0,
	"FORGE_RECIPE_MISSING": 0,
	"FORGE_ITEM_SLOTS_FREE": 3,
	"FORGE_RECIPES_EMPTY": 0,
	"FORGE_IMBUE_ITEMS_EMPTY": 0,
	"FORGE_UPGRADES_EMPTY": 0,
	"SKILL_BUILD_SLOT_EMPTY": 0,
	"SKILL_BUILD_PASSIVES_NONE": 0,
	"SKILL_BUILD_PASSIVES": 2,
	"SKILL_BUILD_TAG_LOCKED": 0,
	"SKILL_BUILD_TAG_ACTIVE": 0,
	"TAROT_TAG_LOCKED": 0,
	"TAROT_TAG_EQUIPPED": 0,
	"TAROT_TAG_AVAILABLE": 0,
	"TAROT_TAG_CONFLICT": 1,
	"MAIN_MENU_SLOT_OCCUPIED": 0,
	"MAIN_MENU_SLOT_SAVED_AT": 1,
	"MISSION_SELECT_TIER_TIME": 2,
	"MISSION_SELECT_TIER_UNCLEARED": 0,
	"MISSION_SELECT_NOT_CLEARED": 0,
	"MISSION_SELECT_TIER_SELECTED": 0,
	"MISSION_SELECT_TIER_NORMAL": 0,
	"MISSION_SELECT_TIER_HARD": 0,
	"MISSION_SELECT_TIER_BRUTAL": 0,
	"MISSION_SELECT_TIER_GENERIC": 1,
	"MISSION_SELECT_STEP_OFF": 0,
	"MISSION_SELECT_STEP_LOW": 0,
	"MISSION_SELECT_STEP_HIGH": 0,
	"MISSION_SELECT_MODIFIERS_NONE": 0,
	"MISSION_SELECT_RECAP": 3,
	"HUD_PHASE": 1,
	"HUD_PHASE_TIMER": 2,
	"HUD_PREVIEW_TIER_COUNT": 2,
	"MAIN_MENU_SLOT_EMPTY": 0,
}

## file -> old literals that must no longer appear.
const REMOVED_LITERALS: Dictionary = {
	"res://src/presentation/mission_hud/mission_hud.gd": [
		"\"Tower %d: %d/%d\"", "\"Hero HP: %d/%d\"", "\"BOSS %s: %d/%d\"", "\"Breaches: %d\"",
		"\"Wave: %d/%d\"", "\"Wave incoming: %ds\"", "\"Could not pick up", "\"Skill Learned: %s\"",
	],
	"res://src/gameplay/ui/hero_skill_build_screen/hero_skill_build_screen.gd": [
		"\"Ultimate: ", "\"(empty)\"", "\"[ACTIVE]\"",
	],
	"res://src/gameplay/ui/inventory_screen/inventory_screen.gd": ["text = \"Repair\"", "\"Common %d/%d\""],
	"res://src/gameplay/ui/menagerie_screen/menagerie_screen.gd": ["\"H: %d\""],
	"res://src/gameplay/ui/mission_select_screen/mission_select_screen.gd": ["text = \"Launch\"", "text = \"Confirm Launch\""],
	"res://src/presentation/sanctuary_ui/diorama.gd": ["\"Habitat: %d\""],
	"res://src/gameplay/ui/defense_building_screen/defense_building_screen.gd": [
		"\"UNLOCKED\"", "\"AVAILABLE\"", "gold:%d", "\" gated:%s\"",
	],
	"res://src/gameplay/ui/equipment_forge_screen/equipment_forge_screen.gd": [
		"\"CRAFTABLE\"", "\"MISSING_MATERIALS\"", "slots free)\"",
	],
	"res://src/presentation/mission_hud/planning_cluster.gd": ["label.text = \"%d %s\" % [totals"],
	"res://src/gameplay/ui/tarot_screen/tarot_screen.gd": [
		"\"%s [LOCKED]\"", "\"%s [EQUIPPED]\"", "\"%s [AVAILABLE]\"", "\"%s [CONFLICT: %s]\"",
	],
	"res://src/scenes/main_menu.gd": ["\"This will overwrite Slot", "\"Slot %d", "\"Occupied\"", "\"Empty\""],
	"res://src/gameplay/ui/hero_skill_tree_screen/hero_skill_tree_screen.gd": [
		"\"[LOCKED]\"", "\"[UNLOCKED]\"", "\"(locked out:", "\"Overflow\"", "\"Minor\"", "\"Opener\"",
		"archetype.capitalize()",
	],
}


## Parses strings.csv (header keys,en) honouring double-quoted values.
func _load_rows() -> Dictionary:
	var rows: Dictionary = {}
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	if file == null:
		return rows
	var first: bool = true
	while not file.eof_reached():
		var cols: PackedStringArray = file.get_csv_line(",")
		if first:
			first = false
			continue
		if cols.size() >= 2 and not cols[0].is_empty():
			rows[cols[0]] = cols[1]
	return rows


func _count_placeholders(value: String) -> int:
	var count: int = 0
	var i: int = 0
	while i < value.length() - 1:
		if value[i] == "%":
			var nxt: String = value[i + 1]
			if nxt == "%":
				i += 2
				continue
			if nxt == "d" or nxt == "s" or nxt == "f":
				count += 1
			elif nxt == "." and i + 3 < value.length() and value[i + 3] == "f":
				count += 1  # precision float, e.g. %.1f
		i += 1
	return count


func test_every_added_key_exists_with_english_value() -> void:
	var rows: Dictionary = _load_rows()
	for key: String in EXPECTED_PLACEHOLDERS:
		assert_bool(rows.has(key)).override_failure_message("missing key %s" % key).is_true()
		assert_str(String(rows.get(key, ""))).override_failure_message("empty value for %s" % key).is_not_empty()


func test_placeholder_counts_match_call_sites() -> void:
	var rows: Dictionary = _load_rows()
	for key: String in EXPECTED_PLACEHOLDERS:
		var value: String = String(rows.get(key, ""))
		assert_int(_count_placeholders(value)).override_failure_message(
			"placeholder count mismatch for %s ('%s')" % [key, value]
		).is_equal(EXPECTED_PLACEHOLDERS[key] as int)


func test_scripts_no_longer_contain_old_literals() -> void:
	for path: String in REMOVED_LITERALS:
		var source: String = FileAccess.get_file_as_string(path)
		assert_str(source).override_failure_message("cannot read %s" % path).is_not_empty()
		for literal: String in REMOVED_LITERALS[path]:
			assert_bool(source.contains(literal)).override_failure_message(
				"%s still contains %s" % [path, literal]
			).is_false()


func test_scripts_reference_each_key_via_tr() -> void:
	var combined: String = ""
	for path: String in REMOVED_LITERALS:
		combined += FileAccess.get_file_as_string(path)
	for key: String in EXPECTED_PLACEHOLDERS:
		assert_bool(combined.contains("tr(\"%s\")" % key)).override_failure_message(
			"no tr(\"%s\") call in scope files" % key
		).is_true()
