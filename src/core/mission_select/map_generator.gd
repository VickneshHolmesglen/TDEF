class_name MapGenerator
extends RefCounted

## Procedurally generates a mission grid layout (player-requested 2026-08-15).
##
## Replaces the 4 hand-authored static GridConfig layouts (the_gap,
## the_foothills, the_hollow, the_narrows) — every mission launch now builds
## a fresh, unique map instead of reloading the same fixed cell layout each
## time. MissionEntry.grid_config is still authored per mission (it supplies
## cols/rows/cell_size), but its `cells` dictionary is no longer read for
## gameplay purposes — generate() builds a brand-new layout at launch time
## from those dimensions instead. See mission_select.gd's confirm_launch().
##
## Algorithm: a single winding corridor is randomly walked from a SPAWN cell
## on the left border to a GOAL cell on the right border, biased toward
## reducing distance to the goal but with enough randomness to wind rather
## than run straight (matches the existing hand-authored missions' visual
## character). Every walked cell becomes PATH; every other interior cell
## becomes PLACEABLE — still walkable at Formula-cost 10 if a player boxes
## in the PATH lane with towers, matching this project's existing maze-
## tower-defense model (see design/gdd/pathfinding.md's cost table). The
## 1-cell border ring is BLOCKED except the single SPAWN and GOAL gaps.
##
## Connectivity is guaranteed by construction, not by a post-hoc validation
## step: the walk itself performs a proper backtracking depth-first search
## (a "growing tree" maze algorithm), which — because the interior has no
## static obstacles besides the border — is mathematically guaranteed to
## reach the goal cell (it explores every cell in its own connected
## component before giving up, and the entire open interior is one
## component). This satisfies design/gdd/pathfinding.md's AC-13c ("at least
## one valid route of length >= 2 from SPAWN to GOAL") without needing a
## runtime A* check on every generated map. A straight-line connector
## fallback exists as a defensive last resort (see _walk()'s own comment)
## in case that guarantee is ever violated by a future change to this file.

const MIN_DIMENSION: int = 5  ## smallest cols/rows this generator can produce a valid interior for


## cols/rows/cell_size: forwarded onto the returned GridConfig unchanged.
## rng: injectable for deterministic tests; a fresh randomized generator is
## used if omitted.
static func generate(cols: int, rows: int, cell_size: float, rng: RandomNumberGenerator = null) -> GridConfig:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var config := GridConfig.new()
	config.cols = cols
	config.rows = rows
	config.cell_size = cell_size

	var cells: Dictionary[Vector2i, int] = {}

	# Border ring: BLOCKED. Written explicitly (not left absent) so the
	# interior/border boundary doesn't depend on GridConfig's own "absent
	# cell defaults to BLOCKED" fallback behavior.
	for x: int in range(cols):
		cells[Vector2i(x, 0)] = Grid.CellType.BLOCKED
		cells[Vector2i(x, rows - 1)] = Grid.CellType.BLOCKED
	for y: int in range(rows):
		cells[Vector2i(0, y)] = Grid.CellType.BLOCKED
		cells[Vector2i(cols - 1, y)] = Grid.CellType.BLOCKED

	# Interior defaults to PLACEABLE; the walk below overwrites its own cells.
	for x: int in range(1, cols - 1):
		for y: int in range(1, rows - 1):
			cells[Vector2i(x, y)] = Grid.CellType.PLACEABLE

	var spawn_row: int = rng.randi_range(1, rows - 2)
	var goal_row: int = rng.randi_range(1, rows - 2)
	var spawn_cell := Vector2i(0, spawn_row)
	var goal_cell := Vector2i(cols - 1, goal_row)
	var spawn_entry := Vector2i(1, spawn_row)       ## first interior step off SPAWN
	var goal_entry := Vector2i(cols - 2, goal_row)  ## last interior step before GOAL

	var path: Array[Vector2i] = _walk(spawn_entry, goal_entry, cols, rows, rng)

	cells[spawn_cell] = Grid.CellType.SPAWN
	cells[goal_cell] = Grid.CellType.GOAL
	for cell: Vector2i in path:
		cells[cell] = Grid.CellType.PATH

	config.cells = cells
	return config


## Randomized backtracking walk from `from` to `to`, biased toward reducing
## Manhattan distance but free to step sideways/backward for a winding
## shape. Guaranteed to terminate at `to` in a fully open interior (see this
## file's own class doc comment) — the `path.size() <= 1` branch below is a
## defensive fallback for a case that should be structurally unreachable,
## not the expected path.
static func _walk(from: Vector2i, to: Vector2i, cols: int, rows: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var visited: Dictionary[Vector2i, bool] = {from: true}
	var path: Array[Vector2i] = [from]
	var current: Vector2i = from
	var max_steps: int = cols * rows * 4  ## generous cap: worst case is ~2x the interior cell count

	var steps: int = 0
	while current != to and steps < max_steps:
		steps += 1
		var candidates: Array[Vector2i] = _neighbor_candidates(current, cols, rows, visited)
		if candidates.is_empty():
			if path.size() <= 1:
				break  ## structurally unreachable in an open interior; see class doc comment
			path.pop_back()
			current = path[path.size() - 1]
			continue
		current = _pick_biased(current, to, candidates, rng)
		visited[current] = true
		path.append(current)

	if current != to:
		# Defensive fallback only (see doc comment) -- connect via a
		# guaranteed-adjacent straight corridor rather than ever leaving a
		# gap in the path.
		path.append_array(_straight_connector(current, to))

	return path


static func _neighbor_candidates(cell: Vector2i, cols: int, rows: int, visited: Dictionary[Vector2i, bool]) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var next: Vector2i = cell + offset
		if next.x < 1 or next.x > cols - 2 or next.y < 1 or next.y > rows - 2:
			continue
		if visited.has(next):
			continue
		candidates.append(next)
	return candidates


## Weighted pick: candidates that reduce Manhattan distance to `to` are 3x
## more likely than ones that don't -- keeps the walk winding rather than
## fully random while still reliably progressing toward the goal.
static func _pick_biased(current: Vector2i, to: Vector2i, candidates: Array[Vector2i], rng: RandomNumberGenerator) -> Vector2i:
	var current_dist: int = absi(current.x - to.x) + absi(current.y - to.y)
	var weights: Array[float] = []
	var total: float = 0.0
	for c: Vector2i in candidates:
		var dist: int = absi(c.x - to.x) + absi(c.y - to.y)
		var w: float = 3.0 if dist < current_dist else 1.0
		weights.append(w)
		total += w
	var roll: float = rng.randf() * total
	var acc: float = 0.0
	for i: int in range(candidates.size()):
		acc += weights[i]
		if roll <= acc:
			return candidates[i]
	return candidates[candidates.size() - 1]


## Straight-line (L-shaped) adjacent-cell corridor from `from` to `to`,
## exclusive of `from` itself (already in the caller's path). Only used by
## the defensive fallback in _walk() -- see that function's own comment.
static func _straight_connector(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var connector: Array[Vector2i] = []
	var current: Vector2i = from
	while current.x != to.x:
		current.x += 1 if to.x > current.x else -1
		connector.append(current)
	while current.y != to.y:
		current.y += 1 if to.y > current.y else -1
		connector.append(current)
	return connector
