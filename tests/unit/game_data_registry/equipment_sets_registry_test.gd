extends GdUnitTestSuite

## Unit tests for GameDataRegistry's equipment-set loading (equipment-set-
## bonuses spec §3.2, AC-2).

const VALID_DIR: String = "res://tests/fixtures/game_data_registry/equipment_sets_valid/"
const INVALID_DIR: String = "res://tests/fixtures/game_data_registry/equipment_sets_invalid/"
const DUPLICATE_DIR: String = "res://tests/fixtures/game_data_registry/equipment_sets_duplicate/"
const MISSING_DIR: String = "res://tests/fixtures/game_data_registry/equipment_sets_does_not_exist/"

var _registry: GameDataRegistry


func before_test() -> void:
	_registry = GameDataRegistry.new()


func after_test() -> void:
	if _registry != null and is_instance_valid(_registry):
		_registry.free()
	_registry = null


func _load(dir: String) -> void:
	_registry._equipment_sets_dir = dir
	_registry._load_equipment_sets()


func test_valid_directory_loads_the_set_keyed_by_id() -> void:
	_load(VALID_DIR)
	var s: EquipmentSetResource = _registry.get_equipment_set(&"set_test_a")
	assert_object(s).is_not_null()
	assert_str(s.display_name).is_equal("Test A")
	assert_int(s.member_item_ids.size()).is_equal(3)
	assert_float(float(s.bonuses[2][&"armor"])).is_equal_approx(5.0, 0.0001)
	assert_float(float(s.bonuses[3][&"additive_bonus_total"])).is_equal_approx(0.05, 0.0001)


func test_unknown_set_returns_null() -> void:
	_load(VALID_DIR)
	assert_object(_registry.get_equipment_set(&"nope")).is_null()


func test_get_all_returns_a_copy() -> void:
	_load(VALID_DIR)
	var all: Dictionary = _registry.get_all_equipment_sets()
	all.clear()
	assert_int(_registry.get_all_equipment_sets().size()).is_equal(1)


func test_invalid_set_is_still_cached_and_validate_flags_it() -> void:
	_load(INVALID_DIR)
	var s: EquipmentSetResource = _registry.get_equipment_set(&"set_bad")
	assert_object(s).is_not_null()
	assert_bool(s.validate().size() > 0).is_true()


func test_duplicate_set_id_does_not_crash_and_keeps_one_entry() -> void:
	_load(DUPLICATE_DIR)
	assert_int(_registry.get_all_equipment_sets().size()).is_equal(1)
	assert_object(_registry.get_equipment_set(&"set_dup")).is_not_null()


func test_missing_directory_yields_no_sets_without_crashing() -> void:
	_load(MISSING_DIR)
	assert_int(_registry.get_all_equipment_sets().size()).is_equal(0)
