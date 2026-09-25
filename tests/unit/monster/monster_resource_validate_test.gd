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
	res.hero_attack_windup_seconds = 1.0
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


# ---------------------------------------------------------------------------
# Hero attack settings (hero-damage spec section 4.1, AC-1)
# ---------------------------------------------------------------------------

func _make_valid_elite_attacker() -> MonsterResource:
	var res := _make_valid_standard()
	res.tier = 1
	res.base_damage = 30.0
	res.base_attack_interval = 2.5
	res.boss_attack_range_cells = 2
	res.hero_attack_windup_seconds = 0.9
	return res


func test_validate_valid_elite_attacker_returns_empty_array() -> void:
	assert_array(_make_valid_elite_attacker().validate()).is_empty()


func test_validate_elite_with_zero_base_damage_is_a_valid_non_attacker() -> void:
	var res := _make_valid_standard()
	res.tier = 1
	assert_array(res.validate()).is_empty()


func test_validate_elite_attacker_requires_interval_range_and_windup() -> void:
	var no_interval := _make_valid_elite_attacker()
	no_interval.base_attack_interval = 0.0
	assert_array(no_interval.validate()).contains("ELITE attacker requires base_attack_interval > 0")
	var no_range := _make_valid_elite_attacker()
	no_range.boss_attack_range_cells = 0
	assert_array(no_range.validate()).contains("ELITE attacker requires boss_attack_range_cells > 0")
	var no_windup := _make_valid_elite_attacker()
	no_windup.hero_attack_windup_seconds = 0.0
	assert_array(no_windup.validate()).contains("ELITE attacker requires hero_attack_windup_seconds > 0")


func test_validate_boss_tier_missing_hero_windup_returns_error() -> void:
	var res := _make_valid_standard()
	res.tier = 2
	res.base_damage = 10.0
	res.base_attack_interval = 1.0
	res.boss_attack_range_cells = 3
	res.hero_attack_windup_seconds = 0.0
	assert_array(res.validate()).contains("BOSS tier requires hero_attack_windup_seconds > 0")


func test_validate_standard_with_base_damage_is_rejected() -> void:
	var res := _make_valid_standard()
	res.base_damage = 5.0
	assert_array(res.validate()).contains("STANDARD tier must have base_damage == 0")


func test_validate_negative_windup_is_rejected() -> void:
	var res := _make_valid_standard()
	res.hero_attack_windup_seconds = -0.5
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("hero_attack_windup_seconds must not be negative"))).is_true()


func test_shipped_monsters_all_validate_and_attackers_carry_the_authored_values() -> void:
	# id -> [tier, base_damage, base_attack_interval, boss_attack_range_cells, hero_attack_windup_seconds]
	var expected: Dictionary = {
		&"bog_lurker_elite": [1, 30.0, 2.5, 2, 0.9],
		&"forest_troll_elite": [1, 45.0, 3.0, 2, 1.0],
		&"iron_colossus_elite": [1, 70.0, 4.0, 2, 1.2],
		&"goblin_warlord_boss": [2, 60.0, 3.0, 3, 1.0],
		&"rift_sentinel_boss": [2, 20.0, 2.2, 2, 0.8],
	}
	var all: Dictionary = GGameDataRegistry.get_all_monster_resources()
	for id: StringName in all:
		var res: MonsterResource = all[id]
		assert_array(res.validate()).override_failure_message(String(id)).is_empty()
		if res.tier == 0:
			assert_float(res.base_damage).override_failure_message("%s standard damage" % id).is_equal(0.0)
	for id: StringName in expected:
		assert_bool(all.has(id)).override_failure_message("%s missing" % id).is_true()
		var res: MonsterResource = all[id]
		var want: Array = expected[id]
		assert_int(res.tier).override_failure_message("%s tier" % id).is_equal(want[0])
		assert_float(res.base_damage).override_failure_message("%s damage" % id).is_equal_approx(want[1], 0.0001)
		assert_float(res.base_attack_interval).override_failure_message("%s interval" % id).is_equal_approx(want[2], 0.0001)
		assert_int(res.boss_attack_range_cells).override_failure_message("%s range" % id).is_equal(want[3])
		assert_float(res.hero_attack_windup_seconds).override_failure_message("%s windup" % id).is_equal_approx(want[4], 0.0001)
