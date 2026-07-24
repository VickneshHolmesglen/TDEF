# Story 008: Hero Equipment Slots & Non-Coupling

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/equipment-forge.md`
**Requirement**: `TR-equipforge-001` (slot model portion)

**ADR Governing Implementation**: ADR-0025 (Equipment Forge Cross-System Aggregation)
**ADR Decision Summary**: The hero has exactly 5 fixed equipment slots (`weapon`, `armor`, `accessory_a`, `accessory_b`, `trinket`) — originated by this GDD since `hero.md` never fixes a slot count. Equipping/unequipping is Inventory-owned; Equipment Forge only crafts/imbues items, never calls Hero directly.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No new engine subsystem — reuses ADR-0009's `GameDataRegistry` convention.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0025 directly.
- Forbidden: Equipment Forge must never call Hero directly, in either direction, for equip/unequip or stat recalculation — the only direct Hero-facing event it emits is `item_rune_imbued`, reached via Hero's own EventBus subscription, not a direct call.
- Guardrail: At `inventory_starting_slot_count = 10`, 5 mandatory-locked Hero equipment slots leaves 5 free — satisfies Inventory Rule 5a's ≥4-free floor with one slot of headroom (this check considers Hero equipment locks only, not Tower System's per-tower component locks).

---

## Acceptance Criteria

*From GDD `design/gdd/equipment-forge.md`, scoped to this story:*

- [x] AC-1 — exactly 5 named equipment slots exist; at `inventory_starting_slot_count=10`, exactly 5 discretionary slots remain free
- [x] AC-2 — an `accessory`-category item can equip into either `accessory_a` or `accessory_b`; rejected as a category mismatch for `weapon`/`armor`/`trinket`
- [x] AC-3 *(Integration/architecture check, not a unit test)* — no direct function call from Equipment Forge into Hero System exists anywhere in the rune-imbuing/crafting resolution call graph

---

## Implementation Notes

*Derived from ADR-0025 Implementation Guidelines:*

- 5 fixed Hero equipment slots: `weapon`, `armor`, `accessory_a`, `accessory_b` (both accept the generic `accessory` category, no subtype restriction at Alpha), `trinket`. This is a flagged origination — `hero.md` never fixes this number; `inventory.md`'s Rule 5a explicitly deferred its floor check until this GDD fixed a concrete number.
- Equipment items are `stack_cap=1`, unique per-instance, per `inventory.md`'s already-established schema — no new stacking rule introduced.
- Equipping/unequipping into a named Hero slot is an Inventory-owned action (`equipment_slot_changed(slot, new_item_id, previous_item_id)`, Inventory-emitted). Equipment Forge does not perform the equip action itself — it only crafts/imbues the items that end up in these slots.
- Confirmed non-direct-coupling: Hero reads equipment state passively by subscribing to `equipment_slot_changed` for stat recalculation. The only direct Hero-facing event Equipment Forge emits is `item_rune_imbued`, which Hero also reaches via its own EventBus subscription, not a direct call.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 010: the actual equipment crafting resolution flow (this story only establishes the slot/category model)
- Story 013: rune imbuing's own emission of `item_rune_imbued`

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-1**: 5 fixed slots, floor satisfied
  - Given: a fresh save with no prior slot configuration
  - When: Hero System and Inventory initialize
  - Then: exactly 5 named equipment slots exist (`weapon`, `armor`, `accessory_a`, `accessory_b`, `trinket`); at `inventory_starting_slot_count=10`, exactly 5 discretionary slots remain free

- **AC-2**: Accessory dual-slot, category mismatch rejected
  - Given: an Equipment item whose category is `accessory`
  - When: an equip action targets either `accessory_a` or `accessory_b`
  - Then: succeeds for both; when targeting `weapon`/`armor`/`trinket`, rejected as a category mismatch (Inventory-owned validation)

- **AC-3**: No direct Hero coupling *(Integration/architecture check)*
  - Given: the full call graph of Equipment Forge's rune-imbuing and crafting resolution paths
  - When: those paths are traced
  - Then: no direct function call from Equipment Forge into Hero System exists anywhere — Hero's only two data paths in are `equipment_slot_changed` and `item_rune_imbued` subscriptions
  - Edge cases: evidence is a documented code-path review, not an automated unit test, since this is an absence-of-coupling claim

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/equipment-forge/hero-equipment-slots-non-coupling_test.gd` — must exist and pass for AC-1/AC-2
- Documented code-path review for AC-3 (architecture check, not automated)

**Status**: [x] Created — `tests/integration/equipment-forge/hero-equipment-slots-non-coupling_test.gd` (14 tests, passing) + this Completion Notes section documents the AC-3 code-path review

---

## Dependencies

- Depends on: None (foundational story for this system)
- Unlocks: Story 009, Story 010

**Unblocked**: ADR-0025 accepted 2026-07-18 (Sprint 6, S6-04).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 3/3 passing (14 integration tests, all passing). AC-3's code-path review: `grep -rn "GHero\.\|Hero\.new\(\)" src/` across the entire `src/` tree confirms `equip_item()`/`unequip_item()` (the only production code this story adds) never reference Hero directly in any form — they only mutate `_slots` and emit `equipment_slot_changed`. No Equipment Forge system code exists anywhere in `src/` yet (Stories 009+ build it) — AC-3 currently holds vacuously as well as by direct inspection of what does exist.
**Deviations**: Slot/equip mechanics landed in `src/core/inventory/inventory.gd` (per ADR-0025's explicit "equip/unequip is Inventory-owned"), not a new Equipment Forge class file — consistent with the story's own Implementation Notes, not a deviation. **Real, expected regression found and fixed**: implementing Rule 5a's mandatory-lock slot occupancy (already written in `inventory.md` from an earlier design-review pass, but never actually implemented in code until this story) broke 6 pre-existing Epic 03 Inventory tests that assumed all 10 array slots were generically fillable — fixed all 6 to reflect the now-real 5-discretionary/5-locked split; not a design deviation, the GDD's own pre-existing rule finally being enforced.
**Test Evidence**: Integration — `tests/integration/equipment-forge/hero-equipment-slots-non-coupling_test.gd`.
**Code Review**: Pending — deferred to a batch pass at a later Equipment Forge checkpoint, per this session's established pattern.
