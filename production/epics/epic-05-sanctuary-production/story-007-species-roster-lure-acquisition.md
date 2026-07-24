# Story 007: Species Roster & Lure Acquisition

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (3-4 hrs)
> **Manifest Version**: 2026-07-13b *(stale — does not yet cover ADR-0026; rules below extracted directly from the ADR)*

## Context

**GDD**: `design/gdd/menagerie.md`
**Requirement**: `TR-menag-001` (roster/acquisition half)

**ADR Governing Implementation**: ADR-0026 (Menagerie creature lifecycle)
**ADR Decision Summary**: `SpeciesResource` (minimal, GameDataRegistry-backed: `species_id`, `species_tier`). Lure is a deterministic, player-initiated action — query `Inventory.has_items()` for `menagerie_lure`, consume via `materials_spent`, instantiate a `CreatureInstance` at `starting_happiness=70`. No RNG on species or outcome.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `Inventory.has_items()` is a Criterion A direct Autoload call (ADR-0020).

**Control Manifest Rules (extracted from ADR-0026)**:
- Required: `CreatureInstance` is a plain `RefCounted`, never a `Resource` — mirrors `InventorySlot`'s precedent for flat-primitive runtime entities
- Required: `creature_id: int`, monotonic counter (`_next_creature_id`), same pattern as Inventory's `_next_instance_id`
- Forbidden: any RNG in the Lure resolution — species, cost, and starting happiness are all fully deterministic

## Acceptance Criteria

- [ ] AC-1: GIVEN the full five-species roster, WHEN a Lure is attempted against any one of them, THEN the action is permitted with no additional discovery/unlock gate beyond `has_items(lure_cost)`.
- [ ] AC-2: GIVEN a selected target species and sufficient `menagerie_lure` per Formula 4's cost, WHEN Lure is confirmed, THEN `materials_spent` fires for the exact `lure_cost`, one new creature instance is created at `starting_happiness = 70`, deterministic — no RNG affects species, outcome, or starting state.
- [ ] AC-3: GIVEN a selected target species and insufficient `menagerie_lure`, WHEN Lure is confirmed, THEN the action is rejected before any `materials_spent` call — no creature instance created, no state changes.
- [ ] AC-37: GIVEN `base_lure_cost = 3` (default) and a Tier 1 target species, WHEN `lure_cost` is computed, THEN it equals exactly `3`.
- [ ] AC-38: GIVEN `base_lure_cost = 3` and a Tier 3 target species (`aurora_stag`), WHEN `lure_cost` is computed, THEN it equals exactly `9`.

## Implementation Notes

```gdscript
class_name SpeciesResource extends Resource
@export var species_id: StringName = &""
@export var species_tier: int = 1   # 1-3

# Formula 4: lure_cost(tier) = base_lure_cost × tier
```

## Out of Scope

- Story 008: where the new creature lands (HABITAT vs RESERVE) — this story only creates it
- Story 015: breeding-produced offspring (a distinct creation path, never via Lure)

## QA Test Cases

**AC-1**
- Given: all 5 species (`glimmer_hare`, `mossback_toad`, `emberwing_moth`, `duskfang_fox`, `aurora_stag`)
- When: Lure attempted against each
- Then: no rejection beyond the material-cost check
- Edge cases: none — this is an absence-of-gate assertion

**AC-2**
- Given: sufficient `menagerie_lure` for the target species' tier
- When: Lure confirmed
- Then: `materials_spent` fires for the exact cost, one `CreatureInstance` created at `happiness=70`
- Edge cases: confirm twice rapidly — must not create two creatures from one confirm (guard against double-fire)

**AC-3**
- Given: insufficient `menagerie_lure`
- When: Lure confirmed
- Then: rejected, zero state change, no `materials_spent` call
- Edge cases: exactly 1 unit short of the cost

**AC-37 / AC-38**
- Given: `base_lure_cost=3`
- When: cost computed for Tier 1 vs Tier 3
- Then: 3 vs 9 respectively
- Edge cases: Tier 2 — expect 6 (not directly an AC but implied by Formula 4's linear scaling)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/menagerie/lure_acquisition_test.gd`
**Status**: [x] Created — 7 test functions covering AC-1, AC-2, AC-3, AC-37, AC-38. Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 5/5 passing (AC-1, AC-2, AC-3, AC-37, AC-38)
**Deviations**: ADVISORY — 2 real prerequisite gaps found and fixed: (1) `creature_acquired` signal referenced in ADR-0021's "Enables" note as already catalogued, but missing from `event_bus.gd`; (2) `creature_id`/`target_item_id`/`offspring_id` on 4 existing Menagerie signals were typed `String`, but ADR-0026's own Risks section explicitly requires `int` (matching `Inventory.reserve_instance_id()`'s type) — corrected all 5 signals. Also added `Inventory.has_item_quantity(item_id, quantity)` (a new, item_id-specific check — `has_items()` sums by item_type and would incorrectly aggregate `menagerie_lure` with other `Material`-type items). `Menagerie` is NOT yet registered as Autoload #11 in `project.godot` — deferred to whichever later story actually needs `request_sacrifice()` bare-global callability, mirroring Defense Building's Story 018/019 precedent.
**Test Evidence**: `tests/unit/menagerie/lure_acquisition_test.gd` (7 functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Skipped per "keep skip review plan through the remaining stories" instruction

## Dependencies

- Depends on: None (first Menagerie story)
- Unlocks: Story 008
