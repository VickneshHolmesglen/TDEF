class_name SceneTransitionGuard
extends RefCounted
## Test helper: stops a test from leaking a whole real scene.
##
## Emitting MISSION_COMPLETE / DEFEAT (or pressing Launch / Loadout) makes the
## live GSceneManager change scene for real. Nothing frees the scene it loads,
## so every node in it is counted as an orphan (2026-11-03: ~4,000 across the
## suite). The guard points SceneManager at the one-node stub fixture, then
## waits for any transition, restores the paths and the current scene, and
## frees whatever was loaded -- scene_manager_transition_test.gd's pattern.
##
## Usage:
##   var _guard: SceneTransitionGuard
##   func before_test() -> void:
##       _guard = SceneTransitionGuard.new(get_tree())
##   func after_test() -> void:
##       await _guard.release()

const STUB_SCENE_PATH: String = "res://tests/fixtures/scene_manager/StubScene.tscn"

var _tree: SceneTree
var _mission_path: String
var _sanctuary_path: String
var _tarot_path: String
var _main_menu_path: String
var _death_hold: float
var _current_scene: Node


func _init(tree: SceneTree) -> void:
	_tree = tree
	_mission_path = GSceneManager._mission_scene_path
	_sanctuary_path = GSceneManager._sanctuary_scene_path
	_tarot_path = GSceneManager._tarot_deck_scene_path
	_main_menu_path = GSceneManager._main_menu_scene_path
	_death_hold = GSceneManager._death_hold_seconds
	_current_scene = tree.current_scene
	GSceneManager._inject(STUB_SCENE_PATH, STUB_SCENE_PATH, STUB_SCENE_PATH, STUB_SCENE_PATH)
	GSceneManager._death_hold_seconds = 0.0


## Waits out a running transition, restores SceneManager, and frees the
## scene a transition loaded (if any).
func release() -> void:
	if GSceneManager._transition_in_progress:
		await GEventBus.scene_transition_completed
	GSceneManager._inject(_mission_path, _sanctuary_path, _tarot_path, _main_menu_path)
	GSceneManager._death_hold_seconds = _death_hold
	GSceneManager._transition_in_progress = false
	var loaded: Node = _tree.current_scene
	if is_instance_valid(_current_scene):
		_tree.current_scene = _current_scene
	if loaded != null and is_instance_valid(loaded) and loaded != _current_scene:
		loaded.free()
