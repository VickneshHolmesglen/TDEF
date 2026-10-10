class_name ScreenHost
extends Control

## Tarot Deck UI screen-hosting lifecycle (Story 003, ADR-0032, epic-11-tarot-deck-ui).
##
## GDD source: design/gdd/tarot-deck-ui.md -- Core Rule 5, AC Group 3.
## ADR: docs/architecture/adr-0032-presentation-shell-hosting-pattern.md
## Story: production/epics/epic-11-tarot-deck-ui/story-003-exit-and-lifecycle.md
##
## Identical mechanism to Sanctuary UI's RoomHost (src/presentation/sanctuary_ui/room_host.gd)
## -- ADR-0032 formalizes this as ONE shared pattern for both shells, this is
## the second, independent implementation of it (Section 3 of that ADR
## explicitly accepted 2 independent implementations over 1 shared component,
## since only 2 consumers exist -- see that ADR's own Alternative 3).
##
## Screen contract (same shape as RoomHost's room contract):
## disconnect_own_subscriptions() -> void, duck-typed via has_method(), called
## before set_process_unhandled_input(false) and queue_free(), in that order.

signal screen_mounted(state: StringName)
signal screen_unmounted(state: StringName)

var _current_screen: Node
var _current_screen_state: StringName = &""


func mount_screen(scene: PackedScene, state: StringName) -> void:
	unmount_current_screen()
	_current_screen = scene.instantiate()
	_current_screen_state = state
	add_child(_current_screen)
	# Same 16 px gutter RoomHost gives Sanctuary rooms (2026-10-10 UI pass);
	# this host's own rect is unchanged.
	if _current_screen is Control:
		var screen: Control = _current_screen as Control
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen.offset_left = RoomHost.ROOM_PADDING
		screen.offset_top = RoomHost.ROOM_PADDING
		screen.offset_right = -RoomHost.ROOM_PADDING
		screen.offset_bottom = -RoomHost.ROOM_PADDING
	screen_mounted.emit(state)


func unmount_current_screen() -> void:
	if _current_screen == null:
		return
	var outgoing: Node = _current_screen
	var outgoing_state: StringName = _current_screen_state
	if outgoing.has_method(&"disconnect_own_subscriptions"):
		outgoing.disconnect_own_subscriptions()
	if outgoing.has_method(&"set_process_unhandled_input"):
		outgoing.set_process_unhandled_input(false)
	outgoing.queue_free()
	_current_screen = null
	_current_screen_state = &""
	screen_unmounted.emit(outgoing_state)


func get_current_screen() -> Node:
	return _current_screen


func get_current_screen_state() -> StringName:
	return _current_screen_state
