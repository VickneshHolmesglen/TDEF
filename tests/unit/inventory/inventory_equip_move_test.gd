extends GdUnitTestSuite

## Unit tests for Inventory.equip_from_slot()/unequip_to_bag() (double-click
## equip/unequip, 2026-10-07): an item must MOVE intact -- same instance_id,
## rolled stat_overrides, runes and damaged flag -- never be duplicated
## (equip_item) or destroyed (unequip_item).


func before_test() -> void:
	GInventory.reset_to_defaults()


func after_test() -> void:
	GInventory.reset_to_defaults()


func _def(item_id: StringName) -> ItemDefinitionResource:
	return GGameDataRegistry.get_item_definition(item_id)


## Adds a rolled helmet with runes to the bag; returns its bag slot index.
func _add_rolled(item_id: StringName, armor: float) -> int:
	var overrides: Dictionary[StringName, float] = {&"armor": armor}
	var idx: int = GInventory.add_unique_item(_def(item_id), overrides, 2)
	GInventory._slots[idx].imbued_runes = [&"rune_test"]
	GInventory._slots[idx].damaged = true
	return idx


func _count_instances(instance_id: int) -> int:
	var n: int = 0
	for slot: InventorySlot in GInventory._slots:
		if slot != null and slot.instance_id == instance_id:
			n += 1
	return n


func test_equip_moves_the_item_intact_and_empties_the_bag_slot() -> void:
	var idx: int = _add_rolled(&"brutes_war_helm", 33.0)
	var instance_id: int = GInventory._slots[idx].instance_id

	assert_bool(GInventory.equip_from_slot(idx)).is_true()

	var equipped: Dictionary = GInventory.get_equipped_item("helmet")
	assert_int(int(equipped["instance_id"])).is_equal(instance_id)
	assert_float(float(equipped["stat_overrides"][&"armor"])).is_equal(33.0)
	assert_array(equipped["imbued_runes"]).contains(["rune_test"])
	assert_int(int(equipped["rune_slot_count"])).is_equal(2)
	assert_bool(bool(equipped["damaged"])).is_true()
	assert_bool(GInventory.is_slot_empty(idx)).is_true()
	assert_int(_count_instances(instance_id)).is_equal(1)


func test_equip_onto_an_occupied_slot_swaps_the_old_item_into_the_bag() -> void:
	var first: int = _add_rolled(&"brutes_war_helm", 10.0)
	GInventory.equip_from_slot(first)
	var second: int = _add_rolled(&"iron_helm", 20.0)
	var old_instance: int = int(GInventory.get_equipped_item("helmet")["instance_id"])

	assert_bool(GInventory.equip_from_slot(second)).is_true()

	assert_str(String(GInventory.get_equipped_item("helmet")["item_id"])).is_equal("iron_helm")
	var back: Dictionary = GInventory.get_slot_contents(second)
	assert_int(int(back["instance_id"])).is_equal(old_instance)
	assert_float(float(back["stat_overrides"][&"armor"])).is_equal(10.0)
	assert_bool(bool(back["locked"])).is_false()


func test_unequip_moves_the_item_intact_into_a_free_bag_slot() -> void:
	var idx: int = _add_rolled(&"brutes_war_helm", 33.0)
	var instance_id: int = GInventory._slots[idx].instance_id
	GInventory.equip_from_slot(idx)

	var bag: int = GInventory.unequip_to_bag("helmet")

	assert_int(bag).is_greater_equal(0)
	assert_bool(GInventory.get_equipped_item("helmet").is_empty()).is_true()
	var contents: Dictionary = GInventory.get_slot_contents(bag)
	assert_int(int(contents["instance_id"])).is_equal(instance_id)
	assert_float(float(contents["stat_overrides"][&"armor"])).is_equal(33.0)
	assert_array(contents["imbued_runes"]).contains(["rune_test"])
	assert_bool(bool(contents["locked"])).is_false()
	assert_int(_count_instances(instance_id)).is_equal(1)


func test_unequip_with_a_full_bag_changes_nothing() -> void:
	var idx: int = _add_rolled(&"brutes_war_helm", 33.0)
	GInventory.equip_from_slot(idx)
	for i: int in GInventory._slots.size():
		if not GInventory.is_equipment_slot_index(i) and GInventory._slots[i] == null:
			GInventory.add_unique_item(_def(&"iron_helm"))

	assert_int(GInventory.unequip_to_bag("helmet")).is_equal(-1)
	assert_str(String(GInventory.get_equipped_item("helmet")["item_id"])).is_equal("brutes_war_helm")


func test_a_ring_fills_the_free_ring_slot_first() -> void:
	GInventory.equip_from_slot(GInventory.add_unique_item(_def(&"brute_core_band")))
	GInventory.equip_from_slot(GInventory.add_unique_item(_def(&"iron_band")))

	assert_str(String(GInventory.get_equipped_item("ring_1")["item_id"])).is_equal("brute_core_band")
	assert_str(String(GInventory.get_equipped_item("ring_2")["item_id"])).is_equal("iron_band")


func test_equip_rejects_empty_and_equipment_slot_indices() -> void:
	assert_bool(GInventory.equip_from_slot(0)).is_false()
	assert_bool(GInventory.equip_from_slot(Inventory.EQUIPMENT_SLOT_INDEX["helmet"])).is_false()


func test_equip_emits_equipment_slot_changed() -> void:
	var idx: int = _add_rolled(&"brutes_war_helm", 1.0)
	var seen: Array[String] = []
	var on_changed := func(slot: String, new_id: String, _prev: String) -> void: seen.append("%s:%s" % [slot, new_id])
	GEventBus.equipment_slot_changed.connect(on_changed)
	GInventory.equip_from_slot(idx)
	GEventBus.equipment_slot_changed.disconnect(on_changed)
	assert_array(seen).contains(["helmet:brutes_war_helm"])


## Regression (found live 2026-10-07): items equipped via equip_item() had
## quantity 0, so after an unequip the grid hid them as if the slot were empty.
func test_an_item_equipped_by_equip_item_shows_up_after_unequip() -> void:
	GInventory.equip_item("helmet", _def(&"brutes_war_helm"))
	GInventory._slots[Inventory.EQUIPMENT_SLOT_INDEX["helmet"]].quantity = 0  # legacy saves

	var bag: int = GInventory.unequip_to_bag("helmet")

	assert_int(int(GInventory.get_slot_contents(bag)["quantity"])).is_equal(1)


func test_equip_item_records_a_quantity_of_one() -> void:
	GInventory.equip_item("helmet", _def(&"brutes_war_helm"))
	assert_int(int(GInventory.get_equipped_item("helmet")["quantity"])).is_equal(1)


func test_loading_a_save_repairs_unique_items_stored_with_quantity_zero() -> void:
	var idx: int = GInventory.add_unique_item(_def(&"brutes_war_helm"))
	GInventory._slots[idx].quantity = 0  # as written by the pre-fix unequip path
	var data: Dictionary = GInventory.get_save_data()

	assert_bool(GInventory.restore_save_data(data)).is_true()

	assert_int(int(GInventory.get_slot_contents(idx)["quantity"])).is_equal(1)
