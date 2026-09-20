extends GdUnitTestSuite

## Content-integrity tests for the authored rune values (rune-variety spec
## §4, AC-1..AC-6). The EXPECTED table below is the spec's authoritative
## value list; editing a rune's value in data must be a deliberate edit here too.

const EXPECTED: Dictionary[StringName, Dictionary] = {
	&"rune_triad_line": {&"physical_attack": 5.0},
	&"rune_quad_line": {&"attack_range": 24.0, &"physical_attack": 2.5},
	&"rune_l_corner": {&"magic_attack": 7.5},
	&"rune_cross_plus": {&"additive_bonus_total": 0.05},
	&"rune_apex_predator": {&"crit_chance": 0.04, &"crit_multiplier": 0.10},
	&"rune_hunters_pace": {&"move_speed": 15.0, &"attack_range": 12.0},
	&"rune_swift_current": {&"move_speed": 20.0, &"cdr": 0.02},
	&"rune_reckless_onslaught": {&"physical_attack": 6.25, &"crit_chance": 0.03},
	&"rune_cautious_advance": {&"armor": 15.0, &"move_speed": 5.0},
	&"rune_golden_ticket": {&"luck": 0.08},
	&"rune_bountiful_harvest": {&"luck": 0.06, &"max_hp": 50.0},
	&"rune_lucky_charm": {&"luck": 0.04, &"crit_chance": 0.03},
	&"rune_grinding_gauntlet": {&"max_hp": 75.0, &"physical_attack": 3.75},
	&"rune_grim_resolve": {&"max_hp": 100.0, &"lifesteal": 0.01},
	&"rune_iron_resolve": {&"armor": 20.0, &"elemental_resist_fire": 0.045, &"elemental_resist_frost": 0.045},
	&"rune_measured_pace": {&"cdr": 0.03, &"armor": 10.0},
	&"rune_steady_hand": {&"crit_chance": 0.04, &"attack_range": 16.0},
	&"rune_menagerie_aurora_stag": {&"additive_bonus_total": 0.08},
	&"rune_menagerie_duskfang_fox": {&"crit_chance": 0.05, &"move_speed": 10.0},
	&"rune_menagerie_emberwing_moth": {&"magic_attack": 7.5, &"elemental_resist_fire": 0.06},
	&"rune_menagerie_glimmer_hare": {&"move_speed": 10.0, &"luck": 0.03},
	&"rune_menagerie_mossback_toad": {&"armor": 10.0, &"elemental_resist_frost": 0.045},
}

const WILDCARDS: Array[StringName] = [&"rune_cross_plus", &"rune_menagerie_aurora_stag"]

## Loose per-stat ceilings for a single rune (tripwire for a stray extra zero).
const MAX_FLAT: Dictionary[StringName, float] = {
	&"max_hp": 150.0, &"armor": 40.0, &"physical_attack": 15.0, &"magic_attack": 15.0,
	&"move_speed": 40.0, &"attack_range": 40.0, &"crit_chance": 0.10,
	&"crit_multiplier": 0.25, &"luck": 0.15, &"cdr": 0.08, &"lifesteal": 0.04,
	&"elemental_resist_fire": 0.12, &"elemental_resist_frost": 0.12,
}


func test_there_are_exactly_22_expected_runes() -> void:
	assert_int(EXPECTED.size()).is_equal(22)


func test_every_rune_resolves_to_exactly_its_spec_value() -> void:
	for rune_id: StringName in EXPECTED:
		var expected: Dictionary = EXPECTED[rune_id]
		var actual: Dictionary = EquipmentForge.resolve_rune_stat_delta(rune_id)
		assert_int(actual.size()).override_failure_message("%s: key count" % rune_id).is_equal(expected.size())
		for stat: StringName in expected:
			assert_bool(actual.has(stat)).override_failure_message("%s missing %s" % [rune_id, stat]).is_true()
			assert_float(float(actual[stat])).override_failure_message("%s.%s" % [rune_id, stat]).is_equal_approx(float(expected[stat]), 0.0001)


func test_only_the_two_wildcards_use_additive_bonus_total() -> void:
	for rune_id: StringName in EXPECTED:
		var actual: Dictionary = EquipmentForge.resolve_rune_stat_delta(rune_id)
		assert_bool(actual.has(&"additive_bonus_total")).override_failure_message(rune_id).is_equal(WILDCARDS.has(rune_id))


func test_all_stat_keys_are_real_and_values_within_ceilings() -> void:
	for rune_id: StringName in EXPECTED:
		var actual: Dictionary = EquipmentForge.resolve_rune_stat_delta(rune_id)
		for stat: Variant in actual:
			var key: StringName = StringName(stat)
			var value: float = float(actual[stat])
			assert_float(value).override_failure_message("%s.%s must be > 0" % [rune_id, key]).is_greater(0.0)
			if key == &"additive_bonus_total":
				assert_float(value).is_between(0.02, 0.08)
			else:
				assert_bool(EquipmentBonuses.FAN_OUT_STATS.has(key)).override_failure_message("%s: unknown stat '%s'" % [rune_id, key]).is_true()
				assert_float(value).override_failure_message("%s.%s=%s exceeds ceiling" % [rune_id, key, value]).is_less_equal(MAX_FLAT[key])


func test_every_rune_id_is_known_to_the_forge() -> void:
	var forge: EquipmentForge = EquipmentForge.new()
	for rune_id: StringName in EXPECTED:
		assert_bool(forge.is_rune_id_known(rune_id)).override_failure_message(rune_id).is_true()
	forge.free()


func test_no_registered_rune_is_missing_from_the_expected_table() -> void:
	var registered: Array[StringName] = []
	for shape_id: String in Constellation.SHAPE_N:
		registered.append(StringName("rune_%s" % shape_id))
	for card: TarotCardResource in GGameDataRegistry.get_all_tarot_cards().values():
		if card.linked_rune_id != &"":
			registered.append(card.linked_rune_id)
	for recipe: SacrificeRecipeResource in GGameDataRegistry.get_all_sacrifice_recipes().values():
		registered.append(recipe.rune_id)
	assert_int(registered.size()).is_equal(EXPECTED.size())
	for rune_id: StringName in registered:
		assert_bool(EXPECTED.has(rune_id)).override_failure_message("%s not in EXPECTED" % rune_id).is_true()


func test_themed_rune_adds_only_its_targeted_stat_on_top_of_the_item() -> void:
	var item_only: Dictionary = {"item_id": "iron_helm", "stat_overrides": {&"max_hp": 10.0, &"armor": 4.0}, "imbued_runes": [], "rune_slot_count": 1}
	var with_rune: Dictionary = item_only.duplicate(true)
	with_rune["imbued_runes"] = ["rune_golden_ticket"]
	var before: Dictionary = EquipmentBonuses.compute([item_only])
	var after: Dictionary = EquipmentBonuses.compute([with_rune])
	assert_float(after["flat"][&"luck"]).is_equal_approx(0.08, 0.0001)
	assert_float(after["flat"][&"max_hp"]).is_equal_approx(before["flat"][&"max_hp"], 0.0001)
	assert_float(after["flat"][&"armor"]).is_equal_approx(before["flat"][&"armor"], 0.0001)
	assert_bool((after["additive"] as Dictionary).is_empty()).is_true()
