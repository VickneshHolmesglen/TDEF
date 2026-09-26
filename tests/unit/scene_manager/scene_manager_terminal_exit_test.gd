## Mission outcome screen Task 3: SceneManager's terminal auto-exit opt-out (ADR-0002). Same
## real-autoload injection pattern as scene_manager_death_hold_test.gd.
extends GdUnitTestSuite

const STUB_SCENE_PATH: String = "res://tests/fixtures/scene_manager/StubScene.tscn"

var _spy: EventBusSpy
var _original_mission_path: String
var _original_sanctuary_path: String


func before_test() -> void:
	_original_mission_path = GSceneManager._mission_scene_path
	_original_sanctuary_path = GSceneManager._sanctuary_scene_path
	GSceneManager._inject(STUB_SCENE_PATH, STUB_SCENE_PATH)
	GSceneManager._death_hold_seconds = 0.2
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.scene_transition_started)


func after_test() -> void:
	GSceneManager.set_terminal_auto_exit(true)
	if GSceneManager._transition_in_progress:
		await GEventBus.scene_transition_completed
	GSceneManager._cancel_death_hold()
	_spy.disconnect_all()
	_spy = null
	GSceneManager._death_hold_seconds = GSceneManager.HERO_DEATH_HOLD_SECONDS
	GSceneManager._inject(_original_mission_path, _original_sanctuary_path)
	GSceneManager._transition_in_progress = false


func test_auto_exit_is_enabled_by_default() -> void:
	assert_bool(GSceneManager.is_terminal_auto_exit_enabled()).is_true()


func test_set_terminal_auto_exit_round_trips() -> void:
	GSceneManager.set_terminal_auto_exit(false)
	assert_bool(GSceneManager.is_terminal_auto_exit_enabled()).is_false()
	GSceneManager.set_terminal_auto_exit(true)
	assert_bool(GSceneManager.is_terminal_auto_exit_enabled()).is_true()


func test_opted_out_hero_died_neither_transitions_nor_arms_a_hold() -> void:
	GSceneManager.set_terminal_auto_exit(false)
	GEventBus.hero_died.emit()
	assert_bool(GSceneManager.is_death_exit_pending()).is_false()
	await get_tree().create_timer(0.35).timeout
	assert_int(_spy.count("scene_transition_started")).is_equal(0)


func test_opted_out_mission_complete_does_not_transition() -> void:
	GSceneManager.set_terminal_auto_exit(false)
	GEventBus.mission_phase_changed.emit("WAVE", "MISSION_COMPLETE", 0.0)
	assert_int(_spy.count("scene_transition_started")).is_equal(0)


func test_restored_hero_died_arms_the_hold_and_transitions() -> void:
	GSceneManager.set_terminal_auto_exit(false)
	GSceneManager.set_terminal_auto_exit(true)
	GEventBus.hero_died.emit()
	assert_bool(GSceneManager.is_death_exit_pending()).is_true()
	await get_tree().create_timer(0.35).timeout
	assert_int(_spy.count("scene_transition_started")).is_equal(1)


func test_restored_mission_complete_transitions() -> void:
	GSceneManager.set_terminal_auto_exit(false)
	GSceneManager.set_terminal_auto_exit(true)
	GEventBus.mission_phase_changed.emit("WAVE", "MISSION_COMPLETE", 0.0)
	assert_int(_spy.count("scene_transition_started")).is_equal(1)


func test_opted_out_still_cancels_a_pending_hold_on_a_retry_phase() -> void:
	GEventBus.hero_died.emit()
	assert_bool(GSceneManager.is_death_exit_pending()).is_true()
	GSceneManager.set_terminal_auto_exit(false)
	GEventBus.mission_phase_changed.emit("DEFEAT", "COUNTDOWN", 0.0)
	assert_bool(GSceneManager.is_death_exit_pending()).is_false()
