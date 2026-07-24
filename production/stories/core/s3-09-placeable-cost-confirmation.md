# S3-09 — PLACEABLE Cost Design Confirmation

**Story ID**: S3-09
**Epic**: Core
**Layer**: Core (design decision)
**Type**: Config/Data
**Owner**: game-designer
**Sprint**: 3
**Estimate**: 0.25 days
**Status**: Complete
**Manifest Version**: 2026-05-16

## TR Coverage

None — design decision that feeds TR-pathfinding-PLACEABLE (advisory).

## ADR Governing Implementation

`docs/architecture/adr-0004-pathfinding-strategy.md` (Accepted) — PLACEABLE cell cost defined
at 10.0; value marked as advisory pending designer confirmation.

## Background

From Sprint 2 QA sign-off conditions:

> *"PLACEABLE cost advisory (advisory — not a blocker): The A* pathfinding system uses a
> PLACEABLE cost of 10.0 to make monsters prefer PATH cells over PLACEABLE cells. The
> acceptable threshold (how many PATH-cell detours a monster will take before a PLACEABLE
> shortcut becomes preferred) has not been confirmed by the game designer. Must be confirmed
> before the Vertical Slice gate."*

This story closes that advisory item before VS gate.

## Acceptance Criteria

- [ ] Game designer has confirmed (or adjusted) the PLACEABLE cost value of 10.0
- [ ] Decision is documented in one of:
  - `design/quick-specs/placeable-cost-confirmation.md` (new file), OR
  - An annotation added to `design/gdd/pathfinding.md` Tuning Knobs section
- [ ] If value changes from 10.0: `src/foundation/pathfinding/pathfinding_system.gd` constant
  `PLACEABLE_COST` is updated; existing pathfinding tests still pass
- [ ] Sprint 2 QA sign-off advisory item 3 marked closed in `production/qa/qa-signoff-sprint-02-2026-06-30.md`

## The Design Question

Monsters use A* with two cell costs:
- `PATH` cells: cost = 1.0 (strongly preferred)
- `PLACEABLE` cells: cost = 10.0 (heavily penalised)

A monster will walk up to 9 extra PATH-cell steps before it prefers a PLACEABLE shortcut.

**Question for game designer**: Is "9 extra steps before taking a shortcut through PLACEABLE"
the right threshold? Consider:
- Too low (cost = 2.0): monsters constantly cut through tower placement zones, making placement ineffective
- Too high (cost = 50.0): monsters never use shortcuts even when they should; pathfinding takes longer
- Current (cost = 10.0): monsters absorb 9 extra steps; this feels like the mid-game "forcing" threshold

## Files to Create or Modify

- `design/quick-specs/placeable-cost-confirmation.md` (if new file approach)
- OR annotation to `design/gdd/pathfinding.md` Tuning Knobs
- `production/qa/qa-signoff-sprint-02-2026-06-30.md` (add closure note)
- If value changes from 10.0: `src/foundation/pathfinding/pathfinding_system.gd` (`PLACEABLE_COST` constant)

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: Decision doc exists; if PLACEABLE_COST changed, pathfinding tests still pass

**Status**: [x] Confirmed 2026-07-06

## Dependencies

- Depends on: None
- Unlocks: Pre-Production → Production gate (QA condition 3 of 3 closed)

---

## Completion Notes
**Completed**: 2026-07-06
**Criteria**: 4/4 passing. PLACEABLE cost confirmed as-is at 10.0 — no code change needed (`PLACEABLE_COST` in `src/foundation/pathfinding/pathfinding_system.gd` unchanged). Decision documented as an annotation to `design/gdd/pathfinding.md`'s `pathfinding_placeable_cost` Tuning Knob row (chose the GDD-annotation option over a new `design/quick-specs/` file, keeping the decision co-located with the value it governs). Sprint 2 QA sign-off advisory item 3 marked CLOSED in `production/qa/qa-signoff-sprint-02-2026-06-30.md`.
**Deviations**: Advisory only — two stale file-path references found and fixed during story-readiness: the ADR reference (`adr-0004-pathfinding-system.md` → real file is `adr-0004-pathfinding-strategy.md`) and the source-file reference (`pathfinding.gd` → real file is `pathfinding_system.gd`).
**Test Evidence**: Config/Data — no code changed, so no test re-run required. Decision doc exists at the GDD location above.
**Code Review**: Skipped — no code changed (pure design-decision/documentation story).
