## Free tower placement (ADR-0005 amendment 2026-11-04): a tower is a square
## centred anywhere. Its logical cells (rounded block, single owner) feed every
## cell-based system; every cell the square overlaps becomes non-walkable.
extends GdUnitTestSuite

const CELL := 64.0
## Row 5 is a PATH lane; rows 0-4 of columns 0-7 are PLACEABLE.
const PATH_ROW := 5

var _grid: Grid


func before_test() -> void:
	var cfg := GridConfig.new()
	cfg.cols = 8
	cfg.rows = 6
	cfg.cell_size = CELL
	var cells: Dictionary[Vector2i, int] = {}
	for x: int in 8:
		for y: int in 5:
			cells[Vector2i(x, y)] = Grid.CellType.PLACEABLE
		cells[Vector2i(x, PATH_ROW)] = Grid.CellType.PATH
	cfg.cells = cells
	_grid = Grid.new()
	_grid.initialize(cfg)


func after_test() -> void:
	_grid.free()


## World centre of a 1x1 square at fractional cell coordinates (cx, cy) = cell
## centres at .5 offsets: (1.5, 1.5) is exactly cell (1, 1).
func _at(cx: float, cy: float) -> Vector2:
	return Vector2(cx, cy) * CELL


func test_free_placement_aligned_square_covers_only_its_footprint() -> void:
	assert_int(_grid.place_tower_at(1, _at(1.5, 1.5), Vector2i.ONE)).is_equal(OK)
	assert_array(_grid.get_tower_covered_cells(1)).contains_exactly([Vector2i(1, 1)])
	assert_int(_grid.get_occupant(Vector2i(1, 1))).is_equal(1)
	assert_bool(_grid.get_walkable_cell_map().has(Vector2i(2, 1))).is_true()


func test_free_placement_grid_aligned_api_matches_centre_api() -> void:
	assert_int(_grid.place_tower(1, Vector2i(2, 2), Vector2i(2, 2))).is_equal(OK)
	assert_array(_grid.get_tower_covered_cells(1)).contains_exactly_in_any_order(
			[Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)])
	assert_bool(_grid.is_footprint_placeable(Vector2i(3, 3), Vector2i.ONE)).is_false()


func test_free_placement_off_grid_square_blocks_every_cell_it_overlaps() -> void:
	assert_int(_grid.place_tower_at(1, _at(2.2, 1.8), Vector2i.ONE)).is_equal(OK)
	var cover: Array[Vector2i] = _grid.get_tower_covered_cells(1)
	assert_array(cover).contains_exactly_in_any_order(
			[Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)])
	var walk: Dictionary = _grid.get_walkable_cell_map()
	for cell: Vector2i in cover:
		assert_bool(walk.has(cell)).override_failure_message(str(cell)).is_false()
	# Logical cell: square's top-left (1.7, 1.3) rounds to (2, 1).
	assert_int(_grid.get_occupant(Vector2i(2, 1))).is_equal(1)
	assert_int(_grid.get_occupant(Vector2i(1, 1))).is_equal(-1)
	# A cell the square only partly covers can't take a grid-aligned tower.
	assert_bool(_grid.is_placeable(Vector2i(1, 2))).is_false()


func test_free_placement_touching_squares_share_a_covered_cell() -> void:
	assert_int(_grid.place_tower_at(1, _at(1.8, 1.5), Vector2i.ONE)).is_equal(OK)
	assert_int(_grid.place_tower_at(2, _at(2.8, 1.5), Vector2i.ONE)).is_equal(OK)
	# Both cover cell (2, 1); logical cells stay disjoint.
	assert_int(_grid.get_occupant(Vector2i(1, 1))).is_equal(1)
	assert_int(_grid.get_occupant(Vector2i(2, 1))).is_equal(2)
	_grid.remove_tower(1)
	assert_bool(_grid.get_walkable_cell_map().has(Vector2i(2, 1))).is_false()
	assert_bool(_grid.get_walkable_cell_map().has(Vector2i(1, 1))).is_true()
	_grid.remove_tower(2)
	assert_bool(_grid.get_walkable_cell_map().has(Vector2i(2, 1))).is_true()


func test_free_placement_rejects_overlap_with_another_square() -> void:
	assert_int(_grid.place_tower_at(1, _at(2.0, 2.0), Vector2i.ONE)).is_equal(OK)
	assert_bool(_grid.is_square_placeable(_at(2.6, 2.4), Vector2i.ONE)).is_false()
	assert_int(_grid.place_tower_at(2, _at(2.6, 2.4), Vector2i.ONE)).is_equal(Grid.GRID_WRITE_REJECTED)


func test_free_placement_rejects_squares_reaching_into_the_path_or_off_grid() -> void:
	assert_bool(_grid.is_square_placeable(_at(3.5, 4.8), Vector2i.ONE)).is_false()  # overlaps row 5
	assert_bool(_grid.is_square_placeable(_at(3.5, 4.5), Vector2i.ONE)).is_true()   # flush with it
	assert_bool(_grid.is_square_placeable(_at(0.3, 1.5), Vector2i.ONE)).is_false()  # past column 0


func test_free_placement_snap_pulls_near_aligned_positions_onto_the_grid() -> void:
	var snapped: Vector2 = _grid.snap_center(_at(1.62, 1.9), Vector2i.ONE, 0.2)
	assert_float(snapped.x).is_equal_approx(1.5 * CELL, 0.001)  # 0.12 off: snapped
	assert_float(snapped.y).is_equal_approx(1.9 * CELL, 0.001)  # 0.4 off: left free
	var big: Vector2 = _grid.snap_center(_at(3.1, 2.9), Vector2i(2, 2), 0.2)
	assert_vector(big).is_equal_approx(_at(3.0, 3.0), Vector2(0.001, 0.001))
