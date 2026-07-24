# Story 007: Two-Panel Screen Presentation

> **Epic**: Epic 03 — Core Economy
> **Status**: Complete
> **Layer**: Core
> **Type**: UI
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/inventory.md`
**Requirement**: `TR-inventory-???` *(no TR-ID exists yet)*

**ADR Governing Implementation**: ADR-0016 (Inventory Storage Model) covers the data side. **ADR-0011 (UI Dual-Focus Handling)** — Accepted 2026-07-13 — covers the focus/gamepad-navigation implementation side.
**ADR Decision Summary**: **UNBLOCKED (2026-07-13).** ADR-0011 resolves the previously-open dual-focus gap: a reusable, scene-instanced `InputModeTracker` helper (`src/ui/input_mode_tracker.gd`, not an Autoload) is instanced per interactive UI screen, detects mouse vs. keyboard/gamepad via `_input()` event-type sniffing, and exposes `is_focus_ring_visible()`. Any focusable widget on this screen must gate its focus-ring visual on `has_focus() AND tracker.is_focus_ring_visible()`, keeping the ring visually distinct from mouse hover per `inventory.md`'s own UI Requirements. `focus_neighbor_*` must be wired explicitly per grid (not left to automatic traversal) to support the GDD's tab-wrap-at-edge navigation. This story still has no dedicated UX spec — per the design-system skill's own UX Flag on this GDD, a `/ux-design` pass for the Sanctuary Inventory screen is still recommended before or alongside implementation, with acceptance criteria ideally migrating to cite `design/ux/[screen].md` — but that is a process recommendation, not an architectural blocker.

**Engine**: Godot 4.6.2 / GDScript | **Risk**: HIGH (unchanged) — Godot 4.6's dual-focus system (`grab_focus()` sets keyboard/gamepad focus only; mouse focus is independent) still requires every interactive widget to be verified under both K/M and gamepad. ADR-0011 supplies the *mechanism*; the HIGH risk rating reflects that live verification (not just code review) is still required — see ADR-0011's Verification Required item (gamepad-driven `focus_entered` firing under dual-focus, confirmed via one live smoke test).
**Engine Notes**: See `docs/architecture/architecture.md`'s "Systems in HIGH/MEDIUM Risk Domains" table — Sanctuary UI-class screens remain flagged HIGH; ADR-0011 does not lower this to MEDIUM/LOW, it specifies the implementation that must be live-verified.

**Control Manifest Rules (this layer)**:
- Required (ADR-0011): interactive widgets show their focus ring only when `has_focus() AND InputModeTracker.is_focus_ring_visible()`; mouse hover is a fully separate signal (`mouse_entered`/`mouse_exited`), never merged with focus state.
- Required (ADR-0011): `focus_neighbor_top/bottom/left/right` wired explicitly per grid at scene-build time — do not rely on Godot's automatic nearest-neighbor traversal for the tab-wrap behavior this GDD requires.
- Note: `control-manifest.md` itself is still stale (last updated 2026-05-16, `ADRs Covered: 0001–0004`) and does not yet list these rules directly — `/create-control-manifest` is a standing recommendation from `architecture-review-2026-07-13.md`.

---

## Acceptance Criteria

*From GDD `design/gdd/inventory.md`, scoped to this story:*

- [x] **AC-13** *(UI — advisory, screenshot)*: GIVEN the player opens Inventory, WHEN it renders, THEN the grid (left) and the right-hand panel are simultaneously visible with no extra navigation.
- [x] **AC-14-focus** *(new — ADR-0011, UI/gamepad — advisory, live verification)*: GIVEN the Inventory screen is open with an `InputModeTracker` instanced, WHEN the player presses a gamepad D-pad direction with the mouse stationary over an unrelated slot, THEN the focus ring appears on the newly-focused slot with no dependency on mouse position; WHEN the player then clicks the mouse elsewhere, THEN the focus ring is hidden even though keyboard/gamepad focus has not moved. *(Verified via keyboard input — same code branch as gamepad; true physical-gamepad hardware verification remains open, see Completion Notes.)*

**Explicitly excluded from this story**: AC-14 (Crafting panel functional content) is DEFERRED per the GDD itself — Crafting has no GDD yet, so this story only covers the two-panel *layout*, not the right panel's actual content. (Note: "AC-14-focus" above is this story's own new criterion from ADR-0011, unrelated to the GDD's deferred AC-14.)

---

## Implementation Notes

Instance `InputModeTracker` (per ADR-0011) as a child of the Inventory screen's root scene. Wire the left inventory grid's slots and the right-hand panel's focusable elements to gate their focus-ring visuals on `has_focus() AND input_mode_tracker.is_focus_ring_visible()`, with mouse hover handled entirely separately via `mouse_entered`/`mouse_exited`. Wire `focus_neighbor_*` explicitly on the grid (needed by Story 002/004's tab and slot logic, not just this story's layout) rather than relying on automatic traversal. This is still a HIGH-risk story precisely because it's the project's first UI screen exercising Godot 4.6's dual-focus split in practice — budget time for the live gamepad smoke test ADR-0011 calls for, not just code review.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: tab bar content and categorization logic (this story only covers the two-panel container layout)
- Crafting panel's actual functional content (AC-14, explicitly deferred — no Crafting GDD exists)

---

## QA Test Cases

- **AC-13**: Simultaneous two-panel visibility
  - Setup: open the Inventory screen from any Sanctuary state
  - Verify: both the left inventory grid and the right-hand panel are visible in the same view, with no click/tab/navigation required to reveal the second panel
  - Pass condition: a screenshot immediately after opening the screen shows both panels simultaneously

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/two-panel-presentation-evidence.md` — screenshot evidence + sign-off

**Status**: [x] Created — `production/qa/evidence/two-panel-presentation-evidence.md`, live-verified via Godot MCP against the pinned Godot 4.6.2.stable binary

---

## Dependencies

- Depends on: Story 002 (tab categorization, since the left panel must render tabs)
- Unlocks: None currently identified

---

## Completion Notes

**Completed**: 2026-07-15
**Criteria**: 2/2 passing (AC-13, AC-14-focus)
**Deviations**: Advisory only
- ADR-0011's gamepad-hardware Verification Required item remains genuinely open — no physical gamepad in this environment; keyboard input exercises the identical `KEYBOARD_GAMEPAD` code branch but is not a substitute for the literal hardware confirmation the ADR calls for. Logged as tech debt.
- Tab/`ui_focus_next` traversal and multi-resolution `GridContainer` layout are untested paths (flagged by godot-specialist review, not defects). Logged as tech debt.
- `get_node("FocusRing")` string-based lookup — style fragility only. Logged as tech debt.
- **Real bug found and fixed during this story, not carried forward**: per-slot `Signal.connect()` of the same method to a shared signal silently failed for 9 of 10 slots (Godot dedups by object+method, ignoring `.bind()` args) — caught via live MCP testing, fixed to a single fan-out connection, re-verified. Promoted into ADR-0011 itself so future UI screens (Sanctuary UI, Tarot Deck UI) inherit the lesson.
**Test Evidence**: UI — `production/qa/evidence/two-panel-presentation-evidence.md`, live-verified
**Code Review**: Complete — verdict APPROVED WITH SUGGESTIONS (`/code-review`, 2026-07-15)
