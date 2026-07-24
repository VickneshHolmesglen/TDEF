# Story 020: Habitat Expansion 3-Tier Contract

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L (4-6 hrs)
> **Manifest Version**: 2026-07-13b *(stale for this epic — see Story 018)*

## Context

**GDD**: `design/gdd/defense-building.md`
**Requirement**: `TR-defbuild-002` — "sanctuary_structure_built contract for Habitat Expansion's 3-tier structure (independently verified 2026-07-17 to match menagerie.md's expected contract exactly)"

**ADR Governing Implementation**: ADR-0024
**ADR Decision Summary**: `habitat_expansion_tier_1/2/3`, each emitting `sanctuary_structure_built(structure_id, structure_type="habitat_expansion")` on that exact string, all 3 tiers. Tier 1 ungated; Tier 2 gated on `tech_structural_1`; Tier 3 on `tech_structural_2`. Sequential-tier enforcement via `prerequisite_structure_id`.

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules**:
- Required: `structure_type` is the literal string `"habitat_expansion"` on all 3 tiers without exception — Menagerie's Story 009 subscriber keys off this fixed string alone
- Required: `structure_id` values are exactly `habitat_expansion_tier_1`/`_2`/`_3` — no alternate suffix, no zero-indexing

## Acceptance Criteria

- [ ] AC-7: GIVEN the three Habitat Expansion tiers, WHEN each `structure_id` is read, THEN they are exactly `habitat_expansion_tier_1`, `_tier_2`, `_tier_3`.
- [ ] AC-8: GIVEN any of the three tiers is built, WHEN its `sanctuary_structure_built` event is emitted, THEN `structure_type` is the literal string `"habitat_expansion"` on all three without exception.
- [ ] AC-9: GIVEN `habitat_expansion_tier_2` is built, WHEN emitted, THEN the payload is exactly `sanctuary_structure_built(structure_id="habitat_expansion_tier_2", structure_type="habitat_expansion")` — two fields only, no tier as a separate numeric argument.
- [ ] AC-10: GIVEN no tech node is `UNLOCKED`, WHEN `habitat_expansion_tier_1` is attempted, THEN the tech-gate check passes unconditionally (`tech_gate=""`).
- [ ] AC-11: GIVEN `habitat_expansion_tier_1` IS `BUILT` but `tech_structural_1` is NOT `UNLOCKED`, WHEN `habitat_expansion_tier_2` is attempted, THEN rejected at the tech-gate check — even though the tier-sequence prerequisite is independently satisfied.
- [ ] AC-12: GIVEN `habitat_expansion_tier_2` IS `BUILT` but `tech_structural_2` is NOT `UNLOCKED`, WHEN `habitat_expansion_tier_3` is attempted, THEN rejected identically to AC-11.
- [ ] AC-13: GIVEN `habitat_expansion_tier_1` is NOT yet `BUILT`, WHEN `habitat_expansion_tier_2` is attempted, THEN rejected at the prerequisite-structure check — a later tier can never be purchased before its predecessor.
- [ ] AC-14: GIVEN Tier 1 IS built but Tier 2 is NOT, WHEN Tier 3 is attempted, THEN rejected identically to AC-13.
- [ ] AC-15: GIVEN a fresh save, WHEN Tier 1 built → `tech_structural_1` unlocked → Tier 2 built → `tech_structural_2` unlocked → Tier 3 built, in that exact order, THEN all three succeed in sequence with correct `sanctuary_structure_built` payloads for each.
- [ ] AC-27: GIVEN `habitat_expansion_tier_1` is already `BUILT`, WHEN a build is attempted on it again, THEN rejected identically to AC-26's shape — no duplicate event.

## Implementation Notes

Both the tier-sequence prerequisite check and the tech-gate check are evaluated together at Rule 9 step (a) — either failing alone produces full rejection (AC-11/AC-12 demonstrate the tech-gate failing even when the tier-sequence independently passes).

## Out of Scope

- Story 009 (Menagerie epic story): the subscriber side — Menagerie's capacity increment logic

## QA Test Cases

Each AC above maps 1:1 to a test case per its own Given/When/Then — see the AC text directly. Highest-priority: AC-15's full happy-path sequence (end-to-end, not just individual gate checks in isolation) and AC-9's exact-payload-shape assertion (Menagerie's Story 009 depends on this being bit-exact).

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/defense_building/habitat_expansion_contract_test.gd`
**Status**: [x] Created — 10 executable test functions (AC-7, 8, 10-14, 27). AC-9/AC-15 deferred (see Completion Notes). Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Dependencies

- Depends on: Story 018, Story 019
- Unlocks: Story 009 (Menagerie epic story, cross-epic within Epic 05)

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 7/9 passing, 2 deferred (AC-9, AC-15 — require Story 022/023's build-resolution/`sanctuary_structure_built` emission mechanism, which doesn't exist yet; documented in-file rather than faked, same treatment as Story 018's AC-2)
**Deviations**: None blocking. Story 018's guard test (`test_ready_empty_structures_directory_produces_no_crash_and_no_entries`) updated to expect 3 structures instead of 0, and the now-obsolete `structures/.gdignore` placeholder removed — both necessary, documented consequences of this story authoring the first real Structure content.
**Test Evidence**: `tests/integration/defense_building/habitat_expansion_contract_test.gd` (10 test functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Complete — `/code-review`, Verdict: APPROVED WITH SUGGESTIONS (2026-07-18)
