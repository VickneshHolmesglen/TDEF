## Integration test for InventoryScreen's Tab-key focus traversal (TD-ui-002
## item 1). Godot's Tab-key traversal (`ui_focus_next`/`ui_focus_prev`) is a
## separate, automatic algorithm entirely unaffected by inventory_screen.gd's
## own explicit `focus_neighbor_*` wiring (that wiring only governs
## directional arrow-key/D-pad traversal — see _wire_focus_neighbors()'s own
## doc comment). This was previously unexercised by any test; the slot grid's
## own doc comment predicted correct index-order traversal "by incidental
## tree-child order" but that prediction had never been verified.
##
## Player-requested 2026-08-16: empty slots are now hidden (invisible), and
## Godot's automatic ui_focus_next/prev skips non-visible Controls entirely
## — confirmed live via the Godot MCP bridge, pressing Tab from a focused-
## but-invisible slot on a freshly-reset (fully empty) inventory jumps focus
## to the tab strip instead of the next slot. before_test() now seeds 3 real
## Equipment items so slots 0-2 are actually visible/occupied — the default
## active tab is Equipment (Inventory.TAB_ORDER[0]), so no tab switch is
## needed for them to show up, and add_unique_item() allocates the first
## empty slot in order, landing them at indices 0/1/2 exactly as these tests
## already assumed.
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	GInventory.reset_to_defaults()
	for item_id: StringName in [&"iron_sword", &"steel_greatsword", &"reinforced_plate"]:
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(item_id)
		GInventory.add_unique_item(definition)
	_runner = scene_runner("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn")
	_screen = _runner.scene() as Control


func after_test() -> void:
	GInventory.reset_to_defaults()


func _slot_button(index: int) -> Button:
	var slot_buttons: Array = _screen.get("_slot_buttons")
	return slot_buttons[index] as Button


func test_tab_advances_focus_in_slot_index_order() -> void:
	_slot_button(0).grab_focus()
	assert_object(_screen.get_viewport().gui_get_focus_owner()).is_equal(_slot_button(0))

	await _runner.simulate_key_pressed(KEY_TAB)

	assert_object(_screen.get_viewport().gui_get_focus_owner()).is_equal(_slot_button(1))


func test_shift_tab_moves_focus_backward_in_slot_index_order() -> void:
	_slot_button(1).grab_focus()
	assert_object(_screen.get_viewport().gui_get_focus_owner()).is_equal(_slot_button(1))

	await _runner.simulate_key_pressed(KEY_TAB, true)  # shift_pressed=true -> ui_focus_prev

	assert_object(_screen.get_viewport().gui_get_focus_owner()).is_equal(_slot_button(0))


func test_tab_from_the_last_slot_does_not_crash_and_leaves_a_valid_focus() -> void:
	var slot_buttons: Array = _screen.get("_slot_buttons")
	var last_index: int = slot_buttons.size() - 1
	_slot_button(last_index).grab_focus()

	await _runner.simulate_key_pressed(KEY_TAB)

	# Godot's automatic Tab traversal wraps or stops at the end depending on
	# sibling context -- this only asserts the screen survives it with a
	# real, still-focusable Control holding focus (not null/crashed), since
	# wrap-at-edge behavior is inventory.md's own documented Story
	# 002-tab-bar-scope, out of this screen's current interactive scope.
	var focus_owner: Control = _screen.get_viewport().gui_get_focus_owner()
	assert_object(focus_owner).is_not_null()
	assert_bool(focus_owner is Button).is_true()
