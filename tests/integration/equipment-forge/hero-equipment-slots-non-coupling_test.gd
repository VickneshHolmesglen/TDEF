## Integration tests for Story 008 (TR-equipforge-001 slot-model portion,
## ADR-0025): Hero equipment slots & non-coupling (AC-1/AC-2). AC-3 (no
## direct Equipment Forge -> Hero call anywhere in the codebase) is a
## documented code-path review, not an automated test — see this story's
## Completion Notes.
##
## Expanded 2026-08-16 (player-requested) from the original 5-slot model
## (weapon/armor/accessory_a/accessory_b/trinket) to 10 named slots
## (helmet/chest/gloves/pants/boots/main_hand/neck/ring_1/ring_2/offhand)
## matching a Diablo-style paperdoll layout the player specified. See
## Inventory.EQUIPMENT_SLOT_NAMES' own doc comment for the full rationale.
##
## Inventory is instantiated directly (Inventory.new()) and
## reset_to_defaults() is called explicitly rather than add_child()-ing it —
## mirrors this project's established Inventory test convention
## (tests/unit/inventory/slot_stack_model_test.gd).
extends GdUnitTestSuite

var _inventory: Inventory


func before_test() -> void:
	_inventory = Inventory.new()
	_inventory.reset_to_defaults()


func after_test() -> void:
	if _inventory != null and is_instance_valid(_inventory):
		_inventory.free()
	_inventory = null


func _make_item(item_id: String, category: String) -> ItemDefinitionResource:
	var definition := ItemDefinitionResource.new()
	definition.item_id = StringName(item_id)
	definition.item_type = &"Equipment"
	definition.display_name = item_id
	definition.is_unique_instance = true
	definition.equipment_category = category
	return definition


# ---------------------------------------------------------------------------
# AC-1: exactly 10 named slots exist; 4 discretionary slots remain free
# ---------------------------------------------------------------------------

func test_exactly_10_equipment_slot_names_exist() -> void:
	assert_int(Inventory.EQUIPMENT_SLOT_NAMES.size()).is_equal(10)
	assert_array(Inventory.EQUIPMENT_SLOT_NAMES).contains_exactly([
		"helmet", "chest", "gloves", "pants", "boots", "main_hand",
		"neck", "ring_1", "ring_2", "offhand",
	])


func test_4_discretionary_slots_remain_free_at_starting_capacity() -> void:
	assert_int(_inventory.get_slot_count()).is_equal(14)  # unchanged — equipment slots are carved out, not additive

	var discretionary_free: int = 0
	for i: int in range(_inventory.get_slot_count()):
		if _inventory.is_slot_empty(i):
			discretionary_free += 1
	assert_int(discretionary_free).is_equal(4)


func test_fresh_equipment_slots_have_no_item_equipped() -> void:
	for slot_name: String in Inventory.EQUIPMENT_SLOT_NAMES:
		assert_dict(_inventory.get_equipped_item(slot_name)).is_empty()


# ---------------------------------------------------------------------------
# AC-2: ring dual-slot; category mismatch rejected
# ---------------------------------------------------------------------------

func test_ring_item_equips_into_ring_1() -> void:
	var item: ItemDefinitionResource = _make_item("ring_of_power", "ring")
	var result: bool = _inventory.equip_item("ring_1", item)

	assert_bool(result).is_true()
	assert_str(_inventory.get_equipped_item("ring_1")["item_id"] as String).is_equal("ring_of_power")


func test_ring_item_equips_into_ring_2() -> void:
	var item: ItemDefinitionResource = _make_item("amulet_of_haste", "ring")
	var result: bool = _inventory.equip_item("ring_2", item)

	assert_bool(result).is_true()
	assert_str(_inventory.get_equipped_item("ring_2")["item_id"] as String).is_equal("amulet_of_haste")


func test_ring_item_rejected_for_non_ring_slots() -> void:
	var item: ItemDefinitionResource = _make_item("ring_of_power", "ring")
	assert_bool(_inventory.equip_item("main_hand", item)).is_false()
	assert_bool(_inventory.equip_item("chest", item)).is_false()
	assert_bool(_inventory.equip_item("neck", item)).is_false()


func test_weapon_item_rejected_for_non_weapon_slots() -> void:
	var item: ItemDefinitionResource = _make_item("iron_sword", "weapon")
	assert_bool(_inventory.equip_item("chest", item)).is_false()
	assert_bool(_inventory.equip_item("ring_1", item)).is_false()
	assert_bool(_inventory.equip_item("neck", item)).is_false()
	assert_bool(_inventory.equip_item("main_hand", item)).is_true()


func test_helmet_item_rejected_for_other_armor_slots() -> void:
	var item: ItemDefinitionResource = _make_item("iron_helm", "helmet")
	assert_bool(_inventory.equip_item("chest", item)).is_false()
	assert_bool(_inventory.equip_item("gloves", item)).is_false()
	assert_bool(_inventory.equip_item("pants", item)).is_false()
	assert_bool(_inventory.equip_item("boots", item)).is_false()
	assert_bool(_inventory.equip_item("helmet", item)).is_true()


func test_offhand_item_only_equips_into_offhand() -> void:
	var item: ItemDefinitionResource = _make_item("wooden_buckler", "offhand")
	assert_bool(_inventory.equip_item("main_hand", item)).is_false()
	assert_bool(_inventory.equip_item("offhand", item)).is_true()


# ---------------------------------------------------------------------------
# equip/unequip mechanics and equipment_slot_changed emission
# ---------------------------------------------------------------------------

func test_equip_item_emits_equipment_slot_changed() -> void:
	var spy: EventBusSpy = EventBusSpy.new()
	spy.watch(GEventBus.equipment_slot_changed)

	var item: ItemDefinitionResource = _make_item("iron_sword", "weapon")
	_inventory.equip_item("main_hand", item)

	assert_int(spy.count("equipment_slot_changed")).is_equal(1)
	var emission: Array = (spy.emissions["equipment_slot_changed"] as Array)[0]
	assert_str(emission[0] as String).is_equal("main_hand")
	assert_str(emission[1] as String).is_equal("iron_sword")
	assert_str(emission[2] as String).is_equal("")
	spy.disconnect_all()


func test_equip_item_rejects_when_slot_already_occupied() -> void:
	var item_a: ItemDefinitionResource = _make_item("iron_sword", "weapon")
	var item_b: ItemDefinitionResource = _make_item("steel_sword", "weapon")
	_inventory.equip_item("main_hand", item_a)

	var result: bool = _inventory.equip_item("main_hand", item_b)

	assert_bool(result).is_false()
	assert_str(_inventory.get_equipped_item("main_hand")["item_id"] as String).is_equal("iron_sword")


func test_unequip_item_clears_slot_and_emits_event() -> void:
	var item: ItemDefinitionResource = _make_item("iron_sword", "weapon")
	_inventory.equip_item("main_hand", item)
	var spy: EventBusSpy = EventBusSpy.new()
	spy.watch(GEventBus.equipment_slot_changed)

	var result: bool = _inventory.unequip_item("main_hand")

	assert_bool(result).is_true()
	assert_dict(_inventory.get_equipped_item("main_hand")).is_empty()
	var emission: Array = (spy.emissions["equipment_slot_changed"] as Array)[0]
	assert_str(emission[0] as String).is_equal("main_hand")
	assert_str(emission[1] as String).is_equal("")
	assert_str(emission[2] as String).is_equal("iron_sword")
	spy.disconnect_all()


func test_unequip_item_rejected_when_already_empty() -> void:
	assert_bool(_inventory.unequip_item("main_hand")).is_false()


func test_equip_item_rejects_unknown_slot_name() -> void:
	var item: ItemDefinitionResource = _make_item("iron_sword", "weapon")
	assert_bool(_inventory.equip_item("shield", item)).is_false()


func test_equipment_slots_do_not_consume_generic_pickup_capacity() -> void:
	# _find_first_empty_slot() must skip the 10 reserved equipment indices —
	# a generic stackable pickup should land in a discretionary slot, never
	# silently occupy a reserved equipment slot.
	var material := ItemDefinitionResource.new()
	material.item_id = &"iron_ore"
	material.item_type = &"Material"
	material.display_name = "Iron Ore"
	material.is_unique_instance = false

	for i: int in 4:
		_inventory.add_stackable(material, 1)

	for slot_name: String in Inventory.EQUIPMENT_SLOT_NAMES:
		assert_dict(_inventory.get_equipped_item(slot_name)).is_empty()


# ---------------------------------------------------------------------------
# Persistence: equipment slots survive a save/load round-trip
# ---------------------------------------------------------------------------

func test_equipped_item_survives_save_load_round_trip() -> void:
	var item: ItemDefinitionResource = _make_item("iron_sword", "weapon")
	_inventory.equip_item("main_hand", item)

	var saved: Dictionary = _inventory.get_save_data()
	var restored := Inventory.new()
	var ok: bool = restored.restore_save_data(saved)

	assert_bool(ok).is_true()
	assert_str(restored.get_equipped_item("main_hand")["item_id"] as String).is_equal("iron_sword")
	restored.free()
