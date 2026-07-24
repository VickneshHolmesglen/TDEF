# Story 008: Back Navigation — Cancel Idiom

> **Epic**: Sanctuary UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 4/4 passing; `/story-done` verification complete)
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-07-13b
> **Estimate**: 2h

## Context

**GDD**: `design/gdd/sanctuary-ui.md`
**Requirement**: `TR-sanctuary-ui-???` (no TR-ID registered — scoped from GDD Core Rule 7 and AC Group 7)

**ADR Governing Implementation**: ADR-0011 (UI Dual-Focus Handling)
**ADR Decision Summary**: Cancel/back navigation is a focus-and-state operation, not a new input pattern — reuses each room's own established Cancel idiom.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: None beyond standard focus-return handling.

**Control Manifest Rules (this layer)**:
- Required: every focusable widget gates its focus-ring on `has_focus() AND tracker.is_focus_ring_visible()` — source: ADR-0011

---

## Acceptance Criteria

*From GDD `design/gdd/sanctuary-ui.md`, AC Group 7:*

- [x] GIVEN `ROOM_EQUIPMENT_FORGE` is active with a staged imbue confirmation pending (nested state), WHEN Cancel is pressed once, THEN the room steps back exactly one stage (staged confirmation clears) and the room's own state remains `ROOM_EQUIPMENT_FORGE` — it does not exit to `OVERVIEW`. — tested against a stub room's `handle_cancel()` contract (real Equipment Forge scene doesn't exist yet, OQ-5); the shell-level dispatch mechanism this AC actually exercises is room-content-agnostic.
- [x] GIVEN a room is at its own root (no nested state left to back out of), WHEN Cancel is pressed, THEN the active state transitions to `OVERVIEW`.

---

## Implementation Notes

Pressing Cancel (`Esc` / gamepad East face button) inside a room's own nested state steps back one stage at a time, exactly as each room's own GDD already specifies — the active state remains that room's `ROOM_*` state throughout. Pressing Cancel again once the room has nothing left to back out of (its own root) exits the room entirely: active state transitions to `OVERVIEW` (per the States and Transitions table), focus naturally lands on the tab strip since no room panel is docked there, and this also triggers Story 007's destroy-on-exit lifecycle.

No separate "leave room" action exists — this is the sole back-navigation mechanism.

This story also owns the "Cancel with focus already on the tab strip, no room open" no-op edge case (Load-Bearing Edge Cases) — folded here since it's the same Cancel-handler code path, just verifying it does nothing when there's nothing to cancel out of.

---

## Out of Scope

- Story 007: the actual destroy-and-recreate mechanics this triggers when Cancel exits a room at root
- Each room's own nested-state stepping logic — already specified by that room's own GDD, not re-implemented here

---

## QA Test Cases

- **AC-1 (Cancel steps back within a room)**
  - Given: `ROOM_EQUIPMENT_FORGE` active, staged imbue confirmation pending
  - When: Cancel pressed once
  - Then: staged confirmation clears, room state remains `ROOM_EQUIPMENT_FORGE`
  - Edge cases: repeat for Menagerie's breeding-pen flow

- **AC-2 (Cancel at root exits to OVERVIEW)**
  - Given: a room at its own root, no nested state
  - When: Cancel pressed
  - Then: active state becomes `OVERVIEW`
  - Edge cases: test for all 4 rooms

- **AC-3 (Cancel no-op with no room open)**
  - Given: `OVERVIEW` active, focus on tab strip, no room open
  - When: Cancel pressed
  - Then: no state change, error, or side effect
  - Edge cases: none additional

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/sanctuary_ui/back_navigation_test.gd`

**Status**: [x] Created — `tests/integration/sanctuary-ui/back-navigation_test.gd` (4/4 passing, verified live via headless GdUnit4, 2026-07-24)

---

## Dependencies

- Depends on: Story 007 (room lifecycle mechanics this triggers)
- Unlocks: None (leaf story)

---

## Completion Notes
**Completed**: 2026-07-24
**Criteria**: 3/3 passing
**Deviations**: None
**Test Evidence**: Logic: `tests/integration/sanctuary-ui/back-navigation_test.gd` (4/4 passing)
**Code Review**: Complete (full Sanctuary UI code-review pass, 2026-07-24)
