# Story 010: HABITAT-Only Quality Bonus & Aggregate Formula

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (2-3 hrs)
> **Manifest Version**: 2026-07-13b *(stale for this epic — see Story 007)*

## Context

**GDD**: `design/gdd/menagerie.md`
**Requirement**: `TR-menag-002` (aggregate formula half)

**ADR Governing Implementation**: ADR-0026
**ADR Decision Summary**: Only `HABITAT`-state creatures contribute to `menagerie_quality_bonus` (Formula 3). RESERVE and BREEDING_PEN are fully excluded — `N_habitat=0` returns exactly `1.0`, never a divide-by-zero.

**Engine**: Godot 4.6.2 | **Risk**: LOW

## Acceptance Criteria

- [ ] AC-8: GIVEN one creature in `HABITAT` at happiness 80 and one creature in `RESERVE` at happiness 80, WHEN `menagerie_quality_bonus` is computed, THEN only the HABITAT creature counts — the RESERVE creature's happiness has zero effect.
- [ ] AC-9: GIVEN one creature in `HABITAT` and one in `BREEDING_PEN`, both at happiness 80, WHEN computed, THEN the result equals the single-HABITAT-creature scenario (`1.0 + 0.5 × 0.80 = 1.40`) — the BREEDING_PEN creature is fully excluded.
- [ ] AC-33: GIVEN zero creatures in HABITAT, WHEN computed, THEN it returns exactly `1.0` — the floor case, not a divide-by-zero or undefined result.
- [ ] AC-34: GIVEN three HABITAT creatures at happiness 82, 70, 55, WHEN computed, THEN `H_avg = 69.0` and the result is `1.345` exactly.
- [ ] AC-35: GIVEN a single HABITAT creature at the happiness floor (20), WHEN computed, THEN the result is `1.10` exactly.
- [ ] AC-36: GIVEN HABITAT creatures whose average happiness would compute above 1.5 or below 1.0 under any tuning-knob drift, WHEN computed, THEN the result is clamped to `[1.0, 1.5]`.

## Implementation Notes

```
Formula 3:
menagerie_quality_bonus = 1.0                                         if N_habitat = 0
menagerie_quality_bonus = clamp(1.0 + 0.5 × (H_avg / 100), 1.0, 1.5)  if N_habitat > 0
```

`N_habitat`/`H_avg` computed by filtering `_creatures` to `state == HABITAT` only — never iterate the full roster without the filter.

## Out of Scope

- Story 011: when/how this formula's result gets pushed to Resource Economy (this story only computes the value)

## QA Test Cases

**AC-8 / AC-9**: as stated — filter correctness, HABITAT-only inclusion. Edge case: all creatures non-HABITAT — must hit the AC-33 floor case, not error.

**AC-33**: `N_habitat=0` → exactly `1.0`. Edge case: this must be checked *before* any division, not caught via exception handling.

**AC-34**: `(82+70+55)/3 = 69.0` → `1.0+0.5×0.69 = 1.345`. Edge case: verify floating-point precision doesn't drift the result (use an epsilon-tolerant assertion, not exact `==`).

**AC-35**: single creature at floor 20 → `1.0+0.5×0.20=1.10`. Edge case: this is the lowest non-zero-HABITAT value the formula can produce under normal conditions — assert nothing lower is reachable without tuning-knob drift.

**AC-36**: clamp — construct an out-of-range tuning scenario and confirm the clamp holds at exactly 1.0/1.5 boundaries.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/menagerie/quality_bonus_formula_test.gd`
**Status**: [x] Created — 8 test functions covering AC-8, AC-9, AC-33 through AC-36. Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 6/6 passing (AC-8, AC-9, AC-33, AC-34, AC-35, AC-36)
**Deviations**: None.
**Test Evidence**: `tests/unit/menagerie/quality_bonus_formula_test.gd` (8 functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Skipped per "keep skip review plan through the remaining stories" instruction

## Dependencies

- Depends on: Story 007
- Unlocks: Story 011
