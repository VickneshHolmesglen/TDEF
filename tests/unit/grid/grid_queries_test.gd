## Tests for Grid spatial queries, walkability, and coordinate conversion (AC-7 through AC-11).
## Grid.new() bypasses _ready() — no EventBus Autoload needed.
extends GdUnitTestSuite

var _grid: Grid

func _make_config_with_spawn() -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 16
	cfg.rows = 12
	cfg.cell_size = 64.0
	cfg.cells = {
		Vector2i(0, 0): Grid.CellType.SPAWN,
		Vector2i(1, 0): Grid.CellType.PATH,
		Vector2i(2, 0): Grid.CellType.GOAL,
		Vector2i(3, 4): Grid.CellType.PLACEABLE,
		Vector2i(4, 4): Grid.CellType.PLACEABLE,
		Vector2i(3, 5): Grid.CellType.PLACEABLE,
		Vector2i(4, 5): Grid.CellType.PLACEABLE,
		Vector2i(5, 5): Grid.CellType.PLACEABLE,
		Vector2i(7, 7): Grid.CellType.PLACEABLE,
	}
	return cfg

func before_test() -> void:
	_grid = Grid.new()
	_grid.initialize(_make_config_with_spawn())

func after_test() -> void:
	_grid.free()


# ---- AC-7: world_to_cell uses floor() ----

func test_grid_world_to_cell_at_exact_cell_boundary() -> void:
	# world_pos.x == 64.0 exactly → belongs to column 1, not 0
	assert_that(_grid.world_to_cell(Vector2(64.0, 0.0))).is_equal(Vector2i(1, 0))

func test_grid_world_to_cell_negative_x_returns_floor_result() -> void:
	# int truncation of -0.00156 = 0; floor gives -1 (correct)
	assert_that(_grid.world_to_cell(Vector2(-0.1, 0.0))).is_equal(Vector2i(-1, 0))

func test_grid_cell_to_world_returns_cell_center() -> void:
	# cell (1,0) center = (64*1 + 32, 64*0 + 32) = (96, 32)
	assert_that(_grid.cell_to_world(Vector2i(1, 0))).is_equal(Vector2(96.0, 32.0))

func test_grid_is_in_bounds_inside_grid() -> void:
	assert_bool(_grid.is_in_bounds(Vector2i(0, 0))).is_true()
	assert_bool(_grid.is_in_bounds(Vector2i(15, 11))).is_true()

func test_grid_is_in_bounds_outside_grid() -> void:
	assert_bool(_grid.is_in_bounds(Vector2i(-1, 0))).is_false()
	assert_bool(_grid.is_in_bounds(Vector2i(16, 0))).is_false()


# ---- AC-8: Walkability map excludes occupied PLACEABLE cells ----

func test_grid_walkable_map_includes_spawn_path_goal() -> void:
	var wmap: Dictionary = _grid.get_walkable_cell_map()
	assert_bool(wmap.has(Vector2i(0, 0))).is_true()  # SPAWN
	assert_bool(wmap.has(Vector2i(1, 0))).is_true()  # PATH
	assert_bool(wmap.has(Vector2i(2, 0))).is_true()  # GOAL

func test_grid_walkable_map_includes_unoccupied_placeable() -> void:
	var wmap: Dictionary = _grid.get_walkable_cell_map()
	assert_bool(wmap.has(Vector2i(3, 4))).is_true()

func test_grid_walkable_map_excludes_occupied_placeable() -> void:
	_grid.place_tower(5, Vector2i(3, 4), Vector2i(1, 1))
	var wmap: Dictionary = _grid.get_walkable_cell_map()
	# Occupied PLACEABLE is absent (absence = non-walkable)
	assert_bool(wmap.has(Vector2i(3, 4))).is_false()

func test_grid_walkable_map_excludes_blocked_cells() -> void:
	# Cells not in config are BLOCKED — absent from walkability map
	var wmap: Dictionary = _grid.get_walkable_cell_map()
	assert_bool(wmap.has(Vector2i(9, 9))).is_false()


# ---- AC-9: get_all_occupied_cells returns a copy ----

func test_grid_occupied_cells_snapshot_unaffected_by_remove() -> void:
	_grid.place_tower(10, Vector2i(3, 4), Vector2i(1, 1))
	var snapshot: Array[Vector2i] = _grid.get_all_occupied_cells()
	assert_int(snapshot.size()).is_equal(1)
	_grid.remove_tower(10)
	# Snapshot must not be mutated by the removal
	assert_int(snapshot.size()).is_equal(1)
	assert_that(snapshot[0]).is_equal(Vector2i(3, 4))


# ---- AC-11: get_occupied_cells_in_radius uses Chebyshev distance ----

func test_grid_chebyshev_radius_2_includes_diagonal_cell() -> void:
	# tower at (5,5) and (7,7): Chebyshev = max(|7-5|, |7-5|) = 2
	_grid.place_tower(1, Vector2i(5, 5), Vector2i(1, 1))
	_grid.place_tower(2, Vector2i(7, 7), Vector2i(1, 1))
	var result: Array[Vector2i] = _grid.get_occupied_cells_in_radius(Vector2i(5, 5), 2)
	assert_bool(result.has(Vector2i(7, 7))).is_true()

func test_grid_chebyshev_radius_1_excludes_distance_2_cell() -> void:
	_grid.place_tower(1, Vector2i(5, 5), Vector2i(1, 1))
	_grid.place_tower(2, Vector2i(7, 7), Vector2i(1, 1))
	var result: Array[Vector2i] = _grid.get_occupied_cells_in_radius(Vector2i(5, 5), 1)
	assert_bool(result.has(Vector2i(7, 7))).is_false()

func test_grid_chebyshev_includes_self_cell() -> void:
	_grid.place_tower(1, Vector2i(5, 5), Vector2i(1, 1))
	var result: Array[Vector2i] = _grid.get_occupied_cells_in_radius(Vector2i(5, 5), 0)
	assert_bool(result.has(Vector2i(5, 5))).is_true()


# ---- Spatial query helpers ----

func test_grid_get_spawn_cells_returns_all_spawn_cells() -> void:
	var spawns: Array[Vector2i] = _grid.get_spawn_cells()
	assert_int(spawns.size()).is_equal(1)
	assert_bool(spawns.has(Vector2i(0, 0))).is_true()

func test_grid_get_goal_cells_returns_all_goal_cells() -> void:
	var goals: Array[Vector2i] = _grid.get_goal_cells()
	assert_int(goals.size()).is_equal(1)
	assert_bool(goals.has(Vector2i(2, 0))).is_true()

func test_grid_get_towers_in_range_returns_unique_entity_ids() -> void:
	_grid.place_tower(42, Vector2i(5, 5), Vector2i(1, 1))
	var result: Array[int] = _grid.get_towers_in_range(Vector2i(5, 5), 1)
	assert_int(result.size()).is_equal(1)
	assert_int(result[0]).is_equal(42)

func test_grid_get_towers_in_range_deduplicates_multi_cell_tower() -> void:
	# A 2×2 tower occupies 4 cells — all within radius 2 of its own top-left.
	# get_towers_in_range must return the tower ID exactly once.
	_grid.place_tower(99, Vector2i(3, 4), Vector2i(2, 2))
	var result: Array[int] = _grid.get_towers_in_range(Vector2i(3, 4), 2)
	assert_int(result.size()).is_equal(1)
	assert_int(result[0]).is_equal(99)
