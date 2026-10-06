extends GdUnitTestSuite

## Integration tests for double-click equip/unequip on the Inventory screen
## (2026-10-07): a double-click on a bag item equips it, on an equipped slot
## (grid or paperdoll frame) unequips it to the bag. Single clicks do nothing.

var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	GInventory.reset_to_defaults()
	_runner = scene_runner("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn")
	_screen = _runner.scene() as Control


func after_test() -> void:
	GInventory.reset_to_defaults()


func _double_click() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.double_click = true
	return ev


func _add_helm() -> int:
	return GInventory.add_unique_item(GGameDataRegistry.get_item_definition(&"brutes_war_helm"))


func test_double_click_on_a_bag_item_equips_it() -> void:
	var idx: int = _add_helm()
	_screen._on_slot_gui_input(_double_click(), idx)
	assert_str(String(GInventory.get_equipped_item("helmet").get("item_id", ""))).is_equal("brutes_war_helm")
	assert_bool(GInventory.is_slot_empty(idx)).is_true()


func test_double_click_on_an_equipped_grid_slot_unequips_it() -> void:
	GInventory.equip_from_slot(_add_helm())
	_screen._on_slot_gui_input(_double_click(), Inventory.EQUIPMENT_SLOT_INDEX["helmet"])
	assert_bool(GInventory.get_equipped_item("helmet").is_empty()).is_true()


func test_a_single_click_does_not_equip() -> void:
	var idx: int = _add_helm()
	var single := _double_click()
	single.double_click = false
	_screen._on_slot_gui_input(single, idx)
	assert_bool(GInventory.get_equipped_item("helmet").is_empty()).is_true()


func test_paperdoll_double_click_unequips_through_the_screen() -> void:
	GInventory.equip_from_slot(_add_helm())
	_screen._equipment_paperdoll.emit_signal(&"slot_unequip_requested", "helmet")
	assert_bool(GInventory.get_equipped_item("helmet").is_empty()).is_true()
