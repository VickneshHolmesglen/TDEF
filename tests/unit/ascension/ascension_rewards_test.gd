## Ascension rewards (design/quick-specs/ascension-rewards-2026-11-03.md):
## the pure reward rules, and the authored data (shard item, Ascendant set,
## Ascension Tarot cards).
extends GdUnitTestSuite

const ASCENDANT_ITEMS: Array[StringName] = [
	&"ascendant_blade", &"ascendant_aegis", &"ascendant_crown", &"ascendant_cuirass", &"ascendant_grips",
	&"ascendant_greaves", &"ascendant_treads", &"ascendant_pendant", &"ascendant_band",
]


func test_ascension_rewards_shards_pay_only_on_ascension() -> void:
	assert_int(AscensionRewards.shards_for_victory(3, true)).is_equal(0)  # Brutal
	assert_int(AscensionRewards.shards_for_victory(1, true)).is_equal(0)


func test_ascension_rewards_first_clear_adds_bounty_to_run_reward() -> void:
	assert_int(AscensionRewards.shards_for_victory(5, true)).is_equal(24)   # A2: 20 + 4
	assert_int(AscensionRewards.shards_for_victory(5, false)).is_equal(4)
	assert_int(AscensionRewards.shards_for_victory(18, true)).is_equal(180)  # A15: 150 + 30


func test_ascension_rewards_extra_rune_slot_cost_steps_then_caps() -> void:
	assert_int(AscensionRewards.extra_rune_slot_cost(0)).is_equal(40)
	assert_int(AscensionRewards.extra_rune_slot_cost(1)).is_equal(120)
	assert_int(AscensionRewards.extra_rune_slot_cost(2)).is_equal(-1)
	assert_int(AscensionRewards.extra_rune_slot_cost(-1)).is_equal(-1)


func test_ascension_rewards_rim_level_from_best_rank() -> void:
	assert_int(AscensionRewards.rim_level(0)).is_equal(0)
	assert_int(AscensionRewards.rim_level(4)).is_equal(0)
	assert_int(AscensionRewards.rim_level(5)).is_equal(1)
	assert_int(AscensionRewards.rim_level(10)).is_equal(2)
	assert_int(AscensionRewards.rim_level(15)).is_equal(3)


## Rarity "" so a rarity-keyed cost ("32 Rare") can never eat shards.
func test_ascension_rewards_shard_is_a_material_outside_rarity_costs() -> void:
	var shard: ItemDefinitionResource = GGameDataRegistry.get_item_definition(AscensionRewards.SHARD_ITEM_ID)
	assert_object(shard).is_not_null()
	assert_str(String(shard.item_type)).is_equal("Material")
	assert_str(shard.rarity).is_equal("")


func test_ascension_rewards_ascendant_set_covers_every_slot_at_tier_5() -> void:
	var slots: Dictionary = {}
	for item_id: StringName in ASCENDANT_ITEMS:
		var item: ItemDefinitionResource = GGameDataRegistry.get_item_definition(item_id)
		assert_object(item).is_not_null()
		slots[item.equipment_category] = true
		var recipe: EquipmentRecipeResource = GGameDataRegistry.get_equipment_recipe(StringName("recipe_%s" % item_id))
		assert_object(recipe).is_not_null()
		assert_int(recipe.quality_tier).is_equal(5)
		assert_array(recipe.validate()).is_empty()
		assert_bool(recipe.inputs.has(AscensionRewards.SHARD_ITEM_ID)).is_true()
		assert_str(String(recipe.tech_prerequisite)).is_equal("tech_production_4")
	assert_int(slots.size()).is_equal(EquipmentRecipeResource.RUNE_SLOT_COUNT_FOR_SLOT.size())


func test_ascension_rewards_ascendant_set_costs_2000_shards() -> void:
	var total: int = 0
	for item_id: StringName in ASCENDANT_ITEMS:
		total += GGameDataRegistry.get_equipment_recipe(StringName("recipe_%s" % item_id)).inputs[AscensionRewards.SHARD_ITEM_ID] as int
	assert_int(total).is_equal(2000)


func test_ascension_rewards_tarot_cards_unlock_at_ranks_3_6_10() -> void:
	var expected: Dictionary = {&"dawnbreaker": 3, &"final_judgement": 6, &"worlds_weight": 10}
	for card_id: StringName in expected:
		var card: TarotCardResource = GGameDataRegistry.get_tarot_card(card_id)
		assert_object(card).is_not_null()
		assert_int(card.unlock_ascension_rank).is_equal(expected[card_id])
		assert_bool(card.validate()).is_true()


## Found live 2026-11-03: capitalize() dropped the apostrophe ("Worlds Weight").
func test_ascension_rewards_card_display_name_uses_string_override() -> void:
	assert_str(TarotCardResource.display_name(&"worlds_weight")).is_equal("World's Weight")
	assert_str(TarotCardResource.display_name(&"hunters_pace")).is_equal("Hunter's Pace")
	assert_str(TarotCardResource.display_name(&"swift_current")).is_equal("Swift Current")  # fallback


func test_ascension_rewards_quality_tier_6_is_rejected() -> void:
	var recipe := EquipmentRecipeResource.new()
	recipe.recipe_id = &"recipe_test"
	recipe.output_slot = "weapon"
	recipe.output_item_id = &"x"
	recipe.rune_slot_count = 2
	recipe.quality_tier = 6
	assert_array(recipe.validate()).is_not_empty()
