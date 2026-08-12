# Story 005: Edge-Case Regression Coverage

> **Epic**: Building Upgrade System
> **Status**: Ready
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

- [ ] **AC-10**: GIVEN a `requirements` entry references an unrecognized `structure_id`/`item_id`/`card_id`/`species_id`, WHEN checked, THEN the entry resolves `false` and the upgrade never reaches `PURCHASABLE` via that entry.
- [ ] **AC-11**: GIVEN two upgrades (same or different `target_structure_id`) share an identical `requirements` entry, WHEN one is `PURCHASED`, THEN the shared requirement remains independently satisfied and unaffected for the other upgrade's own evaluation.

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DONE)
- Unlocks: None
