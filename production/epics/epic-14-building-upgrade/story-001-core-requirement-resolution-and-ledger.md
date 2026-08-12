# Story 001: Core Requirement Resolution & Purchase Ledger

> **Epic**: Building Upgrade System
> **Status**: Complete (retroactive — implemented 2026-08-11, before this epic/story existed)
> **Layer**: Advanced
> **Type**: Logic
> **Estimate**: N/A — already implemented
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-08-12

## Context

**GDD**: `design/gdd/building-upgrade.md`
**Requirement**: `TR-buildupgrade-001`, `TR-buildupgrade-002`, `TR-buildupgrade-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0034 (Building Upgrade Cross-System Requirements Model)
**ADR Decision Summary**: `BuildingUpgradeResource` (content) + `BuildingUpgrade` (scene-instanced, permanent `_purchased_upgrades` ledger). 3 of 4 requirement-category reads (`"building"`/`"equipment"`/`"creature"`) are ADR-0020 Criterion A direct Autoload calls against `GDefenseBuilding`/`GInventory`/`GMenagerie`; the 4th (`"tarot"`) is a group-lookup read of Tarot (not an Autoload), fails closed.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs used. `Dictionary[StringName, bool]` typed ledger per project convention.

**Control Manifest Rules (this layer)**:
- Required: Static typing throughout (`technical-preferences.md`); primitive-only `get_save_data()` return (`resource_object_in_save_data`, ADR-0003)
- Forbidden: Untyped `Array`/`Dictionary` where a typed variant is available
- Guardrail: N/A — this system has no per-frame hot path; reads are UI-tab-gated, not per-frame

---

## Acceptance Criteria

*From GDD `design/gdd/building-upgrade.md`, scoped to this story:*

- [x] **AC-1**: GIVEN `target_structure_id` is not yet `BUILT`, WHEN the Forge's Building Upgrade tab is viewed, THEN that upgrade is not listed at all (Rule 3).
- [x] **AC-2**: GIVEN `target_structure_id` is `BUILT` and every `requirements` entry is satisfied but `gold_cost`/`material_cost` are not affordable, WHEN the tab is viewed, THEN the upgrade shows `VISIBLE_LOCKED` with a cost-insufficient cue, not `PURCHASABLE`.
- [x] **AC-3**: GIVEN all `requirements` entries and both costs are satisfied, WHEN the player confirms, THEN `gold_cost`/`material_cost` are debited, the upgrade becomes `PURCHASED` permanently, and `structure_upgraded(structure_id, upgrade_id)` fires exactly once (event-emission only — no downstream mechanical effect asserted, since no consumer is wired per Rule 7).
- [x] **AC-4**: GIVEN a successful purchase per AC-3, WHEN the resulting Inventory/Tarot/Menagerie/Defense Building state is inspected, THEN none of the `requirements` inputs were consumed, removed, or otherwise mutated (Rule 5) — only the two cost fields changed.
- [x] **AC-5**: GIVEN an upgrade with a `"creature"` requirement is `PURCHASABLE`, WHEN that creature is later removed from the menagerie by an unrelated system before the player confirms, THEN the upgrade reverts to `VISIBLE_LOCKED` and confirming is rejected (Edge Cases).
- [x] **AC-7**: GIVEN `upgrade_id` B's `prerequisite_upgrade_id` is `upgrade_id` A (same `target_structure_id`), WHEN A has not yet been `PURCHASED`, THEN B is not `PURCHASABLE` regardless of B's own `requirements`/cost state.

---

## Implementation Notes

*Derived from ADR-0034 Decision:*

Already implemented exactly as specified — `src/core/building_upgrade/building_upgrade.gd`: `is_visible()` (AC-1), `can_purchase()` including the `prerequisite_upgrade_id` gate at line ~95 (AC-2, AC-7), `resolve_upgrade()` (AC-3, dual-gate + no `await`, single synchronous call), `_requirement_satisfied()` (the 4-category dispatcher — AC-4/AC-5 depend on this being read-only, which it is: `is_structure_built`/`has_specific_item`/`has_creature_species`/`is_card_unlocked` are all pure queries, never mutating). No further implementation work required — this story exists to give the already-shipped code formal AC/TR/ADR traceability, closing the gap `/design-review` (2026-08-12) found (implementation predated any epic, story, or ADR).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `BuildingUpgradeResource.validate()` (Rule 1a/1b) — content validation, not resolution logic
- Story 003: Per-requirement legibility UI (Rule 2a)
- Story 004: PURCHASABLE notification + purchase feedback (Rule 6a)
- Story 005: AC-10 (malformed requirement ID) / AC-11 (shared requirement) edge-case regression tests

---

## QA Test Cases

*Already satisfied by the existing test suite — cases below map to what's already covered, for traceability, not new work.*

- **AC-1**: Given a `BuildingUpgradeResource` whose `target_structure_id` is not `BUILT`, When `is_visible()` is called, Then it returns `false`.
- **AC-2**: Given all requirements satisfied but insufficient gold/materials, When `can_purchase()` is called, Then it returns `false`.
- **AC-3**: Given all requirements + costs satisfied, When `resolve_upgrade()` is called, Then it returns `true`, debits both costs, and `structure_upgraded` fires exactly once (event spy).
- **AC-4**: Given a successful purchase, When Inventory/Menagerie/Defense Building state is inspected, Then none of the requirement inputs changed.
- **AC-5**: Given a `PURCHASABLE` upgrade with a `"creature"` requirement, When that creature is removed before confirm, Then `can_purchase()` returns `false` and `resolve_upgrade()` is rejected.
- **AC-7**: Given upgrade B's prerequisite A is not yet `PURCHASED`, When `can_purchase(B)` is called regardless of B's own requirements, Then it returns `false`.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/building_upgrade/building_upgrade_test.gd` — exists, 12 tests, passing (confirmed 2026-08-12)

**Status**: [x] Evidence exists — pre-dates this story file

---

## Dependencies

- Depends on: None
- Unlocks: Story 002, Story 005 (both extend this story's own `BuildingUpgrade`/`BuildingUpgradeResource`)
