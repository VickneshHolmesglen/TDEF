## Integration tests for Story 009 (epic-10-sanctuary-ui, ADR-0020/ADR-0001):
## Exit -- Launch/Depart to Mission Select, Terminal Latch (GDD Core Rule 8,
## AC Group 8 + the DEPARTING-specific States/Transitions and terminal-latch
## Edge Cases items).
##
## See sanctuary_ui.gd's own confirm_launch_depart() doc comment for a real,
## flagged gap: no resolved "hand off to Mission Select's browsing screen"
## API exists in this project (ADR-0002 only defines 2 top-level scenes,
## matching the GDD's own OQ-2). These tests cover the terminal-latch state
## machine, which IS fully real and testable, not the unresolved hand-off.
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _shell: SanctuaryUI


func before_test() -> void:
	TabStrip.reset_onboarding_flag_for_tests()
	_runner = scene_runner("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as SanctuaryUI


# ---------------------------------------------------------------------------
# AC-1: Launch/Depart is OVERVIEW-only, as a code-level guarantee
# ---------------------------------------------------------------------------

func test_confirm_launch_depart_from_a_room_state_is_a_no_op() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()  # Inventory & Crafting
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_INVENTORY_CRAFTING")

	_shell.confirm_launch_depart()

	assert_that(_shell.get_active_state()).is_equal(&"ROOM_INVENTORY_CRAFTING")
	assert_bool(_shell.is_departing()).is_false()


# ---------------------------------------------------------------------------
# AC-2: OVERVIEW + confirm -> DEPARTING
# ---------------------------------------------------------------------------

func test_confirm_launch_depart_from_overview_enters_departing() -> void:
	assert_that(_shell.get_active_state()).is_equal(&"OVERVIEW")

	_shell.confirm_launch_depart()

	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING")
	assert_bool(_shell.is_departing()).is_true()


# ---------------------------------------------------------------------------
# AC-3 (via Story 002/005's own already-tested internal navigation): confirm
# no EventBus event fires on internal tab switches, only the eventual
# hand-off call. Scoped here to the specific claim this story adds: entering
# DEPARTING is exactly one state transition, not an EventBus emission.
# ---------------------------------------------------------------------------

func test_internal_navigation_before_departing_fires_no_scene_transition_completed() -> void:
	var received: Array = []
	var handler := func(target: String, mission_id: String) -> void:
		received.append([target, mission_id])
	GEventBus.scene_transition_completed.connect(handler)

	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()
	_shell.get_tab_strip_for_test().get_tab_button(0).pressed.emit()

	assert_array(received).is_empty()
	GEventBus.scene_transition_completed.disconnect(handler)


# ---------------------------------------------------------------------------
# AC-4 (DEPARTING is a pure transitional state): no player action changes
# anything while departing
# ---------------------------------------------------------------------------

func test_departing_blocks_further_launch_depart_tabs_and_cancel() -> void:
	_shell.confirm_launch_depart()
	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING")

	_shell.confirm_launch_depart()  # 2nd Launch/Depart -- no-op
	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING")

	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()  # tab select
	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING")

	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	_shell._input(cancel_event)
	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING")


# ---------------------------------------------------------------------------
# Double-press guard: only one DEPARTING entry, no duplicate hand-off call
# ---------------------------------------------------------------------------

func test_double_press_within_same_frame_produces_only_one_departing_entry() -> void:
	_shell.confirm_launch_depart()
	var first_state: StringName = _shell.get_active_state()

	_shell.confirm_launch_depart()

	assert_that(_shell.get_active_state()).is_equal(first_state)
	assert_bool(_shell.is_departing()).is_true()


# ---------------------------------------------------------------------------
# Terminal latch discards EventBus events during DEPARTING -- both regular
# events and the CONNECT_DEFERRED-already-queued race
# ---------------------------------------------------------------------------

func test_sanctuary_structure_built_discarded_during_departing() -> void:
	_shell.confirm_launch_depart()
	var count_before: int = _shell.get_built_structure_ids().size()

	GEventBus.sanctuary_structure_built.emit("watchtower", "defensive")

	assert_int(_shell.get_built_structure_ids().size()).is_equal(count_before)


func test_scene_transition_completed_discarded_during_departing() -> void:
	_shell.confirm_launch_depart()
	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING")

	GEventBus.scene_transition_completed.emit("SANCTUARY", "")

	# Would normally re-mount to OVERVIEW (Story 006) -- must NOT while
	# departing, confirming the latch, not just Story 006's own logic, is
	# what's gating this.
	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING")


func test_disconnect_not_just_flag_closes_the_connect_deferred_race() -> void:
	# Confirms the guarantee is structural (the subscription itself is gone),
	# not merely a flag check inside the handler -- reconnecting a NEW
	# listener to the same signal after departing and confirming SanctuaryUI's
	# own handler is genuinely absent from the connection list is the direct
	# way to test "disconnected," as distinct from "would no-op if called."
	_shell.confirm_launch_depart()

	assert_bool(
		GEventBus.sanctuary_structure_built.is_connected(_shell._on_sanctuary_structure_built)
	).is_false()
	assert_bool(
		GEventBus.scene_transition_completed.is_connected(_shell._on_scene_transition_completed)
	).is_false()
