# Story 009: Equipment Recipe Model & Discovery

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/equipment-forge.md`
**Requirement**: `TR-equipforge-001`

**ADR Governing Implementation**: ADR-0025 (Equipment Forge Cross-System Aggregation)
**ADR Decision Summary**: `EquipmentRecipeResource` is a separate `Resource` subclass mirroring Crafting's `RecipeResource` field shape and validation convention (a sibling, not a subtype) — fixed `recipe_category="hero_equipment"`, plus `output_slot` and `rune_slot_count` (derived from `output_slot`, not authored per-recipe). Discovery reuses Crafting's exact two-gate model and the already-frozen `recipe_discovered` event.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Extends ADR-0009's `GameDataRegistry`/`Resource`/`validate()` convention and ADR-0023's `RecipeResource` shape. No new engine subsystem.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0009/ADR-0023/ADR-0025 directly.
- Forbidden: `output_slot` (`weapon`/`armor`/`accessory`/`trinket`) is a distinct vocabulary from Tower's `foundation`/`weapon`/`focus`/`power` slot names — the shared string `"weapon"` is a content-authoring caution, never a mechanical conflict; the two systems must never compare these strings against each other.
- Guardrail: `rune_slot_count` is derived at data-authoring time from the fixed `output_slot -> rune_slot_count` table, never authored per-recipe.

---

## Acceptance Criteria

*From GDD `design/gdd/equipment-forge.md`, scoped to this story:*

- [x] AC-4 — all 7 `EquipmentRecipeResource` fields present and typed as specified
- [x] AC-5 — `quality_tier` is a fixed author-set integer in 1–4, never rolled or computed at craft time
- [x] AC-6 — tech gate and material gate both true in the same frame fires `recipe_discovered("hero_equipment")` exactly once, transitions `HIDDEN → DISCOVERED` permanently; a later material-gate loss does not revert
- [x] AC-7 — craftability flag flips independently of the one-time discovery event, on `item_added` alone

---

## Implementation Notes

*Derived from ADR-0025 Implementation Guidelines:*

```gdscript
class_name EquipmentRecipeResource extends Resource
@export var recipe_id: StringName = &""
@export var recipe_category: String = "hero_equipment"   # fixed literal
@export var output_slot: String = ""              # weapon|armor|accessory|trinket
@export var inputs: Dictionary[StringName, int] = {}
@export var tech_prerequisite: StringName = &""
@export var output_item_id: StringName = &""
@export var quality_tier: int = 1                  # 1-4, fixed author-set
@export var rune_slot_count: int = 0                # derived from output_slot table, validated
func validate() -> Array[String]: ...
```

- Discovery reuses Crafting's exact two-gate model (tech gate + material gate, both true simultaneously → permanent discovery) and the already-frozen `recipe_discovered` event — extending its Key Subscribers list from "Encyclopedia, Crafting UI" to include "Equipment Forge UI" (no payload change; `recipe_category` already generically supports `"hero_equipment"`).
- Craftability (whether a recipe's craft action is currently enabled) is continuously re-evaluated on `item_added`/`item_removed`, independent of the one-time discovery event — identical semantics to Crafting Rule 4's Discovery/Craftability split.
- `rune_slot_count` per `output_slot`: `weapon`=2, `armor`=2, `accessory`=1, `trinket`=1 — validated by `validate()` against this fixed table, never authored freely per-recipe.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 010: the actual crafting resolution flow that consumes a discovered/craftable recipe
- Story 012: the rune slot *ledger* (this story only covers the recipe's `rune_slot_count` field, not the imbuing ledger)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-4**: Field completeness
  - Given: an authored `EquipmentRecipeResource`
  - When: its fields are inspected
  - Then: all 7 fields present and typed as specified

- **AC-5**: Fixed quality tier
  - Given: any authored Equipment Recipe
  - When: `quality_tier` is read
  - Then: a fixed author-set integer in 1–4 — never rolled, never computed at craft time

- **AC-6**: Two-gate discovery, permanent
  - Given: an Equipment Recipe whose tech gate and material gate both become true in the same frame
  - When: that frame resolves
  - Then: `recipe_discovered(recipe_category="hero_equipment")` fires exactly once, transitions `HIDDEN → DISCOVERED` permanently; a subsequent material-gate loss does not revert the state

- **AC-7**: Independent craftability re-eval
  - Given: a `DISCOVERED` Equipment Recipe whose inputs are currently insufficient
  - When: `item_added` fires for a material completing the input requirement
  - Then: craftability flag flips to true on that event alone, independent of the already-fired `recipe_discovered` event

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/equipment-forge/recipe-model-discovery_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/equipment-forge/recipe-model-discovery_test.gd` (11 tests, passing)

---

## Dependencies

- Depends on: Story 008 (`output_slot` vocabulary this recipe schema uses)
- Unlocks: Story 010

**Unblocked**: ADR-0025 accepted 2026-07-18 (Sprint 6, S6-04).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 4/4 passing (11 unit tests, all passing).
**Deviations**: SaveRestorer persistence (`restore_order=32`) deliberately not implemented — Story 011 ("Save Payload Ownership Clarification") owns that; the discovery ledger is in-memory only until that story lands, matching the epic's own story boundaries, not a scope gap.
**Test Evidence**: Logic — `tests/unit/equipment-forge/recipe-model-discovery_test.gd`.
**Code Review**: Pending — deferred to a batch pass at a later Equipment Forge checkpoint, per this session's established pattern.
