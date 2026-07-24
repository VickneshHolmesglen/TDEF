# Story 006: Placement-Only Formation & Edge Cases

> **Epic**: Epic 06 — Mission Combat Extensions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/constellation.md`
**Requirement**: `TR-const-001`

**ADR Governing Implementation**: ADR-0022 (Constellation Pattern-Detection Data Structure)
**ADR Decision Summary**: New pattern instances can only ever form as a result of `tower_placed` (restricted to SCOUT/INTERMISSION by `tower.md`). Instances can break via `tower_removed` (SCOUT/INTERMISSION only) or `tower_destroyed` (any phase, including WAVE_ACTIVE). Constellation enforces no phase gating of its own — it is a pure consequence of which events Tower emits when.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No new engine subsystem — this story is pure event-ordering/state-machine logic on top of the structures built in Stories 001–003.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0022/constellation.md Core Rule 9 directly.
- Forbidden: Never let a `tower_removed` event complete a shape — vacating a cell can only break an instance, never complete one.
- Guardrail: No partial-pattern state is retained across a remove-then-replace-elsewhere sequence — each `tower_placed` triggers a fresh, independent, localized recheck.

---

## Acceptance Criteria

*From GDD `design/gdd/constellation.md`, scoped to this story:*

- [x] AC-18 — Removal alone can never simultaneously complete a shape
- [x] AC-19 — `tower_destroyed` breaks an active instance during WAVE_ACTIVE
- [x] AC-27 — N-1-then-remove-and-replace-elsewhere fires no deactivation (nothing was ever active)

---

## Implementation Notes

*Derived from ADR-0022 Implementation Guidelines / constellation.md Core Rule 9:*

- Formation logic (Story 001/002) is only ever invoked from the `tower_placed` handler — never from `tower_removed`. This is a structural guarantee, not a runtime check: the removal handler only ever calls `_deactivate_instance()`, never the shape-matching path.
- `tower_destroyed` uses the same deactivation path as `tower_removed` (Story 003) and is not phase-gated by Constellation itself — if it fires during `WAVE_ACTIVE`, the instance still deactivates immediately.
- If N-1 of N required towers are placed (no instance ever reached `ACTIVE`) and one of the N-1 is removed and re-placed elsewhere, no `constellation_deactivated` fires (nothing was ever active to deactivate) — the re-placement triggers only its own fresh, independent, localized recheck from its new cell.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: shape/orientation matching itself
- Story 003: the reverse-index deactivation mechanics this story's edge cases build on

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-18**: Removal cannot complete a shape
  - Given: `(2,4)`,`(3,4)` occupied by identically-tagged eligible towers, a third differently-tagged tower occupies `(4,4)` (blocking `triad_line`)
  - When: the blocking tower at `(4,4)` is removed via `tower_removed`
  - Then: no `constellation_activated` fires from that removal event

- **AC-19**: `tower_destroyed` breaks an active instance during WAVE_ACTIVE
  - Given: an `ACTIVE` `quad_line@(3,5)` instance formed during a prior SCOUT phase, current mission phase is `WAVE_ACTIVE`
  - When: `tower_destroyed` fires for a member tower
  - Then: `constellation_deactivated("quad_line@(3,5)", "tower_destroyed")` emits regardless of current phase

- **AC-27**: N-1-then-remove-and-replace fires no deactivation
  - Given: `(2,4)`,`(3,4)` occupied by identically-tagged eligible towers (2 of 3 needed, no instance ever `ACTIVE`)
  - When: the tower at `(3,4)` is removed via `tower_removed`, then a same-tag eligible tower is placed at unrelated cell `(10,10)` via `tower_placed`
  - Then: no `constellation_deactivated` emits at any point in the sequence; the `(10,10)` placement triggers only its own independent, localized recheck

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/constellation/placement-only-formation-edge-cases_test.gd` — 3 tests covering AC-18/19/27. All passing.

**Status**: [x] Created and passing (2026-07-19). Full project regression re-run: 1118/1119 (the sole failure is the same pre-existing, unrelated Menagerie `CreatureInstance.CreatureState` enum-value mismatch, `TD-menag-006` — untouched by this story).

---

## Dependencies

- Depends on: Story 001 (DONE), Story 003 (DONE)
- Unlocks: None further within this epic — completes Constellation's core Logic/Integration coverage

**Unblocked**: ADR-0022 accepted 2026-07-18 (Sprint 6, S6-02).

**Implemented (2026-07-19, Sprint 7)**: same pattern as Stories 004/005 — production code already satisfied every AC structurally: `_on_tower_removed`/`_on_tower_destroyed` only ever call `_handle_tower_departed()` → `_deactivate_instance()`, never the shape-matching path, so removal/destruction can never complete a shape (AC-18) and `tower_destroyed` deactivates unconditionally regardless of phase since Constellation reads no phase state at all (AC-19). AC-27 falls out for the same reason: a tower never part of `_tower_membership` produces an empty `affected` list, so nothing deactivates. Only the test file was missing. One authoring correction made while writing it: the AC-19 fixture (a `quad_line`) also intrinsically forms 2 overlapping `triad_line` sub-instances sharing the destroyed tower (Core Rule 6/AC-26, the same precedent already documented in the other 3 Constellation test files) — the test filters deactivation by `pattern_id` rather than asserting a raw count of 1. No production code changes were needed. Full regression 1118/1119 (same pre-existing unrelated `TD-menag-006` failure).
