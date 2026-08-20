## Unit tests for Inventory.has_items_by_material_id()/consume_by_material_id()
## (2026-08-17, Tower Components blueprint-sourced recipes). Mirrors
## has_items_by_rarity_test.gd's structure, but sums by slot.item_id
## directly — a third aggregation axis alongside item_type (has_items()) and
## rarity (has_items_by_rarity()), needed when a recipe must gate on one
## exact material (e.g. foundation_surplus) rather than any item sharing its
## type or rarity. Unlike the rarity axis, this one needs no
## GGameDataRegistry lookup to determine "which bucket" an item falls into
## (the item_id IS the bucket), so synthetic definitions are sufficient —
## no dependency on real registered content.
extends GdUnitTestSuite

const FOUNDATION_SURPLUS: StringName = &"foundation_surplus"
const WEAPON_SURPLUS: StringName = &"weapon_surplus"

var _inventory: Inventory


func before_test() -> void:
	_inventory = Inventory.new()
	_inventory.reset_to_defaults()


func after_test() -> void:
	if _inventory != null and is_instance_valid(_inventory):
		_inventory.free()
	_inventory = null


func _make_stackable_definition(item_id: StringName) -> ItemDefinitionResource:
	var def := ItemDefinitionResource.new()
	def.item_id = item_id
	def.item_type = &"Material"
	def.display_name = String(item_id)
	def.is_unique_instance = false
	return def


func test_has_items_by_material_id_empty_cost_returns_true_trivially() -> void:
	assert_bool(_inventory.has_items_by_material_id({})).is_true()


func test_has_items_by_material_id_sufficient_returns_true() -> void:
	_inventory.add_stackable(_make_stackable_definition(FOUNDATION_SURPLUS), 2)
	assert_bool(_inventory.has_items_by_material_id({&"foundation_surplus": 2})).is_true()


func test_has_items_by_material_id_insufficient_returns_false() -> void:
	_inventory.add_stackable(_make_stackable_definition(FOUNDATION_SURPLUS), 1)
	assert_bool(_inventory.has_items_by_material_id({&"foundation_surplus": 2})).is_false()


## The whole point of this axis: two materials sharing item_type=Material
## must NOT cross-count against a specific-material requirement — this is
## exactly the gap has_items() (item_type-keyed) and has_items_by_rarity()
## (rarity-keyed) cannot close.
func test_has_items_by_material_id_different_materials_do_not_cross_count() -> void:
	_inventory.add_stackable(_make_stackable_definition(WEAPON_SURPLUS), 10)
	assert_bool(_inventory.has_items_by_material_id({&"foundation_surplus": 1})).is_false()
	assert_bool(_inventory.has_items_by_material_id({&"weapon_surplus": 1})).is_true()


func test_consume_by_material_id_deducts_correct_quantity() -> void:
	_inventory.add_stackable(_make_stackable_definition(FOUNDATION_SURPLUS), 5)
	var consumed: int = _inventory.consume_by_material_id(FOUNDATION_SURPLUS, 2, false)
	assert_int(consumed).is_equal(2)
	assert_bool(_inventory.has_items_by_material_id({&"foundation_surplus": 4})).is_false()
	assert_bool(_inventory.has_items_by_material_id({&"foundation_surplus": 3})).is_true()


func test_consume_by_material_id_never_touches_a_different_material() -> void:
	_inventory.add_stackable(_make_stackable_definition(FOUNDATION_SURPLUS), 5)
	_inventory.add_stackable(_make_stackable_definition(WEAPON_SURPLUS), 5)
	_inventory.consume_by_material_id(FOUNDATION_SURPLUS, 5, false)
	assert_bool(_inventory.has_items_by_material_id({&"weapon_surplus": 5})).is_true()
