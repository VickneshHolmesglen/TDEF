# Grid System

> **Status**: Approved (pass 1 — 2026-05-15; 1 blocker + 4 recommended resolved in-session)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-05-15
> **Implements Pillar**: Placement is the Puzzle

## Overview

The Grid System is the mission map's spatial data structure: a two-dimensional array of discrete cells that serves as the authoritative source of positional truth for all systems operating during a mission. It stores per-cell type data (placeable, blocked, path, spawn, goal) and per-cell occupancy (which tower instance, if any, occupies a given cell). No system holds a direct reference to scene nodes for spatial queries — all positional information flows through the Grid. The Pathfinding System reads walkability data from the Grid to build its navigation mesh. The Tower System reads and writes cell occupancy when towers are placed or removed. The Constellation System queries spatial cell adjacency to detect geometric tower patterns and award bonuses. The Tower Mastery System queries cell distance between the hero and occupied tower cells to determine proximity thresholds. The Grid is active exclusively during missions (SCOUT through OUTCOME states); the Sanctuary has no grid. Cells are addressed by `Vector2i` coordinates. The grid's dimensions, cell size, and cell types are configuration data set per-mission by the Mission Select System and exposed as read-only to all other systems. The Grid publishes state changes (tower placed, tower removed, cell type changed) to the EventBus; it does not call other systems directly.

## Player Fantasy

The Grid System has no player fantasy of its own — it is pure infrastructure. Players experience the Grid indirectly through every placement decision, constellation layout, and pathfinding outcome. The feeling of "this tower covers that chokepoint" and "if I complete this L-shape I trigger the constellation bonus" is the Grid's contribution to player experience, expressed entirely through the Tower System, Constellation System, and Mission HUD that read from it. Players never see or interact with the Grid directly; they see its consequences in the world.

## Detailed Design

### Core Rules

1. The Grid is a flat 2D array of cells with default dimensions **16 columns × 12 rows** (configurable per mission via `GridConfig` Resource). Column indices run left to right; row indices run top to bottom. The total default cell count is 192.

2. Each cell is addressed by `Vector2i(col, row)` where `(0, 0)` is the top-left cell and `(15, 11)` is the bottom-right cell (default dimensions).

3. World space conversion: `cell_to_world(cell) = Vector2(cell.x * cell_size, cell.y * cell_size) + Vector2(cell_size * 0.5, cell_size * 0.5)`. The `cell_size` parameter is set per mission and determines the physical scale of the grid in the game world. The inverse `world_to_cell(world_pos) = Vector2i(floor(world_pos.x / cell_size), floor(world_pos.y / cell_size))` converts a world position to its containing cell. Uses `floor()` not integer truncation — see Formula 1.

4. Each cell has exactly one `CellType`. Cells not explicitly listed in the mission's `GridConfig` are implicitly `BLOCKED`:
   - **`PLACEABLE`**: Open terrain. Towers and player-placed mission structures may be built here. Monster pathing does not route through PLACEABLE cells unless the Pathfinding System has no walkable alternative.
   - **`PATH`**: Designated monster walking lane. No player structures may be placed here. Hero may traverse freely in world space across PATH cells.
   - **`SPAWN`**: Monster entry point. No placement permitted. Defines the origin cells from which Wave Manager releases monsters.
   - **`GOAL`**: Protected zone. No placement permitted. A monster reaching any GOAL cell is counted as a breach; the monster is removed from the map and the breach counter increments.
   - **`BLOCKED`**: Impassable and non-buildable (walls, terrain obstacles, out-of-bounds). Neither monsters nor the hero can traverse BLOCKED cells.

5. **Tower footprint**: Towers occupy either a **1×1** or **2×2** cell footprint. Before placement is confirmed, all cells in the footprint must be `PLACEABLE` and unoccupied. A 2×2 tower occupying `(col, row)` as its top-left also occupies `(col+1, row)`, `(col, row+1)`, and `(col+1, row+1)`. All 4 cells are marked with the same tower entity ID in the occupancy map.

6. The Grid maintains two internal data structures:
   - **`_cell_types: Dictionary[Vector2i, CellType]`** — set at mission initialization from `GridConfig`; static for the duration of the mission (cell types do not change mid-mission).
   - **`_occupancy: Dictionary[Vector2i, int]`** — maps each occupied cell to the entity ID of the tower occupying it. Updated only during `SCOUT` and `INTERMISSION` states.

7. **Placement permission by mission state**:
   - During `SCOUT` and `INTERMISSION`: tower placement and removal are permitted.
   - During `WAVE_ACTIVE`, `OUTCOME`, and `DEFEAT`: all write operations are rejected. The Grid returns `GRID_WRITE_REJECTED` (project constant: `const GRID_WRITE_REJECTED = ERR_UNAVAILABLE` from Godot 4's `Error` enum) without modifying state or emitting events.

8. **The Grid exposes a direct read API.** All spatial queries from other systems (Tower, Constellation, Pathfinding, Wave Manager, Tower Mastery) call Grid functions directly — Grid is an Autoload. Read queries do not go through the EventBus. This is a deliberate exception to the general no-direct-reference rule: the Grid is a shared data store, not a behavioral system, and routing frame-by-frame spatial queries through EventBus would consume an unacceptable share of the frame budget.

9. **The Grid does not emit EventBus events directly.** State change notifications (tower placed, tower removed) are the responsibility of the Tower System, which includes cell coordinate data in its `tower_placed` and `tower_removed` event payloads. Systems that need to react to placement changes (e.g., Pathfinding rebuilding navmesh, Constellation rechecking patterns) subscribe to Tower System events, then call Grid read functions for updated state.

10. **Grid initialization and teardown**: At mission start, the Grid receives a `GridConfig` Resource from Mission Select System. It sets `_cell_types` from the config and clears `_occupancy` entirely. At mission end (any outcome), `_occupancy` is discarded. Grid state is not persisted to Save & Persistence — the mission map is stateless between mission attempts. A mission restart (DEFEAT → SCOUT) reinitializes the Grid from the same `GridConfig`.

---

### States and Transitions

| Grid State | Active During | Write Operations | Description |
|---|---|---|---|
| `UNINITIALIZED` | Between missions | Rejected | No GridConfig loaded; all queries return default/empty |
| `ACTIVE_WRITABLE` | `SCOUT`, `INTERMISSION` | Permitted | Cell types set; occupancy can be modified |
| `ACTIVE_READONLY` | `WAVE_ACTIVE`, `OUTCOME`, `DEFEAT` | Rejected | Cell types and occupancy readable; writes return `GRID_WRITE_REJECTED` |

The Grid transitions between states in response to `mission_phase_changed` events received via EventBus. It does not drive phase transitions itself.

---

### Interactions with Other Systems

| System | Data Flow | Data | Mechanism |
|---|---|---|---|
| Mission Select System | → Grid | `GridConfig` Resource (dimensions, cell_size, `_cell_types` map) | Direct initialization call at mission load |
| Tower System | → Grid | `place_tower(tower_id, top_left, size)` | Direct write API; Tower System validates intent, then calls Grid to commit |
| Tower System | → Grid | `remove_tower(tower_id)` | Direct write API; Grid clears all cells for that tower_id |
| Constellation System | Grid → | Occupied cell positions, adjacency queries | Direct read API (`get_all_occupied_cells()`, `get_occupied_cells_in_radius()`) |
| Pathfinding System | Grid → | Full walkability map | Direct read API (`get_walkable_cell_map()`); called when navmesh rebuild is triggered by Tower System events |
| Wave Manager | Grid → | All SPAWN cell positions | Direct read API (`get_spawn_cells()`) at mission start |
| Tower Mastery System | Grid → | Occupied cells within Chebyshev distance of hero cell | Direct read API (`get_occupied_cells_in_radius(world_to_cell(hero_pos), radius)`) |
| Monster System | Grid → | Tower IDs within BOSS attack range; cell type validation at spawn; world↔cell conversion per frame | Direct read API (`get_towers_in_range()`, `get_cell_type()`, `cell_to_world()`, `world_to_cell()`) |
| EventBus | Grid ← | `mission_phase_changed` | Grid subscribes to transition between ACTIVE_WRITABLE and ACTIVE_READONLY |

**Read API (public — all systems may call directly):**

| Function | Returns | Description |
|---|---|---|
| `is_placeable(cell: Vector2i) -> bool` | bool | True if cell is PLACEABLE and unoccupied (1×1 placement check) |
| `is_footprint_placeable(top_left: Vector2i, size: Vector2i) -> bool` | bool | True if all cells in footprint are PLACEABLE and unoccupied |
| `get_cell_type(cell: Vector2i) -> CellType` | CellType | Returns the cell's type (BLOCKED if not in config) |
| `get_occupant(cell: Vector2i) -> int` | int | Tower entity ID, or `-1` if unoccupied |
| `get_all_occupied_cells() -> Array[Vector2i]` | Array | All cells with a tower occupant |
| `get_occupied_cells_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]` | Array | Occupied cells within Chebyshev distance ≤ radius |
| `get_towers_in_range(center: Vector2i, radius: int) -> Array[int]` | Array[int] | Tower entity IDs for all occupied cells within Chebyshev distance ≤ radius. Convenience wrapper: calls `get_occupied_cells_in_radius()` then `get_occupant()` on each. Returns empty array if no towers in range. Used by Monster System BOSS attack targeting. |
| `get_spawn_cells() -> Array[Vector2i]` | Array | All SPAWN cells |
| `get_goal_cells() -> Array[Vector2i]` | Array | All GOAL cells |
| `get_walkable_cell_map() -> Dictionary[Vector2i, bool]` | Dictionary | True for cells monsters can traverse (PATH, SPAWN, GOAL; PLACEABLE only if unoccupied). **BLOCKED cells and occupied PLACEABLE cells are excluded from the returned dictionary** — keys are present only for walkable cells. Callers treat any absent cell as non-walkable. Used by Pathfinding to populate AStar2D graph nodes. |
| `world_to_cell(world_pos: Vector2) -> Vector2i` | Vector2i | World position → grid cell |
| `cell_to_world(cell: Vector2i) -> Vector2` | Vector2 | Grid cell center → world position |
| `is_in_bounds(cell: Vector2i) -> bool` | bool | True if cell is within grid dimensions |

**Write API (called only by Tower System):**

| Function | Returns | Description |
|---|---|---|
| `place_tower(tower_id: int, top_left: Vector2i, size: Vector2i) -> Error` | Error | Marks cells occupied; returns `OK` or `ERR_UNAVAILABLE` (used as `GRID_WRITE_REJECTED` — define project constant `const GRID_WRITE_REJECTED = ERR_UNAVAILABLE`) |
| `remove_tower(tower_id: int) -> void` | void | Clears all cells mapped to this tower_id. Implementation: linear scan of `_occupancy` entries to find matching cells — O(N_occupied), negligible at MVP scale (≤240 occupied cells). |

## Formulas

### Formula 1: World-to-Cell Conversion

```
cell = Vector2i( floor(world_pos.x / cell_size), floor(world_pos.y / cell_size) )
```

| Variable | Type | Description |
|---|---|---|
| `world_pos` | Vector2 | World space position (pixels or units from origin) |
| `cell_size` | float | Size of one cell in world units (tuning knob; set per mission) |
| `cell` | Vector2i | Output: grid column and row |

**Notes**: Uses `floor()` not integer truncation — negative world positions must round toward negative infinity to avoid off-by-one at the origin boundary. If `world_pos` is outside grid bounds, `is_in_bounds(cell)` will return false; callers must check before using the result.

---

### Formula 2: Cell-to-World Conversion (Cell Center)

```
world_pos = Vector2( cell.x * cell_size + cell_size * 0.5,
                     cell.y * cell_size + cell_size * 0.5 )
```

| Variable | Type | Description |
|---|---|---|
| `cell` | Vector2i | Grid column and row |
| `cell_size` | float | Size of one cell in world units |
| `world_pos` | Vector2 | Output: world position at the center of the cell |

---

### Formula 3: Chebyshev Distance (Grid Proximity)

Used by `get_occupied_cells_in_radius` to determine which occupied cells fall within a given radius. Chebyshev distance treats diagonal adjacency as equal to cardinal adjacency — distance 1 means all 8 neighbours are within range.

```
chebyshev(a, b) = max( abs(a.x - b.x), abs(a.y - b.y) )
```

| Variable | Type | Description |
|---|---|---|
| `a`, `b` | Vector2i | Two grid cells |
| Output | int | Chebyshev distance between cells (0 = same cell) |

**Why Chebyshev, not Euclidean**: Tower Mastery proximity checks run every physics frame for each occupied cell within range. Chebyshev distance is O(1) with no square root — significantly cheaper than Euclidean at scale. Constellation pattern detection uses adjacency (distance = 1) which is a special case of Chebyshev. If Euclidean feel is required for Tower Mastery (e.g., "radius feels circular"), a Euclidean check can be applied as a secondary filter after Chebyshev culling.

---

### Formula 4: Footprint Validation Cost

```
validation_checks = footprint_width * footprint_height
```

| Variable | Type | Description |
|---|---|---|
| `footprint_width` | int | Tower width in cells (1 or 2) |
| `footprint_height` | int | Tower height in cells (1 or 2) |
| `validation_checks` | int | Number of Dictionary lookups required |

**Output range**: 1 (1×1 tower) to 4 (2×2 tower). Each lookup is O(1). Placement validation is therefore O(1) to O(4) — negligible and not a frame budget concern.

## Edge Cases

**EC-1: Out-of-bounds world position passed to `world_to_cell`**
> A hero or monster moves to the edge of the map and their world position falls outside the grid's extent. `world_to_cell` returns a `Vector2i` that fails `is_in_bounds()`. Callers must check `is_in_bounds()` before using the result — the Grid does not clamp the return value. Tower Mastery System must guard against hero positions that produce out-of-bounds cells when calling `get_occupied_cells_in_radius`.

**EC-2: 2×2 tower placed partially outside grid bounds**
> A player attempts to place a 2×2 tower at column 15 (rightmost column in default 16-wide grid), where cells `(16, row)` do not exist. `is_footprint_placeable` returns false for any footprint that includes out-of-bounds cells, because `get_cell_type` returns `BLOCKED` for cells not in `_cell_types`. No special boundary check is needed — the out-of-bounds cells implicitly fail validation.

**EC-3: Placement attempted during WAVE_ACTIVE (write during locked state)**
> The Tower System attempts to call `place_tower` during WAVE_ACTIVE (e.g., due to a race condition or UI input not properly blocked). The Grid returns `GRID_WRITE_REJECTED` without modifying state. The Tower System is responsible for surfacing the rejection to the player (e.g., greying out placement UI). The Grid does not emit any event on rejection.

**EC-4: Tower removed while another system is mid-iteration over `get_all_occupied_cells`**
> A constellation pattern check iterates over the occupied cell array while a tower removal is processed. Since GDScript Arrays are value-typed (returned as copies from `get_all_occupied_cells()`), the returned array is a snapshot at the time of the call. The mid-iteration removal only affects `_occupancy` in the Grid; it does not mutate the caller's snapshot. Callers receive consistent data for the duration of their iteration. **Note**: this guarantee applies only because the read API returns copies, not references. Implementors must never return a direct reference to `_occupancy`.

**EC-5: Duplicate tower entity IDs in `_occupancy`**
> The Grid does not validate entity ID uniqueness. `is_footprint_placeable` prevents placing at an already-occupied *cell*, but does not prevent the Tower System from calling `place_tower` with the same `tower_id` at a different, unoccupied cell. If that occurs, `_occupancy` would map multiple cells to the same ID, and `remove_tower(id)` would clear all of them on scan — which is technically correct but indicates a Tower System bug. The Tower System is solely responsible for issuing unique entity IDs. The Grid relies on that contract.

**EC-6: Mission restart reinitializes Grid mid-session**
> On DEFEAT → SCOUT transition, the Grid clears `_occupancy` entirely and re-reads `_cell_types` from the same `GridConfig`. Any system that cached Grid state across the defeat must reinitialize. Systems that call read functions fresh each time (e.g., Wave Manager calling `get_spawn_cells()` at each wave start) are unaffected. Systems that cache grid queries (e.g., Pathfinding System storing walkable cell maps) must subscribe to `mission_phase_changed` and invalidate caches on `SCOUT` entry.

**EC-7: Grid queried before mission initialization**
> A system calls a Grid read function before Mission Select System has passed a `GridConfig` (Grid state = `UNINITIALIZED`). All read functions return safe defaults: `get_cell_type` returns `BLOCKED`, `is_placeable` returns false, `get_all_occupied_cells` returns an empty array, `get_spawn_cells` returns an empty array. No assert or error is thrown — safe defaults prevent crashes during engine startup order edge cases.

**EC-8: Two SPAWN cells in the same column with different rows**
> Wave Manager calls `get_spawn_cells()` and receives multiple spawn cells. This is intentional — maps may have multiple entry points. Wave Manager is responsible for distributing monster spawns across all SPAWN cells as defined in its own GDD. The Grid makes no assumption about how spawn cells are used.

**EC-9: Pathfinding System walkability vs. PLACEABLE cell occupancy**
> An occupied PLACEABLE cell (has a tower on it) must not be walkable for monsters. The `get_walkable_cell_map()` function returns `false` for any PLACEABLE cell where `get_occupant(cell) != -1`. This means the walkability map changes whenever towers are placed or removed. The Pathfinding System must call `get_walkable_cell_map()` fresh after each `tower_placed` or `tower_removed` event, not cache a stale version.

**EC-10: Simultaneous placement at the same cell from two input sources**
> Not possible within single-threaded GDScript — only one call can execute at a time. No mutex or lock needed. Simultaneous input events (e.g., two gamepad controllers both trying to place) are serialized by the input system before reaching the Grid. The second call will find the cell occupied and receive `GRID_WRITE_REJECTED`.

## Dependencies

### Upstream Dependencies (systems this GDD depends on)

| System | Dependency Type | What Grid needs from it |
|---|---|---|
| **EventBus System** | Infrastructure | Grid subscribes to `mission_phase_changed` to transition between ACTIVE_WRITABLE and ACTIVE_READONLY states. EventBus must be initialized before Grid (Autoload order enforced). |
| **Mission Select System** | Data source | Provides `GridConfig` Resource at mission start. Grid has no default map — it cannot initialize without a `GridConfig`. If Mission Select is not yet designed when Grid is implemented, a hardcoded test `GridConfig` must be used as a stand-in. |

### Downstream Dependents (systems that depend on this GDD)

| System | What it needs from Grid | Constraint on Grid |
|---|---|---|
| **Tower System** | Write API (`place_tower`, `remove_tower`), read API (`is_placeable`, `is_footprint_placeable`) | Grid write API must be called by Tower System only; grid state changes must be confirmed before Tower System emits `tower_placed` event |
| **Constellation System** | Read API (`get_all_occupied_cells`, `get_occupied_cells_in_radius`) | Grid must return Array copies (not references) so Constellation can iterate safely |
| **Pathfinding System** | Read API (`get_walkable_cell_map`, `get_spawn_cells`, `get_goal_cells`) | Walkability map must account for occupied PLACEABLE cells as non-walkable |
| **Wave Manager** | Read API (`get_spawn_cells`) | Must return all SPAWN cells; empty array is a map configuration error |
| **Tower Mastery System** | Read API (`world_to_cell`, `get_occupied_cells_in_radius`) | Chebyshev distance formula must be consistent with Tower Mastery GDD's proximity radius definition |
| **Monster System** | Read API (indirectly via Pathfinding System) | Monster positions are world-space; Grid is not queried per-monster per-frame — Pathfinding System mediates |

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Effect |
|---|---|---|---|
| `grid_cols` | 16 | 10–24 | Map width in cells. Lower = tighter, higher-pressure placement decisions. Higher = more room for creative layouts and multi-path constellation builds. |
| `grid_rows` | 12 | 8–18 | Map height in cells. Pairs with `grid_cols` — together they define total buildable area. |
| `cell_size` | (set per mission) | 48–128 (world units) | Physical size of each cell in the game world. Affects hero movement feel relative to the grid. Smaller cells = hero feels larger; larger cells = more room to navigate within a lane. |
| `max_placeable_cells` | (derived from map layout) | — | Number of PLACEABLE cells in a mission. This is a map-design knob controlled by the `GridConfig` layout, not a code constant. |

**Notes**:
- `grid_cols` and `grid_rows` are set by Mission Select System via `GridConfig`. Different missions may have different grid sizes.
- `cell_size` is the primary lever for visual scale without changing logical grid size. It must remain constant within a mission.
- The default 16×12 (192 cells) is calibrated for the 15–25 minute mission target. Larger maps will extend mission length as players spend more time repositioning.

## Visual/Audio Requirements

N/A — the Grid System is a pure data structure with no visual or audio output of its own. The visual grid overlay displayed to players during the Scout and Intermission phases (cell highlighting, placement preview, constellation pattern indicators) is owned by the Mission HUD and Tower System, which read from the Grid's read API to determine what to display.

## UI Requirements

N/A — the Grid System does not own any UI. The placement cursor, cell validity highlighting, and tower footprint preview are Tower System UI concerns. The Mission HUD may display a minimap derived from grid data, but that is a Mission HUD requirement, not a Grid requirement.

## Acceptance Criteria

**AC-1 — Cell type integrity**
> **Given** a `GridConfig` with N cells explicitly typed, **when** the Grid is initialized, **then** `get_cell_type(cell)` returns the correct type for all N configured cells and returns `BLOCKED` for any cell not in the config.

**AC-2 — 1×1 tower placement succeeds on PLACEABLE unoccupied cell**
> **Given** the Grid is in `ACTIVE_WRITABLE` state and cell `(3, 4)` is `PLACEABLE` and unoccupied, **when** `place_tower(id=42, top_left=(3,4), size=(1,1))` is called, **then** `get_occupant((3,4))` returns `42`, `is_placeable((3,4))` returns `false`, and the function returns `OK`.

**AC-3 — 2×2 tower placement occupies all 4 cells**
> **Given** cells `(2,2)`, `(3,2)`, `(2,3)`, `(3,3)` are all `PLACEABLE` and unoccupied, **when** `place_tower(id=7, top_left=(2,2), size=(2,2))` is called, **then** `get_occupant` returns `7` for all 4 cells.

**AC-4 — Placement rejected on non-PLACEABLE cell**
> **Given** cell `(5,5)` is `PATH`, **when** `place_tower(id=1, top_left=(5,5), size=(1,1))` is called, **then** the function returns `GRID_WRITE_REJECTED` and `_occupancy` is unchanged.

**AC-5 — Placement rejected during WAVE_ACTIVE**
> **Given** the Grid is in `ACTIVE_READONLY` state (WAVE_ACTIVE), **when** `place_tower` is called with any valid arguments, **then** the function returns `GRID_WRITE_REJECTED` and state is unchanged.

**AC-6 — Tower removal frees all occupied cells**
> **Given** a 2×2 tower with id=7 occupies cells `(2,2)`, `(3,2)`, `(2,3)`, `(3,3)`, **when** `remove_tower(7)` is called, **then** all 4 cells are unoccupied (`get_occupant` returns `-1`) and all 4 return `true` from `is_placeable`.

**AC-7 — World-to-cell conversion is correct at cell boundaries**
> **Given** `cell_size = 64`, **when** `world_to_cell(Vector2(64.0, 0.0))` is called, **then** it returns `Vector2i(1, 0)` (not `Vector2i(0, 0)` — the boundary belongs to the next cell).

**AC-8 — Walkability map correctly excludes occupied PLACEABLE cells**
> **Given** cell `(3, 4)` is `PLACEABLE` and occupied by tower id=5, **when** `get_walkable_cell_map()` is called, **then** `(3,4)` maps to `false` in the returned dictionary.

**AC-9 — `get_all_occupied_cells` returns a copy, not a reference**
> **Given** `get_all_occupied_cells()` returns array A, **when** `remove_tower` is called on any tower, **then** array A is unchanged (still contains the removed tower's cells).

**AC-10 — Safe defaults when UNINITIALIZED**
> **Given** the Grid has not been initialized with a `GridConfig`, **when** any read function is called, **then** it returns a safe default (BLOCKED, false, empty array) without throwing an error.

**AC-11 — `get_occupied_cells_in_radius` uses Chebyshev distance**
> **Given** tower at `(5,5)` and tower at `(7,7)`, **when** `get_occupied_cells_in_radius(center=(5,5), radius=2)` is called, **then** `(7,7)` is included (Chebyshev distance = max(2,2) = 2 ≤ radius). **When** radius=1, `(7,7)` is excluded (Chebyshev = 2 > 1).

**AC-12 — Mission restart clears occupancy**
> **Given** a tower occupies cell `(3,4)` during a mission, **when** a `mission_phase_changed` event signals `SCOUT` after a DEFEAT, **then** `get_occupant((3,4))` returns `-1` (occupancy fully cleared).

## Open Questions

**OQ-1: Does the Tower Mastery System use Chebyshev or Euclidean distance for its proximity threshold?**
> This GDD provides `get_occupied_cells_in_radius` using Chebyshev (Formula 3). If Tower Mastery GDD decides proximity should feel circular (Euclidean), the Grid API will need an additional `get_occupied_cells_in_euclidean_radius(center, radius_world_units)` function. Decision deferred to Tower Mastery GDD.

**OQ-2: Are there mission map cell types beyond PLACEABLE, PATH, SPAWN, GOAL, BLOCKED?**
> The current 5-type model covers known requirements. Future mission designs may require additional types (e.g., `HERO_ONLY`, `ELEVATED`). Any new cell type is a Grid GDD revision and a breaking change for Constellation, Pathfinding, and Wave Manager GDDs.

**OQ-3: Can maps have multiple GOAL cells (multi-lane exit)?**
> The GDD supports this by design. Wave Manager and breach tracking must be designed to handle multiple GOAL cells. This is a Wave Manager GDD responsibility to confirm.

**OQ-4: Is `cell_size` a constant per project or truly per-mission?**
> Current spec allows per-mission `cell_size`. If all missions use the same value, it becomes a project constant suitable for registration in `design/registry/entities.yaml`. Defer to Mission Select GDD.

**OQ-5: How does the Constellation System communicate pattern detection results back through EventBus?**
> The Grid exposes the spatial query API; Constellation performs the geometry. Constellation must emit its activation event via EventBus including the triggering cell and tower IDs. This is a Constellation System GDD responsibility — no Grid changes required.
