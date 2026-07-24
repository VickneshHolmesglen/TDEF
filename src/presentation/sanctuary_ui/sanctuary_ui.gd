class_name SanctuaryUI
extends Control

## Sanctuary UI structural shell (Story 001, ADR-0002, epic-10-sanctuary-ui).
##
## GDD source: design/gdd/sanctuary-ui.md — Core Rule 1 (Structural Model),
## AC Group 1. Scene-instanced (not an Autoload), mounted by SceneManager on
## `scene_transition_completed(target_context="SANCTUARY")` — that wiring is
## NOT part of this story (see Out of Scope); this file is buildable and
## testable standalone.
##
## Owns exactly the structural skeleton AC Group 1 requires: a shell-owned
## Diorama node that persists for this instance's whole lifetime regardless
## of active state (never freed on a room switch), a RoomHost Control sized
## to the frame minus chrome, and a Chrome layer (TabStrip + ResourceHeader)
## that is always present and rendering. Diorama and RoomHost are mutually
## exclusive content — exactly one is visible at a time, selected by
## set_active_state().
##
## Deliberately minimal state surface for this story: only an OVERVIEW vs.
## not-OVERVIEW distinction (StringName-keyed) is modeled. The real 4-room
## ROOM_* enum (Core Rule 2/States-and-Transitions table) belongs to Story
## 002 (tab strip navigation) and Story 007 (room lifecycle) — inventing it
## here would be scope creep past this story's own AC Group 1.
##
## Tab strip width / resource header height are Story 002's / Story 004's
## own tuning-knob stories to finalize — the values below are this story's
## placeholder, taken directly from the GDD's own Tuning Knobs defaults
## (72px / 48px), not a percentage-of-frame margin (Implementation Notes'
## explicit "do not hardcode a margin percentage" only forbids a %-based
## margin, not a placeholder px constant pending those later stories).

## Sole state this story models as "OVERVIEW" — every other StringName value
## passed to set_active_state() is treated uniformly as "a room is active"
## (RoomHost visible, Diorama hidden). See class doc for why the full
## ROOM_* enum isn't modeled yet.
const OVERVIEW_STATE: StringName = &"OVERVIEW"

## Story 009 (Core Rule 8) — pure transitional state, no player action
## available while active (terminal latch).
const DEPARTING_STATE: StringName = &"DEPARTING"

## Story 010 (Core Rule 10) — pure transitional state, shares the same
## terminal latch as DEPARTING (ADR-0032 Section 2).
const DEPARTING_TO_LOADOUT_STATE: StringName = &"DEPARTING_TO_LOADOUT"

## Story 005 (Room Hosting) — which real room scene backs each ROOM_* state.
## As of 2026-07-25, all 4 rooms have real scenes (see each addition's own
## note below for honestly-scoped deviations from its GDD's literal wording).
##
## Menagerie added 2026-07-25: `MenagerieScreen.tscn`, built directly against
## menagerie.md's UI Requirements section (roster review, tend, breeding
## multi-select-then-confirm, sacrifice two-step confirmation) — see that
## scene's own doc comment for the honestly-scoped deviations (roster-list
## primary view instead of habitat-diorama primary view, since no diorama/
## creature art exists; explicit per-action buttons instead of one context-
## sensitive confirm button).
##
## Defense Building added 2026-07-25: `DefenseBuildingScreen.tscn`, built
## directly against defense-building.md's UI Requirements section (two
## linked views — tech tree, structure build — single-confirm convention for
## both). See that scene's own doc comment for the honestly-scoped deviation
## (flat ordered list instead of a literal branching-graph tech tree, since
## no graph-layout art exists).
##
## Equipment Forge added 2026-07-25: `EquipmentForgeScreen.tscn`, built
## directly against equipment-forge.md's UI Requirements section (persistent
## Craft/Imbue tab toggle, equipment-recipe crafting, rune-imbuing with a
## Menagerie-sacrifice-style two-step confirmation). See that scene's own
## doc comment for the honestly-scoped deviations (own recipe list instead
## of literally reusing a nonexistent Crafting panel; 2-way item→rune
## selection instead of the GDD's literal 3-way item→slot→rune selection,
## since `Inventory.apply_rune_to_item()` has no per-slot targeting to
## select in the first place).
const ROOM_SCENES: Dictionary[StringName, PackedScene] = {
	&"ROOM_INVENTORY_CRAFTING": preload("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn"),
	&"ROOM_MENAGERIE": preload("res://src/gameplay/ui/menagerie_screen/MenagerieScreen.tscn"),
	&"ROOM_DEFENSE_BUILDING": preload("res://src/gameplay/ui/defense_building_screen/DefenseBuildingScreen.tscn"),
	&"ROOM_EQUIPMENT_FORGE": preload("res://src/gameplay/ui/equipment_forge_screen/EquipmentForgeScreen.tscn"),
}

## GDD Tuning Knobs default (56-96px safe range) — Story 002 owns tuning this.
const TAB_STRIP_WIDTH: float = 72.0
## GDD Tuning Knobs default (40-64px safe range) — Story 004 owns tuning this.
const HEADER_HEIGHT: float = 48.0

@onready var _diorama: Control = $Diorama
@onready var _room_host: RoomHost = $RoomHost
@onready var _chrome: Control = $Chrome
@onready var _tab_strip: TabStrip = $Chrome/TabStrip
@onready var _resource_header: ResourceHeader = $Chrome/ResourceHeader

## AC-1: shell-owned, never reassigned/freed for this instance's lifetime —
## exposed read-only so tests can capture identity before/after a state
## switch (Story-001 QA Test Case AC-1).
var _active_state: StringName = OVERVIEW_STATE

## Story 006: fed by sanctuary_structure_built regardless of active state --
## the diorama's own rendering doesn't exist yet (no art, no fixed structure
## positions -- Diorama is still Story 001's placeholder Control), so this is
## the honest scope of "the diorama's own always-listening update" today: the
## data feed a future rendering pass will read, kept correctly up to date
## from the instant this shell mounts to the instant it's freed, independent
## of which tab is active. Building the actual visual is a future story's job.
var _built_structure_ids: Array[String] = []

## Story 009 (Core Rule 8) — the terminal latch. Set exactly once, the first
## EventBus-touching/state-mutating statement of whichever handler reaches it
## first (only Launch/Depart today; Story 010's Loadout hand-off will share
## this same flag and disconnect routine, per ADR-0032 Section 2 -- ADR-0032
## already anticipates and formalizes this exact sharing). Once true: every
## further tab/hotkey/Cancel input and every remaining EventBus subscription
## this shell owns is inert -- disconnect-not-just-flag-check is what closes
## the CONNECT_DEFERRED race (a subscription already queued before this flag
## was set cannot fire after the disconnect, regardless of flag state).
var _departing: bool = false


func _ready() -> void:
	_configure_chrome_layout()
	set_active_state(OVERVIEW_STATE)
	_tab_strip.tab_target_selected.connect(_on_tab_target_selected)
	GEventBus.scene_transition_completed.connect(_on_scene_transition_completed)
	GEventBus.sanctuary_structure_built.connect(_on_sanctuary_structure_built)


func _exit_tree() -> void:
	# Idempotent against the terminal latch already having disconnected these
	# same 2 subscriptions -- Godot errors on disconnecting an already-
	# disconnected signal, and _exit_tree() legitimately still runs after
	# confirm_launch_depart() already ran the latch this same instance's
	# lifetime (e.g. the scene is freed sometime after departing).
	if _departing:
		return
	GEventBus.scene_transition_completed.disconnect(_on_scene_transition_completed)
	GEventBus.sanctuary_structure_built.disconnect(_on_sanctuary_structure_built)


## Story 008 (GDD Core Rule 7): Cancel reuses the existing idiom -- Esc /
## gamepad East face button, Godot's built-in ui_cancel action (this project's
## InputMap has no override for it, so the engine's own default bindings
## already cover both). No separate "leave room" action exists.
func _input(event: InputEvent) -> void:
	if _departing:
		return
	if event.is_action_pressed(&"ui_cancel"):
		_handle_cancel()


## AC-2: with no room active (OVERVIEW, focus on tab strip), Cancel is a
## genuine no-op -- there is no "exit Sanctuary UI via Cancel" path (Core
## Rule 7's own explicit statement); exit is exclusively Launch/Depart
## (Story 009, out of scope here).
##
## AC-1/AC-2: with a room active, the room's own nested state is that room's
## concern (Core Rule 7 -- "exactly as each room's own GDD already
## specifies"), not this shell's. This shell's own room contract (mirroring
## Story 007's disconnect_own_subscriptions() duck-typed pattern):
## handle_cancel() -> bool, returning true if the room stepped back one
## nested stage internally (room's own state remains active, unchanged),
## false if it had nothing left to step back from (shell exits it to
## OVERVIEW). A room with no handle_cancel() method (e.g. InventoryScreen
## today, which has no nested-confirmation state of its own) is treated the
## same as "always at root" -- Cancel exits it immediately, the correct
## behavior for a room with nothing to step back through.
func _handle_cancel() -> void:
	if _active_state == OVERVIEW_STATE:
		return
	var room: Node = _room_host.get_current_room()
	if room != null and room.has_method(&"handle_cancel") and bool(room.handle_cancel()):
		return
	set_active_state(OVERVIEW_STATE)


## AC-2/AC-3: switches which of Diorama/RoomHost is the visible content.
## Chrome (_tab_strip/_resource_header) is never touched here — AC-4 requires
## both always present/rendering regardless of active state, which holding
## them outside this branch guarantees by construction.
##
## Story 005: also drives RoomHost's actual content via ROOM_SCENES. Entering
## OVERVIEW or any state with no mapped scene yet (see ROOM_SCENES) unmounts
## whatever room was previously hosted -- RoomHost's own Story 007 lifecycle
## (disconnect-then-gate-then-free) runs identically either way, this class
## never duplicates that sequence.
func set_active_state(state: StringName) -> void:
	_active_state = state
	# GDD Visual/Audio Requirements: DEPARTING keeps the diorama visible (camera
	# pull-back plays against it) — it is NOT a ROOM_* state and must not fall
	# into the generic "room active" branch below, which would incorrectly hide
	# the diorama and show an empty RoomHost. Real bug found by code review
	# 2026-07-24: this branch previously only special-cased OVERVIEW_STATE.
	var shows_diorama: bool = state == OVERVIEW_STATE or state == DEPARTING_STATE
	_diorama.visible = shows_diorama
	_room_host.visible = not shows_diorama

	if not shows_diorama and ROOM_SCENES.has(state):
		_room_host.mount_room(ROOM_SCENES[state], state)
	else:
		_room_host.unmount_current_room()


## The currently active state (OVERVIEW_STATE, DEPARTING_STATE,
## DEPARTING_TO_LOADOUT_STATE, or a ROOM_* StringName) — see class doc for
## why only this minimal set is modeled today.
func get_active_state() -> StringName:
	return _active_state


## Read-only accessor for tests/future stories that need the persistent
## Diorama node reference (AC-1) without reaching into a private field.
func get_diorama() -> Control:
	return _diorama


## Read-only accessor mirroring get_diorama() for RoomHost (AC-2).
func get_room_host() -> Control:
	return _room_host


## Test/inspection accessor for Story 004's resource header.
func get_resource_header() -> ResourceHeader:
	return _resource_header


## Test/inspection accessor for driving tab-strip selection directly in tests
## (Story 005's room-hosting suite triggers real tab clicks rather than
## calling set_active_state() directly, to exercise the full click -> mount
## path, not just the mounting logic in isolation).
func get_tab_strip_for_test() -> TabStrip:
	return _tab_strip


## Test/inspection accessor -- structures recorded via sanctuary_structure_built,
## regardless of which state was active when each one fired (Story 006).
func get_built_structure_ids() -> Array[String]:
	return _built_structure_ids


func _on_scene_transition_completed(target_context: String, _mission_id: String) -> void:
	if _departing:
		return
	if target_context == "SANCTUARY":
		set_active_state(OVERVIEW_STATE)


## Always listening regardless of active state -- the subscription itself
## (made once in _ready(), alongside the Diorama node's own instance, which
## Story 001 already guarantees persists for this shell's whole lifetime) is
## what makes "always," not a check against the currently active state. The
## _departing check here is defense-in-depth for the CONNECT_DEFERRED race
## (an event already queued before the disconnect ran) -- the disconnect
## itself is what actually prevents any FUTURE event from reaching this
## handler at all.
func _on_sanctuary_structure_built(structure_id: String, _structure_type: String) -> void:
	if _departing:
		return
	_built_structure_ids.append(structure_id)


## Story 009 (Core Rule 8, AC Group 8): the sole Launch/Depart trigger.
## OVERVIEW-only by construction (not merely by UI visibility) -- a call
## reaching here from any other state or while already departing is a no-op,
## satisfying AC-1's "no control reachable outside OVERVIEW" as a code-level
## guarantee and the double-press guard (AC in Load-Bearing Edge Cases) in
## the same check.
func confirm_launch_depart() -> void:
	if _active_state != OVERVIEW_STATE or _departing:
		return
	# Terminal latch: set the flag and disconnect this shell's own EventBus
	# subscriptions in the same statement group, before any other
	# EventBus-touching logic below -- ADR-0032 Section 2's exact guarantee.
	_departing = true
	GEventBus.scene_transition_completed.disconnect(_on_scene_transition_completed)
	GEventBus.sanctuary_structure_built.disconnect(_on_sanctuary_structure_built)
	set_active_state(DEPARTING_STATE)
	_play_departing_chrome_fade()
	# REAL GAP, FLAGGED NOT SILENTLY WORKED AROUND (mirrors Story 004's
	# balance-ownership gap): "Sanctuary UI hands off to Mission Select" has
	# no resolved API today. ADR-0002's scene hierarchy only defines
	# SanctuaryScene and MissionScene -- there is no third "Mission Select
	# browsing" scene/screen anywhere in this project to hand off TO, and the
	# GDD's own OQ-2 confirms this call is "not yet classified under
	## ADR-0020's Criterion A/B framework." back_out_to_browsing() is the
	# closest real, safe, idempotent MissionSelect method available today
	# (it only sets state = BROWSING, which is likely already true post-
	# MISSION_COMPLETE reset) -- called here as an explicitly-flagged
	# placeholder, not a resolved design decision. The AC's stronger claim
	# ("control genuinely passes to Mission Select... receives input") is
	# NOT implementable until a real browsing screen/scene exists; tracked as
	# a new gap alongside OQ-2, not silently treated as closed by this call.
	GMissionSelect.back_out_to_browsing()


## Test/inspection accessor -- true from the instant confirm_launch_depart()'s
## terminal latch fires.
func is_departing() -> bool:
	return _departing


## GDD Visual/Audio Requirements: chrome fades out first and fastest within
## the DEPARTING beat's ~0.5s budget (roughly 60% fade / 40% hold-on-settled-
## frame -- the diorama's own slow pull-back/settle half needs a real
## Camera2D on real diorama content, neither of which exists yet, Story 012's
## own already-confirmed gap -- not attempted here). Purely cosmetic, runs
## after the terminal latch and state transition above are already committed.
func _play_departing_chrome_fade() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_chrome, "modulate:a", 0.0, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Story 010 (Core Rule 10, AC Group 10): the Loadout hand-off. Reachable
## from ANY state (OVERVIEW or any ROOM_*) -- unlike confirm_launch_depart(),
## deliberately NOT gated on _active_state == OVERVIEW_STATE, per the GDD's
## own explicit reachability principle: irreversible exits (Launch/Depart)
## get a pacing gate, reversible lateral navigation (Loadout) does not.
## Double-selection guard is still the shared _departing flag.
##
## The exact 4-step ordered sequence (ADR-0032 Section 2/3), in order:
func select_loadout() -> void:
	if _departing:
		return

	# Step 1: kill any in-flight shell-level transition tween. RoomHost-owned
	# (ADR-0032 Section 3 -- never the room instance's own), so killing it here
	# is EventBus-inert and can safely precede the latch below without
	# weakening what the latch protects, exactly as the GDD's own precision
	# note states.
	_room_host.kill_transition_tween()

	# Step 2: terminal latch -- the SAME shared flag and disconnect routine
	# confirm_launch_depart() uses (ADR-0032 Section 2's explicit sharing).
	_departing = true
	GEventBus.scene_transition_completed.disconnect(_on_scene_transition_completed)
	GEventBus.sanctuary_structure_built.disconnect(_on_sanctuary_structure_built)

	# Step 3: if a room is currently active, tear it down via Story 007's own
	# lifecycle (disconnect-then-gate-then-free) -- unmount_current_room() is
	# already a safe no-op if nothing is mounted (OVERVIEW case).
	_room_host.unmount_current_room()

	# Step 4: enter DEPARTING_TO_LOADOUT and hand off.
	_active_state = DEPARTING_TO_LOADOUT_STATE
	_diorama.visible = false
	_room_host.visible = false
	# Gap closed 2026-07-25: SceneManager.transition_to_tarot_deck_ui() now
	# exists (a real, tested top-level SANCTUARY->TAROT_DECK scene
	# transition, mirroring transition_to_sanctuary() exactly) and
	# TarotDeckUIScene.tscn hosts the real, fully-built TarotDeckUI.tscn
	# shell. The GDD's own OQ-9 (ADR-0020 Criterion A/B classification of
	# this call) remains formally open -- shipped ahead of that
	# classification per this epic's own established precedent, not
	# silently treated as resolved.
	GSceneManager.transition_to_tarot_deck_ui()


## Test/inspection accessor -- true once the active state is
## DEPARTING_TO_LOADOUT.
func is_departing_to_loadout() -> bool:
	return _active_state == DEPARTING_TO_LOADOUT_STATE


## Computes every chrome/content region from TAB_STRIP_WIDTH/HEADER_HEIGHT —
## the one place this story's rect math lives, so Story 002/004 only need to
## update the two constants above, not re-derive anchor/offset math per node.
## Tab strip is a fixed-width full-height left column; resource header is a
## fixed-height bar spanning the remaining width at the top; Diorama/RoomHost
## share the remaining rect (frame minus both), matching AC-2/AC-3 exactly.
func _configure_chrome_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_tab_strip.anchor_left = 0.0
	_tab_strip.anchor_top = 0.0
	_tab_strip.anchor_right = 0.0
	_tab_strip.anchor_bottom = 1.0
	_tab_strip.offset_left = 0.0
	_tab_strip.offset_top = 0.0
	_tab_strip.offset_right = TAB_STRIP_WIDTH
	_tab_strip.offset_bottom = 0.0

	_resource_header.anchor_left = 0.0
	_resource_header.anchor_top = 0.0
	_resource_header.anchor_right = 1.0
	_resource_header.anchor_bottom = 0.0
	_resource_header.offset_left = TAB_STRIP_WIDTH
	_resource_header.offset_top = 0.0
	_resource_header.offset_right = 0.0
	_resource_header.offset_bottom = HEADER_HEIGHT

	for content: Control in [_diorama, _room_host]:
		content.anchor_left = 0.0
		content.anchor_top = 0.0
		content.anchor_right = 1.0
		content.anchor_bottom = 1.0
		content.offset_left = TAB_STRIP_WIDTH
		content.offset_top = HEADER_HEIGHT
		content.offset_right = 0.0
		content.offset_bottom = 0.0


## Story 002: routes TabStrip's direct-click/hotkey/`[`/`]`/LT-RT navigation.
## Loadout's target (DEPARTING_TO_LOADOUT_STATE) is intercepted and routed to
## Story 010's own select_loadout() -- its reachable-from-any-state semantics
## and 4-step ordered sequence are structurally different from a normal
## set_active_state() room switch, not a variant of it. Every other target
## still goes through set_active_state() unchanged.
func _on_tab_target_selected(target_state: StringName) -> void:
	if _departing:
		return
	if target_state == DEPARTING_TO_LOADOUT_STATE:
		select_loadout()
		return
	set_active_state(target_state)
