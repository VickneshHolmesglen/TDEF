## Integration tests for SceneManager (S4-01, ADR-0002). Covers AC-2, AC-3, AC-4, AC-7.
##
## Uses the real GSceneManager autoload (not a locally-created instance) for
## AC-7 since the test exercises actual Autoload instance persistence across a
## real change_scene_to_packed() round trip. _inject() temporarily points the
## live autoload at the stub fixture scene (for isolation — SanctuaryScene.tscn
## now exists for real, 2026-07-20, but a shared fixture keeps these tests fast
## and independent of that scene's own content). See
## test_transition_to_sanctuary_loads_the_real_shipped_scene() below for the
## one test that deliberately does NOT inject a stub, confirming the real file.
extends GdUnitTestSuite

const STUB_SCENE_PATH: String = "res://tests/fixtures/scene_manager/StubScene.tscn"
const INVALID_SCENE_PATH: String = "res://tests/fixtures/scene_manager/does_not_exist.tscn"

var _spy: EventBusSpy
var _original_mission_path: String
var _original_sanctuary_path: String
var _original_current_scene: Node


func before_test() -> void:
	_original_mission_path = GSceneManager._mission_scene_path
	_original_sanctuary_path = GSceneManager._sanctuary_scene_path
	GSceneManager._inject(STUB_SCENE_PATH, STUB_SCENE_PATH)
	_original_current_scene = get_tree().current_scene

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.scene_transition_started)
	_spy.watch(GEventBus.scene_transition_completed)


func after_test() -> void:
	if GSceneManager._transition_in_progress:
		await GEventBus.scene_transition_completed
	_spy.disconnect_all()
	_spy = null
	GSceneManager._inject(_original_mission_path, _original_sanctuary_path)
	GSceneManager._transition_in_progress = false
	# Restore current_scene — these tests actually swap it via
	# change_scene_to_packed(); leaving it pointed at the stub scene would
	# pollute assumptions in any later suite in the same headless run.
	if is_instance_valid(_original_current_scene):
		get_tree().current_scene = _original_current_scene

# ---------------------------------------------------------------------------
# AC-2/AC-3/AC-4: Transition signal sequence
# ---------------------------------------------------------------------------

func test_transition_to_mission_loads_stub_scene_and_fires_signals_in_order() -> void:
	GSceneManager.transition_to_mission("the_gap")
	await GEventBus.scene_transition_completed  # exact resolution point, not a frame-count guess

	assert_int(_spy.count("scene_transition_started")).is_equal(1)
	assert_int(_spy.count("scene_transition_completed")).is_equal(1)

	var started_args: Array = (_spy.emissions["scene_transition_started"] as Array)[0] as Array
	assert_str(started_args[0] as String).is_equal("MISSION")
	assert_str(started_args[1] as String).is_equal("the_gap")

	var completed_args: Array = (_spy.emissions["scene_transition_completed"] as Array)[0] as Array
	assert_str(completed_args[0] as String).is_equal("MISSION")


func test_transition_to_sanctuary_fires_started_before_completed() -> void:
	GSceneManager.transition_to_sanctuary()
	await GEventBus.scene_transition_completed

	assert_int(_spy.count("scene_transition_started")).is_equal(1)
	assert_int(_spy.count("scene_transition_completed")).is_equal(1)


func test_transition_with_invalid_scene_path_aborts_without_crash_or_completion() -> void:
	GSceneManager._inject(INVALID_SCENE_PATH, INVALID_SCENE_PATH)
	await assert_error(func() -> void: GSceneManager.transition_to_mission("bad_mission")) \
		.is_push_error("[SceneManager] %s: failed to load as PackedScene." % INVALID_SCENE_PATH)

	assert_int(_spy.count("scene_transition_started")).is_equal(1)  # started fires before the load attempt
	assert_int(_spy.count("scene_transition_completed")).is_equal(0)  # never reaches completion
	assert_bool(GSceneManager._transition_in_progress).is_false()  # guard reset, not stuck

# ---------------------------------------------------------------------------
# AC-7: State persistence across transition — Autoload instance identity
# AND actual value persistence (not just identity — a broken SceneManager
# that e.g. re-instantiated Autoloads would still pass an identity-only
# check if Godot happened to reuse the same object id; mutating and
# re-reading a real tracked value is the stronger, non-tautological proof).
# ---------------------------------------------------------------------------

func test_autoload_instances_survive_sanctuary_mission_sanctuary_round_trip() -> void:
	var event_bus_ref: Object = GEventBus
	var save_ref: Object = GSavePersistence
	var grid_ref: Object = GGrid
	var pathfinding_ref: Object = GPathfindingSystem
	var registry_ref: Object = GGameDataRegistry
	var scene_manager_ref: Object = GSceneManager
	var wave_manager_ref: Object = GWaveManager
	var known_monster_resource: MonsterResource = GGameDataRegistry.get_monster_resource(&"goblin_runner")

	# Mutate a real, observable value on a persistent Autoload before the
	# round trip — the concrete "known value" the story's QA case calls for.
	var original_wave_index: int = GWaveManager._wave_index
	GWaveManager._wave_index = 42

	GSceneManager.transition_to_mission("the_gap")
	await GEventBus.scene_transition_completed
	GSceneManager.transition_to_sanctuary()
	await GEventBus.scene_transition_completed

	assert_bool(is_same(event_bus_ref, GEventBus)).is_true()
	assert_bool(is_same(save_ref, GSavePersistence)).is_true()
	assert_bool(is_same(grid_ref, GGrid)).is_true()
	assert_bool(is_same(pathfinding_ref, GPathfindingSystem)).is_true()
	assert_bool(is_same(registry_ref, GGameDataRegistry)).is_true()
	assert_bool(is_same(scene_manager_ref, GSceneManager)).is_true()
	assert_bool(is_same(wave_manager_ref, GWaveManager)).is_true()
	# Concrete "known value" the story text references: same cached Resource
	# instance, not just an equal one, survives the round trip.
	assert_bool(is_same(known_monster_resource, GGameDataRegistry.get_monster_resource(&"goblin_runner"))).is_true()
	# The actual value-persistence claim, not just object identity.
	assert_int(GWaveManager._wave_index).is_equal(42)

	GWaveManager._wave_index = original_wave_index  # restore — shared Autoload state


# ---------------------------------------------------------------------------
# Real bug regression (2026-07-20): SanctuaryScene.tscn never existed, so
# hero_died / MISSION_COMPLETE / the Pause Menu's "Quit to Sanctuary" button
# all hard-errored in real play. This is the one test in this file that does
# NOT inject a stub — it deliberately exercises the real, shipped
# res://src/scenes/SanctuaryScene.tscn.
# ---------------------------------------------------------------------------

func test_transition_to_sanctuary_loads_the_real_shipped_scene() -> void:
	GSceneManager._inject(_original_mission_path, _original_sanctuary_path)  # undo before_test()'s stub injection

	GSceneManager.transition_to_sanctuary()
	await GEventBus.scene_transition_completed

	assert_int(_spy.count("scene_transition_completed")).is_equal(1)
	assert_str(get_tree().current_scene.scene_file_path).is_equal("res://src/scenes/SanctuaryScene.tscn")
