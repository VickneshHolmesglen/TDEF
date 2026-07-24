## Integration tests for Story 013 (TR-equipforge-001, ADR-0021/ADR-0025):
## the Rune Imbuing Action (AC-16(a-d)).
##
## Exercises the real, authored res://assets/data/equipment_recipes/ and
## res://assets/data/items/ content via GGameDataRegistry. EquipmentForge is
## instantiated directly (EquipmentForge.new(), no add_child()). GInventory
## IS the real global Autoload — reset in before_test()/after_test().
extends GdUnitTestSuite

var _forge: EquipmentForge
var _spy: EventBusSpy


func before_test() -> void:
	_forge = EquipmentForge.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.item_rune_imbued)
	_spy.watch(GEventBus.equipment_slot_changed)
	GInventory.reset_to_defaults()


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _forge != null and is_instance_valid(_forge):
		_forge.free()
	_forge = null
	GInventory.reset_to_defaults()


## Crafts iron_sword (weapon, rune_slot_count=2) and returns its instance_id.
func _craft_iron_sword() -> int:
	_forge._equipment_discovery_ledger[&"recipe_iron_sword"] = true
	GInventory.add_stackable(GGameDataRegistry.get_item_definition(&"common_scrap"), 4)
	_forge.resolve_craft(&"recipe_iron_sword")
	return GInventory.get_slot_contents(0)["instance_id"] as int


# ---------------------------------------------------------------------------
# AC-16(a): imbuing a currently-equipped item succeeds
# ---------------------------------------------------------------------------

## Story 008's equip_item() creates a fresh instance from a definition — it
## has no API to relocate an existing crafted instance into a named
## equipment slot, so a crafted item's "currently equipped" state is
## represented here by setting InventorySlot.locked directly (exactly what
## that field means per its own doc comment: "true while equipped/
## installed"). This directly proves the claim AC-16(a) makes: imbuing
## succeeds on a currently-equipped item, no unequip->imbue->re-equip cycle.
func test_imbue_succeeds_on_currently_equipped_item() -> void:
	var instance_id: int = _craft_iron_sword()
	GInventory.set_slot_locked(0, true)
	_forge._on_constellation_rune_discovered("rune_triad_line", "pattern_triad_line")

	var result: bool = _forge.resolve_imbue(instance_id, &"rune_triad_line")

	assert_bool(result).is_true()
	var contents: Dictionary = GInventory.get_slot_contents_by_instance_id(instance_id)
	assert_array(contents["imbued_runes"] as Array).contains_exactly(["rune_triad_line"])
	assert_bool(contents["locked"] as bool).is_true()  # remains equipped throughout
	assert_int(_spy.count("item_rune_imbued")).is_equal(1)
	# No equipment_slot_changed side effect — imbuing is not an equip action.
	assert_bool(_spy.was_emitted("equipment_slot_changed")).is_false()


# ---------------------------------------------------------------------------
# AC-16(b): one-time-use consumption
# ---------------------------------------------------------------------------

func test_imbued_rune_is_consumed_and_cannot_be_reused() -> void:
	var instance_id_a: int = _craft_iron_sword()
	_forge._equipment_discovery_ledger[&"recipe_lucky_charm_trinket"] = true
	GInventory.add_stackable(GGameDataRegistry.get_item_definition(&"common_scrap"), 3)
	_forge.resolve_craft(&"recipe_lucky_charm_trinket")
	var instance_id_b: int = GInventory.get_slot_contents(1)["instance_id"] as int

	_forge._on_constellation_rune_discovered("rune_triad_line", "pattern_triad_line")
	_forge.resolve_imbue(instance_id_a, &"rune_triad_line")

	assert_dict(_forge.get_available_rune(&"rune_triad_line")).is_empty()

	# Attempting to re-target it (even against a different item) fails —
	# the rune no longer exists in the ledger to be found.
	var second_result: bool = _forge.resolve_imbue(instance_id_b, &"rune_triad_line")
	assert_bool(second_result).is_false()
	var item_b_contents: Dictionary = GInventory.get_slot_contents_by_instance_id(instance_id_b)
	assert_array(item_b_contents["imbued_runes"] as Array).is_empty()


# ---------------------------------------------------------------------------
# AC-16(c): clean rejection, no free rune slot
# ---------------------------------------------------------------------------

func test_imbue_rejected_when_no_free_rune_slot_rune_stays_available() -> void:
	_forge._equipment_discovery_ledger[&"recipe_lucky_charm_trinket"] = true
	GInventory.add_stackable(GGameDataRegistry.get_item_definition(&"common_scrap"), 3)
	_forge.resolve_craft(&"recipe_lucky_charm_trinket")  # trinket, rune_slot_count = 1
	var instance_id: int = GInventory.get_slot_contents(0)["instance_id"] as int

	_forge._on_constellation_rune_discovered("rune_a", "pattern_a")
	_forge._on_constellation_rune_discovered("rune_b", "pattern_b")
	_forge.resolve_imbue(instance_id, &"rune_a")  # fills the trinket's only slot

	var result: bool = _forge.resolve_imbue(instance_id, &"rune_b")

	assert_bool(result).is_false()
	assert_bool(_forge.get_available_rune(&"rune_b").is_empty()).is_false()  # still AVAILABLE
	var contents: Dictionary = GInventory.get_slot_contents_by_instance_id(instance_id)
	assert_array(contents["imbued_runes"] as Array).contains_exactly(["rune_a"])  # unchanged


func test_imbue_rejected_for_unknown_instance_id() -> void:
	_forge._on_constellation_rune_discovered("rune_triad_line", "pattern_triad_line")
	var result: bool = _forge.resolve_imbue(99999, &"rune_triad_line")
	assert_bool(result).is_false()


func test_imbue_rejected_for_unknown_rune_id() -> void:
	var instance_id: int = _craft_iron_sword()
	var result: bool = _forge.resolve_imbue(instance_id, &"rune_never_discovered")
	assert_bool(result).is_false()


# ---------------------------------------------------------------------------
# AC-16(d): rune source literal strings
# ---------------------------------------------------------------------------

func test_item_rune_imbued_carries_exact_constellation_source_string() -> void:
	var instance_id: int = _craft_iron_sword()
	_forge._on_constellation_rune_discovered("rune_triad_line", "pattern_triad_line")

	_forge.resolve_imbue(instance_id, &"rune_triad_line")

	var args: Array = (_spy.emissions["item_rune_imbued"] as Array)[0]
	assert_str(args[2] as String).is_equal("constellation")


func test_item_rune_imbued_carries_exact_tarot_source_string() -> void:
	var instance_id: int = _craft_iron_sword()
	_forge._on_tarot_rune_discovered("rune_iron_resolve", "iron_resolve")

	_forge.resolve_imbue(instance_id, &"rune_iron_resolve")

	var args: Array = (_spy.emissions["item_rune_imbued"] as Array)[0]
	assert_str(args[2] as String).is_equal("tarot")


## AC-16(d)'s menagerie half ("a Menagerie-sourced rune imbued at item
## creation") is a DIFFERENT code path — Story 014's own sacrifice
## resolution flow calls Inventory.apply_rune_to_item() directly at the
## moment of item creation, never through resolve_imbue()/_available_runes
## (per Story 012's own AC-15: Menagerie-sourced runes never enter this
## ledger). This test confirms Inventory's own layer is source-agnostic —
## apply_rune_to_item() has no rune_source parameter at all, so whichever
## caller (resolve_imbue() here, or Story 014's future sacrifice flow)
## supplies the literal string at its own item_rune_imbued emission site.
func test_apply_rune_to_item_is_source_agnostic_at_the_inventory_layer() -> void:
	var instance_id: int = _craft_iron_sword()
	var result: bool = GInventory.apply_rune_to_item(instance_id, "rune_menagerie_sourced", {})
	assert_bool(result).is_true()
	var contents: Dictionary = GInventory.get_slot_contents_by_instance_id(instance_id)
	assert_array(contents["imbued_runes"] as Array).contains_exactly(["rune_menagerie_sourced"])
