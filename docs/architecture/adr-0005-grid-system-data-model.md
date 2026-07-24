# ADR-0005: Grid System Data Model and Access Pattern

## Status
Accepted

## Date
2026-05-16

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / Data Structures |
| **Knowledge Risk** | LOW — `Dictionary`, `Array`, `Vector2i`, `Error` enum, and `floor()` are all stable pre-4.x APIs unchanged through 4.6 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | `Dictionary[Vector2i, CellType]`, `Dictionary[Vector2i, int]`, `Dictionary[Vector2i, bool]` — typed Dictionaries (Godot 4.4+; corrected 2026-07-13 via `/architecture-review` Pass 4 — this row previously read "None," which contradicted the Decision section below. Functionally low-risk: `grid-system.md`'s own Engine Risk Notes table already lists typed Dictionaries as "Verified working — exercised by the passing test suite," and `VERSION.md`'s Project-Specific API Tracking table independently confirms the same. This was a documentation-accuracy fix only, not a behavior change.) |
| **Verification Required** | Verify `ERR_UNAVAILABLE` from the `Error` enum is the correct constant for "operation not available in current state" (as opposed to `ERR_LOCKED` or `FAILED`). (The typed-Dictionary compile-and-runtime verification previously listed here is now confirmed — see Post-Cutoff APIs Used row.) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus — Grid subscribes to `mission_phase_changed` via EventBus to transition between ACTIVE_WRITABLE and ACTIVE_READONLY); ADR-0002 (Scene/Autoload structure — Grid is Autoload #3, boots after EventBus and SavePersistence, before Pathfinding) |
| **Enables** | ADR-0006 (Monster movement — monsters read grid state via PathfindingSystem which calls `get_walkable_cell_map()`); ADR-0007 (Damage pipeline — D&S queries Grid for occupant lookups when resolving AoE); ADR-0008 (Tower placement gate — Tower System is the exclusive Grid write caller; write gate is defined here); ADR-0009 (Resource data model — GridConfig Resource carries cell type data into Grid at mission start) |
| **Blocks** | All implementation stories for Tower System, Constellation System, Pathfinding System, Wave Manager, Tower Mastery System, and Monster System that require spatial queries |
| **Ordering Note** | Grid must be Autoload #3 so it is ready when Pathfinding (Autoload #4) calls `get_walkable_cell_map()` in its own `_ready()`. Pathfinding cannot run its initial template build until Grid is initialized with a GridConfig — see templates_ready gate in ADR-0004. |

## Context

### Problem Statement
Sanctuary Defenders requires a spatial data structure that is the single authoritative source of cell type and tower occupancy for the entire mission. Seven systems query or modify this data during gameplay. A clear API boundary — what data is read-only, what is write-restricted, and what contract callers can rely on — must be decided now, before any system is implemented, to prevent coupling between systems and to ensure that the Grid's data can be safely shared.

Four specific decisions need documentation:
1. **Data model**: How cell types and occupancy are stored internally.
2. **API boundary**: Which systems may read and write, and via which mechanism.
3. **Return-by-copy contract**: Whether read functions return live references or snapshots.
4. **State machine**: How the Grid enforces write restrictions during WAVE_ACTIVE.

### Constraints
- Grid is an Autoload (confirmed by ADR-0002 / `autoload_boot_order`) — accessible project-wide without scene-tree queries.
- All seven consuming systems use `Vector2i` coordinates for cell addressing, established by grid-system GDD.
- Write restriction during WAVE_ACTIVE must be enforced by the Grid itself — the Tower System UI may not perfectly block all input paths.
- The general EventBus-only cross-system rule (ADR-0001) does not apply to the Grid read API: read functions are called directly as an intentional exception documented in GDD Rule 8, because routing per-frame spatial queries through EventBus would consume an unacceptable share of the frame budget.
- Grid state is not persisted (ADR-0003 registry: `save_slot_data` owned by SavePersistence — Grid has no save state).

### Requirements
- `Dictionary[Vector2i, CellType]` for cell type storage — sparse, supports non-rectangular map layouts.
- `Dictionary[Vector2i, int]` for occupancy — maps occupied cells to tower entity IDs.
- Read API callable by any system directly (Autoload direct access).
- Write API callable only by Tower System (convention enforced by code review).
- All array-returning read functions return **copies** — callers get snapshots, not live references.
- State machine: `UNINITIALIZED` → `ACTIVE_WRITABLE` → `ACTIVE_READONLY` ↔ `ACTIVE_WRITABLE`, driven by `mission_phase_changed` EventBus subscription.
- Write attempts in `ACTIVE_READONLY` return `ERR_UNAVAILABLE` (project constant: `GRID_WRITE_REJECTED = ERR_UNAVAILABLE`).
- `world_to_cell()` uses `floor()` — not integer truncation — to correctly handle negative world positions at cell boundaries.

## Decision

### Data Model: Two Typed Dictionaries

The Grid Autoload (`Grid.gd`) maintains two internal data structures:

```gdscript
# Grid.gd — Autoload #3
class_name Grid
extends Node

enum CellType { PLACEABLE, PATH, SPAWN, GOAL, BLOCKED }

# ---- Internal state ----
var _cell_types: Dictionary[Vector2i, CellType] = {}  # Set at mission init; static during mission
var _occupancy: Dictionary[Vector2i, int] = {}         # Maps occupied cells to tower entity IDs
var _grid_cols: int = 16       # Set from GridConfig at mission start
var _grid_rows: int = 12       # Set from GridConfig at mission start
var _cell_size: float = 64.0   # Set from GridConfig at mission start

enum GridState { UNINITIALIZED, ACTIVE_WRITABLE, ACTIVE_READONLY }
var _state: GridState = GridState.UNINITIALIZED

const GRID_WRITE_REJECTED: int = ERR_UNAVAILABLE
```

`_cell_types` is populated once at mission start from a `GridConfig` Resource and is **static for the entire mission** — cell types do not change mid-mission. Cells not in `_cell_types` are implicitly `BLOCKED`.

`_occupancy` is modified only during `ACTIVE_WRITABLE` (SCOUT and INTERMISSION phases). It maps each cell that has a tower to that tower's integer entity ID. An absent key means the cell is unoccupied.

### API Boundary

**Read API (direct call, any system)**

```gdscript
# Placement validation
func is_placeable(cell: Vector2i) -> bool
func is_footprint_placeable(top_left: Vector2i, size: Vector2i) -> bool

# Cell queries
func get_cell_type(cell: Vector2i) -> CellType     # Returns BLOCKED if cell not in config
func get_occupant(cell: Vector2i) -> int            # Returns -1 if unoccupied

# Spatial queries (all return copies)
func get_all_occupied_cells() -> Array[Vector2i]
func get_occupied_cells_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]
func get_towers_in_range(center: Vector2i, radius: int) -> Array[int]
func get_spawn_cells() -> Array[Vector2i]
func get_goal_cells() -> Array[Vector2i]
func get_walkable_cell_map() -> Dictionary[Vector2i, bool]

# Coordinate conversion
func world_to_cell(world_pos: Vector2) -> Vector2i
func cell_to_world(cell: Vector2i) -> Vector2
func is_in_bounds(cell: Vector2i) -> bool
```

**Write API (Tower System only — convention enforced by code review)**

```gdscript
func place_tower(tower_id: int, top_left: Vector2i, size: Vector2i) -> Error
func remove_tower(tower_id: int) -> void
```

`place_tower` returns `OK` on success or `GRID_WRITE_REJECTED` (`ERR_UNAVAILABLE`) if:
- Any cell in the footprint is non-PLACEABLE
- Any cell in the footprint is already occupied
- Grid state is `ACTIVE_READONLY`

`remove_tower` performs an O(N_occupied) linear scan of `_occupancy` to find all cells matching `tower_id` and clears them. No return value — the Tower System confirms removal by re-checking occupancy.

**Mission lifecycle API (Mission Select System only)**

```gdscript
func initialize(config: GridConfig) -> void
# Called once per mission; populates _cell_types from config, clears _occupancy,
# transitions _state to ACTIVE_WRITABLE.
```

### Return-by-Copy Contract

All functions returning `Array[Vector2i]` or `Dictionary` return **new copies**, never references to internal data structures. This ensures callers can safely iterate without risk of mid-iteration mutation.

Implemented via:
- `Array[Vector2i]` returns: explicit `.duplicate()` on internal arrays, or construction of a new array from a Dictionary key scan.
- `Dictionary` returns: explicit `.duplicate()` on internal dictionaries.

**Code review invariant**: Any PR that returns `_occupancy` or `_cell_types` directly (not via `.duplicate()` or explicit construction) is a correctness violation. The review gate is the only enforcement mechanism.

### State Machine

```
UNINITIALIZED
  │ Grid.initialize(config) called by Mission Select System
  ▼
ACTIVE_WRITABLE  ←──────────────────────────────┐
  │ mission_phase_changed(WAVE_ACTIVE)           │
  ▼                                              │
ACTIVE_READONLY                                  │
  │ mission_phase_changed(INTERMISSION)          │
  └─────────────────────────────────────────────┘
  │ mission_phase_changed(DEFEAT or OUTCOME)
  ▼
UNINITIALIZED (occupancy cleared; _cell_types reset on next initialize())
```

The Grid subscribes to `EventBus.mission_phase_changed` in `_ready()` and disconnects in `_exit_tree()` (ADR-0001 rule: mandatory `_exit_tree()` disconnect).

### World-to-Cell Coordinate Semantics

```gdscript
func world_to_cell(world_pos: Vector2) -> Vector2i:
    return Vector2i(
        int(floor(world_pos.x / _cell_size)),
        int(floor(world_pos.y / _cell_size))
    )

func cell_to_world(cell: Vector2i) -> Vector2:
    return Vector2(
        cell.x * _cell_size + _cell_size * 0.5,
        cell.y * _cell_size + _cell_size * 0.5
    )
```

`floor()` is required for negative world positions. Integer truncation rounds toward zero — `floor(-0.1 / 64.0)` = `floor(-0.00156)` = `-1`, while `int(-0.00156)` = `0`. The boundary at `world_pos.x = 0` must belong to cell column 0, and any negative x must resolve to a negative (out-of-bounds) column.

### Walkability Semantics

`get_walkable_cell_map()` returns a `Dictionary[Vector2i, bool]` where:
- **Key present, value `true`**: cell is walkable (PATH, SPAWN, GOAL, or unoccupied PLACEABLE)
- **Key absent** (not in dict): cell is non-walkable (BLOCKED, or occupied PLACEABLE)

This absence-means-non-walkable contract means Pathfinding can check walkability with `if cell in walkable_map` — no default-value guard needed. The Pathfinding System must call `get_walkable_cell_map()` fresh after each `tower_placed` or `tower_removed` EventBus event; caching a stale map across tower changes is a correctness violation.

### Architecture Diagram

```
MISSION START
  Mission Select System → Grid.initialize(GridConfig)
    → _cell_types populated (non-BLOCKED cells only)
    → _occupancy cleared
    → _state = ACTIVE_WRITABLE

SCOUT / INTERMISSION (ACTIVE_WRITABLE)
  Tower System   → Grid.is_footprint_placeable(top_left, size) → bool
  Tower System   → Grid.place_tower(tower_id, top_left, size)  → Error
  Tower System   → Grid.remove_tower(tower_id)

WAVE_ACTIVE (ACTIVE_READONLY — writes return GRID_WRITE_REJECTED)
  Pathfinding    → Grid.get_walkable_cell_map()                 → Dictionary[Vector2i, bool]
  Pathfinding    → Grid.get_spawn_cells()                       → Array[Vector2i] (copy)
  Pathfinding    → Grid.get_goal_cells()                        → Array[Vector2i] (copy)
  Monster        → Grid.world_to_cell(world_pos)                → Vector2i
  Monster        → Grid.cell_to_world(cell)                     → Vector2
  Constellation  → Grid.get_all_occupied_cells()                → Array[Vector2i] (copy)
  Constellation  → Grid.get_occupied_cells_in_radius(...)       → Array[Vector2i] (copy)
  Tower Mastery  → Grid.get_occupied_cells_in_radius(...)       → Array[Vector2i] (copy)
  Wave Manager   → Grid.get_spawn_cells()                       → Array[Vector2i] (copy)

EventBus.mission_phase_changed → Grid (updates _state)
```

## Alternatives Considered

### Alternative A: 2D Array indexed by row and column

- **Description**: Internal storage as `Array[Array[CellType]]` sized `grid_rows × grid_cols`. Cell at `(col, row)` accessed as `_cell_types[row][col]`.
- **Pros**: O(1) access with array index arithmetic; potentially cache-friendly for row-sequential iteration.
- **Cons**: Requires allocating all `grid_rows × grid_cols` entries regardless of how many are non-BLOCKED; forces rectangular map layout; accessing `_cell_types[row][col]` requires callers to swap x/y (bug-prone); does not naturally represent sparse layouts.
- **Rejection Reason**: `Dictionary` with `Vector2i` keys has identical O(1) asymptotic cost, is idiomatic GDScript, naturally handles sparse maps, and keeps callers using the same `Vector2i` coordinate type used throughout all GDDs.

### Alternative B: TileMapLayer as the data container

- **Description**: Use a `TileMapLayer` node (replacement for deprecated `TileMap` since Godot 4.3) as the authoritative grid storage. Cell types encoded as tile IDs. Pathfinding reads from TileMapLayer.
- **Pros**: Native Godot tool; built-in visual editing in the editor; automatic cell-to-world coordinate helpers.
- **Cons**: `TileMapLayer` is a visual/rendering node — it carries texture atlas, rendering pipeline, and editor overhead that is unnecessary for a pure data store. Coupling mission spatial data to a scene node means Grid data is destroyed when the scene changes (breaks the Autoload model). The render representation of the grid is owned by Mission HUD — mixing data and visuals creates bidirectional coupling.
- **Rejection Reason**: The Grid must be a stateless-between-missions Autoload with a clean programmatic API. TileMapLayer is a scene node — the wrong abstraction for a shared data store.

### Alternative C: `Dictionary[int, CellType]` with manual cell ID encoding

- **Description**: Encode `Vector2i(col, row)` as a single integer key: `cell_id = row * grid_cols + col`. Internal structures use `Dictionary[int, CellType]` and `Dictionary[int, int]`.
- **Pros**: Integer keys are potentially faster to hash than `Vector2i` struct keys.
- **Cons**: Every call site that passes a `Vector2i` must call an `_encode(cell)` helper before lookup and `_decode(id)` after extraction — adds code complexity and off-by-one risk at boundaries.
- **Rejection Reason**: API clarity wins over speculative micro-optimization. `Vector2i` keys eliminate the encode/decode layer, making the implementation directly match all GDD coordinate references. Performance benefit of integer hashing over `Vector2i` hashing is unmeasured and unlikely to matter for ≤240 cells.

## Consequences

### Positive
- All seven dependent systems share a single, unambiguous spatial truth with no cross-system state ownership dispute for cell types or occupancy.
- `Dictionary[Vector2i, CellType]` is sparse — only configured cells consume memory. 192-cell default grid with typical partial BLOCKED coverage stores only non-BLOCKED cells.
- Return-by-copy contract makes all read-heavy callers (Constellation System iterating occupied cells, Pathfinding rebuilding templates) safe from concurrent mutation with no lock or version counter needed.
- Write gate via `_state` enum is exhaustive — no write path bypasses it without explicitly violating the API contract.
- Absence-means-non-walkable `get_walkable_cell_map()` contract minimizes the data Pathfinding must consume: only walkable cells are present as keys.

### Negative
- `.duplicate()` on every array-returning function adds a small heap allocation per call. For `get_all_occupied_cells()` called frequently by Constellation System, this is a known allocation hotspot. Profile during integration — if allocation pressure is observed, introduce a `get_occupied_cell_count() -> int` + index-based access pattern to avoid the copy.
- Write restriction is by convention, not engine enforcement. If a non-Tower system calls `Grid.place_tower()`, GDScript will not prevent it — code review is the only gate.
- `remove_tower(tower_id)` is O(N_occupied) — linear scan of `_occupancy`. At ≤240 occupied cells (pathological worst case), this is negligible. Profile if tower removal causes frame spikes during INTERMISSION cleanup.

### Risks
- **Risk**: A caller caches `get_walkable_cell_map()` across a tower placement event and Pathfinding uses a stale walkability map. **Mitigation**: Control Manifest rule: "Never cache `get_walkable_cell_map()` across EventBus `tower_placed` or `tower_removed` events." ADR-0004 already requires Pathfinding to refresh after tower events.
- ~~**Risk**: `Dictionary[Vector2i, CellType]` static typing with a user-defined enum value type may not compile in Godot 4.6.2 GDScript.~~ **RESOLVED** — confirmed working via the passing test suite (see `grid-system.md`'s Engine Risk Notes table and `VERSION.md`'s Project-Specific API Tracking table). No cast/helper workaround was needed.
- **Risk**: Tower System accesses write API during WAVE_ACTIVE due to a UI input not blocked at the UI layer. **Mitigation**: Grid returns `GRID_WRITE_REJECTED` regardless of caller; Tower System must surface the rejection to the player. The write gate is in the Grid — not a caller precondition.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| grid-system.md | Rule 1: 16×12 default grid; 5 cell types (PLACEABLE, PATH, SPAWN, GOAL, BLOCKED) | `_grid_cols = 16`, `_grid_rows = 12` defaults; `CellType` enum with all 5 values defined in Decision |
| grid-system.md | Rule 6: Two internal data structures (`_cell_types` + `_occupancy`) | Exact field names and types defined in Decision — Data Model section |
| grid-system.md | Rule 7: Write rejected during WAVE_ACTIVE, OUTCOME, DEFEAT | State machine + `GRID_WRITE_REJECTED = ERR_UNAVAILABLE` defined in Decision — State Machine section |
| grid-system.md | Rule 8: Direct read API (Autoload); EventBus exception documented | API Boundary section; deliberate exception to `direct_cross_system_node_reference` forbidden pattern documented |
| grid-system.md | EC-4: Returns copies, not references | Return-by-Copy Contract section; `.duplicate()` requirement; code review invariant documented |
| grid-system.md | Formula 1: `world_to_cell` uses `floor()` | World-to-Cell Coordinate Semantics section; floor vs truncation behaviour at negative boundaries explained |
| grid-system.md | EC-9: `get_walkable_cell_map()` excludes occupied PLACEABLE cells | Walkability Semantics section; absence-means-non-walkable contract defined |
| tower.md | Tower System is sole caller of write API | Write API section; convention enforcement via code review documented |
| pathfinding.md | `get_walkable_cell_map()`, `get_spawn_cells()`, `get_goal_cells()` needed by Pathfinding | All three in Read API; walkability contract (EC-9) documented |
| wave-manager.md | Wave Manager reads `get_spawn_cells()` at mission start | `get_spawn_cells()` in Read API |

**Technical Requirements covered**: TR-grid-001, TR-grid-002, TR-grid-003, TR-grid-004

## Performance Implications
- **CPU (read queries)**: All read functions are O(1) Dictionary lookups or O(N_occupied) scans. Worst-case O(N_occupied) = O(240) at 16×12 fully occupied grid — negligible. `world_to_cell()` is O(1) arithmetic — safe for per-frame per-monster calls.
- **CPU (write operations)**: `place_tower()` is O(footprint_area) = O(1–4). `remove_tower()` is O(N_occupied) linear scan — see Negative consequences.
- **Memory**: `_cell_types`: ~10–40 entries (only non-BLOCKED cells stored). `_occupancy`: 0–240 entries. At ~16 bytes per Dictionary entry (Vector2i + int): max ~4 KB. Negligible.
- **Load Time**: `Grid.initialize()` populates `_cell_types` from GridConfig — one-time O(N_cells_in_config) = O(192) operation. Sub-millisecond.
- **Network**: Not applicable (single-player only).

## Migration Plan
Greenfield project. No existing Grid code to migrate. Grid is the third Autoload to be implemented (after EventBus and SavePersistence). Pathfinding scaffold depends on Grid being ready — Grid must be stubbed before Pathfinding integration tests can run.

## Validation Criteria
- [ ] `get_cell_type(cell)` returns `BLOCKED` for cells not present in `GridConfig`.
- [ ] `place_tower()` returns `OK` for valid PLACEABLE unoccupied footprint; returns `GRID_WRITE_REJECTED` for occupied or non-PLACEABLE footprint.
- [ ] `place_tower()` returns `GRID_WRITE_REJECTED` during `ACTIVE_READONLY` state; no state is mutated.
- [ ] `remove_tower(id)` clears all cells mapped to `tower_id`; unrelated cells are unaffected.
- [ ] `get_all_occupied_cells()` returns a copy — removing a tower after the call does not mutate the previously returned array.
- [ ] `world_to_cell(Vector2(-0.1, 0.0))` returns `Vector2i(-1, 0)` — `floor()` handles negative positions correctly.
- [ ] `get_walkable_cell_map()` excludes occupied PLACEABLE cells; unoccupied PLACEABLE cells are included with value `true`.
- [ ] `Grid.initialize()` called after DEFEAT clears `_occupancy` fully.
- [ ] Grid in `UNINITIALIZED` state returns safe defaults (BLOCKED, false, empty arrays) for all read functions without throwing.

## Related Decisions
- ADR-0001 — EventBus architecture (Grid subscribes to `mission_phase_changed`; direct read API is a documented exception to the EventBus-only cross-system rule)
- ADR-0002 — Scene and Autoload structure (Grid as Autoload #3; boot order constraint)
- ADR-0004 — Pathfinding strategy (Pathfinding calls `get_walkable_cell_map()` to populate AStar2D instances; must refresh after each tower event)
- ADR-0008 — Tower placement gate (Tower System is the exclusive write caller; ADR-0008 documents WAVE_ACTIVE write-block from Tower's side)
- `design/gdd/grid-system.md` — canonical source for all rules, formulas, edge cases, and acceptance criteria
