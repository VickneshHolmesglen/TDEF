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

var _transition_in_progress: bool = false


func _ready() -> void:
	GEventBus.hero_died.connect(_on_hero_died)
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)


func _exit_tree() -> void:
	GEventBus.hero_died.disconnect(_on_hero_died)
	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)


## Inject alternate scene paths. Tests only — including re-injecting the live
## GSceneManager autoload with stub paths, since SceneManager is a singleton
## and tests must redirect its real transition targets rather than isolate a
## second instance (see tests/unit/scene_manager/scene_manager_test.gd header
## comment for why). GDScript has no real access modifiers to enforce
## "tests only" — this is convention, matching game_data_registry.gd.
func _inject(mission_scene_path: String, sanctuary_scene_path: String, tarot_deck_scene_path: String = DEFAULT_TAROT_DECK_SCENE_PATH) -> void:
	_mission_scene_path = mission_scene_path
	_sanctuary_scene_path = sanctuary_scene_path
	_tarot_deck_scene_path = tarot_deck_scene_path

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

# =============================================================================
# Transition sequencing
# =============================================================================

func _do_transition(target_context: String, mission_id: String, scene_path: String) -> void:
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
	GEventBus.scene_transition_completed.emit(target_context, mission_id)

# =============================================================================
# Terminal mission event handlers — the only trigger path for a transition
# =============================================================================

func _on_hero_died() -> void:
	transition_to_sanctuary()


func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	if new_phase == "MISSION_COMPLETE":
		transition_to_sanctuary()
