# S2-03 — Grid System Autoload Implementation

**Story ID**: S2-03
**Epic**: Foundation
**Layer**: Foundation
**Type**: Logic
**Owner**: godot-gdscript-specialist
**Sprint**: 2
**Estimate**: 1.5 days
**Status**: Complete
**Manifest Version**: 2026-05-16

## TR Coverage

| TR-ID | Requirement |
|-------|-------------|
| TR-grid-001 | 16×12 default grid; 5 cell types (PLACEABLE, SPAWN, GOAL, PATH, BLOCKED) |
| TR-grid-002 | Direct read API (Autoload); write restricted to Tower System |
| TR-grid-003 | world_to_cell uses floor() |
| TR-grid-004 | Returns copies, not references |

## ADR Governing Implementation

`docs/architecture/adr-0005-grid-system-data-model.md` (Accepted 2026-05-16)

## Dependencies

- S2-01 EventBus Autoload — Complete (2026-05-25)

## Files to Create / Modify

- `src/foundation/grid/grid.gd` — create (Grid Autoload)

## Test Evidence

- `tests/unit/grid/grid_placement_test.gd` — placement, occupancy, write-gate
- `tests/unit/grid/grid_queries_test.gd` — spatial queries, walkability, coordinate conversion

## Acceptance Criteria

- [ ] `get_cell_type(cell)` returns the configured type for all cells in GridConfig and `BLOCKED` for unconfigured cells (GDD AC-1, TR-grid-001)
- [ ] `place_tower(id=42, top_left=(3,4), size=(1,1))` on a PLACEABLE unoccupied cell returns `OK`, sets `get_occupant((3,4))==42`, `is_placeable((3,4))==false` (GDD AC-2)
- [ ] `place_tower(id=7, top_left=(2,2), size=(2,2))` sets `get_occupant` to 7 for all 4 cells `(2,2),(3,2),(2,3),(3,3)` (GDD AC-3)
- [ ] `place_tower` on a non-PLACEABLE cell (e.g. PATH) returns `GRID_WRITE_REJECTED`; `_occupancy` unchanged (GDD AC-4, TR-grid-002)
- [ ] `place_tower` during `ACTIVE_READONLY` state returns `GRID_WRITE_REJECTED`; state unchanged (GDD AC-5, TR-grid-002)
- [ ] `remove_tower(7)` on a 2×2 tower clears all 4 cells: `get_occupant` returns -1, `is_placeable` returns true for all 4 (GDD AC-6)
- [ ] `world_to_cell(Vector2(64.0, 0.0))` returns `Vector2i(1,0)` with `cell_size=64`; `world_to_cell(Vector2(-0.1, 0.0))` returns `Vector2i(-1,0)` (GDD AC-7, TR-grid-003)
- [ ] `get_walkable_cell_map()` excludes occupied PLACEABLE cells (absent key = non-walkable) (GDD AC-8)
- [ ] Array returned by `get_all_occupied_cells()` before a `remove_tower` call is unaffected by the removal (copy contract) (GDD AC-9, TR-grid-004)
- [ ] All read functions return safe defaults (BLOCKED, false, empty array) when Grid is `UNINITIALIZED`; no error thrown (GDD AC-10)
- [ ] `get_occupied_cells_in_radius(center=(5,5), radius=2)` includes `(7,7)` (Chebyshev=2); radius=1 excludes it (GDD AC-11)
- [ ] After `mission_phase_changed` signals SCOUT following DEFEAT, `get_occupant((3,4))` returns -1 (occupancy cleared) (GDD AC-12)
- [ ] Subscribes to `EventBus.mission_phase_changed` in `_ready()`; disconnects in `_exit_tree()` (ADR-0001 rule)
- [ ] Unit tests: ≥12 tests pass across `tests/unit/grid/`

## Implementation Notes (from ADR-0005)

### Data Structures

```gdscript
class_name Grid
extends Node

enum CellType { PLACEABLE, PATH, SPAWN, GOAL, BLOCKED }
enum GridState { UNINITIALIZED, ACTIVE_WRITABLE, ACTIVE_READONLY }

# Dictionary[Vector2i, CellType] — verify typed dict compiles in Godot 4.6.2;
# fallback: untyped Dictionary with _to_cell_type() helper at read boundaries (ADR-0005 risk)
var _cell_types: Dictionary = {}
var _occupancy: Dictionary = {}    # Dictionary[Vector2i, int]; -1 = unoccupied (key absent)
var _grid_cols: int = 16
var _grid_rows: int = 12
var _cell_size: float = 64.0
var _state: GridState = GridState.UNINITIALIZED

const GRID_WRITE_REJECTED: int = ERR_UNAVAILABLE
```

### State Machine

```
UNINITIALIZED
  ↓ initialize(config) called
ACTIVE_WRITABLE  ←─────────────────────────┐
  ↓ mission_phase_changed(WAVE_ACTIVE)      │
ACTIVE_READONLY                             │
  ↓ mission_phase_changed(INTERMISSION) ───→┘
  ↓ mission_phase_changed(DEFEAT or OUTCOME)
UNINITIALIZED (occupancy cleared)
```

### world_to_cell (must use floor, not int truncation)

```gdscript
func world_to_cell(world_pos: Vector2) -> Vector2i:
    return Vector2i(
        int(floor(world_pos.x / _cell_size)),
        int(floor(world_pos.y / _cell_size))
    )
```

### Return-by-Copy Contract

All functions returning Array or Dictionary must return new copies:
- Array results: `.duplicate()` or build fresh from Dictionary key iteration
- Walkability dict: `.duplicate()` — never return `_cell_types` or `_occupancy` directly

### Write-gate pattern (all write functions check _state first)

```gdscript
func place_tower(tower_id: int, top_left: Vector2i, size: Vector2i) -> Error:
    if _state != GridState.ACTIVE_WRITABLE:
        return GRID_WRITE_REJECTED
    # ... validate footprint then write to _occupancy
```

### Walkability contract

`get_walkable_cell_map()` — key present = walkable (PATH, SPAWN, GOAL, or unoccupied PLACEABLE).
BLOCKED cells and occupied PLACEABLE cells are absent (absence = non-walkable).

### EventBus subscription

```gdscript
func _ready() -> void:
    EventBus.mission_phase_changed.connect(_on_mission_phase_changed)

func _exit_tree() -> void:
    EventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)
```

## Completion Notes
**Completed**: 2026-06-29
**Criteria**: 14/14 passing
**Deviations**: ADVISORY — `src/foundation/grid/grid_config.gd` created (out-of-scope per story), required by code review for ADR-0005 compliance (`initialize()` contract). Valid early resolution of a deferred item.
**Test Evidence**: Logic — `tests/unit/grid/grid_placement_test.gd` (26 tests) + `tests/unit/grid/grid_queries_test.gd` (13 tests) = 39 tests total
**Code Review**: Complete — APPROVED (2026-06-29)

## Out of Scope

- `GridConfig` Resource class — not created here; tests use a plain Dictionary stub
- Pathfinding integration — S2-04
- Visual grid overlay — Mission HUD (post-MVP)
- `would_block_all_paths()` — Pathfinding System owns this
- EventBus registration in project.godot — tracked separately (pending both EventBus + SavePersistence)
