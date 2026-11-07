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

## A square must overlap a cell by more than this (world units) to cover it,
## and two tower squares may touch within it without counting as overlapping.
## Keeps a grid-aligned square from covering its neighbours through float error.
const COVER_EPSILON: float = 0.5

## Returned by all write functions when the grid is not ACTIVE_WRITABLE or
## when placement preconditions fail. Equals ERR_UNAVAILABLE from Godot's Error enum.
const GRID_WRITE_REJECTED: int = ERR_UNAVAILABLE

# Internal state — never expose references to these directly.
# Dictionary[Vector2i, CellType] would be ideal; int fallback per ADR-0005 risk note.
var _cell_types: Dictionary[Vector2i, int] = {}
# Terrain (spec 2026-11-07-3d-terrain §4.1): height level per cell (absent = 0)
# and water cells (absent = dry). Hills block walking; water blocks building.
var _heights: Dictionary[Vector2i, int] = {}
var _water: Dictionary[Vector2i, bool] = {}
var _occupancy: Dictionary[Vector2i, int] = {}
# Free placement (ADR-0005 amendment 2026-11-04). _occupancy above holds each
# tower's LOGICAL cells (its square rounded to the grid: single owner, what
# constellation / mastery / boss scans / range read). These hold the tower's
# true world-space square and every cell that square overlaps (COVERED cells,
# non-walkable). For a grid-aligned tower covered == logical.
var _tower_rects: Dictionary[int, Rect2] = {}
var _tower_cover: Dictionary[int, Array] = {}
var _cover_count: Dictionary[Vector2i, int] = {}
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
	_heights = config.heights.duplicate()
	_water = config.water.duplicate()
	_occupancy.clear()
	_tower_rects.clear()
	_tower_cover.clear()
	_cover_count.clear()
	_state = GridState.ACTIVE_WRITABLE
	GEventBus.grid_initialized.emit(_grid_cols, _grid_rows, _cell_size)


# ---------------------------------------------------------------------------
# Write API (Tower System only — convention enforced by code review)
# ---------------------------------------------------------------------------

## Place a tower on a grid-aligned footprint. Same as place_tower_at() with
## the footprint's centre. Returns OK or GRID_WRITE_REJECTED.
func place_tower(tower_id: int, top_left: Vector2i, size: Vector2i) -> Error:
	return place_tower_at(tower_id, footprint_center(top_left, size), size)


## Free placement: place a tower whose size-cell square is centred on
## `center` (world units, anywhere). Returns GRID_WRITE_REJECTED if the state
## is not ACTIVE_WRITABLE or is_square_placeable() fails. Records the logical
## cells (logical_top_left()) in occupancy and every overlapped cell as covered.
##
## Example: GGrid.place_tower_at(7, Vector2(100.0, 40.0), Vector2i(1, 1))
func place_tower_at(tower_id: int, center: Vector2, size: Vector2i) -> Error:
	if _state != GridState.ACTIVE_WRITABLE:
		return GRID_WRITE_REJECTED
	if not is_square_placeable(center, size):
		return GRID_WRITE_REJECTED
	var top_left: Vector2i = logical_top_left(center, size)
	for col: int in range(size.x):
		for row: int in range(size.y):
			_occupancy[top_left + Vector2i(col, row)] = tower_id
	var rect: Rect2 = square_rect(center, size)
	var cover: Array[Vector2i] = covered_cells(rect)
	_tower_rects[tower_id] = rect
	_tower_cover[tower_id] = cover
	for cell: Vector2i in cover:
		_cover_count[cell] = _cover_count.get(cell, 0) + 1
	return OK


## Remove all cells occupied or covered by tower_id. O(N_occupied) linear scan.
func remove_tower(tower_id: int) -> void:
	var to_clear: Array[Vector2i] = []
	for cell: Vector2i in _occupancy:
		if _occupancy[cell] == tower_id:
			to_clear.append(cell)
	for cell: Vector2i in to_clear:
		_occupancy.erase(cell)
	for cell: Vector2i in _tower_cover.get(tower_id, []):
		var left: int = _cover_count.get(cell, 0) - 1
		if left > 0:
			_cover_count[cell] = left
		else:
			_cover_count.erase(cell)
	_tower_cover.erase(tower_id)
	_tower_rects.erase(tower_id)


# ---------------------------------------------------------------------------
# Read API — placement validation
# ---------------------------------------------------------------------------

## True if a 1×1 tower fits exactly on this cell (PLACEABLE, not occupied,
## not overlapped by any tower's square).
func is_placeable(cell: Vector2i) -> bool:
	return is_square_placeable(cell_to_world(cell), Vector2i.ONE)


## True if a grid-aligned footprint fits (see is_square_placeable()).
func is_footprint_placeable(top_left: Vector2i, size: Vector2i) -> bool:
	return is_square_placeable(footprint_center(top_left, size), size)


## Free placement check: every cell the square overlaps is PLACEABLE, dry and
## at one height level (no straddling a slope), none of
## its logical cells is occupied, and it does not overlap another tower's
## square (touching is fine). Covered cells may be shared between towers.
func is_square_placeable(center: Vector2, size: Vector2i) -> bool:
	var rect: Rect2 = square_rect(center, size)
	for cell: Vector2i in covered_cells(rect):
		if get_cell_type(cell) != CellType.PLACEABLE:
			return false
	if square_height_level(center, size) < 0:
		return false
	var top_left: Vector2i = logical_top_left(center, size)
	for col: int in range(size.x):
		for row: int in range(size.y):
			if _occupancy.has(top_left + Vector2i(col, row)):
				return false
	var inner: Rect2 = rect.grow(-COVER_EPSILON)
	for other: Rect2 in _tower_rects.values():
		if inner.intersects(other):
			return false
	return true


## World-space square of a size-cell tower centred on `center`.
func square_rect(center: Vector2, size: Vector2i) -> Rect2:
	var extent: Vector2 = Vector2(size) * _cell_size
	return Rect2(center - extent * 0.5, extent)


## Every cell `rect` overlaps by more than COVER_EPSILON.
func covered_cells(rect: Rect2) -> Array[Vector2i]:
	var first: Vector2i = world_to_cell(rect.position + Vector2.ONE * COVER_EPSILON)
	var last: Vector2i = world_to_cell(rect.end - Vector2.ONE * COVER_EPSILON)
	var result: Array[Vector2i] = []
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			result.append(Vector2i(x, y))
	return result


## The grid-aligned block a free-placed square counts as for cell-based
## systems: the square's top-left corner rounded to the nearest cell corner.
## Two non-overlapping squares always round to disjoint blocks.
func logical_top_left(center: Vector2, size: Vector2i) -> Vector2i:
	var corner: Vector2 = (center - Vector2(size) * _cell_size * 0.5) / _cell_size
	return Vector2i(roundi(corner.x), roundi(corner.y))


## World centre of a grid-aligned footprint.
func footprint_center(top_left: Vector2i, size: Vector2i) -> Vector2:
	return cell_to_world(top_left) + Vector2(size - Vector2i.ONE) * _cell_size * 0.5


## Cells a placed tower's square overlaps (non-walkable). Empty if unknown.
func get_tower_covered_cells(tower_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(_tower_cover.get(tower_id, []))
	return result


## World centre of a placed tower's square, or Vector2.INF for an unknown id.
## Gridless range checks (WorldRange) measure from here.
## Usage: GGrid.get_tower_center(state.tower_id)
func get_tower_center(tower_id: int) -> Vector2:
	if not _tower_rects.has(tower_id):
		return Vector2.INF
	return _tower_rects[tower_id].get_center()


## Moves `center` onto the grid-aligned position on each axis where it is
## within snap_cells of it, so aligned building stays effortless.
##
## Example: GGrid.snap_center(mouse_world, Vector2i(1, 1), 0.2)
func snap_center(center: Vector2, size: Vector2i, snap_cells: float) -> Vector2:
	var aligned: Vector2 = footprint_center(logical_top_left(center, size), size)
	var limit: float = snap_cells * _cell_size
	var result: Vector2 = center
	if absf(center.x - aligned.x) <= limit:
		result.x = aligned.x
	if absf(center.y - aligned.y) <= limit:
		result.y = aligned.y
	return result


# ---------------------------------------------------------------------------
# Read API — cell queries
# ---------------------------------------------------------------------------

## Returns the cell's type; BLOCKED for any cell not present in the config.
func get_cell_type(cell: Vector2i) -> CellType:
	if not _cell_types.has(cell):
		return CellType.BLOCKED
	return _cell_types[cell]


## Terrain height level of a cell (0 = ground, 1 = hill, 2 = high hill).
func get_height_level(cell: Vector2i) -> int:
	return _heights.get(cell, 0)


## True if the cell is water (a river; a PATH cell with water is a ford).
func is_water(cell: Vector2i) -> bool:
	return _water.get(cell, false)


## Height level shared by every cell a size-cell square centred on `center`
## covers, or -1 when they differ or any covered cell is water.
##
## Example: GGrid.square_height_level(center, Vector2i.ONE)
func square_height_level(center: Vector2, size: Vector2i) -> int:
	var level: int = -1
	for cell: Vector2i in covered_cells(square_rect(center, size)):
		if is_water(cell):
			return -1
		var h: int = get_height_level(cell)
		if level == -1:
			level = h
		elif h != level:
			return -1
	return level


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
## Absent key means non-walkable (BLOCKED, occupied PLACEABLE, or a hill).
## Returns a copy — callers must not cache across tower_placed/tower_removed events.
func get_walkable_cell_map() -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in _cell_types:
		var ct: int = _cell_types[cell]
		match ct:
			CellType.PATH, CellType.SPAWN, CellType.GOAL:
				result[cell] = true
			CellType.PLACEABLE:
				if not _occupancy.has(cell) and not _cover_count.has(cell) and _heights.get(cell, 0) == 0:
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
