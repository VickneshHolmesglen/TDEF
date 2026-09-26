## Wind-up presentation Task 7: SceneManager holds the mission for HERO_DEATH_HOLD_SECONDS after
## hero_died so the death sequence can play. Same real-autoload injection pattern as
## scene_manager_test.gd (stub scene paths, hold shortened to 0.2 s).
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
	if GSceneManager._transition_in_progress:
		await GEventBus.scene_transition_completed
	GSceneManager._cancel_death_hold()
	_spy.disconnect_all()
	_spy = null
	GSceneManager._death_hold_seconds = GSceneManager.HERO_DEATH_HOLD_SECONDS
	GSceneManager._inject(_original_mission_path, _original_sanctuary_path)
	GSceneManager._transition_in_progress = false


func test_hero_died_does_not_transition_immediately_but_does_after_the_hold() -> void:
	GEventBus.hero_died.emit()
	assert_int(_spy.count("scene_transition_started")).is_equal(0)
	assert_bool(GSceneManager.is_death_exit_pending()).is_true()
	await get_tree().create_timer(0.35).timeout
	assert_int(_spy.count("scene_transition_started")).is_equal(1)
	assert_bool(GSceneManager.is_death_exit_pending()).is_false()


func test_a_second_hero_died_during_the_hold_does_not_stack_a_second_transition() -> void:
	GEventBus.hero_died.emit()
	GEventBus.hero_died.emit()
	await get_tree().create_timer(0.35).timeout
	assert_int(_spy.count("scene_transition_started")).is_equal(1)


func test_a_retry_phase_change_during_the_hold_cancels_the_exit() -> void:
	GEventBus.hero_died.emit()
	GEventBus.mission_phase_changed.emit("DEFEAT", "COUNTDOWN", 0.0)
	assert_bool(GSceneManager.is_death_exit_pending()).is_false()
	await get_tree().create_timer(0.35).timeout
	assert_int(_spy.count("scene_transition_started")).is_equal(0)


func test_the_defeat_phase_change_does_not_cancel_the_hold() -> void:
	GEventBus.hero_died.emit()
	GEventBus.mission_phase_changed.emit("WAVE", "DEFEAT", 0.0)
	assert_bool(GSceneManager.is_death_exit_pending()).is_true()


func test_mission_complete_during_the_hold_transitions_once_and_cancels_the_pending_exit() -> void:
	GEventBus.hero_died.emit()
	GEventBus.mission_phase_changed.emit("WAVE", "MISSION_COMPLETE", 0.0)
	assert_bool(GSceneManager.is_death_exit_pending()).is_false()
	await get_tree().create_timer(0.35).timeout
	assert_int(_spy.count("scene_transition_started")).is_equal(1)


func test_hero_died_while_a_transition_is_in_flight_starts_no_hold() -> void:
	GSceneManager._transition_in_progress = true
	GEventBus.hero_died.emit()
	assert_bool(GSceneManager.is_death_exit_pending()).is_false()
	GSceneManager._transition_in_progress = false  # set by hand: after_test would otherwise await a completion that never comes


func test_zero_hold_transitions_immediately() -> void:
	GSceneManager._death_hold_seconds = 0.0
	GEventBus.hero_died.emit()
	assert_int(_spy.count("scene_transition_started")).is_equal(1)
