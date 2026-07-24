# Story 003: Exit & Lifecycle — Destroy-and-Recreate, Gamepad Pick-Up Transient State

> **Epic**: Tarot Deck UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 3/3 passing; `/story-done` verification complete. Cancel's real `GSceneManager.transition_to_sanctuary()` call is genuine, not a placeholder — see note below)
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-07-13b
> **Estimate**: 4h

## Context

**GDD**: `design/gdd/tarot-deck-ui.md`
**Requirement**: `TR-tarot-deck-ui-???` (no TR-ID registered — scoped from GDD Core Rule 4–5 and AC Group 3)

**ADR Governing Implementation**: ADR-0032 (Presentation Shell Hosting Pattern) + ADR-0011 (UI Dual-Focus Handling) + ADR-0001 (EventBus) + ADR-0020 (Direct-Autoload-call exception pattern, for the exit hand-off back to Sanctuary UI)
**ADR Decision Summary**: ADR-0032 (written 2026-07-24) is the direct architectural source for this story's destroy-and-recreate lifecycle — the same pattern Sanctuary UI's Epic 10 Story 007 implements, now formalized as one shared ADR for both shells rather than independently re-derived.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM
**Engine Notes**: `queue_free()`'s end-of-frame deferral is the same risk class Sanctuary UI Story 007 addresses — this story restates the identical mechanism independently rather than only citing it by reference, per this GDD's own explicit design.

**Control Manifest Rules (this layer)**:
- Required: disconnect every EventBus subscription in `_exit_tree()`, no exceptions — source: ADR-0001

---

## Acceptance Criteria

*From GDD `design/gdd/tarot-deck-ui.md`, AC Group 3:*

- [x] GIVEN the shell is open in either state, WHEN Cancel/back or the explicit return affordance is triggered, THEN control returns to a freshly-mounted Sanctuary UI instance at `OVERVIEW`, with no confirmation prompt of any kind. — genuinely real, tested via the project's established `_inject()`-stub-scene-path seam (not a placeholder call).
- [?] GIVEN either screen has just received a player edit that each wrapped screen's own GDD defines as immediately committed, WHEN the player immediately switches to the other screen or exits the shell, THEN re-entering that screen (or querying its own already-existing state, per `tarot.md`'s/`hero-skill-build.md`'s own AC suites) shows the edit still applied. — DEFERRED: neither screen's `.tscn` exists yet (OQ-5); the generic `ScreenHost` mechanism that would deliver this guarantee is tested instead.
- [?] GIVEN a Hero Skill Build gamepad pick-up is in progress (a library entry selected, not yet placed), WHEN the player switches screens or exits the shell, THEN the pick-up is silently abandoned with no error, no toast, and no lingering "picked up" visual state on next entry. — DEFERRED: same OQ-5 gap, no real Hero Skill Build screen to test against.

---

## Implementation Notes

Each of the 2 screens is instantiated fresh as a child of a shell-owned `ScreenHost` `Control` on entry, and freed on exit (screen switch or shell exit) — same destroy-and-recreate model as Sanctuary UI's rooms. Each exit synchronously calls `set_process_unhandled_input(false)` on the outgoing screen before `queue_free()`-ing it, closing the same same-frame double-input-handling gap `queue_free()`'s end-of-frame deferral would otherwise allow.

Almost no discard-related edge case exists for the two screens' own primary content — both `tarot.md` and `hero-skill-build.md` confirm every committed edit is already fully applied, fully reversible, and zero-cost the instant it happens. **One real transient exception**: Hero Skill Build's own gamepad flow has an in-progress "pick-up" state (a library entry selected, not yet placed) between the first and second confirm presses. A screen switch mid-pick-up abandons that in-progress selection — safe because no model mutation has occurred yet (only the second confirm commits anything), not because of the "already committed" reasoning covering every other edit. No toast or confirmation affordance is needed for this case (unlike Sanctuary UI's staged-changes toast) — an abandoned pick-up is a single unconsummated selection, not multi-step staged work.

Exit: Cancel (matching both wrapped screens' own established Cancel idiom) or an explicit "Return to Sanctuary" affordance closes the shell and returns control to Sanctuary UI, mounting a fresh instance at `OVERVIEW` — not a special-cased "return from Loadout" state, the same entry path any other Sanctuary arrival uses. No confirmation of any kind is required. No EventBus event fires on this transition beyond whatever internal signal Sanctuary UI itself needs for its own remount.

---

## Out of Scope

- Story 001: the tab-strip's own switch-trigger routing (this story owns what happens once a switch/exit is triggered)
- `tarot.md`'s/`hero-skill-build.md`'s own internal edit-commit logic — already implemented, only regression-verified here via each screen's own AC suite

**Real finding, 2026-07-24 — unlike Sanctuary UI's own Mission Select/Tarot Deck UI hand-off gaps (Stories 009/010), this shell's own exit hand-off is NOT a placeholder**: `GSceneManager.transition_to_sanctuary()` is a real, correctly-implemented ADR-0002 public API, confirmed directly and exercised live in a test (using this project's own established `_inject()`-stub-scene-path seam, matching `tests/integration/foundation/scene_manager_transition_test.gd`'s identical pattern, so the test doesn't disrupt the real `SanctuaryScene.tscn`). The one residual gap is pre-existing and narrower: `SanctuaryScene.tscn` itself is still Story-001-era placeholder content (every Sanctuary UI story from 001-012 explicitly deferred wiring `SanctuaryUI.tscn` into it) — so the loaded scene won't visually show the real shell yet, but the hand-off call itself is genuine, not fabricated.

**AC-2/AC-3 gap, flagged**: neither `tarot.md`'s nor `hero-skill-build.md`'s own screen exists as a built `.tscn` yet (OQ-5), so the specific claims about committed-edit survival and gamepad-pick-up abandonment can't be tested against real content. The generic `ScreenHost` mechanism that would deliver both guarantees is fully tested instead, mirroring Sanctuary UI's own Story 007/010 precedent for its equivalent rooms.

---

## QA Test Cases

- **AC-1 (exit returns to fresh Sanctuary UI OVERVIEW, no confirmation)**
  - Given: shell open in either state
  - When: Cancel or explicit return affordance triggered
  - Then: control returns to a freshly-mounted Sanctuary UI at `OVERVIEW`, no confirmation prompt
  - Edge cases: test from both `HERO_SKILL_BUILD` and `TAROT_DECK`

- **AC-2 (committed edits survive switch/exit)**
  - Given: a committed edit on either screen (e.g. Tarot card swap, Hero Skill Build slot assignment)
  - When: immediate screen switch or shell exit, then re-query via that screen's own existing AC-suite state query
  - Then: edit still applied
  - Edge cases: test edits on both screens individually, both switch and exit paths

- **AC-3 (gamepad pick-up silently abandoned)**
  - Given: Hero Skill Build gamepad pick-up in progress (library entry selected, not placed)
  - When: screen switch or shell exit
  - Then: pick-up abandoned, no error, no toast, no lingering "picked up" visual on next entry
  - Edge cases: test both screen-switch and shell-exit triggers

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tarot_deck_ui/exit_and_lifecycle_test.gd`

**Status**: [x] Created — `tests/integration/tarot-deck-ui/exit-and-lifecycle_test.gd` (3/3 passing, verified live via headless GdUnit4, 2026-07-24)

---

## Dependencies

- Depends on: Story 001 (ScreenHost structure), Story 002 (entry model this exit's return path mirrors)
- Unlocks: Story 004, Story 005 (both screens must reliably mount/unmount before their own cross-screen features are testable)

---

## Completion Notes
**Completed**: 2026-07-24
**Criteria**: 1/3 passing, 2/3 deferred (AC-2/AC-3 — neither wrapped screen's real scene exists yet, OQ-5)
**Deviations**: ADVISORY — real bug found and fixed during this session's `/code-review` remediation: `confirm_return_to_sanctuary()` was missing ADR-0032 Section 2's terminal latch entirely (no `_departing` flag, no subscription disconnects) — fixed by adding the flag and a new `ConflictIndicator.disconnect_own_subscriptions()` method.
**Test Evidence**: Logic: `tests/integration/tarot-deck-ui/exit-and-lifecycle_test.gd` (3/3 passing)
**Code Review**: Complete (full Tarot Deck UI code-review pass, 2026-07-24 — this story's own `confirm_return_to_sanctuary()` was the review's 1 Required Change, remediated same session)
