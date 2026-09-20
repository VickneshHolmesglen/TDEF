extends GdUnitTestSuite

## Unit tests for EquipmentForge.resolve_rune_stat_delta() (equipment-stats-
## wiring spec §3.4, AC-4/AC-5/AC-7).

var _forge: EquipmentForge


func before_test() -> void:
	_forge = EquipmentForge.new()


func after_test() -> void:
	if _forge != null and is_instance_valid(_forge):
		_forge.free()
	_forge = null


func test_constellation_themed_rune_resolves_to_flat_stats() -> void:
	var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(&"rune_triad_line")
	assert_int(delta.size()).is_equal(1)
	assert_float(float(delta[&"physical_attack"])).is_equal_approx(5.0, 0.0001)
	assert_bool(delta.has("additive_bonus_total")).is_false()


func test_constellation_wildcard_rune_resolves_to_additive_only() -> void:
	var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(&"rune_cross_plus")
	assert_int(delta.size()).is_equal(1)
	assert_float(float(delta[&"additive_bonus_total"])).is_equal_approx(EquipmentForge.RUNE_ADDITIVE_BONUS, 0.0001)


func test_tarot_rune_resolves_to_card_rune_stat_delta_or_fallback() -> void:
	var cards: Dictionary = GGameDataRegistry.get_all_tarot_cards()
	if cards.is_empty():
		return
	var card: TarotCardResource = cards.values()[0]
	var expected: Dictionary = card.rune_stat_delta if not card.rune_stat_delta.is_empty() else {"additive_bonus_total": EquipmentForge.RUNE_ADDITIVE_BONUS}
	var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(card.linked_rune_id)
	assert_int(delta.size()).is_equal(expected.size())
	for key: Variant in expected:
		assert_float(float(delta[key])).is_equal_approx(float(expected[key]), 0.0001)


func test_fallback_helper_returns_generic_bonus_for_empty_delta() -> void:
	var delta: Dictionary = EquipmentForge._rune_delta_or_fallback({})
	assert_int(delta.size()).is_equal(1)
	assert_float(float(delta["additive_bonus_total"])).is_equal_approx(EquipmentForge.RUNE_ADDITIVE_BONUS, 0.0001)


func test_fallback_helper_passes_through_and_copies_nonempty_delta() -> void:
	var source: Dictionary = {&"armor": 10.0}
	var delta: Dictionary = EquipmentForge._rune_delta_or_fallback(source)
	assert_float(float(delta[&"armor"])).is_equal_approx(10.0, 0.0001)
	delta[&"armor"] = 99.0
	assert_float(float(source[&"armor"])).is_equal_approx(10.0, 0.0001)


func test_menagerie_rune_resolves_to_recipe_stat_delta() -> void:
	var recipes: Dictionary = GGameDataRegistry.get_all_sacrifice_recipes()
	if recipes.is_empty():
		return
	var recipe: SacrificeRecipeResource = recipes.values()[0]
	var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(recipe.rune_id)
	assert_int(delta.size()).is_equal(recipe.stat_delta.size())
	for key: StringName in recipe.stat_delta:
		assert_float(float(delta[key])).is_equal_approx(recipe.stat_delta[key], 0.0001)


func test_unknown_rune_id_returns_empty_dict() -> void:
	assert_dict(EquipmentForge.resolve_rune_stat_delta(&"no_such_rune_xyz")).is_empty()


func test_empty_rune_id_returns_empty_dict() -> void:
	assert_dict(EquipmentForge.resolve_rune_stat_delta(&"")).is_empty()


func test_resolution_agrees_with_is_rune_id_known() -> void:
	var ids: Array[StringName] = [&"no_such_rune_xyz", &""]
	for shape_id: String in Constellation.SHAPE_N:
		ids.append(StringName("rune_%s" % shape_id))
	for card: TarotCardResource in GGameDataRegistry.get_all_tarot_cards().values():
		ids.append(card.linked_rune_id)
	for recipe: SacrificeRecipeResource in GGameDataRegistry.get_all_sacrifice_recipes().values():
		ids.append(recipe.rune_id)
	for id: StringName in ids:
		var known: bool = _forge.is_rune_id_known(id)
		var resolved: bool = not EquipmentForge.resolve_rune_stat_delta(id).is_empty()
		# A known Menagerie rune may legitimately have an empty authored
		# stat_delta, so only assert one direction: non-empty implies known.
		if resolved:
			assert_bool(known).is_true()
		if not known:
			assert_bool(resolved).is_false()
