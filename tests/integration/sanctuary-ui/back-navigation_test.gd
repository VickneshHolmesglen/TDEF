## Integration tests for Story 008 (epic-10-sanctuary-ui, ADR-0011): Back
## Navigation -- Cancel steps back one nested stage within a room, or exits
## to OVERVIEW from a room's own root; no-op with no room active (GDD Core
## Rule 7, AC Group 7 + the Load-Bearing Edge Case Cancel no-op item).
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _shell: SanctuaryUI


func before_test() -> void:
	TabStrip.reset_onboarding_flag_for_tests()
	_runner = scene_runner("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as SanctuaryUI


func _press_cancel() -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	_shell._input(event)


# ---------------------------------------------------------------------------
# AC-1: Cancel steps back one nested stage, room's own state unchanged
# ---------------------------------------------------------------------------

func test_cancel_steps_back_one_nested_stage_room_stays_active() -> void:
	# BackNavigationStubRoom isn't a scene by itself -- attach it directly to
	# a bare Control instance and mount that through RoomHost, matching how a
	# real room's script would be attached to its own root node.
	var stub_scene := PackedScene.new()
	var stub_root := Control.new()
	var stub_script: GDScript = load("res://tests/integration/sanctuary-ui/back_navigation_stub_room.gd")
	stub_root.set_script(stub_script)
	stub_scene.pack(stub_root)
	stub_root.free()

	_shell.set_active_state(&"ROOM_EQUIPMENT_FORGE")
	_shell.get_room_host().mount_room(stub_scene, &"ROOM_EQUIPMENT_FORGE")
	var room: BackNavigationStubRoom = _shell.get_room_host().get_current_room() as BackNavigationStubRoom
	assert_bool(room.has_nested_state).is_true()

	_press_cancel()

	assert_that(_shell.get_active_state()).is_equal(&"ROOM_EQUIPMENT_FORGE")
	assert_bool(room.has_nested_state).is_false()
	assert_object(_shell.get_room_host().get_current_room()).is_same(room)


func test_second_cancel_from_room_root_exits_to_overview() -> void:
	var stub_scene := PackedScene.new()
	var stub_root := Control.new()
	var stub_script: GDScript = load("res://tests/integration/sanctuary-ui/back_navigation_stub_room.gd")
	stub_root.set_script(stub_script)
	stub_scene.pack(stub_root)
	stub_root.free()

	_shell.set_active_state(&"ROOM_EQUIPMENT_FORGE")
	_shell.get_room_host().mount_room(stub_scene, &"ROOM_EQUIPMENT_FORGE")

	_press_cancel()  # consumes nested state, stays in the room
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_EQUIPMENT_FORGE")

	_press_cancel()  # at root now -- exits

	assert_that(_shell.get_active_state()).is_equal(&"OVERVIEW")
	assert_object(_shell.get_room_host().get_current_room()).is_null()


# ---------------------------------------------------------------------------
# AC-2: a room with no nested state (or no handle_cancel() at all) exits to
# OVERVIEW on the first Cancel -- InventoryScreen has no staged/nested
# confirmation state of its own today
# ---------------------------------------------------------------------------

func test_cancel_from_a_room_with_no_nested_state_exits_immediately() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()  # real Inventory & Crafting
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_INVENTORY_CRAFTING")

	_press_cancel()

	assert_that(_shell.get_active_state()).is_equal(&"OVERVIEW")
	assert_object(_shell.get_room_host().get_current_room()).is_null()


# ---------------------------------------------------------------------------
# Cancel with no room open (tab strip focus, OVERVIEW) is a genuine no-op
# ---------------------------------------------------------------------------

func test_cancel_with_no_room_open_is_a_no_op() -> void:
	assert_that(_shell.get_active_state()).is_equal(&"OVERVIEW")

	_press_cancel()

	assert_that(_shell.get_active_state()).is_equal(&"OVERVIEW")
