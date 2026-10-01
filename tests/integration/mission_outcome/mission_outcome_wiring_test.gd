extends GdUnitTestSuite

## Wiring guard (mission outcome screen spec §4-§7): both mission scenes host a MissionOutcomeScreen,
## whose mere presence in the tree is what opts SceneManager out of the terminal auto-exit (no
## explicit opt-in/opt-out call exists any more — see SceneManager.is_mission_outcome_screen_present()).
## The real hero_died and MISSION_COMPLETE are never emitted here: the screen's handlers are called
## directly.

const THE_GAP_PATH: String = "res://src/gameplay/missions/the_gap/the_gap.tscn"
const MISSION_SCENE_PATH: String = "res://src/scenes/MissionScene.tscn"

var _scene: Node


func before_test() -> void:
	GSceneManager._death_hold_seconds = 0.0
	GMissionSelect.reset_to_defaults()
	GMissionSelect._restore_completed = true


func after_test() -> void:
	if is_instance_valid(_scene):
		if _scene.get_parent() != null:
			_scene.get_parent().remove_child(_scene)
		_scene.free()
	_scene = null
	GSceneManager._death_hold_seconds = GSceneManager.HERO_DEATH_HOLD_SECONDS
	GGrid.initialize(GridConfig.new())
	GMissionSelect.reset_to_defaults()


func _check_scene(path: String) -> void:
	var before_scene: Node = get_tree().current_scene
	assert_bool(GSceneManager.is_mission_outcome_screen_present()).is_false()
	_scene = (load(path) as PackedScene).instantiate()
	add_child(_scene)
	var screen: MissionOutcomeScreen = _scene.get_node_or_null("MissionOutcomeScreen") as MissionOutcomeScreen
	assert_object(screen).is_not_null()
	assert_object(screen.get_parent()).is_same(_scene)
	assert_bool(GSceneManager.is_mission_outcome_screen_present()).is_true()
	# Simulated DEFEAT: handler called directly, no real bus emission.
	screen._defeat_delay = 0.0
	screen._on_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)
	await get_tree().process_frame
	assert_bool(screen.is_showing()).is_true()
	# No MissionSelect-armed retry here (the scene self-launches), so Retry is hidden by design.
	assert_bool((screen.find_child("RetryButton", true, false) as Button).visible).is_false()
	assert_object(get_tree().current_scene).is_same(before_scene)
	_scene.get_parent().remove_child(_scene)
	_scene.free()
	_scene = null
	assert_bool(GSceneManager.is_mission_outcome_screen_present()).is_false()


func test_the_gap_hosts_outcome_screen_and_opts_out() -> void:
	await _check_scene(THE_GAP_PATH)


func test_mission_scene_hosts_outcome_screen_and_opts_out() -> void:
	await _check_scene(MISSION_SCENE_PATH)
