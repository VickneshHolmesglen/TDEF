# S2-04 — Pathfinding Autoload Implementation

**Story ID**: S2-04
**Epic**: Foundation
**Layer**: Foundation
**Type**: Logic
**Owner**: godot-gdscript-specialist
**Sprint**: 2
**Estimate**: 2 days
**Status**: Complete
**Manifest Version**: 2026-05-16

## TR Coverage

| TR-ID | Requirement |
|-------|-------------|
| TR-path-001 | AStar2D Autoload (not NavigationServer) |
| TR-path-002 | Route templates with cell_index_map |
| TR-path-003 | Super-goal node for multi-goal convergence |
| TR-path-004 | templates_ready event gates all spawning |
| TR-path-005 | would_block_all_paths() speculative check |
| TR-path-006 | Deferred dirty rebuild on tower changes |
| TR-path-007 | 100+ simultaneous agents at 60 FPS |

## ADR Governing Implementation

`docs/architecture/adr-0004-pathfinding-strategy.md` (Accepted 2026-05-16)

## Dependencies

- S2-01 EventBus Autoload — Complete (2026-05-25)
- S2-02 SavePersistence Autoload — Complete (2026-05-25)
- S2-03 Grid System Autoload — Complete (2026-06-29)

## Files to Create / Modify

- `src/foundation/pathfinding/pathfinding_astar2d.gd` — PathfindingAStar2D subclass (AStar2D override)
- `src/foundation/pathfinding/route_template.gd` — RouteTemplate data class
- `src/foundation/pathfinding/pathfinding_system.gd` — PathfindingSystem Autoload (Node)

## Test Evidence

- `tests/unit/pathfinding/pathfinding_template_test.gd` — template build, get_path slices, fallback A*, mission restart
- `tests/unit/pathfinding/pathfinding_block_test.gd` — would_block_all_paths true/false, live-state immutability, tower_placement_blocked emission
- `tests/unit/pathfinding/pathfinding_invalidation_test.gd` — deferred rebuild deduplication, WAVE_ACTIVE guard, BOSS auto-rebuild

## Acceptance Criteria

- [ ] After `mission_phase_changed(new_phase="SCOUT")` with a valid GridConfig (1 SPAWN, 1+ GOAL, reachable path), `templates_ready(spawn_count=1, build_duration_ms>0)` is emitted via EventBus exactly once (GDD AC-1, AC-14, TR-path-004)
- [ ] `get_path(spawn_cell, 0)` returns a non-empty `Array[Vector2i]` whose final entry is a GOAL cell; first entry is the cell immediately after SPAWN in the computed route (GDD AC-1, AC-3, TR-path-002)
- [ ] `get_path(mid_route_cell, 0)` returns path slice starting at the cell after `mid_route_cell`, ending at GOAL; `mid_route_cell` itself is NOT included; no cells are skipped (cardinal adjacency verified) (GDD AC-3, F3)
- [ ] `get_path(goal_cell, 0)` returns `[]` — monster at GOAL receives arrival signal (GDD AC-3, F3)
- [ ] `would_block_all_paths(blocking_footprint)` returns `true` when the footprint would disconnect all SPAWN-to-GOAL paths; `Grid.get_walkable_cell_map()` is identical before and after the call (GDD AC-5, AC-18, TR-path-005)
- [ ] `would_block_all_paths(non_blocking_footprint)` returns `false` when at least one SPAWN-to-GOAL path remains (GDD AC-6, TR-path-005)
- [ ] Two `tower_placed` events in the same physics frame produce exactly 1 `path_invalidated` emission with `affected_cells` equal to the union of both footprints (no duplicate Vector2i entries) (GDD AC-9a, TR-path-006)
- [ ] When `get_path()` is called for a cell not in any template's `cell_index_map`, `last_fallback_warning` is a non-empty String (fallback A* fired) and the return value is either a non-empty `Array[Vector2i]` or `[]`; no crash (GDD AC-11, TR-path-001)
- [ ] When SCOUT phase starts and `Grid.get_spawn_cells()` returns empty OR `Grid.get_goal_cells()` returns empty, `push_error()` is called, `templates_ready` is NOT emitted, and `get_path(any_cell, 0)` returns `[]` without crashing (GDD AC-19)
- [ ] `is_rebuild_pending()` returns `true` when `_rebuild_queued == true` (tower event received, deferred call pending); returns `false` when no rebuild is queued (GDD AC-27, TR-path-006)
- [ ] On mission restart (DEFEAT → SCOUT with new GridConfig G2), `get_path(G1_route_cell, 0)` for a cell only in G1's layout returns `[]`; `templates_ready` emits once with G2's spawn_count (GDD AC-25)
- [ ] `tower_placed` event received during `WAVE_ACTIVE` triggers `push_error()` and does NOT emit `path_invalidated` (defense-in-depth guard) (GDD AC-23, TR-path-006)
- [ ] Subscribes to `EventBus.mission_phase_changed`, `EventBus.tower_placed`, `EventBus.tower_removed`, `EventBus.tower_destroyed` in `_ready()`; disconnects all in `_exit_tree()` (ADR-0001 rule)
- [ ] Unit tests: ≥15 tests pass across `tests/unit/pathfinding/`

## Implementation Notes (from ADR-0004 and GDD)

### Class Structure

```gdscript
# pathfinding_astar2d.gd — AStar2D subclass
class_name PathfindingAStar2D
extends AStar2D

var goal_cells: Array[Vector2i] = []   # Must be set before any A* query
var _super_goal_id: int = 0            # Set by owner before use
var _grid_cols: int = 16               # For cell_at() reverse lookup
var _point_positions: Dictionary[int, Vector2] = {}  # point_id → Vector2

func _estimate_cost(from_id: int, to_id: int) -> float:
    if to_id == _super_goal_id:
        if goal_cells.is_empty():
            push_error("PathfindingAStar2D._estimate_cost: goal_cells is empty — returning INF")
            return INF
        var min_dist: float = INF
        for g: Vector2i in goal_cells:
            var cell: Vector2i = _cell_at(from_id)
            var d: float = abs(g.x - cell.x) + abs(g.y - cell.y)
            if d < min_dist:
                min_dist = d
        return min_dist
    if from_id == _super_goal_id:
        return 0.0
    var from_cell: Vector2i = _cell_at(from_id)
    var to_cell: Vector2i = _cell_at(to_id)
    return abs(to_cell.x - from_cell.x) + abs(to_cell.y - from_cell.y)

func _compute_cost(from_id: int, to_id: int) -> float:
    if to_id == _super_goal_id:
        return 0.0
    if from_id == _super_goal_id:
        push_error("PathfindingAStar2D._compute_cost: from_id == super_goal_id")
        return 0.0
    var from_pos: Vector2 = _point_positions[from_id]
    var to_pos: Vector2 = _point_positions[to_id]
    return from_pos.distance_to(to_pos) * (get_point_weight_scale(from_id) + get_point_weight_scale(to_id)) / 2.0

func _cell_at(point_id: int) -> Vector2i:
    return Vector2i(point_id % _grid_cols, point_id / _grid_cols)

# Factory seam for AC-22b testing
func _create_fallback_astar() -> PathfindingAStar2D:
    return PathfindingAStar2D.new()
```

```gdscript
# route_template.gd — data class (not a Resource — no need for @export)
class_name RouteTemplate

var path: Array[Vector2i] = []
var cell_index_map: Dictionary[Vector2i, int] = {}

func build_from_path(raw_path: Array[Vector2i]) -> void:
    path = raw_path
    cell_index_map.clear()
    for i: int in range(path.size()):
        cell_index_map[path[i]] = i
```

```gdscript
# pathfinding_system.gd — Autoload #4
class_name PathfindingSystem
extends Node

const STANDARD_TIER: int = 0

var _templates: Dictionary[Vector2i, RouteTemplate] = {}      # SPAWN cell → RouteTemplate
var _spawn_assignment: Dictionary[Vector2i, Vector2i] = {}    # walkable cell → nearest SPAWN
var _dirty_templates: Dictionary[Vector2i, bool] = {}         # SPAWN cell → dirty flag
var _rebuild_queued: bool = false
var _templates_built: bool = false
var _current_phase: String = ""
var _tower_destroyed_during_wave: bool = false
var last_fallback_warning: String = ""                         # reset each _physics_process()
var _fallback_count_this_frame: int = 0
```

### Point ID Encoding (Binding)

Row-major: `point_id = cell.y * grid_cols + cell.x`
Inverse: `cell.x = point_id % grid_cols`, `cell.y = point_id / grid_cols`
Example at `grid_cols=16`: cell (col=2, row=3) → `point_id = 48 + 2 = 50`

**`super_goal_id = grid_cols * grid_rows`** — re-computed at start of EVERY template build; never cached as member variable across missions.

### Cell Cost Model

| Cell Type | `weight_scale` |
|-----------|---------------|
| PATH, SPAWN, GOAL | 1.0 |
| Unoccupied PLACEABLE | 10.0 |
| Occupied PLACEABLE | `astar.set_point_disabled(id, true)` |

### Template Build Trigger

```gdscript
func _on_mission_phase_changed(_prev: String, new_phase: String, _ts: float) -> void:
    _current_phase = new_phase
    match new_phase:
        "SCOUT":
            _build_all_templates()
        "INTERMISSION":
            if _tower_destroyed_during_wave:
                _tower_destroyed_during_wave = false
                # Mark all templates dirty for auto-rebuild
                for spawn_cell: Vector2i in _templates:
                    _dirty_templates[spawn_cell] = true
                if not _rebuild_queued:
                    _rebuild_queued = true
                    call_deferred("_rebuild_dirty_templates")
        "DEFEAT", "OUTCOME":
            _clear_all_state()
```

### F3 Slice Pattern (Binding)

```gdscript
# CORRECT — preserves Array[Vector2i] type annotation
var result: Array[Vector2i] = []
result.assign(template.path.slice(idx + 1))
return result

# WRONG — .slice() drops type annotation in GDScript 4
# return template.path.slice(idx + 1)
```

### would_block_all_paths() — 6-Step Procedure

```gdscript
func would_block_all_paths(cells: Array[Vector2i]) -> bool:
    # Step 1: deep copy of live walkability map
    var walkable_copy: Dictionary[Vector2i, bool] = Grid.get_walkable_cell_map().duplicate(true)
    # Step 2: mark footprint cells non-walkable in copy
    for c: Vector2i in cells:
        walkable_copy.erase(c)
    # Step 3: re-compute super_goal_id from current grid dims
    var grid_cols: int = Grid.get_grid_cols()
    var grid_rows: int = Grid.get_grid_rows()
    var temp_super_goal_id: int = grid_cols * grid_rows
    # Step 4: populate temp_goal_cells (mandatory before A* query)
    var temp_goal_cells: Array[Vector2i] = Grid.get_goal_cells()
    var spawn_cells: Array[Vector2i] = Grid.get_spawn_cells()
    # Step 5: build standalone PathfindingAStar2D from copy
    var temp_astar: PathfindingAStar2D = PathfindingAStar2D.new()
    temp_astar._super_goal_id = temp_super_goal_id
    temp_astar._grid_cols = grid_cols
    temp_astar.goal_cells = temp_goal_cells
    _populate_astar_from_walkable(temp_astar, walkable_copy, temp_goal_cells,
                                   temp_super_goal_id, grid_cols)
    # Step 6: run A* from each SPAWN; return true if any has no path
    for spawn_cell: Vector2i in spawn_cells:
        var spawn_id: int = spawn_cell.y * grid_cols + spawn_cell.x
        if not temp_astar.has_point(spawn_id):
            return true
        var id_path: PackedInt64Array = temp_astar.get_id_path(spawn_id, temp_super_goal_id)
        if id_path.is_empty():
            return true
    return false
```

### Deferred Rebuild Deduplication

```gdscript
func _on_tower_placed(_tower_id: int, _position: Vector2i, footprint: Array[Vector2i]) -> void:
    if _current_phase == "WAVE_ACTIVE":
        push_error("PathfindingSystem: tower_placed during WAVE_ACTIVE — Grid lock failure")
        _tower_destroyed_during_wave = true
        return
    _mark_dirty_from_footprint(footprint)

func _mark_dirty_from_footprint(footprint: Array[Vector2i]) -> void:
    for spawn_cell: Vector2i in _templates:
        var tmpl: RouteTemplate = _templates[spawn_cell]
        for cell: Vector2i in footprint:
            if tmpl.cell_index_map.has(cell):
                _dirty_templates[spawn_cell] = true
                break
    if not _rebuild_queued and not _dirty_templates.is_empty():
        _rebuild_queued = true
        call_deferred("_rebuild_dirty_templates")
```

### Mission Restart

On DEFEAT/OUTCOME: clear `_templates`, `_spawn_assignment`, `_dirty_templates`, reset `_rebuild_queued = false`, `_templates_built = false`, `_tower_destroyed_during_wave = false`.

### EventBus subscription

```gdscript
func _ready() -> void:
    EventBus.mission_phase_changed.connect(_on_mission_phase_changed)
    EventBus.tower_placed.connect(_on_tower_placed)
    EventBus.tower_removed.connect(_on_tower_removed)
    EventBus.tower_destroyed.connect(_on_tower_destroyed)

func _exit_tree() -> void:
    EventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)
    EventBus.tower_placed.disconnect(_on_tower_placed)
    EventBus.tower_removed.disconnect(_on_tower_removed)
    EventBus.tower_destroyed.disconnect(_on_tower_destroyed)
```

### process_priority

`PathfindingSystem.process_priority` must be lower (runs earlier) than all Monster nodes so `_fallback_count_this_frame` and `last_fallback_warning` are reset before monster `_physics_process()` callbacks read them.

## Out of Scope

- CI mission validator (`tools/validate_mission_map.gd`) — AC-13b/c/d, separate story
- Visual debug route overlay — Mission HUD, post-MVP
- Performance profiling / benchmark measurement — AC-4, AC-17, AC-24 require reference hardware; deferred to QA gate
- Multi-SPAWN missions — post-MVP (Voronoi code scaffolded but MVP uses N=1 SPAWN only)
- Registering Pathfinding as Autoload #4 in `project.godot` — tracked separately (requires all 4 Foundation autoloads + S2-05 boot-order test before registration)
- `would_block_all_paths()` hover-frequency guard — Tower System concern (ADR-0004 Risk)
- `tower_placement_blocked` event emission with `primary_blocking_cell` computation — implement as part of `would_block_all_paths()` but `primary_blocking_cell` iteration is secondary; mark as ADVISORY if not covered in initial tests

## Completion Notes
**Completed**: 2026-06-30
**Criteria**: 14/14 passing
**Deviations**:
- OUT OF SCOPE (valid): `src/foundation/grid/grid.gd` — added `get_grid_cols()` / `get_grid_rows()` getters required by ADR-0004; pure getters, no behavioral change to Grid
- ADVISORY: `_compute_cost` averaged weight makes PLACEABLE entry cost 5.5 (not 10.0) per cardinal step — correct A*, but monsters will shortcut through open PLACEABLE terrain at detours >9 PATH cells rather than ADR-0004's intended >19. Verify intended routing behavior with design before Vertical Slice.
**Test Evidence**: 31 unit tests across 3 files — `tests/unit/pathfinding/pathfinding_template_test.gd` (14), `pathfinding_block_test.gd` (8), `pathfinding_invalidation_test.gd` (9)
**Code Review**: Complete — CHANGES REQUIRED verdict resolved (typed Dictionary, Callable call_deferred, Array[Vector2i] param, AC-1 emission counter)
