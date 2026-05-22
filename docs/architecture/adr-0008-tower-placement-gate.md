# ADR-0008: Tower Placement Gate — Phase Guard, Path Integrity, and Component Deep-Copy Policy

## Status
Accepted

## Date
2026-05-19

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / Resource Management |
| **Knowledge Risk** | MEDIUM — `duplicate_deep()` added in Godot 4.5 (post-LLM-cutoff) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | `Resource.duplicate_deep()` — added Godot 4.5; replaces manual recursive `Resource.duplicate()` chains. Confirmed available in 4.6.2. |
| **Verification Required** | Confirm `duplicate_deep()` correctly deep-copies Resources nested inside typed `Array[Resource]` and `Dictionary` fields before first Tower System story ships. Raw `RefCounted` or `Node` references inside a component will NOT be deep-copied — see Risks. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus — `tower_placed`, `tower_removed` events must be declared); ADR-0004 (Pathfinding — `would_block_all_paths()` interface); ADR-0005 (Grid — `place_tower()`, `is_footprint_placeable()` write API) — all Accepted |
| **Enables** | Tower System implementation stories; Vertical Slice tower placement interaction |
| **Blocks** | None — this ADR unblocks the Tower System Epic |
| **Ordering Note** | All three dependency ADRs are Accepted. This ADR may be implemented immediately. |

## Context

### Problem Statement
The Tower System must define two coupled policies before implementation can begin:
(1) Under what conditions is tower placement or removal allowed, and what does the
system return when it is not? (2) When a tower is placed, how are its component
Resources (Foundation, Weapon, Focus, Power) isolated from the player's inventory
data so that mission-time mutations do not corrupt the inventory state?

Without a defined placement gate, the UI layer cannot know what feedback to show.
Without component isolation, mission-time mutations (e.g., `damaged: true` on tower
destruction) would silently write back to inventory Resources.

### Constraints
- Tower GDD Rule 8: mid-wave placement is explicitly forbidden — no queueing
- Tower GDD Rule 9: 3 gate checks must run in a specific order; path check only on confirmation
- Tower GDD Rule 13: removal is also blocked during WAVE_ACTIVE
- ADR-0004: `would_block_all_paths()` must not be called on hover (registered forbidden pattern `would_block_all_paths_on_hover`)
- ADR-0005: `Grid.place_tower()` is the authoritative write call — Tower System is sole caller (registered forbidden pattern `grid_write_outside_tower_system`)
- Resource isolation must not affect the sell refund — the refund formula uses original placement cost, not the mission instance

### Requirements
- `place_tower()` must be authoritative — the HUD reacts to its return value, not pre-check independently
- Path integrity check runs only on placement confirmation, never on hover
- Component Resources must be fully independent per placed tower instance
- Mission-time mutations to component state must not affect inventory Resources
- All nested component data must be `Resource` subclasses for `duplicate_deep()` guarantee to hold

## Decision

### Placement Gate — 4 sequential checks

`TowerSystem.place_tower(tower_id: String, top_left: Vector2i) -> bool` runs
four ordered checks. Each check short-circuits on failure — no subsequent check
is run. Only when all four pass does the system commit placement.

```
Gate 1 — Phase check
  if _current_phase == Phase.WAVE_ACTIVE: return false
  (no resource query, no Grid call, no Pathfinding call)

Gate 2 — Resource check
  if not ResourceSystem.can_afford(placement_cost(tower_id)): return false
  (no Grid call, no Pathfinding call)

Gate 3 — Grid footprint check
  if not Grid.is_footprint_placeable(top_left, tower_data.footprint): return false
  (no Pathfinding call)

Gate 4 — Path integrity check  [confirmation only — never on hover]
  var cells := Grid.get_footprint_cells(top_left, tower_data.footprint)
  if PathfindingSystem.would_block_all_paths(cells): return false

Commit
  var err := Grid.place_tower(tower_id, top_left, tower_data.footprint)
  if err != OK: return false
  _activate_tower_instance(tower_id, top_left)   # duplicate_deep() happens here
  EventBus.tower_placed.emit(tower_id, top_left, tower_data.archetype)
  return true
```

`TowerSystem.remove_tower(tower_id: String) -> bool` runs a single gate:

```
Gate 1 — Phase check
  if _current_phase == Phase.WAVE_ACTIVE: return false

Commit
  Grid.remove_tower(tower_id)
  _deactivate_tower_instance(tower_id)   # mission-instance Resources freed here
  EventBus.tower_removed.emit(tower_id, archetype)
  return true
```

### HUD Preview API — hover feedback without Gate 4

```
TowerSystem.get_placement_preview(tower_id: String, top_left: Vector2i) -> PlacementPreview
  Runs Gate 1 + Gate 2 + Gate 3 only.
  Returns: PlacementPreview { valid: bool, reason: PlacementBlockReason }
  Gate 4 (path check) is NEVER called from this function.
```

`PlacementBlockReason` enum: `NONE`, `WAVE_ACTIVE`, `INSUFFICIENT_RESOURCES`,
`FOOTPRINT_BLOCKED`, `PATH_BLOCKED`.

`PATH_BLOCKED` is only set by the `place_tower()` commit path, never by
`get_placement_preview()`. The HUD renders a provisional valid state on hover
and updates to blocked only after the player confirms placement and the result
returns false with `PATH_BLOCKED`.

### Component Deep-Copy Policy — duplicate_deep() at placement commit

When `place_tower()` commits (all 4 gates pass), `_activate_tower_instance()`
calls `Resource.duplicate_deep()` on each of the 4 component Resources to create
independent mission-instance copies:

```gdscript
var mission_foundation: FoundationComponent = inventory_foundation.duplicate_deep()
var mission_weapon:     WeaponComponent     = inventory_weapon.duplicate_deep()
var mission_focus:      FocusComponent      = inventory_focus.duplicate_deep()
var mission_power:      PowerComponent      = inventory_power.duplicate_deep()
```

These copies are stored in a `TowerMissionState` Resource keyed by `tower_id`.
All mid-mission mutations (e.g., `damaged := true` on tower destruction, HP
tracking, perk activation state) apply to the mission-instance copies only.
Inventory Resources are never written to during a mission.

On `remove_tower()`, `_deactivate_tower_instance()` releases the `TowerMissionState`
reference — the Resource is `RefCounted` and is collected automatically. No
manual `free()` call is used or needed.

**`duplicate_deep()` contract requirement**: All data nested inside component
Resources (e.g., `TowerPerkData` inside `FoundationComponent`) must be `Resource`
subclasses. `duplicate_deep()` only deep-copies `Resource` subclasses — raw
`RefCounted` or `Node` references nested in a component will be shared between the
mission instance and the inventory item, not copied. This is a schema enforcement
rule: component designers must never nest non-Resource objects inside component slots.

**`TowerMissionState` must never be assigned to an `@export` property on any
Autoload or persistent node.** The Godot editor holds strong references to
exported Resources — an accidental `@export` assignment would prevent the mission
instance from being collected after tower removal.

### Architecture Diagram

```
Player inventory (persistent — never mutated during mission)
  └── TowerBlueprintData
        ├── FoundationComponent  ─┐
        ├── WeaponComponent       │  duplicate_deep() ×4 at placement commit
        ├── FocusComponent        │
        └── PowerComponent       ─┘
                                   ↓
             TowerMissionState (RefCounted — freed on removal or mission end)
               ├── foundation: FoundationComponent  ← mission copy
               ├── weapon:     WeaponComponent      ← mission copy
               ├── focus:      FocusComponent       ← mission copy
               └── power:      PowerComponent       ← mission copy

Grid.place_tower()   ← sole write path           (ADR-0005)
EventBus.tower_placed ← sole event emission path  (ADR-0001)
```

### Key Interfaces

```gdscript
# Tower System public API
func place_tower(tower_id: String, top_left: Vector2i) -> bool
func remove_tower(tower_id: String) -> bool
func get_placement_preview(tower_id: String, top_left: Vector2i) -> PlacementPreview

# Preview result
class PlacementPreview:
    var valid: bool
    var reason: PlacementBlockReason

enum PlacementBlockReason {
    NONE,
    WAVE_ACTIVE,
    INSUFFICIENT_RESOURCES,
    FOOTPRINT_BLOCKED,
    PATH_BLOCKED       # set only by place_tower(), never by get_placement_preview()
}
```

## Alternatives Considered

### Alternative A: Queue placement requests during WAVE_ACTIVE
- **Description**: Accept placement input during waves; execute at next INTERMISSION
- **Pros**: Player can pre-queue placements during hectic wave moments
- **Cons**: Tower GDD Rule 8 explicitly forbids this; introduces async state complexity
- **Rejection Reason**: Explicitly ruled out by GDD Rule 8 with a cross-doc conflict note

### Alternative B: UI-only gate — no system-level check
- **Description**: Disable the placement button in the HUD during WAVE_ACTIVE; no `place_tower()` gate
- **Pros**: Simpler TowerSystem code
- **Cons**: System is not authoritative — any non-UI caller (automation, test harness, future gameplay system) bypasses the gate silently
- **Rejection Reason**: System-level authority is required. The HUD must react to `place_tower()`'s return value, not pre-check independently.

### Alternative C: Shallow duplicate() with manual deep copy
- **Description**: Call `Resource.duplicate()` (shallow) then manually duplicate nested Resource fields
- **Pros**: Works on Godot versions before 4.5
- **Cons**: Requires a custom recursive copy function that must be updated whenever component schemas change
- **Rejection Reason**: `duplicate_deep()` (Godot 4.5+) handles the full tree automatically. We are on 4.6.2 — manual deep copy is unnecessary complexity. Note: deprecated-apis doc confirms `duplicate()` for nested resources is deprecated since 4.5.

## Consequences

### Positive
- `place_tower()` is the single authoritative placement gate — any caller simply reacts to the bool return
- Component Resources are fully isolated per tower instance — inventory is never corrupted by mission-time events
- Gate 4 (path check) is separated from hover preview — no per-frame A* cost on cursor movement
- `PlacementBlockReason` enum enables the HUD to display specific feedback without duplicating gate logic
- `TowerMissionState` is `RefCounted` — no manual memory management required

### Negative
- `get_placement_preview()` returns provisional valid state on hover when the path check would block — player sees a valid ghost until confirmation, then receives a rejection. UX trade-off accepted to avoid per-frame path check cost. The HUD spec must document this case with a distinct feedback animation on `PATH_BLOCKED`.
- `duplicate_deep()` creates 4 Resource copies at every placement. Negligible at MVP scope; monitor for GC pressure under stress (50+ rapid placements).

### Risks
- **Risk**: `duplicate_deep()` does not deep-copy raw `RefCounted` or `Node` references inside component Resources — only `Resource` subclasses are deep-copied. **Mitigation**: Schema enforcement rule — all nested component data must be `Resource` subclasses. Verify before first Tower System story ships (see Engine Compatibility row).
- **Risk**: `TowerMissionState` accidentally assigned to `@export` on a persistent node prevents GC. **Mitigation**: Code review gate — `TowerMissionState` instances must never appear in `@export` declarations.
- **Risk**: HUD shows misleading valid ghost on hover when path would block. **Mitigation**: `PATH_BLOCKED` reason on `place_tower()` false return must trigger a distinct UI feedback (e.g., red flash + "path blocked" label). This is a UX spec requirement, not just a code concern.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `tower.md` | Rule 8: mid-wave placement forbidden, no queueing | Gate 1 in `place_tower()` returns false immediately during WAVE_ACTIVE |
| `tower.md` | Rule 9: 3 gate checks in order; path check on confirmation only | 4-gate sequential check; `get_placement_preview()` separates hover from confirmation |
| `tower.md` | Rule 13: removal blocked during WAVE_ACTIVE | `remove_tower()` Gate 1 — same phase check pattern |
| `tower.md` | Rule 3: component loadout locked per placed tower for mission duration | `duplicate_deep()` creates independent mission-instance copies at placement commit |
| `tower.md` | Rule 2a: `damaged: bool` field mutated on tower destruction | Mission-instance copy absorbs `damaged := true`; inventory copy never written |
| Architecture OQ-4 | `duplicate_deep()` usage policy for composite Resources | Policy defined: `duplicate_deep()` at placement commit; shallow `duplicate()` forbidden for component isolation |

## Performance Implications
- **CPU**: `place_tower()` — O(1) phase/resource checks + O(footprint_area) grid check + O(SPAWN_count × A*) path check on confirmation. Gates 1–3 short-circuit before path check when WAVE_ACTIVE or placement is invalid.
- **CPU**: `duplicate_deep()` — O(component_tree_depth), one-time at placement commit. Negligible at expected placement frequency.
- **Memory**: 4 Resource copies per placed tower. At 20 towers: ~80 Resource instances. Freed on removal or mission end — no persistent growth across missions.
- **Load Time**: None.
- **Network**: Not applicable.

## Migration Plan
No existing Tower System code — greenfield implementation. No migration required.

## Validation Criteria
- Unit test: `place_tower()` returns `false` during WAVE_ACTIVE
- Unit test: `place_tower()` returns `false` when `Grid.is_footprint_placeable()` returns `false`
- Unit test: `place_tower()` returns `false` when `PathfindingSystem.would_block_all_paths()` returns `true`
- Unit test: `remove_tower()` returns `false` during WAVE_ACTIVE
- Unit test: mutating `mission_foundation.damaged := true` does not affect inventory `FoundationComponent`
- Unit test: `get_placement_preview()` never calls `PathfindingSystem.would_block_all_paths()`
- Integration test: full placement → mutation → removal → inventory check round-trip

## Related Decisions
- ADR-0001: EventBus — `tower_placed`, `tower_removed` signal declarations
- ADR-0004: Pathfinding — `would_block_all_paths()` interface and `would_block_all_paths_on_hover` forbidden pattern
- ADR-0005: Grid — `place_tower()` write API and `grid_write_outside_tower_system` forbidden pattern
