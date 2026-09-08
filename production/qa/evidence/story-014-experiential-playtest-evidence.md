# Story 014 Evidence — Experiential Playtest (Player Fantasy, Loadout Continuity, Badge Legibility)

**Date**: 2026-09-08
**Playtester**: Vicknesh
**Session type**: Informal — this was NOT the full 3-scenario moderated debrief the story's own
Implementation Notes specify (mission-complete → `OVERVIEW` debrief; mid-room Loadout-selection
debrief; engineered Connection Badge debrief). Only the badge-legibility scenario was actually
exercised, and only informally (no scripted mission-complete or mid-room-Loadout walkthrough).
**Story status**: Still not closable from this session alone — 2 of 3 ACs remain untested. See
"What's still open" below.

---

## What was played

Player launched the game, navigated to Sanctuary UI, and used the Skills tab (`ROOM_HERO_SKILLS`,
`design/gdd/hero-skills-room.md`) — toggling between the Loadout and Skill Tree sub-screens.

**Player's own words**: "played it, feels fine, badge wasn't very noticeable"

## AC-by-AC status

- **AC-1 (Player Fantasy "step back and look")** — NOT TESTED this session. No mission-complete →
  `OVERVIEW` debrief occurred.
- **AC-2 (Loadout "one continuous motion")** — NOT TESTED this session as the story's own scripted
  scenario (mid-room Loadout selection specifically). The Skills-room Loadout/Skill Tree toggle the
  player did try got a positive but informal signal ("feels fine") — not a substitute for the
  scripted test, which is about reaching Loadout via Sanctuary UI's Core Rule 10 hand-off, a
  different flow than the Skills room's internal sub-screen toggle.
- **AC-3 (Connection Badge legibility)** — **TESTED, real finding, root-caused and fixed same
  session.** Player noticed the badge on the Skills tab was not noticeable. This was not a vague
  subjective miss — code inspection confirmed a genuine bug (see below), fixed and live-verified
  via Godot MCP before this evidence was recorded. Re-test with a real player after this fix is
  still recommended before treating AC-3 as passing — the fix is confirmed *rendered correctly*,
  not yet confirmed *actually more legible to a fresh player*.

## Root cause (AC-3 finding)

`src/presentation/sanctuary_ui/tab_strip.gd`'s badge `Label` (added Story 003, extended for the
Skills tab 2026-09-01, Core Rule 11) had no `custom_minimum_size`, no offset from the button's
corner, and default alignment — it shrank to fit only its own digit glyph, pinned flush to the
button's exact top-right corner. Against a 56×56px button this rendered as a barely-visible sliver,
not a badge.

**Fix**: explicit 20×20px rect, anchored to the button's top-right corner and inset 4px on both
axes (the standard notification-badge overlap convention), 14pt centered text. Landed *after*
`button.add_child(badge)` rather than before — the first attempt (`set_anchors_and_offsets_preset()`
called on an unparented Label) computed offsets against a zeroed/unparented rect and produced a
badge positioned partly *outside* the button's own bounds; moving the sizing/positioning calls to
after `add_child()` fixed that.

**Live-verified via Godot MCP** (not just code-read): loaded `SanctuaryUI.tscn` standalone, fired
`GEventBus.skill_tree_point_earned` to trigger the real badge-increment path, confirmed the
computed rect (`Rect2(294.8, 366.8, 22.4, 22.4)`) sits fully inside the button's rect
(`Rect2(0, 364, 320, 56)`), and screenshotted the result — a clearly visible orange "1" chip in the
Skills tab's corner, replacing the earlier unreadable sliver.

**Code**: `src/presentation/sanctuary_ui/tab_strip.gd` (`_build_buttons()`, badge construction block).

## What's still open

- AC-1 and AC-2 need a real scripted debrief session (mission-complete → Overview; mid-room →
  Loadout hand-off via Core Rule 10) — not yet attempted.
- AC-3's fix should get one more informal look from a real player next session, now that the badge
  actually renders as intended — confirming it reads as "there's a notification here" without being
  told what it is.
- Story 014 stays at **Ready**, not Complete — this session closes out one concrete, real bug found
  during it, but the story's own defined evidence bar (player's own words on all 3 scenarios) isn't
  met yet.
