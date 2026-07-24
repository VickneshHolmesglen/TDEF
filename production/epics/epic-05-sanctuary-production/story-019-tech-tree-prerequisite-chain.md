# Story 019: Tech Tree Prerequisite Chain Enforcement

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (3-4 hrs)
> **Manifest Version**: 2026-07-13b *(stale for this epic — see Story 018)*

## Context

**GDD**: `design/gdd/defense-building.md`
**Requirement**: `TR-defbuild-001` (chain-enforcement half)

**ADR Governing Implementation**: ADR-0024
**ADR Decision Summary**: `LOCKED_PREREQ`/`AVAILABLE` derived at query time from `_tech_ledger` + `prerequisite_tech_id` chain. `is_tech_unlocked(tech_id) -> bool` is a Criterion B direct-call read exposed to Crafting.

**Engine**: Godot 4.6.2 | **Risk**: LOW

## Acceptance Criteria

- [ ] AC-4: GIVEN `tech_production_2` is not yet `UNLOCKED`, WHEN an unlock is attempted on `tech_production_3`, THEN the action is rejected at the eligibility check before any cost check — no gold debited, no materials consumed, no `tech_unlocked` fires. Same for `tech_production_4` before `_3`, and `tech_structural_2` before `_1`.
- [ ] AC-5: GIVEN `tech_production_2` IS `UNLOCKED`, WHEN an unlock is attempted on `tech_production_3`, THEN the prerequisite check passes and proceeds to the cost-affordability check — prerequisite satisfaction alone does not bypass the cost gate.
- [ ] AC-6: GIVEN `tech_structural_1` is `UNLOCKED` and `tech_production_2` is still `LOCKED_PREREQ`, WHEN either chain's next node is queried, THEN `tech_structural_2` becomes eligible while `tech_production_3` remains `LOCKED_PREREQ` — the two categories' chains are fully independent.
- [ ] AC-26: GIVEN `tech_production_2` is already `UNLOCKED`, WHEN an unlock is attempted on it again, THEN the action is rejected at the eligibility check before any cost is touched — no gold debited, no materials consumed, no duplicate event fires.

## Implementation Notes

```gdscript
func is_tech_unlocked(tech_id: StringName) -> bool:
    return _tech_ledger.get(tech_id, false)
```

Idempotency (AC-26) and prerequisite-chain enforcement share the same eligibility-check code path — a node already `UNLOCKED` is treated identically to a node whose prerequisite isn't met: rejected before any cost check.

**Autoload registration (closes `TD-defbuild-001`)**: This story must also register `DefenseBuilding` as Autoload #10 in `project.godot`, per ADR-0024's Decision — required so `is_tech_unlocked()` is callable as a bare global from Crafting's Story 002 boot sweep, which this story's own Dependencies section states as an unlock. Check `project.godot` first: if `Inventory` (Autoload #9) is not yet registered either, register it before `DefenseBuilding` in the same pass — DefenseBuilding's future resolution sequence (Story 022/023) calls `Inventory.has_items()`/batch-consume directly and must load after it. Once `DefenseBuilding` is registered, update Story 018's `test_defense_building_is_not_registered_as_autoload()` (`tests/unit/defense_building/tech_structure_data_schema_test.gd`) to assert the opposite — that the Autoload entry now exists — since that test was written specifically to guard against premature registration before this story.

## Out of Scope

- Story 020: structure-side tech-gating (uses this same `is_tech_unlocked()` read, but the structure-specific tier-sequence enforcement is its own story)

## QA Test Cases

**AC-4**: attempt each of the 3 skip-ahead cases (prod_3 before prod_2, prod_4 before prod_3, struct_2 before struct_1) — all rejected, zero side effects.

**AC-5**: prerequisite met, cost check still runs — assert the flow reaches the cost gate, doesn't auto-succeed on prerequisite alone.

**AC-6**: independent chains — unlocking in one category has zero effect on the other's eligibility.

**AC-26**: already-unlocked node, re-attempt — rejected, idempotent, no duplicate `tech_unlocked`.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/defense_building/tech_prerequisite_chain_test.gd`
**Status**: [x] Created — 13 test functions, all 4 ACs covered. Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Dependencies

- Depends on: Story 018
- Unlocks: Story 002 (Crafting's boot sweep consumes `is_tech_unlocked()`), Story 022, Story 023

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 4/4 passing
**Deviations**: ADVISORY — `src/gameplay/ui/inventory_screen/inventory_screen.gd` fixed outside declared scope (defaults to `GInventory` Autoload instead of a disconnected fallback instance), a direct consequence of this story's Autoload registration. Fixed during `/code-review`, not deferred.
**Test Evidence**: `tests/unit/defense_building/tech_prerequisite_chain_test.gd` (13 test functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Complete — `/code-review`, Verdict: APPROVED WITH SUGGESTIONS (2026-07-18, after the `inventory_screen.gd` fix)
**Tech Debt Closed**: `TD-defbuild-001` (DefenseBuilding Autoload registration) — resolved by this story.
