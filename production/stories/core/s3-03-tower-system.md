# S3-03 — Tower System Implementation

**Story ID**: S3-03
**Epic**: Core
**Layer**: Core
**Type**: Logic + Integration
**Owner**: godot-gdscript-specialist
**Sprint**: 3
**Estimate**: 2.0 days
**Status**: Complete
**Manifest Version**: 2026-05-16

## TR Coverage

| TR-ID | Requirement |
|-------|-------------|
| TR-tower-001 | 4 component slots; 4 archetypes; 4 tiers |
| TR-tower-002 | Placement blocked during WAVE_ACTIVE |
| TR-tower-003 | Monster cache via EventBus; no direct Monster refs |
| TR-tower-004 | would_block_all_paths() gate before placement |
| TR-tower-005 | Pre-placement perk (Scout phase only) |
| TR-tower-006 | Support archetype aura pulse model |

## ADR Governing Implementation

`docs/architecture/adr-0008-tower-placement-gate.md` (Accepted)

**ADR Decision Summary**: `TowerSystem.place_tower()` runs 4 ordered gates — phase, resource,
footprint, path integrity. Each gate short-circuits on failure. Mission-instance Resources
use `duplicate_deep()` at activation. `get_placement_preview()` runs Gate 1+2+3 only
(never Gate 4). Tower removal also gates on phase.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM — `duplicate_deep()` added in Godot 4.5 (post-LLM-cutoff); verify API signature before use.

## Dependencies

- S2-01 EventBus Autoload — Complete (`resources_changed` signal must be defined; add to event_bus.gd if missing)
- S2-03 Grid System — Complete
- S2-04 Pathfinding — Complete

## Files to Create

- `src/core/tower/tower_system.gd` — TowerSystem autoload
- `src/core/tower/tower_data.gd` — TowerData Resource (base config)
- `src/core/tower/placement_preview.gd` — PlacementPreview Resource
- `tests/unit/tower/tower_placement_test.gd`
- `tests/unit/tower/tower_combat_test.gd`
- `tests/unit/tower/tower_component_test.gd`
- `tests/helpers/event_bus_spy.gd` — **must be created here** (needed for negative-emission ACs)

## ⚠ EventBusSpy Prerequisite

Several negative-emission ACs (WAVE_ACTIVE rejects → `tower_placed` NOT fired) require
an injectable EventBus observer. Build `tests/helpers/event_bus_spy.gd` as part of this
story. It is ~30 lines, test-only, extends `RefCounted`:

```gdscript
class_name EventBusSpy
extends RefCounted

var emissions: Dictionary = {}  # signal_name: String → Array[Variant]

func watch(sig: Signal) -> void:
    sig.connect(func(...args): _record(sig.get_name(), args))

func _record(name: String, args: Array) -> void:
    if not emissions.has(name):
        emissions[name] = []
    emissions[name].append(args)

func count(signal_name: String) -> int:
    return emissions.get(signal_name, []).size()

func was_emitted(signal_name: String) -> bool:
    return count(signal_name) > 0

func clear() -> void:
    emissions.clear()
```

If EventBusSpy cannot be completed in this story, mark those ACs
`[DEFERRED — EventBusSpy required]` and carry to Sprint 4.

## Acceptance Criteria

### Placement Gate (AC-1 to AC-8)
- [ ] AC-1: PLACEABLE cell + INTERMISSION phase + sufficient resources + path clear → tower placed,
  `tower_placed` fires, Grid marks cells OCCUPIED
- [ ] AC-2: WAVE_ACTIVE phase → gate 1 fails immediately, no Grid write, `tower_placed` NOT fired
- [ ] AC-3: INTERMISSION + `_player_gold` < placement_cost → gate 2 fails, no Grid write, `tower_placed` NOT fired
  (test: set `_ts._player_gold = 0`, `placement_cost = 30` → place returns false)
- [ ] AC-4: Cell not PLACEABLE → gate 3 fails, no Grid write
- [ ] AC-5: Placement would block all paths → gate 4 fails, `tower_placed` NOT fired
- [ ] AC-6: SCOUT placement fires `pre_placement_perk_activated` in addition to `tower_placed`
- [ ] AC-7: INTERMISSION placement does NOT fire `pre_placement_perk_activated`
- [ ] AC-8: `get_placement_preview()` never calls Gate 4 (path check) — verified by calling it
  with a path-blocking footprint and confirming PathfindingSystem is NOT invoked

### DPS Formula (Formula 1)
- [ ] AC-9: weapon_damage=35, attack_speed=2.0, tier_dps_multiplier=1.0 → tower_dps=**70.0**
- [ ] AC-10: weapon_damage=35, attack_speed=2.0, tier_dps_multiplier=1.6 → tower_dps=**112.0**
- [ ] AC-11: Continuous fire 10 seconds T1 (70 dps) → total damage accumulated=**700** (±1)
- [ ] AC-12: Continuous fire 10 seconds T2 (112 dps) → total damage accumulated=**1120** (±1)

### Range + Cone (Formula 2)
- [ ] AC-13: Tower at (8,6), range=4, cone=180°, enemy at (13,6) → Chebyshev=5 > 4 → does NOT fire
- [ ] AC-14: Narrow cone 30° bonus +2 range: enemy at distance 5 ≤ effective_range=6 → fires
- [ ] AC-15: Same tower cone=90° (no bonus): distance=5 > effective_range=4 → does NOT fire
- [ ] AC-16: Chebyshev exactly == attack_range_cells → in range (inclusive)
- [ ] AC-17: Chebyshev == attack_range_cells + 1 → out of range

### HP and Destruction
- [ ] AC-18: hp_base=220, tier_multiplier=1.5 → tower_max_hp=**330.0**
- [ ] AC-19: Tower at 120 HP takes 120 damage → DESTROYED same frame; `tower_destroyed` fires;
  Grid cells return to PLACEABLE immediately

### Sell (40% refund)
- [ ] AC-20: placement_cost=30 sold in INTERMISSION → resource +**12** (`round(30 × 0.4)`);
  4 components returned; `tower_removed` fires (NOT `tower_destroyed`)
- [ ] AC-21: Sell during WAVE_ACTIVE → rejected; no resource change; no event fires

### Targeting Behaviour
- [ ] AC-22: Focus=LOWEST_HP: enemy B lower HP than enemy A → tower selects B
- [ ] AC-23: HOMING projectile: target dies mid-flight, second in range → re-acquires
  **[DEFERRED — ADR-0013 required]**
- [ ] AC-24: BALLISTIC projectile: target dies before impact → no damage; projectile terminates cleanly
  **[DEFERRED — ADR-0013 required]**
- [ ] AC-29: TowerSystem holds an internal `_monster_cache: Dictionary` (entity_id → position/hp)
  populated by `monster_spawned`, `monster_cell_entered`, and `monster_died` EventBus subscriptions.
  TowerSystem holds NO reference to MonsterManager or any MonsterEntity instance.
  Verified by: injecting stub EventBus emissions and asserting cache contents directly.

### Component Validation
- [ ] AC-25: `weapon_damage` outside [8.0, 120.0] → `push_error()` at load time
- [ ] AC-26: `attack_speed` outside [0.5, 4.0] → `push_error()` at load time
- [ ] AC-27: `tier_dps_multiplier` not in {1.0, 1.6, 2.4, 4.0} → `push_error()` at load time
- [ ] AC-28: T4 `tier_boss_dps_multiplier` must be 2.0; T1/T2/T3 must be 1.0

## Implementation Notes (from ADR-0008)

### Placement Gate — 4 sequential checks

```gdscript
func place_tower(tower_id: String, top_left: Vector2i) -> bool:
    # Gate 1 — Phase check
    if _current_phase == Phase.WAVE_ACTIVE: return false
    # Gate 2 — Resource check (TowerSystem caches gold from EventBus resources_changed)
    if _player_gold < _get_placement_cost(tower_id): return false
    # Gate 3 — Grid footprint check
    if not Grid.is_footprint_placeable(top_left, tower_data.footprint): return false
    # Gate 4 — Path integrity (NEVER on hover)
    var cells := Grid.get_footprint_cells(top_left, tower_data.footprint)
    if PathfindingSystem.would_block_all_paths(cells): return false
    # Commit
    var err := Grid.place_tower(tower_id, top_left, tower_data.footprint)
    if err != OK: return false
    _activate_tower_instance(tower_id, top_left)  # duplicate_deep() here
    EventBus.tower_placed.emit(tower_id, top_left, tower_data.archetype)
    return true
```

### `duplicate_deep()` — Godot 4.5+ API

`duplicate_deep()` on a Resource was added in Godot 4.5. Verify the method signature in
`docs/engine-reference/godot/` before using. Fallback if unavailable: manual deep-copy
via `Resource.duplicate(true)` (subresource recursion flag — available since 4.0).

### HUD Preview (Gate 3 max, never Gate 4)

```gdscript
func get_placement_preview(tower_id: String, top_left: Vector2i) -> PlacementPreview:
    # Runs Gate 1 + Gate 2 + Gate 3 only. Gate 4 NEVER called.
    ...
```

### Resource Cache (Gate 2)

TowerSystem does NOT call a ResourceSystem singleton. Instead it subscribes to
`GEventBus.resources_changed` and maintains:

```gdscript
var _player_gold: int = 0

func _on_resources_changed(gold: int, _source: StringName) -> void:
    _player_gold = gold
```

Gate 2 compares `_player_gold >= tower_data.placement_cost`. This follows the same
EventBus-centric caching pattern as the monster cache (TR-tower-003). In unit tests,
inject `_player_gold` directly (same pattern as `_mm._is_wave_active = true` in monster tests).

Verify `GEventBus.resources_changed` signal exists before implementing. If missing,
add it to `src/foundation/event_bus/event_bus.gd` as part of this story.

### SCOUT vs INTERMISSION

Phase-change subscription: listen to `EventBus.mission_phase_changed` and update `_current_phase`.
SCOUT = `pre_placement_perk_activated` fires on tower_placed.
INTERMISSION = perk does NOT fire.

### ADR Coverage Scope

ADR-0008 governs the placement gate (ACs 1–8). The following mechanics derive
directly from GDD formulas with no separate ADR required:

- **DPS formula** (AC-9 to AC-12): `tower_dps = weapon_damage × attack_speed × tier_dps_multiplier`
- **Range + cone** (AC-13 to AC-17): Chebyshev distance + cone bonus — pure math, no engine risk
- **HP + destruction** (AC-18, AC-19): `tower_max_hp = hp_base × tier_multiplier`
- **Sell refund** (AC-20, AC-21): `round(placement_cost × 0.4)` in INTERMISSION only
- **Component validation** (AC-25 to AC-28): `@export_range` guards + `push_error()` at load time

**Projectile behavior (AC-23, AC-24) requires ADR-0013 before implementation.**
Homing re-acquisition and ballistic early-termination involve non-trivial lifecycle
choices (pooling, mid-flight state, signal timing). Mark AC-23 and AC-24
`[DEFERRED — ADR-0013 required]` until that ADR is Accepted.

## Out of Scope

- Tower visual/animation (Visual/Feel story)
- Mission HUD HP bar for tower (UI story, Sprint 4+)
- `constellation_deactivated` timing (Constellation GDD not yet authored)
- Tower upgrade system (post-MVP)

## QA Test Cases

- **AC-2**: WAVE_ACTIVE placement rejection
  - Given: TowerSystem phase = WAVE_ACTIVE, EventBusSpy watching `tower_placed`
  - When: `place_tower("archer", Vector2i(5,5))` called
  - Then: returns false; spy.count("tower_placed") == 0; Grid unchanged
  - Edge cases: call with valid footprint/resources — gate 1 must short-circuit before any check

- **AC-9/AC-10**: DPS formula
  - Given: TowerData with weapon_damage=35, attack_speed=2.0, tier_dps_multiplier in {1.0, 1.6}
  - When: `compute_dps(tower_data)` called
  - Then: returns 70.0 for T1, 112.0 for T2
  - Edge cases: all multiplier values {1.0, 1.6, 2.4, 4.0} produce distinct DPS values

- **AC-13 through AC-17**: Range + cone
  - Given: Tower at (8,6), attack_range_cells=4, cone angles vary
  - When: `is_in_range(enemy_position)` called for positions at Chebyshev 3, 4, 5
  - Then: Chebyshev ≤ effective_range → true; Chebyshev > effective_range → false
  - Edge cases: exactly on boundary (Chebyshev == range) → true (inclusive)

- **AC-20**: Sell refund
  - Given: Tower placed with placement_cost=30 in INTERMISSION
  - When: `sell_tower(tower_id)` called
  - Then: resource delta = +12; `tower_removed` fires; `tower_destroyed` does NOT fire

- **AC-25 through AC-28**: Component validation
  - Given: TowerData resource with out-of-bounds weapon_damage
  - When: resource is loaded/instantiated
  - Then: `push_error()` called; no crash; game continues in degraded state

- **AC-29**: EventBus monster cache (no direct Monster refs)
  - Given: TowerSystem with stubs; emit `monster_spawned` for entity_id=7 at cell (3,4)
  - When: internal `_monster_cache` dictionary is read directly
  - Then: entry for entity_id=7 exists with position (3,4)
  - Edge case: emit `monster_died` for entity_id=7 → entry removed from cache

## Test Evidence

**Story Type**: Logic + Integration
**Required evidence**:
- `tests/unit/tower/tower_placement_test.gd` — AC-1 through AC-8, AC-21
- `tests/unit/tower/tower_combat_test.gd` — AC-9 through AC-24
- `tests/unit/tower/tower_component_test.gd` — AC-25 through AC-28
- `tests/helpers/event_bus_spy.gd` — prerequisite test helper

**Status**: [ ] Not yet created
**Note**: AC-23 and AC-24 are deferred pending ADR-0013 (Tower Projectile Lifecycle).
`tower_combat_test.gd` covers AC-9 through AC-22, AC-29 only until ADR-0013 is Accepted.

## Dependencies

- Depends on: S2-01 (EventBus), S2-03 (Grid), S2-04 (Pathfinding) — all Complete
- Unlocks: S3-04 (Damage & Status), S3-05 (Combat loop integration)

## Completion Notes

**Completed**: 2026-07-01
**Criteria**: 24/26 passing (AC-23, AC-24 formally deferred — ADR-0013 required)
**Deviations**:
- ADVISORY: `0.4` sell refund multiplier hardcoded — GDD formula constant, not a tunable value
- ADVISORY: TR-tower-006 (Support archetype aura pulse) listed in TR Coverage but has no ACs in this story — deferred to dedicated story
- ADVISORY: AC-23/AC-24 deferred pending ADR-0013 (Tower Projectile Lifecycle)
**Test Evidence**: Logic + Integration — unit tests at `tests/unit/tower/` (3 files, ~35 test functions); helper at `tests/helpers/event_bus_spy.gd`
**Code Review**: Complete — 2 passes; all required changes resolved (ADR-0001 deferred emit, hot-path alloc removal, float comparison fix, EventBusSpy memory leak, defensive cache guard)
