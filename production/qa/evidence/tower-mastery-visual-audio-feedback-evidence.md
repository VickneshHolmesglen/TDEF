# Evidence: Tower Mastery Mid-Combat Visual/Audio Feedback

**Story**: `production/epics/epic-06-mission-combat-extensions/story-013-mid-combat-visual-audio-feedback.md`
**ADR**: ADR-0029 (Tower Mastery Proximity-Detection Strategy)
**Date**: 2026-07-19 (Sprint 7)

## Scope Decision (made before implementation)

Before writing any code, the codebase was checked for the infrastructure this
story's own Implementation Notes assume exists:

- **Mission HUD**: no implementation anywhere in `src/` — only a placeholder
  `Panel`, per `mission-hud.md`'s own tracked status ("PC-1/PC-2/PC-5 have no
  code yet"). The skill_unlocked HUD corner callout this story requires
  cannot be built against real HUD infrastructure that doesn't exist.
- **Constellation's "rune-deactivation visual vocabulary"**: this story's
  Implementation Notes direct reuse of it, but Constellation
  (`src/core/constellation/constellation.gd`) has zero visual/VFX code —
  it is pure EventBus-driven logic. There is nothing to reuse; the
  vocabulary exists only as design-document color/motion language.
- **Audio bible / sound assets**: none exist. The story's own scope note
  ("this story specifies category/direction only, per the GDD's own scope
  note") already anticipates this.

Given this, the user chose (via `AskUserQuestion`) to scope this pass to
**the in-world proximity arc only** — the one piece of this story genuinely
buildable without inventing Mission HUD infrastructure or fabricating audio
assets that don't exist. The HUD corner callout and real audio are recorded
here as explicitly blocked, not silently dropped.

## What Was Built

- `src/core/tower_mastery/tower_mastery_arc.gd` — `TowerMasteryArc extends Node2D`,
  a pure view component: procedural `_draw()`-based radial arc (Sanctum Amber
  `#C8801A`, never Herald Gold), clockwise sweep from 12 o'clock, fixed
  screen-space radius (does not scale with the node's own transform — see
  Known Limitation below), a placeholder archetype-glyph circle at center,
  and 4 states (`ACCRUING`, `PAUSED_OUT_OF_RANGE`, `PAUSED_DESTROYED`,
  `UNLOCKED_PULSE`) each differing via opacity and/or animated motion, never
  hue alone (art bible Section 4.5 accessibility requirement).
- `src/core/tower_mastery/tower_mastery_feedback.gd` — `TowerMasteryFeedback extends Node`,
  the scene-instanced manager: subscribes to `tower_placed`/
  `tower_component_equipped`/`tower_removed`/`tower_destroyed`/
  `mastery_progress_updated`/`skill_unlocked`, creates/positions/drives one
  arc per currently-active `build_signature`, and frees arcs once their
  destroyed-fade completes.
- 20 new unit tests (`tests/unit/tower-mastery/tower_mastery_arc_test.gd`,
  `tests/unit/tower-mastery/tower_mastery_feedback_test.gd`) covering state
  transitions, progress clamping, destroyed-fade completion, the unlock
  pulse's auto-clear, arc creation/repositioning/reuse, the
  destroyed-tower pause and automatic resumption via a different live tower
  sharing the same signature, and post-fade cleanup.

## Update — 2026-07-20: HUD Corner Callout Built (Mission HUD now exists)

Mission HUD (Epic 09) is now fully implemented and code-reviewed. Its
`ToastHost` mechanism (Story 011 — a bottom-left, non-blocking, transient
Label feed already used for Inventory events) already satisfies this story's
own placement requirement ("non-blocking... corner... clear of the Combat
Cluster... never top-center" — top-center is reserved for Mission HUD's
own path-update/hero-class banner). `MissionHud` now subscribes to
`GEventBus.skill_unlocked` and shows `"Skill Learned: %s" % skill_id` via
that same toast feed, guarded by the existing `_terminal` latch so it can't
fire after DEFEAT/MISSION_COMPLETE.

**RESOLVED 2026-08-13**: `SkillDefinitionResource` gained a `display_name`
field (all 8 real content files updated: `phys_cleave`→"Cleave", etc.).
`MissionHud._on_skill_unlocked()` now looks it up via
`GGameDataRegistry.get_skill_definition()`, falling back to the raw
`skill_id` for an unrecognized skill (never a crash). The callout now
reads e.g. `"Skill Learned: Cleave"`, matching the story's own "[Name]"
example text. `test_skill_unlocked_shows_a_toast` updated; a new
`test_skill_unlocked_falls_back_to_raw_id_for_unrecognized_skill` added.

**Also resolved 2026-08-13**: `skill_unlocked` wired into
`AudioCueDispatcher`'s generic dispatch mechanism (`_connect_all_events()`),
now possible since Epic 12/Audio System shipped Complete 2026-07-25 (after
this evidence file's original pass). No real sound content exists yet
(unchanged OQ-2 gap — same "mechanism real, content placeholder" convention
every other cue uses) — only the wiring/dispatch mechanism itself is real.
New test: `data-driven-cue-dispatch_test.gd::test_skill_unlocked_dispatches_its_mapped_cue`.

2 original tests (`tests/integration/mission-hud/combat-cluster-live-data_test.gd`:
`test_skill_unlocked_shows_a_toast`, `test_skill_unlocked_suppressed_after_terminal`)
plus the 2 new ones above, all passing. Live-MCP-verified against the real
running `the_gap.tscn`: `skill_unlocked` correctly produced a
`"Skill Learned: phys_cleave"` toast at the time of that original pass,
zero errors. Full project regression clean (296/296 across affected suites
in this latest pass).

## Update — 2026-08-13 (same day, enter-range/pause stingers)

Item 1 below ("flagged for whoever revisits this if a real explicit pause
signal is added later") is now resolved for the audio side: added
`GEventBus.tower_mastery_proximity_changed(build_signature: String,
in_range: bool)`, emitted from `TowerMastery._recompute_signatures_in_range()`
via an edge-detection diff against the previous in-range set — fires exactly
once per real transition, verified silent on a recompute that leaves
membership unchanged (`test_recompute_with_unchanged_membership_does_not_reemit`).
Wired to two distinct `AudioCueDispatcher` cues
(`tower_mastery_proximity_entered`/`_exited`), matching the GDD's two
distinct stingers. **The visual arc's own pause detection (`TowerMasteryFeedback`)
was deliberately left on its existing timeout heuristic, not migrated to
this new signal** — that would be a separate, riskier refactor of already-
shipped, already-tested visual code, outside this pass's narrower audio-
wiring scope. 5 new tests in `cell-boundary-proximity-tracking_test.gd`,
2 new tests in `data-driven-cue-dispatch_test.gd`. No real sound content
exists for either cue (unchanged OQ-2 gap) — only the mechanism is real.

## Known Limitations (documented, not fabricated as resolved)

1. ~~**Paused-out-of-range detection is a timeout heuristic, not an explicit
   signal.**~~ **Partially resolved 2026-08-13** — see Update section above.
   The visual arc (`TowerMasteryFeedback`) still uses its original timeout
   heuristic (a reasonable, already-tested approach, deliberately not
   touched); a real discrete signal (`tower_mastery_proximity_changed`) now
   exists and is used for the audio stingers, which need a precise trigger
   moment in a way the visual arc's own softer heuristic doesn't.
2. **Fixed-screen-space-diameter is not counter-scaled against a live
   camera zoom.** The arc renders at a fixed local-pixel radius; true
   zoom-invariance requires reading an active `Camera2D.zoom` and inversely
   scaling, which needs a real mission scene with a camera to wire against
   and verify. Every mission scene shipped in this project so far never
   zooms its camera, so this is correct today but not future-proofed against
   a zoom feature.
3. ~~**HUD corner callout**: not built. Blocked on Mission HUD, which has no
   code anywhere in this project yet.~~ **Built 2026-07-20** — see Update section above.
4. ~~**Real audio stingers**: not built.~~ **Mechanism built 2026-08-13** —
   `skill_unlocked`, `tower_mastery_proximity_entered`, and
   `tower_mastery_proximity_exited` are all wired into `AudioCueDispatcher`.
   Real sound content itself remains unbuilt (no audio bible/sound assets
   authored for these 3 cues specifically) — this story's own scope note
   already anticipated only specifying category/direction, not shipping
   final sound.
5. **Archetype glyph**: renders as a placeholder filled circle. No real
   per-archetype glyph asset catalogue exists; swap `_draw_glyph()`'s body
   when the Art Director supplies real assets.

## Manual QA Checks — What Could and Could Not Be Verified

This story's own QA Test Cases are all "Manual check" entries requiring a
human observe the arc rendering in a live mission scene (legibility at
camera distance, comparison against monster telegraph brightness, a
colorblind-simulation-filter pass). **No human tester was available in this
automated session** — mirroring Story 012's own honest treatment of its
playtest axis, this is reported as genuinely open rather than fabricated.

| Manual check | Status |
|---|---|
| In-combat proximity arc renders correctly, legible at default camera distance, never brighter/larger than a tower sprite or monster telegraph | ⚠️ **Not verified** — requires a live mission scene and a human observer |
| Accrual-paused states are visually distinguishable from each other and neither reads as a failure state | ⚠️ **Not verified** — same as above |
| `skill_unlocked` moment reads as a brief, non-blocking flourish | ⚠️ **Not verified** — same as above |
| Accessibility: all 3 states remain distinguishable under a colorblind simulation filter | ⚠️ **Not verified** — same as above; the *code* implements opacity/motion-based differentiation (see class doc comment), but whether it is actually legible enough is a human judgment call this session cannot make |

**What can be confirmed via code review/unit tests**: every state transition
implements the *rule* the GDD specifies (arc sweeps clockwise from 12
o'clock; paused-out-of-range only changes opacity; paused-destroyed
desaturates toward Fieldstone Grey while fading out over 0.5s; the unlock
pulse auto-clears after ~0.75s) — 20 unit tests verify these mechanics.
Whether the *result* looks and feels right is unverified. **Recommend a real
playtest/visual-review pass** (mirroring Story 012's own recommendation)
once Mission HUD exists and this arc can actually be seen in a running
mission scene.

## Summary

| Question | Status |
|---|---|
| Does the in-world proximity arc implement the GDD's state/motion rules correctly? | ✅ **Yes** — 20 unit tests passing, full project regression clean |
| Is the HUD corner callout built? | ✅ **Yes** (2026-07-20) — reuses Mission HUD's ToastHost mechanism; raw `skill_id` used as a placeholder label pending a real `display_name` field |
| Are real audio stingers built? | ❌ **No** — blocked on absent audio bible/assets, per this story's own scope note |
| Has a human verified the arc's actual legibility/feel/accessibility? | ⚠️ **Not yet** — no playtester available in this session |
