## Pre-computed route from one SPAWN cell to the nearest GOAL cell.
##
## Stores both the ordered path (Array[Vector2i]) and a reverse-lookup map
## (cell_index_map) so PathfindingSystem can slice the remaining path for any
## monster in O(1) time without re-running A*.
##
## Usage (F3 slice pattern — binding):
##   var idx: int = template.cell_index_map[from_cell]
##   var result: Array[Vector2i] = []
##   result.assign(template.path.slice(idx + 1))
##
## build_from_path() is the only write path. After calling it, path and
## cell_index_map are always consistent — never mutate them individually.
class_name RouteTemplate

## Ordered cells from SPAWN to GOAL (GOAL cell included, SPAWN cell included at index 0).
## Empty array means no path exists from this SPAWN to any GOAL.
var path: Array[Vector2i] = []

## Reverse lookup: cell → index in path. O(1) membership test and index retrieval.
## Consistent with path — rebuilt atomically in build_from_path().
var cell_index_map: Dictionary[Vector2i, int] = {}


## Populate path and cell_index_map from a computed A* result.
## raw_path must be ordered SPAWN→GOAL with the super-goal node already stripped.
func build_from_path(raw_path: Array[Vector2i]) -> void:
	path = raw_path
	cell_index_map.clear()
	for i: int in range(path.size()):
		cell_index_map[path[i]] = i


## True if no valid path exists from this SPAWN to any GOAL.
func is_empty() -> bool:
	return path.is_empty()
