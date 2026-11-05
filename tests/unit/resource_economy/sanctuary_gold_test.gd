extends GdUnitTestSuite

## Sanctuary gold (design/quick-specs/sanctuary-gold-2026-11-05.md,
## resource-economy.md Rule 11): held mission gold banks at mission end at the
## conversion rate, Treasury techs raise the rate, the Forge spends it.
## Handlers are called directly on a fresh, tree-less SanctuaryGold so no
## autoload state or EventBus wiring is involved.

var _gold: SanctuaryGold
var _saved_mission_gold: int = 0


func before_test() -> void:
	_gold = SanctuaryGold.new()
	_saved_mission_gold = GMissionEconomy._gold_balance


func after_test() -> void:
	GMissionEconomy._gold_balance = _saved_mission_gold
	_gold.free()


func test_sanctuary_gold_conversion_rate_rises_per_treasury_tech() -> void:
	assert_float(SanctuaryGold.conversion_rate_for(0)).is_equal_approx(0.25, 0.0001)
	assert_float(SanctuaryGold.conversion_rate_for(1)).is_equal_approx(0.35, 0.0001)
	assert_float(SanctuaryGold.conversion_rate_for(3)).is_equal_approx(0.55, 0.0001)
	assert_float(SanctuaryGold.conversion_rate_for(9)).is_equal_approx(0.55, 0.0001)


func test_sanctuary_gold_banked_amount_floors_and_ignores_debt() -> void:
	assert_int(SanctuaryGold.banked_amount(301, 0.25)).is_equal(75)
	assert_int(SanctuaryGold.banked_amount(-20, 0.55)).is_equal(0)


func test_sanctuary_gold_forge_prices() -> void:
	assert_int(SanctuaryGold.craft_cost(1)).is_equal(80)
	assert_int(SanctuaryGold.craft_cost(4)).is_equal(320)
	assert_int(SanctuaryGold.craft_cost(5)).is_equal(320)
	assert_int(SanctuaryGold.rune_slot_cost(0)).is_equal(250)
	assert_int(SanctuaryGold.rune_slot_cost(2)).is_equal(750)


func test_sanctuary_gold_mission_end_banks_held_gold_once() -> void:
	# Arrange
	GMissionEconomy._gold_balance = 200
	_gold._on_mission_launched("m", PackedStringArray(), 1)
	# Act
	_gold._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)
	_gold._on_mission_phase_changed("MISSION_COMPLETE", "MISSION_COMPLETE", 0.0)
	# Assert: 200 x rate, banked once
	assert_int(_gold.get_balance()).is_equal(SanctuaryGold.banked_amount(200, _gold.conversion_rate()))


func test_sanctuary_gold_defeat_also_banks_but_mid_mission_phases_do_not() -> void:
	# Arrange
	GMissionEconomy._gold_balance = 100
	_gold._on_mission_launched("m", PackedStringArray(), 1)
	# Act
	_gold._on_mission_phase_changed("SCOUT", "INTERMISSION", 0.0)
	assert_int(_gold.get_balance()).is_equal(0)
	_gold._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)
	# Assert
	assert_int(_gold.get_balance()).is_equal(SanctuaryGold.banked_amount(100, _gold.conversion_rate()))


func test_sanctuary_gold_spend_rejects_when_short_and_spends_when_able() -> void:
	# Arrange
	_gold.add(50, &"test")
	# Act / Assert
	assert_bool(_gold.spend(60, &"forge_craft")).is_false()
	assert_int(_gold.get_balance()).is_equal(50)
	assert_bool(_gold.spend(30, &"forge_craft")).is_true()
	assert_int(_gold.get_balance()).is_equal(20)


func test_sanctuary_gold_save_round_trip_and_malformed_data() -> void:
	# Arrange
	_gold.add(123, &"test")
	var data: Dictionary = _gold.get_save_data()
	_gold.reset_to_defaults()
	# Act / Assert
	assert_bool(_gold.restore_save_data(data)).is_true()
	assert_int(_gold.get_balance()).is_equal(123)
	assert_bool(_gold.restore_save_data({"balance": -5})).is_false()
	assert_bool(_gold.restore_save_data({})).is_false()


func test_sanctuary_gold_treasury_tech_data_matches_ids() -> void:
	for tech_id: StringName in SanctuaryGold.TREASURY_TECH_IDS:
		var node: TechNodeResource = GGameDataRegistry.get_all_tech_nodes().get(tech_id)
		assert_object(node).is_not_null()
		assert_str(node.tech_category).is_equal("economy_tech")
		assert_array(node.validate()).is_empty()
