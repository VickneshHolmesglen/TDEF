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
