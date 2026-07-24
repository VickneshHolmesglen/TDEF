## Integration tests for Story 005 (epic-10-sanctuary-ui, ADR-0002): Room
## Hosting -- real room scenes mounted into RoomHost via Story 007's generic
## mount/unmount mechanism (GDD Core Rule 4, AC Group 4 + States/Transitions
## room-entry regression items).
##
## Only ROOM_INVENTORY_CRAFTING has a real scene as of this story --
## Menagerie/Defense Building/Equipment Forge don't exist anywhere in this
## project yet (confirmed by direct search, matches the GDD's own OQ-5).
## These tests cover what IS real: InventoryScreen docks cleanly with no
## CanvasLayer (the Core Rule 1 z-order guarantee this whole shell depends
## on), mounts/unmounts correctly through the tab strip, and the 3 unmapped
## rooms fail safe (no crash, no fabricated content) rather than being
## silently skipped from test coverage.
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
# Unmapped rooms (no real scene yet) fail safe -- no crash, RoomHost stays
# empty rather than hosting fabricated content
# ---------------------------------------------------------------------------

func test_unmapped_room_selection_does_not_crash_and_hosts_nothing() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(2).pressed.emit()  # Menagerie -- no scene yet

	assert_that(_shell.get_active_state()).is_equal(&"ROOM_MENAGERIE")
	assert_object(_shell.get_room_host().get_current_room()).is_null()
	# RoomHost is still the visible content zone (Story 001's own AC-2/AC-3
	# contract) even with nothing mounted into it -- this is "empty," not
	# "broken."
	assert_bool(_shell.get_room_host().visible).is_true()
	assert_bool(_shell.get_diorama().visible).is_false()


func test_switching_from_inventory_crafting_to_an_unmapped_room_unmounts_cleanly() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()  # Inventory & Crafting
	assert_object(_shell.get_room_host().get_current_room()).is_not_null()

	_shell.get_tab_strip_for_test().get_tab_button(3).pressed.emit()  # Defense Building -- no scene yet

	assert_object(_shell.get_room_host().get_current_room()).is_null()
