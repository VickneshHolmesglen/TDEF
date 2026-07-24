# Story 005: Mid-Mission Pickup Rejection

> **Epic**: Epic 03 — Core Economy
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/inventory.md`
**Requirement**: `TR-inventory-???` *(no TR-ID exists yet)*

**ADR Governing Implementation**: ADR-0016 (Inventory Storage Model)
**ADR Decision Summary**: Storage-model blocker resolved (Story 001's `InventorySlot`/capacity model defines "full"). **Remaining prerequisite, not an ADR gap**: `item_pickup_rejected` still needs to be added to `event-bus.md`'s formal catalogue and declared in `event_bus.gd` — per the GDD's own Open Questions, this is expected to happen exactly when Inventory is implemented (i.e., now), not before.

**Engine**: Godot 4.6.2 / GDScript | **Risk**: Unassessed
**Engine Notes**: None yet.

**Control Manifest Rules (this layer)**:
- Required (Global Rules): events with 1-4 data fields use typed parameters directly on signal (ADR-0001 Rule 3) — `item_pickup_rejected(item_id: String, item_type: String, quantity: int, reason: String)` is a 4-field event, fits the typed-parameter pattern, no Resource subclass needed
- Required (Global Rules): no direct runtime Node reference — Mission HUD must receive this purely via EventBus subscription

---

## Acceptance Criteria

*From GDD `design/gdd/inventory.md`, scoped to this story:*

- [x] **AC-15**: GIVEN `INVENTORY_HEADLESS`, inventory full, WHEN a pickup arrives, THEN `item_added` does NOT fire, `item_pickup_rejected` fires instead, no retry occurs.

---

## Implementation Notes

*Derived from ADR-0016 + prerequisite housekeeping:* "Full" is determined by Story 001's `InventorySlot` array/capacity model. Before writing the emission logic, first add `item_pickup_rejected(item_id: String, item_type: String, quantity: int, reason: String)` to `event-bus.md`'s catalogue and declare it in `event_bus.gd` (currently only exists in `inventory.md`'s own Interactions table). This is a small, mechanical addition, not a design decision — but it's a real prerequisite step within this story, not a separate blocker.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the "inventory full" determination itself (this story only handles the rejection *response* once fullness is already known)
- Mission HUD's actual toast/notification rendering (Mission HUD is only a skeleton GDD — its consumption of this event is its own future story)

---

## QA Test Cases

- **AC-15**: Full-inventory pickup rejection during HEADLESS state
  - Given: Inventory is in `INVENTORY_HEADLESS` state (SCOUT/WAVE_ACTIVE/INTERMISSION) and completely full (no slot has room, per Story 001's definition)
  - When: a pickup event arrives (e.g., via `materials_earned` from Resource Economy, or a Tower component return)
  - Then: `item_added` does NOT fire; `item_pickup_rejected(item_id, item_type, quantity, reason)` fires instead
  - Edge cases: confirm the rejected item is NOT queued anywhere for later retry — a subsequent slot becoming free (e.g., from consumption) must not automatically deliver the previously-rejected item

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/inventory/pickup_rejection_test.gd` — must exist and pass

**Status**: [x] Created — 10/10 passing (83/83 combined with Stories 001-004/006, live-verified, Godot 4.6.2.stable headless)

---

## Dependencies

- Depends on: Story 001 (slot/stack model, for the "is full" determination)
- Unlocks: None currently identified (Mission HUD's toast display is a separate future story once Mission HUD's own GDD is expanded)

---

## Completion Notes

**Completed**: 2026-07-15
**Criteria**: 1/1 passing (AC-15)
**Deviations**: Advisory only
- `item_added` wired into `add_unique_item()`/`add_stackable()`'s success paths — necessary to make AC-15 non-vacuous (the criterion's "does not fire" half was untestable before this story, since `item_added` never fired under any condition).
- `add_stackable()`'s partial-placement case emits both signals from one call — generalization beyond AC-15's literal wording, deliberate and documented.
- `add_stackable()`'s pre-existing `quantity <= 0` gap now visible through a negative-quantity signal payload. Logged as tech debt.
**Test Evidence**: Integration — `tests/integration/inventory/pickup_rejection_test.gd`, 10/10 passing
**Code Review**: Complete — verdict APPROVED (`/code-review`, 2026-07-15)
