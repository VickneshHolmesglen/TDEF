## Integration tests for Story 004 (epic-10-sanctuary-ui, ADR-0001): Persistent
## Resource Header -- read-only gold/materials display, updates on the real
## EventBus deltas, never focusable (GDD Core Rule 3, AC Group 3).
##
## See resource_header.gd's own class doc for a real, flagged architectural
## gap: no system in this project currently owns a queryable Sanctuary-context
## gold/materials balance, so the GDD's "mount-time poll fallback" Edge Case
## is not implementable as literally specified -- these tests cover the local-
## accumulation behavior that IS implemented, not the unimplementable poll.
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _shell: SanctuaryUI
var _header: ResourceHeader


func before_test() -> void:
	_runner = scene_runner("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as SanctuaryUI
	_header = _shell.get_resource_header()


# ---------------------------------------------------------------------------
# Displays identically regardless of active state
# ---------------------------------------------------------------------------

func test_header_value_identical_across_overview_and_room_states() -> void:
	GEventBus.resources_changed.emit(120, &"test_source")
	GEventBus.materials_earned.emit("wood", 5, "test_source")

	assert_int(_header.get_gold()).is_equal(120)
	assert_int(_header.get_material_quantity("wood")).is_equal(5)

	_shell.set_active_state(&"ROOM_MENAGERIE")

	# Header is chrome, held outside the OVERVIEW/RoomHost branch entirely
	# (Story 001's own AC-4 guarantee) -- its own accumulated values are
	# untouched by an active-state switch.
	assert_int(_header.get_gold()).is_equal(120)
	assert_int(_header.get_material_quantity("wood")).is_equal(5)


# ---------------------------------------------------------------------------
# Sequential event updates apply in order, no stale intermediate value
# ---------------------------------------------------------------------------

func test_sequential_events_apply_in_order() -> void:
	GEventBus.materials_earned.emit("wood", 10, "test_source")
	assert_int(_header.get_material_quantity("wood")).is_equal(10)

	GEventBus.materials_spent.emit("wood", 3, "test_destination")
	assert_int(_header.get_material_quantity("wood")).is_equal(7)

	GEventBus.resources_changed.emit(50, &"test_source")
	assert_int(_header.get_gold()).is_equal(50)

	GEventBus.resources_changed.emit(-20, &"test_source")
	assert_int(_header.get_gold()).is_equal(30)


# ---------------------------------------------------------------------------
# Never focusable / not a navigable region
# ---------------------------------------------------------------------------

func test_header_never_receives_focus() -> void:
	assert_int(_header.focus_mode).is_equal(Control.FOCUS_NONE)

	_header.grab_focus()

	assert_bool(_header.has_focus()).is_false()
