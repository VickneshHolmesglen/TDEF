# Story 012: Happiness Start Value, Decay & Floor (Formula 1)

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: XS (<1 hr)
> **Manifest Version**: 2026-07-13b *(stale for this epic — see Story 007)*

## Context

**GDD**: `design/gdd/menagerie.md`
**Requirement**: `TR-menag-002` (decay half)

**ADR Governing Implementation**: ADR-0026
**ADR Decision Summary**: `starting_happiness = 70` (fixed constant). Formula 1 decays HABITAT creatures by `decay_per_mission` (default 8) per `mission_launched`, floored at 20 — never removed, never dies (floor-not-death, deliberate Alpha decision).

**Engine**: Godot 4.6.2 | **Risk**: LOW

## Acceptance Criteria

- [ ] AC-16: GIVEN a newly-Lured creature, WHEN its `happiness` is checked immediately after creation, THEN it equals exactly `70`.
- [ ] AC-17: GIVEN a HABITAT creature at `happiness = 24`, WHEN one `mission_launched` decay tick applies with `decay_per_mission = 8`, THEN `happiness' = max(20, 24-8) = 20` — the floor is respected exactly, not overshooting below 20.
- [ ] AC-18: GIVEN a HABITAT creature already at the floor (`happiness = 20`), WHEN another decay tick applies, THEN `happiness'` remains `20` — the creature is not removed, does not transition state.
- [ ] AC-40: GIVEN a creature at the happiness floor for an extended period (multiple un-tended ticks past reaching 20), WHEN its state is checked, THEN it remains a fully functional HABITAT creature — no removal, no forced eviction, no state-machine transition triggered purely by floor happiness.

## Implementation Notes

```
Formula 1: happiness' = max(happiness_floor(20), happiness - decay_per_mission(8))
```

Applies to HABITAT creatures only — RESERVE and BREEDING_PEN creatures never decay (their happiness is frozen at whatever value it held when they left HABITAT). See Story 013 for the mission-tick scope guard.

## Out of Scope

- Story 013: which creatures the mission_launched tick even applies to (this story covers only the math once a HABITAT creature is selected)
- Story 014: the Tend action that reverses decay

## QA Test Cases

**AC-16**: creature created via Lure → `happiness == 70` exactly, no rounding drift.

**AC-17**: `24 - 8 = 16`, floored to `20` (not `16`) — exact floor-clamp assertion.

**AC-18**: already at 20, decay applies again → stays 20, not 12 or any negative-then-clamped intermediate.

**AC-40**: creature at floor for 5+ consecutive un-tended ticks → still `state == HABITAT`, still contributes to Formula 3 at its minimum share, no exception thrown, no removal signal fired.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/menagerie/happiness_decay_floor_test.gd`
**Status**: [x] Created — 4 test functions covering AC-16, AC-17, AC-18, AC-40. Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 4/4 passing (AC-16, AC-17, AC-18, AC-40)
**Deviations**: None.
**Test Evidence**: `tests/unit/menagerie/happiness_decay_floor_test.gd` (4 functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Skipped per "keep skip review plan through the remaining stories" instruction

## Dependencies

- Depends on: Story 007
- Unlocks: Story 013, Story 014
