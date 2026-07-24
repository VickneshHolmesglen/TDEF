# Story 009: Quality Tier Roll & Menagerie Bonus Scope

> **Epic**: Epic 03 — Core Economy
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/resource-economy.md`
**Requirement**: `TR-econ-???` *(no TR-ID exists yet)*

**ADR Governing Implementation**: ADR-0017 (Resource Economy Drop Resolution)
**ADR Decision Summary**: `_menagerie_quality_bonus` (ADR-0017's sole cached scalar) applies only to the quantity term per the GDD's Rule 3 — ADR-0017 does not alter this reconciliation, only confirms the node architecture that hosts it.

**Engine**: Godot 4.6.2 / GDScript | **Risk**: Unassessed
**Engine Notes**: None yet.

**Control Manifest Rules (this layer)**:
- Required (Global Rules): gameplay values must be data-driven — `quality_probability_ceiling` and `base_quality_probability` must come from data/config, never hardcoded inline

---

## Acceptance Criteria

*From GDD `design/gdd/resource-economy.md`, scoped to this story:*

- [x] **AC-03**: GIVEN `base_quality_probability=0.20`, `wave_reward_scalar=4.768` (raw product 0.954), WHEN the quality roll probability is computed, THEN the used probability is clamped to `0.80`.
- [x] **AC-04**: GIVEN `menagerie_quality_bonus=1.5`, WHEN a kill resolves both terms, THEN quantity reflects the 1.5× factor but the quality-probability calculation does not include it.

---

## Implementation Notes

*Derived from ADR-0017:* this is the story that implements the deliberate quantity/quality asymmetry: quality is a probability (naturally bounded 0-1), quantity is an unbounded multiplier. Do not "simplify" by applying `_menagerie_quality_bonus` to both terms — the GDD is explicit that this is wrong (Rule 3: "not the quality-probability term").

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: quantity formula and drop-occurrence roll
- Story 010: drop table schema (`base_quality_probability` is read from `DropEntry` data, sourced there)

---

## QA Test Cases

- **AC-03**: Quality probability ceiling clamp
  - Given: `base_quality_probability=0.20`, `wave_reward_scalar=4.768` (raw product = 0.954)
  - When: the quality roll probability is computed
  - Then: the used probability is clamped to 0.80, not the raw 0.954
  - Edge cases: verify a combination that stays *under* the ceiling (e.g., `base_quality_probability=0.10` at wave 8 → 0.477) is NOT clamped — confirm the clamp only activates when actually exceeded

- **AC-04**: Menagerie bonus applies to quantity only
  - Given: `menagerie_quality_bonus=1.5`
  - When: a kill resolves both the quantity and quality terms
  - Then: the quantity calculation includes the 1.5× factor; the quality-probability calculation does not
  - Edge cases: a regression test should explicitly assert the quality-probability output is *identical* with and without a Menagerie bonus present, to catch an accidental future coupling of the two terms

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/resource_economy/quality_roll_menagerie_scope_test.gd` — must exist and pass

**Status**: [x] Created — 7/7 passing (766/766 full project suite, live-verified, Godot 4.6.2.stable headless)

---

## Dependencies

- Depends on: Story 010 (drop table schema)
- Unlocks: None currently identified

---

## Completion Notes

**Completed**: 2026-07-16
**Criteria**: 2/2 passing (AC-03, AC-04)
**Deviations**: Advisory only
- Computes Formula 3's probability but doesn't perform a roll/surface a result — no consumer exists yet (Story 011/012). Deliberate scope boundary.
- Stale doc-comment usage example ("0.477" vs. corrected "0.4768") — cosmetic.
**Test Evidence**: Logic — `tests/unit/resource_economy/quality_roll_menagerie_scope_test.gd`, 7/7 passing
**Code Review**: Complete — verdict APPROVED WITH SUGGESTIONS (`/code-review`, 2026-07-16; both specialist review agents hit an external weekly API limit mid-task, substituted with orchestrator's own direct math/trace verification)
