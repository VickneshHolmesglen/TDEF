# Story 003: Slot Expansion & Cost Table

> **Epic**: Epic 03 — Core Economy
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/inventory.md`
**Requirement**: `TR-inventory-???` *(no TR-ID exists yet)*

**ADR Governing Implementation**: ADR-0016 (Inventory Storage Model)
**ADR Decision Summary**: ADR-0016 establishes the `GameDataRegistry`/Resource-subclass convention for Inventory's data; the 5-tier cost table itself should follow the same pattern (a small Resource array or equivalent data-driven table), consumed against `InventorySlot` quantities on the Materials tab per Story 001's model. ADR-0016 does not itself enumerate the cost-table schema in detail — treat it as an extension of the established pattern, not a new decision.

**Engine**: Godot 4.6.2 / GDScript | **Risk**: Unassessed
**Engine Notes**: None yet.

**Control Manifest Rules (this layer)**:
- Required (Global Rules): gameplay values must be data-driven — this story's cost table is the textbook case; it must never be hardcoded as inline literals in a function body
- Required (Global Rules): all public methods must be unit-testable via dependency injection

---

## Acceptance Criteria

*From GDD `design/gdd/inventory.md`, scoped to this story:*

- [x] **AC-8**: GIVEN the current slot tier, WHEN each expansion completes, THEN capacity increases exactly as 10→16→22→28→34→40 (max); no Tier 6 exists.
- [x] **AC-9**: GIVEN tier index 1–5, WHEN the material cost is checked, THEN it matches the Formulas table exactly: 10/18/28/36/45 Common; —/4/10/18/28 Uncommon; —/—/—/5/12 Rare.
- [x] **AC-10**: GIVEN Tier 4 (28→34), WHEN the material requirement is checked, THEN it requires all 3 rarity tiers, Rare appearing for the first time.
- [x] **AC-16**: GIVEN slot tier at max (40/40), WHEN another expansion is attempted, THEN it's blocked at the eligibility check, no materials deducted, no event fires.

---

## Implementation Notes

*Cannot be derived from an ADR — none exists.* The GDD's own Formulas section (2026-07-10 correction) is explicit that the cost table is hand-tuned, **not** formula-derived — a prior draft's `round(10 × 1.35^(tier-1))` formula was found wrong and removed. Implementers must hardcode-as-data the exact table values (10/18/28/36/45 Common; 4/10/18/28 Uncommon at tiers 2-5; 5/12 Rare at tiers 4-5) — do not attempt to "clean up" this into a closed-form expression; the GDD explicitly states no such formula reproduces these values.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the base slot/stack storage this expansion operates on
- Resource Economy's material-earning flow (separate epic scope — this story only covers spending against whatever the player already has in Inventory)

---

## QA Test Cases

- **AC-8**: Tier progression sequence
  - Given: the Inventory at any tier 1-4
  - When: an eligible expansion completes
  - Then: capacity increases to the exact next value in the sequence 10→16→22→28→34→40
  - Edge cases: attempting to skip a tier (e.g., jump from Tier 1 directly to Tier 3) must not be possible via any code path

- **AC-9**: Cost table exact match
  - Given: each tier index 1 through 5
  - When: the material cost is queried
  - Then: it returns exactly 10/18/28/36/45 Common, —/4/10/18/28 Uncommon, —/—/—/5/12 Rare (per tier)
  - Edge cases: querying tier 0 or tier 6 (out of range) must fail explicitly, not return a default/zero cost

- **AC-10**: Tier 4 rarity gate
  - Given: Tier 4 (28→34 expansion)
  - When: the material requirement is checked
  - Then: it requires Common, Uncommon, AND Rare material — Rare appearing for the first time at this tier
  - Edge cases: confirm Tier 1-3 never require Rare material under any circumstance

- **AC-16**: Max-tier expansion block
  - Given: slot tier already at max (40/40, Tier 5 complete)
  - When: another expansion is attempted
  - Then: the action is blocked at the eligibility check — no materials are deducted, no event fires
  - Edge cases: this must be a UI-disableable state (the button/action shouldn't even be reachable), not merely a runtime rejection after the fact

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/inventory/slot_expansion_test.gd` — must exist and pass

**Status**: [x] Created — 27/27 passing (49/49 combined with Stories 001/002, live-verified, Godot 4.6.2.stable headless)

---

## Dependencies

- Depends on: Story 001 (slot/stack model)
- Unlocks: None currently identified

---

## Completion Notes

**Completed**: 2026-07-15
**Criteria**: 4/4 passing (AC-8, AC-9, AC-10, AC-16)
**Deviations**: Advisory only
- `attempt_expand_slots()` takes rarity-quantities as caller-supplied input rather than resolving real Inventory contents — genuine GDD-acknowledged gap (no material-rarity vocabulary exists; Crafting's future GDD owns real resolution). Logged as tech debt.
- No EventBus signal for expansion completion, despite the GDD's Visual/Audio section implying one should exist eventually — Inventory still emits nothing per Story 001's scope. Logged as tech debt.
- One test gap (missing-key vs. explicit-zero equivalence not paired-tested). Logged as tech debt.
**Test Evidence**: Logic — `tests/unit/inventory/slot_expansion_test.gd`, 27/27 passing
**Code Review**: Complete — verdict APPROVED WITH SUGGESTIONS (`/code-review`, 2026-07-15)
