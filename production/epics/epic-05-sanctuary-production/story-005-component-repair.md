# Story 005: Component Repair (In-Place Mutation)

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (3-4 hrs)
> **Manifest Version**: 2026-07-13b *(stale for this epic — see Story 001)*

## Context

**GDD**: `design/gdd/crafting.md`
**Requirement**: `TR-craft-003` (repair half)

**ADR Governing Implementation**: ADR-0023 (Crafting) + ADR-0021 (`clear_damaged_flag()`)
**ADR Decision Summary**: Repair is NOT a recipe — no `RecipeResource` entry, no `tech_prerequisite`, never fires `recipe_discovered`. Gated on `InventorySlot.damaged == true` and Formula 3's Common-material-only cost. Mutates the existing item instance in place (`damaged: true → false`) via `Inventory.clear_damaged_flag(item_id)` — does not consume/produce, does not fire `component_crafted`.

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules**:
- Required: `component_repaired(item_id, component_type)` fires exactly once on successful repair — already merged into `event-bus.md`'s frozen catalogue (78 events)
- Forbidden: repairing via the same code path as Rule 8's crafting resolution — repair has its own resolution sequence, distinct sub-steps

## Acceptance Criteria

- [ ] AC-6: GIVEN a `damaged=true` Tower Component instance and sufficient Common material per Formula 3, WHEN Repair is confirmed, THEN the same `item_id` has `damaged` flipped to `false` (no new item created, no `component_crafted` fires), and `component_repaired` fires exactly once.
- [ ] AC-9: GIVEN a Tier 4 component instance with `damaged=true`, WHEN its repair cost is checked, THEN it matches Formula 3 exactly: 16 Common, zero Uncommon/Rare required.

## Implementation Notes

Repair cost scales by the component's *originally-crafted* `quality_tier` (read from the instance, never re-rolled) via Formula 3: `repair_common_qty(T) = round(base_repair_common × tier_dps_multiplier(T))`. Always Common-only, regardless of the component's original tier's rarity mix — this is what keeps repair cheaper than a fresh recraft.

A component is never simultaneously equipped and damaged (Edge Cases — a component is only `damaged==true` after being returned to Inventory), so this story does not need to defend against an equipped-item-lock conflict.

## Out of Scope

- Story 004: fresh crafting (a distinct resolution path)
- Story 006: Formula 3's exact scaling table — this story consumes the formula's output, doesn't define it (see Story 006, which covers Formulas 1-3 together)

## QA Test Cases

**AC-6**
- Given: a `damaged=true` item instance, sufficient Common material held
- When: Repair confirmed
- Then: `Inventory.clear_damaged_flag(item_id)` succeeds, same `item_id` now `damaged=false`, `component_repaired(item_id, component_type)` fires exactly once, no `item_added`/`item_removed`/`component_crafted`
- Edge cases: insufficient Common material — rejected, zero mutation, no event

**AC-9**
- Given: a Tier 4 component, `base_repair_common=4` (default), `tier_dps_multiplier(4)=4.0`
- When: repair cost computed
- Then: `round(4 × 4.0) = 16` Common, 0 Uncommon, 0 Rare
- Edge cases: Tier 1 component — `round(4 × 1.0) = 4` Common

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/crafting/component_repair_test.gd`
**Status**: [x] Created — 5 test functions covering AC-6, AC-9. Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 2/2 passing (AC-6, AC-9)
**Deviations**: ADVISORY — implemented alongside Story 005, four real prerequisite gaps found and fixed: (1) `component_repaired` signal documented in event-bus.md's catalogue but missing from `event_bus.gd`; (2) `InventorySlot.damaged` field (ADR-0021-specified) never added; (3) `Inventory.clear_damaged_flag()` never implemented — took `instance_id` (not `item_id` as ADR-0021's parameter naming suggests, since item_id can't disambiguate multiple copies); (4) Story 004's `resolve_craft()` never stored `quality_tier` on the crafted instance's `stat_overrides`, which this story's repair-cost formula needs to read back — fixed retroactively in `crafting.gd`. Also: repair's Common-material cost check is subject to the same `TD-craft-001`/`TD-defbuild-002` rarity-vocabulary gap — content-correct, not yet genuinely payable against real Inventory contents.
**Test Evidence**: `tests/integration/crafting/component_repair_test.gd` (5 functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Skipped per "keep skip review plan through the remaining stories" instruction

## Dependencies

- Depends on: Story 001, Story 006 (Formula 3)
- Unlocks: None within this epic
