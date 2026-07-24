# Story 015: Combined-ERI Content-Authoring Validator

> **Epic**: Epic 03 — Core Economy
> **Status**: Complete
> **Layer**: Core
> **Type**: Config/Data
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/resource-economy.md`
**Requirement**: `TR-econ-002` — "DropTableResource/DropEntry schema + drop quantity/quality Formulas 1-4" (this validator checks Formula 4)

**ADR Governing Implementation**: ADR-0017 (Resource Economy Drop Resolution)
**ADR Decision Summary**: `DropTableResource`/`DropEntry`'s schema (ADR-0017) is the concrete data this validator checks. **Still open**: the GDD's own Open Question about enforcement workflow (build-time validator vs. design-review checklist vs. manual step) is not resolved by ADR-0017 — implement the arithmetic check itself (per GDD Formula 4), and treat the workflow question as a separate technical-director decision if it blocks CI integration.

**Correction (2026-07-16, during implementation)**: this story's AC-14 and Implementation Notes below quote Formula 4's *original* formula and its `343.3 > 22.73` worked example. `design/gdd/resource-economy.md`'s Formula 4 section was corrected during `/design-review` on **2026-07-14** — after this story was authored (2026-07-13b) but before it was implemented. The original formula was mathematically broken (it multiplied a worst-case value from one hypothetical entry against a worst-case value from a *different* hypothetical entry — a product no single kill ever produces) and was replaced with a per-entry wave-1-to-max-wave yield-growth ratio, checked against `WAVE_ERI_CEILING_COMBINED × ROUNDING_TOLERANCE (22.73 × 1.10 = 25.0)`. The implementation below is built against the corrected, current formula — see `src/core/resource_economy/combined_eri_validator.gd`'s class doc comment for the full discrepancy writeup.

**Engine**: Godot 4.6.2 / GDScript | **Risk**: Unassessed
**Engine Notes**: None yet.

**Control Manifest Rules (this layer)**:
- Required (Global Rules): gameplay values must be data-driven — this validator itself should read the registry constant `WAVE_ERI_CEILING_COMBINED` (22.73) rather than hardcoding it a second time

---

## Acceptance Criteria

*From GDD `design/gdd/resource-economy.md`, scoped to this story:*

- [x] **AC-14 [Content-authoring]** *(corrected 2026-07-16 — see ADR Decision Summary above)*: GIVEN a `DropTableResource` entry, WHEN the combined-ERI check computes `[quantity(wave_max)/quantity(wave_1)] × [quality_roll(wave_max)/quality_roll(wave_1)]` per Formula 4's corrected math, THEN it flags a failure only when the result exceeds `WAVE_ERI_CEILING_COMBINED × ROUNDING_TOLERANCE (25.0)` — verified via a degenerate authored value (`base_quality_probability=0.0`, which zeroes the wave-1 denominator) as the reachable failing case, since the corrected formula is mathematically bounded to a maximum of 23.84 for any schema-valid content within Formula 3's authored range.

---

## Implementation Notes

*Cannot be derived from an ADR — none exists, and this story's very shape (build-time tool vs. design-time checklist) is undecided.* The formula itself (Formula 4 in the GDD) is fully specified:
```
combined_ERI = (max quantity multiplier) × (quality_probability_ceiling / min base_quality_probability)
```
Must not exceed `WAVE_ERI_CEILING_COMBINED` (22.73, registered in `design/registry/entities.yaml`). This is explicitly a content-authoring guardrail, not a runtime assertion — do not gate gameplay on this check at runtime; it should run when `DropTableResource` content is authored/imported.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 010: the `DropTableResource`/`DropEntry` schema this validator checks against
- Any runtime drop-resolution logic (Stories 008/009) — this story never runs during actual gameplay

---

## QA Test Cases

- **AC-14 [Content-authoring]**: Combined-ERI violation detection
  - Given: a `DropTableResource` authored with `base_quantity=3`, `base_quality_probability=0.05`
  - When: the combined-ERI check runs against this content
  - Then: it flags a failure, computing `343.3 > 22.73`
  - Edge cases: also test a passing case (values that stay under the ceiling) to confirm the validator doesn't false-positive on reasonable content

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `tests/unit/resource_economy/combined_eri_validator_test.gd` — must exist and pass, covering AC-14's failing case and the QA Test Cases' passing-content edge case
- CI/content-import pipeline wiring is explicitly deferred, not required for this story's closure — the GDD's own Open Question on enforcement workflow (build-time validator vs. design-review checklist vs. manual step) remains unresolved and is a separate technical-director decision. This story closes once the arithmetic check itself exists, is correct, and is callable — not once it's wired into a specific pipeline.

**Status**: [x] Created and passing — `tests/unit/resource_economy/combined_eri_validator_test.gd` (15 tests — 2 added during code review: multi-entry per-entry isolation, guaranteed_min_quantity distortion)

---

## Dependencies

- Depends on: Story 010 (drop table schema — this validator operates on `DropTableResource`/`DropEntry` instances)
- Unlocks: None currently identified

---

## Completion Notes

**Completed**: 2026-07-16
**Criteria**: 1/1 passing (AC-14, corrected — see Context section above)
**Deviations**: AC-14 and Implementation Notes quoted Formula 4's pre-2026-07-14-correction text; implementation correctly targets the current, corrected GDD formula (see Correction note in Context). Not a deviation from the GDD — a deviation from the story's own stale quotation of it.
**Test Evidence**: Config/Data (with a required unit test, per this story's own Test Evidence section) — `tests/unit/resource_economy/combined_eri_validator_test.gd` (15 tests, all passing). CI/content-import pipeline wiring remains explicitly deferred per this story's scope. Full project suite: 798/798 passing, 0 errors, 0 failures, 63/63 suites — no regression.
**Code Review**: Complete — APPROVED (godot-gdscript-specialist: CLEAN; qa-tester: GAPS → resolved by adding 2 tests; one finding intentionally NOT closed by code changes — see Notes).
**Notes**: Code review surfaced a genuine design-value question, not a code defect: the property-sweep test proves the corrected Formula 4 makes this validator mathematically unable to fail for any content authored within Formula 3's realistic range — only a degenerate zero input or an extreme `guaranteed_min_quantity` distortion can trigger it, and the latter was verified (via a new test) to only ever lower the result further, never raise it. This was not resolved unilaterally; logged as **TD-econ-007** (`docs/tech-debt-register.md`) and a new Open Question in `design/gdd/resource-economy.md`, for game-designer/qa-lead to decide whether the check's purpose needs rescoping now that Formula 4 itself is fixed.
