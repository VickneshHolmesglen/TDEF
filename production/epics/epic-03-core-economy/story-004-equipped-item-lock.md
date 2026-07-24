# Story 004: Equipped-Item Lock

> **Epic**: Epic 03 — Core Economy
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/inventory.md`
**Requirement**: `TR-inventory-???` *(no TR-ID exists yet)*

**ADR Governing Implementation**: ADR-0016 (Inventory Storage Model)
**ADR Decision Summary**: `InventorySlot.locked: bool` is Inventory's own per-slot flag — Inventory does not query Hero/Tower live. Inventory sets `locked=true` when it emits `equipment_slot_changed`/equivalent on equip, and clears it on unequip. Removal-attempt and capacity-check logic both read this flag directly, per the Decision's Key Interfaces.

**Engine**: Godot 4.6.2 / GDScript | **Risk**: Unassessed
**Engine Notes**: None yet.

**Control Manifest Rules (this layer)**:
- Required (Global Rules): no direct runtime Node reference to any other system — lock-state determination must go through EventBus, not a direct query into Hero/Tower nodes

---

## Acceptance Criteria

*From GDD `design/gdd/inventory.md`, scoped to this story:*

- [x] **AC-11**: GIVEN an equipped/installed item, WHEN a remove/discard is attempted, THEN it's rejected and the item stays unchanged.
- [x] **AC-12**: GIVEN an equipped/installed item occupying a slot, WHEN the full-capacity check runs, THEN that slot counts toward the cap. *(Note, corrected 2026-07-15: Equipment and Tower Components are both `is_unique_instance=true`/cap=1 per Story 001's data model, not two distinct cap-type cases as this AC's wording implies — the actually-orthogonal axis, unique-instance vs. stackable, is what the test suite covers.)*

---

## Implementation Notes

*Derived from ADR-0016:* `InventorySlot.locked: bool` is the single source of truth — check it at both the removal-attempt gate and the capacity-check gate. Note the GDD's explicit framing: locked items are "not exempted from capacity" — this is a two-part rule (rejection on removal attempt, AND continued cap consumption) that must both be tested, not just the removal-rejection half.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the base slot/stack storage and cap-checking mechanism this story adds a lock condition to
- Actual equip/unequip flow itself (owned by Hero System / Tower System, not Inventory)

---

## QA Test Cases

- **AC-11**: Locked-item removal rejection
  - Given: a slot holding an item currently equipped (Hero gear) or installed (active Tower Component)
  - When: a remove or discard action is attempted on that slot
  - Then: the action is rejected and the item remains unchanged in its slot
  - Edge cases: attempting removal via every available code path (direct API call, UI action if wired) must be rejected consistently — no path should bypass the lock check

- **AC-12**: Locked item counts against cap
  - Given: an equipped/installed item occupying a slot, and the Inventory otherwise at (N-1)/N capacity
  - When: the full-capacity check runs
  - Then: the locked slot counts toward the total — the Inventory reports as fully at capacity, not with one "free" slot
  - Edge cases: verify this holds for both Equipment (cap=1) and installed Tower Components — the lock rule is orthogonal to stack-cap type

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/inventory/equipped_lock_test.gd` — must exist and pass

**Status**: [x] Created — 11/11 passing (60/60 combined with Stories 001/002/003, live-verified, Godot 4.6.2.stable headless)

---

## Dependencies

- Depends on: Story 001 (slot/stack model)
- Unlocks: None currently identified

---

## Completion Notes

**Completed**: 2026-07-15
**Criteria**: 2/2 passing (AC-11, AC-12)
**Deviations**: Advisory only
- `set_slot_locked()` is a mechanism with no live caller yet — real equip/unequip EventBus wiring deferred to a future Hero/Tower-integration story (explicit Out of Scope).
- No test proves `remove_item()` nulls a stackable slot regardless of quantity — flagged as real regression risk once Story 006 (partial-consumption) touches this area. Logged as tech debt.
**Test Evidence**: Logic — `tests/unit/inventory/equipped_lock_test.gd`, 11/11 passing
**Code Review**: Complete — verdict APPROVED WITH SUGGESTIONS (`/code-review`, 2026-07-15)
