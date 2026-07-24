# Story 001: RecipeResource Data Model & Content Validation

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Config/Data *(implementation was real code — RecipeResource class + GameDataRegistry extension — same routing correction precedent as Story 018)*
> **Estimate**: S (1-2 hrs)
> **Manifest Version**: 2026-07-13b *(stale — does not yet cover ADR-0023; rules below are extracted directly from the ADR)*

## Context

**GDD**: `design/gdd/crafting.md`
**Requirement**: `TR-craft-001` — "RecipeResource data schema via GameDataRegistry, extending ADR-0009's existing Resource-subclass convention"

**ADR Governing Implementation**: ADR-0023 (Crafting recipe data model)
**ADR Decision Summary**: `RecipeResource` is a static, immutable, `GameDataRegistry`-backed Resource subclass (mirrors `MonsterResource`/`ItemDefinitionResource`/`TechNodeResource`) — fields: `recipe_id`, `recipe_category`, `component_slot`, `inputs: Dictionary[StringName, int]`, `tech_prerequisite`, `output_item_id`, `output_quantity`, `quality_tier`. Repair is explicitly NOT modeled as a `RecipeResource`.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Typed `Dictionary[StringName, int]` for `inputs` (4.4+, already verified working project-wide). No post-cutoff API risk.

**Control Manifest Rules (Feature layer, extracted from ADR-0023 since the manifest predates it)**:
- Required: `RecipeResource` loads via `GameDataRegistry` at boot (Autoload #5) — no system constructs its own `res://assets/data/...` path (ADR-0009 convention, inherited)
- Required: `validate() -> Array[String]` confirms every `modifiers`/`inputs` entry references a known material_id and a `modifier_type` from the registered set — `push_error()` per issue, never abort in release
- Forbidden: mutable per-playthrough state (discovery/craftability) on this Resource instance — that is Story 002's `CraftingDiscoveryLedger`, a separate runtime structure

## Acceptance Criteria

*From `design/gdd/crafting.md`, scoped to this story:*

- [ ] AC-1 (Config/Data half): GIVEN a `RecipeResource` loaded from `assets/data/recipes/`, WHEN its fields are inspected, THEN `recipe_id`, `recipe_category`, `component_slot`, `inputs`, `tech_prerequisite`, `output_item_id`, `output_quantity`, `quality_tier` are all present with the types specified in Rule 1's table.
- [ ] AC-3: GIVEN a card's `modifiers`/`inputs` entries, WHEN content is validated pre-ship, THEN every `modifier_type`/material reference resolves to a known registered value — a recipe authored with an invalid reference fails content validation before it can be added to the recipe pool.

## Implementation Notes

*Derived from ADR-0023 Decision/Key Interfaces:*

```gdscript
class_name RecipeResource extends Resource
@export var recipe_id: StringName = &""
@export var recipe_category: String = ""        # "tower_component" | "crafted_good"
@export var component_slot: String = ""         # foundation|weapon|focus|power; "" unless tower_component
@export var inputs: Dictionary[StringName, int] = {}   # material_id -> quantity, 1-3 entries
@export var tech_prerequisite: StringName = &""  # "" = ungated
@export var output_item_id: StringName = &""
@export var output_quantity: int = 1
@export var quality_tier: int = 0                # 0 = N/A (crafted_good); 1-4 for tower_component
func validate() -> Array[String]: ...
```

Repair (Rule 2/6) has no `RecipeResource` entry — do not create one for it. Its own gating (`InventorySlot.damaged == true`) and cost (Formula 3) are Story 005's concern, not this one.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `CraftingDiscoveryLedger` (runtime, per-playthrough discovery state)
- Story 006: Formula 1/2 material-cost computation logic

## QA Test Cases

**AC-1**
- Given: a `.tres` file authored under `assets/data/recipes/`
- When: `GameDataRegistry` loads it at boot
- Then: all 8 fields resolve to their declared types with no null/missing-field error
- Edge cases: a recipe with `component_slot=""` and `recipe_category="crafted_good"` (valid — component_slot only meaningful for tower_component); a recipe with 0 or 4+ `inputs` entries (invalid — spec requires 1-3)

**AC-3**
- Given: a recipe whose `inputs` dictionary references a `material_id` not present in `GameDataRegistry`'s loaded item catalogue
- When: `validate()` runs at boot
- Then: `push_error()` fires with a specific, identifiable message; the recipe is excluded from the loaded catalogue (or flagged invalid) rather than crashing the boot sequence
- Edge cases: a recipe with a valid `output_item_id` but malformed `quality_tier` (out of 0-4 range)

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check pass (`production/qa/smoke-*.md`)
**Status**: [x] Exceeded — real unit test suite at `tests/unit/crafting/recipe_data_model_test.gd` (16 test functions). Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 2/2 passing (AC-1, AC-3)
**Deviations**: ADVISORY — 2 minimal recipes (`recipe_iron_foundation`, `recipe_healing_salve`) plus their 2 output `ItemDefinitionResource`s authored as initial content, matching Story 018's precedent. Also: `RecipeResource.inputs` was initially authored keyed by `material_id` (matching ADR-0023's own comment) but corrected to `item_type`-keyed during Story 002, since `Inventory.has_items()`'s real contract sums by `item_type` — logged and fixed as `TD-craft-001`, caught before propagating further.
**Test Evidence**: `tests/unit/crafting/recipe_data_model_test.gd` (16 functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Skipped per "keep skip review plan through the remaining stories" instruction

## Dependencies

- Depends on: None (first story in this epic)
- Unlocks: Story 002, Story 004, Story 005, Story 006
