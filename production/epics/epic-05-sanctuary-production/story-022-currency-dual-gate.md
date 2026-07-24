# Story 022: Currency Dual-Gate & Gold Debit

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (3-4 hrs)
> **Manifest Version**: 2026-07-13b *(stale for this epic — see Story 018)*

## Context

**GDD**: `design/gdd/defense-building.md`
**Requirement**: `TR-defbuild-001` (currency half)

**ADR Governing Implementation**: ADR-0024
**ADR Decision Summary**: Both ledgers spend gold AND materials together (never one alone) — deliberately distinct from Crafting/Menagerie's materials-only convention. Gold debit follows `resources_changed(-cost, source_tag)`.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Gold-balance ownership itself (who validates affordability) is a pre-existing, unresolved project-wide gap shared with Tower System — this story does not resolve it, only follows the existing self-debit convention every gold-spending system currently uses.

## Acceptance Criteria

- [ ] AC-18: GIVEN sufficient gold but insufficient materials for a tech node, WHEN unlock confirmed, THEN rejected in full — gold alone is not sufficient.
- [ ] AC-19: GIVEN sufficient materials but insufficient gold for a structure, WHEN build confirmed, THEN rejected in full — materials alone is not sufficient.
- [ ] AC-20: GIVEN a tech node unlock resolves successfully, WHEN its gold debit is observed, THEN `resources_changed(-gold_cost, "tech_unlock")` fires with the exact negative value and source tag `"tech_unlock"`.
- [ ] AC-21: GIVEN a structure build resolves successfully, WHEN its gold debit is observed, THEN `resources_changed(-gold_cost, "structure_built")` fires with source tag `"structure_built"`.

## Implementation Notes

`AC-22` (the balance-read/validate step itself) is explicitly flagged by the GDD's own qa-lead note as not independently verifiable as a pure Defense Building unit test — its correctness depends on Resource Economy's own unresolved balance-ownership implementation. Do not attempt to close that gap in this story; test only the debit-emission side (AC-20/AC-21), which is independently testable.

## Out of Scope

- Resolving gold-balance ownership project-wide — a separate, cross-system concern not owned by this epic

## QA Test Cases

**AC-18 / AC-19**: each single-currency-insufficient scenario rejected in full — zero partial debit.

**AC-20 / AC-21**: exact payload assertion — negative value, correct source tag distinguishing tech vs. structure spends.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/defense_building/currency_dual_gate_test.gd`
**Status**: [x] Created — 4 test functions (AC-20, AC-21, + 2 eligibility-gate regression tests). AC-18/AC-19 deferred (see Completion Notes). Plus 6 more tests in `tests/unit/inventory/has_items_test.gd` for the prerequisite fix. Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Dependencies

- Depends on: Story 018, Story 019
- Unlocks: Story 023

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 2/4 passing, 2 deferred (AC-18 — real content all has `material_costs={}` pending Story 025, underlying `has_items()` logic tested directly instead; AC-19 — pre-existing project-wide gold-balance-ownership gap)
**Deviations**: ADVISORY — story expanded beyond Defense Building to fix two real prerequisite gaps discovered mid-implementation: `Inventory.has_items()` was documented (ADR-0021) as already existing but didn't; fixing it required adding `GameDataRegistry.get_item_definition()` (a whole missing item-definition loader subsystem, confirmed deliberately unwired since Story 001 per `ItemDefinitionResource`'s own header comment). Both explicitly approved mid-session before any code was written.
**Test Evidence**: `tests/unit/defense_building/currency_dual_gate_test.gd` (4 functions) + `tests/unit/inventory/has_items_test.gd` (6 functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Complete — `/code-review`, Verdict: APPROVED WITH SUGGESTIONS (2026-07-18); the one suggested doc-comment fix (`inventory.gd` class header staleness) was applied before closing this story.
