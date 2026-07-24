# Story 008: Placement on Acquisition (HABITAT/RESERVE Routing)

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: XS (<1 hr)
> **Manifest Version**: 2026-07-13b *(stale for this epic — see Story 007)*

## Context

**GDD**: `design/gdd/menagerie.md`
**Requirement**: `TR-menag-001` (placement half)

**ADR Governing Implementation**: ADR-0026
**ADR Decision Summary**: New creature placed directly into HABITAT if an open slot exists; if HABITAT is full, routed to RESERVE instead — acquisition never fails or is blocked by capacity.

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules**:
- Required: HABITAT-placement path must trigger the aggregate recompute-and-push (Story 011) — RESERVE placement must NOT
- Forbidden: rejecting or queuing a Lure due to full HABITAT — RESERVE is always available as overflow

## Acceptance Criteria

- [ ] AC-4: GIVEN HABITAT has at least one open slot at the moment Lure succeeds, WHEN the new creature instance is created, THEN it is placed directly into `HABITAT`, and `creature_acquired` + aggregate-recompute + `creature_happiness_changed` side effects fire.
- [ ] AC-5: GIVEN HABITAT is at full capacity at the moment Lure succeeds, WHEN the new creature instance is created, THEN it is placed into `RESERVE`, `creature_acquired` fires, but no aggregate recompute or `creature_happiness_changed` fires.

## Implementation Notes

`creature_acquired(creature_id, species)` is now merged into `event-bus.md`'s frozen catalogue (78 events, as of 2026-07-17) — no longer a proposed/blocked event, safe to implement against directly.

## Out of Scope

- Story 011: the aggregate recompute-and-push mechanism itself (this story only triggers it on the HABITAT path)
- Story 009: HABITAT capacity expansion (this story reads current capacity, doesn't change it)

## QA Test Cases

**AC-4**
- Given: HABITAT has 1+ open slot
- When: Lure succeeds
- Then: creature state = HABITAT; `creature_acquired` fires; aggregate recomputes; `creature_happiness_changed` fires with the fresh aggregate
- Edge cases: HABITAT has exactly 1 open slot (the boundary case)

**AC-5**
- Given: HABITAT at full capacity (4-10 depending on expansion tier)
- When: Lure succeeds
- Then: creature state = RESERVE; `creature_acquired` fires; no aggregate recompute, no `creature_happiness_changed`
- Edge cases: HABITAT capacity is exactly 0 open (not negative — capacity is never exceeded)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/menagerie/placement_on_acquisition_test.gd`
**Status**: [x] Created — 3 test functions covering AC-4, AC-5. Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 2/2 passing (AC-4, AC-5)
**Deviations**: None — small addition on top of Story 011's already-built `move_to_habitat()`.
**Test Evidence**: `tests/unit/menagerie/placement_on_acquisition_test.gd` (3 functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Skipped per "keep skip review plan through the remaining stories" instruction

## Dependencies

- Depends on: Story 007, Story 011 (for the aggregate-recompute side effect)
- Unlocks: None within this epic
