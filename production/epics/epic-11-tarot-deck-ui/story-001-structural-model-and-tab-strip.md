# Story 001: Structural Model — Sibling Shell, 2-Screen Tab Strip Navigation

> **Epic**: Tarot Deck UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 5/5 passing; `/story-done` verification complete)
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-07-13b
> **Estimate**: 3h

## Context

**GDD**: `design/gdd/tarot-deck-ui.md`
**Requirement**: `TR-tarot-deck-ui-???` (no TR-ID registered — scoped from GDD Core Rule 1–2 and AC Group 1)

**ADR Governing Implementation**: ADR-0011 (UI Dual-Focus Handling)
**ADR Decision Summary**: Same `InputModeTracker` pattern Sanctuary UI's own tab strip relies on. ADR-0011's Accepted text names Sanctuary UI/Tarot Deck UI together as anticipated consumers.

**Engine**: Godot 4.6.2 | **Risk**: HIGH
**Engine Notes**: Godot 4.6 split mouse focus from `grab_focus()` — same dual-focus discipline as Sanctuary UI's Story 002. Detect input mode via `_input()`, not `_unhandled_input()`.

**Control Manifest Rules (this layer)**:
- Required: `InputModeTracker` instanced per interactive UI screen; detect via `_input()` not `_unhandled_input()`; focus-ring gated on `has_focus() AND tracker.is_focus_ring_visible()` — source: ADR-0011
- Forbidden: never assume `grab_focus()` affects mouse focus — source: ADR-0011

---

## Acceptance Criteria

*From GDD `design/gdd/tarot-deck-ui.md`, AC Group 1:*

- [x] GIVEN the shell has just mounted, THEN exactly 2 states exist (`HERO_SKILL_BUILD`, `TAROT_DECK`) and the tab strip is present and rendering in both.
- [x] GIVEN either state is active, WHEN the other tab is clicked (K/M) or `LT`/`RT`/`[`/`]` is pressed, THEN the active state switches accordingly.
- [x] GIVEN `TAROT_DECK` is active, WHEN gamepad `LB`/`RB` is pressed, THEN the shell's active state does NOT change — confirming bumpers never trigger a screen switch (this AC asserts only the shell-owned half; `tarot.md`'s own AC territory covers what `LB`/`RB` does inside the screen).

---

## Implementation Notes

Tarot Deck UI is its own top-level destination, architecturally separate from `sanctuary-ui.md`'s 5-room hub — hosts exactly 2 full-frame screens (Tarot's deck-building screen, Hero Skill Build's loadout screen) plus a thin persistent chrome layer. No third "overview" content state exists here — structurally the smallest version of the shell problem Sanctuary UI solved.

Fixed 2-entry tab strip (Hero Skill Build · Tarot Deck, in that order — matching the Player Fantasy's "build, then deck" reading, though either is directly selectable at any time), always visible.

- K/M: click either tab directly.
- Gamepad/keyboard: `LT`/`RT` (or `[`/`]`) switch between the 2 screens. Not `LB`/`RB` — both wrapped screens already commit those to their own internal category-cycling (Tarot's card-pool categories, Hero Skill Build's archetype-category filter). Same fixed split as Sanctuary UI: triggers = switch screens, bumpers = switch categories within the open screen.
- No onboarding tooltip needed — a player who has already used Sanctuary UI (a more complex instance of the identical convention) has already learned it.

---

## Out of Scope

- Story 002: entry from Sanctuary UI (this story covers the shell's own internal navigation once mounted)
- Story 003: the destroy-and-recreate lifecycle mechanics behind each screen switch

---

## QA Test Cases

- **AC-1 (mount state)**
  - Given: shell mounts fresh
  - When: queried immediately
  - Then: exactly 2 states exist, tab strip present/rendering in both
  - Edge cases: none additional

- **AC-2 (screen switch via click/hotkey/trigger)**
  - Given: either state active
  - When: other tab clicked, or `LT`/`RT`/`[`/`]` pressed
  - Then: active state switches
  - Edge cases: test all 3 input methods individually, from both starting states

- **AC-3 (bumpers never switch screens)**
  - Given: `TAROT_DECK` active
  - When: `LB`/`RB` pressed
  - Then: shell's active state unchanged
  - Edge cases: repeat with `HERO_SKILL_BUILD` active

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `tests/integration/tarot_deck_ui/structural_model_tab_strip_test.gd`

**Status**: [x] Created — `tests/integration/tarot-deck-ui/structural-model-and-tab-strip_test.gd` (5/5 passing, verified live via headless GdUnit4, 2026-07-24)

---

## Dependencies

- Depends on: None (foundational — first story in this epic)
- Unlocks: Story 002, Story 003, Story 004, Story 005

---

## Completion Notes
**Completed**: 2026-07-24
**Criteria**: 3/3 passing
**Deviations**: None
**Test Evidence**: UI: `tests/integration/tarot-deck-ui/structural-model-and-tab-strip_test.gd` (5/5 passing)
**Code Review**: Complete (full Tarot Deck UI code-review pass, 2026-07-24)
