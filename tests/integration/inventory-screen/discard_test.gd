extends GdUnitTestSuite

## Discard (design/quick-specs/inventory-discard-2026-11-03.md): right-click,
## Delete or gamepad X on a bag slot asks to discard the whole stack/item;
## confirming removes it and emits item_removed; equipped items are refused.
## The bag-clog finding behind it: production/balance/progression-targets.md.

var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	GInventory.reset_to_defaults()
	GMissionSelect.reset_to_defaults()
	_runner = scene_runner("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn")
	_screen = _runner.scene() as Control


func after_test() -> void:
	GInventory.reset_to_defaults()
	GMissionSelect.reset_to_defaults()


func _right_click() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	return ev


func _hide_slot(quantity: int) -> int:
	var hide: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"goblin_hide")
	if quantity > 0:
		GInventory.add_stackable(hide, quantity)
	for i: int in range(GInventory.get_slot_count()):
		if String(GInventory.get_slot_contents(i).get("item_id", "")) == "goblin_hide":
			return i
	return -1


func test_discard_right_click_asks_then_confirm_removes_the_stack() -> void:
	var idx: int = _hide_slot(40)
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.item_removed)

	_screen._on_slot_gui_input(_right_click(), idx)

	var dialog: ConfirmationDialog = _screen.get_discard_dialog()
	assert_bool(dialog.visible).is_true()
	assert_str(dialog.dialog_text).contains("40")
	assert_str(dialog.dialog_text).contains("Goblin Hide")
	assert_bool(GInventory.is_slot_empty(idx)).is_false()  # nothing gone until confirmed

	dialog.confirmed.emit()

	assert_bool(GInventory.is_slot_empty(idx)).is_true()
	var args: Array = (spy.emissions["item_removed"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal("goblin_hide")
	assert_int(args[2] as int).is_equal(40)
	spy.disconnect_all()


func test_discard_cancel_keeps_the_stack() -> void:
	var idx: int = _hide_slot(12)
	assert_bool(_screen.request_discard(idx)).is_true()

	_screen.get_discard_dialog().canceled.emit()
	_screen._on_discard_confirmed()  # a stray confirm after cancel does nothing

	assert_int(GInventory.get_slot_contents(idx)["quantity"] as int).is_equal(12)


func test_discard_refuses_empty_and_equipped_slots() -> void:
	var empty_idx: int = -1
	for i: int in range(GInventory.get_slot_count()):
		if GInventory.is_slot_empty(i) and not GInventory.is_equipment_slot_index(i):
			empty_idx = i
			break
	assert_bool(_screen.request_discard(empty_idx)).is_false()

	GInventory.equip_from_slot(GInventory.add_unique_item(GGameDataRegistry.get_item_definition(&"brutes_war_helm")))
	assert_bool(_screen.request_discard(Inventory.EQUIPMENT_SLOT_INDEX["helmet"])).is_false()
	assert_bool(GInventory.get_equipped_item("helmet").is_empty()).is_false()


func test_discard_input_is_right_click_delete_or_gamepad_x() -> void:
	var script: GDScript = _screen.get_script()
	assert_bool(script.call("is_discard_input", _right_click())).is_true()
	var del := InputEventKey.new()
	del.keycode = KEY_DELETE
	del.pressed = true
	assert_bool(script.call("is_discard_input", del)).is_true()
	del.echo = true
	assert_bool(script.call("is_discard_input", del)).is_false()  # held key doesn't repeat-discard
	var x := InputEventJoypadButton.new()
	x.button_index = JOY_BUTTON_X
	x.pressed = true
	assert_bool(script.call("is_discard_input", x)).is_true()
	var left := _right_click()
	left.button_index = MOUSE_BUTTON_LEFT
	assert_bool(script.call("is_discard_input", left)).is_false()


## The point of the feature: freeing a slot lets held Ascendant Shards in.
func test_discard_frees_room_for_held_shards() -> void:
	var hide: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"goblin_hide")
	GInventory.add_stackable(hide, GInventory.stackable_room(hide))
	GMissionSelect._held_shards = 30
	var idx: int = _hide_slot(0)

	assert_bool(GInventory.discard_slot(idx)).is_true()
	await await_idle_frame()  # delivery is deferred

	assert_int(GInventory.count_by_material_id(AscensionRewards.SHARD_ITEM_ID)).is_equal(30)
	assert_int(GMissionSelect.get_held_shards()).is_equal(0)
