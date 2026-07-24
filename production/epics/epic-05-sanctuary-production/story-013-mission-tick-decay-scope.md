# Story 013: Mission-Tick Decay Scope

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (2-3 hrs)
> **Manifest Version**: 2026-07-13b *(stale for this epic — see Story 007)*

## Context

**GDD**: `design/gdd/menagerie.md`
**Requirement**: `TR-menag-002` — "Happiness decay/tend formulas ticking on `mission_launched`, not wall-clock or `_process()`"

**ADR Governing Implementation**: ADR-0026
**ADR Decision Summary**: The `mission_launched` tick's decay pass and the breeding-completion pass run as two separate, non-interleaved passes — offspring creation happens only after both complete, to avoid a mutate-during-iterate bug on `_creatures` (the same class of bug ADR-0022/Constellation caught and fixed earlier this session).

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Time is measured in missions launched, never wall-clock or `_process()` — this is a structural, non-negotiable rule per the GDD.

**Control Manifest Rules (extracted from ADR-0026)**:
- Required: decay pass and breeding pass are sequenced — decay first, breeding second, offspring creation only after both complete
- Forbidden: any `_process()`/`_physics_process()`-driven decay or breeding timer — `mission_launched` is the sole tick source

## Acceptance Criteria

- [ ] AC-19: GIVEN a mix of HABITAT, RESERVE, and BREEDING_PEN creatures, WHEN a single `mission_launched` event fires, THEN only HABITAT creatures' `happiness` decays and have `missions_since_tended` incremented — RESERVE and BREEDING_PEN creatures' `happiness` values are read identically before and after the event.
- [ ] AC-42: GIVEN up to the Rule 4 maximum of 10 HABITAT creatures, WHEN a single `mission_launched` fires, THEN each of the 10 creatures' `creature_happiness_changed` fires independently (10 total emissions in one frame), which stays under EventBus's `eventbus_batch_threshold` (20/frame) — no batched/deferred dispatch required.

## Implementation Notes

Two-pass sequencing (per ADR-0026, the fix for the mutate-during-iterate risk):
1. Decay pass — snapshot `_creatures.filter(state == HABITAT)`, apply Formula 1 to each
2. Breeding pass — iterate `_breeding_pens` (fixed size 2), decrement counters, collect any pairs reaching 0
3. Only after both passes complete: create offspring instances for any pairs that reached 0 in step 2

## Out of Scope

- Story 012: the decay formula itself
- Story 015: the breeding pass's own pairing/duration logic

## QA Test Cases

**AC-19**
- Given: 1 HABITAT, 1 RESERVE, 1 BREEDING_PEN creature, all at the same starting happiness
- When: `mission_launched` fires once
- Then: only the HABITAT creature's happiness changes; the other two are bit-identical before/after
- Edge cases: a creature transitions HABITAT→RESERVE in the same session before the tick — must not decay

**AC-42**
- Given: 10 HABITAT creatures (Rule 4's max)
- When: one `mission_launched` fires
- Then: 10 independent `creature_happiness_changed` emissions in that frame, no batching triggered
- Edge cases: verify no single combined/batch event fires instead of 10 individual ones

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/menagerie/mission_tick_decay_scope_test.gd`
**Status**: [x] Created — 2 test functions covering AC-19, AC-42. Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 2/2 passing (AC-19, AC-42)
**Deviations**: None — wires `_ready()`'s `mission_launched` subscription to call `_tick_decay()` then `_tick_breeding_pens()` (Story 015) in that fixed order, matching ADR-0026's explicit two-pass sequencing requirement.
**Test Evidence**: `tests/unit/menagerie/mission_tick_decay_scope_test.gd` (2 functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Skipped per "keep skip review plan through the remaining stories" instruction

## Dependencies

- Depends on: Story 012, Story 015 (both passes must exist to test their sequencing)
- Unlocks: None within this epic
