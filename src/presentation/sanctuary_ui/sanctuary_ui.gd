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
## Hero Skills added 2026-09-01 (Claude Code): `HeroSkillsRoom.tscn`, a new
## composite room hosting both hero_skill_build_screen.gd (Loadout) and
## hero_skill_tree_screen.gd (Skill Tree) as bumper-toggled sub-screens,
## per sanctuary-ui.md Core Rule 11 — see that scene's own doc comment for
## the real gaps this closes (no ROOM_HERO_SKILLS entry existed anywhere in
## code before this, and no LB/RB gamepad InputMap action existed in this
## project at all despite tab_strip.gd's own comment implying one did).
const ROOM_SCENES: Dictionary[StringName, PackedScene] = {
	&"ROOM_INVENTORY_CRAFTING": preload("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn"),
	&"ROOM_MENAGERIE": preload("res://src/gameplay/ui/menagerie_screen/MenagerieScreen.tscn"),
	&"ROOM_DEFENSE_BUILDING": preload("res://src/gameplay/ui/defense_building_screen/DefenseBuildingScreen.tscn"),
	&"ROOM_EQUIPMENT_FORGE": preload("res://src/gameplay/ui/equipment_forge_screen/EquipmentForgeScreen.tscn"),
	&"ROOM_HERO_SKILLS": preload("res://src/gameplay/ui/hero_skills_room/HeroSkillsRoom.tscn"),
}

## GDD Tuning Knobs default (56-96px safe range) — Story 002 owns tuning this.
## Widened past that range's own ceiling to 240px (2026-08-09): the 56-96px
## number assumed the GDD's icon-first/label-on-focus-only ideal, but this
## screen ships icon+text always-on (see tab_strip.gd's class doc), and once
## a real translation catalog existed, live-verified label text permanently
## ellipsis-truncated at 96px -- confirmed via MCP as a real player-visible
## regression, not a cosmetic nit. 240px is measured live against the real
## button/font/stylebox (Font.get_string_size + icon + h_separation +
## stylebox margins), not guessed -- an initial 180px guess (based on a
## bare Button.new() with the default theme, not this screen's actual font
## metrics) still truncated "Inventory & Crafting" in-engine. 240px cleared
## every current label ("Inventory & Crafting" needs ~221px) with margin.
## text_overrun_behavior in tab_strip.gd stays on as a defensive fallback
## for future/longer localized strings, not as the primary rendering path.
## Widened again to match RESOURCE_HEADER_WIDTH exactly (2026-08-09, same
## day): now that the header sits above the tab strip instead of beside it
## (see _configure_chrome_layout()'s own note), a narrower tab strip left
## its right edge short of the header's, reading as misaligned columns.
const TAB_STRIP_WIDTH: float = RESOURCE_HEADER_WIDTH
## GDD Tuning Knobs safe range is 40-64px (Story 004 owns tuning this) --
## raised from the 48px placeholder to the range's own ceiling (2026-08-04) so
## `sanctuary_header_gold.png`'s corner-flourish trim (design/art/asset-UI-
## prompt.md) has room to read as a frame rather than a squished pinstripe.
const HEADER_HEIGHT: float = 64.0

## Fixed width for the gold header art itself (2026-08-04): the header no
## longer stretches full-width edge-to-edge across the top bar -- that
## squashed the 9-sliced art's proportions into a thin plain stripe with tiny
## end-caps. Left-aligned next to the tab strip instead, close to the source
## art's own unstretched proportions (sanctuary_header_gold.png is 350x80,
## ~4.4:1) at HEADER_HEIGHT, so it reads as a compact title plaque. The
## remaining top-bar space to its right is bare Chrome background (untextured
## -- no GDD requirement fills it with anything else).
const RESOURCE_HEADER_WIDTH: float = 320.0

## Player-reported 2026-08-16: a "lot of grey area" was visible throughout
## the Sanctuary UI. Root cause: Diorama/RoomHost's content zone had no
## background fill at all -- every room (Overview's diorama, Inventory &
## Crafting, Menagerie, Defense Building, Equipment Forge) rendered directly
## on Godot's raw default viewport clear color, not any intentional color.
## Fix: a single UI_CHROME-filled ColorRect sized to the exact same content
## rect as Diorama/RoomHost (see _configure_chrome_layout()), sitting behind
## both -- closes the gap for every room at once since they all mount inside
## this same content zone. Uses the art bible's own existing UI Chrome Dark
## token (already used for the tab strip/resource header), not new art --
## the art bible's own UI shape grammar calls for flat chrome here, not a
## painterly scene (reserved for Diorama's own future backdrop art, a
## separate and still-open piece of work).
@onready var _content_background: ColorRect = $ContentBackground
@onready var _diorama: Control = $Diorama
@onready var _room_host: RoomHost = $RoomHost
@onready var _chrome: Control = $Chrome
@onready var _tab_strip: TabStrip = $Chrome/TabStrip
@onready var _resource_header: ResourceHeader = $Chrome/ResourceHeader
@onready var _launch_mission_button: Button = $LaunchMissionButton

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
	_configure_launch_mission_button()
	set_active_state(OVERVIEW_STATE)
	_tab_strip.tab_target_selected.connect(_on_tab_target_selected)
	# Town buildings (2026-10-07): a building click selects its tab exactly like the side panel.
	if _diorama.has_signal(&"building_selected"):
		_diorama.connect(&"building_selected", _tab_strip.select_target)
	_launch_mission_button.pressed.connect(confirm_launch_depart)
	_launch_mission_button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CONFIRM)
	GEventBus.scene_transition_completed.connect(_on_scene_transition_completed)
	GEventBus.sanctuary_structure_built.connect(_on_sanctuary_structure_built)


func _exit_tree() -> void:
	# Idempotent against the terminal latch already having disconnected these
	# same 2 subscriptions -- Godot errors on disconnecting an already-
	# disconnected signal, and _exit_tree() legitimately still runs after
	# confirm_launch_depart() already ran the latch this same instance's
	# lifetime (e.g. the scene is freed sometime after departing).
	if _launch_mission_button.pressed.is_connected(confirm_launch_depart):
		_launch_mission_button.pressed.disconnect(confirm_launch_depart)
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
	# Core Rule 8 / AC Group 8: Launch/Depart is OVERVIEW-only -- absent from
	# every ROOM_* state (RoomHost visible) AND from DEPARTING itself ("no
	# action is available to the player" while the transitional beat plays,
	# per the States and Transitions table), not merely "wherever the
	# diorama happens to be visible."
	_launch_mission_button.visible = state == OVERVIEW_STATE

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
	if _diorama.has_method(&"play_departing_pull_back"):
		_diorama.call(&"play_departing_pull_back")
	# Gap closed 2026-07-25: MissionScene.tscn now exists (a real, tested,
	# generic MISSION-context scene hosting both Mission Select's own
	# browsing/configuring screen and the live gameplay assembly, switching
	# on GMissionSelect.state) -- SceneManager.transition_to_mission("")
	# genuinely hands off to it, replacing the previously-flagged
	# back_out_to_browsing() placeholder. Empty mission_id is correct here:
	# no mission is chosen yet at this point, matching MissionSelect's own
	# BROWSING entry state. ADR-0020's Criterion A/B classification of this
	# call (OQ-2) remains formally open -- shipped ahead of it per this
	# epic's own established precedent.
	GSceneManager.transition_to_mission("")


## Test/inspection accessor -- true from the instant confirm_launch_depart()'s
## terminal latch fires.
func is_departing() -> bool:
	return _departing


## GDD Visual/Audio Requirements: chrome fades out first and fastest within
## the DEPARTING beat's ~0.5s budget (roughly 60% fade / 40% hold-on-settled-
## frame). Purely cosmetic, runs after the terminal latch and state
## transition above are already committed.
##
## Update 2026-07-25: the diorama's own pull-back/settle half is now real
## too (see the play_departing_pull_back() call in confirm_launch_depart()
## above) -- diorama.gd implements it as a scale+position tween on its own
## World container rather than a literal Camera2D, since the Diorama's root
## is a Control, not a Node2D/Viewport (see that file's own doc comment).
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
## Resource header sits at the top-left corner, full HEADER_HEIGHT tall; tab
## strip is a fixed-width column starting below it (not beside it -- moved
## 2026-08-09, see below); Diorama/RoomHost share the remaining rect (frame
## minus both), matching AC-2/AC-3 exactly.
##
## Header moved from "beside the tab strip" to "above it" (2026-08-09): the
## prior layout put ResourceHeader to the right of TabStrip at the same
## y-origin, which read as a header floating beside the room list rather than
## over it. Repositioning is pure rect math -- ResourceHeader itself has no
## position assumptions baked in (see its own class doc: PRESET_FULL_RECT
## children throughout), so only the two offset blocks below change.
func _configure_chrome_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Real pre-existing bug found while live-verifying the header art wiring
	# (2026-08-04): Chrome itself was never given full-rect anchors, so it
	# stayed at Control's zero-size default. _resource_header's anchor_right
	# = 1.0 below resolves against Chrome's OWN rect, not the window -- with
	# Chrome at 0 width, that anchor collapsed to 0 regardless of offsets,
	# and only the header Label's own text-driven minimum size kept it
	# visible at all (rendering squashed on top of the first tab button
	# instead of spanning the top bar). TabStrip/ResourceHeader are anchored
	# relative to Chrome (not this Control, unlike Diorama/RoomHost below),
	# so Chrome must be full-rect for those percentage anchors to resolve
	# against the actual window size.
	_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_resource_header.anchor_left = 0.0
	_resource_header.anchor_top = 0.0
	_resource_header.anchor_right = 0.0
	_resource_header.anchor_bottom = 0.0
	_resource_header.offset_left = 0.0
	_resource_header.offset_top = 0.0
	_resource_header.offset_right = RESOURCE_HEADER_WIDTH
	_resource_header.offset_bottom = HEADER_HEIGHT

	_tab_strip.anchor_left = 0.0
	_tab_strip.anchor_top = 0.0
	_tab_strip.anchor_right = 0.0
	_tab_strip.anchor_bottom = 1.0
	_tab_strip.offset_left = 0.0
	_tab_strip.offset_top = HEADER_HEIGHT
	_tab_strip.offset_right = TAB_STRIP_WIDTH
	_tab_strip.offset_bottom = 0.0

	_content_background.color = ShellChromeStyle.UI_CHROME

	for content: Control in [_content_background, _diorama, _room_host]:
		content.anchor_left = 0.0
		content.anchor_top = 0.0
		content.anchor_right = 1.0
		content.anchor_bottom = 1.0
		content.offset_left = TAB_STRIP_WIDTH
		content.offset_top = HEADER_HEIGHT
		content.offset_right = 0.0
		content.offset_bottom = 0.0


## Core Rule 8 / design/ux/sanctuary-ui.md Component Inventory: "Launch/Depart
## button renders inside [the OVERVIEW content] zone." Bottom-right corner of
## the content zone (past the diorama's own structures, out of the tab
## strip's/resource header's way) — a fixed placement, not the diorama's own
## structure-ring hand-off the UX spec flags as an open implementation-detail
## choice (design/ux/sanctuary-ui.md line 287); this is the simpler of its
## two explicitly-equally-valid options ("a direct hop from the tab strip").
##
## Real gap found and fixed 2026-08-08: confirm_launch_depart() (Story 009)
## was fully implemented and tested, but no button/control anywhere in this
## scene ever called it — Sanctuary UI had no way for a real player to reach
## Mission Select at all. Story 009's own AC Group 8 already required this
## button to exist and be OVERVIEW-only reachable; only the logic half had
## actually been built.
func _configure_launch_mission_button() -> void:
	_launch_mission_button.anchor_left = 1.0
	_launch_mission_button.anchor_top = 1.0
	_launch_mission_button.anchor_right = 1.0
	_launch_mission_button.anchor_bottom = 1.0
	_launch_mission_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_launch_mission_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_launch_mission_button.offset_left = -220.0
	_launch_mission_button.offset_top = -64.0
	_launch_mission_button.offset_right = -24.0
	_launch_mission_button.offset_bottom = -24.0
	_launch_mission_button.text = tr("SANCTUARY_LAUNCH_MISSION_BUTTON")
	_launch_mission_button.add_theme_stylebox_override("normal", ShellChromeStyle.launch_button_stylebox())
	_launch_mission_button.add_theme_stylebox_override("hover", ShellChromeStyle.launch_button_stylebox())
	_launch_mission_button.add_theme_stylebox_override("pressed", ShellChromeStyle.launch_button_stylebox())
	_launch_mission_button.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	# Focus-reachable via Godot's default Tab-order traversal (the UX spec's
	# own "implementation-detail choice, not fixed here" — design/ux/
	# sanctuary-ui.md line 287 names two equally-valid options; this is the
	# simpler one, deferring a custom focus-ring hand-off to a future pass).
	# Cancel/ui_cancel from here does not exit (Core Rule 7 — OVERVIEW has no
	# Cancel-driven exit at all).
	_launch_mission_button.focus_mode = Control.FOCUS_ALL


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
