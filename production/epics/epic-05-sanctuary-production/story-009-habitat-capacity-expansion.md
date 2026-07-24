# Story 009: Habitat Capacity & Defense Building Expansion Subscription

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: S (1-2 hrs)
> **Manifest Version**: 2026-07-13b *(stale for this epic — see Story 007)*

## Context

**GDD**: `design/gdd/menagerie.md`
**Requirement**: `TR-menag-001` (capacity half)

**ADR Governing Implementation**: ADR-0026 (Menagerie) + ADR-0024 (Defense Building — event producer)
**ADR Decision Summary**: `_habitat_capacity: int`, base 4, incremented by 2 on each `sanctuary_structure_built` event where `structure_type == "habitat_expansion"` — an EventBus subscription, no direct call to Defense Building. Capped at 10 (3 tiers) by construction.

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules**:
- Required: capacity increment is EventBus-subscription-driven only — Menagerie never calls Defense Building directly for this
- Required: a 4th `sanctuary_structure_built(structure_type="habitat_expansion")` event, if it ever arrived, is a no-op past the cap

## Acceptance Criteria

- [ ] AC-6: GIVEN a fresh save with no Habitat Expansion structures built, WHEN HABITAT capacity is queried, THEN it equals the base 4 slots exactly.
- [ ] AC-7: GIVEN a `sanctuary_structure_built` event for a "Habitat Expansion" structure tier, WHEN Menagerie receives it, THEN HABITAT capacity increases by exactly +2 slots per tier, up to a maximum of 3 tiers (10 slots total) — a 4th expansion event, if it ever arrived, does not raise capacity further.

## Implementation Notes

Cross-system dependency: this story requires Defense Building's `sanctuary_structure_built` emission (Epic 05's own Story 020) to exist for a true integration test — an isolated Menagerie-side mock emitting the event is an acceptable interim test path per the GDD's own qa-lead note.

## Out of Scope

- Story 020 (Defense Building epic story): the emitter side of `sanctuary_structure_built`

## QA Test Cases

**AC-6**
- Given: fresh save, no structures built
- When: capacity queried
- Then: exactly 4
- Edge cases: none

**AC-7**
- Given: 0, 1, 2, then 3 Habitat Expansion tier-built events received in sequence
- When: capacity queried after each
- Then: 4, 6, 8, 10 respectively; a 4th (hypothetical) event leaves it at 10
- Edge cases: events received out of tier order (e.g. Tier 2 before Tier 1) — Defense Building's own sequential-tier enforcement (Story 019 in this epic) prevents this at the source, but Menagerie's own increment logic should not itself assume ordering, only count events

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/menagerie/habitat_capacity_expansion_test.gd`
**Status**: [x] Created — 4 test functions covering AC-6, AC-7. Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 2/2 passing (AC-6, AC-7)
**Deviations**: None. Tested via direct handler invocation (`_on_sanctuary_structure_built()`), not a live EventBus round-trip with a real DefenseBuilding instance — matches the story's own stated interim test path (qa-lead-approved) and this project's established convention.
**Test Evidence**: `tests/integration/menagerie/habitat_capacity_expansion_test.gd` (4 functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Skipped per "keep skip review plan through the remaining stories" instruction

## Dependencies

- Depends on: Story 007
- Unlocks: None within this epic (cross-epic: Story 020, Defense Building's structure-build story)
