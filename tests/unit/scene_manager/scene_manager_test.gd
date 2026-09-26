## Unit tests for SceneManager (S4-01, ADR-0002). Covers AC-1, AC-5, AC-6.
##
## AC-5 tests inject the REAL GSceneManager autoload (not a locally-created
## instance) with stub scene paths before emitting global EventBus signals.
## SceneManager is a singleton Autoload — the real GSceneManager is always
## live and subscribed to hero_died/mission_phase_changed for the whole test
## suite's duration, so a locally-constructed second instance does not
## isolate a test from it. Emitting these signals without first injecting
## safe stub paths into the real autoload causes it to attempt loading the
## real (not-yet-existing, S4-09) default scene paths and error. Same
## injection pattern as tests/integration/foundation/scene_manager_transition_test.gd.
extends GdUnitTestSuite

const STUB_SCENE_PATH: String = "res://tests/fixtures/scene_manager/StubScene.tscn"

var _spy: EventBusSpy
var _original_mission_path: String
var _original_sanctuary_path: String


func before_test() -> void:
	_original_mission_path = GSceneManager._mission_scene_path
	_original_sanctuary_path = GSceneManager._sanctuary_scene_path
	GSceneManager._inject(STUB_SCENE_PATH, STUB_SCENE_PATH)
	GSceneManager._death_hold_seconds = 0.0

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.scene_transition_started)


func after_test() -> void:
	get_tree().paused = false
	# Wait for any in-flight transition triggered by this test to actually
	# resolve before tearing down — a fixed frame-count guess here would risk
	# a leftover coroutine emitting scene_transition_completed into the NEXT
	# test's fresh spy after this one returns (flaky cross-test pollution).
	if GSceneManager._transition_in_progress:
		await GEventBus.scene_transition_completed
	_spy.disconnect_all()
	_spy = null
	GSceneManager._death_hold_seconds = GSceneManager.HERO_DEATH_HOLD_SECONDS
	GSceneManager._inject(_original_mission_path, _original_sanctuary_path)
	GSceneManager._transition_in_progress = false

# ---------------------------------------------------------------------------
# AC-1: Autoload registration order (pure static file check — no instance needed)
# ---------------------------------------------------------------------------

func test_autoload_registered_immediately_after_gamedataregistry_and_before_wavemanager() -> void:
	var text: String = FileAccess.get_file_as_string("res://project.godot")
	var registry_idx: int = text.find("GGameDataRegistry=")
	var scene_manager_idx: int = text.find("GSceneManager=")
	var wave_manager_idx: int = text.find("GWaveManager=")
	assert_int(registry_idx).is_greater(-1)
	assert_int(scene_manager_idx).is_greater(-1)
	assert_int(wave_manager_idx).is_greater(-1)
	assert_bool(registry_idx < scene_manager_idx).is_true()
	assert_bool(scene_manager_idx < wave_manager_idx).is_true()


func test_autoload_script_path_matches_adr_0002() -> void:
	var text: String = FileAccess.get_file_as_string("res://project.godot")
	assert_bool(text.contains("GSceneManager=\"*res://src/core/scene_manager.gd\"")).is_true()

# ---------------------------------------------------------------------------
# AC-5: Transition trigger restriction (uses the real, injected GSceneManager)
# ---------------------------------------------------------------------------

func test_unrelated_eventbus_signal_does_not_trigger_transition() -> void:
	GEventBus.wave_started.emit(1, 5, 1.0)
	assert_int(_spy.count("scene_transition_started")).is_equal(0)


func test_mission_phase_changed_non_terminal_does_not_trigger_transition() -> void:
	GEventBus.mission_phase_changed.emit("SCOUT", "WAVE_ACTIVE", 0.0)
	assert_int(_spy.count("scene_transition_started")).is_equal(0)


func test_mission_complete_phase_triggers_exactly_one_transition() -> void:
	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)
	assert_int(_spy.count("scene_transition_started")).is_equal(1)


func test_hero_died_and_mission_complete_same_frame_triggers_exactly_one_transition() -> void:
	# Race condition: both terminal events could theoretically fire in the same
	# frame. _transition_in_progress guard ensures exactly one transition, not two.
	GEventBus.hero_died.emit()
	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)
	assert_int(_spy.count("scene_transition_started")).is_equal(1)


func test_external_double_call_while_transition_in_progress_is_silently_dropped() -> void:
	# Same guard, exercised via a direct external caller (not an internal
	# EventBus race) — e.g. gameplay code calling transition_to_mission()
	# twice in quick succession.
	GSceneManager.transition_to_mission("first_mission")
	GSceneManager.transition_to_mission("second_mission")
	assert_int(_spy.count("scene_transition_started")).is_equal(1)
	var started_args: Array = (_spy.emissions["scene_transition_started"] as Array)[0] as Array
	assert_str(started_args[1] as String).is_equal("first_mission")

# ---------------------------------------------------------------------------
# AC-6: FSM independence (static/structural check — no instance needed)
# ---------------------------------------------------------------------------

func test_scene_manager_source_does_not_reference_wave_manager() -> void:
	# Checks the actual coupling pattern (the GWaveManager autoload singleton
	# reference or the WaveManager class), not incidental prose mentions —
	# scene_manager.gd's own header comment legitimately documents the
	# Autoload boot order and may mention "WaveManager" in prose.
	var text: String = FileAccess.get_file_as_string("res://src/core/scene_manager.gd")
	assert_bool(text.contains("GWaveManager")).is_false()
	assert_bool(text.contains("WaveManager.")).is_false()
	assert_bool(text.contains("WaveManager.new()")).is_false()


func test_wave_manager_source_does_not_reference_scene_manager() -> void:
	# Same rationale: wave_manager.gd's header comment documents the Autoload
	# boot order and legitimately mentions "SceneManager" in prose (added
	# during S4-06's implementation) — that is not code coupling. Check for
	# the actual coupling pattern instead.
	var text: String = FileAccess.get_file_as_string("res://src/gameplay/wave_manager.gd")
	assert_bool(text.contains("GSceneManager")).is_false()
	assert_bool(text.contains("SceneManager.")).is_false()
	assert_bool(text.contains("SceneManager.new()")).is_false()


func test_transition_forces_tree_unpaused() -> void:
	get_tree().paused = true
	GSceneManager.transition_to_sanctuary()
	assert_bool(get_tree().paused).is_false()
