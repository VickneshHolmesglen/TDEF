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


# ---------------------------------------------------------------------------
# Tower Build Panel wiring (2026-08-10) — replaces the previous hardcoded
# `place_tower(&"archer", cell)` debug behavior every grid click used to
# trigger regardless of intent. Real mouse-position-dependent grid-click
# dispatch is not exercised here (this project's own established precedent —
# every existing tower-placement test calls TowerSystem.place_tower()
# directly rather than fighting headless mouse-position control); this
# covers the one thing that's actually new: does the scene's pending
# selection state track the real tower_blueprint_selected signal correctly.
# ---------------------------------------------------------------------------

func test_no_blueprint_selected_by_default() -> void:
	assert_str(String(_scene.get("_selected_blueprint_id"))).is_equal("")


func test_tower_blueprint_selected_signal_updates_pending_selection() -> void:
	GEventBus.tower_blueprint_selected.emit(&"frostbolt_turret")

	assert_str(String(_scene.get("_selected_blueprint_id"))).is_equal("frostbolt_turret")


func test_later_selection_replaces_earlier_one() -> void:
	GEventBus.tower_blueprint_selected.emit(&"archer")
	GEventBus.tower_blueprint_selected.emit(&"longshot_sniper")

	assert_str(String(_scene.get("_selected_blueprint_id"))).is_equal("longshot_sniper")


## Regression guard (2026-08-10): a real live-play bug reported as "a red spot
## when I click on a tower" -- design/ux/interaction-patterns.md line 61
## requires a successful placement to "return cursor to free-cursor mode,"
## but the selection was never cleared. The player's mouse then sat over the
## tower just placed, and the next mouse-motion event re-ran the placement
## preview against that now-occupied cell -- rendering the invalid-placement
## (red) cursor directly on top of the tower that was just bought.
func test_successful_placement_clears_selection_and_returns_to_free_cursor() -> void:
	GMissionSelect.select_mission("the_gap")
	GMissionSelect.confirm_launch()
	GEventBus.tower_blueprint_selected.emit(&"archer")

	var placed: bool = _scene.call("_attempt_placement_at", Vector2i(1, 1))

	assert_bool(placed).is_true()
	assert_str(String(_scene.get("_selected_blueprint_id"))).is_equal("")
