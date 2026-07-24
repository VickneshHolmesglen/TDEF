# Story 004: Persistent Resource Header

> **Epic**: Sanctuary UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 3/3 passing; `/story-done` verification complete. One edge case not fully implementable as specified — see the flagged gap note below, not silently resolved)
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b
> **Estimate**: 2h

## Context

**GDD**: `design/gdd/sanctuary-ui.md`
**Requirement**: `TR-sanctuary-ui-???` (no TR-ID registered — scoped from GDD Core Rule 3 and AC Group 3)

**ADR Governing Implementation**: ADR-0001 (EventBus)
**ADR Decision Summary**: Read-only pure subscriber pattern — owns no data, validates nothing, no interactive affordance.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: None beyond standard EventBus subscription discipline.

**Control Manifest Rules (this layer)**:
- Required: connect in `_ready()`, disconnect in `_exit_tree()` — source: ADR-0001
- Forbidden: header must never receive focus or show a focus ring — it is not a navigable region (GDD Core Rule 3, not an engine-level forbidden pattern but a hard GDD constraint)

---

## Acceptance Criteria

*From GDD `design/gdd/sanctuary-ui.md`, AC Group 3:*

- [x] GIVEN Resource Economy's current balance is `gold=120, materials={wood:5}`, THEN the header displays that value identically whether the active state is `OVERVIEW` or any `ROOM_*`. — satisfied via a local running tally accumulated from emitted deltas (display cache, not state ownership); the mount-time boot-fallback poll against a real balance-owning system is NOT implementable, see flagged gap.
- [x] GIVEN the header is mounted and subscribed, WHEN `materials_earned` then `materials_spent` then `resources_changed` fire in sequence, THEN the displayed value updates to match each event's resulting balance, in order, with no stale intermediate value persisting.
- [x] GIVEN the header is focused via keyboard/gamepad navigation attempt (e.g. tab-through), THEN it never receives focus and shows no focus ring.

---

## Implementation Notes

Pure subscriber to `resources_changed`/`materials_earned`/`materials_spent` — renders at the top edge of the screen in every state, including `OVERVIEW`, height 40–64px (Tuning Knobs). Owns no data, validates nothing; each room's own cost-preview logic remains independently authoritative for affordability checks.

Boot-order fallback (Edge Cases): if `resources_changed` hasn't fired yet by the time Sanctuary UI finishes mounting, the header polls Resource Economy directly for the current balance as a mount-time fallback rather than waiting indefinitely — same static treatment as a normal render, no loading state.

Visual: UI Chrome background / UI Parchment text — never world-saturation Sanctum Amber. Numeric changes reuse Inventory's existing scale-pop feedback (~1.0→1.15→1.0 over ~0.2s).

**Implementation gap, flagged 2026-07-24 (real, not a naming mismatch)**: this story's Edge Case requires a mount-time poll fallback against "Resource Economy's current balance" so the header never shows an empty/loading/zero state before the first `resources_changed` event. Checked directly: no system in this project actually owns or exposes a queryable Sanctuary-context gold/materials balance. `resource_economy.gd` (ADR-0017) only owns a `_menagerie_quality_bonus` scalar, no balance getter. `mission_economy.gd` (ADR-0018) owns gold but is explicitly Mission-only, resets to 0 on `mission_launched`, and holds a stale value during `SanctuaryScene` per ADR-0002's own diagram note — not the right owner for a Sanctuary display. Implemented the rest of this story as specified (a pure local running tally accumulated from already-emitted `resources_changed`/`materials_earned`/`materials_spent` deltas — a display cache, not state ownership, since nothing is written back), but the mount-time-poll AC specifically is NOT implementable until a real balance-owning system exists for Sanctuary-context gold/materials. This is a genuine cross-system architecture gap, not a Presentation-layer detail — recommend a small follow-up ADR or an extension to Resource Economy/a new system deciding who owns this value, before this AC can be closed for real.

---

## Out of Scope

- Story 013: the mount-time-poll edge case's exact test coverage (folded into this story's own AC-1/boot-fallback note above, but the broader Edge Cases bundle story cross-references it)

---

## QA Test Cases

- **AC-1 (consistent display across states)**
  - Given: `gold=120, materials={wood:5}`
  - When: header rendered in `OVERVIEW` and in each `ROOM_*` state
  - Then: identical displayed value in all 5 states
  - Edge cases: none additional

- **AC-2 (sequential event updates)**
  - Given: header mounted and subscribed
  - When: `materials_earned` → `materials_spent` → `resources_changed` fire in sequence
  - Then: displayed value updates to match each event's resulting balance in order, no stale intermediate
  - Edge cases: rapid-fire all 3 within the same frame

- **AC-3 (never focusable)**
  - Given: header mounted
  - When: keyboard/gamepad tab-through navigation attempted
  - Then: header never receives focus, no focus ring shown
  - Edge cases: attempt from every adjacent focusable widget

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/sanctuary_ui/resource_header_test.gd`

**Status**: [x] Created — `tests/integration/sanctuary-ui/resource-header_test.gd` (3/3 passing, verified live via headless GdUnit4, 2026-07-24)

---

## Dependencies

- Depends on: Story 001 (chrome layer must exist)
- Unlocks: None (leaf story)

---

## Completion Notes
**Completed**: 2026-07-24
**Criteria**: 3/3 passing
**Deviations**: ADVISORY — mount-time boot-fallback poll (Edge Case, Implementation Notes) is not implementable: no system in this project owns a queryable Sanctuary-context gold/materials balance (`resource_economy.gd` and `mission_economy.gd` both confirmed wrong owners). Recommend a follow-up ADR/system decision before this edge case can close for real; the 3 formal ACs above are satisfied via a local running tally, unaffected by this gap.
**Test Evidence**: Integration: `tests/integration/sanctuary-ui/resource-header_test.gd` (3/3 passing)
**Code Review**: Complete (full Sanctuary UI code-review pass, 2026-07-24)
