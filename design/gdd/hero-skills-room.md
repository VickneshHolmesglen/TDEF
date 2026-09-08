---
status: reverse-documented
source: src/gameplay/ui/hero_skills_room/
date: 2026-09-08
verified-by: Vicknesh
---

# Hero Skills Room

> **Note**: This document was reverse-engineered from the existing implementation
> (`src/gameplay/ui/hero_skills_room/hero_skills_room.gd`, `HeroSkillsRoom.tscn`,
> `tests/integration/hero-skills-room/hero_skills_room_test.gd`). It captures
> current, already-shipped behavior. The room's mount point, tab-strip position,
> and Connection Badge wiring are also independently specified in
> `sanctuary-ui.md` Core Rule 11 — that document remains the canonical source
> for how `ROOM_HERO_SKILLS` fits into the shell as a whole (tab strip, focus
> trackers, room lifecycle). This document exists at the more granular level:
> the room's own internal composition and the sub-screen-toggle mechanism it
> introduces, which Core Rule 11 references but does not itself fully specify.

> **Status**: Reverse-Documented — not yet run through `/design-review`.
> **Author**: Vicknesh + Claude Sonnet (reverse-documented from code)
> **Last Updated**: 2026-09-08
> **Implements Pillar**: Everything Connects (a single room hosting two
> previously-separately-designed Hero systems)

## Overview

Hero Skills Room is the composite `ROOM_HERO_SKILLS` room that `sanctuary-ui.md`
Core Rule 11 names as the tab strip's Skills entry. It exists to solve a single
structural constraint: `RoomHost.mount_room()` only ever mounts one `PackedScene`
per `ROOM_*` state (`room_host.gd`'s own contract), but two independently-designed
systems — Hero Skill Build (`hero-skill-build.md`, the Loadout screen) and Hero
Skill Tree (`hero-skill-tree.md`, the Skill Tree screen) — both needed to live
under the one Skills tab. Hero Skills Room is a thin `Control` wrapper that
instantiates both systems' existing screens as children, keeps both alive for
the room's whole lifetime, and shows exactly one at a time via a `.visible`
toggle. It owns no game logic of its own — no EventBus subscriptions, no
skill/point state — it is pure navigation: which of the two already-built
screens is currently on top.

## Player Fantasy

> Two different questions about your Hero — "what do I have equipped right
> now" and "what am I working toward next" — live one tab apart, not two.

Hero Skill Build answers "what is my Hero using this run" (the Loadout).
Hero Skill Tree answers "what am I unlocking permanently" (the Tree). They are
mechanically unrelated systems with unrelated data models, but they are the
*same conversation* from the player's chair — you rarely think about one
without immediately wanting to check the other ("I just unlocked a new skill —
let me go equip it"). Hero Skills Room's whole job is making that conversation
feel like one continuous action (a single bumper-press) rather than two
separate trips through the tab strip. Loadout opens first on every visit,
because equipping is the more frequent, more habitual half of that
conversation (Core Rule 11); the Tree is one press away whenever the player's
intent shifts to "what's next" instead of "what's equipped."

## Detailed Design

### Core Rules

**Composition**

1. Hero Skills Room's scene tree (`HeroSkillsRoom.tscn`) is: a root `Control`,
   an `InputModeTracker` child (per ADR-0011's "one instance per interactive
   UI screen" scope, extended to this room by `sanctuary-ui.md` Core Rule 11),
   and a `MainLayout` `VBoxContainer` holding a `SubTabStrip`
   (`HBoxContainer` with `LoadoutTabButton`/`SkillTreeTabButton`, both
   `toggle_mode` buttons) and a `SubScreenHost` (`Control`) that parents both
   sub-screen instances.
2. `_ready()` instantiates `HeroSkillBuildScreen` and `HeroSkillTreeScreen`
   from their own `PackedScene`s and adds both as children of
   `SubScreenHost` — eagerly, once, for the room's whole lifetime. Neither is
   ever destroyed or re-instantiated on a sub-screen switch; only `.visible`
   changes. This is a deliberate departure from `RoomHost`'s own
   destroy-and-recreate room lifecycle (Core Rule 6) — sub-screen switching is
   lateral navigation *within* one already-mounted room, not a new room mount.
3. Exactly one sub-screen is visible at any time, tracked by a single
   `_showing_loadout: bool` (`true` = Loadout, `false` = Skill Tree). Loadout
   is the default on room entry (Core Rule 11 — "the more frequently-visited
   of the two").
4. `_refresh_sub_screen_visibility()` is the single source of truth for
   presentation: it sets both screens' `.visible` and both tab buttons'
   `button_pressed` from `_showing_loadout` in one place, called after every
   state change (click or bumper) so the two can never drift out of sync.

**Switching mechanisms — two independent, always-both-live paths**

5. **Click/focus**: `LoadoutTabButton.pressed`/`SkillTreeTabButton.pressed`
   call `_show_loadout()`/`_show_skill_tree()` directly. This matches every
   other room's own real sub-nav precedent (`inventory_screen.gd`'s
   Recipes/Assemble/Repair, `defense_building_screen.gd`'s Tech/Build) — none
   of which are gamepad-bumper-driven despite `tab_strip.gd`'s own class doc
   comment implying they already were.
6. **Gamepad bumper**: `_unhandled_input()` listens for
   `room_bumper_left`/`room_bumper_right` (new `InputMap` actions this room's
   authoring introduced — `project.godot`: `JOY_BUTTON_LEFT_SHOULDER`/
   `JOY_BUTTON_RIGHT_SHOULDER`, indices 9/10, with a `Q`/`E` keyboard
   fallback). Either action calls `_toggle_sub_screen()`, which flips
   `_showing_loadout` to its opposite value — **direction-agnostic**: with
   only two sub-screens, "left" and "right" both mean "the other one" (see
   Edge Cases). The input is consumed (`set_input_as_handled()`) so it cannot
   also reach `TabStrip`'s own `LT`/`RT` room-cycling handler in the same
   frame — the two are deliberately different physical inputs for exactly
   this reason (Core Rule 2: "triggers = switch tab-strip entries, bumpers =
   switch tabs within the open room").
7. `room_bumper_left`/`room_bumper_right` are named generically, not
   `hero_skills_`-scoped, so a future room can reuse the same actions rather
   than inventing its own pair — this room is simply the first to add a real
   bumper handler; `tab_strip.gd`'s own comment had claimed this idiom was
   already project-wide before this room existed, which was not true (see
   Open Questions).

**RoomHost contract**

8. `disconnect_own_subscriptions()` — required by every `RoomHost`-mounted
   room (ADR-0032 §1) — delegates to both sub-screens' own
   `disconnect_own_subscriptions()` if they implement it. Hero Skills Room
   itself makes no EventBus subscriptions of its own to clean up (only
   `Button.pressed` connections, which self-disconnect on `queue_free()`).

### Non-Goals

- Hero Skills Room does not read or mutate any Hero Skill Build or Hero Skill
  Tree state. It has no knowledge of skills, points, or unlock status — that
  entirely belongs to the two hosted screens and their own Autoloads
  (`GHeroSkillBuild`, and Hero Skill Tree's own data owner).
- It does not decide *when* it is mounted or *which tab-strip entry* it is —
  that is `sanctuary_ui.gd`'s `ROOM_SCENES` dictionary and `tab_strip.gd`'s
  own entry table, both owned by `sanctuary-ui.md` Core Rule 11, not by this
  document.

## Formulas

None. Hero Skills Room is a pure navigation/composition shell — its only
state is a single boolean, and both of its transition paths (click, bumper)
are unconditional toggles, not derived calculations. This matches
`sanctuary-ui.md`'s own precedent for the same reason (Formulas section,
that document).

## Edge Cases

- **Bumper direction is currently meaningless.** `room_bumper_left` and
  `room_bumper_right` both call the same `_toggle_sub_screen()` and produce
  identical results (confirmed by
  `hero_skills_room_test.gd::test_bumper_left_toggles_to_skill_tree` and
  `::test_bumper_right_toggles_to_skill_tree`, which assert the same outcome
  from opposite inputs). This is correct-by-construction today because there
  are exactly two sub-screens — a third sub-screen would require the toggle
  to become a real left/right-aware cycle instead of an unconditional flip
  (flagged, not yet a bug: see Open Questions).
- **Rapid button-mashing**: each press is a synchronous, immediate
  `.visible` flip with no tween/transition and no debounce — there is no
  in-flight state to race against, unlike `RoomHost`'s own room-mount
  tween (`sanctuary-ui.md` Edge Cases). Mashing either tab button or either
  bumper repeatedly just keeps flipping visibility deterministically, one
  toggle per input.
- **Room re-entry**: per Core Rule 11's Dependencies-table row, sub-screen
  selection is not persisted — every fresh `RoomHost.mount_room()` of
  `ROOM_HERO_SKILLS` re-instantiates `HeroSkillsRoom` from its
  `PackedScene`, which always re-defaults to Loadout (`_showing_loadout = true`
  in `_ready()`), regardless of which sub-screen was showing on the previous
  visit.
- **A sub-screen's own internal state is untouched by the toggle.** Because
  both sub-screens are instantiated once and merely hidden (not destroyed),
  switching away from and back to a sub-screen within the same room visit
  preserves whatever in-progress UI state that sub-screen had (e.g. an
  expanded Choice-node candidate panel on the Skill Tree screen) — this is
  a direct consequence of Rule 2's "kept alive, not recreated" choice, not
  separately implemented.

## Dependencies

| System | Relationship | Notes |
|---|---|---|
| Sanctuary UI | Depended on by | Mounts this room as `ROOM_HERO_SKILLS` (`sanctuary-ui.md` Core Rule 11) — tab-strip position, hotkey, and Connection Badge are that document's responsibility, not this one's |
| Hero Skill Build | Hosts | Instantiates and shows/hides `HeroSkillBuildScreen` (`hero-skill-build.md`) unmodified, as the default sub-screen |
| Hero Skill Tree | Hosts | Instantiates and shows/hides `HeroSkillTreeScreen` (`hero-skill-tree.md`) unmodified, as the bumper-toggled second sub-screen |
| InputModeTracker | Uses | One instance per ADR-0011's scope, for this room's own focus-traversal graph (the two tab buttons plus whichever sub-screen is visible) |
| RoomHost | Depended on by | Mounts/unmounts this scene per its own contract (ADR-0032 §1); this room implements the required `disconnect_own_subscriptions()` |

## Tuning Knobs

| Knob | Value | Notes |
|---|---|---|
| Default sub-screen | Loadout (`_showing_loadout = true`) | Not currently exposed as a config value — hardcoded per Core Rule 11's explicit design choice, not a placeholder |
| `room_bumper_left` binding | `Q` (keyboard), `JOY_BUTTON_LEFT_SHOULDER` (gamepad) | `project.godot` InputMap |
| `room_bumper_right` binding | `E` (keyboard), `JOY_BUTTON_RIGHT_SHOULDER` (gamepad) | `project.godot` InputMap |

## Acceptance Criteria

- [x] **GIVEN** Hero Skills Room is freshly mounted, **THEN** the Loadout
  sub-screen is visible and its tab button shows pressed; the Skill Tree
  sub-screen is hidden. (`test_loadout_is_the_default_sub_screen_on_room_entry`)
- [x] **GIVEN** the Skill Tree tab button is pressed, **THEN** the room
  switches to showing the Skill Tree sub-screen only.
  (`test_pressing_the_skill_tree_tab_button_switches_sub_screens`)
- [x] **GIVEN** the Skill Tree sub-screen is showing, **WHEN** the Loadout
  tab button is pressed, **THEN** the room switches back to Loadout.
  (`test_pressing_the_loadout_tab_button_switches_back`)
- [x] **GIVEN** Loadout is showing, **WHEN** `room_bumper_left` fires,
  **THEN** the room switches to Skill Tree.
  (`test_bumper_left_toggles_to_skill_tree`)
- [x] **GIVEN** Loadout is showing, **WHEN** `room_bumper_right` fires,
  **THEN** the room switches to Skill Tree (same outcome as bumper-left —
  see Edge Cases). (`test_bumper_right_toggles_to_skill_tree`)
- [x] **GIVEN** either bumper is pressed twice in a row, **THEN** the room
  ends back on Loadout (a full round-trip toggle).
  (`test_bumper_toggles_back_and_forth`)
- [x] **GIVEN** `disconnect_own_subscriptions()` is called at any point,
  **THEN** it completes without error and delegates to both sub-screens.
  (`test_disconnect_own_subscriptions_is_safe_to_call`)
- [ ] No icon asset exists yet for the Skills tab button
  (`sanctuary-ui.md` Core Rule 11's own flagged gap) — not this document's
  scope to resolve, listed here only for cross-reference.

## Open Questions

| ID | Question | Owner | Resolve By |
|---|---|---|---|
| OQ-1 | If a third sub-screen is ever added to this room, `_toggle_sub_screen()`'s unconditional flip (Rule 6, Edge Cases) needs to become a real left/right-aware cycle — not yet a problem with two, but a real design change on that day. | UX Designer | Whenever a third Hero-adjacent sub-screen is proposed |
| OQ-2 | `tab_strip.gd`'s pre-existing class doc comment claimed every room already had bumper-driven internal tab switching before this room's authoring found that untrue for all 4 prior rooms (Inventory, Defense Building, Equipment Forge use click-only sub-nav). Should the other rooms be retrofitted to also support `room_bumper_left`/`right` now that the actions exist project-wide, for input-model consistency? | UX Designer | Not blocking — flagged for a future consistency pass |
