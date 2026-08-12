# Story 002: Content Validation — Prerequisite Cycle Guard & Chain Cap

> **Epic**: Building Upgrade System
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Logic
> **Estimate**: S (2-3 hours)
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-08-12

## Context

**GDD**: `design/gdd/building-upgrade.md`
**Requirement**: `TR-buildupgrade-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0034 (Building Upgrade Cross-System Requirements Model)
**ADR Decision Summary**: `BuildingUpgradeResource` mirrors Defense Building's/Crafting's own Resource-backed recipe shape. **Correction (found during `/story-readiness`, 2026-08-12)**: `validate()` was NOT missing — it already shipped 2026-08-11 (`src/core/building_upgrade/building_upgrade_resource.gd:36`), returning `Array[String]` (matching `RecipeResource.validate()`'s convention, not `TechNodeResource.validate()`'s bool+`push_error()` one), and already checks `upgrade_id`/`target_structure_id` non-empty, the `target_structure_id`↔`GameDataRegistry.get_structure()` cross-reference, and the `requirements` dict's key/value shape. This story **extends** that existing method with the 2 checks it doesn't yet have (cross-structure prerequisite rejection, same-structure cycle/chain-length rejection) — it does not create `validate()` from scratch.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Pure GDScript content validation, no engine API risk. No post-cutoff APIs involved.

**Control Manifest Rules (this layer)**:
- Required: `validate()` returns `Array[String]` (one message per invalid field), appended to — never switch the existing method's return type to `bool`. Matches `RecipeResource.validate()`'s established convention, which `BuildingUpgradeResource.validate()` already follows (see `src/core/building_upgrade/building_upgrade_resource.gd:36`) — NOT `TarotCardResource.validate()`/`TechNodeResource.validate()`'s different bool+`push_error()` convention.
- Required: the new cross-structure-prerequisite and cycle/chain-length checks need sibling context beyond a single `BuildingUpgradeResource` instance — confirm whether this fits inside `validate()` itself (called once per instance, would need the full loaded set passed in) or is cleaner as a second pass in `GameDataRegistry._load_building_upgrades()` (which already runs after `_load_structures()`, per its existing `target_structure_id` cross-reference) — this is an open implementation-approach decision for whoever picks up this story, not pre-decided here.
- Forbidden: Do not perform cross-Resource-*type* validation here (e.g. confirming a `"tarot"` requirement's `card_id` actually exists in the Tarot registry) — a missing/malformed target id *inside* a category is Edge Cases' own "resolves false at runtime" case (Story 001, already implemented), not a load-time content error. Cross-Resource validation *within the same type* (the prerequisite chain-walk) is exactly this story's own scope, per the existing `target_structure_id` cross-reference precedent already in the method.
- Guardrail: N/A — load-time only, not a hot path

---

## Acceptance Criteria

*From GDD `design/gdd/building-upgrade.md`, scoped to this story:*

- [ ] **AC-12**: GIVEN a `target_structure_id`'s `prerequisite_upgrade_id` chain forms a cycle, WHEN content is validated at load time, THEN `BuildingUpgradeResource.validate()` rejects it as a content error, never reaching a runtime deadlock.
- [ ] **AC-13**: GIVEN a `target_structure_id`'s `prerequisite_upgrade_id` chain exceeds 3 upgrades, WHEN content is validated at load time, THEN `BuildingUpgradeResource.validate()` rejects it as a content error, never reaching an undefined `upgrade_tier_multiplier` lookup at runtime.
- [ ] (Rule 1b, no separate AC number — part of this story's own scope) GIVEN a `requirements` entry uses a key not in `VALID_REQUIREMENT_TYPES`, WHEN validated, THEN it is rejected.
- [ ] (Rule 1b, no separate AC number) GIVEN a `prerequisite_upgrade_id` references an upgrade for a *different* `target_structure_id`, WHEN validated, THEN it is rejected.

---

## Implementation Notes

*Derived from ADR-0034 Decision and GDD Rule 1a/1b:*

- `validate()` needs cross-Resource context (every other `BuildingUpgradeResource` sharing the same `target_structure_id`, to walk the chain) — unlike a single-Resource `validate()` such as `TarotCardResource`'s. Follow whichever precedent this project uses for chain validation across multiple Resources of the same type at load time (check `GameDataRegistry`'s loader loop — it's the natural place to pass sibling context, or `validate()` may need a second method taking the full sibling set, e.g. `validate_chain(all_upgrades: Dictionary[StringName, BuildingUpgradeResource]) -> bool`, called once per `target_structure_id` group after individual `validate()` passes).
- Chain-walk cycle detection: for each `target_structure_id` group, walk from every upgrade with no forward reference to it (or from any starting point, tracking visited `upgrade_id`s) — a chain that revisits an already-visited `upgrade_id` is a cycle. Standard visited-set walk, no need for anything more sophisticated (chains are expected to be short, ≤3 per Rule 1a).
- Chain-length cap: same walk can simultaneously count depth — reject if any `target_structure_id` group's longest chain exceeds 3.
- `GGameDataRegistry`'s loader loop (wherever it loads `BuildingUpgradeResource` `.tres` files, mirroring `_load_tarot_cards()`'s pattern in `game_data_registry.gd`) should call this validation and `push_error()`/skip-or-fail on rejection, matching the project's established "invalid content fails loud at boot, never silently" convention.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the runtime resolution logic this validates content for (already Complete)
- Story 005: AC-10's "malformed requirement ID resolves false at runtime" — a different, already-implemented case, not a load-time validation concern

---

## QA Test Cases

- **AC-12**: Given `BuildingUpgradeResource` A (prerequisite=B) and B (prerequisite=A), both `target_structure_id="watchtower_tier_1"`, When `validate()`/`validate_chain()` runs, Then it returns `false` and logs an error identifying the cycle. Edge cases: a 3-upgrade cycle (A→B→C→A); a self-referencing upgrade (A→A).
- **AC-13**: Given 4 `BuildingUpgradeResource`s chained A→B→C→D (all same `target_structure_id`), When validated, Then it returns `false`. Edge cases: exactly 3 (should PASS — boundary); exactly 4 (should FAIL — boundary).
- **Rule 1b, unrecognized key**: Given a `requirements` dict with key `"unknown_category"`, When `validate()` runs, Then it returns `false`.
- **Rule 1b, cross-structure prerequisite**: Given upgrade A (`target_structure_id="watchtower_tier_1"`) with `prerequisite_upgrade_id` pointing to an upgrade whose own `target_structure_id="habitat_expansion_tier_1"`, When validated, Then it returns `false`.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/building_upgrade/content_validation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DONE — extends `BuildingUpgradeResource`)
- Unlocks: None (independent of Stories 003/004)

## Completion Notes
**Completed**: 2026-08-12
**Criteria**: 4/4 passing (AC-12, AC-13, Rule 1b unrecognized key, Rule 1b cross-structure prerequisite)
**Deviations**: None
**Test Evidence**: Logic — `tests/unit/building_upgrade/content_validation_test.gd` (11 tests, all passing; 23/23 across the whole `building_upgrade` suite)
**Code Review**: Complete — APPROVED (2 minor findings fixed during review: a doc-comment loop-bound inaccuracy, and one missing test for a cycle longer than the depth cap)
**Note**: implementation found `BuildingUpgradeResource.validate()` already existed pre-story (shipped 2026-08-11) — this story extended it with `validate_chain()` rather than creating validation from scratch, correcting an inaccuracy in the story's own original Implementation Notes (fixed during `/story-readiness`).
