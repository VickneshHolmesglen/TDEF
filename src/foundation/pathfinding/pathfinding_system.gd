## PathfindingSystem — Autoload #4.
##
## Single authority on navigable routes from monster SPAWN cells to GOAL cells.
## Maintains one RouteTemplate per SPAWN cell; monsters share templates and call
## get_path() for O(1) path slices during WAVE_ACTIVE.
##
## Architecture (ADR-0004, Accepted 2026-05-16):
##   - AStar2D (C++ backed), one instance per SPAWN cell — not NavigationServer2D
##   - route templates built at SCOUT phase start (not in _ready())
##   - deferred dirty rebuild on tower_placed / tower_removed, batched per frame
##   - would_block_all_paths() uses a temp copy — never mutates cached templates
##
## Point ID encoding (binding — row-major):
##   point_id = cell.y * grid_cols + cell.x
##   cell.x = point_id % grid_cols,  cell.y = point_id / grid_cols
##   super_goal_id = grid_cols * grid_rows  (one past the last valid cell ID)
##
## Cell costs (weight_scale in AStar2D):
##   PATH / SPAWN / GOAL          → 1.0
##   unoccupied PLACEABLE         → 10.0
##   occupied PLACEABLE (tower)   → absent from graph (disabled)
class_name PathfindingSystem
extends Node

const STANDARD_TIER: int = 0
const PLACEABLE_COST: float = 10.0
const PATH_COST: float = 1.0

# Injected in production from global Autoloads; overridden in tests via _inject().
var _grid: Grid = null
var _event_bus: Node = null

# Per-SPAWN route templates and AStar2D instances.
var _templates: Dictionary[Vector2i, RouteTemplate] = {}
var _astar_instances: Dictionary[Vector2i, PathfindingAStar2D] = {}

# Maps every walkable cell to its nearest SPAWN cell (Voronoi, Chebyshev distance).
# Populated after all templates are built at SCOUT start.
var _spawn_assignment: Dictionary[Vector2i, Vector2i] = {}

# Dirty-rebuild state.
var _dirty_templates: Dictionary[Vector2i, bool] = {}
var _rebuild_queued: bool = false
# Union of footprint cells from all batched tower events — becomes path_invalidated payload.
var _pending_affected_cells_set: Dictionary[Vector2i, bool] = {}

# Lifecycle flags.
var _templates_built: bool = false
var _current_phase: String = ""
var _tower_destroyed_during_wave: bool = false

# Footprint cache: tower_id → Array[Vector2i] of occupied cells.
# Needed because tower_removed signal does not carry footprint.
var _tower_footprint_cache: Dictionary[int, Array] = {}

# Per-frame fallback tracking (reset in _physics_process before monster callbacks).
## Public — tests assert this to verify fallback A* fired (reset to "" each physics frame).
var last_fallback_warning: String = ""
var _fallback_count_this_frame: int = 0

## Configurable fallback cap. Default 1 per frame budget analysis (GDD Tuning Knobs).
var pathfinding_max_fallbacks_per_frame: int = 1


func _ready() -> void:
	if _grid == null:
		_grid = GGrid
	if _event_bus == null:
		_event_bus = GEventBus
	_event_bus.mission_phase_changed.connect(_on_mission_phase_changed)
	_event_bus.tower_placed.connect(_on_tower_placed)
	_event_bus.tower_removed.connect(_on_tower_removed)
	_event_bus.tower_destroyed.connect(_on_tower_destroyed)


func _exit_tree() -> void:
	_event_bus.mission_phase_changed.disconnect(_on_mission_phase_changed)
	_event_bus.tower_placed.disconnect(_on_tower_placed)
	_event_bus.tower_removed.disconnect(_on_tower_removed)
	_event_bus.tower_destroyed.disconnect(_on_tower_destroyed)


func _physics_process(_delta: float) -> void:
	last_fallback_warning = ""
	_fallback_count_this_frame = 0


# ---------------------------------------------------------------------------
# Test injection seam
# ---------------------------------------------------------------------------

## Inject Grid and EventBus references before add_child() triggers _ready().
## Tests MUST call this before the node enters the scene tree.
func _inject(grid: Grid, event_bus: Node) -> void:
	_grid = grid
	_event_bus = event_bus


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns remaining path from from_cell to GOAL (from_cell excluded).
## Two-value contract: [] means GOAL arrival, unreachable, or fallback cap exhausted.
## Never returns null. O(1) template lookup + O(k) slice. Thread-unsafe — main thread only.
func find_path(from_cell: Vector2i, tier: int) -> Array[Vector2i]:
	if not _templates_built:
		push_error("PathfindingSystem.find_path: called before templates_ready — returning [].")
		return []

	if tier != STANDARD_TIER:
		push_warning("PathfindingSystem.find_path: tier parameter reserved for MVP. Proceeding with STANDARD routing.")

	# Template lookup via spawn assignment.
	if not _spawn_assignment.has(from_cell):
		push_error("PathfindingSystem.find_path: from_cell %s not in _spawn_assignment — possible initialization failure." % str(from_cell))
		return _fallback_get_path(from_cell)

	var spawn_key: Vector2i = _spawn_assignment[from_cell]
	if not _templates.has(spawn_key):
		push_error("PathfindingSystem.find_path: SPAWN %s has no template — partial initialization failure." % str(spawn_key))
		return _fallback_get_path(from_cell)

	var template: RouteTemplate = _templates[spawn_key]
	if template.cell_index_map.has(from_cell):
		# F3 slice — result.assign() preserves Array[Vector2i] type annotation.
		var idx: int = template.cell_index_map[from_cell]
		var result: Array[Vector2i] = []
		result.assign(template.path.slice(idx + 1))
		return result

	# from_cell not in template — monster drifted off-path; attempt fallback A*.
	return _fallback_get_path(from_cell)


## Returns true if marking cells non-walkable would disconnect any SPAWN from all GOALs.
## When true, also emits tower_placement_blocked(cells, primary_blocking_cell) on EventBus.
## Does NOT mutate cached templates. grid.get_walkable_cell_map() is unchanged after this call.
func would_block_all_paths(cells: Array[Vector2i]) -> bool:
	var blocks: bool = _check_blocks_all_paths(cells)
	if blocks:
		var primary: Vector2i = _find_primary_blocking_cell(cells)
		_event_bus.tower_placement_blocked.emit(cells, primary)
	return blocks


## Internal speculative-block check (no signal emission). Used by would_block_all_paths()
## and by _find_primary_blocking_cell() to test individual cells.
func _check_blocks_all_paths(cells: Array[Vector2i]) -> bool:
	# Step 1: deep copy of live walkability map, excluding PLACEABLE cells so that
	# alternate routes through tower-slot cells cannot mask a true PATH disconnection.
	var full_map: Dictionary[Vector2i, bool] = _grid.get_walkable_cell_map()
	var walkable_copy: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in full_map:
		if _grid.get_cell_type(cell) != Grid.CellType.PLACEABLE:
			walkable_copy[cell] = true
	# Step 2: mark footprint cells non-walkable.
	for c: Vector2i in cells:
		walkable_copy.erase(c)
	# Step 3: re-compute dimensions and super_goal_id.
	var grid_cols: int = _grid.get_grid_cols()
	var grid_rows: int = _grid.get_grid_rows()
	var temp_super_goal_id: int = grid_cols * grid_rows
	# Step 4: populate temp_goal_cells (mandatory before A* query).
	var temp_goal_cells: Array[Vector2i] = _grid.get_goal_cells()
	var spawn_cells: Array[Vector2i] = _grid.get_spawn_cells()
	# Step 5: build standalone temporary AStar2D from walkability copy.
	var temp_astar: PathfindingAStar2D = _create_temp_astar()
	temp_astar._super_goal_id = temp_super_goal_id
	temp_astar._grid_cols = grid_cols
	temp_astar.goal_cells = temp_goal_cells
	_populate_astar(temp_astar, walkable_copy, temp_goal_cells, temp_super_goal_id, grid_cols)
	# Step 6: run A* from each SPAWN — return true if any produces an empty path.
	for spawn_cell: Vector2i in spawn_cells:
		var spawn_id: int = spawn_cell.y * grid_cols + spawn_cell.x
		if not temp_astar.has_point(spawn_id):
			return true
		var id_path: PackedInt64Array = temp_astar.get_id_path(spawn_id, temp_super_goal_id)
		if id_path.is_empty():
			return true
	return false


## Returns the first cell in cells that alone blocks all paths, or Vector2i(-1,-1)
## if no single cell is individually load-bearing (multi-cell interaction block).
func _find_primary_blocking_cell(cells: Array[Vector2i]) -> Vector2i:
	for cell: Vector2i in cells:
		if _check_blocks_all_paths([cell]):
			return cell
	return Vector2i(-1, -1)


## Returns true if a deferred template rebuild is queued but not yet executed.
## WaveManager checks this at INTERMISSION → PRE_WAVE to avoid starting a wave
## while a rebuild is still pending.
func is_rebuild_pending() -> bool:
	return _rebuild_queued


# ---------------------------------------------------------------------------
# EventBus handlers
# ---------------------------------------------------------------------------

func _on_mission_phase_changed(previous_phase: String, new_phase: String, _timestamp: float) -> void:
	_current_phase = new_phase
	match new_phase:
		"SCOUT":
			_clear_all_state()
			_build_all_templates()
		"INTERMISSION":
			# BOSS tower-destruction auto-rebuild (GDD Rule 11).
			if _tower_destroyed_during_wave:
				_tower_destroyed_during_wave = false
				for spawn_cell: Vector2i in _templates:
					_dirty_templates[spawn_cell] = true
				if not _rebuild_queued:
					_rebuild_queued = true
					_rebuild_dirty_templates.call_deferred()
		"DEFEAT", "OUTCOME":
			_clear_all_state()


func _on_tower_placed(tower_id: int, grid_position: Vector2i, _archetype: String, footprint_size: Vector2i, _placed_in_scout: bool) -> void:
	if _current_phase == "WAVE_ACTIVE":
		push_error("PathfindingSystem: tower_placed received during WAVE_ACTIVE — Grid lock failure detected. Setting _tower_destroyed_during_wave for INTERMISSION recovery.")
		_tower_destroyed_during_wave = true
		return
	var cells: Array[Vector2i] = _cells_from_footprint(grid_position, footprint_size)
	_tower_footprint_cache[tower_id] = cells
	_queue_dirty_rebuild(cells)


func _on_tower_removed(tower_id: int, _grid_position: Vector2i, _archetype: String) -> void:
	if _current_phase == "WAVE_ACTIVE":
		push_error("PathfindingSystem: tower_removed received during WAVE_ACTIVE — Grid lock failure detected.")
		_tower_destroyed_during_wave = true
		return
	var cells: Array[Vector2i] = []
	if _tower_footprint_cache.has(tower_id):
		cells = _tower_footprint_cache[tower_id]
		_tower_footprint_cache.erase(tower_id)
	if not cells.is_empty():
		_queue_dirty_rebuild(cells)


func _on_tower_destroyed(tower_id: int, _grid_position: Vector2i, _archetype: String, _footprint: Array) -> void:
	_tower_footprint_cache.erase(tower_id)
	if _current_phase == "WAVE_ACTIVE":
		# Do NOT rebuild now — defer to INTERMISSION entry (GDD EC-11, Rule 11).
		_tower_destroyed_during_wave = true


# ---------------------------------------------------------------------------
# Template build
# ---------------------------------------------------------------------------

func _build_all_templates() -> void:
	var spawn_cells: Array[Vector2i] = _grid.get_spawn_cells()
	var goal_cells: Array[Vector2i] = _grid.get_goal_cells()

	if spawn_cells.is_empty() or goal_cells.is_empty():
		push_error("PathfindingSystem: mission map has no %s cells — templates not built." % ("SPAWN" if spawn_cells.is_empty() else "GOAL"))
		return

	var build_start: int = Time.get_ticks_usec()
	var grid_cols: int = _grid.get_grid_cols()
	var grid_rows: int = _grid.get_grid_rows()
	var super_goal_id: int = grid_cols * grid_rows
	var walkable_map: Dictionary[Vector2i, bool] = _grid.get_walkable_cell_map()

	for spawn_cell: Vector2i in spawn_cells:
		var astar: PathfindingAStar2D = PathfindingAStar2D.new()
		astar._super_goal_id = super_goal_id
		astar._grid_cols = grid_cols
		astar.goal_cells = goal_cells
		_populate_astar(astar, walkable_map, goal_cells, super_goal_id, grid_cols)
		_astar_instances[spawn_cell] = astar

		var spawn_id: int = spawn_cell.y * grid_cols + spawn_cell.x
		var raw_path_ids: PackedInt64Array = []
		if astar.has_point(spawn_id):
			raw_path_ids = astar.get_id_path(spawn_id, super_goal_id)

		var path: Array[Vector2i] = _ids_to_cells(raw_path_ids, super_goal_id, grid_cols)
		var tmpl := RouteTemplate.new()
		tmpl.build_from_path(path)
		_templates[spawn_cell] = tmpl

	# Build Voronoi spawn assignment for all walkable cells.
	# TODO(post-MVP): Replace with reverse-Dijkstra flood-fill. Chebyshev distance produces
	# incorrect assignment for cells near walls between SPAWNs — fallback A* masks the
	# misassignment as performance degradation, not a routing failure. See pathfinding.md Rule 3.
	_build_spawn_assignment(spawn_cells, walkable_map)

	_templates_built = true
	var build_ms: float = float(Time.get_ticks_usec() - build_start) / 1000.0
	_event_bus.templates_ready.emit(spawn_cells.size(), build_ms)


func _build_spawn_assignment(spawn_cells: Array[Vector2i], walkable_map: Dictionary) -> void:
	_spawn_assignment.clear()
	for cell: Vector2i in walkable_map:
		var nearest_spawn: Vector2i = spawn_cells[0]
		var nearest_dist: int = _chebyshev(cell, spawn_cells[0])
		for i: int in range(1, spawn_cells.size()):
			var d: int = _chebyshev(cell, spawn_cells[i])
			if d < nearest_dist:
				nearest_dist = d
				nearest_spawn = spawn_cells[i]
		_spawn_assignment[cell] = nearest_spawn


# ---------------------------------------------------------------------------
# Dirty rebuild
# ---------------------------------------------------------------------------

func _queue_dirty_rebuild(footprint_cells: Array[Vector2i]) -> void:
	_mark_dirty_from_footprint(footprint_cells)
	# Accumulate affected cells for the path_invalidated union payload.
	for c: Vector2i in footprint_cells:
		_pending_affected_cells_set[c] = true
	if not _rebuild_queued and not _dirty_templates.is_empty():
		_rebuild_queued = true
		_rebuild_dirty_templates.call_deferred()


func _mark_dirty_from_footprint(footprint_cells: Array[Vector2i]) -> void:
	for spawn_cell: Vector2i in _templates:
		var tmpl: RouteTemplate = _templates[spawn_cell]
		for cell: Vector2i in footprint_cells:
			if tmpl.cell_index_map.has(cell):
				_dirty_templates[spawn_cell] = true
				break


func _rebuild_dirty_templates() -> void:
	# Empty-dirty guard: stale deferred call after mission restart.
	if _dirty_templates.is_empty():
		_rebuild_queued = false
		return

	# WAVE_ACTIVE guard: deferred call survived a phase transition.
	if _current_phase == "WAVE_ACTIVE":
		push_error("PathfindingSystem._rebuild_dirty_templates: called during WAVE_ACTIVE — clearing without emitting path_invalidated.")
		_rebuild_queued = false
		_dirty_templates.clear()
		_pending_affected_cells_set.clear()
		return

	_rebuild_queued = false

	var grid_cols: int = _grid.get_grid_cols()
	var grid_rows: int = _grid.get_grid_rows()
	var super_goal_id: int = grid_cols * grid_rows
	var goal_cells: Array[Vector2i] = _grid.get_goal_cells()
	var walkable_map: Dictionary[Vector2i, bool] = _grid.get_walkable_cell_map()

	var dirty_spawns: Array[Vector2i] = []
	for spawn_cell: Vector2i in _dirty_templates:
		dirty_spawns.append(spawn_cell)
	_dirty_templates.clear()

	for spawn_cell: Vector2i in dirty_spawns:
		if not _astar_instances.has(spawn_cell):
			continue
		var astar: PathfindingAStar2D = _astar_instances[spawn_cell]
		astar.clear()
		astar._super_goal_id = super_goal_id
		astar._grid_cols = grid_cols
		astar.goal_cells = goal_cells
		astar._point_positions.clear()
		_populate_astar(astar, walkable_map, goal_cells, super_goal_id, grid_cols)

		var spawn_id: int = spawn_cell.y * grid_cols + spawn_cell.x
		var raw_path_ids: PackedInt64Array = []
		if astar.has_point(spawn_id):
			raw_path_ids = astar.get_id_path(spawn_id, super_goal_id)

		var path: Array[Vector2i] = _ids_to_cells(raw_path_ids, super_goal_id, grid_cols)
		var tmpl: RouteTemplate = _templates[spawn_cell]
		tmpl.build_from_path(path)

	# Emit path_invalidated with deduplicated union of all affected cells.
	var affected_cells: Array[Vector2i] = []
	for cell: Vector2i in _pending_affected_cells_set:
		affected_cells.append(cell)
	_pending_affected_cells_set.clear()
	_event_bus.path_invalidated.emit(affected_cells)


# ---------------------------------------------------------------------------
# Fallback A*
# ---------------------------------------------------------------------------

func _fallback_get_path(from_cell: Vector2i) -> Array[Vector2i]:
	# Cap check fires BEFORE incrementing (GDD Rule 15e binding).
	if _fallback_count_this_frame >= pathfinding_max_fallbacks_per_frame:
		return []

	var grid_cols: int = _grid.get_grid_cols()
	var grid_rows: int = _grid.get_grid_rows()
	var super_goal_id: int = grid_cols * grid_rows
	var goal_cells: Array[Vector2i] = _grid.get_goal_cells()
	var walkable_map: Dictionary[Vector2i, bool] = _grid.get_walkable_cell_map()

	var temp_astar: PathfindingAStar2D = _create_fallback_astar()
	temp_astar._super_goal_id = super_goal_id
	temp_astar._grid_cols = grid_cols
	temp_astar.goal_cells = goal_cells
	_populate_astar(temp_astar, walkable_map, goal_cells, super_goal_id, grid_cols)

	var from_id: int = from_cell.y * grid_cols + from_cell.x
	var raw_path_ids: PackedInt64Array = []
	if temp_astar.has_point(from_id):
		raw_path_ids = temp_astar.get_id_path(from_id, super_goal_id)

	_fallback_count_this_frame += 1
	last_fallback_warning = "PathfindingSystem.find_path: fallback A* fired for cell %s — possible level design issue or off-template drift." % str(from_cell)
	push_warning(last_fallback_warning)

	if raw_path_ids.is_empty():
		return []
	var result: Array[Vector2i] = _ids_to_cells(raw_path_ids, super_goal_id, grid_cols)
	# Fallback returns the full path including from_cell (index 0); skip it to match template contract.
	if not result.is_empty() and result[0] == from_cell:
		var sliced: Array[Vector2i] = []
		sliced.assign(result.slice(1))
		return sliced
	return result


# ---------------------------------------------------------------------------
# AStar2D population helper
# ---------------------------------------------------------------------------

func _populate_astar(astar: PathfindingAStar2D, walkable_map: Dictionary[Vector2i, bool],
		goal_cells: Array[Vector2i], super_goal_id: int, grid_cols: int) -> void:
	# Add all walkable cells.
	for cell: Vector2i in walkable_map:
		var point_id: int = cell.y * grid_cols + cell.x
		var weight_scale: float = _cell_weight_scale(cell)
		var pos: Vector2 = Vector2(float(cell.x), float(cell.y))
		astar.add_point(point_id, pos, weight_scale)
		astar._point_positions[point_id] = pos

	# Add cardinal edges (right and down only — bidirectional covers the reverse).
	for cell: Vector2i in walkable_map:
		var right: Vector2i = Vector2i(cell.x + 1, cell.y)
		var down: Vector2i = Vector2i(cell.x, cell.y + 1)
		var cell_id: int = cell.y * grid_cols + cell.x
		if walkable_map.has(right):
			astar.connect_points(cell_id, right.y * grid_cols + right.x, true)
		if walkable_map.has(down):
			astar.connect_points(cell_id, down.y * grid_cols + down.x, true)

	# Add super-goal node (zero weight — virtual sink).
	astar.add_point(super_goal_id, Vector2.ZERO, 0.0)
	astar._point_positions[super_goal_id] = Vector2.ZERO

	# Connect each GOAL cell to super-goal (one-directional: GOAL → super-goal).
	for g: Vector2i in goal_cells:
		var g_id: int = g.y * grid_cols + g.x
		if astar.has_point(g_id):
			astar.connect_points(g_id, super_goal_id, false)


func _cell_weight_scale(cell: Vector2i) -> float:
	var ct: int = _grid.get_cell_type(cell)
	match ct:
		Grid.CellType.PLACEABLE:
			return PLACEABLE_COST
		_:
			return PATH_COST


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

func _ids_to_cells(id_path: PackedInt64Array, super_goal_id: int, grid_cols: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for id: int in id_path:
		if id == super_goal_id:
			continue
		result.append(Vector2i(id % grid_cols, id / grid_cols))
	return result


func _cells_from_footprint(top_left: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for col: int in range(size.x):
		for row: int in range(size.y):
			cells.append(top_left + Vector2i(col, row))
	return cells


func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


func _clear_all_state() -> void:
	_templates.clear()
	_astar_instances.clear()
	_spawn_assignment.clear()
	_dirty_templates.clear()
	_pending_affected_cells_set.clear()
	_tower_footprint_cache.clear()
	_rebuild_queued = false
	_templates_built = false
	_tower_destroyed_during_wave = false


# ---------------------------------------------------------------------------
# Test seams (virtual factory methods — override in test subclasses)
# ---------------------------------------------------------------------------

## Factory for the fallback A* instance in get_path() (Rule 15e).
## Override in tests to inject a pre-configured instance with empty goal_cells (AC-22b).
func _create_fallback_astar() -> PathfindingAStar2D:
	return PathfindingAStar2D.new()


## Factory for the temporary A* instance in would_block_all_paths() (Rule 9).
## Override in tests to inject a pre-configured instance with empty goal_cells (AC-22).
func _create_temp_astar() -> PathfindingAStar2D:
	return PathfindingAStar2D.new()
