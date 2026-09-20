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


func test_constellation_rune_resolves_to_fixed_additive_bonus() -> void:
	var shape_id: String = Constellation.SHAPE_N.keys()[0]
	var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(StringName("rune_%s" % shape_id))
	assert_dict(delta).contains_key_value("additive_bonus_total", EquipmentForge.RUNE_ADDITIVE_BONUS)
	assert_int(delta.size()).is_equal(1)


func test_tarot_rune_resolves_to_fixed_additive_bonus() -> void:
	var cards: Dictionary = GGameDataRegistry.get_all_tarot_cards()
	if cards.is_empty():
		return
	var card: TarotCardResource = cards.values()[0]
	var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(card.linked_rune_id)
	assert_dict(delta).contains_key_value("additive_bonus_total", EquipmentForge.RUNE_ADDITIVE_BONUS)


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
