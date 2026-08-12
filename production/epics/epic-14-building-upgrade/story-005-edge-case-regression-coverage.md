# Story 005: Edge-Case Regression Coverage

> **Epic**: Building Upgrade System
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Logic
> **Estimate**: XS (1-2 hours)
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-08-12

## Context

**GDD**: `design/gdd/building-upgrade.md`
**Requirement**: `TR-buildupgrade-001`, `TR-buildupgrade-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0034 (Building Upgrade Cross-System Requirements Model)
**ADR Decision Summary**: Both cases below describe behavior the shipped `_requirement_satisfied()`/ledger design (Story 001) already produces structurally — this story is test-only, confirming that behavior with dedicated regression coverage rather than adding new production code.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: None — pure test-writing against existing code.

**Control Manifest Rules (this layer)**:
- Required: GUT/gdUnit4 test framework, matching every other test file in this project
- Guardrail: N/A

---

## Acceptance Criteria

*From GDD `design/gdd/building-upgrade.md`, scoped to this story:*

- [x] **AC-10**: GIVEN a `requirements` entry references an unrecognized `structure_id`/`item_id`/`card_id`/`species_id`, WHEN checked, THEN the entry resolves `false` and the upgrade never reaches `PURCHASABLE` via that entry.
- [x] **AC-11**: GIVEN two upgrades (same or different `target_structure_id`) share an identical `requirements` entry, WHEN one is `PURCHASED`, THEN the shared requirement remains independently satisfied and unaffected for the other upgrade's own evaluation.
- [x] **AC-10b** (added during `/story-readiness`, closing a Definition-of-Done minimum-AC gap — Logic stories require ≥3 testable criteria; promotes an edge case already named in this story's own QA Test Cases to a formal AC): GIVEN each of the 4 requirement categories (`"building"`, `"equipment"`, `"tarot"`, `"creature"`) independently references an unrecognized id, WHEN checked, THEN every category's own resolution branch — not just one — resolves `false` safely, confirming `_requirement_satisfied()`'s null-safety holds uniformly across all 4 branches, not only the one AC-10 happens to exercise.

---

## Implementation Notes

*Derived from GDD Edge Cases:*

- AC-10: confirm `_requirement_satisfied()`'s 4 branches each safely return `false` for an id their target system's own registry/ledger doesn't recognize (e.g. `GDefenseBuilding.is_structure_built(&"not_a_real_structure")`, `GInventory.has_specific_item(&"not_a_real_item")`) — this should already hold, since each upstream query is itself null-safe by construction (confirmed during `/design-review`, 2026-08-12). If any branch is found NOT to be null-safe during this story, that's a real bug to fix here, not just a test-writing task — escalate if found.
- AC-11: purchasing one upgrade must never mutate the shared requirement's own underlying state (Rule 5's non-consumption already guarantees this structurally) — the test should assert the SECOND upgrade's `can_purchase()`/requirement-satisfied state is unchanged by the FIRST upgrade's `resolve_upgrade()` call, not just re-assert the first upgrade's own success.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: load-time content validation (a different class of "malformed" — authored-wrong content vs. this story's "resolves false at runtime" for an id that's simply unrecognized)

---

## QA Test Cases

- **AC-10**: Given a `BuildingUpgradeResource` with a `"building"` requirement referencing a nonexistent `structure_id`, When `can_purchase()` is evaluated, Then it returns `false` (never crashes). Edge cases: repeat for each of the 4 requirement categories (`"equipment"`, `"tarot"`, `"creature"` with nonexistent ids).
- **AC-11**: Given two `BuildingUpgradeResource`s (A, B) both requiring the same built structure, When A is purchased via `resolve_upgrade()`, Then B's `can_purchase()` (assuming B's other requirements/costs are also satisfied) still evaluates the shared requirement as satisfied — unaffected by A's purchase.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/building_upgrade/edge_cases_test.gd` — must exist and pass

**Status**: [x] Created — 6 test functions, all passing

---

## Dependencies

- Depends on: Story 001 (DONE)
- Unlocks: None

## Completion Notes
**Completed**: 2026-08-12
**Criteria**: 3/3 passing (AC-10, AC-10b, AC-11)
**Deviations**: ADVISORY — during `/code-review`, the first draft's AC-10 and AC-11 tests were found to test only the isolated `_requirement_satisfied()` branch rather than the public `can_purchase()` path the AC/QA Test Case text actually specifies (a false-positive risk: both would still pass even if `can_purchase()` itself had a bug). Fixed directly: AC-10's test now temporarily mutates the live registered `upgrade_watchtower_reinforced` resource's `requirements["building"]` via `GGameDataRegistry.get_building_upgrade()` and asserts through real `can_purchase()`; AC-11's test now registers a genuine second `BuildingUpgradeResource` (`SHARED_REQUIREMENT_UPGRADE_ID`) directly into the registry ledger (same direct-dict test-seam convention already used for `GDefenseBuilding._structure_ledger`/`Tarot._card_unlocked`) and asserts its own `can_purchase()` is unaffected by the first upgrade's purchase — avoiding new permanent `.tres` content per the story's own test-only scope.
**Test Evidence**: Logic — `tests/unit/building_upgrade/edge_cases_test.gd` (6 tests, 0 failures)
**Code Review**: Complete — APPROVED (2 real findings from 2 specialist passes — godot-gdscript-specialist and qa-tester independently flagged the same AC-10 gap; qa-tester additionally caught the AC-11 gap — both fixed)
