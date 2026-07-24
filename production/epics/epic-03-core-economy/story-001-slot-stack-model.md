# Story 001: Slot & Stack Model

> **Epic**: Epic 03 — Core Economy
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/inventory.md`
**Requirement**: `TR-inventory-???` *(no TR-ID exists yet — `/architecture-review` has not run against this GDD; assign at that time)*

**ADR Governing Implementation**: ADR-0016 (Inventory Storage Model)
**ADR Decision Summary**: Two-tier model — static `ItemDefinitionResource` (loaded via `GameDataRegistry`, per ADR-0009's convention) + lightweight runtime `InventorySlot` (`RefCounted`, not a Resource) holding `item_id`, `quantity`, `instance_id` (monotonic counter, `-1` for stackable), `stat_overrides`, `locked`. Unique-instance non-merging is keyed on `instance_id`, never on `item_id`/stat equality.

**Engine**: Godot 4.6.2 / GDScript | **Risk**: Unassessed (no ADR to derive Engine Compatibility notes from)
**Engine Notes**: None yet — flag any Resource-copying concerns for the eventual ADR given `architecture.md`'s existing MEDIUM-risk note on `duplicate()` vs `duplicate_deep()` for nested Resources (4.5+ API change).

**Control Manifest Rules (this layer)**:
- Required (Global Rules): gameplay values must be data-driven, never hardcoded; all public methods must be unit-testable via dependency injection, no singleton coupling
- Required (Global Rules): no direct runtime Node reference to any other system — all cross-system communication via EventBus
- Forbidden (Global Rules): untyped `Array`/`Dictionary` where a typed variant is possible

---

## Acceptance Criteria

*From GDD `design/gdd/inventory.md`, scoped to this story:*

- [x] **AC-1**: GIVEN a freshly initialized Inventory with no save data, WHEN it starts up, THEN it exposes exactly 10 slots, all empty.
- [x] **AC-2**: GIVEN any occupied slot, WHEN its contents are queried, THEN it holds exactly one stack of exactly one `item_id`.
- [x] **AC-3**: GIVEN an empty slot, WHEN a stat-rolled Equipment/Tower Component instance is added, THEN the resulting stack has quantity 1 and cap 1.
- [x] **AC-4**: GIVEN a Material/generic Crafted Good stack at quantity 99 in slot N, WHEN one more unit is added, THEN the pickup is not blocked, a new stack of quantity 1 is created in the next open slot, and slot N remains at 99.
- [x] **AC-18**: GIVEN two independently stat-rolled instances of the same item definition, WHEN both are added, THEN they occupy two distinct slots and never merge.

---

## Implementation Notes

*Derived from ADR-0016's Decision and Key Interfaces:*

- `InventorySlot` is a plain `class_name InventorySlot extends RefCounted` — not a Resource. Fields: `item_id: StringName`, `quantity: int`, `instance_id: int`, `stat_overrides: Dictionary`, `locked: bool`.
- `ItemDefinitionResource` is loaded once at boot via `GameDataRegistry` (Autoload position 5). Query it with `GameDataRegistry.get_item_definition(item_id)`.
- Unique-instance identity: Inventory owns `_next_instance_id: int`, a monotonic counter persisted in `get_save_data()`. Every stat-rolled pickup gets a new `instance_id`; two identical rolls of the same `item_id` get different `instance_id` values and must never merge (AC-18).
- Stack-cap type (1 vs 99) is driven by `ItemDefinitionResource.is_unique_instance: bool`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: tab categorization and `item_type` → tab mapping
- Story 003: slot expansion / tier progression
- Story 004: equipped-item lock behavior
- Story 006: partial-stack consumption and slot-index stability

---

## QA Test Cases

- **AC-1**: Slot count on fresh init
  - Given: no save data exists for this Inventory instance
  - When: the Inventory initializes
  - Then: `get_slot_count()` returns 10, and every slot's contents are empty/null
  - Edge cases: initializing twice in the same session must not double-allocate slots

- **AC-2**: One stack per slot invariant
  - Given: any slot with contents
  - When: the slot is queried
  - Then: exactly one `item_id` and one quantity value are returned — never a list or multiple stacks in one slot
  - Edge cases: querying an empty slot returns a well-defined empty/null result, not an error

- **AC-3**: Unique-instance cap enforcement
  - Given: an empty slot and a stat-rolled Equipment or Tower Component instance
  - When: `add_item()` is called with that instance
  - Then: the resulting stack has `quantity == 1` and `cap == 1`
  - Edge cases: attempting to add a second unit of the *same instance ID* to an already-occupied cap=1 slot must be rejected, not silently ignored

- **AC-4**: Stackable overflow to new slot
  - Given: a Material/Crafted-Good stack at exactly quantity 99 in slot N
  - When: one more unit of the same `item_id` is added
  - Then: slot N remains at 99, a new stack of quantity 1 appears in the next open slot, and the pickup is not blocked
  - Edge cases: overflow when there is no open slot at all is out of scope here — covered by Story 005 (pickup rejection)

- **AC-18**: Stat-rolled duplicates never merge
  - Given: two separately stat-rolled instances of the same item definition (identical rolled stats permitted)
  - When: both are added
  - Then: they occupy two distinct slots, each individually cap=1
  - Edge cases: verify this holds even when the two rolls produce byte-identical stat blocks — merging must be keyed on instance ID, never on stat equality

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/inventory/slot_stack_model_test.gd` — must exist and pass

**Status**: [x] Created — 16/16 passing (live-verified, Godot 4.6.2.stable headless)

---

## Dependencies

- Depends on: None (this is the foundational story for the epic)
- Unlocks: Story 002, Story 003, Story 004, Story 006

---

## Completion Notes

**Completed**: 2026-07-15
**Criteria**: 5/5 passing (AC-1, AC-2, AC-3, AC-4, AC-18)
**Deviations**: Advisory only — see below; no blocking deviations
- Tuning constants (`STARTING_SLOT_COUNT`, `STACK_CAP_STACKABLE`, `STACK_CAP_UNIQUE`) are named consts in `inventory.gd`, consistent with existing project precedent (`hero.gd`'s `RESTORE_ORDER`, `save_persistence.gd`'s `AUTOSAVE_INTERVAL`) for system-tuning values vs. per-content balance data.
- `restore_save_data()` lacks range/collision validation on restored `quantity`/`instance_id`; `add_stackable()` has no `quantity <= 0` guard. Logged as tech debt (see `docs/tech-debt-register.md`).
**Test Evidence**: Logic — `tests/unit/inventory/slot_stack_model_test.gd`, 16/16 passing
**Code Review**: Complete — verdict APPROVED WITH SUGGESTIONS (`/code-review`, 2026-07-15)
