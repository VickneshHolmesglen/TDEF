## Integration tests for Story 011 (TR-equipforge-003, ADR-0025): Save Payload
## Ownership Clarification (AC-12) — plus the SaveRestorer round-trip and
## boot sweep (restore_order=32) this story implements alongside it.
##
## EquipmentForge is instantiated directly (EquipmentForge.new(), no
## add_child()) so _ready() never fires — GSavePersistence.register() is
## never called, avoiding pollution of the real Autoload's registered-systems
## list. get_save_data()/restore_save_data() are called directly, matching
## Tarot/Mission Select/Hero Skill Build's established persistence-test
## convention. GInventory/GDefenseBuilding are the real global Autoloads —
## reset in before_test()/after_test().
extends GdUnitTestSuite

var _forge: EquipmentForge


func before_test() -> void:
	_forge = EquipmentForge.new()
	GInventory.reset_to_defaults()


func after_test() -> void:
	if _forge != null and is_instance_valid(_forge):
		_forge.free()
	_forge = null
	GInventory.reset_to_defaults()


func test_restore_order_is_32() -> void:
	assert_int(EquipmentForge.RESTORE_ORDER).is_equal(32)


# ---------------------------------------------------------------------------
# AC-12: payload contains exactly two entries, no item-instance data
# ---------------------------------------------------------------------------

func test_save_payload_contains_exactly_two_ledger_entries() -> void:
	_forge._equipment_discovery_ledger[&"recipe_iron_sword"] = true
	_forge._on_constellation_rune_discovered("rune_triad_line", "pattern_triad_line")

	var saved: Dictionary = _forge.get_save_data()

	assert_int(saved.size()).is_equal(2)
	assert_bool(saved.has("equipment_discovery_ledger")).is_true()
	assert_bool(saved.has("available_runes")).is_true()


func test_save_payload_contains_no_item_instance_data() -> void:
	# Crafting a real item (Story 010) creates item-instance data in
	# Inventory (rune_slot_count/imbued_runes) — none of that leaks into
	# Equipment Forge's own payload, confirming the ownership split.
	_forge._equipment_discovery_ledger[&"recipe_iron_sword"] = true
	GInventory.add_stackable(GGameDataRegistry.get_item_definition(&"common_scrap"), 4)
	_forge.resolve_craft(&"recipe_iron_sword")

	var saved: Dictionary = _forge.get_save_data()

	assert_bool(saved.has("imbued_runes")).is_false()
	assert_bool(saved.has("rune_slot_count")).is_false()
	assert_bool(saved.has("item_instances")).is_false()
	assert_bool(saved.has("crafted_items")).is_false()


# ---------------------------------------------------------------------------
# SaveRestorer round-trip
# ---------------------------------------------------------------------------

func test_get_save_data_round_trips_both_ledgers() -> void:
	_forge._equipment_discovery_ledger[&"recipe_iron_sword"] = true
	_forge._on_constellation_rune_discovered("rune_triad_line", "pattern_triad_line")

	var saved: Dictionary = _forge.get_save_data()
	var restored := EquipmentForge.new()
	var ok: bool = restored.restore_save_data(saved)

	assert_bool(ok).is_true()
	assert_bool(restored.is_discovered(&"recipe_iron_sword")).is_true()
	var entry: Dictionary = restored.get_available_rune(&"rune_triad_line")
	assert_str(entry["rune_source"] as String).is_equal("constellation")
	restored.free()


func test_restore_save_data_rejects_malformed_payload() -> void:
	assert_bool(_forge.restore_save_data({})).is_false()
	assert_bool(_forge.restore_save_data({"equipment_discovery_ledger": "not_a_dict", "available_runes": {}})).is_false()


func test_reset_to_defaults_clears_both_ledgers() -> void:
	_forge._equipment_discovery_ledger[&"recipe_iron_sword"] = true
	_forge._on_constellation_rune_discovered("rune_triad_line", "pattern_triad_line")

	_forge.reset_to_defaults()

	assert_bool(_forge.is_discovered(&"recipe_iron_sword")).is_false()
	assert_dict(_forge.get_available_rune(&"rune_triad_line")).is_empty()


# ---------------------------------------------------------------------------
# Boot sweep (trigger 3) — resolves at restore time
# ---------------------------------------------------------------------------

func test_boot_sweep_discovers_recipe_already_both_gates_true_at_restore() -> void:
	GInventory.add_stackable(GGameDataRegistry.get_item_definition(&"common_scrap"), 4)

	var ok: bool = _forge.restore_save_data({"equipment_discovery_ledger": {}, "available_runes": {}})

	assert_bool(ok).is_true()
	assert_bool(_forge.is_discovered(&"recipe_iron_sword")).is_true()
