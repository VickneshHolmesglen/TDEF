## Tests for would_block_all_paths(), live-state immutability, and tower_placement_blocked.
## Covers: GDD AC-5, AC-6, AC-18, AC-21 (partial); ADR-0004 validation criteria.
##
## Block map: SPAWN(0,0) → PATH(1,0) → GOAL(2,0) with one additional PLACEABLE col.
## Blocking PATH(1,0) disconnects the only route (1-cell-wide corridor for testing).
##
## Note: 1-cell-wide critical lanes are flagged by the CI validator (AC-13b) in real missions.
## This test intentionally uses such a lane to create a deterministic blocking fixture.
extends GdUnitTestSuite

const SPAWN_CELL := Vector2i(0, 0)
const CHOKE_CELL := Vector2i(1, 0)  # blocking this disconnects SPAWN from GOAL
const GOAL_CELL := Vector2i(2, 0)
const PLACEABLE_A := Vector2i(0, 1)
const PLACEABLE_B := Vector2i(1, 1)
const PLACEABLE_C := Vector2i(2, 1)

# Two-route map: two parallel PATH rows so no single PLACEABLE is a solo blocker.
const SPAWN_2R := Vector2i(0, 0)
const GOAL_2R := Vector2i(3, 0)

var _grid: Grid
var _event_bus: EventBus
var _pathfinding: PathfindingSystem

## Single-route map: SPAWN→PATH→GOAL (1-cell chokepoint at CHOKE_CELL).
func _make_narrow_config() -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 4
	cfg.rows = 2
	cfg.cell_size = 64.0
	cfg.cells = {
		SPAWN_CELL: Grid.CellType.SPAWN,
		CHOKE_CELL: Grid.CellType.PATH,
		GOAL_CELL: Grid.CellType.GOAL,
		PLACEABLE_A: Grid.CellType.PLACEABLE,
		PLACEABLE_B: Grid.CellType.PLACEABLE,
		PLACEABLE_C: Grid.CellType.PLACEABLE,
	}
	return cfg

## Two-route map: SPAWN connects to both routes via two direct neighbors.
## Row 0: SPAWN(0,0) - PATH(1,0) - PATH(2,0) - GOAL(3,0)
##            |
## Row 1:  PATH(0,1) - PATH(1,1) - PATH(2,1) - PATH(3,1) ← adjacent to GOAL(3,0) vertically
##
## Blocking Vector2i(1,0) alone: Route 2 still works → returns false.
## Blocking Vector2i(0,1) alone: Route 1 still works → returns false.
## Blocking [Vector2i(1,0), Vector2i(0,1)]: SPAWN has no connections → returns true,
##   but neither cell ALONE causes the block → primary_blocking_cell == Vector2i(-1,-1).
func _make_two_route_config() -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 4
	cfg.rows = 2
	cfg.cell_size = 64.0
	cfg.cells = {
		SPAWN_2R: Grid.CellType.SPAWN,        # (0,0) — connects right to (1,0) and down to (0,1)
		Vector2i(1, 0): Grid.CellType.PATH,
		Vector2i(2, 0): Grid.CellType.PATH,
		GOAL_2R: Grid.CellType.GOAL,           # (3,0)
		Vector2i(0, 1): Grid.CellType.PATH,    # second connection from SPAWN
		Vector2i(1, 1): Grid.CellType.PATH,
		Vector2i(2, 1): Grid.CellType.PATH,
		Vector2i(3, 1): Grid.CellType.PATH,    # adjacent to GOAL(3,0) → Route 2 reaches GOAL
	}
	return cfg

func before_test() -> void:
	_grid = Grid.new()
	_event_bus = EventBus.new()
	_pathfinding = PathfindingSystem.new()
	_pathfinding._inject(_grid, _event_bus)
	add_child(_event_bus)
	add_child(_grid)
	add_child(_pathfinding)

func after_test() -> void:
	_pathfinding.queue_free()
	_grid.queue_free()
	_event_bus.queue_free()


# ---- AC-5: would_block_all_paths returns true for blocking footprint ----

func test_pathfinding_would_block_all_paths_returns_true_for_sole_chokepoint() -> void:
	_grid.initialize(_make_narrow_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	var result: bool = _pathfinding.would_block_all_paths([CHOKE_CELL])
	assert_bool(result).is_true()


# ---- AC-6: would_block_all_paths returns false for non-blocking footprint ----

func test_pathfinding_would_block_all_paths_returns_false_for_non_blocking_cell() -> void:
	_grid.initialize(_make_narrow_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	# Blocking a PLACEABLE cell that runs parallel to the PATH doesn't disconnect the route
	var result: bool = _pathfinding.would_block_all_paths([PLACEABLE_A])
	assert_bool(result).is_false()


func test_pathfinding_would_block_all_paths_returns_false_with_two_routes_available() -> void:
	_grid.initialize(_make_two_route_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	# Blocking just one path cell still leaves the second route open
	var result: bool = _pathfinding.would_block_all_paths([Vector2i(1, 0)])
	assert_bool(result).is_false()


# ---- AC-18: live walkability map is unchanged after would_block_all_paths ----

func test_pathfinding_would_block_all_paths_does_not_mutate_grid_walkability() -> void:
	_grid.initialize(_make_narrow_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	# Snapshot before
	var before: Dictionary = _grid.get_walkable_cell_map()
	# Call would_block_all_paths (returns true — blocking footprint)
	_pathfinding.would_block_all_paths([CHOKE_CELL])
	# Snapshot after — must be identical
	var after: Dictionary = _grid.get_walkable_cell_map()
	assert_int(before.size()).is_equal(after.size())
	for cell: Vector2i in before:
		assert_bool(after.has(cell)).is_true()


# ---- AC-5: no path_invalidated emitted when placement is rejected ----

func test_pathfinding_would_block_returns_true_no_path_invalidated_emitted() -> void:
	_grid.initialize(_make_narrow_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	var invalidated_count: int = 0
	_event_bus.path_invalidated.connect(func(_cells): invalidated_count += 1)
	_pathfinding.would_block_all_paths([CHOKE_CELL])
	assert_int(invalidated_count).is_equal(0)


# ---- AC-21 (partial): tower_placement_blocked emitted when blocked ----

func test_pathfinding_tower_placement_blocked_emitted_when_would_block_returns_true() -> void:
	_grid.initialize(_make_narrow_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	var state := {"cells": [], "primary": Vector2i(-99, -99)}
	_event_bus.tower_placement_blocked.connect(func(cells, primary):
		state.cells.assign(cells)
		state.primary = primary
	)
	_pathfinding.would_block_all_paths([CHOKE_CELL])
	assert_int(state.cells.size()).is_equal(1)
	assert_object(state.primary).is_equal(CHOKE_CELL)


func test_pathfinding_tower_placement_blocked_not_emitted_when_path_remains() -> void:
	_grid.initialize(_make_narrow_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	var emitted: bool = false
	_event_bus.tower_placement_blocked.connect(func(_c, _p): emitted = true)
	_pathfinding.would_block_all_paths([PLACEABLE_A])
	assert_bool(emitted).is_false()


# ---- primary_blocking_cell sentinel when multi-cell interaction ----

func test_pathfinding_primary_blocking_cell_is_sentinel_for_multi_cell_interaction() -> void:
	# Two-route map: blocking Vector2i(1,0) alone still leaves Route 2 open (via (0,1)).
	# Blocking Vector2i(0,1) alone still leaves Route 1 open (via (1,0)).
	# Blocking BOTH [Vector2i(1,0), Vector2i(0,1)] cuts both connections from SPAWN → blocks all.
	# Since neither is individually load-bearing, primary_blocking_cell == Vector2i(-1,-1).
	_grid.initialize(_make_two_route_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	var state := {"primary": Vector2i(-99, -99)}
	_event_bus.tower_placement_blocked.connect(func(_c, primary):
		state.primary = primary
	)
	_pathfinding.would_block_all_paths([Vector2i(1, 0), Vector2i(0, 1)])
	# Neither cell alone causes the block → sentinel
	assert_object(state.primary).is_equal(Vector2i(-1, -1))
