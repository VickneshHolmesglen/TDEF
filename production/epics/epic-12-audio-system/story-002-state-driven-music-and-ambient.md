# Story 002: State-Driven Music and Ambient — Crossfades, Anticipation, and the One Hard-Cut Exception

> **Epic**: Audio System
> **Status**: Complete (2026-07-25)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: 4h
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-07-25

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-audio-???` (no TR-ID registered — scoped from GDD Core Rule 2, States and Transitions, and AC Group 2)

**ADR Governing Implementation**: N/A — see Story 001's identical note.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Crossfades are typically implemented via two `AudioStreamPlayer`s (or a pooled pair) with a `Tween` on each's `volume_db`, not a single-player fade — confirm this pattern against the project's existing Tween conventions (`sanctuary_ui.gd`'s own tween usage) before inventing a new one.

**Control Manifest Rules (this layer)**:
- Required: none Audio-specific exist yet — this story establishes the crossfade convention future Audio stories should reuse

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, AC Group 2 + States and Transitions table:*

- [x] **AC-3**: GIVEN Music state is `Measured` (SCOUT), WHEN `wave_countdown_warning(seconds_remaining=10)` fires, THEN a crossfade to `Urgent` begins, timed to complete as the countdown reaches 0. Implemented as `duration = seconds_remaining` (explicit interpretation call, see Implementation Notes addendum below) — verified via `test_countdown_warning_during_measured_state_begins_a_crossfade_to_urgent`, `test_countdown_warning_with_short_remaining_time_still_schedules_matching_duration`, `test_countdown_warning_outside_measured_state_is_ignored`.
- [x] **AC-4**: GIVEN Music state is `Urgent` (WAVE_ACTIVE), WHEN the wave-clear signal fires (`mission_phase_changed` → INTERMISSION), THEN Music ducks/cuts to `Measured-urgent` within the Tuning Knobs' 0.2–0.5s window — not a multi-second crossfade. Verified via `test_wave_clear_to_intermission_is_a_hard_cut_within_tuning_bounds`, `test_wave_clear_hard_cut_is_not_a_multi_second_crossfade`.
- [x] **AC-5**: GIVEN any `mission_phase_changed` fires with `previous_phase == new_phase`, THEN no music retrigger or restart occurs. Verified via `test_identical_phase_transition_does_not_retrigger_in_measured_state`, `test_identical_phase_transition_does_not_retrigger_in_urgent_state`.
- [x] **AC-6**: GIVEN INTERMISSION's Ambient combat layer is fading out, WHEN a new wave begins (`Measured-urgent` → `Urgent`), THEN the base Ambient bed is never interrupted or restarted — only layers change. Verified via `test_ambient_base_bed_is_never_restarted_across_any_transition`, `test_next_wave_during_combat_layer_fade_out_reactivates_it_without_touching_base_bed`, `test_intermission_after_full_settle_still_leaves_base_bed_untouched`.

**Implementation Notes addendum (AC-3 interpretation call)**: this story's own QA Test Case for AC-3 states the crossfade's "scheduled completion time equals the countdown's own remaining-time-to-zero" — implemented literally as `duration = seconds_remaining` at the moment `wave_countdown_warning` fires, rather than the GDD prose's separate "3.5s Tuning Knob default" (which describes the expected real-world *tuned* value once real music-stem content and real wave-timing exist to tune against). Flagged honestly rather than silently guessed — no real audio content exists yet to validate either interpretation against, and the QA spec is the more authoritative, testable source per this project's own `/dev-story` convention ("the developer implements against these — do not invent new test cases").

---

## Implementation Notes

4 Music Energy levels (Core Rule 2, mapped 1:1 to `art-bible.md` Section 2): `Contemplative` (SANCTUARY/MISSION_COMPLETE/DEFEAT), `Measured` (SCOUT), `Urgent` (WAVE_ACTIVE), `Measured-urgent` (INTERMISSION). Music is one continuous stem per level, **crossfaded** on state entry, never hard-cut, with exactly one deliberate exception (AC-4).

**SCOUT→WAVE_ACTIVE anticipation**: begins on `wave_countdown_warning`'s 10-second signal, not on `mission_phase_changed` itself — a 3–4 second crossfade (Tuning Knobs default 3.5s) timed to resolve as the countdown's final beat lands. **Resync fallback** (Edge Cases, OQ-9 placeholder tolerance): if `mission_phase_changed`→WAVE_ACTIVE arrives before the crossfade finishes, complete it immediately rather than continuing to play out.

**WAVE_ACTIVE→INTERMISSION** is the one deliberate hard-cut exception: a fast duck/cut under 0.5s (Tuning Knobs default 0.4s) on wave-clear, not a slow crossfade. Ambient's combat layer fades out over ~2s afterward; the base ambient bed is never interrupted through any of this.

**Ambient model**: a continuous base environmental bed that never fully restarts across a state transition; state-specific **layers** fade in/out additively over that base — this is the mechanism AC-6 tests directly.

**Interrupted-crossfade edge case** (Edge Cases): if `mission_phase_changed` fires again before an in-flight crossfade finishes, cancel it and begin a new one immediately from the current live volume/position — crossfades never queue, matching Sanctuary UI's own "re-targets from current live value" interrupt discipline.

---

## Out of Scope

- Story 001: bus existence itself (this story assumes Music/Ambient buses already exist and route correctly)
- Story 003: one-shot SFX cue dispatch (Combat Impact family, etc.) — this story is Music/Ambient only
- Story 006: pause-time crossfade freeze/resume (Core Rule 7) — this story's crossfade mechanism must be *resumable*, but the pause-specific freeze behavior itself is Story 006's own scope

---

## QA Test Cases

- **AC-3**
  - Given: Music state is `Measured`
  - When: `wave_countdown_warning(10)` fires
  - Then: a crossfade to `Urgent` begins; its scheduled completion time equals the countdown's own remaining-time-to-zero
  - Edge cases: countdown fires with an unusually short remaining time (tests the resync fallback, Edge Cases)

- **AC-4**
  - Given: Music state is `Urgent`
  - When: `mission_phase_changed` fires WAVE_ACTIVE→INTERMISSION
  - Then: Music transitions to `Measured-urgent` within 0.2–0.5s, not via a multi-second crossfade
  - Edge cases: measure the actual transition duration against the Tuning Knobs bound, not just "eventually changes"

- **AC-5**
  - Given: any Music state active
  - When: `mission_phase_changed` fires with identical previous/new phase
  - Then: no restart/retrigger occurs — the currently-playing stem's position is unchanged
  - Edge cases: test at least 2 different states, not just one

- **AC-6**
  - Given: INTERMISSION's Ambient combat layer is actively fading out
  - When: `mission_phase_changed` fires INTERMISSION→WAVE_ACTIVE (next wave)
  - Then: the base Ambient bed's own playback position/instance is unchanged (never restarted) — only the layer set changes
  - Edge cases: trigger the next wave mid-fade (fade not yet complete) vs. after it's fully settled

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/audio/state-driven-music-and-ambient_test.gd`

**Status**: [x] Created and passing — 10/10 test cases, 0 errors, 0 failures, 0 orphans (`tests/integration/audio/state-driven-music-and-ambient_test.gd`, run 2026-07-25). Real scene instantiation (`add_child()`) exercising the real `GEventBus` signals — not mocked.

**Content note**: no real music/ambient stem assets exist yet (matches every other system's own "no content authored yet" gap) — `MusicAmbientController` implements the full state machine, timing, and crossfade/duck mechanism for real; it does not yet drive an `AudioStreamPlayer` with actual audio, since there is nothing to play. This mirrors the Diorama's placeholder-`ColorRect`-but-real-mechanism precedent from Epic 10.

**Refactored during Story 006**: the crossfade timing mechanism was originally `Tween`-based; refactored to a manually delta-driven countdown once Story 006 (Pause Behavior) found `Tween.custom_step()` ignores a tween's paused state, making a genuine freeze impossible on top of it. Backward-compatible — all 10 tests above still pass unchanged after the refactor.

---

## Dependencies

- Depends on: Story 001 (real Music/Ambient buses must exist to route through)

---

## Completion Notes
**Completed**: 2026-07-25
**Criteria**: 4/4 passing (AC-3, AC-4, AC-5, AC-6)
**Deviations**: AC-3's crossfade duration implemented literally as `= seconds_remaining` rather than the GDD's separate "3.5s Tuning Knob default" — documented interpretation call, see Implementation Notes addendum above
**Test Evidence**: Integration — `tests/integration/audio/state-driven-music-and-ambient_test.gd`, 10/10 passing, 0 orphans
**Code Review**: Complete (`/code-review` run 2026-07-25 across all Epic 12 files; no findings against this story's own code, though its class was later refactored during Story 006 to support a genuine pause-freeze)
- Unlocks: Story 006 (pause-time freeze/resume operates on this story's own crossfade mechanism)
