# ADR-0004: Pathfinding Strategy — AStar2D with Pre-Computed Route Templates

## Status
Accepted

## Date
2026-05-16

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / Navigation |
| **Knowledge Risk** | LOW — `AStar2D` is a stable pre-Godot-4.x class, unchanged through 4.6. `NavigationServer2D` underwent significant API changes in 4.0 and again in 4.2; intentionally avoided here. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None — `AStar2D.add_point()`, `connect_points()`, `get_id_path()`, `get_point_path()` are all pre-4.x stable APIs. `AStar2D` subclassing for `_estimate_cost()` override is pre-4.x. |
| **Verification Required** | Verify `AStar2D.get_id_path()` returns `PackedInt64Array` (not `Array[int]`) — conversion to `Array[Vector2i]` requires a point_id → Vector2i lookup dictionary. Verify `_estimate_cost(from_id, to_id)` virtual override syntax is idiomatic in GDScript 4.x (use `func _estimate_cost(from_id: int, to_id: int) -> float:`). Verify `AStar2D.add_point(id, position, weight_scale)` accepts a float weight_scale for the PLACEABLE cost ratio. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus — Pathfinding emits `templates_ready` and `path_invalidated` via EventBus; subscribes to `tower_placed` and `tower_removed`); ADR-0002 (Scene/Autoload structure — Pathfinding is Autoload #4, boots after Grid, before SceneManager) |
| **Enables** | ADR-0006 (Monster movement — confirms that monsters read route templates via direct Pathfinding API, not NavigationAgent2D); ADR-0008 (Tower placement gate — `would_block_all_paths()` API is defined here); all Mission layer implementation stories |
| **Blocks** | All Pathfinding implementation stories and any Monster story that reads `get_path()`. The `templates_ready` event gate is required before WaveManager can emit `monster_spawn_requested`. |
| **Ordering Note** | Pathfinding is Autoload #4 (boots after Grid). Grid must be Autoload #3 so Pathfinding can call `Grid.get_walkable_cell_map()` at SCOUT phase start without null reference. Templates are NOT built in `_ready()` — Pathfinding subscribes to `mission_phase_changed` (EventBus) and builds templates when `new_phase == "SCOUT"`, after GridConfig is applied. This order was fixed by ADR-0002. |

## Context

### Problem Statement
Sanctuary Defenders requires 100+ simultaneous monsters to navigate a discrete 16×12 grid from SPAWN cells to GOAL cells, with routes updating live when the player places or removes a tower. The solution must fit within the game's frame budget during `WAVE_ACTIVE` — when no route recomputation should occur — and must block tower placements that would leave monsters with no path to a goal.

Two fundamental choices were needed:
1. **Which pathfinding API?** Godot provides `AStar2D` (fully programmable, grid-centric) and `NavigationServer2D` (mesh-based, continuous space, significantly changed in 4.x).
2. **Per-monster or shared route computation?** Running a fresh A* for each of 100+ monsters per placement event would consume the entire frame budget. A shared route template model amortises A* cost to O(SPAWN_count) per rebuild.

The game's GDD mandates the Pathfinding system is an Autoload, routes are pre-computed before WAVE_ACTIVE, and a `templates_ready` event gates the wave start sequence.

### Constraints
- `NavigationServer2D` underwent breaking API changes in Godot 4.0 (removal of `Navigation2D` node) and again in 4.2 (navigation region baking). These changes are partially post-LLM-cutoff — using NavigationServer2D would require extensive API verification against engine reference docs.
- 100+ monsters share routes simultaneously. Per-monster A* during WAVE_ACTIVE would spike the CPU budget.
- Tower writes are locked by the Grid during `WAVE_ACTIVE` — route recomputation cannot happen during active waves. Routes must be stable once the wave starts.
- `would_block_all_paths(footprint)` must be callable synchronously before tower placement confirmation, without mutating cached route state.
- The game grid is discrete and cardinal-only — no continuous-space navigation is needed.

### Requirements
- One `AStar2D` instance per SPAWN cell. Pre-compute a full route template (SPAWN → nearest GOAL) at SCOUT phase start.
- Template lookup returns the remaining path from a monster's current cell in O(1) — no per-monster A* during WAVE_ACTIVE.
- After a tower event, recompute only the templates whose paths pass through the changed cells (deferred, batched).
- After all dirty templates are rebuilt, emit `path_invalidated` so active monsters can refresh their local path copies.
- Emit `templates_ready` after initial template build — gates WaveManager from spawning until routes exist.
- Provide `would_block_all_paths(footprint) -> bool` for Tower System pre-placement validation.
- Multi-GOAL routing requires a single A* pass, not one pass per GOAL cell.

## Decision

### Pathfinding API: AStar2D (not NavigationServer2D)

`AStar2D` is chosen for all route computation. One `AStar2D` instance is created per SPAWN cell. Each instance is cleared and repopulated when its template is marked dirty. `AStar2D` is subclassed in GDScript to override `_estimate_cost()` for the super-goal heuristic (Rule 8 in GDD).

**Why not NavigationServer2D:**
- NavigationServer2D operates in continuous space with navigation meshes — the game's grid is entirely discrete.
- NavigationServer2D's API changed significantly in Godot 4.0 and 4.2 (both partially post-LLM-cutoff). AStar2D is a stable, well-understood API.
- NavigationAgent2D (the node-level consumer) would need to be attached to each monster, adding per-monster overhead and continuous-space interpolation that fights the game's cell-step movement model.
- AStar2D is C++ backed — there is no GDScript overhead for the graph traversal itself.

### Route Template Model

The Pathfinding Autoload maintains one **route template** per SPAWN cell:

```gdscript
class_name RouteTemplate
var path: Array[Vector2i]             # Ordered cells SPAWN → GOAL (GOAL cell included)
var cell_index_map: Dictionary        # Vector2i → int: O(1) reverse lookup
```

Templates are built once at `SCOUT` phase start (after `GridConfig` is applied, before player tower placement). After all templates are built, `templates_ready(spawn_count: int, build_duration_ms: float)` is emitted via EventBus.

### Super-Goal for Multi-GOAL Routing

When multiple GOAL cells exist, a virtual **super-goal node** is added to each AStar2D instance:

```gdscript
const SUPER_GOAL_ID: int = grid_cols * grid_rows  # One past the last valid cell ID

# One-time setup per AStar2D instance:
astar.add_point(SUPER_GOAL_ID, Vector2.ZERO, 0.0)  # weight_scale = 0 (zero-cost)
for goal_cell in Grid.get_goal_cells():
    astar.connect_points(cell_to_id(goal_cell), SUPER_GOAL_ID, false)  # bidirectional=false
```

A* runs to `SUPER_GOAL_ID`. The returned `PackedInt64Array` is converted to `Array[Vector2i]` via a `point_id → Vector2i` reverse lookup dict. The super-goal ID is stripped from the result. The stored `path` includes the GOAL cell as its final entry.

**Heuristic admissibility** for the super-goal: subclass `AStar2D` and override `_estimate_cost()`. When `to_id == SUPER_GOAL_ID`, return `min(manhattan(cell_at(from_id), g) for g in goal_cells)`. This is admissible — the minimum Manhattan distance to any GOAL cell never overestimates the true path cost to the nearest reachable GOAL.

### Key Interfaces

```gdscript
# PathfindingSystem.gd — Autoload #4

# Called by Monster System at spawn and after path_invalidated:
func get_path(from_cell: Vector2i, tier: int) -> Array[Vector2i]:
    # tier: reserved for MVP; all tiers use standard routing
    # Returns remaining path from from_cell to GOAL.
    # O(1) template lookup + O(k) slice where k = remaining cells.
    # Fallback: standalone A* if from_cell not in any template (logs push_warning).
    # Two-value return: [] (GOAL arrival, unreachable, or fallback cap exhausted) OR
    # non-empty Array[Vector2i] (valid remaining path). Never returns null.

# Called by Tower System before placement confirmation:
func would_block_all_paths(cells: Array[Vector2i]) -> bool:
    # Speculatively marks cells non-walkable in a temp copy.
    # Builds temporary AStar2D instances from the copy.
    # Returns true if any SPAWN has no path to any GOAL.
    # Does NOT mutate cached template state.

# Internal — triggered by tower_placed / tower_removed EventBus subscription:
func _on_tower_changed(footprint: Array[Vector2i]) -> void:
    # Checks each template's cell_index_map for footprint membership.
    # Marks affected templates dirty.
    # Defers _rebuild_dirty_templates() to end of physics frame.

# Emits (via EventBus):
# templates_ready(spawn_count: int, build_duration_ms: float)  — after initial build
# path_invalidated(affected_cells: Array[Vector2i])             — after dirty rebuild
```

### Cell Cost Model

| Cell Type | `weight_scale` in AStar2D | Rationale |
|-----------|--------------------------|-----------|
| PATH | 1.0 | Designated lanes — minimum cost |
| SPAWN | 1.0 | Equal to PATH — spawn cells are traversable |
| GOAL | 1.0 | Equal to PATH — goal cells are traversable |
| PLACEABLE (unoccupied) | 10.0 | Strong preference for PATH lanes; a full PATH→PLACEABLE→PATH crossing costs W+1 = 11 PATH steps — detour > 11 steps triggers 1-cell PLACEABLE shortcut (per GDD F4 cost model) |
| Tower (occupied PLACEABLE) | Removed from graph | `astar.set_point_disabled(id, true)` — non-walkable |

The PLACEABLE cost ratio of 10 ensures monsters route through designated PATH lanes by default and only cross open PLACEABLE terrain when the PATH alternative is substantially longer (>9 cells). This makes chokepoints tactically meaningful.

### Invalidation and Rebuild Sequence

```
TOWER_PLACED / TOWER_REMOVED event received (from EventBus)
  │
  ├─ For each template: check cell_index_map for any footprint cell
  ├─ Mark matching templates dirty
  └─ call_deferred("_rebuild_dirty_templates")

_rebuild_dirty_templates() (runs at end of physics frame — batched):
  │
  For each dirty template:
  ├─ Grid.get_walkable_cell_map() → fresh snapshot
  ├─ Clear + repopulate AStar2D instance
  ├─ A* to super-goal → PackedInt64Array → Array[Vector2i] (strip super-goal ID)
  ├─ Rebuild cell_index_map
  └─ Store updated template
  │
  └─ EventBus.path_invalidated.emit(union_of_all_footprint_cells)
```

Multiple tower events in the same frame are batched — a 2×2 tower generates one footprint union, not four separate A* runs.

### Architecture Diagram

```
MISSION START (SCOUT phase)
  │
  ▼ Pathfinding._on_mission_phase_changed(new_phase) — triggered by EventBus `mission_phase_changed`
    when new_phase == "SCOUT" (NOT in _ready() — templates build after GridConfig is applied)
  ┌─────────────────────────────────────────┐
  │  Grid.get_spawn_cells()  → N cells      │
  │  Grid.get_goal_cells()   → M cells      │
  │  Grid.get_walkable_cell_map() → map     │
  │                                         │
  │  For each SPAWN cell:                   │
  │    Build AStar2D instance               │
  │    Add super-goal node (ID = cols×rows) │
  │    Run A* → store RouteTemplate         │
  │                                         │
  │  Build _spawn_assignment (Voronoi)      │
  │  EventBus.templates_ready.emit(...)     │
  └─────────────────────────────────────────┘

WAVE_ACTIVE (hot path)
  Monster.get_path(from_cell, tier)
  → _spawn_assignment[from_cell] → template index
  → template.cell_index_map[from_cell] → idx
  → template.path.slice(idx + 1)      → Array[Vector2i]
  No A* computation. O(1) lookup + O(k) slice.

TOWER PLACED/REMOVED (SCOUT or INTERMISSION only)
  EventBus.tower_placed/tower_removed → _on_tower_changed(footprint)
  → dirty check → deferred rebuild → EventBus.path_invalidated

PRE-PLACEMENT VALIDATION
  Tower.confirm_placement(footprint)
  → Pathfinding.would_block_all_paths(footprint)
     → temp copy of walkability map
     → temp AStar2D per SPAWN → A* to super-goal
     → returns bool (does NOT mutate cached templates)
  If true → Tower.place_tower() rejected, no Grid write
```

### MVP Constraint: Single SPAWN Cell

At MVP, all missions use exactly one SPAWN cell. The Voronoi partition (`_spawn_assignment`) is computed but returns index 0 for all walkable cells. Multi-SPAWN missions are a post-MVP feature — no MVP mission may ship with more than one SPAWN cell.

The super-goal mechanism is implemented regardless of SPAWN count — a single SPAWN with multiple GOALs still uses the super-goal for correct nearest-GOAL routing.

## Alternatives Considered

### Alternative A: NavigationServer2D + NavigationAgent2D per monster
- **Description**: Each monster is a `NavigationAgent2D` consumer. Navigation meshes are baked from the grid's walkable area. Monsters call `NavigationAgent2D.get_next_path_position()` each frame.
- **Pros**: Godot-native continuous-space navigation; handles arbitrary mesh shapes natively.
- **Cons**: NavigationServer2D API changed significantly in Godot 4.0 and 4.2 — post-LLM-cutoff API risk is HIGH for this domain. Each monster computes its own path independently — 100+ monsters means 100+ path queries per frame. Baking navigation meshes from a discrete grid adds complexity with no benefit over a cell-cost AStar2D. Continuous-space interpolation fights the game's cell-step movement model (monsters move one cell per physics tick, not along a smooth spline).
- **Rejection Reason**: High post-cutoff API risk, per-monster computation overhead, and a mismatch with the discrete grid model. AStar2D is a better fit at every dimension.

### Alternative B: Per-monster A* on demand (no route templates)
- **Description**: Each monster runs its own A* query at spawn and after each `path_invalidated` event.
- **Pros**: No shared template state to manage; each monster always has a fresh path; simpler invalidation logic.
- **Cons**: 100 monsters × A* per `path_invalidated` = 100 A* runs per tower placement. On a 16×12 grid, a single A* run is fast (~0.02 ms), but 100 runs = ~2 ms — consuming the entire EventBus frame budget in one event. At peak (multiple placements per SCOUT phase) this would spike visibly.
- **Rejection Reason**: O(monster_count × SPAWN_count) A* runs per placement event vs. O(SPAWN_count) with route templates. At 100 monsters and MVP's single SPAWN, templates reduce per-event A* from ~100 runs to 1 run.

### Alternative C: Pre-baked path grid (flow field / influence map)
- **Description**: Pre-compute a directional vector for every cell pointing toward the nearest GOAL. Monsters read their cell's vector to determine next step — no A* queries during gameplay.
- **Pros**: O(1) per-monster movement decision; extremely cache-friendly; scales to thousands of monsters.
- **Cons**: Flow field invalidation on tower placement requires updating potentially the entire grid (cells far from the changed tower may change their optimal direction). Building the flow field requires a backward BFS/Dijkstra from all GOAL cells simultaneously. More complex to implement than AStar2D — no Godot built-in support.
- **Rejection Reason**: Over-engineered for 100 monsters at MVP. AStar2D templates achieve acceptable performance at 1/10th the implementation complexity. Flow fields are the right answer at 1000+ monsters — a post-MVP consideration if profiling reveals template slice pressure.

## Consequences

### Positive
- O(SPAWN_count) A* runs per placement event — at MVP (1 SPAWN), exactly 1 A* run per tower change.
- O(1) `get_path()` lookup during WAVE_ACTIVE — 100 monsters calling `get_path()` per frame has negligible CPU cost.
- `would_block_all_paths()` uses a temp copy of the walkability map — cached templates are never mutated by validation queries.
- `templates_ready` event provides a clean async gate — WaveManager cannot start spawning before routes exist.
- Deferred dirty rebuild batches multiple tower events in the same frame — a 2×2 tower generates 1 A* run, not 4.
- AStar2D is a stable, well-understood Godot API with no post-cutoff changes — implementation risk is LOW.

### Negative
- Route template model stores one `Array[Vector2i]` per SPAWN cell (~10–30 cells on a 16×12 grid). At MVP (1 SPAWN, ~192 walkable cells, ~30 step route), memory footprint is negligible.
- `get_path()` returns a **copy** of the path slice — 100 monsters × average 25-cell slice = 2500 Vector2i copies per frame. This is a known hotspot flagged in the GDD. Must be profiled during prototyping; if allocation pressure is observed, switch to returning a view (start index + template reference) rather than a copied slice.
- `_estimate_cost()` override requires subclassing `AStar2D` in GDScript — adds one custom class file to the project.
- Voronoi partition (Chebyshev distance, all walkable cells) is computed at SCOUT start — a one-time O(cells × SPAWN_count) pass. At MVP (192 cells × 1 SPAWN), this is negligible.

### Risks
- **Risk**: `get_path()` copy allocation becomes a frame budget problem at 100+ monsters with long routes. **Mitigation**: GDD flags this as a known hotspot. Profile during prototyping. If allocation pressure is confirmed, refactor `get_path()` to return `(template_ref, start_index)` — monsters advance the index directly without copying the slice.
- **Risk**: `templates_ready` is not emitted if `Grid.get_spawn_cells()` returns empty (valid error case for a misconfigured mission). WaveManager never receives the event and the mission hangs. **Mitigation**: WaveManager must implement a `_routes_ready: bool` flag that stays false until `templates_ready` fires. Mission loading should validate SPAWN/GOAL cell counts against GDD minimums before entering SCOUT. AC-13 in the GDD mandates a CI validator for this.
- **Risk**: A developer calls `would_block_all_paths()` from hover (per-frame) rather than placement confirmation (on click/release). At ~60 hover events/second × temp A* construction cost → frame budget spike. **Mitigation**: GDD Rule 10 explicitly restricts `would_block_all_paths()` to placement confirmation only. Code review enforces this. A `push_warning` can be added if the call frequency exceeds 2/second.
- **Risk**: The super-goal `SUPER_GOAL_ID = grid_cols × grid_rows` collides with a real cell ID if the grid is resized beyond the safe range. **Mitigation**: The last valid real cell ID is `(grid_rows − 1) × grid_cols + (grid_cols − 1) = grid_cols × grid_rows − 1`. SUPER_GOAL_ID is therefore always one past the last real cell and never collides within any grid size the game supports. An assertion at startup verifies this invariant.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| pathfinding.md | Rule 1: Autoload singleton, direct function call API | Pathfinding as Autoload #4 confirmed by ADR-0002; `get_path()` and `would_block_all_paths()` are direct-call APIs |
| pathfinding.md | Rule 4: One route template per SPAWN cell | RouteTemplate structure with `path` + `cell_index_map` defined in Decision |
| pathfinding.md | Rule 5: `templates_ready` event gates WaveManager | Event emission after initial build confirmed; WaveManager must subscribe |
| pathfinding.md | Rule 8: Super-goal for multi-GOAL routing | SUPER_GOAL_ID formula and heuristic admissibility documented in Decision |
| pathfinding.md | Rule 9: `would_block_all_paths()` — pre-placement only, not hover | API defined; placement-only restriction documented in Risks |
| pathfinding.md | Rule 14: `path_invalidated` emitted after deferred dirty rebuild | Invalidation sequence documented; batching of multiple tower events confirmed |
| pathfinding.md | Rule 15c: F3 slice formula — O(1) lookup + O(k) copy | `get_path()` implementation notes the hotspot and profiling requirement |
| pathfinding.md | Rule 16–18: Cardinal-only, cell costs, Manhattan heuristic | Cell cost model table defined; `_estimate_cost()` override specified |
| pathfinding.md | Rule 19: AStar2D C++ backed, one instance per SPAWN | Decision section; Alternative A rejection reasoning |
| wave-manager.md | Wave Manager must not emit `monster_spawn_requested` before `templates_ready` | ADR Dependencies section; `_routes_ready` flag requirement documented in Risks |
| monster.md | Monster reads route template via direct Pathfinding API | `get_path()` API confirmed; ADR-0006 (Monster movement) is enabled by this ADR |
| tower.md | Tower placement blocked if `would_block_all_paths()` returns true | API defined here; Tower System ownership of the placement gate confirmed |

**Technical Requirements covered**: TR-path-001, TR-path-002, TR-path-003, TR-path-004, TR-path-005, TR-path-006, TR-monster-004, TR-wave-004

## Performance Implications
- **CPU (WAVE_ACTIVE)**: `get_path()` is O(1) lookup + O(k) Array.slice — no A* computation. At 100 monsters × average k=25 cells, ~2500 `Vector2i` copies per frame. Estimated < 0.1 ms under normal conditions; flagged as a profiling priority.
- **CPU (tower placement)**: 1 A* run per dirty SPAWN template. At MVP (1 SPAWN, 16×12 grid), a single A* run is estimated at ~0.02 ms. `would_block_all_paths()` builds temp AStar2D instances — ~0.05–0.1 ms per call. Only on placement confirmation, not hover.
- **CPU (SCOUT start)**: N templates × A* + Voronoi partition. At MVP (1 SPAWN, 192 walkable cells), estimated < 1 ms total. Acceptable for a one-time load event.
- **Memory**: One `AStar2D` instance per SPAWN cell + RouteTemplate Arrays. At MVP (1 SPAWN, ~30-step route), negligible. At 5 SPAWNs (post-MVP maximum), still < 1 MB.
- **Load Time**: Template build occurs during SCOUT phase entry, not during scene load — loading screen is already dismissed before this runs.
- **Network**: Not applicable (single-player only).

## Migration Plan
Greenfield project. No existing pathfinding code to migrate. Pathfinding is the first implementation deliverable after EventBus, SavePersistence, and Grid Autoloads are wired up.

## Validation Criteria
- [ ] `AStar2D.get_id_path(spawn_id, super_goal_id)` returns a `PackedInt64Array` that correctly excludes the `SUPER_GOAL_ID` after stripping, with the GOAL cell as the final entry.
- [ ] `templates_ready` is emitted after initial template build, before any `monster_spawn_requested` can fire. WaveManager's `_routes_ready` flag correctly gates spawn logic.
- [ ] `get_path(spawn_cell, 0)` returns the full template path (index 0 of the slice).
- [ ] `get_path(mid_route_cell, 0)` returns the path slice from that cell to GOAL.
- [ ] `get_path(cell_not_in_template, 0)` triggers fallback A*, logs `push_warning`, and returns a valid path or `[]`.
- [ ] `would_block_all_paths(footprint_that_blocks_all_routes)` returns `true` and the template cache is unchanged after the call.
- [ ] A tower placement followed by `path_invalidated` causes active monsters to refresh their path copies — verified by integration test.
- [ ] Multiple tower events in the same frame produce exactly 1 `path_invalidated` emission with the union of all footprint cells.
- [ ] `SUPER_GOAL_ID = grid_cols × grid_rows` does not collide with any real cell ID on a 16×12 grid — asserted at startup.

## Related Decisions
- ADR-0001 — EventBus architecture (`templates_ready` and `path_invalidated` are EventBus signals; `tower_placed` and `tower_removed` are subscribed via EventBus)
- ADR-0002 — Scene and Autoload structure (Pathfinding as Autoload #4; Grid as Autoload #3 — boot dependency confirmed)
- ADR-0005 — Grid system (Pathfinding calls `Grid.get_walkable_cell_map()` at SCOUT phase start via `mission_phase_changed` subscription; boot order Grid #3 → Pathfinding #4)
- ADR-0006 — Monster movement (uses `get_path()` directly; Area2D root is compatible with cell-step movement reading template slices)
- ADR-0008 — Tower placement gate (calls `would_block_all_paths()` before placement; WAVE_ACTIVE write lock defined here)
- `design/gdd/pathfinding.md` — canonical source for all rules, formulas, edge cases, and acceptance criteria
