class_name SceneManager
extends Node

## SceneManager — Autoload #6 (ADR-0002, revised 2026-05-24).
##
## Owns SANCTUARY <-> MISSION scene transitions exclusively — no other system
## may call get_tree().change_scene_to_packed() directly. Publishes
## scene_transition_started before unloading the current scene and
## scene_transition_completed after the new scene's _ready() has run.
##
## Only initiates a transition in response to terminal mission events
## (mission_complete via mission_phase_changed, or hero_died). Wave Manager
## emits both only from terminal FSM states, so mid-wave transitions are
## architecturally impossible by this design (ADR-0002 Risks).
##
## SceneManager and Wave Manager are independent FSMs: SceneManager does not
## know which mission phase is active; Wave Manager does not know which scene
## is loaded. Neither file references the other's class or private fields.
##
## Usage:
##   GSceneManager.transition_to_mission("the_gap")
##   GSceneManager.transition_to_sanctuary()

const DEFAULT_MISSION_SCENE_PATH: String = "res://src/scenes/MissionScene.tscn"
const DEFAULT_SANCTUARY_SCENE_PATH: String = "res://src/scenes/SanctuaryScene.tscn"
const DEFAULT_TAROT_DECK_SCENE_PATH: String = "res://src/scenes/TarotDeckUIScene.tscn"
const DEFAULT_MAIN_MENU_SCENE_PATH: String = "res://src/scenes/MainMenu.tscn"

# Test injection seam — override via _inject() before add_child() triggers _ready().
# SanctuaryScene.tscn was created 2026-07-20 (src/scenes/sanctuary_scene.gd) as a
# minimal connective-tissue stub — see that file's own doc comment for why. Tests
# still point these at stub fixture scenes instead of the real ones (isolation,
# not because the real scenes are missing). MissionScene.tscn genuinely still
# does not exist — there is no generic mission-select-driven scene yet, only
# the_gap.tscn as a directly-booted concrete mission.
var _mission_scene_path: String = DEFAULT_MISSION_SCENE_PATH
var _sanctuary_scene_path: String = DEFAULT_SANCTUARY_SCENE_PATH
## Added 2026-07-25, closing Sanctuary UI Epic 10 Story 010's/Tarot Deck UI
## Epic 11 Story 002's own flagged gap: Sanctuary UI's Loadout tab had a
## fully-real 4-step ordered hand-off sequence with no actual scene-
## transition call at the end (no SceneManager method existed to reach
## Tarot Deck UI at all). ADR-0002's own Decision text currently enumerates
## exactly 2 top-level contexts ("SANCTUARY and MISSION") — this is a real,
## not-yet-formally-classified expansion to a 3rd lateral context
## (TAROT_DECK), flagged here rather than silently treated as already
## covered by that ADR. TarotDeckUI itself already calls
## transition_to_sanctuary() on its own real, working Cancel/return path
## (Tarot Deck UI Story 003) — this closes the missing other direction.
var _tarot_deck_scene_path: String = DEFAULT_TAROT_DECK_SCENE_PATH

## Added 2026-08-23, closing Pause Menu's "Quit to Main Menu" gap (deferred
## 2026-07-08 pending Settings/Objective/a real Main Menu scene existing —
## all 3 now do). Same real, not-yet-formally-classified expansion beyond
## ADR-0002's original 2-context ("SANCTUARY and MISSION") enumeration that
## `_tarot_deck_scene_path` already flagged above — a 4th lateral context,
## MAIN_MENU, this time leaving the play session entirely rather than moving
## between in-session contexts. Flagged here rather than silently treated as
## already covered.
var _main_menu_scene_path: String = DEFAULT_MAIN_MENU_SCENE_PATH

var _transition_in_progress: bool = false

## Wind-up presentation spec §5.4: how long the mission stays up after the Hero dies so the death
## sequence can play before returning to the Sanctuary. Injectable (tests set 0).
const HERO_DEATH_HOLD_SECONDS: float = 1.5
var _death_hold_seconds: float = HERO_DEATH_HOLD_SECONDS
var _death_exit_timer: SceneTreeTimer = null

## Fade-in from black after every scene swap (2026-10-05 polish pass), so transitions read as a
## deliberate cut instead of a hard pop. Purely visual and non-blocking: the swap itself and
## scene_transition_completed keep their exact timing. 0 disables it (tests may set that).
const FADE_IN_SECONDS: float = 0.3
var _fade_in_seconds: float = FADE_IN_SECONDS
const _FADE_LAYER: int = 128
const FADE_HOLD_FRAMES: int = 2
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _fade_tween: Tween = null



func _ready() -> void:
	_create_button_feedback()
	GEventBus.hero_died.connect(_on_hero_died)
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)


func _exit_tree() -> void:
	_cancel_death_hold()
	GEventBus.hero_died.disconnect(_on_hero_died)
	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)


## Inject alternate scene paths. Tests only — including re-injecting the live
## GSceneManager autoload with stub paths, since SceneManager is a singleton
## and tests must redirect its real transition targets rather than isolate a
## second instance (see tests/unit/scene_manager/scene_manager_test.gd header
## comment for why). GDScript has no real access modifiers to enforce
## "tests only" — this is convention, matching game_data_registry.gd.
func _inject(mission_scene_path: String, sanctuary_scene_path: String, tarot_deck_scene_path: String = DEFAULT_TAROT_DECK_SCENE_PATH, main_menu_scene_path: String = DEFAULT_MAIN_MENU_SCENE_PATH) -> void:
	_mission_scene_path = mission_scene_path
	_sanctuary_scene_path = sanctuary_scene_path
	_tarot_deck_scene_path = tarot_deck_scene_path
	_main_menu_scene_path = main_menu_scene_path

# =============================================================================
# Public API (ADR-0002 SceneManager Responsibilities)
# =============================================================================

## Transition from SANCTUARY to the mission scene. Idempotent no-op if a
## transition is already in flight — see _do_transition's guard.
func transition_to_mission(mission_id: String) -> void:
	_do_transition("MISSION", mission_id, _mission_scene_path)


## Transition from MISSION back to the sanctuary scene. Idempotent no-op if a
## transition is already in flight — see _do_transition's guard.
func transition_to_sanctuary() -> void:
	_do_transition("SANCTUARY", "", _sanctuary_scene_path)


## Transition from SANCTUARY to the Tarot Deck UI scene (Sanctuary UI's
## Loadout hand-off, added 2026-07-25). Idempotent no-op if a transition is
## already in flight — see _do_transition's guard. Return path is
## TarotDeckUI's own existing transition_to_sanctuary() call (Story 003),
## not a separate method here.
func transition_to_tarot_deck_ui() -> void:
	_do_transition("TAROT_DECK", "", _tarot_deck_scene_path)


## Transition from MISSION (via Pause Menu's "Quit to Main Menu") straight to
## the Main Menu scene, leaving the play session entirely rather than
## returning to Sanctuary. Idempotent no-op if a transition is already in
## flight — see _do_transition's guard.
func transition_to_main_menu() -> void:
	_do_transition("MAIN_MENU", "", _main_menu_scene_path)

## Mission outcome screen spec §4 (ADR-0002): true when a MissionOutcomeScreen is mounted
## anywhere in the live tree, in which case it — not SceneManager — owns the mission-end exit
## (hero_died, MISSION_COMPLETE). Derived from the tree every call, not a manually toggled flag:
## the screen adds itself to its own group in _ready() and the engine clears that membership
## automatically the moment it's freed, so a mission scene needs no explicit opt-in/opt-out call
## at all — mounting or freeing the screen IS the opt-out.
func is_mission_outcome_screen_present() -> bool:
	return get_tree().get_first_node_in_group(MissionOutcomeScreen.GROUP_NAME) != null

# =============================================================================
# Transition sequencing
# =============================================================================

## Belt-and-braces: always leaves the tree unpaused, so a terminal panel or pause menu can
## never strand the next scene in a paused state.
func _do_transition(target_context: String, mission_id: String, scene_path: String) -> void:
	_cancel_death_hold()
	get_tree().paused = false
	if _transition_in_progress:
		return
	_transition_in_progress = true

	GEventBus.scene_transition_started.emit(target_context, mission_id)

	var packed_scene: PackedScene = ResourceLoader.load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("[SceneManager] %s: failed to load as PackedScene." % scene_path)
		_transition_in_progress = false
		return

	get_tree().change_scene_to_packed(packed_scene)

	# change_scene_to_packed() defers the actual swap to the end of the current
	# frame — await one process_frame so the new scene's _ready() has run
	# before announcing completion (ADR-0002: "after new scene is ready").
	await get_tree().process_frame
	# Safe even if self became invalid during the await: _transition_in_progress
	# is an instance member, so a freed self has no future caller left to
	# observe a stale true value. SceneManager persists for the whole game
	# session as Autoload #6 (ADR-0002) — this branch is only reachable in
	# practice when a non-autoload test instance is torn down mid-await.
	if not is_instance_valid(self): return

	# Reset the guard BEFORE emitting scene_transition_completed. Awaiting a
	# signal in GDScript resumes the awaiter synchronously as part of the
	# emit() call chain, before this function continues past the emit() line
	# — so any caller awaiting this signal and immediately starting a new
	# transition (e.g. mission -> sanctuary back-to-back) would see a stale
	# _transition_in_progress = true and be silently dropped, hanging forever
	# waiting for a completion signal that would never come. Confirmed by a
	# real 5-minute test timeout during code review before this fix.
	_transition_in_progress = false
	_play_fade_in()
	GEventBus.scene_transition_completed.emit(target_context, mission_id)


## Hosts the global button hover/press feedback here because SceneManager lives for the whole
## session and owns "what a screen change looks like" -- the same lifetime UiAudioBinder gets
## from the audio autoload.
func _create_button_feedback() -> void:
	if get_node_or_null("ButtonFeedbackBinder") != null:
		return
	var binder := ButtonFeedbackBinder.new()
	binder.name = "ButtonFeedbackBinder"
	binder.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(binder)
	binder.setup(get_tree())


## Covers the freshly swapped-in scene with black and fades it out. The overlay ignores the
## mouse, so input is never blocked even mid-fade.
func _play_fade_in() -> void:
	if _fade_in_seconds <= 0.0:
		return
	if _fade_layer == null:
		_fade_layer = CanvasLayer.new()
		_fade_layer.name = "SceneFade"
		_fade_layer.layer = _FADE_LAYER
		_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		_fade_rect = ColorRect.new()
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade_layer.add_child(_fade_rect)
		add_child(_fade_layer)
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_rect.color = Color.BLACK
	_fade_layer.visible = true
	# Hold black through the new scene's first frames: those carry its load/_ready hitch, and a
	# tween stepped with that one huge delta would skip almost the whole fade (seen live).
	for i in FADE_HOLD_FRAMES:
		await get_tree().process_frame
		if not is_instance_valid(self) or not _fade_layer.visible:
			return
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(_fade_rect, "color:a", 0.0, _fade_in_seconds) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_callback(func() -> void: _fade_layer.visible = false)


## True while the post-transition fade overlay is still visible.
func is_fade_in_playing() -> bool:
	return _fade_layer != null and _fade_layer.visible

# =============================================================================
# Terminal mission event handlers — the only trigger path for a transition
# =============================================================================

## True while a delayed Hero-death exit to the Sanctuary is waiting out the death hold.
func is_death_exit_pending() -> bool:
	return _death_exit_timer != null


func _on_hero_died() -> void:
	if is_mission_outcome_screen_present():
		return
	if _transition_in_progress or _death_exit_timer != null:
		return
	if _death_hold_seconds <= 0.0:
		transition_to_sanctuary()
		return
	_death_exit_timer = get_tree().create_timer(_death_hold_seconds)
	_death_exit_timer.timeout.connect(_on_death_hold_elapsed)


func _on_death_hold_elapsed() -> void:
	_death_exit_timer = null
	transition_to_sanctuary()


## SceneTreeTimers cannot be cancelled, so cancelling disconnects the callback and drops the reference.
func _cancel_death_hold() -> void:
	if _death_exit_timer == null:
		return
	if _death_exit_timer.timeout.is_connected(_on_death_hold_elapsed):
		_death_exit_timer.timeout.disconnect(_on_death_hold_elapsed)
	_death_exit_timer = null


func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	# A Retry reuses the scene and never calls _do_transition: its phase change out of DEFEAT is
	# what cancels a pending death exit (wind-up presentation spec §5.4, edge case 1).
	if new_phase != "DEFEAT" and new_phase != "MISSION_COMPLETE":
		_cancel_death_hold()
	if new_phase == "MISSION_COMPLETE" and not is_mission_outcome_screen_present():
		transition_to_sanctuary()
