## Integration tests for Story 005 (epic-10-sanctuary-ui, ADR-0002): Room
## Hosting -- real room scenes mounted into RoomHost via Story 007's generic
## mount/unmount mechanism (GDD Core Rule 4, AC Group 4 + States/Transitions
## room-entry regression items).
##
## As of 2026-07-25, all 4 rooms (ROOM_INVENTORY_CRAFTING, ROOM_MENAGERIE,
## ROOM_DEFENSE_BUILDING, ROOM_EQUIPMENT_FORGE) have real scenes -- the
## "unmapped room fails safe" tests this file used to cover no longer have
## a real example to test against, so they were retargeted (2026-07-25) to
## verify Equipment Forge -- the last room to gain a real scene -- mounts and
## unmounts correctly, mirroring the InventoryScreen tests below rather than
## a fail-safe/no-op assertion.
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _shell: SanctuaryUI


func before_test() -> void:
	TabStrip.reset_onboarding_flag_for_tests()
	_runner = scene_runner("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as SanctuaryUI


# ---------------------------------------------------------------------------
# InventoryScreen docks with no CanvasLayer -- the Core Rule 1 z-order
# guarantee this whole shell's chrome-above-content promise depends on
# ---------------------------------------------------------------------------

func test_inventory_screen_has_no_canvas_layer_anywhere_in_its_subtree() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()  # index 1 = Inventory & Crafting

	var room: Node = _shell.get_room_host().get_current_room()
	assert_object(room).is_not_null()
	assert_bool(_has_canvas_layer_descendant(room)).is_false()


func _has_canvas_layer_descendant(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is CanvasLayer or _has_canvas_layer_descendant(child):
			return true
	return false


# ---------------------------------------------------------------------------
# Selecting Inventory & Crafting via the tab strip mounts the real screen
# ---------------------------------------------------------------------------

func test_selecting_inventory_crafting_tab_mounts_the_real_inventory_screen() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()

	var room: Node = _shell.get_room_host().get_current_room()
	assert_object(room).is_not_null()
	assert_that(_shell.get_room_host().get_current_room_state()).is_equal(&"ROOM_INVENTORY_CRAFTING")


func test_leaving_inventory_crafting_unmounts_it() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()
	assert_object(_shell.get_room_host().get_current_room()).is_not_null()

	_shell.get_tab_strip_for_test().get_tab_button(0).pressed.emit()  # back to Overview

	assert_object(_shell.get_room_host().get_current_room()).is_null()


# ---------------------------------------------------------------------------
# Selecting Equipment Forge via the tab strip mounts the real screen
# (retargeted 2026-07-25 -- was the "unmapped room fails safe" case until
# Equipment Forge, the last room, gained a real scene)
# ---------------------------------------------------------------------------

func test_selecting_equipment_forge_tab_mounts_the_real_screen() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(4).pressed.emit()  # Equipment Forge

	assert_that(_shell.get_active_state()).is_equal(&"ROOM_EQUIPMENT_FORGE")
	assert_object(_shell.get_room_host().get_current_room()).is_not_null()
	assert_that(_shell.get_room_host().get_current_room_state()).is_equal(&"ROOM_EQUIPMENT_FORGE")
	assert_bool(_shell.get_room_host().visible).is_true()
	assert_bool(_shell.get_diorama().visible).is_false()


func test_switching_from_inventory_crafting_to_equipment_forge_unmounts_and_remounts_cleanly() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()  # Inventory & Crafting
	var inventory_room: Node = _shell.get_room_host().get_current_room()
	assert_object(inventory_room).is_not_null()

	_shell.get_tab_strip_for_test().get_tab_button(4).pressed.emit()  # Equipment Forge

	var forge_room: Node = _shell.get_room_host().get_current_room()
	assert_object(forge_room).is_not_null()
	assert_bool(forge_room == inventory_room).is_false()
