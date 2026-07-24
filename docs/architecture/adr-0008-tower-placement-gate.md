# ADR-0008: Tower Placement Gate — Phase Guard, Path Integrity, and Component Deep-Copy Policy

## Status
Accepted

## Date
2026-05-19

> **Revised 2026-07-13** — resolves the BLOCKING "`tower_id` type & signal arity" conflict
> found by `/architecture-review` (`docs/architecture/architecture-review-2026-07-13b.md`).
> This ADR's Decision text originally showed `place_tower(tower_id: String, top_left) -> bool`
> and a 3-arg `tower_placed(tower_id, top_left, archetype)` emission — both inconsistent with
> ADR-0005 (Grid, `tower_id: int`) and ADR-0010 (Hero, expects `int` with a different arg
> order). The shipped `src/core/tower/tower_system.gd` and `src/foundation/event_bus/event_bus.gd`
> were built with a self-consistent contract that this text never documented: `place_tower()`
> takes a `blueprint_id: StringName` catalog key, generates its own `int` runtime `tower_id`,
> and the bus signals carry 5/3/4 typed args respectively. The Decision section below is
> corrected to document the interface that was actually built. No behavioral/code change.
> This revision also documents the `tower_destroyed` emission path (mid-wave boss-attack
> HP-zero), which this ADR previously omitted entirely, leaving ADR-0010's subscription to
> it looking like a dangling reference.

> **Amendment 2026-07-19** — Implementation catch-up: the 4-component Resource
> architecture (Component Deep-Copy Policy section below) was Accepted 2026-05-19
> but never actually implemented. The shipped `TowerData`
> (`src/core/tower/tower_data.gd`) is a flat Resource with direct stat fields
> (`weapon_damage`, `attack_speed`, `hp_base`, etc.) — no `FoundationComponent`/
> `WeaponComponent`/`FocusComponent`/`PowerComponent` classes exist anywhere in
> `src/` (confirmed via grep). `TowerMissionState.tower_data` holds a bare shared
> reference to the blueprint, not a `duplicate_deep()`'d mission-instance copy —
> `tower_system.gd:124`'s own comment (`state.tower_data = data  # ADR-0008:
> duplicate_deep() when components are authored`) is contemporaneous evidence
> this was a known, deliberately-deferred gap, not an oversight introduced
> since. Discovered while investigating why Tower Mastery's `build_signature`
> (Epic 06 Story 008) had nothing to derive from — there is no per-tower
> component-slot data at all today, only a flat archetype+stats blueprint.
> **Decision (user-confirmed, 2026-07-19): implement the architecture as
> originally specified, catching the code up to this ADR** — not a revision of
> the decision itself. See "Implementation Catch-Up Schema" immediately below
> the Component Deep-Copy Policy section for the exact field-level schema
> (sourced verbatim from `design/gdd/tower.md`'s own already-authored
> component-schema tables, lines ~48-93 — no new design work, this was already
> specified, just never built). godot-gdscript-specialist validation (2026-07-19):
> MINOR NOTES, not blocking — see that section's own sign-off note.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / Resource Management |
| **Knowledge Risk** | MEDIUM — `duplicate_deep()` added in Godot 4.5 (post-LLM-cutoff) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | `Resource.duplicate_deep()` — added Godot 4.5; replaces manual recursive `Resource.duplicate()` chains. Confirmed available in 4.6.2. |
| **Verification Required** | ~~Confirm `duplicate_deep()` correctly deep-copies Resources nested inside typed `Array[Resource]` and `Dictionary` fields before first Tower System story ships.~~ **CLOSED 2026-07-19 (Sprint 7, S7-01)**: live-verified via Godot MCP — mutating a mission-instance component copy left the original blueprint's components completely untouched, all 4 confirmed as distinct object instances. Raw `RefCounted`/`Node` references still will NOT be deep-copied if ever nested inside a component (see Risks) — none are today. |

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

`TowerSystem.place_tower(blueprint_id: StringName, top_left: Vector2i) -> bool`
takes a catalog lookup key (`blueprint_id`, resolved against the tower data table)
and runs four ordered checks. Each check short-circuits on failure — no subsequent
check is run. Only when all four pass does the system commit placement, at which
point it mints its own runtime `int tower_id` — `blueprint_id` and `tower_id` are
deliberately distinct: `blueprint_id` identifies *what* tower (catalog/data lookup),
`tower_id` identifies *this specific placed instance* (Grid occupancy key, EventBus
identity, save/mission state key). This matches the shipped
`src/core/tower/tower_system.gd`:

```
Gate 1 — Phase check
  if _current_phase == Phase.WAVE_ACTIVE: return false
  if not _tower_table.has(blueprint_id): return false   # unknown blueprint guard
  (no resource query, no Grid call, no Pathfinding call)

Gate 2 — Resource check
  if not GMissionEconomy.can_afford(data.placement_cost): return false
  (no Grid call, no Pathfinding call)
  # Resolved (2026-07-16, Epic 03 Story 013): the 2026-07-13 note below was live —
  # TowerSystem's old _player_gold local cache treated resources_changed's payload
  # as an absolute balance, violating the delta-payload contract event-bus.md
  # documents (and ADR-0018 assumes), which corrupted the newly-implemented
  # MissionEconomy Autoload's balance the moment a tower was placed or sold.
  # Fixed same-session: TowerSystem no longer caches gold locally at all — Gate 2
  # reads GMissionEconomy.can_afford() live, and place_tower()/sell_tower() emit
  # signed deltas (-placement_cost / +refund), not absolute balances. See
  # docs/tech-debt-register.md TD-econ-008 for the full writeup.

Gate 3 — Grid footprint check
  if not Grid.is_footprint_placeable(top_left, data.footprint): return false
  (no Pathfinding call)

Gate 4 — Path integrity check  [confirmation only — never on hover]
  var cells := _get_footprint_cells(top_left, data.footprint)
  if Pathfinding.would_block_all_paths(cells): return false

Commit
  _tower_id_counter += 1
  var tower_id: int = _tower_id_counter
  var err := Grid.place_tower(tower_id, top_left, data.footprint)
  if err != OK:
    _tower_id_counter -= 1
    return false
  var state := TowerMissionState.new()   # tower_id, tower_data, grid_position, hp — see ADR-0008
  placed_towers[tower_id] = state
  EventBus.resources_changed.emit(-data.placement_cost, &"tower_placed")
  var placed_in_scout := _current_phase == Phase.SCOUT
  EventBus.tower_placed.emit(tower_id, top_left, String(data.archetype), data.footprint, placed_in_scout)
  if placed_in_scout:
    EventBus.pre_placement_perk_activated.emit(tower_id, String(data.archetype))
  return true
```

`TowerSystem.sell_tower(tower_id: int) -> bool` (an `int`, since this operates on
an already-placed instance, not a catalog lookup) runs a single gate:

```
Gate 1 — Phase check
  if _current_phase == Phase.WAVE_ACTIVE: return false
  if not placed_towers.has(tower_id): return false   # unknown-instance guard

Commit
  var refund := roundi(state.tower_data.placement_cost * 0.4)
  Grid.remove_tower(tower_id)
  placed_towers.erase(tower_id)
  EventBus.resources_changed.emit(refund, &"tower_sold")
  EventBus.tower_removed.emit(tower_id, state.grid_position, String(state.tower_data.archetype))
  return true
```

### Tower Destroyed — mid-wave HP-zero path (previously undocumented by this ADR)

A placed tower can also leave the grid mid-wave via boss attack damage reducing its
HP to zero — a distinct path from the player-initiated `sell_tower()` above. This
path emits `tower_destroyed`, not `tower_removed`:

```
On boss-attack damage resolution, if resulting tower HP <= 0:
  Grid.remove_tower(tower_id)
  placed_towers.erase(tower_id)
  EventBus.tower_destroyed.emit(tower_id, state.grid_position,
      String(state.tower_data.archetype), state.tower_data.footprint)
```

This is the publisher ADR-0010's `_on_tower_destroyed` subscription depends on —
previously undocumented here, which made that subscription look like a dangling
reference with no emitter. It is shipped (`TowerSystem._on_boss_tower_attack_attempted`).

### HUD Preview API — hover feedback without Gate 4

```
TowerSystem.get_placement_preview(blueprint_id: StringName, top_left: Vector2i) -> PlacementPreview
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

### Implementation Catch-Up Schema (Amendment 2026-07-19)

Exact field-level schema for the 4 component `Resource` subclasses, sourced
verbatim from `design/gdd/tower.md`'s own already-authored component-schema
tables — no new design decision, this closes an implementation gap only.
All four include `damaged: bool = false` (set true on tower destruction,
non-equippable until Sanctuary repair — ADR-0021's `Inventory.clear_damaged_flag()`
precedent applies to the Foundation component's copy specifically, since
Foundation is the slot Sanctuary repair targets per `crafting.md`).

```gdscript
class_name FoundationComponent extends Resource
@export var archetype: String = "physical"       # physical|ranged|elemental|support
@export var hp_base: float = 100.0                # [80.0, 400.0]
@export var tier: int = 1                         # 1-4
@export var tier_multiplier: float = 1.0          # {1.0, 1.5, 2.0, 2.5}
@export var tier_dps_multiplier: float = 1.0      # {1.0, 1.6, 2.4, 4.0}
@export var tier_cost_factor: float = 1.0         # {1.0, 1.5, 2.0, 4.0}
@export var tier_boss_dps_multiplier: float = 1.0 # {1.0, 2.0} — T1-T3=1.0, T4=2.0
@export var footprint: Vector2i = Vector2i(1, 1)  # (1,1) or (2,2)
@export var pre_placement_perk: String = ""       # any perk id, or ""
@export var archetype_cost_factor: float = 1.0    # [0.5, 2.0]
@export var damaged: bool = false

class_name WeaponComponent extends Resource
@export var weapon_damage: float = 10.0           # [8.0, 120.0]
@export var attack_speed: float = 1.0             # [0.5, 4.0]
@export var projectile_type: String = "BALLISTIC" # HOMING|BALLISTIC|BEAM|AURA
@export var aura_effect_type: String = ""         # Support/AURA only
@export var aura_effect_value: float = 0.0        # Support/AURA only, [0.0, ...]
@export var aura_radius_cells: int = 0            # Support/AURA only, [1, 6]
@export var aoe_radius_cells: int = 0              # BALLISTIC only, [0, 4]
@export var damaged: bool = false

class_name FocusComponent extends Resource
@export var targeting_mode: String = "CLOSEST_TO_GOAL"  # CLOSEST_TO_GOAL|SPAWN_ORDER|LOWEST_HP|HIGHEST_HP|SCATTER
@export var attack_range_cells: int = 3            # [1, 8]
@export var cone_half_angle: float = 180.0         # [22.5, 180.0]
@export var facing_direction: String = "N"         # N|NE|E|SE|S|SW|W|NW
@export var damaged: bool = false

class_name PowerComponent extends Resource
@export var effect_type: String = ""               # any effect id, or ""
@export var effect_value: float = 0.0               # [0.0, ...]
@export var effect_duration: float = 0.0            # [0.0, ...], 0 = instant
@export var constellation_eligibility_tag: String = ""  # any tag id, or "" — moves here from TowerData
@export var damaged: bool = false

# Composing blueprint Resource (replaces flat TowerData as the .tres-authored unit)
class_name TowerBlueprintData extends Resource
@export var tower_id: StringName = &""
@export var display_name: String = ""
@export var placement_cost: int = 10
@export var foundation: FoundationComponent
@export var weapon: WeaponComponent
@export var focus: FocusComponent
@export var power: PowerComponent
```

**Migration scope, confirmed narrow (godot-gdscript-specialist validation)**:
only `src/core/tower/tower_system.gd` and `src/core/tower/tower_mission_state.gd`
reference `TowerData`/`tower_data` today — no HUD/UI/Hero code touches it
directly. `TowerMissionState.tower_data: TowerData` becomes 4 separate
`duplicate_deep()`'d fields (`foundation`, `weapon`, `focus`, `power`); every
`state.tower_data.X` read site (9 call sites in `tower_system.gd`) becomes
`state.foundation.X` / `state.weapon.X` / `state.focus.X` / `state.power.X`
per field. `TowerData.validate()` splits into one `validate()` per component
class (or one composed check on `TowerBlueprintData`). Existing `.tres`
blueprint files must be restructured to nest 4 sub-resources instead of flat
fields — this content-migration cost exists under any implementation approach
(inline `@export` sub-resources would require the identical `.tres`
restructuring), so the 4-separate-class design is not adding migration
overhead beyond what any correct implementation requires.

**`constellation_eligibility_tag` relocation**: this field currently lives
directly on `TowerData` (added Sprint 6, S6-08, as a minimal stopgap — see
that story's own doc comment) because `PowerComponent` didn't exist yet.
Once this catch-up lands, it moves to `PowerComponent.constellation_eligibility_tag`
per `tower.md`'s own schema, and `TowerSystem`'s 3 `EventBus` emit sites
(`tower_placed`/`tower_removed`/`tower_destroyed`) read it from
`state.power.constellation_eligibility_tag` instead of `data.constellation_eligibility_tag`
— no change to the EventBus payload shape itself, only to where the value is
sourced from internally.

**Tower Mastery `build_signature` unblock (Epic 06 Stories 008/009)**: with
all 4 components now real per-tower data, `tower_placed`'s payload gains 4
new trailing fields (`foundation_component_id`/`weapon_component_id`/
`focus_component_id`/`power_component_id` — content-authored identifiers for
which named component asset is equipped, distinct from the component
Resources' own runtime field values) per Epic 06 Story 008's own
Implementation Notes; `tower_component_equipped` is promoted to a Resource
subclass carrying the same 4 identifiers. This ADR does not redesign that
payload contract — it only removes the blocker (no component data model to
derive it from) that made Story 008 previously `[BLOCKED]`.

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
func place_tower(blueprint_id: StringName, top_left: Vector2i) -> bool
func sell_tower(tower_id: int) -> bool
func get_placement_preview(blueprint_id: StringName, top_left: Vector2i) -> PlacementPreview

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

# EventBus signals emitted (canonical — see event-bus.md for full doc comments):
signal tower_placed(tower_id: int, grid_position: Vector2i, archetype: String, footprint: Vector2i, placed_in_scout: bool)
signal tower_removed(tower_id: int, grid_position: Vector2i, archetype: String)     # sell_tower() path
signal tower_destroyed(tower_id: int, grid_position: Vector2i, archetype: String, footprint: Array)  # boss-attack HP-zero path
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
- **Risk**: `duplicate_deep()` does not deep-copy raw `RefCounted` or `Node` references inside component Resources — only `Resource` subclasses are deep-copied. **Mitigation**: Schema enforcement rule — all nested component data must be `Resource` subclasses. Verify before first Tower System story ships (see Engine Compatibility row). **(Amendment 2026-07-19, godot-gdscript-specialist validation)**: this verification never actually happened despite being flagged since 2026-05-19 — must close as part of the implementation catch-up (see Migration Plan step 7), not remain open a second time. Concretely matters if any future perk/effect data nested inside `PowerComponent`/`WeaponComponent` (e.g. `aura_effect_type`-adjacent data) is ever modeled as a plain `Dictionary` instead of a `Resource` — enforce Resource-subclass-only nesting.
- **Risk (Amendment 2026-07-19)**: `VERSION.md`'s Project-Specific API Tracking table does not list `duplicate_deep()` despite it being a load-bearing post-cutoff (4.5+) API in this Accepted ADR since 2026-05-19. **Mitigation**: add a tracking row when this catch-up implementation lands and is live-verified.
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
**Original (2026-05-19)**: No existing Tower System code — greenfield implementation. No migration required.

**Amended 2026-07-19** (implementation catch-up, since Tower System now fully
exists): migration is scoped to 2 files (`tower_system.gd`, `tower_mission_state.gd`,
confirmed via grep — no HUD/UI/Hero code touches `TowerData` directly). Steps:
1. Add the 4 component classes + `TowerBlueprintData` (see Implementation
   Catch-Up Schema above) alongside the existing flat `TowerData` — do not
   delete `TowerData` yet.
2. Restructure `assets/data/towers/*.tres` blueprint files to the new
   4-sub-resource `TowerBlueprintData` shape.
3. Update `GameDataRegistry`'s tower-blueprint loader to load
   `TowerBlueprintData` instead of `TowerData`.
4. Update `TowerSystem.place_tower()`'s `_activate_tower_instance()` path to
   call `duplicate_deep()` on all 4 components and store them on
   `TowerMissionState` (replacing the bare `tower_data: TowerData` reference).
5. Update all 9 `state.tower_data.X` read sites in `tower_system.gd` to the
   per-component equivalent.
6. Delete `TowerData`/`tower_data.gd` only after all read sites are migrated
   and the full test suite passes.
7. Live-verify via Godot MCP that `duplicate_deep()` actually isolates a
   mutated `mission_foundation.damaged` from the inventory-side original —
   this ADR's own "Verification Required" row has been open since 2026-05-19
   and must close as part of this catch-up, not remain deferred again.

## Validation Criteria
- Unit test: `place_tower()` returns `false` during WAVE_ACTIVE
- Unit test: `place_tower()` returns `false` when `Grid.is_footprint_placeable()` returns `false`
- Unit test: `place_tower()` returns `false` when `PathfindingSystem.would_block_all_paths()` returns `true`
- Unit test: `sell_tower()` returns `false` during WAVE_ACTIVE
- Unit test: `tower_destroyed` emits with correct args on boss-attack HP-zero; `tower_removed` emits (not `tower_destroyed`) on `sell_tower()`
- Unit test: mutating `mission_foundation.damaged := true` does not affect inventory `FoundationComponent`
- Unit test: `get_placement_preview()` never calls `PathfindingSystem.would_block_all_paths()`

**Added 2026-07-19 (implementation catch-up) — all verified, landed Sprint 7 S7-01**:
- [x] Live MCP verification: `duplicate_deep()` genuinely produces 4 independent component copies per placed tower — mutating a mission-instance copy's `power.effect_value`/`foundation.damaged` left the original `TowerBlueprintData` and its own nested components completely untouched; all 4 component instances confirmed as genuinely distinct objects via `!=` reference comparison. This closes the Engine Compatibility "Verification Required" row, open since 2026-05-19.
- [x] All 9 former `state.tower_data.X` read sites in `tower_system.gd` migrated to their per-component equivalent (`state.foundation.X`/`state.weapon.X`/`state.focus.X`/`state.power.X`), no leftover `tower_data` references (confirmed via grep) — `TowerData`/`tower_data.gd` deleted.
- [x] `TowerBlueprintData.validate()` aggregates all 4 components' individual `validate()` results.
- [x] `PowerComponent.constellation_eligibility_tag` flows through to `tower_placed`/`tower_removed`/`tower_destroyed`'s existing payload field (Sprint 6, S6-08) with zero change to Constellation's own consuming code — verified via full regression (1045/1045 passing, only a pre-existing unrelated failure, `TD-menag-006`).
- [x] Full gdUnit4 regression across `tests/unit/tower`, `tests/integration/core`, `tests/unit/game_data_registry` (118/118) plus project-wide (1045/1045) — 0 errors, 0 new failures.

## Related Decisions
- ADR-0001: EventBus — `tower_placed`, `tower_removed` signal declarations
- ADR-0004: Pathfinding — `would_block_all_paths()` interface and `would_block_all_paths_on_hover` forbidden pattern
- ADR-0005: Grid — `place_tower()` write API and `grid_write_outside_tower_system` forbidden pattern
- ADR-0018: Mission Economy — resolves the Gate 2 `ResourceSystem.can_afford()` placeholder to the concrete `MissionEconomy.can_afford()` API
