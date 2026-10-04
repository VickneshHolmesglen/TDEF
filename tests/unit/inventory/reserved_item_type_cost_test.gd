## Regression tests for ItemDefinitionResource.excluded_from_type_costs
## (2026-10-04 smoke check). menagerie_lure shares item_type "Material" with
## crafting materials, and has_items()/consume_by_type() used to count and
## consume it as one -- so any "Material: N" recipe silently ate the player's
## lures, which menagerie.md Rule 2 reserves for the Lure action alone.
##
## Uses the REAL registered menagerie_lure/common_scrap definitions, since
## Inventory resolves item_type through GGameDataRegistry.
extends GdUnitTestSuite

const LURE: StringName = &"menagerie_lure"
const COMMON_SCRAP: StringName = &"common_scrap"

var _inventory: Inventory


func before_test() -> void:
	_inventory = Inventory.new()
	_inventory.reset_to_defaults()


func after_test() -> void:
	if _inventory != null and is_instance_valid(_inventory):
		_inventory.free()
	_inventory = null


func _add(item_id: StringName, quantity: int) -> void:
	_inventory.add_stackable(GGameDataRegistry.get_item_definition(item_id), quantity)


func test_lure_definition_is_flagged_reserved() -> void:
	assert_bool(GGameDataRegistry.get_item_definition(LURE).excluded_from_type_costs).is_true()


func test_ordinary_material_is_not_flagged() -> void:
	assert_bool(GGameDataRegistry.get_item_definition(COMMON_SCRAP).excluded_from_type_costs).is_false()


func test_lures_do_not_satisfy_a_material_cost() -> void:
	_add(LURE, 10)
	assert_bool(_inventory.has_items({&"Material": 1})).is_false()


func test_lures_still_count_for_their_own_specific_check() -> void:
	_add(LURE, 10)
	assert_bool(_inventory.has_item_quantity(LURE, 10)).is_true()


func test_consume_by_type_skips_lures_and_takes_real_materials() -> void:
	_add(LURE, 10)
	_add(COMMON_SCRAP, 5)

	var consumed: int = _inventory.consume_by_type("Material", 5, false)

	assert_int(consumed).is_equal(5)
	assert_bool(_inventory.has_item_quantity(LURE, 10)).is_true()
	assert_bool(_inventory.has_item_quantity(COMMON_SCRAP, 1)).is_false()


func test_consume_by_type_never_dips_into_lures_when_short() -> void:
	_add(LURE, 10)
	_add(COMMON_SCRAP, 2)

	var consumed: int = _inventory.consume_by_type("Material", 5, false)

	assert_int(consumed).is_equal(2)
	assert_bool(_inventory.has_item_quantity(LURE, 10)).is_true()
