extends GdUnitTestSuite

## Temperament effects reach their payout points (menagerie-rehoming spec,
## Rule 3): Scholar -> Hero XP, Forager -> drop quantity, Hoarder -> banked
## Sanctuary gold, Shardbound -> Ascension shards. Each test puts one 5-star
## HABITAT creature (+8%) into the GMenagerie autoload and restores it after.

var _saved_creatures: Array[CreatureInstance] = []


func before_test() -> void:
	_saved_creatures = GMenagerie._creatures.duplicate()
	GMenagerie._creatures.clear()


func after_test() -> void:
	GMenagerie._creatures = _saved_creatures


func _habitat(trait_id: StringName, grade: int = 5) -> void:
	var creature := CreatureInstance.new()
	creature.creature_id = 900000 + GMenagerie._creatures.size()
	creature.species = &"aurora_stag"
	creature.state = CreatureInstance.CreatureState.HABITAT
	creature.trait_id = trait_id
	creature.grade = grade
	GMenagerie._creatures.append(creature)


func test_temperament_scholar_raises_hero_xp() -> void:
	# Arrange
	var hero := Hero.new()
	add_child(hero)
	_habitat(Temperament.SCHOLAR)
	var before: int = hero._current_xp
	# Act
	hero._grant_xp(50)
	# Assert: 50 x 1.08 (stays under the level-2 threshold)
	assert_int(hero._current_xp - before).is_equal(54)
	remove_child(hero)
	hero.free()


func test_temperament_forager_raises_drop_quantity_of_its_rarity() -> void:
	# Arrange: 5-star Common Forager; goblin_hide is a Common material
	_habitat(Temperament.FORAGER_COMMON)
	var re := ResourceEconomy.new()
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"goblin_hide")
	# Act / Assert
	assert_str(definition.rarity).is_equal("Common")
	assert_float(re._forager_bonus(&"goblin_hide")).is_equal_approx(0.08, 0.0001)
	assert_int(ResourceEconomy._compute_drop_quantity(25, 1.0 * (1.0 + re._forager_bonus(&"goblin_hide")), 1.0, 1)).is_equal(27)
	re.free()


func test_temperament_hoarder_raises_banked_gold() -> void:
	# Arrange
	_habitat(Temperament.HOARDER)
	var gold := SanctuaryGold.new()
	var saved_mission_gold: int = GMissionEconomy._gold_balance
	GMissionEconomy._gold_balance = 400
	# Act
	gold._on_mission_launched("m", PackedStringArray(), 1)
	gold._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)
	# Assert: floor(400 x rate x 1.08)
	assert_int(gold.get_balance()).is_equal(SanctuaryGold.banked_amount(400, gold.conversion_rate() * 1.08))
	assert_int(gold.get_balance()).is_greater(SanctuaryGold.banked_amount(400, gold.conversion_rate()))
	GMissionEconomy._gold_balance = saved_mission_gold
	gold.free()


func test_temperament_shardbound_raises_ascension_shards() -> void:
	# Arrange
	_habitat(Temperament.SHARDBOUND)
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.ascension_shards_awarded)
	var saved_held: int = GMissionSelect._held_shards
	GMissionSelect._held_shards = 0
	var tier: int = DifficultyRewards.BRUTAL_TIER + 5
	var base: int = AscensionRewards.shards_for_victory(tier, false)
	# Act
	GMissionSelect._award_ascension_shards(tier, false)
	# Assert
	assert_int((spy.emissions["ascension_shards_awarded"] as Array)[0][0]).is_equal(roundi(base * 1.08))
	spy.disconnect_all()
	var shard_count: int = GInventory.count_by_material_id(AscensionRewards.SHARD_ITEM_ID)
	GInventory.consume_by_material_id(AscensionRewards.SHARD_ITEM_ID, mini(shard_count, roundi(base * 1.08)))
	GMissionSelect._held_shards = saved_held
