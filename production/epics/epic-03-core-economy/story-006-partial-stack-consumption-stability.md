# Story 006: Partial Stack Consumption Stability

> **Epic**: Epic 03 — Core Economy
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/inventory.md`
**Requirement**: `TR-inventory-???` *(no TR-ID exists yet)*

**ADR Governing Implementation**: ADR-0016 (Inventory Storage Model)
**ADR Decision Summary**: `Array[InventorySlot]` is index-stable by design (ADR-0016's GDD Requirements table explicitly cites AC-17) — consumption mutates `InventorySlot.quantity` in place, never re-indexes or compacts the array.

**Engine**: Godot 4.6.2 / GDScript | **Risk**: Unassessed
**Engine Notes**: None yet.

**Control Manifest Rules (this layer)**:
- Required (Global Rules): all public methods must be unit-testable via dependency injection

---

## Acceptance Criteria

*From GDD `design/gdd/inventory.md`, scoped to this story:*

- [x] **AC-17**: GIVEN a 99-quantity Material stack at slot N, WHEN 40 units are consumed, THEN slot N holds 59 at the same index, `item_removed` fires with quantity 40, no compaction occurs.

---

## Implementation Notes

*Derived from ADR-0016:* consumption mutates `InventorySlot.quantity` at the existing array index — never removes/re-inserts/shifts array elements. The GDD is explicit that this must not trigger a slot-compaction pass — called out specifically because save/load and drag-drop UI would otherwise disagree on slot stability if consumption silently repacked the array. Do not "optimize" partial consumption into a compaction step even if it seems tidier — it's an explicit anti-requirement.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: full/zero-quantity add and stack-cap behavior (this story only covers the partial-consumption path)
- Full-stack depletion to exactly 0 (an empty slot after full consumption) — not explicitly covered by this story's AC-17 scope; confirm behavior when scoping test cases, but do not expand this story's boundaries without an explicit new AC

---

## QA Test Cases

- **AC-17**: Partial consumption preserves slot index
  - Given: a Material stack at quantity 99 in slot N
  - When: 40 units are consumed (e.g., via a Crafting-style batch-consume call)
  - Then: slot N holds exactly 59, still at index N; `item_removed` fires with quantity 40; no other slot's index changes
  - Edge cases: consuming exactly 99 (full depletion) is a boundary condition worth testing even though not explicitly in AC-17's wording — confirm whether the slot becomes empty-but-present-at-index-N, or is removed from the array (this ambiguity should be raised as a follow-up question if the ADR doesn't resolve it)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/inventory/stack_consumption_test.gd` — must exist and pass

**Status**: [x] Created — 13/13 passing (73/73 combined with Stories 001-004, live-verified, Godot 4.6.2.stable headless)

---

## Dependencies

- Depends on: Story 001 (slot/stack model)
- Unlocks: None currently identified

---

## Completion Notes

**Completed**: 2026-07-15
**Criteria**: 1/1 passing (AC-17)
**Deviations**: Advisory only
- `consume_stackable()` takes `ItemDefinitionResource` rather than the story's illustrative `(item_id, item_type, quantity)` signature — consistent with sibling mutation methods.
- Single-slot-only consumption (no cross-slot aggregation) — matches AC-17's literal wording, explicitly tested as deliberate.
- Locked stackable slots reject consumption — Story 004 precedent extension, not textually mandated.
- One real correctness gap found during code review (locked slot at a lower index spuriously blocking an eligible unlocked slot elsewhere) was fixed and independently re-verified before closure — not deferred as tech debt.
**Test Evidence**: Logic — `tests/unit/inventory/stack_consumption_test.gd`, 13/13 passing
**Code Review**: Complete — verdict APPROVED (`/code-review`, 2026-07-15, after one fix cycle)
