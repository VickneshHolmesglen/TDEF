extends GdUnitTestSuite

## Unit tests for Hero's transient effect-modifier layer and is_direct_kill()
## (equipment-set-effects spec §3.4/§3.5, AC-9/AC-10).

var _hero: Hero


func before_test() -> void:
	GInventory.reset_to_defaults()
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[&"physical_attack"] = 100.0
	_hero._base_stats[&"attack_range"] = 200.0
	_hero.global_position = Vector2.ZERO


func after_test() -> void:
	GInventory.reset_to_defaults()
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


func _kill(x: float, source: String = "") -> MonsterDiedEvent:
	var payload := MonsterDiedEvent.new()
	payload.world_position = Vector2(x, 0.0)
	payload.kill_source = source
	return payload


func test_modifier_raises_the_effective_stat_as_a_percentage() -> void:
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.25})
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(125.0, 0.0001)


func test_two_sources_sum_and_clear_independently() -> void:
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.25})
	_hero.set_effect_modifier(&"b", {&"physical_attack": 0.10})
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(135.0, 0.0001)
	_hero.clear_effect_modifier(&"a")
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(110.0, 0.0001)
	_hero.clear_effect_modifier(&"b")
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(100.0, 0.0001)


func test_setting_the_same_source_again_replaces_it() -> void:
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.25})
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.10})
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(110.0, 0.0001)


func test_clear_all_removes_every_source() -> void:
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.25})
	_hero.set_effect_modifier(&"b", {&"attack_range": 0.5})
	_hero.clear_all_effect_modifiers()
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(100.0, 0.0001)
	assert_float(_hero.get_effective_stat(&"attack_range")).is_equal_approx(200.0, 0.0001)


func test_clearing_an_unknown_source_is_a_no_op() -> void:
	_hero.clear_effect_modifier(&"nope")
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(100.0, 0.0001)


func test_modifier_is_bounded_by_the_existing_additive_cap() -> void:
	_hero.set_effect_modifier(&"a", {&"physical_attack": 5.0})
	# ADDITIVE_BONUS_CAP is 3.0 -> multiplier 4.0
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(400.0, 0.0001)


func test_equipment_recompute_does_not_wipe_a_live_modifier() -> void:
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.25})
	_hero._recompute_equipment_bonuses()
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(125.0, 0.0001)


func test_reset_to_defaults_clears_modifiers() -> void:
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.25})
	_hero.reset_to_defaults()
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(100.0, 0.0001)


func test_modifiers_are_not_part_of_the_save_data() -> void:
	var before: Dictionary = _hero.get_save_data()
	_hero.set_effect_modifier(&"a", {&"physical_attack": 0.25})
	assert_bool(_hero.get_save_data() == before).is_true()


func test_is_direct_kill_true_inside_attack_range() -> void:
	assert_bool(_hero.is_direct_kill(_kill(150.0))).is_true()


func test_is_direct_kill_false_outside_attack_range() -> void:
	assert_bool(_hero.is_direct_kill(_kill(250.0))).is_false()


func test_is_direct_kill_false_for_wave_end_despawns() -> void:
	assert_bool(_hero.is_direct_kill(_kill(10.0, "wave_end"))).is_false()


func test_is_direct_kill_follows_a_range_modifier() -> void:
	_hero.set_effect_modifier(&"a", {&"attack_range": 0.5})
	assert_bool(_hero.is_direct_kill(_kill(250.0))).is_true()
