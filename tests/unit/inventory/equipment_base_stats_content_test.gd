extends GdUnitTestSuite

## Content-integrity tests for the authored equipment base_stats (equipment-
## stats-wiring follow-up, 2026-09-20). Guards against a typo'd stat key
## (silently inert per Hero's "unknown = inert" convention), a missing entry,
## or a value that would break the stat budget.

const ITEMS_DIR: String = "res://assets/data/items/"

## Loose per-stat ceilings for a SINGLE item (top quality tier). Not the
## design budget itself -- a tripwire so a stray extra zero is caught.
const MAX_PER_ITEM: Dictionary[StringName, float] = {
	&"max_hp": 300.0, &"armor": 60.0, &"physical_attack": 20.0, &"magic_attack": 20.0,
	&"move_speed": 40.0, &"attack_range": 60.0, &"crit_chance": 0.15,
	&"crit_multiplier": 0.5, &"luck": 0.15, &"cdr": 0.10, &"lifesteal": 0.05,
	&"elemental_resist_fire": 0.20, &"elemental_resist_frost": 0.20,
}


func _equipment_items() -> Array[ItemDefinitionResource]:
	var result: Array[ItemDefinitionResource] = []
	for file: String in DirAccess.get_files_at(ITEMS_DIR):
		if not file.ends_with(".tres"):
			continue
		var item: ItemDefinitionResource = load(ITEMS_DIR + file) as ItemDefinitionResource
		if item != null and item.equipment_category != "":
			result.append(item)
	return result


func test_all_45_equipment_items_have_authored_base_stats() -> void:
	var items: Array[ItemDefinitionResource] = _equipment_items()
	assert_int(items.size()).is_equal(45)
	for item: ItemDefinitionResource in items:
		assert_bool(item.base_stats.is_empty()).override_failure_message("%s has empty base_stats" % item.item_id).is_false()


func test_every_stat_key_is_a_real_hero_stat_and_within_ceiling() -> void:
	for item: ItemDefinitionResource in _equipment_items():
		for stat: StringName in item.base_stats:
			assert_bool(Hero.EQUIPMENT_FAN_OUT_STATS.has(stat)).override_failure_message("%s: unknown stat '%s'" % [item.item_id, stat]).is_true()
			var value: float = item.base_stats[stat]
			assert_float(value).override_failure_message("%s.%s must be > 0" % [item.item_id, stat]).is_greater(0.0)
			assert_float(value).override_failure_message("%s.%s=%s exceeds ceiling" % [item.item_id, stat, value]).is_less_equal(MAX_PER_ITEM[stat])


func test_non_equipment_items_are_untouched() -> void:
	for file: String in DirAccess.get_files_at(ITEMS_DIR):
		if not file.ends_with(".tres"):
			continue
		var item: ItemDefinitionResource = load(ITEMS_DIR + file) as ItemDefinitionResource
		if item != null and item.equipment_category == "":
			assert_bool(item.base_stats.is_empty()).override_failure_message("%s is not equipment but has base_stats" % item.item_id).is_true()
