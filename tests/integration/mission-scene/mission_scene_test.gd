## Integration tests for MissionScene (src/scenes/mission_scene.gd) — the
## generic MISSION-context shell hosting both the Mission Select browsing/
## configuring screen and the live gameplay assembly, closing the real gap
## found and fixed 2026-07-25: `res://src/scenes/MissionScene.tscn`
## (SceneManager's own DEFAULT_MISSION_SCENE_PATH) never existed before this.
##
## Live-verified end-to-end via Godot MCP (run_project against this exact
## scene, real "the_gap" mission data): Grid initialized with the real
## authored GridConfig (1 real spawn cell), WaveManager transitioned to a
## real SCOUT phase, Hero spawned at the exact correct world position
## derived from the real spawn cell, and the content swap (browsing screen
## -> gameplay) fired correctly on mission_launched. These automated tests
## cover the same mechanism at the unit/integration level.
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _scene: Node2D


func before_test() -> void:
	GMissionSelect.reset_to_defaults()
	GMissionSelect._restore_completed = true
	_runner = scene_runner("res://src/scenes/MissionScene.tscn")
	@warning_ignore("unsafe_cast")
	_scene = _runner.scene() as Node2D


func after_test() -> void:
	GMissionSelect.reset_to_defaults()


func test_mission_select_screen_is_visible_and_gameplay_hidden_at_fresh_mount() -> void:
	var mission_select_screen: Control = _scene.get_node("MissionSelectScreen") as Control
	var gameplay_root: Node2D = _scene.get_node("GameplayRoot") as Node2D

	assert_bool(mission_select_screen.visible).is_true()
	assert_bool(gameplay_root.visible).is_false()


func test_confirming_a_real_launch_swaps_to_gameplay() -> void:
	GMissionSelect.select_mission("the_gap")

	# mission_launched is emitted synchronously inside confirm_launch() and
	# MissionScene connects to it directly (not CONNECT_DEFERRED) -- by the
	# time confirm_launch() returns, the content swap has already happened.
	# Awaiting the signal here would hang forever (it already fired).
	GMissionSelect.confirm_launch()

	var mission_select_screen: Control = _scene.get_node("MissionSelectScreen") as Control
	var gameplay_root: Node2D = _scene.get_node("GameplayRoot") as Node2D
	assert_bool(mission_select_screen.visible).is_false()
	assert_bool(gameplay_root.visible).is_true()


func test_confirming_a_real_launch_initializes_grid_from_the_real_mission_data() -> void:
	GMissionSelect.select_mission("the_gap")

	GMissionSelect.confirm_launch()

	# "the_gap"'s own authored GridConfig has exactly 1 SPAWN cell and 1 GOAL
	# cell (assets/data/missions/entries/the_gap_entry.tres) -- confirms Grid
	# was genuinely initialized from the real mission's data, not left stale.
	assert_int(GGrid.get_spawn_cells().size()).is_equal(1)
	assert_int(GGrid.get_goal_cells().size()).is_equal(1)


func test_hero_is_positioned_at_the_real_spawn_cell() -> void:
	GMissionSelect.select_mission("the_gap")

	GMissionSelect.confirm_launch()

	var hero: Hero = _scene.get_node("GameplayRoot/Hero") as Hero
	var expected_position: Vector2 = GGrid.cell_to_world(GGrid.get_spawn_cells()[0])
	assert_vector(hero.global_position).is_equal_approx(expected_position, Vector2(0.5, 0.5))
