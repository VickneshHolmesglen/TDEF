## Spawn assignment by path cost (pathfinding.md Rule 3, 2026-11-04).
## Two SPAWNs separated by a wall: B's lane runs along the bottom row and up
## the right column to the GOAL. Cells on that lane are as close to A as to B
## in straight-line terms, so the old Chebyshev assignment handed them to A,
## whose template does not contain them, and find_path() fell back to A*.
##
##   row 0: A . . . . G
##   row 1: # # # # # .
##   row 2: # # # # # .
##   row 3: B . . . . .
extends GdUnitTestSuite

const SPAWN_A := Vector2i(0, 0)
const SPAWN_B := Vector2i(0, 3)
const GOAL := Vector2i(5, 0)

var _grid: Grid
var _event_bus: EventBus
var _pathfinding: PathfindingSystem


func _make_config() -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 6
	cfg.rows = 4
	cfg.cell_size = 64.0
	var cells: Dictionary[Vector2i, int] = {}
	for x: int in range(6):
		for y: int in range(4):
			cells[Vector2i(x, y)] = Grid.CellType.BLOCKED
	for x: int in range(1, 5):
		cells[Vector2i(x, 0)] = Grid.CellType.PATH
		cells[Vector2i(x, 3)] = Grid.CellType.PATH
	for y: int in range(1, 4):
		cells[Vector2i(5, y)] = Grid.CellType.PATH
	cells[SPAWN_A] = Grid.CellType.SPAWN
	cells[SPAWN_B] = Grid.CellType.SPAWN
	cells[GOAL] = Grid.CellType.GOAL
	cfg.cells = cells
	return cfg


func before_test() -> void:
	_grid = Grid.new()
	_event_bus = EventBus.new()
	_pathfinding = PathfindingSystem.new()
	_pathfinding._inject(_grid, _event_bus)
	add_child(_event_bus)
	add_child(_grid)
	add_child(_pathfinding)
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)


func after_test() -> void:
	_pathfinding.queue_free()
	_grid.queue_free()
	_event_bus.queue_free()


func test_cell_on_second_lane_uses_that_lanes_template_without_fallback() -> void:
	# (3,3) is Chebyshev 3 from both spawns; the tie used to go to A.
	var result: Array[Vector2i] = _pathfinding.find_path(Vector2i(3, 3), 0)
	assert_str(_pathfinding.last_fallback_warning).is_empty()
	assert_array(result).contains_exactly(
			[Vector2i(4, 3), Vector2i(5, 3), Vector2i(5, 2), Vector2i(5, 1), GOAL])


func test_every_route_cell_maps_to_a_template_that_contains_it() -> void:
	for spawn_cell: Vector2i in [SPAWN_A, SPAWN_B]:
		for cell: Vector2i in _pathfinding._templates[spawn_cell].path:
			var owner: Vector2i = _pathfinding._spawn_assignment[cell]
			assert_bool(_pathfinding._templates[owner].cell_index_map.has(cell)) \
					.override_failure_message("%s assigned to %s, whose route skips it" % [cell, owner]) \
					.is_true()


func test_every_walkable_cell_is_assigned() -> void:
	for cell: Vector2i in _grid.get_walkable_cell_map():
		assert_bool(_pathfinding._spawn_assignment.has(cell)).is_true()
