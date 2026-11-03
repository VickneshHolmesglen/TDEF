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

## Per-map path character (2026-11-03, MissionEntry.spawn_count / path_winding):
## winding 0..1 maps to how strongly the walk prefers steps toward its target.
## 0.5 reproduces the original fixed 3.0 weight, so existing maps are unchanged.
const DEFAULT_WINDING: float = 0.5
const MAX_SPAWNS: int = 2


## Forward-step weight for `winding` (0 = nearly straight, 1 = coils freely).
## 0..0.5 keeps the original curve (5.0 down to 3.0); above 0.5 the weight
## drops below 1, so steps that DON'T approach the target become likelier and
## the lane doubles back (0.9 -> about 0.9, 1.0 -> 0.4). Measured average lane
## on 16x12 over 300 seeds is in design/quick-specs/procedural-paths-2026-11-03.md.
## Example: forward_weight(0.5) == 3.0
static func forward_weight(winding: float) -> float:
	var w: float = clampf(winding, 0.0, 1.0)
	if w <= 0.5:
		return 1.0 + (1.0 - w) * 4.0
	return 3.0 - (w - 0.5) * 5.2


## cols/rows/cell_size: forwarded onto the returned GridConfig unchanged.
## rng: injectable for deterministic tests; a fresh randomized generator is
## used if omitted.
## spawn_count: 1, or 2 for a second entrance on the top/bottom edge whose lane
## merges into the main lane. winding: see forward_weight().
static func generate(cols: int, rows: int, cell_size: float, rng: RandomNumberGenerator = null,
		spawn_count: int = 1, winding: float = DEFAULT_WINDING) -> GridConfig:
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

	var weight: float = forward_weight(winding)
	var path: Array[Vector2i] = _walk(spawn_entry, goal_entry, cols, rows, rng, weight)

	cells[spawn_cell] = Grid.CellType.SPAWN
	cells[goal_cell] = Grid.CellType.GOAL
	for cell: Vector2i in path:
		cells[cell] = Grid.CellType.PATH

	if clampi(spawn_count, 1, MAX_SPAWNS) == 2:
		_add_merging_lane(cells, path, cols, rows, rng, weight)

	config.cells = cells
	return config


## Randomized backtracking walk from `from` to `to`, biased toward reducing
## Manhattan distance but free to step sideways/backward for a winding
## shape. Guaranteed to terminate at `to` in a fully open interior (see this
## file's own class doc comment) — the `path.size() <= 1` branch below is a
## defensive fallback for a case that should be structurally unreachable,
## not the expected path.
static func _walk(from: Vector2i, to: Vector2i, cols: int, rows: int, rng: RandomNumberGenerator,
		weight: float = 3.0) -> Array[Vector2i]:
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
		current = _pick_biased(current, to, candidates, rng, weight)
		visited[current] = true
		path.append(current)

	if current != to:
		# Defensive fallback only (see doc comment) -- connect via a
		# guaranteed-adjacent straight corridor rather than ever leaving a
		# gap in the path.
		path.append_array(_straight_connector(current, to))

	return path


## TD-map-001 fix (2026-08-16, player-reported): PathfindingSystem connects
## every grid-adjacent walkable cell pair at equal cost (see its own class doc
## comment), not just cells consecutive in this walk's corridor. Without the
## _touches_carved_elsewhere() guard below, the walk could carve a corridor
## that winds back adjacent to itself (a U-turn passing beside an earlier
## segment) — A* then cuts across that adjacency, so the real monster route
## (PathfindingSystem.find_path()) skips a chunk of painted PATH cells
## entirely. Live-verified via the Godot MCP bridge before this fix: a
## generated map had 6 PATH cells absent from the actual computed route.
## Standard "no self-touching corridor" constraint from growing-tree maze
## generation closes this — a candidate is only valid if `cell` (the cell
## being stepped FROM) is its only already-carved neighbor.
static func _neighbor_candidates(cell: Vector2i, cols: int, rows: int, visited: Dictionary[Vector2i, bool]) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var next: Vector2i = cell + offset
		if next.x < 1 or next.x > cols - 2 or next.y < 1 or next.y > rows - 2:
			continue
		if visited.has(next):
			continue
		if _touches_carved_elsewhere(next, cell, cols, rows, visited):
			continue
		candidates.append(next)
	return candidates


## True if `next` is grid-adjacent to any already-carved cell other than
## `from` (the cell the walk is stepping from). Rejecting such candidates is
## what keeps the corridor exactly one cell wide and self-avoiding, so the
## painted PATH cells and the AStar2D-computed route are always identical.
static func _touches_carved_elsewhere(next: Vector2i, from: Vector2i, cols: int, rows: int, visited: Dictionary[Vector2i, bool]) -> bool:
	for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor: Vector2i = next + offset
		if neighbor == from:
			continue
		if visited.has(neighbor):
			return true
	return false


## Weighted pick: candidates that reduce Manhattan distance to `to` are 3x
## more likely than ones that don't -- keeps the walk winding rather than
## fully random while still reliably progressing toward the goal.
static func _pick_biased(current: Vector2i, to: Vector2i, candidates: Array[Vector2i], rng: RandomNumberGenerator,
		weight: float = 3.0) -> Vector2i:
	var current_dist: int = absi(current.x - to.x) + absi(current.y - to.y)
	var weights: Array[float] = []
	var total: float = 0.0
	for c: Vector2i in candidates:
		var dist: int = absi(c.x - to.x) + absi(c.y - to.y)
		var w: float = weight if dist < current_dist else 1.0
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


## Second entrance (spawn_count 2): a SPAWN on the top or bottom border, in
## the left half, whose lane walks toward the middle of the main lane and
## joins it. The lane never touches the main lane except at the join (the
## same no-shortcut rule as _touches_carved_elsewhere), so the painted PATH
## and the A* route stay identical. Falls back to a straight connector if the
## walk dead-ends (defensive; the open interior makes that unlikely).
static func _add_merging_lane(cells: Dictionary[Vector2i, int], main: Array[Vector2i], cols: int, rows: int,
		rng: RandomNumberGenerator, weight: float) -> void:
	var main_set: Dictionary[Vector2i, bool] = {}
	for c: Vector2i in main:
		main_set[c] = true
	# Only the main lane's later two thirds can be joined; its first third is
	# kept clear, so the second lane is a real lane rather than a two-cell stub
	# beside the first entrance (live check 2026-11-03).
	var join_set: Dictionary[Vector2i, bool] = {}
	var early_set: Dictionary[Vector2i, bool] = {}
	for i: int in range(main.size()):
		if i >= main.size() / 3:
			join_set[main[i]] = true
		else:
			early_set[main[i]] = true
	var target: Vector2i = main[(main.size() * 2) / 3]
	# Pick an entry cell on the top or bottom interior row: left half first,
	# then the full width, then the other edge; clear of the main lane if
	# possible (so the second lane has length), else just not on it.
	var first_top: bool = rng.randf() < 0.5
	var entry := Vector2i(-1, -1)
	var edge_y: int = 0
	for top: bool in [first_top, not first_top]:
		var entry_y: int = 1 if top else rows - 2
		for span: Vector2i in [Vector2i(cols / 4, (cols * 3) / 4), Vector2i(2, cols - 2)]:
			var xs: Array[int] = []
			for x: int in range(maxi(2, span.x), span.y):
				xs.append(x)
			_shuffle(xs, rng)
			for strict: bool in [true, false]:
				for x: int in xs:
					var c := Vector2i(x, entry_y)
					if main_set.has(c) or (strict and _adjacent_to(c, main_set)):
						continue
					entry = c
					break
				if entry.x >= 0:
					break
			if entry.x >= 0:
				break
		if entry.x >= 0:
			edge_y = 0 if top else rows - 1
			break
	if entry.x < 0:
		return  # the main lane covers both edge rows entirely: one entrance only
	cells[Vector2i(entry.x, edge_y)] = Grid.CellType.SPAWN
	for cell: Vector2i in _walk_to_join(entry, target, main_set, join_set, early_set, cols, rows, rng, weight):
		cells[cell] = Grid.CellType.PATH


static func _walk_to_join(from: Vector2i, target: Vector2i, main_set: Dictionary[Vector2i, bool],
		join_set: Dictionary[Vector2i, bool], early_set: Dictionary[Vector2i, bool], cols: int, rows: int,
		rng: RandomNumberGenerator, weight: float) -> Array[Vector2i]:
	var visited: Dictionary[Vector2i, bool] = {from: true}
	var path: Array[Vector2i] = [from]
	var current: Vector2i = from
	var steps: int = 0
	while not _adjacent_to(current, join_set) and steps < cols * rows * 4:
		steps += 1
		var candidates: Array[Vector2i] = []
		for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + offset
			if next.x < 1 or next.x > cols - 2 or next.y < 1 or next.y > rows - 2:
				continue
			if visited.has(next) or main_set.has(next) or _adjacent_to(next, early_set):
				continue
			if _touches_carved_elsewhere(next, current, cols, rows, visited):
				continue
			candidates.append(next)
		if candidates.is_empty():
			if path.size() <= 1:
				break
			path.pop_back()
			current = path[path.size() - 1]
			continue
		current = _pick_biased(current, target, candidates, rng, weight)
		visited[current] = true
		path.append(current)
	if not _adjacent_to(current, join_set):
		# Defensive: step straight toward the target until the lanes meet.
		while not _adjacent_to(current, join_set) and current != target:
			if current.x != target.x:
				current.x += 1 if target.x > current.x else -1
			else:
				current.y += 1 if target.y > current.y else -1
			if main_set.has(current):
				break
			path.append(current)
	return path


static func _adjacent_to(cell: Vector2i, cell_set: Dictionary[Vector2i, bool]) -> bool:
	for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if cell_set.has(cell + offset):
			return true
	return false


## Fisher-Yates with the injected rng, so a seeded generate() stays deterministic.
static func _shuffle(values: Array[int], rng: RandomNumberGenerator) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = values[i]
		values[i] = values[j]
		values[j] = tmp
