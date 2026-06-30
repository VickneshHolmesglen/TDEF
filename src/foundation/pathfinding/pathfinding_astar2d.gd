## AStar2D subclass for PathfindingSystem.
##
## Overrides _estimate_cost() for the super-goal heuristic (GDD Rule 8, F1):
##   - When to_id == _super_goal_id: min Manhattan distance to any GOAL cell
##   - Otherwise: standard Manhattan distance
##
## Overrides _compute_cost() to enforce zero-cost GOAL→super-goal edges (GDD Rule 8):
##   Without this, Godot's default uses euclidean_distance × weight_scale average,
##   which is nonzero for any GOAL cell not at pixel (0,0) — biasing A* toward
##   GOAL cells near the grid origin, silently breaking nearest-GOAL semantics.
##
## Caller responsibilities (PathfindingSystem):
##   1. Set _super_goal_id before any add_point() or A* query.
##   2. Set _grid_cols before any _cell_at() call.
##   3. Set goal_cells before any A* query (checked by _estimate_cost guard).
##   4. Populate _point_positions alongside every add_point() call.
##   5. Call astar.clear() followed by steps 1–4 before each template rebuild.
##
## Test seam: PathfindingSystem overrides _create_fallback_astar() to inject
## a pre-configured instance with empty goal_cells for AC-22b testing.
class_name PathfindingAStar2D
extends AStar2D

## GOAL cells for the super-goal heuristic. MUST be set before any A* query.
## If empty when _estimate_cost fires with to_id == _super_goal_id, a push_error
## is called and INF is returned — safe but visible as a development error.
var goal_cells: Array[Vector2i] = []

## Virtual super-goal node ID. Set to grid_cols * grid_rows before use.
var _super_goal_id: int = 0

## Grid column count for row-major cell decoding: cell.x = point_id % _grid_cols.
var _grid_cols: int = 16

## point_id → Vector2 position used in _compute_cost. Populated by caller alongside add_point().
## GDD mandates using this dict over get_point_position() — Godot 4 API stability not guaranteed.
var _point_positions: Dictionary[int, Vector2] = {}


func _estimate_cost(from_id: int, to_id: int) -> float:
	if to_id == _super_goal_id:
		if goal_cells.is_empty():
			push_error("PathfindingAStar2D._estimate_cost: goal_cells is empty — must be set before any A* query. Returning INF.")
			return INF
		var min_dist: float = INF
		var from_cell: Vector2i = _cell_at(from_id)
		for g: Vector2i in goal_cells:
			var d: float = float(abs(g.x - from_cell.x) + abs(g.y - from_cell.y))
			if d < min_dist:
				min_dist = d
		return min_dist
	if from_id == _super_goal_id:
		return 0.0
	var fc: Vector2i = _cell_at(from_id)
	var tc: Vector2i = _cell_at(to_id)
	return float(abs(tc.x - fc.x) + abs(tc.y - fc.y))


func _compute_cost(from_id: int, to_id: int) -> float:
	if to_id == _super_goal_id:
		return 0.0
	if from_id == _super_goal_id:
		push_error("PathfindingAStar2D._compute_cost: from_id == super_goal_id — super-goal should never be a traversal source.")
		return 0.0
	if not _point_positions.has(from_id) or not _point_positions.has(to_id):
		push_error("PathfindingAStar2D._compute_cost: missing position for point id — _point_positions not populated correctly.")
		return 1.0
	var dist: float = _point_positions[from_id].distance_to(_point_positions[to_id])
	return dist * (get_point_weight_scale(from_id) + get_point_weight_scale(to_id)) / 2.0


## Decode row-major point_id back to grid cell. Inverse of: point_id = cell.y * _grid_cols + cell.x
func _cell_at(point_id: int) -> Vector2i:
	return Vector2i(point_id % _grid_cols, point_id / _grid_cols)
