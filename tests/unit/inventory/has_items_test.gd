## Unit tests for Inventory.has_items() (Story 022 prerequisite fix, ADR-0021).
##
## Exercises the real GGameDataRegistry Autoload content
## (res://assets/data/items/common_scrap.tres, iron_ore.tres,
## menagerie_lure.tres — all item_type = &"Material") to resolve item_id ->
## item_type, same rationale as every other GameDataRegistry-backed test in
## this project: these are the actual authored definitions, not synthetic
## fixtures.
##
## Inventory is instantiated directly (Inventory.new() + reset_to_defaults()),
## matching slot_stack_model_test.gd's established convention — avoids the
## GSavePersistence Autoload dependency that add_child()-triggered _ready()
## would introduce.
extends GdUnitTestSuite

const COMMON_SCRAP: StringName = &"common_scrap"
const IRON_ORE: StringName = &"iron_ore"

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


func test_has_items_empty_cost_returns_true_trivially() -> void:
	assert_bool(_inventory.has_items({})).is_true()


func test_has_items_sufficient_single_item_type_returns_true() -> void:
	_inventory.add_stackable(_make_stackable_definition(COMMON_SCRAP), 40)
	assert_bool(_inventory.has_items({&"Material": 40})).is_true()


func test_has_items_insufficient_single_item_type_returns_false() -> void:
	_inventory.add_stackable(_make_stackable_definition(COMMON_SCRAP), 10)
	assert_bool(_inventory.has_items({&"Material": 40})).is_false()


func test_has_items_sums_across_two_stacks_of_different_item_ids_same_item_type() -> void:
	# common_scrap and iron_ore are both item_type = &"Material" — has_items()
	# sums by item_type, not item_id, so two distinct materials both count
	# toward the same &"Material" requirement.
	_inventory.add_stackable(_make_stackable_definition(COMMON_SCRAP), 25)
	_inventory.add_stackable(_make_stackable_definition(IRON_ORE), 25)
	assert_bool(_inventory.has_items({&"Material": 50})).is_true()
	assert_bool(_inventory.has_items({&"Material": 51})).is_false()


func test_has_items_sums_across_two_stacks_of_same_item_id_after_overflow() -> void:
	# add_stackable()'s own overflow behavior splits a large quantity across
	# multiple slots once STACK_CAP_STACKABLE (99) is exceeded — has_items()
	# must sum across all of them, not just the first slot found.
	_inventory.add_stackable(_make_stackable_definition(COMMON_SCRAP), 150)
	assert_bool(_inventory.has_items({&"Material": 150})).is_true()
	assert_bool(_inventory.has_items({&"Material": 151})).is_false()


func test_has_items_unknown_item_id_slots_are_ignored_not_crashed() -> void:
	# A slot whose item_id has no matching ItemDefinitionResource in the
	# registry (content-authoring gap) must not crash has_items() — it's
	# simply excluded from the item_type totals.
	var slot := InventorySlot.new()
	slot.item_id = &"item_does_not_exist"
	slot.instance_id = -1
	slot.quantity = 99
	_inventory._slots[0] = slot
	assert_bool(_inventory.has_items({&"Material": 1})).is_false()
