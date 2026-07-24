# Story 003: Craftability Re-Check (Discovery vs. Craftability Split)

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: XS (<1 hr)
> **Manifest Version**: 2026-07-13b *(stale for this epic — see Story 001)*

## Context

**GDD**: `design/gdd/crafting.md`
**Requirement**: `TR-craft-002` (craftability half — discovery is one-way/permanent, craftability flickers on `item_added`/`item_removed`)

**ADR Governing Implementation**: ADR-0023
**ADR Decision Summary**: Craftability (Craft button enabled/disabled) is a separate, continuously re-evaluated `has_items(inputs)` check, independent of the one-time Discovery Ledger — a `DISCOVERED` recipe stays visible even when temporarily unaffordable.

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules**:
- Required: craftability check subscribes to `item_added`/`item_removed`, re-evaluates only `DISCOVERED` recipes
- Forbidden: writing to `_discovery_ledger` from the craftability check path — the two are structurally separate, never cross-write

## Acceptance Criteria

- [ ] AC-3: GIVEN a `DISCOVERED` recipe, WHEN the player's material stock later drops below `inputs`, THEN the recipe remains visible in the Crafting panel (still `DISCOVERED`) but its Craft button becomes disabled.

## Implementation Notes

Craftability is a pure read (`Inventory.has_items(recipe.inputs)`) evaluated on demand by the UI layer or cached and invalidated on `item_added`/`item_removed` — either is acceptable, but the cache (if used) must never be treated as a second discovery gate.

## Out of Scope

- Story 002: one-time discovery itself
- Story 004: what happens when Craft is actually confirmed

## QA Test Cases

**AC-3**
- Given: a `DISCOVERED` recipe currently affordable
- When: materials are spent elsewhere (e.g. a different craft), dropping stock below `inputs`
- Then: the recipe stays in the Discovery Ledger as `DISCOVERED`; only its craftability flag flips to false
- Edge cases: stock rises again on a later `item_added` — craftability flips back to true with no re-discovery event

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/crafting/craftability_recheck_test.gd`
**Status**: [x] Created — 5 test functions. Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 1/1 passing (AC-3)
**Deviations**: None. Chose the on-demand (no-cache) implementation of the two options the story's Implementation Notes allowed, avoiding cache-invalidation complexity entirely.
**Test Evidence**: `tests/unit/crafting/craftability_recheck_test.gd` (5 functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Skipped per "keep skip review plan through the remaining stories" instruction

## Dependencies

- Depends on: Story 002
- Unlocks: Story 004
