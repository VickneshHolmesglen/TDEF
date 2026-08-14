## Unit tests for MapGenerator (player-requested 2026-08-15) --
## src/core/mission_select/map_generator.gd.
##
## Connectivity is checked here via a direct BFS flood-fill over the
## generated cells dictionary (BLOCKED impassable, everything else
## walkable) rather than the real PathfindingSystem/AStar2D machinery --
## this is a pure data-shape test with no Autoload dependencies, matching
## design/gdd/pathfinding.md AC-13c's own stated validation approach
## (simulate reachability on the initial grid state).
extends GdUnitTestSuite

const COLS: int = 16
const ROWS: int = 12
const CELL_SIZE: float = 64.0


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## BFS from spawn_cell over every non-BLOCKED cell; returns true if
## goal_cell is reached.
func _is_connected(cells: Dictionary, spawn_cell: Vector2i, goal_cell: Vector2i, cols: int, rows: int) -> bool:
	var visited: Dictionary[Vector2i, bool] = {spawn_cell: true}
	var queue: Array[Vector2i] = [spawn_cell]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == goal_cell:
			return true
		for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + offset
			if next.x < 0 or next.x >= cols or next.y < 0 or next.y >= rows:
				continue
			if visited.has(next):
				continue
			if (cells.get(next, Grid.CellType.BLOCKED) as int) == Grid.CellType.BLOCKED:
				continue
			visited[next] = true
			queue.append(next)
	return false


func test_generated_dimensions_match_input() -> void:
	var config: GridConfig = MapGenerator.generate(COLS, ROWS, CELL_SIZE, _seeded_rng(1))
	assert_int(config.cols).is_equal(COLS)
	assert_int(config.rows).is_equal(ROWS)
	assert_float(config.cell_size).is_equal_approx(CELL_SIZE, 0.001)
	assert_array(config.validate()).is_empty()


func test_border_ring_is_blocked_except_spawn_and_goal() -> void:
	var config: GridConfig = MapGenerator.generate(COLS, ROWS, CELL_SIZE, _seeded_rng(2))
	var non_blocked_border: Array[Vector2i] = []
	for x: int in range(COLS):
		for cell: Vector2i in [Vector2i(x, 0), Vector2i(x, ROWS - 1)]:
			if (config.cells[cell] as int) != Grid.CellType.BLOCKED:
				non_blocked_border.append(cell)
	for y: int in range(ROWS):
		for cell: Vector2i in [Vector2i(0, y), Vector2i(COLS - 1, y)]:
			if (config.cells[cell] as int) != Grid.CellType.BLOCKED:
				non_blocked_border.append(cell)
	# Exactly 2 non-BLOCKED border cells: one SPAWN (left edge), one GOAL (right edge).
	assert_int(non_blocked_border.size()).is_equal(2)


func test_exactly_one_spawn_and_one_goal_cell() -> void:
	var config: GridConfig = MapGenerator.generate(COLS, ROWS, CELL_SIZE, _seeded_rng(3))
	var spawn_count: int = 0
	var goal_count: int = 0
	for cell: Vector2i in config.cells:
		var type: int = config.cells[cell] as int
		if type == Grid.CellType.SPAWN:
			spawn_count += 1
		elif type == Grid.CellType.GOAL:
			goal_count += 1
	assert_int(spawn_count).is_equal(1)
	assert_int(goal_count).is_equal(1)


func test_spawn_cell_is_on_left_edge_and_goal_on_right_edge() -> void:
	var config: GridConfig = MapGenerator.generate(COLS, ROWS, CELL_SIZE, _seeded_rng(4))
	var spawn_cell: Vector2i = Vector2i(-1, -1)
	var goal_cell: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in config.cells:
		var type: int = config.cells[cell] as int
		if type == Grid.CellType.SPAWN:
			spawn_cell = cell
		elif type == Grid.CellType.GOAL:
			goal_cell = cell
	assert_int(spawn_cell.x).is_equal(0)
	assert_int(goal_cell.x).is_equal(COLS - 1)


func test_spawn_and_goal_are_connected() -> void:
	for seed_value: int in range(20):
		var config: GridConfig = MapGenerator.generate(COLS, ROWS, CELL_SIZE, _seeded_rng(seed_value))
		var spawn_cell: Vector2i = Vector2i(-1, -1)
		var goal_cell: Vector2i = Vector2i(-1, -1)
		for cell: Vector2i in config.cells:
			var type: int = config.cells[cell] as int
			if type == Grid.CellType.SPAWN:
				spawn_cell = cell
			elif type == Grid.CellType.GOAL:
				goal_cell = cell
		assert_bool(_is_connected(config.cells, spawn_cell, goal_cell, COLS, ROWS)) \
				.override_failure_message("seed %d produced a disconnected map (spawn=%s goal=%s)" % [seed_value, spawn_cell, goal_cell]) \
				.is_true()


## Stress test (this file's own class doc comment claims connectivity is
## "guaranteed by construction, not a post-hoc validation step" -- this test
## exists to back that claim with real evidence across many seeds, not just
## trust the algorithm).
func test_100_generations_are_all_connected() -> void:
	for seed_value: int in range(100):
		var config: GridConfig = MapGenerator.generate(COLS, ROWS, CELL_SIZE, _seeded_rng(1000 + seed_value))
		var spawn_cell: Vector2i = Vector2i(-1, -1)
		var goal_cell: Vector2i = Vector2i(-1, -1)
		for cell: Vector2i in config.cells:
			var type: int = config.cells[cell] as int
			if type == Grid.CellType.SPAWN:
				spawn_cell = cell
			elif type == Grid.CellType.GOAL:
				goal_cell = cell
		assert_bool(_is_connected(config.cells, spawn_cell, goal_cell, COLS, ROWS)) \
				.override_failure_message("seed %d produced a disconnected map" % (1000 + seed_value)) \
				.is_true()


func test_path_cells_are_never_on_the_border() -> void:
	var config: GridConfig = MapGenerator.generate(COLS, ROWS, CELL_SIZE, _seeded_rng(5))
	for cell: Vector2i in config.cells:
		if (config.cells[cell] as int) == Grid.CellType.PATH:
			assert_bool(cell.x > 0 and cell.x < COLS - 1 and cell.y > 0 and cell.y < ROWS - 1) \
					.override_failure_message("PATH cell %s is on the border" % cell) \
					.is_true()


func test_every_cell_has_a_type_no_gaps() -> void:
	var config: GridConfig = MapGenerator.generate(COLS, ROWS, CELL_SIZE, _seeded_rng(6))
	assert_int(config.cells.size()).is_equal(COLS * ROWS)


func test_same_seed_produces_identical_layout() -> void:
	var config_a: GridConfig = MapGenerator.generate(COLS, ROWS, CELL_SIZE, _seeded_rng(42))
	var config_b: GridConfig = MapGenerator.generate(COLS, ROWS, CELL_SIZE, _seeded_rng(42))
	assert_int(config_a.cells.size()).is_equal(config_b.cells.size())
	for cell: Vector2i in config_a.cells:
		assert_int(config_b.cells[cell] as int).is_equal(config_a.cells[cell] as int)


func test_different_seeds_produce_different_layouts() -> void:
	var config_a: GridConfig = MapGenerator.generate(COLS, ROWS, CELL_SIZE, _seeded_rng(7))
	var config_b: GridConfig = MapGenerator.generate(COLS, ROWS, CELL_SIZE, _seeded_rng(8))
	var differences: int = 0
	for cell: Vector2i in config_a.cells:
		if (config_b.cells.get(cell, -1) as int) != (config_a.cells[cell] as int):
			differences += 1
	assert_int(differences).is_greater(0)


func test_interior_cells_off_the_path_are_placeable() -> void:
	var config: GridConfig = MapGenerator.generate(COLS, ROWS, CELL_SIZE, _seeded_rng(9))
	for cell: Vector2i in config.cells:
		var type: int = config.cells[cell] as int
		var on_border: bool = cell.x == 0 or cell.x == COLS - 1 or cell.y == 0 or cell.y == ROWS - 1
		if not on_border and type != Grid.CellType.PATH:
			assert_int(type) \
					.override_failure_message("interior non-PATH cell %s should be PLACEABLE, got %d" % [cell, type]) \
					.is_equal(Grid.CellType.PLACEABLE)
