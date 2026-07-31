## Unit tests for InputModeTracker (ADR-0011 — UI Dual-Focus Handling).
##
## No dedicated unit test file existed for this class before now — it was
## only exercised indirectly via screen-level integration tests. Added
## alongside TD-ui-001 item 2's deadzone-guard fix (2026-08-01): raw
## InputEventJoypadMotion reaching _input() is not deadzone-filtered by
## Godot itself, so a resting controller's axis noise could previously
## flip the tracker's mode away from MOUSE/KEYBOARD_GAMEPAD spuriously.
extends GdUnitTestSuite

var _tracker: InputModeTracker


func before_test() -> void:
	_tracker = InputModeTracker.new()


func after_test() -> void:
	if _tracker != null and is_instance_valid(_tracker):
		_tracker.free()
	_tracker = null


func test_default_mode_is_keyboard_gamepad() -> void:
	assert_bool(_tracker.is_focus_ring_visible()).is_true()


func test_mouse_motion_switches_to_mouse_mode() -> void:
	var event := InputEventMouseMotion.new()
	_tracker._input(event)

	assert_bool(_tracker.is_focus_ring_visible()).is_false()


func test_joypad_button_switches_to_keyboard_gamepad_mode_from_mouse() -> void:
	_tracker._input(InputEventMouseMotion.new())
	assert_bool(_tracker.is_focus_ring_visible()).is_false()

	var button_event := InputEventJoypadButton.new()
	_tracker._input(button_event)

	assert_bool(_tracker.is_focus_ring_visible()).is_true()


## TD-ui-001 item 2: a resting controller's low-magnitude axis noise must
## not flip the tracker away from MOUSE mode.
func test_joypad_motion_below_deadzone_does_not_switch_mode() -> void:
	_tracker._input(InputEventMouseMotion.new())
	assert_bool(_tracker.is_focus_ring_visible()).is_false()

	var motion_event := InputEventJoypadMotion.new()
	motion_event.axis_value = 0.1  # well under the 0.5 deadzone
	_tracker._input(motion_event)

	assert_bool(_tracker.is_focus_ring_visible()).is_false()  # still MOUSE


func test_joypad_motion_at_or_above_deadzone_switches_mode() -> void:
	_tracker._input(InputEventMouseMotion.new())
	assert_bool(_tracker.is_focus_ring_visible()).is_false()

	var motion_event := InputEventJoypadMotion.new()
	motion_event.axis_value = 0.5  # exactly at the deadzone threshold
	_tracker._input(motion_event)

	assert_bool(_tracker.is_focus_ring_visible()).is_true()


func test_joypad_motion_below_deadzone_on_negative_axis_does_not_switch_mode() -> void:
	_tracker._input(InputEventMouseMotion.new())
	assert_bool(_tracker.is_focus_ring_visible()).is_false()

	var motion_event := InputEventJoypadMotion.new()
	motion_event.axis_value = -0.2  # negative axis, still below deadzone in magnitude
	_tracker._input(motion_event)

	assert_bool(_tracker.is_focus_ring_visible()).is_false()


func test_input_mode_changed_signal_fires_only_on_real_transition() -> void:
	var received: Array = []
	var handler := func(mode: InputModeTracker.InputMode) -> void:
		received.append(mode)
	_tracker.input_mode_changed.connect(handler)

	# Sub-deadzone motion first -- must not emit.
	var noise_event := InputEventJoypadMotion.new()
	noise_event.axis_value = 0.05
	_tracker._input(noise_event)
	assert_array(received).is_empty()

	# Real mouse motion -- must emit exactly once.
	_tracker._input(InputEventMouseMotion.new())
	assert_array(received).has_size(1)

	_tracker.input_mode_changed.disconnect(handler)
