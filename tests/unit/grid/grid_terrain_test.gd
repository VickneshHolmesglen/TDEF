## Terrain facts on the grid (spec 2026-11-07-3d-terrain §4): hills block
## monsters but allow building; water is walkable but never buildable; a tower
## square may not straddle two height levels.
extends GdUnitTestSuite

const CELL := 64.0

var _grid: Grid


## 6x4 board: PATH row at y=1, PLACEABLE elsewhere. (3,2) is a level-1 hill,
## (4,2) is water, (2,1) is a ford (PATH + water).
static func make_config() -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 6
	cfg.rows = 4
	cfg.cell_size = CELL
	var cells: Dictionary[Vector2i, int] = {}
	for x: int in 6:
		for y: int in 4:
			cells[Vector2i(x, y)] = Grid.CellType.PATH if y == 1 else Grid.CellType.PLACEABLE
	cfg.cells = cells
	cfg.heights = {Vector2i(3, 2): 1}
	cfg.water = {Vector2i(4, 2): true, Vector2i(2, 1): true}
	return cfg


func before_test() -> void:
	_grid = Grid.new()
	_grid.initialize(make_config())


func after_test() -> void:
	_grid.free()


func test_hill_cell_not_walkable() -> void:
	assert_bool(_grid.get_walkable_cell_map().has(Vector2i(3, 2))).is_false()


func test_water_cell_walkable() -> void:
	var walk: Dictionary[Vector2i, bool] = _grid.get_walkable_cell_map()
	assert_bool(walk.has(Vector2i(4, 2))).is_true()
	assert_bool(walk.has(Vector2i(2, 1))).is_true()


func test_water_cell_not_placeable() -> void:
	assert_bool(_grid.is_placeable(Vector2i(4, 2))).is_false()


func test_hill_cell_placeable() -> void:
	assert_bool(_grid.is_placeable(Vector2i(3, 2))).is_true()


func test_square_over_mixed_heights_not_placeable() -> void:
	var mid: Vector2 = Vector2(3.0, 2.5) * CELL
	assert_bool(_grid.is_square_placeable(mid, Vector2i.ONE)).is_false()


func test_square_height_level() -> void:
	assert_int(_grid.square_height_level(_grid.cell_to_world(Vector2i(3, 2)), Vector2i.ONE)).is_equal(1)
	assert_int(_grid.square_height_level(Vector2(3.0, 2.5) * CELL, Vector2i.ONE)).is_equal(-1)
	assert_int(_grid.get_height_level(Vector2i(0, 0))).is_equal(0)
	assert_bool(_grid.is_water(Vector2i(2, 1))).is_true()
	assert_bool(_grid.is_water(Vector2i(0, 0))).is_false()


func test_validate_rejects_height_on_path() -> void:
	var cfg: GridConfig = make_config()
	cfg.heights[Vector2i(0, 1)] = 1
	assert_array(cfg.validate()).is_not_empty()


func test_validate_rejects_water_with_height() -> void:
	var cfg: GridConfig = make_config()
	cfg.heights[Vector2i(4, 2)] = 1
	assert_array(cfg.validate()).is_not_empty()


func test_validate_rejects_height_out_of_range() -> void:
	var cfg: GridConfig = make_config()
	cfg.heights[Vector2i(0, 3)] = 3
	assert_array(cfg.validate()).is_not_empty()


func test_validate_accepts_fixture() -> void:
	assert_array(make_config().validate()).is_empty()


func test_tuning_defaults() -> void:
	var t: TerrainTuning = TerrainTuning.load_default()
	assert_float(t.hill_cost_per_level).is_equal(0.25)
	assert_int(t.hill_range_per_level).is_equal(1)
	assert_float(t.water_monster_speed_mult).is_equal(0.6)
	assert_float(t.water_hero_speed_mult).is_equal(0.7)
	assert_float(t.water_hero_linger_seconds).is_equal(3.0)
	assert_float(t.min_buildable_share).is_equal(0.4)
	assert_float(t.height_per_level_cells).is_equal(0.5)
