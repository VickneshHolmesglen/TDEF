extends Control

## Hero Skills Room (new 2026-09-01, Claude Code) — the `ROOM_HERO_SKILLS`
## room sanctuary-ui.md Core Rule 11 describes. Hosts both
## hero_skill_build_screen.gd (Loadout, default) and hero_skill_tree_screen.gd
## (Skill Tree) as bumper-toggled sub-screens of one RoomHost-mounted scene —
## RoomHost.mount_room() only ever mounts ONE PackedScene per ROOM_* state
## (room_host.gd's own contract), so this composite room, not a change to
## RoomHost itself, is what makes "two sub-screens in one room" possible.
##
## GDD source: design/gdd/sanctuary-ui.md Core Rule 11.
##
## **Closes the real gap flagged in hero_skill_tree_screen.gd/hero_skill_
## build_screen.gd's own doc comments (2026-09-01)**: `sanctuary_ui.gd`'s
## `ROOM_SCENES` had no `ROOM_HERO_SKILLS` entry at all — this scene plus
## that dictionary addition (and the matching TabStrip entry) is what makes
## both of those already-built, already-verified screens reachable from the
## live game for the first time.
##
## Scope, honestly bounded:
## - **Real gap found while building this**: no LB/RB gamepad shoulder-button
##   InputMap action existed anywhere in this project before this change
##   (`sanctuary_tab_prev`/`_next` and `tarot_tab_prev`/`_next` are LT/RT
##   triggers, axis motion — a different input entirely) despite tab_strip.gd's
##   own class doc comment claiming "each room owns its own internal
##   bumper-driven category cycling independently" as an already-established
##   idiom. It wasn't. New `room_bumper_left`/`room_bumper_right` InputMap
##   actions (project.godot) close this — real JOY_BUTTON_LEFT_SHOULDER/
##   JOY_BUTTON_RIGHT_SHOULDER (indices 9/10) plus a Q/E keyboard fallback,
##   generically named (not "hero_skills_"-scoped) so a future room can reuse
##   the same actions rather than this one inventing a room-specific pair.
## - Sub-screen switching is ALSO reachable via two plain click/focus tab
##   buttons (matching every other room's real, already-shipped sub-nav
##   pattern — inventory_screen.gd's Recipes/Assemble/Repair,
##   defense_building_screen.gd's Tech/Build — none of which are actually
##   bumper-driven despite that same tab_strip.gd comment's claim; this room
##   is the first one to add real bumper input, not remove the click
##   fallback every other room relies on exclusively).
## - Both sub-screens are instantiated eagerly at _ready() and kept alive
##   for this room's whole lifetime, toggled via `.visible` — not destroyed/
##   recreated on each switch (unlike RoomHost's own room-level lifecycle).
##   Matches Core Rule 11's own "Bumpers never trigger a tab-strip switch"
##   framing: this is lateral navigation within one already-mounted room, not
##   a new RoomHost.mount_room() cycle each time.
##
## Root is a plain Control. No class_name — matches the other room/screen
## scripts' TD-workflow-001 precedent.

@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker
@onready var _sub_tab_strip: HBoxContainer = $MainLayout/SubTabStrip
@onready var _loadout_tab_button: Button = $MainLayout/SubTabStrip/LoadoutTabButton
@onready var _skill_tree_tab_button: Button = $MainLayout/SubTabStrip/SkillTreeTabButton
@onready var _sub_screen_host: Control = $MainLayout/SubScreenHost

const HERO_SKILL_BUILD_SCREEN_SCENE: PackedScene = preload("res://src/gameplay/ui/hero_skill_build_screen/HeroSkillBuildScreen.tscn")
const HERO_SKILL_TREE_SCREEN_SCENE: PackedScene = preload("res://src/gameplay/ui/hero_skill_tree_screen/HeroSkillTreeScreen.tscn")

var _loadout_screen: Control
var _skill_tree_screen: Control
## true = Loadout (Hero Skill Build) showing, false = Skill Tree showing.
## Loadout is the default sub-screen on room entry (Core Rule 11 — "the more
## frequently-visited of the two").
var _showing_loadout: bool = true


func _ready() -> void:
	_loadout_screen = HERO_SKILL_BUILD_SCREEN_SCENE.instantiate()
	_skill_tree_screen = HERO_SKILL_TREE_SCREEN_SCENE.instantiate()
	_sub_screen_host.add_child(_loadout_screen)
	_sub_screen_host.add_child(_skill_tree_screen)

	_loadout_tab_button.pressed.connect(_show_loadout)
	_skill_tree_tab_button.pressed.connect(_show_skill_tree)

	_refresh_sub_screen_visibility()


## RoomHost contract (ADR-0032 Section 1) — delegates to both children's own
## disconnect_own_subscriptions(), since this room's own _ready() makes no
## EventBus subscriptions of its own (only button.pressed, self-cleaning on
## queue_free()).
func disconnect_own_subscriptions() -> void:
	if _loadout_screen != null and _loadout_screen.has_method(&"disconnect_own_subscriptions"):
		_loadout_screen.call(&"disconnect_own_subscriptions")
	if _skill_tree_screen != null and _skill_tree_screen.has_method(&"disconnect_own_subscriptions"):
		_skill_tree_screen.call(&"disconnect_own_subscriptions")


## Bumpers never trigger a tab-strip switch (Core Rule 11) — this is the
## room's own internal lateral navigation, handled here rather than
## delegated to either sub-screen (neither has any reason to know about the
## other).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"room_bumper_left") or event.is_action_pressed(&"room_bumper_right"):
		_toggle_sub_screen()
		get_viewport().set_input_as_handled()


func _toggle_sub_screen() -> void:
	if _showing_loadout:
		_show_skill_tree()
	else:
		_show_loadout()


func _show_loadout() -> void:
	_showing_loadout = true
	_refresh_sub_screen_visibility()


func _show_skill_tree() -> void:
	_showing_loadout = false
	_refresh_sub_screen_visibility()


func _refresh_sub_screen_visibility() -> void:
	_loadout_screen.visible = _showing_loadout
	_skill_tree_screen.visible = not _showing_loadout
	_loadout_tab_button.button_pressed = _showing_loadout
	_skill_tree_tab_button.button_pressed = not _showing_loadout


# ---------------------------------------------------------------------------
# Test/inspection accessors
# ---------------------------------------------------------------------------

func is_showing_loadout() -> bool:
	return _showing_loadout


func get_loadout_screen() -> Control:
	return _loadout_screen


func get_skill_tree_screen() -> Control:
	return _skill_tree_screen
