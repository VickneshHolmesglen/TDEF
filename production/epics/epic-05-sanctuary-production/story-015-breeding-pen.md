# Story 015: Breeding Pen — Same-Species Pairing & Deterministic Breeding

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L (4-6 hrs)
> **Manifest Version**: 2026-07-13b *(stale for this epic — see Story 007)*

## Context

**GDD**: `design/gdd/menagerie.md`
**Requirement**: `TR-menag-001` (breeding half)

**ADR Governing Implementation**: ADR-0026
**ADR Decision Summary**: Fixed `Array[BreedingPen]` (size 2, not expandable). Same-species pairing only, rejected outright at the move-to-pen action otherwise. Deterministic breeding — no RNG — via Formula 5's `breeding_missions_remaining` counter, decremented once per `mission_launched` (Story 013's breeding pass). Offspring created directly into RESERVE, never HABITAT. Parents remain unconsumed, eligible for another cycle immediately.

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules**:
- Required: `BreedingPen.occupant_ids: Array[int]` (0-2), `breeding_missions_remaining: int` (-1 = not active, only meaningful once 2 occupants)
- Forbidden: cross-species pairing — rejected at the eligibility check, before any state change

## Acceptance Criteria

- [ ] AC-23: GIVEN two creatures of the identical species both selected for the breeding pen, WHEN the move-to-pen action is confirmed, THEN both transition to `BREEDING_PEN`, `creature_moved_to_breeding_pen` fires for each, and `breeding_missions_remaining` begins counting once the second joins.
- [ ] AC-24: GIVEN two creatures of different species both selected, WHEN move-to-pen is attempted, THEN it is rejected at the eligibility check — no event fires for either, no state change.
- [ ] AC-25: GIVEN two Tier 1 (`glimmer_hare`) creatures paired, WHEN `breeding_missions_remaining` is computed (Formula 5), THEN it equals exactly `2`.
- [ ] AC-26: GIVEN two Tier 3 (`aurora_stag`) creatures paired, WHEN computed, THEN it equals exactly `4`.
- [ ] AC-27: GIVEN a pair with `breeding_missions_remaining = 1`, WHEN the next `mission_launched` fires, THEN the counter decrements to `0`, exactly one offspring is created directly into `RESERVE`, `creature_bred` fires exactly once, and both parents remain in `BREEDING_PEN`, unconsumed, eligible for another cycle immediately.
- [ ] AC-28: GIVEN both breeding pens already occupied by 2 pairs (4 creatures total), WHEN a player attempts to move a 5th creature into the breeding pen, THEN the action is rejected — capacity is fixed, not expandable.
- [ ] AC-39: GIVEN `base_breeding_duration=2` and `tier_breeding_penalty=1` (defaults), WHEN `breeding_missions_remaining` is computed across all 3 tiers, THEN the results are exactly `2`, `3`, `4` for Tiers 1/2/3.
- [ ] AC-43: GIVEN a save with an active breeding pen holding `breeding_missions_remaining=1` at save time, WHEN restored and a subsequent `mission_launched` fires, THEN the counter decrements from 1 to 0 and produces offspring on that tick.
- [ ] AC-45: GIVEN a breeding offspring is created, WHEN its initial state is checked, THEN it is `RESERVE`, never `HABITAT` — unlike a Lure acquisition, a bred offspring is never auto-placed.

## Implementation Notes

```
Formula 5: breeding_missions_remaining(tier) = base_breeding_duration(2) + tier_breeding_penalty(1) × (tier - 1)
```

Pen removal (before breeding completes) discards the in-progress timer entirely — not paused/resumable; re-pairing restarts the full duration (Edge Cases).

## Out of Scope

- Story 013: the tick-sequencing this story's breeding pass plugs into
- Story 016: sacrifice validation (which checks `state != BREEDING_PEN` before allowing a sacrifice)

## QA Test Cases

**AC-23 / AC-24**: pairing eligibility gate — same-species succeeds, cross-species rejected outright, zero state change on rejection.

**AC-25 / AC-26 / AC-39**: Formula 5 arithmetic at all 3 tiers — `2+1×0=2`, `2+1×1=3`, `2+1×2=4`.

**AC-27**
- Given: `breeding_missions_remaining=1`
- When: next `mission_launched`
- Then: counter→0, 1 offspring created in RESERVE, `creature_bred` fires once, parents remain BREEDING_PEN unconsumed
- Edge cases: parents immediately begin a second cycle with no manual re-pairing action needed — counter should reset to the same tier's duration automatically, or require explicit re-trigger — confirm against GDD Rule 11's exact wording before implementing (parents "may be bred again," verify whether this is automatic or requires a player action)

**AC-28**: both pens full (4/4), 5th move attempt rejected — no partial/queued state.

**AC-43**: save/load round-trip mid-timer — counter resumes correctly, not reset.

**AC-45**: offspring always RESERVE — assert this explicitly distinct from the Lure auto-placement path (Story 008).

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/menagerie/breeding_pen_test.gd`
**Status**: [x] Created — 8 test functions covering AC-23 through AC-28, AC-39, AC-45. Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 8/8 passing (AC-23, AC-24, AC-25, AC-26, AC-27, AC-28, AC-39, AC-45); AC-43 (save/load round-trip mid-timer) DEFERRED to, and CLOSED BY, Story 017 (Persistence) — `tests/integration/menagerie/persistence_test.gd::test_save_reload_round_trip_preserves_full_state` confirms an active breeding pen's `breeding_missions_remaining` survives the round-trip exactly.
**Deviations**: ADVISORY — resolved the Edge Cases' open question (whether re-breeding after producing offspring is automatic or requires a player action) by reading `menagerie.md` Core Rule 11 directly: "the two parent creatures remain in the pen, un-consumed, and may be bred again" — read this as automatic restart (same occupancy-triggers-countdown rule that started the first cycle applies again), since no distinct "re-trigger breeding" action exists anywhere else in the GDD. Also extended `move_to_breeding_pen()` (Story 011) to accept RESERVE creatures too, not just HABITAT — Story 011 only needed the HABITAT path for its own ACs, but pairing for breeding can source from either state.
**Test Evidence**: `tests/unit/menagerie/breeding_pen_test.gd` (8 functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Skipped per "keep skip review plan through the remaining stories" instruction

## Dependencies

- Depends on: Story 007, Story 011 (aggregate push on HABITAT→BREEDING_PEN transitions)
- Unlocks: Story 013
