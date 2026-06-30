## Grid Autoload — authoritative spatial data store for all mission systems.
##
## Rules (ADR-0005):
##   - Read API is direct-call (any system). Write API is Tower System only (convention).
##   - All array/dictionary returns are COPIES — callers iterate safely without locks.
##   - Writes are rejected with GRID_WRITE_REJECTED during ACTIVE_READONLY.
##   - world_to_cell uses floor() — handles negative coordinates correctly at boundaries.
class_name Grid
extends Node

enum CellType { PLACEABLE, PATH, SPAWN, GOAL, BLOCKED }
enum GridState { UNINITIALIZED, ACTIVE_WRITABLE, ACTIVE_READONLY }

## Returned by all write functions when the grid is not ACTIVE_WRITABLE or
## when placement preconditions fail. Equals ERR_UNAVAILABLE from Godot's Error enum.
const GRID_WRITE_REJECTED: int = ERR_UNAVAILABLE

# Internal state — never expose references to these directly.
# Dictionary[Vector2i, CellType] would be ideal; int fallback per ADR-0005 risk note.
var _cell_types: Dictionary[Vector2i, int] = {}
var _occupancy: Dictionary[Vector2i, int] = {}
var _grid_cols: int = 16
var _grid_rows: int = 12
var _cell_size: float = 64.0
var _state: GridState = GridState.UNINITIALIZED


func _ready() -> void:
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)


func _exit_tree() -> void:
	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)


# ---------------------------------------------------------------------------
# Mission lifecycle API (Mission Select System only)
# ---------------------------------------------------------------------------

## Initialise grid from a GridConfig Resource. Populates cell types, clears occupancy,
## and transitions state to ACTIVE_WRITABLE.
func initialize(config: GridConfig) -> void:
	_grid_cols = config.cols
	_grid_rows = config.rows
	_cell_size = config.cell_size
	_cell_types.clear()
	for cell: Vector2i in config.cells:
		_cell_types[cell] = config.cells[cell]
	_occupancy.clear()
	_state = GridState.ACTIVE_WRITABLE


# ---------------------------------------------------------------------------
# Write API (Tower System only — convention enforced by code review)
# ---------------------------------------------------------------------------

## Place a tower. Returns OK on success or GRID_WRITE_REJECTED if the state
## is not ACTIVE_WRITABLE, any cell is non-PLACEABLE, or any cell is occupied.
func place_tower(tower_id: int, top_left: Vector2i, size: Vector2i) -> Error:
	if _state != GridState.ACTIVE_WRITABLE:
		return GRID_WRITE_REJECTED
	if not is_footprint_placeable(top_left, size):
		return GRID_WRITE_REJECTED
	for col: int in range(size.x):
		for row: int in range(size.y):
			_occupancy[top_left + Vector2i(col, row)] = tower_id
	return OK


## Remove all cells occupied by tower_id. O(N_occupied) linear scan.
func remove_tower(tower_id: int) -> void:
	var to_clear: Array[Vector2i] = []
	for cell: Vector2i in _occupancy:
		if _occupancy[cell] == tower_id:
			to_clear.append(cell)
	for cell: Vector2i in to_clear:
		_occupancy.erase(cell)


# ---------------------------------------------------------------------------
# Read API — placement validation
# ---------------------------------------------------------------------------

## True if cell is PLACEABLE and unoccupied (1×1 placement check).
func is_placeable(cell: Vector2i) -> bool:
	return get_cell_type(cell) == CellType.PLACEABLE and not _occupancy.has(cell)


## True if every cell in the footprint is PLACEABLE and unoccupied.
func is_footprint_placeable(top_left: Vector2i, size: Vector2i) -> bool:
	for col: int in range(size.x):
		for row: int in range(size.y):
			if not is_placeable(top_left + Vector2i(col, row)):
				return false
	return true


# ---------------------------------------------------------------------------
# Read API — cell queries
# ---------------------------------------------------------------------------

## Returns the cell's type; BLOCKED for any cell not present in the config.
func get_cell_type(cell: Vector2i) -> CellType:
	if not _cell_types.has(cell):
		return CellType.BLOCKED
	return _cell_types[cell]


## Returns the tower entity ID occupying the cell, or -1 if unoccupied.
func get_occupant(cell: Vector2i) -> int:
	return _occupancy.get(cell, -1)


# ---------------------------------------------------------------------------
# Read API — spatial queries (all return copies)
# ---------------------------------------------------------------------------

## All cells currently occupied by a tower. Returns a copy.
func get_all_occupied_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _occupancy:
		result.append(cell)
	return result


## Occupied cells within Chebyshev distance <= radius of center. Returns a copy.
## Chebyshev(a,b) = max(|a.x-b.x|, |a.y-b.y|) — treats diagonals as equal to cardinals.
func get_occupied_cells_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _occupancy:
		var dist: int = max(abs(cell.x - center.x), abs(cell.y - center.y))
		if dist <= radius:
			result.append(cell)
	return result


## Unique tower entity IDs for towers within Chebyshev distance <= radius.
## Multi-cell towers appear once regardless of how many cells fall within range.
func get_towers_in_range(center: Vector2i, radius: int) -> Array[int]:
	var seen: Dictionary[int, bool] = {}
	var result: Array[int] = []
	for cell: Vector2i in get_occupied_cells_in_radius(center, radius):
		var id: int = _occupancy[cell]
		if not seen.has(id):
			seen[id] = true
			result.append(id)
	return result


## All SPAWN cells. Returns a copy.
func get_spawn_cells() -> Array[Vector2i]:
	return _cells_of_type(CellType.SPAWN)


## All GOAL cells. Returns a copy.
func get_goal_cells() -> Array[Vector2i]:
	return _cells_of_type(CellType.GOAL)


## Walkability map for Pathfinding. Key present = walkable.
## Absent key means non-walkable (BLOCKED, or occupied PLACEABLE).
## Returns a copy — callers must not cache across tower_placed/tower_removed events.
func get_walkable_cell_map() -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in _cell_types:
		var ct: int = _cell_types[cell]
		match ct:
			CellType.PATH, CellType.SPAWN, CellType.GOAL:
				result[cell] = true
			CellType.PLACEABLE:
				if not _occupancy.has(cell):
					result[cell] = true
	return result


# ---------------------------------------------------------------------------
# Read API — coordinate conversion
# ---------------------------------------------------------------------------

## World position → grid cell. Uses floor() for correct negative-position handling.
func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / _cell_size)),
		int(floor(world_pos.y / _cell_size))
	)


## Grid cell center → world position.
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * _cell_size + _cell_size * 0.5,
		cell.y * _cell_size + _cell_size * 0.5
	)


## True if cell is within grid dimensions.
func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _grid_cols and cell.y >= 0 and cell.y < _grid_rows


## Grid column count. Required by Pathfinding (super_goal_id = cols × rows).
func get_grid_cols() -> int:
	return _grid_cols


## Grid row count. Required by Pathfinding (super_goal_id = cols × rows).
func get_grid_rows() -> int:
	return _grid_rows


# ---------------------------------------------------------------------------
# EventBus handler
# ---------------------------------------------------------------------------

func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	match new_phase:
		"SCOUT", "INTERMISSION":
			_state = GridState.ACTIVE_WRITABLE
		"WAVE_ACTIVE":
			_state = GridState.ACTIVE_READONLY
		"DEFEAT", "OUTCOME":
			_occupancy.clear()
			_state = GridState.UNINITIALIZED


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _cells_of_type(ct: CellType) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _cell_types:
		if _cell_types[cell] == ct:
			result.append(cell)
	return result
