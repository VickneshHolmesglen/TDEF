extends GdUnitTestSuite

## Unit tests for Hero's equipment/rune stat wiring (equipment-stats-wiring
## spec AC-1..AC-6). Uses real GInventory and the real iron_sword.tres
## (equipment_category "weapon"); every test unequips in after_test() so the
## autoload's state never leaks.

const SWORD_PATH: String = "res://assets/data/items/iron_sword.tres"

var _hero: Hero


func before_test() -> void:
	_hero = Hero.new()
	add_child(_hero)


func after_test() -> void:
	GInventory.unequip_item("main_hand")
	GInventory.unequip_item("ring_1")
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


func _equip_sword(overrides: Dictionary[StringName, float] = {}) -> void:
	var sword: ItemDefinitionResource = load(SWORD_PATH)
	assert_bool(GInventory.equip_item("main_hand", sword, overrides)).is_true()


func test_fan_out_list_matches_every_base_stat_key_exactly_once() -> void:
	var keys: Array = Hero.PLACEHOLDER_BASE_STATS.keys()
	assert_int(Hero.EQUIPMENT_FAN_OUT_STATS.size()).is_equal(keys.size())
	for key: StringName in keys:
		assert_bool(Hero.EQUIPMENT_FAN_OUT_STATS.has(key)).is_true()


func test_fold_plain_stat_goes_to_flat_bucket() -> void:
	var flat: Dictionary[StringName, float] = {}
	var add: Dictionary[StringName, float] = {}
	Hero._fold_stat_entry(&"armor", 3.0, flat, add)
	Hero._fold_stat_entry(&"armor", 2.0, flat, add)
	assert_float(flat[&"armor"]).is_equal_approx(5.0, 0.0001)
	assert_bool(add.is_empty()).is_true()


func test_fold_additive_bonus_total_fans_out_to_every_stat() -> void:
	var flat: Dictionary[StringName, float] = {}
	var add: Dictionary[StringName, float] = {}
	Hero._fold_stat_entry(&"additive_bonus_total", 0.05, flat, add)
	assert_bool(flat.is_empty()).is_true()
	assert_int(add.size()).is_equal(Hero.EQUIPMENT_FAN_OUT_STATS.size())
	for stat: StringName in Hero.EQUIPMENT_FAN_OUT_STATS:
		assert_float(add[stat]).is_equal_approx(0.05, 0.0001)


func test_equipping_item_with_override_raises_effective_stat() -> void:
	var before: float = _hero.get_effective_stat(&"armor")
	_equip_sword({&"armor": 7.0})
	assert_float(_hero.get_effective_stat(&"armor")).is_equal_approx(before + 7.0, 0.0001)


func test_unequipping_removes_contribution() -> void:
	var before: float = _hero.get_effective_stat(&"armor")
	_equip_sword({&"armor": 7.0})
	GInventory.unequip_item("main_hand")
	assert_float(_hero.get_effective_stat(&"armor")).is_equal_approx(before, 0.0001)


func test_item_with_unregistered_definition_is_skipped() -> void:
	var before: float = _hero.get_effective_stat(&"armor")
	_equip_sword({&"armor": 7.0})
	var ring: ItemDefinitionResource = ItemDefinitionResource.new()
	ring.item_id = &"test_ring_for_stats"
	ring.equipment_category = "ring"
	assert_bool(GInventory.equip_item("ring_1", ring, {&"armor": 5.0})).is_true()
	assert_float(_hero.get_effective_stat(&"armor")).is_equal_approx(before + 7.0, 0.0001)


func test_hero_created_after_equip_picks_up_bonus_on_ready() -> void:
	_equip_sword({&"armor": 4.0})
	var late: Hero = Hero.new()
	add_child(late)
	assert_float(late.get_effective_stat(&"armor")).is_greater_equal(4.0)
	remove_child(late)
	late.free()
