extends GdUnitTestSuite

## Salvage (design/quick-specs/inventory-salvage-2026-11-03.md): 20 of a
## Common material -> 1 Refined Alloy (Uncommon), 20 Uncommon -> 1 Refined
## Essence (Rare); the remainder stays; nothing is consumed unless the output
## fits. Offered as a third button on the discard dialog.

var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	GInventory.reset_to_defaults()
	_runner = scene_runner("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn")
	_screen = _runner.scene() as Control


func after_test() -> void:
	GInventory.reset_to_defaults()


func _def(id: StringName) -> ItemDefinitionResource:
	return GGameDataRegistry.get_item_definition(id)


func _slot_of(id: StringName) -> int:
	for i: int in range(GInventory.get_slot_count()):
		if String(GInventory.get_slot_contents(i).get("item_id", "")) == String(id):
			return i
	return -1


func test_salvage_common_stack_makes_alloy_and_keeps_the_remainder() -> void:
	GInventory.add_stackable(_def(&"goblin_hide"), 99)

	assert_int(GInventory.salvage_slot(_slot_of(&"goblin_hide"))).is_equal(4)

	assert_int(GInventory.count_by_material_id(&"goblin_hide")).is_equal(19)
	assert_int(GInventory.count_by_material_id(&"refined_alloy")).is_equal(4)


func test_salvage_uncommon_makes_rare_essence_and_whole_batches_free_the_slot() -> void:
	GInventory.add_stackable(_def(&"iron_ore"), 40)

	assert_int(GInventory.salvage_slot(_slot_of(&"iron_ore"))).is_equal(2)

	assert_int(_slot_of(&"iron_ore")).is_equal(-1)
	assert_int(GInventory.count_by_material_id(&"refined_essence")).is_equal(2)
	assert_str(_def(&"refined_essence").rarity).is_equal("Rare")
	assert_bool(GInventory.has_items_by_rarity({"Rare": 2})).is_true()  # pays rarity-keyed costs


func test_salvage_refuses_rare_small_stacks_and_shards() -> void:
	GInventory.add_stackable(_def(&"goblin_fang"), 60)   # Rare: top of the chain
	GInventory.add_stackable(_def(&"spore_dust"), 19)    # under one batch
	GInventory.add_stackable(_def(AscensionRewards.SHARD_ITEM_ID), 100)

	for id: StringName in [&"goblin_fang", &"spore_dust", AscensionRewards.SHARD_ITEM_ID]:
		assert_int(GInventory.salvage_slot(_slot_of(id))).is_equal(0)
	assert_int(GInventory.count_by_material_id(&"goblin_fang")).is_equal(60)
	assert_int(GInventory.count_by_material_id(&"spore_dust")).is_equal(19)


func test_salvage_with_no_room_for_the_output_consumes_nothing() -> void:
	var hide: ItemDefinitionResource = _def(&"goblin_hide")
	GInventory.add_stackable(hide, GInventory.stackable_room(hide))  # every slot a full hide stack
	GInventory.consume_stackable(hide, 9)  # one stack of 90: partial salvage keeps the slot

	var idx: int = -1
	for i: int in range(GInventory.get_slot_count()):
		if (GInventory.get_slot_contents(i).get("quantity", 0) as int) == 90:
			idx = i
	assert_int(GInventory.salvage_slot(idx)).is_equal(0)
	assert_int(GInventory.get_slot_contents(idx)["quantity"] as int).is_equal(90)


func test_salvage_button_offered_only_when_salvage_is_possible() -> void:
	GInventory.add_stackable(_def(&"goblin_hide"), 45)
	GInventory.add_stackable(_def(&"goblin_fang"), 45)

	assert_bool(_screen.request_discard(_slot_of(&"goblin_hide"))).is_true()
	assert_bool(_screen.get_salvage_button().visible).is_true()
	assert_str(_screen.get_discard_dialog().dialog_text).contains("2 Refined Alloy")
	_screen.get_discard_dialog().hide()

	assert_bool(_screen.request_discard(_slot_of(&"goblin_fang"))).is_true()
	assert_bool(_screen.get_salvage_button().visible).is_false()


## Live check 2026-11-03 (real save, bag full): the button was offered, then
## refused with only the denial sound. Now it's shown greyed out with a reason.
func test_salvage_button_disabled_with_reason_when_output_has_no_room() -> void:
	var hide: ItemDefinitionResource = _def(&"goblin_hide")
	GInventory.add_stackable(hide, GInventory.stackable_room(hide))
	GInventory.consume_stackable(hide, 9)  # a 90 stack: salvage leaves 10, slot stays used
	var idx: int = -1
	for i: int in range(GInventory.get_slot_count()):
		if (GInventory.get_slot_contents(i).get("quantity", 0) as int) == 90:
			idx = i

	assert_bool(_screen.request_discard(idx)).is_true()

	assert_bool(_screen.get_salvage_button().visible).is_true()
	assert_bool(_screen.get_salvage_button().disabled).is_true()
	assert_str(_screen.get_discard_dialog().dialog_text).contains(tr("INVENTORY_SALVAGE_NO_ROOM"))


func test_salvage_button_converts_the_stack() -> void:
	GInventory.add_stackable(_def(&"goblin_hide"), 45)
	_screen.request_discard(_slot_of(&"goblin_hide"))

	_screen.get_discard_dialog().custom_action.emit(&"salvage")

	assert_int(GInventory.count_by_material_id(&"refined_alloy")).is_equal(2)
	assert_int(GInventory.count_by_material_id(&"goblin_hide")).is_equal(5)
	assert_bool(_screen.get_discard_dialog().visible).is_false()
