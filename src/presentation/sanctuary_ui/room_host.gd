class_name RoomHost
extends Control

## Sanctuary UI room-hosting lifecycle (Story 007, ADR-0032, epic-10-sanctuary-ui).
##
## GDD source: design/gdd/sanctuary-ui.md -- Core Rule 6, AC Group 6.
## ADR: docs/architecture/adr-0032-presentation-shell-hosting-pattern.md
## Story: production/epics/epic-10-sanctuary-ui/story-007-room-lifecycle.md
##
## Owns the GENERIC destroy-and-recreate mount/unmount mechanism this shell's
## rooms share -- NOT the mapping of which real scene backs which ROOM_*
## state, which is Story 005's own separate scope ("Room Hosting"). Story 005
## is not yet implemented (still `Ready`, only InventoryScreen.tscn exists in
## this project as of this story) -- this class is deliberately independently
## testable against a stub room scene, the same pattern Story 001 used for
## RoomHost's own rect math before real content existed. Story 005's future
## work is: register a StringName -> PackedScene map and call mount_room()
## with the right scene per tab-strip selection; nothing about that requires
## changing this class.
##
## Room contract (this shell's own requirement, not a Godot built-in
## interface): any scene hosted here must expose a
## `disconnect_own_subscriptions() -> void` method if it owns EventBus
## subscriptions -- called synchronously before set_process_unhandled_input
## (false) and queue_free(), per ADR-0032 Section 1's exact ordering
## guarantee. Duck-typed via has_method() -- a room with no subscriptions of
## its own (rare, but not impossible) may omit the method entirely.
##
## InputModeTracker ownership, corrected 2026-07-24 per code review: this
## class does NOT construct or inject a tracker -- each room's own scene
## already owns and constructs its own (GDD Core Rule 6: "each work-room
## keeps its own InputModeTracker instance for its internal navigation
## graph... unchanged from each room's own GDD"), confirmed against the one
## real room in this project (inventory_screen.gd's own
## `$InputModeTracker` child, already part of InventoryScreen.tscn). An
## earlier version of this class injected a second, unwired tracker of its
## own -- dead weight no widget in the room ever checked, and a decoy that
## get_current_room_tracker() returned instead of the room's real one. Fixed
## by removing the injection entirely; get_current_room_tracker() now looks
## up the room's own child node by convention instead.

signal room_mounted(state: StringName)
signal room_unmounted(state: StringName)

## Conventional child-node name a hosted room is expected to use for its own
## InputModeTracker, if it has one -- matches InventoryScreen.tscn's actual
## node name. Not a hard requirement (get_current_room_tracker() returns
## null if absent) -- some rooms may have no interactive elements needing one.
const ROOM_TRACKER_NODE_NAME: StringName = &"InputModeTracker"

var _current_room: Node
var _current_room_state: StringName = &""

## Host-owned transition tween (ADR-0032 Section 3 -- never the room
## instance's own), stored so an in-flight slide can be killed before a new
## one starts. Real bug fixed 2026-07-24 per code review: this tween was
## previously a local variable in _play_drawer_slide_in(), meaning rapid
## re-triggering (the GDD's own named Edge Case) left an orphaned tween still
## stepping a Control that unmount_current_room() had already queue_free()'d
## -- exactly the live-target-validity risk ADR-0032 Section 3 exists to
## prevent. Storing it here and killing any prior instance before starting a
## new one closes that gap.
var _transition_tween: Tween


## Destroys any currently-mounted room (per the exact ADR-0032 Section 1
## ordering) then instantiates `scene` fresh as this host's child. `state` is
## purely a label for get_current_room_state() / room_mounted's payload --
## this class does not interpret it.
func mount_room(scene: PackedScene, state: StringName) -> void:
	unmount_current_room()
	_current_room = scene.instantiate()
	_current_room_state = state
	add_child(_current_room)
	_play_drawer_slide_in(_current_room)
	room_mounted.emit(state)


## The room's own InputModeTracker, if its scene defines one at the
## conventional node name -- null otherwise. This host never constructs or
## owns this node; it only looks it up (see class doc for why).
func get_current_room_tracker() -> InputModeTracker:
	if _current_room == null:
		return null
	return _current_room.get_node_or_null(NodePath(ROOM_TRACKER_NODE_NAME)) as InputModeTracker


## GDD Visual/Audio Requirements: literal drawer-slide, horizontal only,
## incoming room slides in from the left edge (toward the tab strip) --
## 200ms in / 220ms eased-out settle (Tuning Knobs). Host-owned per ADR-0032
## Section 3 (never the room instance's own) -- killable via kill_transition_
## tween(), the exact seam Story 010's select_loadout() Step 1 now calls.
## Purely cosmetic: logical mount state above is already committed
## synchronously, unaffected by this animation's timing.
func _play_drawer_slide_in(room: Node) -> void:
	kill_transition_tween()
	if not (room is Control):
		return
	var control_room: Control = room as Control
	var target_position: Vector2 = control_room.position
	control_room.position = target_position + Vector2(-size.x, 0.0)
	_transition_tween = create_tween()
	_transition_tween.tween_property(control_room, "position", target_position, 0.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## ADR-0032 Section 3: kills any in-flight shell-level transition tween.
## Safe by construction -- the tween is host-owned, never the room
## instance's own, so killing it can never null-ref against a room node
## that's mid-teardown. Called automatically at the start of every new
## slide-in (closing the rapid-re-trigger Edge Case), and callable directly
## by Story 010's select_loadout() Step 1.
func kill_transition_tween() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null


## The exact 2-step synchronous teardown ADR-0032 Section 1 requires, in
## order, before queue_free(): (1) disconnect the room's own EventBus
## subscriptions if it owns any, (2) gate its unhandled-input processing.
## Both must complete before the deferred queue_free() removal even begins --
## queue_free()'s end-of-frame deferral does not stop signal delivery or
## input dispatch in the interim, so calling it first would leave a live
## window for a stray callback to fire against a node that's about to be
## freed.
func unmount_current_room() -> void:
	if _current_room == null:
		return
	var outgoing: Node = _current_room
	var outgoing_state: StringName = _current_room_state
	if outgoing.has_method(&"disconnect_own_subscriptions"):
		outgoing.disconnect_own_subscriptions()
	if outgoing.has_method(&"set_process_unhandled_input"):
		outgoing.set_process_unhandled_input(false)
	outgoing.queue_free()
	_current_room = null
	_current_room_state = &""
	room_unmounted.emit(outgoing_state)


## The currently-mounted room instance, or null if none is mounted.
func get_current_room() -> Node:
	return _current_room


## The state label passed to the currently-mounted room's own mount_room()
## call, or an empty StringName if none is mounted.
func get_current_room_state() -> StringName:
	return _current_room_state
