## Unit tests for MonsterResource.validate() (S4-02, ADR-0009).
extends GdUnitTestSuite


func _make_valid_standard() -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = &"goblin"
	res.display_name = "Goblin"
	res.tier = 0
	res.base_hp = 80.0
	res.base_speed = 1.6
	return res


func test_validate_empty_monster_id_returns_error() -> void:
	var res := _make_valid_standard()
	res.monster_id = &""
	var errors: Array[String] = res.validate()
	assert_array(errors).contains("monster_id must not be empty")


func test_validate_zero_base_hp_returns_error() -> void:
	var res := _make_valid_standard()
	res.base_hp = 0.0
	var errors: Array[String] = res.validate()
	assert_bool(errors.any(func(e: String) -> bool: return e.begins_with("base_hp must be > 0"))).is_true()


func test_validate_negative_base_hp_returns_error() -> void:
	var res := _make_valid_standard()
	res.base_hp = -5.0
	var errors: Array[String] = res.validate()
	assert_bool(errors.any(func(e: String) -> bool: return e.begins_with("base_hp must be > 0"))).is_true()


func test_validate_zero_base_speed_returns_error() -> void:
	var res := _make_valid_standard()
	res.base_speed = 0.0
	var errors: Array[String] = res.validate()
	assert_bool(errors.any(func(e: String) -> bool: return e.begins_with("base_speed must be > 0"))).is_true()


func test_validate_tier_out_of_range_returns_error() -> void:
	var res := _make_valid_standard()
	res.tier = 5
	var errors: Array[String] = res.validate()
	assert_bool(errors.any(func(e: String) -> bool: return e.begins_with("tier must be 0/1/2"))).is_true()


func test_validate_boss_tier_missing_base_damage_returns_error() -> void:
	var res := _make_valid_standard()
	res.tier = 2
	res.base_damage = 0.0
	res.base_attack_interval = 1.0
	res.boss_attack_range_cells = 3
	var errors: Array[String] = res.validate()
	assert_array(errors).contains("BOSS tier requires base_damage > 0")


func test_validate_boss_tier_missing_attack_interval_returns_error() -> void:
	var res := _make_valid_standard()
	res.tier = 2
	res.base_damage = 10.0
	res.base_attack_interval = 0.0
	res.boss_attack_range_cells = 3
	var errors: Array[String] = res.validate()
	assert_array(errors).contains("BOSS tier requires base_attack_interval > 0")


func test_validate_boss_tier_missing_attack_range_returns_error() -> void:
	var res := _make_valid_standard()
	res.tier = 2
	res.base_damage = 10.0
	res.base_attack_interval = 1.0
	res.boss_attack_range_cells = 0
	var errors: Array[String] = res.validate()
	assert_array(errors).contains("BOSS tier requires boss_attack_range_cells > 0")


func test_validate_fully_valid_standard_tier_returns_empty_array() -> void:
	var res := _make_valid_standard()
	var errors: Array[String] = res.validate()
	assert_array(errors).is_empty()


func test_validate_fully_valid_boss_tier_returns_empty_array() -> void:
	var res := _make_valid_standard()
	res.tier = 2
	res.base_damage = 25.0
	res.base_attack_interval = 2.0
	res.boss_attack_range_cells = 4
	var errors: Array[String] = res.validate()
	assert_array(errors).is_empty()


func test_validate_negative_armor_is_invalid() -> void:
	var res := _make_valid_standard()
	res.armor = -5.0
	var errors: Array[String] = res.validate()
	assert_bool(errors.is_empty()).is_false()


func test_validate_zero_armor_is_valid() -> void:
	var res := _make_valid_standard()
	res.armor = 0.0
	var errors: Array[String] = res.validate()
	assert_bool(errors.is_empty()).is_true()


func test_validate_evasion_above_one_hundred_is_invalid() -> void:
	var res := _make_valid_standard()
	res.evasion = 100.1
	var errors: Array[String] = res.validate()
	assert_bool(errors.is_empty()).is_false()


func test_validate_evasion_below_zero_is_invalid() -> void:
	var res := _make_valid_standard()
	res.evasion = -0.1
	var errors: Array[String] = res.validate()
	assert_bool(errors.is_empty()).is_false()


func test_validate_evasion_within_range_is_valid() -> void:
	var res := _make_valid_standard()
	res.evasion = 50.0
	var errors: Array[String] = res.validate()
	assert_bool(errors.is_empty()).is_true()
