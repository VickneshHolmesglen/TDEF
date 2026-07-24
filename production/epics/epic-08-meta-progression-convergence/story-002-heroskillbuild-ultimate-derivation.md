# Story 002: Ultimate Derivation & Combinatorial Tractability Proof

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/hero-skill-build.md`
**Requirement**: `TR-heroskill-001`

**ADR Governing Implementation**: ADR-0030 (Hero Skill Build Ultimate Lookup-Table Architecture)
**ADR Decision Summary**: The Ultimate is derived via a pure 3-function pipeline — `category_profile()` (Formula 1), `classify_shape()` (Formula 2, exhaustive by construction over the 5 integer partitions of 4), `derive_ultimate_id()` (Formula 3, 19 fixed outputs). There is no lookup table data structure to author or maintain — the 19-entry table is a derived, provable enumeration of what the pure function produces, never data kept in sync with it.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Closed-form, mathematically proven exhaustive by the GDD itself (`C(7,4)=35` raw profiles confirmed). Nothing depends on live profiling.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0030 directly.
- Forbidden: No `NONE`-fallback branch reachable for any valid 4-slot, all-known-skills combination — this is proven unreachable by construction, not merely unlikely; the defensive guard exists only for data-integrity bugs (e.g., a skill shipped with a malformed `category`).
- Guardrail: `category_count` is computed fresh from the 4 current active slot bindings on every recompute trigger — never cached or incrementally updated.

---

## Acceptance Criteria

*From GDD `design/gdd/hero-skill-build.md`, scoped to this story:*

- [x] AC-6 — 1, 2, or 3 filled slots (not all 4) resolve the Ultimate to `EMPTY`; Formula 1 never evaluated
- [x] AC-7 — all 4 slots filled but one+ reference an `UNKNOWN` skill_id also yields `EMPTY`
- [x] AC-8 — category profile: 4 non-negative integers summing to exactly 4, each in [0,4]
- [x] AC-9 — shape classification is total and mutually exclusive: exactly one of 5 shapes always returned
- [x] AC-10a — the 35-profile raw enumeration is mathematically exhaustive (shape-by-shape count matches `C(7,4)=35`)
- [x] AC-10b — the 35→19 collapse is correct and complete: every profile resolves to one of the 19 fixed Ultimate IDs, with exact fan-in counts per ID
- [x] AC-10c — matrix size is catalogue-size-independent: an 8-skill and a 20-skill catalogue both produce identical 35/19 counts

---

## Implementation Notes

*Derived from ADR-0030 Implementation Guidelines:*

```gdscript
category_profile(active_slots) -> Dictionary[String, int]   # Formula 1
classify_shape(category_profile) -> Shape enum               # Formula 2, exhaustive by construction
derive_ultimate_id(shape, category_profile) -> String         # Formula 3, 19 fixed outputs + EMPTY

enum Shape { PURE, TRIPLE, DOUBLE_DOUBLE, DOUBLE_SINGLE_SINGLE, ALL_DIFFERENT }
```

- **Formula 1** (category profile): `category_count[c] = |{slot : catalogue[slot.skill_id].category == c}|` for each of the 4 categories. Requires all 4 slots filled with known skills (Rule 7 precondition) — if not met, the formula is not evaluated and Ultimate resolves to `EMPTY` directly.
- **Formula 2** (shape classification): `max_count = max(all 4 counts)`, `n_at_2 = count of categories at exactly 2`. `PURE` if max=4, `TRIPLE` if max=3, `DOUBLE_DOUBLE` if max=2 and n_at_2=2, `DOUBLE_SINGLE_SINGLE` if max=2 and n_at_2=1, `ALL_DIFFERENT` if max=1. Proven total and mutually exclusive — any 4 non-negative integers summing to 4 form exactly one of the 5 partitions of 4.
- **Formula 3** (Ultimate ID): `{category}_ascendant` (PURE, 4 IDs), `{dominant}_overload` (TRIPLE, 4 IDs), `{catA}_{catB}_fusion` alphabetical (DOUBLE_DOUBLE, 6 IDs), `{dominant}_surge` (DOUBLE_SINGLE_SINGLE, 4 IDs), `convergence` (ALL_DIFFERENT, 1 ID) — 19 total.
- The proof: raw assignments sum to 4+12+6+12+1=35 = `C(7,4)`. These collapse onto 19 IDs because TRIPLE/DOUBLE_SINGLE_SINGLE templates deliberately ignore the "minor" category — a design choice, not a coverage gap.
- A unit test must construct all 35 raw profiles programmatically (nested loop generating every non-negative 4-tuple summing to 4) and assert exactly 35 unique members, then pass each through Formulas 2–3 and assert the exact fan-in counts per Ultimate ID (each `_ascendant`×1, each `_overload`×3, each `_fusion`×1, each `_surge`×3, `convergence`×1).
- Catalogue-size-independence (AC-10c) must be tested parametrically against at least two catalogue sizes (8-skill Alpha, synthetic 20-skill fixture) substituting only the `skill_id`→`category` mapping, never touching Formulas 1–3 themselves.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the slot/catalogue data model this story's formulas consume
- Story 003: recompute triggering and Hero System's application of the resolved value

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-6**: Incomplete build resolves EMPTY
  - Given: 1, 2, or 3 active slots filled with known skill_ids (0 to 3 filled)
  - When: the Ultimate is computed
  - Then: `ultimate_id` resolves to `EMPTY`, Formula 1 is never evaluated

- **AC-7**: Unknown skill_id also yields EMPTY
  - Given: all 4 slots filled but one+ reference an `UNKNOWN` skill_id
  - When: the Ultimate is computed
  - Then: `ultimate_id` resolves to `EMPTY`

- **AC-8**: Category profile sums to 4
  - Given: all 4 active slots filled with known skills in any combination
  - When: Formula 1 is evaluated
  - Then: the four `category_count` values are each in [0,4] and sum to exactly 4

- **AC-9**: Shape classification total and exclusive
  - Given: any valid `category_count` vector
  - When: Formula 2 is evaluated
  - Then: exactly one of {PURE, TRIPLE, DOUBLE_DOUBLE, DOUBLE_SINGLE_SINGLE, ALL_DIFFERENT} is returned

- **AC-10a**: 35-profile exhaustiveness
  - Given: the claim that `C(7,4)=35` raw profiles exist
  - When: every profile enumerated by shape-count (4+12+6+12+1) is cross-checked against the stars-and-bars identity
  - Then: the two derivations agree exactly; a unit test constructs all 35 programmatically and asserts exactly 35 unique members, no duplicates, no gaps

- **AC-10b**: 35→19 collapse correctness
  - Given: all 35 raw profiles
  - When: each is passed through Formula 2 then Formula 3
  - Then: every profile resolves to a non-null, non-`EMPTY`, non-`NONE` Ultimate ID from the 19-entry table; fan-in counts match exactly (4×1 ascendant, 4×3 overload, 6×1 fusion, 4×3 surge, 1×1 convergence = 35)

- **AC-10c**: Catalogue-size independence
  - Given: a hypothetical 20-skill catalogue (5 per category) instead of Alpha's 8
  - When: the same 35-profile/19-ID proof is re-run substituting only the skill→category mapping
  - Then: raw profile count remains exactly 35, distinct Ultimate ID count remains exactly 19 — identical to the 8-skill catalogue

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/hero-skill-build/ultimate-derivation-tractability-proof_test.gd` — must exist and pass, including the parametrized 8-skill/20-skill catalogue-independence test

**Status**: [x] Created — `tests/unit/hero-skill-build/ultimate-derivation-tractability-proof_test.gd` (11 tests, passing, including the parametrized 20-skill catalogue-independence test)

---

## Dependencies

- Depends on: Story 001 (slot/catalogue data model)
- Unlocks: Story 003

**Unblocked**: ADR-0030 accepted 2026-07-18 (Sprint 6, S6-04).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 6/6 passing (11 unit tests, all passing) — full exhaustive 35-profile proof (programmatic stars-and-bars enumeration) confirming exact fan-in counts (4 ascendant + 4 overload + 6 fusion + 4 surge + 1 convergence = 35→19).
**Deviations**: None.
**Test Evidence**: Logic — `tests/unit/hero-skill-build/ultimate-derivation-tractability-proof_test.gd`.
**Code Review**: Complete (batch review across Stories 001-007) — APPROVED WITH SUGGESTIONS, required fixes applied.
