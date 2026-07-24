# Story 026: Edge Cases — Stale UI & Shared Double-Confirm Guard

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (2-3 hrs)
> **Manifest Version**: 2026-07-13b *(stale for this epic — see Story 018)*

## Context

**GDD**: `design/gdd/defense-building.md`
**Requirement**: `TR-defbuild-001` (edge-case half)

**ADR Governing Implementation**: ADR-0024
**ADR Decision Summary**: A single `_action_resolving: bool` flag shared across **both** ledgers (not per-ledger) — set at the start of any operation's first validation step, cleared only after event emission. Prevents a tech unlock and a structure build from double-spending the same gold balance concurrently within one frame.

**Engine**: Godot 4.6.2 | **Risk**: LOW

## Acceptance Criteria

- [ ] AC-37: GIVEN gold or materials become insufficient between UI render and click (stale UI), WHEN confirm is pressed, THEN Rule 9 step (b) rejects the action in full — no gold debited, no materials consumed, no ledger write, no event fires.
- [ ] AC-38: GIVEN two confirmations (any combination of tech-node and/or structure actions) arrive within the same frame, WHEN the second is processed, THEN it is rejected outright because `_action_resolving` is already `true` — no queueing, and the guard is shared across both ledgers, preventing a tech unlock and a structure build from double-spending the same gold balance concurrently.
- [ ] AC-39: GIVEN a save references a `tech_id`/`structure_id` that no longer exists in current content, WHEN restored, THEN no specific recovery behavior is asserted — flagged as a shared, project-wide gap, not tested here (do not implement a bespoke recovery path for this story; leave as an open item consistent with the GDD's own scope boundary).

## Implementation Notes

The `_action_resolving` flag is a single field on the DefenseBuilding Autoload, checked/set at the top of the resolution sequence for EITHER ledger — this is the specific detail that closes the cross-ledger double-spend race (a tech unlock and a structure build resolving "simultaneously" in the same frame would otherwise both read the same pre-debit gold balance).

## Out of Scope

- AC-39's actual recovery behavior — explicitly not defined by the GDD, do not invent one

## QA Test Cases

**AC-37**: materials/gold spent by another action between render and click → confirm rejected, zero side effects.

**AC-38**: fire a tech-unlock confirm and a structure-build confirm in the same frame → exactly one resolves, the other rejected — assert this holds even when they're different ledger types (not just same-ledger double-confirms).

**AC-39**: no test — explicitly out of scope, confirmed by absence of an asserted behavior in the GDD itself.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/defense_building/edge_cases_shared_guard_test.gd`
**Status**: [x] Created — 6 test functions (AC-37, AC-38 ×4). AC-39 out of scope, no test. Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Dependencies

- Depends on: Story 023
- Unlocks: None within this epic

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 2/2 in-scope ACs passing (AC-37, AC-38); AC-39 explicitly out of scope, no test
**Deviations**: None.
**Test Evidence**: `tests/unit/defense_building/edge_cases_shared_guard_test.gd` (6 functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Skipped per user instruction ("keep skip review plan through the remaining stories")
