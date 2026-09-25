extends GdUnitTestSuite

## Unit tests for EquipmentSetResource.validate() (equipment-set-bonuses spec §3.1, AC-1).


func _valid() -> EquipmentSetResource:
	var s := EquipmentSetResource.new()
	s.set_id = &"set_test"
	s.display_name = "Test"
	s.member_item_ids = [&"a", &"b", &"c"] as Array[StringName]
	s.bonuses = {2: {&"armor": 5.0}, 3: {&"max_hp": 20.0, &"additive_bonus_total": 0.05}}
	return s


func test_valid_set_has_no_errors() -> void:
	assert_array(_valid().validate()).is_empty()


func test_empty_set_id_and_display_name_are_rejected() -> void:
	var s: EquipmentSetResource = _valid()
	s.set_id = &""
	s.display_name = ""
	assert_int(s.validate().size()).is_equal(2)


func test_fewer_than_two_members_is_rejected() -> void:
	var s: EquipmentSetResource = _valid()
	s.member_item_ids = [&"a"] as Array[StringName]
	s.bonuses = {}
	assert_bool(s.validate().size() > 0).is_true()


func test_duplicate_members_are_rejected() -> void:
	var s: EquipmentSetResource = _valid()
	s.member_item_ids = [&"a", &"a", &"c"] as Array[StringName]
	assert_bool(s.validate().size() > 0).is_true()


func test_empty_bonuses_are_rejected() -> void:
	var s: EquipmentSetResource = _valid()
	s.bonuses = {}
	assert_bool(s.validate().size() > 0).is_true()


func test_threshold_below_two_or_above_member_count_is_rejected() -> void:
	var low: EquipmentSetResource = _valid()
	low.bonuses = {1: {&"armor": 5.0}}
	assert_bool(low.validate().size() > 0).is_true()
	var high: EquipmentSetResource = _valid()
	high.bonuses = {4: {&"armor": 5.0}}
	assert_bool(high.validate().size() > 0).is_true()


func test_empty_delta_is_rejected() -> void:
	var s: EquipmentSetResource = _valid()
	s.bonuses = {2: {}}
	assert_bool(s.validate().size() > 0).is_true()


func test_non_positive_value_is_rejected() -> void:
	var s: EquipmentSetResource = _valid()
	s.bonuses = {2: {&"armor": 0.0}}
	assert_bool(s.validate().size() > 0).is_true()


func test_unknown_stat_key_is_rejected() -> void:
	var s: EquipmentSetResource = _valid()
	s.bonuses = {2: {&"typo_stat": 5.0}}
	assert_bool(s.validate().size() > 0).is_true()


# ---------------------------------------------------------------------------
# Capstone effects (equipment-set-effects spec §3.2, AC-1)
# ---------------------------------------------------------------------------

func _params(type: StringName) -> Dictionary:
	match type:
		&"on_kill_stack_buff":
			return {&"stats": {&"physical_attack": 0.03}, &"max_stacks": 10, &"duration": 6.0}
		&"on_crit_status":
			return {&"effect_type": "poison", &"effect_value": 0.06, &"effect_duration": 4.0}
		&"on_wave_start_buff":
			return {&"stats": {&"physical_attack": 0.35}, &"duration": 10.0}
		&"on_skill_cast_buff":
			return {&"stats": {&"attack_range": 0.2}, &"duration": 5.0}
		&"phase_state":
			return {&"stats": {&"attack_range": 0.2}, &"phases": ["WAVE_ACTIVE"]}
	return {}


func _with_effect(threshold: int, type: StringName, params: Dictionary) -> EquipmentSetResource:
	var s: EquipmentSetResource = _valid()
	s.effects = {threshold: {&"name": "Test Effect", &"type": type, &"params": params}}
	return s


func _assert_rejected(s: EquipmentSetResource) -> void:
	assert_bool(s.validate().size() > 0).is_true()


func test_set_without_effects_is_still_valid() -> void:
	assert_array(_valid().validate()).is_empty()


func test_each_effect_type_with_valid_params_has_no_errors() -> void:
	for type: StringName in EquipmentSetResource.EFFECT_TYPES:
		var errors: Array[String] = _with_effect(3, type, _params(type)).validate()
		assert_array(errors).override_failure_message(String(type)).is_empty()


func test_effect_threshold_out_of_range_is_rejected() -> void:
	_assert_rejected(_with_effect(1, &"phase_state", _params(&"phase_state")))
	_assert_rejected(_with_effect(4, &"phase_state", _params(&"phase_state")))


func test_effect_with_empty_name_is_rejected() -> void:
	var s: EquipmentSetResource = _with_effect(3, &"phase_state", _params(&"phase_state"))
	s.effects[3][&"name"] = ""
	_assert_rejected(s)


func test_unknown_effect_type_is_rejected() -> void:
	_assert_rejected(_with_effect(3, &"on_hurt_shield", {&"stats": {&"armor": 0.1}, &"duration": 5.0}))


func test_missing_required_param_is_rejected() -> void:
	var params: Dictionary = _params(&"on_wave_start_buff")
	params.erase(&"duration")
	_assert_rejected(_with_effect(3, &"on_wave_start_buff", params))


func test_unknown_extra_param_is_rejected() -> void:
	var params: Dictionary = _params(&"on_wave_start_buff")
	params[&"typo"] = 1.0
	_assert_rejected(_with_effect(3, &"on_wave_start_buff", params))


func test_non_positive_duration_is_rejected() -> void:
	var params: Dictionary = _params(&"on_wave_start_buff")
	params[&"duration"] = 0.0
	_assert_rejected(_with_effect(3, &"on_wave_start_buff", params))


func test_bad_stats_are_rejected() -> void:
	for bad: Dictionary in [{}, {&"typo_stat": 0.1}, {&"additive_bonus_total": 0.1}, {&"armor": 0.0}, {&"armor": -0.1}]:
		var params: Dictionary = _params(&"on_wave_start_buff")
		params[&"stats"] = bad
		_assert_rejected(_with_effect(3, &"on_wave_start_buff", params))


func test_max_stacks_must_be_an_int_of_at_least_one() -> void:
	for bad: Variant in [10.0, 0, -2]:
		var params: Dictionary = _params(&"on_kill_stack_buff")
		params[&"max_stacks"] = bad
		_assert_rejected(_with_effect(3, &"on_kill_stack_buff", params))


func test_crit_status_effect_type_must_be_burn_or_poison() -> void:
	var params: Dictionary = _params(&"on_crit_status")
	params[&"effect_type"] = "bleed"
	_assert_rejected(_with_effect(3, &"on_crit_status", params))


func test_phase_state_phases_must_be_non_empty_and_known() -> void:
	for bad: Array in [[], ["NOT_A_PHASE"]]:
		var params: Dictionary = _params(&"phase_state")
		params[&"phases"] = bad
		_assert_rejected(_with_effect(3, &"phase_state", params))


func test_known_phases_match_the_wave_manager_enum() -> void:
	var real: Array = WaveManager.Phase.keys()
	assert_int(EquipmentSetResource.KNOWN_PHASES.size()).is_equal(real.size())
	for phase: String in real:
		assert_bool(EquipmentSetResource.KNOWN_PHASES.has(phase)).override_failure_message(phase).is_true()
