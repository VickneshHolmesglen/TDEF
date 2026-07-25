# Story 003: Data-Driven Cue Dispatch — AudioCueMap, 7 Families, One-Shot Triggering

> **Epic**: Audio System
> **Status**: Complete (2026-07-25)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: 4h
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-07-25

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-audio-???` (no TR-ID registered — scoped from GDD Core Rules 3–4 and AC Group 3)

**ADR Governing Implementation**: N/A — see Story 001's identical note. This story's `AudioCueMap`/`AudioCueEntry` Resource shape is itself a real architectural decision (data structure choice, dispatch mechanism) that may warrant a dedicated ADR before/during implementation — flag for `/architecture-decision` if the implementing agent judges the shape non-trivial enough to need one recorded.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: The GDD's own design review already resolved a real Godot-implementability risk here: `AudioCueMap` must be an `Array[AudioCueEntry]`, **not** a `Dictionary[StringName, AudioCueEntry]` — a Resource-valued Dictionary has no usable inspector editor in Godot 4.6. Build the runtime `Dictionary[StringName, AudioCueEntry]` lookup once at `_ready()` from the authored array, never re-derive it per-dispatch.

**Control Manifest Rules (this layer)**:
- Required: generic dispatch only — never a per-event `match` statement (Core Rule 4's own explicit requirement, the entire point of this story)

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, AC Group 3:*

- [x] **AC-7**: GIVEN `boss_died` fires, THEN a Discovery/Milestone Fanfare-family cue plays (per whatever `AudioCueMap` entry exists for that event), respecting the family's voice cap. Verified via `test_boss_died_dispatches_its_mapped_fanfare_cue` (voice-cap enforcement itself is Story 004's scope, not this story's).
- [x] **AC-8**: GIVEN `tower_attacked` fires, THEN a Combat Impact-family cue plays with world-space distance attenuation (Formula F2) applied. Verified against the GDD's own worked example (V_base=0.7, d=8, R=15 → 0.327) via `test_tower_attacked_spatial_cue_applies_formula_f2_worked_example`, plus edge cases `test_spatial_cue_at_zero_distance_plays_at_full_base_volume`, `test_spatial_cue_beyond_max_audible_radius_is_silent`, `test_negative_distance_is_clamped_to_zero_not_treated_as_an_error`.
- [x] **AC-9**: GIVEN `sanctuary_structure_built` fires, THEN a Progress Blip or Discovery/Milestone Fanfare-family cue plays (per the `AudioCueMap`'s own categorization), at full volume regardless of the structure's world position (not spatial per Formula F2's own exclusion). Verified via `test_sanctuary_structure_built_plays_full_volume_regardless_of_distance`, `test_non_spatial_cue_ignores_distance_argument_entirely`.
- [x] **AC-10**: GIVEN `AudioCueMap` entries exist for at least 2 arbitrarily-different subscribed events (e.g. `boss_died` and `component_crafted`), WHEN each fires in turn, THEN each plays its own correctly-mapped cue on its own configured bus — confirming generic dispatch works across genuinely different events using the same lookup path, without the test itself needing per-event branching. Verified via `test_two_different_events_each_dispatch_their_own_mapped_cue`.
- [x] **AC-10a**: GIVEN an event fires with no matching `AudioCueMap` entry, THEN no cue plays and no error or exception occurs. Verified via `test_event_with_no_map_entry_is_a_silent_no_op`, `test_dispatch_with_empty_cue_map_never_errors`.

**Implementation note (world-space distance)**: Formula F2 needs a real distance-from-camera-focus value; this project has no scrolling-camera/camera-focus concept built yet (fixed top-down viewport). `AudioCueDispatcher.dispatch_cue()` accepts `distance` directly so the formula itself is fully real and tested; the real `tower_attacked` signal wiring currently passes `distance = 0.0` pending that future camera-focus integration — flagged honestly as a separate, real gap (not this story's to close), not silently faked.

---

## Implementation Notes

**7 SFX cue families** (Core Rule 3): Discovery/Milestone Fanfare, Progress Blip, Denial/Rejection, Activation/Deactivation Confirm, UI Confirm/Cancel, Combat Impact, Ambient Environmental (the last is continuous, outside this story's one-shot dispatch entirely — Story 002 owns it).

`AudioCueEntry` fields (Core Rule 4): `event_name: StringName`, `stream: AudioStream`, `bus: StringName`, `polyphony_group: StringName` (which family, for Story 004's voice-limiting), `volume_db_offset: float`, `spatial: bool`.

**Full 16-event inbound subscription list** (Interactions with Other Systems table): `mission_phase_changed`, `wave_countdown_warning`, `hero_skill_activated`, `hero_class_unlocked`, `tower_placed`, `tower_attacked`, `pre_placement_perk_activated`, `boss_died`, `hero_damage_taken`, `constellation_activated`, `component_crafted`, `component_repaired`, `sanctuary_structure_built`, `hero_equipment_crafted`, `game_paused`, `game_unpaused`. This story subscribes to all 16 generically at `_ready()`; Stories 002/006 own the specific *behavior* for `mission_phase_changed`/`wave_countdown_warning` and `game_paused`/`game_unpaused` respectively, but the subscription plumbing itself lives here since it's the same generic mechanism.

**Formula F2** (World-Space Distance Attenuation, spatial cues only): `world_volume = base_volume × clamp(1 − distance / max_audible_radius, 0, 1)`. UI/HUD-family cues (families #2–#5) never use this formula — full authored volume, unmodified. Negative `distance` (Edge Cases, physically impossible under correct grid math) is clamped to `max(distance, 0)` before evaluating — never treated as a special error case by this system.

**Content-authoring is out of scope** (OQ-2): the `AudioCueMap` will ship with 0 or very few real entries — this story builds the *mechanism*, not the actual sorted-into-families content. AC-7/8/9/10/10a should all be testable against a handful of test-authored `AudioCueEntry` fixtures, not real shipped audio assets.

---

## Out of Scope

- Story 001: bus existence (this story routes to buses Story 001 creates)
- Story 004: voice-cap enforcement/oldest-voice-stealing (this story fires cues; Story 004 owns how many can play at once)
- OQ-2's actual content-authoring pass (populating `AudioCueMap` with real SFX/music for all ~10 other GDDs' scattered audio notes) — separate Full Vision-tier work

---

## QA Test Cases

- **AC-7**
  - Given: an `AudioCueMap` test fixture with a `boss_died` → Discovery/Milestone Fanfare entry
  - When: `boss_died` fires
  - Then: that cue plays; the Discovery Fanfare family's voice cap (Story 004) is respected
  - Edge cases: fire `boss_died` twice within the family's cap window (Discovery Fanfare cap = 1) — second call queues/steals per Story 004, not this story's own concern beyond not double-playing incorrectly

- **AC-8**
  - Given: an `AudioCueMap` entry for `tower_attacked` marked `spatial = true`
  - When: `tower_attacked` fires with a known grid-cell distance from the camera focus
  - Then: the cue's effective volume matches Formula F2's worked example for that distance
  - Edge cases: distance = 0 (full volume), distance ≥ max_audible_radius (silence), negative distance (clamped to 0)

- **AC-9**
  - Given: an `AudioCueMap` entry for `sanctuary_structure_built`
  - When: it fires with any world position
  - Then: the cue plays at full authored volume regardless of position — Formula F2 is never applied
  - Edge cases: confirm this holds even when the entry is marked as belonging to a family that, for OTHER events, might use F2 — the exclusion is per-cue (`spatial` field), not per-family

- **AC-10**
  - Given: `AudioCueMap` entries for 2 arbitrarily different events (e.g. `boss_died`, `component_crafted`)
  - When: each fires in turn
  - Then: each plays its own distinctly-configured cue on its own configured bus, via the same dispatch code path
  - Edge cases: none additional — this AC is about dispatch genericity, not per-event correctness

- **AC-10a**
  - Given: an event fires with no `AudioCueMap` entry for it
  - When: dispatch attempts lookup
  - Then: no cue plays, no error/exception raised — silent no-op
  - Edge cases: test with an event that IS in the 16-event subscription list but has no map entry (the realistic case, since most events have no content yet per OQ-2)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/audio/data-driven-cue-dispatch_test.gd`

**Status**: [x] Created and passing — 13/13 test cases (10 original + 3 added 2026-07-25 for the Story 004 wiring below), 0 errors, 0 failures, 0 orphans (`tests/integration/audio/data-driven-cue-dispatch_test.gd`, run 2026-07-25). Real scene instantiation exercising the real `GEventBus` — not mocked.

**Follow-up (2026-07-25): `VoiceLimiter` wired into the live dispatch path.** `dispatch_cue()` now calls `voice_limiter.trigger_voice(entry.polyphony_group)` on every real dispatch (skipped for entries with an empty `polyphony_group`) — closing the deferral Story 004's own file documented ("Story 003 owns triggering a new voice; Story 004 only owns what happens once a family is at/beyond capacity... a natural follow-up for whichever future story needs the composed behavior live"). New accessor `get_last_dispatch_voice_id()`. 3 new tests verify: a dispatched cue registers a voice against its family; dispatching beyond Discovery Fanfare's real cap (1) steals through a real `GEventBus`-driven dispatch, not just a direct `VoiceLimiter` call; a cue with no `polyphony_group` never registers a voice. `VoiceLimiter.compute_ducked_volume()` (Formula F1) remains unwired — no dispatch-time concept of concurrent-voice-count exists yet to feed it.

---

## Dependencies

- Depends on: Story 001 (buses must exist as real dispatch targets)
- Unlocks: Story 004 (voice-limiting operates on cues this story's dispatch mechanism fires)

---

## Completion Notes
**Completed**: 2026-07-25
**Criteria**: 5/5 passing (AC-7, AC-8, AC-9, AC-10, AC-10a)
**Deviations**: `tower_attacked`'s real signal wiring passes `distance = 0.0` pending a camera-focus concept this project hasn't built yet (Formula F2's own math is fully real/tested via direct `dispatch_cue()` calls) — documented in Implementation note above
**Test Evidence**: Integration — `tests/integration/audio/data-driven-cue-dispatch_test.gd`, 13/13 passing, 0 orphans
**Code Review**: Complete (`/code-review` run 2026-07-25) — found and fixed a WARNING: the 16 lambda signal connections had no `_exit_tree()` disconnect capability; fixed with stored Signal/Callable pairs + a double-connect guard. Specialist independently verified all 16 lambda arities against the real `GEventBus` signal declarations — no mismatches.
**Follow-up (2026-07-25)**: `VoiceLimiter` wired into the live dispatch path, closing Story 004's own documented deferral — see updated Test Evidence above.
