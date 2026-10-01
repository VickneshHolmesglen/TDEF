## Mission outcome screen Task 3: SceneManager's terminal auto-exit is derived from whether a
## MissionOutcomeScreen is present anywhere in the live tree (ADR-0002), not a manually toggled
## flag. These tests mount/unmount a bare Node tagged with the screen's own group to simulate
## presence, exactly as get_first_node_in_group() would see a real MissionOutcomeScreen — same
## real-autoload injection pattern as scene_manager_death_hold_test.gd.
extends GdUnitTestSuite

const STUB_SCENE_PATH: String = "res://tests/fixtures/scene_manager/StubScene.tscn"

var _spy: EventBusSpy
var _original_mission_path: String
var _original_sanctuary_path: String
var _outcome_stub: Node = null


func before_test() -> void:
	_original_mission_path = GSceneManager._mission_scene_path
	_original_sanctuary_path = GSceneManager._sanctuary_scene_path
	GSceneManager._inject(STUB_SCENE_PATH, STUB_SCENE_PATH)
	GSceneManager._death_hold_seconds = 0.2
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.scene_transition_started)


func after_test() -> void:
	_unmount_outcome_screen_stub()
	if GSceneManager._transition_in_progress:
		await GEventBus.scene_transition_completed
	GSceneManager._cancel_death_hold()
	_spy.disconnect_all()
	_spy = null
	GSceneManager._death_hold_seconds = GSceneManager.HERO_DEATH_HOLD_SECONDS
	GSceneManager._inject(_original_mission_path, _original_sanctuary_path)
	GSceneManager._transition_in_progress = false


## Tags a bare Node with MissionOutcomeScreen's own group and adds it to the live tree — the same
## membership get_first_node_in_group(GROUP_NAME) would see for a real screen instance.
func _mount_outcome_screen_stub() -> void:
	_outcome_stub = Node.new()
	_outcome_stub.add_to_group(MissionOutcomeScreen.GROUP_NAME)
	get_tree().root.add_child(_outcome_stub)


func _unmount_outcome_screen_stub() -> void:
	if _outcome_stub != null and is_instance_valid(_outcome_stub):
		if _outcome_stub.get_parent() != null:
			_outcome_stub.get_parent().remove_child(_outcome_stub)
		_outcome_stub.free()
	_outcome_stub = null


func test_no_screen_present_by_default() -> void:
	assert_bool(GSceneManager.is_mission_outcome_screen_present()).is_false()


func test_mission_outcome_screen_presence_round_trips_with_the_tree() -> void:
	_mount_outcome_screen_stub()
	assert_bool(GSceneManager.is_mission_outcome_screen_present()).is_true()
	_unmount_outcome_screen_stub()
	assert_bool(GSceneManager.is_mission_outcome_screen_present()).is_false()


func test_a_mounted_screen_means_hero_died_neither_transitions_nor_arms_a_hold() -> void:
	_mount_outcome_screen_stub()
	GEventBus.hero_died.emit()
	assert_bool(GSceneManager.is_death_exit_pending()).is_false()
	await get_tree().create_timer(0.35).timeout
	assert_int(_spy.count("scene_transition_started")).is_equal(0)


func test_a_mounted_screen_means_mission_complete_does_not_transition() -> void:
	_mount_outcome_screen_stub()
	GEventBus.mission_phase_changed.emit("WAVE", "MISSION_COMPLETE", 0.0)
	assert_int(_spy.count("scene_transition_started")).is_equal(0)


func test_hero_died_arms_the_hold_and_transitions_once_the_screen_is_gone() -> void:
	_mount_outcome_screen_stub()
	_unmount_outcome_screen_stub()
	GEventBus.hero_died.emit()
	assert_bool(GSceneManager.is_death_exit_pending()).is_true()
	await get_tree().create_timer(0.35).timeout
	assert_int(_spy.count("scene_transition_started")).is_equal(1)


func test_mission_complete_transitions_once_the_screen_is_gone() -> void:
	_mount_outcome_screen_stub()
	_unmount_outcome_screen_stub()
	GEventBus.mission_phase_changed.emit("WAVE", "MISSION_COMPLETE", 0.0)
	assert_int(_spy.count("scene_transition_started")).is_equal(1)


func test_a_mounted_screen_still_cancels_a_pending_hold_on_a_retry_phase() -> void:
	GEventBus.hero_died.emit()
	assert_bool(GSceneManager.is_death_exit_pending()).is_true()
	_mount_outcome_screen_stub()
	GEventBus.mission_phase_changed.emit("DEFEAT", "COUNTDOWN", 0.0)
	assert_bool(GSceneManager.is_death_exit_pending()).is_false()
