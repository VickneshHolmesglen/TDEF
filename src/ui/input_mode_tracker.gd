class_name InputModeTracker
extends Node

## Reusable, per-screen input-mode detector (ADR-0011 — UI Dual-Focus Handling).
##
## ADR: docs/architecture/adr-0011-ui-dual-focus-handling.md
## Story: production/epics/epic-03-core-economy/story-007-two-panel-screen-presentation.md
##
## Instanced as a child Node of each interactive UI screen that needs
## input-mode-aware focus rings (starting with InventoryScreen, Story 007) —
## NOT an Autoload (ADR-0002 classifies all Presentation-layer/UI concerns as
## scene-instanced; a screen's "what input method is the player currently
## using" state has no meaning outside that screen's own lifetime).
##
## Detection uses _input(), not _unhandled_input(): Controls with
## mouse_filter = STOP (the default for Button/TextureButton) consume click
## events before they would ever reach _unhandled_input(), which would cause
## this tracker to miss every click on a focusable widget. This is a sibling
## Node (not itself a Control competing for input), so _input() observes
## every event regardless of what a child Control consumes.

enum InputMode { MOUSE, KEYBOARD_GAMEPAD }

signal input_mode_changed(mode: InputMode)

## Defaults to KEYBOARD_GAMEPAD: matches inventory.md's own default — "input
## focus defaulting to the first occupied slot in the active tab" on screen
## open, before any mouse motion has occurred.
var _current_mode: InputMode = InputMode.KEYBOARD_GAMEPAD


func _input(event: InputEvent) -> void:
	var detected: InputMode
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		detected = InputMode.MOUSE
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		detected = InputMode.KEYBOARD_GAMEPAD
	else:
		return  # ignore other event types (e.g. InputEventScreenTouch — out of scope, Touch Support: None)
	if detected != _current_mode:
		_current_mode = detected
		input_mode_changed.emit(_current_mode)


## true when the last detected input was keyboard/gamepad — the visibility
## condition every focusable widget's focus-ring overlay must gate on,
## combined with that widget's own has_focus() (ADR-0011 Decision).
func is_focus_ring_visible() -> bool:
	return _current_mode == InputMode.KEYBOARD_GAMEPAD
