class_name TarotDeckUI
extends Control

## Tarot Deck UI structural shell (Story 001, ADR-0011, epic-11-tarot-deck-ui).
##
## GDD source: design/gdd/tarot-deck-ui.md -- Core Rule 1-2, AC Group 1.
## Story: production/epics/epic-11-tarot-deck-ui/story-001-structural-model-and-tab-strip.md
##
## Sibling shell to Sanctuary UI, structurally the smallest version of the
## same shell problem: exactly 2 mutually-exclusive full-frame content
## states (HERO_SKILL_BUILD, TAROT_DECK) plus a persistent 2-entry tab strip
## -- no third "overview" state exists here (Core Rule 1). Scene-instanced
## (not an Autoload), mounted via Sanctuary UI's own Loadout hand-off (Epic
## 10 Story 010) -- that wiring is NOT part of this story (matches Sanctuary
## UI Story 001's own identical precedent); this file is buildable and
## testable standalone.
##
## Story 003 (Exit & Lifecycle): screen hosting uses the real ScreenHost
## generic mount/unmount mechanism (ADR-0032 Section 1, mirroring Sanctuary
## UI's RoomHost exactly).
##
## Both screens added 2026-07-25: `TarotScreen.tscn` and
## `HeroSkillBuildScreen.tscn`, built directly against their own GDDs' UI
## Requirements sections — see each scene's own doc comment for the
## honestly-scoped deviations from each GDD's literal pick-up-then-place
## gamepad wording (both underlying APIs have no slot-targeting/swap
## primitive to bind a 2-step flow to, mirroring Equipment Forge's own
## identical finding the same day).
const SCREEN_SCENES: Dictionary[StringName, PackedScene] = {
	&"TAROT_DECK": preload("res://src/gameplay/ui/tarot_screen/TarotScreen.tscn"),
	&"HERO_SKILL_BUILD": preload("res://src/gameplay/ui/hero_skill_build_screen/HeroSkillBuildScreen.tscn"),
}

const HERO_SKILL_BUILD_STATE: StringName = &"HERO_SKILL_BUILD"
const TAROT_DECK_STATE: StringName = &"TAROT_DECK"

const TAB_STRIP_WIDTH: float = 72.0

@onready var _screen_host: ScreenHost = $ScreenHost
@onready var _tab_strip: DeckTabStrip = $Chrome/TabStrip
@onready var _return_to_sanctuary_button: Button = $ReturnToSanctuaryButton

var _active_state: StringName = HERO_SKILL_BUILD_STATE

## Terminal latch (ADR-0032 Section 2, same mechanism Sanctuary UI's
## confirm_launch_depart() implements) -- real gap found and fixed during
## code review (2026-07-24): the ADR's own Validation Criteria claims this
## shell's Story 003 tests validate "the identical pattern" Sanctuary UI's
## own Story 009 does, which was false until this fix -- confirm_return_to_
## sanctuary() previously called GSceneManager.transition_to_sanctuary()
## directly, leaving _tab_strip.tab_target_selected and
## _conflict_indicator's own EventBus subscriptions live through
## SceneManager's own one-frame deferral window (scene_manager.gd's
## await get_tree().process_frame before scene_transition_completed fires) --
## exactly the window this ADR section exists to close.
var _departing: bool = false

## Story 004 -- instanced once, shell-owned, lives for this instance's whole
## lifetime regardless of active state (same "shell-owned, always listening"
## precedent as Sanctuary UI's own diorama structure feed, Epic 10 Story 006).
var _conflict_indicator: ConflictIndicator

## Story 005 -- stateless query helper, no lifecycle of its own beyond
## existing as a node to hang the class on (both its methods are live reads,
## nothing to subscribe/unsubscribe).
var _snapshot_chip: SnapshotChip


func _ready() -> void:
	add_to_group(&"tarot_deck_ui")
	_configure_chrome_layout()
	_configure_return_to_sanctuary_button()
	set_active_state(HERO_SKILL_BUILD_STATE)
	_tab_strip.tab_target_selected.connect(_on_tab_target_selected)
	_conflict_indicator = ConflictIndicator.new()
	add_child(_conflict_indicator)
	_snapshot_chip = SnapshotChip.new()
	add_child(_snapshot_chip)


## AC-1: switches which of the 2 states is active, now via ScreenHost's real
## destroy-and-recreate mechanism (Story 003).
func set_active_state(state: StringName) -> void:
	_active_state = state
	if SCREEN_SCENES.has(state):
		_screen_host.mount_screen(SCREEN_SCENES[state], state)
	else:
		_screen_host.unmount_current_screen()


func get_active_state() -> StringName:
	return _active_state


func get_screen_host() -> ScreenHost:
	return _screen_host


func get_conflict_indicator() -> ConflictIndicator:
	return _conflict_indicator


func get_snapshot_chip() -> SnapshotChip:
	return _snapshot_chip


## Story 003 (Core Rule 4): Cancel / explicit return affordance closes the
## shell -- no confirmation of any kind (every committed edit on both screens
## is already applied per each screen's own GDD). Calls SceneManager's own
## real, ADR-0002 public API directly -- this is NOT a flagged placeholder
## like Sanctuary UI's own Mission Select/Tarot Deck UI hand-off gaps
## (Stories 009/010): GSceneManager.transition_to_sanctuary() genuinely
## exists and is correctly implemented. The one residual, already-known gap
## is narrower and pre-existing: SanctuaryScene.tscn itself is still Story
## 001-era placeholder content (every Sanctuary UI story from 001-012
## explicitly deferred wiring SanctuaryUI.tscn into it), so the loaded scene
## won't visually show the real shell yet -- that gap belongs to whichever
## story eventually does that integration, not to this one.
##
## Terminal latch (ADR-0032 Section 2): the flag and disconnect run as the
## first statements, before the SceneManager call -- mirrors
## sanctuary_ui.gd's confirm_launch_depart() exactly. Double-press-safe by
## construction (a second call while already departing is a no-op).
func confirm_return_to_sanctuary() -> void:
	if _departing:
		return
	_departing = true
	_tab_strip.tab_target_selected.disconnect(_on_tab_target_selected)
	_conflict_indicator.disconnect_own_subscriptions()
	GSceneManager.transition_to_sanctuary()


func _input(event: InputEvent) -> void:
	if _departing:
		return
	if event.is_action_pressed(&"ui_cancel"):
		confirm_return_to_sanctuary()


## Test/inspection accessor -- true from the instant
## confirm_return_to_sanctuary()'s terminal latch fires.
func is_departing() -> bool:
	return _departing


func get_tab_strip_for_test() -> DeckTabStrip:
	return _tab_strip


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

	_screen_host.anchor_left = 0.0
	_screen_host.anchor_top = 0.0
	_screen_host.anchor_right = 1.0
	_screen_host.anchor_bottom = 1.0
	_screen_host.offset_left = TAB_STRIP_WIDTH
	_screen_host.offset_top = 0.0
	_screen_host.offset_right = 0.0
	_screen_host.offset_bottom = 0.0


func _on_tab_target_selected(target_state: StringName) -> void:
	set_active_state(target_state)


## GDD Core Rule 4: "A Cancel/back action ... OR an explicit 'Return to
## Sanctuary' affordance" -- two independent exits, not one. Only the
## Cancel/back input action (see _input() above) was ever wired; this shell
## had no visible, clickable way to leave for a mouse-only player who never
## discovers the keyboard/gamepad Cancel binding. Bottom-right corner of the
## frame, mirroring Sanctuary UI's own Launch Mission button placement
## (sanctuary_ui.gd's _configure_launch_mission_button()) -- out of the tab
## strip's way, always reachable regardless of which of the 2 screens is
## active (Core Rule 4 draws no state distinction, unlike Sanctuary UI's
## OVERVIEW-only Launch button).
func _configure_return_to_sanctuary_button() -> void:
	_return_to_sanctuary_button.anchor_left = 1.0
	_return_to_sanctuary_button.anchor_top = 1.0
	_return_to_sanctuary_button.anchor_right = 1.0
	_return_to_sanctuary_button.anchor_bottom = 1.0
	_return_to_sanctuary_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_return_to_sanctuary_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_return_to_sanctuary_button.offset_left = -220.0
	_return_to_sanctuary_button.offset_top = -64.0
	_return_to_sanctuary_button.offset_right = -24.0
	_return_to_sanctuary_button.offset_bottom = -24.0
	_return_to_sanctuary_button.text = tr("TAROT_DECK_UI_RETURN_TO_SANCTUARY_BUTTON")
	# Chrome-outline style (not Launch's Amber, which the sanctuary_ui.gd
	# doc comment reserves for "this screen's single most consequential
	# action") -- this is a secondary/back action, matching the tab strip's
	# own inactive-tab treatment.
	_return_to_sanctuary_button.add_theme_stylebox_override("normal", ShellChromeStyle.chrome_button_stylebox(false))
	_return_to_sanctuary_button.add_theme_stylebox_override("hover", ShellChromeStyle.chrome_button_stylebox(false))
	_return_to_sanctuary_button.add_theme_stylebox_override("pressed", ShellChromeStyle.chrome_button_stylebox(false))
	_return_to_sanctuary_button.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	_return_to_sanctuary_button.focus_mode = Control.FOCUS_ALL
	_return_to_sanctuary_button.pressed.connect(confirm_return_to_sanctuary)
	_return_to_sanctuary_button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CANCEL)
