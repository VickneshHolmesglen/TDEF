## Integration tests for Story 007 (epic-10-sanctuary-ui, ADR-0032): Room
## Lifecycle -- destroy-and-recreate on every switch, the exact 2-step
## synchronous teardown order (disconnect subscriptions, then gate
## unhandled-input, then queue_free()), fresh InputModeTracker per mount, and
## nested-state-never-survives-a-switch (GDD Core Rule 6, AC Group 6).
##
## Exercises RoomHost directly against RoomLifecycleStubRoom (this directory)
## rather than a real room -- Story 005 (mapping real room scenes into this
## mechanism) is not yet implemented, matching Story 001's own precedent of
## testing RoomHost's rect math against a stub before real content existed.
extends GdUnitTestSuite

const StubRoomScene: PackedScene = preload("res://tests/integration/sanctuary-ui/RoomLifecycleStubRoom.tscn")

var _runner: GdUnitSceneRunner
var _shell: SanctuaryUI
var _room_host: RoomHost


func before_test() -> void:
	RoomLifecycleStubRoom.reset_call_log()
	_runner = scene_runner("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as SanctuaryUI
	_room_host = _shell.get_room_host() as RoomHost


# ---------------------------------------------------------------------------
# Fresh instance + fresh InputModeTracker per mount, not reused
# ---------------------------------------------------------------------------

func test_mounting_a_room_creates_a_fresh_instance_and_fresh_tracker() -> void:
	_room_host.mount_room(StubRoomScene, &"ROOM_MENAGERIE")
	var first_room: Node = _room_host.get_current_room()
	var first_tracker: InputModeTracker = _room_host.get_current_room_tracker()

	_room_host.mount_room(StubRoomScene, &"ROOM_EQUIPMENT_FORGE")
	_room_host.mount_room(StubRoomScene, &"ROOM_MENAGERIE")
	var second_room: Node = _room_host.get_current_room()
	var second_tracker: InputModeTracker = _room_host.get_current_room_tracker()

	assert_bool(first_room == second_room).is_false()
	assert_bool(first_tracker == second_tracker).is_false()
	assert_bool(is_instance_valid(second_room)).is_true()
	assert_bool(is_instance_valid(second_tracker)).is_true()


# ---------------------------------------------------------------------------
# Exact 2-step teardown order, before queue_free() -- call-order inspection,
# not just eventual absence from the tree
# ---------------------------------------------------------------------------

func test_teardown_disconnects_subscriptions_then_gates_input_before_queue_free() -> void:
	_room_host.mount_room(StubRoomScene, &"ROOM_MENAGERIE")
	var room: Node = _room_host.get_current_room()
	RoomLifecycleStubRoom.reset_call_log()  # clear the "ready" entry from mount

	_room_host.unmount_current_room()

	# disconnect_own_subscriptions() must precede exit_tree() (queue_free()'s
	# eventual effect) -- exact call-order assertion, matching the story's own
	# QA requirement, not just "the node is gone eventually."
	assert_array(RoomLifecycleStubRoom.call_log).is_equal(["disconnect_own_subscriptions"])
	# queue_free() is deferred to end-of-frame -- exit_tree hasn't fired yet,
	# but unhandled-input processing must already be gated synchronously,
	# right now, before that deferred removal even begins.
	assert_bool(room.is_processing_unhandled_input()).is_false()


func test_unmounting_with_no_room_mounted_is_a_safe_no_op() -> void:
	_room_host.unmount_current_room()
	assert_object(_room_host.get_current_room()).is_null()


# ---------------------------------------------------------------------------
# Nested state never survives a lateral switch -- fresh mount always at root
# ---------------------------------------------------------------------------

func test_nested_state_never_survives_a_lateral_switch() -> void:
	_room_host.mount_room(StubRoomScene, &"ROOM_MENAGERIE")
	var first_room: RoomLifecycleStubRoom = _room_host.get_current_room() as RoomLifecycleStubRoom
	first_room.nested_state = "mid_breeding_pen_flow"

	_room_host.mount_room(StubRoomScene, &"ROOM_EQUIPMENT_FORGE")
	_room_host.mount_room(StubRoomScene, &"ROOM_MENAGERIE")
	var second_room: RoomLifecycleStubRoom = _room_host.get_current_room() as RoomLifecycleStubRoom

	assert_str(second_room.nested_state).is_equal("root")


# ---------------------------------------------------------------------------
# Focus independence across a room switch -- a fresh tracker never inherits
# the outgoing room's tracker state (and can't, since it's a new instance)
# ---------------------------------------------------------------------------

func test_new_room_tracker_is_independent_of_the_outgoing_room_tracker() -> void:
	_room_host.mount_room(StubRoomScene, &"ROOM_MENAGERIE")
	var first_tracker: InputModeTracker = _room_host.get_current_room_tracker()
	first_tracker._input(InputEventKey.new())  # forces KEYBOARD_GAMEPAD mode explicitly

	_room_host.mount_room(StubRoomScene, &"ROOM_EQUIPMENT_FORGE")
	var second_tracker: InputModeTracker = _room_host.get_current_room_tracker()

	# Independent instance -- not a shared/reused object carrying over state.
	# (Not asserting is_instance_valid(first_tracker) == false here: queue_free()
	# defers actual removal to end-of-frame, so the outgoing tracker is still a
	# technically-valid orphan the instant after mount_room() returns -- that's
	# expected Godot behavior, not a defect. Object identity divergence above
	# is what actually proves "not the same tracker," independent of GC timing.)
	assert_bool(first_tracker == second_tracker).is_false()


# ---------------------------------------------------------------------------
# Signals fire correctly around mount/unmount
# ---------------------------------------------------------------------------

func test_room_mounted_and_unmounted_signals_carry_the_correct_state_label() -> void:
	var mounted_states: Array[StringName] = []
	var unmounted_states: Array[StringName] = []
	_room_host.room_mounted.connect(func(state: StringName) -> void: mounted_states.append(state))
	_room_host.room_unmounted.connect(func(state: StringName) -> void: unmounted_states.append(state))

	_room_host.mount_room(StubRoomScene, &"ROOM_DEFENSE_BUILDING")
	_room_host.unmount_current_room()

	assert_array(mounted_states).is_equal([&"ROOM_DEFENSE_BUILDING"])
	assert_array(unmounted_states).is_equal([&"ROOM_DEFENSE_BUILDING"])
