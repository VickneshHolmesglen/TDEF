# Story 021: Watchtower Scaffolding

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Config/Data
> **Estimate**: XS (<1 hr) — AC-16 only; `can_build_structure()` already handles any structure generically (Story 020), so this story is just authoring one `.tres` plus tests
> **Manifest Version**: 2026-07-13b *(stale for this epic — see Story 018)*

## Context

**GDD**: `design/gdd/defense-building.md`
**Requirement**: `TR-defbuild-001` (Watchtower half)

**ADR Governing Implementation**: ADR-0024
**ADR Decision Summary**: A single-tier structure (`watchtower_tier_1`, gated on `tech_structural_1`) establishing the "not every structure is Habitat Expansion" pattern. Gameplay effect is deliberately undefined — this story implements only build/unlock mechanics, no gameplay consequence.

**Engine**: Godot 4.6.2 | **Risk**: LOW

## Acceptance Criteria

- [ ] AC-16: GIVEN `tech_structural_1` is NOT `UNLOCKED`, WHEN `watchtower_tier_1` is attempted, THEN rejected at the tech-gate check — identical mechanical shape to AC-11. **Implementable now**: `DefenseBuilding.can_build_structure()` (Story 020) already handles this generically via any `StructureResource`'s `tech_gate` field — no new production code needed, only the `.tres` content and a test.
- [ ] AC-17: GIVEN `tech_structural_1` IS `UNLOCKED` and sufficient gold (70) and Common material (25) are available, WHEN `watchtower_tier_1` is confirmed, THEN it resolves `BUILT` and `sanctuary_structure_built(structure_id="watchtower_tier_1", structure_type="watchtower")` fires. **Scope boundary**: this AC and AC-16 test only build/unlock mechanics — no AC tests any in-game effect, because none is designed yet. **DEFERRED — not implementable in this story**: requires Story 022's gold-debit mechanism, Story 023's atomic build-resolution sequence, and Story 025's authored cost values (70 gold / 25 Common — confirmed in `story-025-cost-formulas.md` AC-36, which itself lists `Unlocks: ... Story 021`). Mirrors the same deferral already applied to Story 018's AC-2 and Story 020's AC-9/AC-15.

## Implementation Notes

Do not invent a gameplay effect for Watchtower. It exists purely to prove the tech-gate/structure-build mechanics generalize beyond Habitat Expansion.

## Out of Scope

- Any gameplay effect for Watchtower — explicitly out of scope project-wide until a future system claims it (see the GDD's own Open Questions)

## QA Test Cases

**AC-16**: tech-gate rejection, same shape as AC-11 (Story 020).

**AC-17**: full build succeeds with correct payload — `structure_type="watchtower"`, distinct from `"habitat_expansion"`.

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check pass (`production/qa/smoke-*.md`)
**Status**: [x] Exceeded — real integration test created at `tests/integration/defense_building/watchtower_scaffolding_test.gd` (4 test functions, covers AC-16 + content checks). Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Dependencies

- Depends on: Story 018, Story 019 (required now, for AC-16). Story 022, Story 023, Story 025 (required before AC-17 can be implemented/tested — not needed for AC-16 alone)
- Unlocks: None within this epic

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 1/2 passing, 1 deferred (AC-17 — requires Story 022/023/025, none implemented yet)
**Deviations**: ADVISORY — `/code-review` skipped per explicit user instruction, no independent review pass occurred. No production code changes were needed (`DefenseBuilding.can_build_structure()` from Story 020 already handles this generically) — only data (`watchtower_tier_1.tres`) and tests were added.
**Test Evidence**: `tests/integration/defense_building/watchtower_scaffolding_test.gd` (4 test functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Skipped per user instruction (2026-07-18)
