# Story 002: Tab Categorization

> **Epic**: Epic 03 — Core Economy
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic *(corrected 2026-07-15 — header originally said Config/Data, but the story's own Test Evidence requirement for a unit test and AC-7's real branching logic are Logic-shaped; see Completion Notes)*
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/inventory.md`
**Requirement**: `TR-inventory-???` *(no TR-ID exists yet)*

**ADR Governing Implementation**: ADR-0016 (Inventory Storage Model)
**ADR Decision Summary**: `ItemDefinitionResource.item_type: StringName` is the data-driven field that maps an item to one of the 4 fixed tabs (Equipment, TowerComponent, Material, CraftedGood) — loaded via `GameDataRegistry`, validated at boot per `validate() -> Array[String]`.

**Engine**: Godot 4.6.2 / GDScript | **Risk**: Unassessed
**Engine Notes**: None yet.

**Control Manifest Rules (this layer)**:
- Required (Global Rules): gameplay values must be data-driven, never hardcoded — the tab mapping should not be a hardcoded `match` statement without a data source of truth
- Required (Global Rules): naming conventions — tab identifiers should follow `snake_case` / `PascalCase` conventions per element type

---

## Acceptance Criteria

*From GDD `design/gdd/inventory.md`, scoped to this story:*

- [x] **AC-5** *(UI — advisory, screenshot evidence)*: GIVEN the Inventory screen is open, WHEN the tab bar renders, THEN exactly 4 tabs appear in fixed order: Equipment, Tower Components, Materials, Crafted Goods. — backing data (`Inventory.TAB_ORDER`) verified; visual render DEFERRED to Story 007 (no UI exists yet).
- [x] **AC-6** *(UI — advisory)*: GIVEN the tab bar, WHEN drag-reorder/add-tab/rename is attempted, THEN no such interaction is available. — satisfied by omission (no such API exists); visual confirmation DEFERRED to Story 007.
- [x] **AC-7**: GIVEN an item with a given `item_type`, WHEN `item_added` fires, THEN it files under exactly one tab per the fixed mapping. — implemented via `Inventory.get_tab_for_item_type()`, 6/6 tests passing.

---

## Implementation Notes

*Derived from ADR-0016:* `item_type` lives on `ItemDefinitionResource`, resolved via `GameDataRegistry.get_item_definition(item_id).item_type` — compute tab membership at read time from this field rather than caching a redundant copy on `InventorySlot`. A malformed `item_type` value (not one of the 4 known categories) should fail `validate()` at load time, per the `resource_validation` contract (ADR-0009) — not be discovered at runtime.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the underlying slot/stack storage this categorization reads from
- Story 007: the two-panel screen presentation that displays these tabs

---

## QA Test Cases

- **AC-5**: Fixed tab order
  - Setup: open the Inventory screen with any save state
  - Verify: exactly 4 tabs render, in the order Equipment, Tower Components, Materials, Crafted Goods
  - Pass condition: screenshot shows all 4 tabs in that exact order, no extra or missing tabs

- **AC-6**: No tab customization
  - Setup: open the Inventory screen
  - Verify: no drag-to-reorder affordance, no "add tab" button, no rename interaction exists anywhere on the tab bar
  - Pass condition: a tester attempting any of these three interactions finds no available control

- **AC-7**: item_type to tab mapping
  - Given: an item with a specific `item_type` value (one representative per tab: Equipment, Tower Component, Material, Crafted Good)
  - When: `item_added` fires for that item
  - Then: the item appears under exactly one tab, matching the fixed category mapping
  - Edge cases: an `item_type` value that doesn't match any of the 4 known categories should fail loudly at data-validation time (load-time), not silently default to a tab

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `tests/unit/inventory/tab_categorization_test.gd` — must exist and pass (covers AC-7)
- `production/qa/evidence/tab-categorization-evidence.md` — screenshot evidence for AC-5/AC-6

**Status**: [x] Unit test created — 6/6 passing (live-verified, Godot 4.6.2.stable headless). Screenshot evidence NOT YET created — no UI exists yet; deferred to Story 007.

---

## Dependencies

- Depends on: Story 001 (slot/stack model must exist first)
- Unlocks: Story 007

---

## Completion Notes

**Completed**: 2026-07-15
**Criteria**: 3/3 addressed — AC-7 fully verified; AC-5/AC-6 backing data verified, visual/screenshot confirmation DEFERRED to Story 007 (no UI exists yet)
**Deviations**: Advisory only
- Story header originally declared `Type: Config/Data`; corrected to `Logic` — AC-7's mapping function and its required unit test are Logic-shaped, not a data-file edit. Logged as tech debt (documentation-only).
**Test Evidence**: Logic — `tests/unit/inventory/tab_categorization_test.gd`, 6/6 passing (22/22 combined with Story 001, no regression)
**Code Review**: Complete — verdict APPROVED WITH SUGGESTIONS (`/code-review`, 2026-07-15)
