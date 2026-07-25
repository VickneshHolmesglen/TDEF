# Story 006: Pause Behavior — Duck, Don't Stop

> **Epic**: Audio System
> **Status**: Complete (2026-07-25)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: 3h
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-07-25

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-audio-???` (no TR-ID registered — scoped from GDD Core Rule 7 and AC Group 6)

**ADR Governing Implementation**: ADR-0014 (Pause System) — governs `SceneTree.paused` as the single source of truth for "the game is paused." This story's own subscription to `game_paused`/`game_unpaused` is informational-only per that ADR ("no system may gate its own `_process`/`_physics_process`/Timer logic on them; `SceneTree.paused` already does that natively") — Audio's ducking response is exactly the kind of informational reaction that ADR anticipates, not a violation of it.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Per ADR-0014, this system's ducking response must NOT gate its own processing on `SceneTree.paused` directly — it reacts to the `game_paused`/`game_unpaused` EventBus signals instead, consistent with every other pause-reactive system in this project.

**Control Manifest Rules (this layer)**:
- Required: `game_paused`/`game_unpaused` are informational-only signals (ADR-0014) — this story's subscriber must not attempt to also gate its own `_process` on `SceneTree.paused` redundantly

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, AC Group 6:*

- [x] **AC-15a** *(split from the original compound AC-15 per the GDD's own `/design-review`)*: GIVEN `game_paused` fires mid-crossfade, THEN the crossfade's progress freezes exactly where it is — no restart, no cancellation; WHEN `game_unpaused` fires, THEN the crossfade resumes from exactly the frozen point, not from the beginning or a default. Verified via `test_pause_mid_crossfade_freezes_progress_exactly_in_place`, `test_unpause_resumes_the_crossfade_from_the_frozen_point`, `test_double_pause_cycle_mid_transition_still_resumes_correctly`.
- [x] **AC-15b** *(split from AC-15)*: GIVEN `game_paused` fires, THEN Music/Ambient buses duck to the configured pause level (~40%, Tuning Knobs) and the SFX bus's world-combat content mutes entirely; WHEN `game_unpaused` fires, THEN all affected bus levels restore to their exact pre-pause values. Verified via `test_pause_ducks_music_and_ambient_to_40_percent_of_pre_pause_level`, `test_pause_mutes_sfx_bus_entirely_and_leaves_ui_bus_untouched`, `test_unpause_restores_exact_pre_pause_values_not_just_any_nonzero_value`, `test_pause_while_music_already_at_a_non_default_player_set_volume_ducks_relative_to_it`, `test_repeated_pause_without_intervening_unpause_does_not_re_duck_an_already_ducked_value`.

**Implementation note — Story 002 refactor required**: `MusicAmbientController`'s original `Tween`-based crossfade timing could not support a genuine freeze, since `Tween.custom_step()` (used by Story 002's own `force_finish_transition()` test seam) explicitly ignores a tween's paused state per Godot's own documentation. Refactored to a manually-tracked delta countdown (`advance_time()`, driven by real `_process(delta)` in production, called directly with explicit deltas in tests) that a `_paused` flag can genuinely halt. Backward-compatible — all of Story 002's own original 10 tests still pass unchanged after the refactor.

**Implementation note — test isolation gap found and fixed**: the real `GAudioSystem` Autoload (always alive in any headless test run) has its own `PauseDuckController` also subscribed to `game_paused`/`game_unpaused`, independently ducking the same shared `AudioServer` Ambient bus this story's own tests assert against directly (Ambient has no per-instance percent abstraction the way Music/SFX/UI do, so it's the one bus where this cross-instance interference actually corrupts a raw readback). Fixed by temporarily disconnecting the real Autoload's subscriptions for this test file's duration only (restored in `after_test()`) — matches this project's own "reset shared Autoload/singleton state between tests" discipline, not a new pattern.

**Real bug found in `/code-review` (2026-07-25) and fixed**: `_on_game_paused()` originally ducked Music/SFX by calling `AudioSystem.set_bus_volume_percent()`, which overwrites `_bus_volumes` — the field `audio_system.gd` itself documents as the sole authoritative source of truth for the player's *persisted* preference. If `save_settings_to_disk()` ran while paused (e.g. quitting to desktop from the pause menu), the ducked value would be permanently written to `user://audio_settings.cfg`, silently replacing the player's real setting. Fixed by adding `AudioSystem.set_bus_volume_db_direct()`/`get_bus_volume_db_direct()` (touch the real `AudioServer` only, never `_bus_volumes`) and routing Music/SFX ducking through those instead — matching the approach Ambient already correctly used from this story's first draft. Added a dedicated regression test, `test_persisted_preference_is_never_touched_while_paused_even_across_a_save`, which pauses, saves, and reloads via a fresh `AudioSystem` instance to prove the real (not ducked) value survives. All of AC-15b's existing tests updated to assert against the real `AudioServer` state (`get_bus_volume_db_direct()`) for the audible check, while separately confirming `get_bus_volume_percent()` (the persisted preference) never changes during a pause cycle.

---

## Implementation Notes

This document defines the subscriber behavior that should close an existing `event-bus.md` placeholder (`game_paused`/`game_unpaused`'s Key Subscribers currently list "None yet — future Audio ducking"). **The actual edit to `event-bus.md` itself is a separate, inherited gap** (OQ-7) — not this story's own defect to silently fix by editing a sibling document unprompted; flag it, optionally propose the edit for approval, but do not treat this story as blocked by it.

On `game_paused`: Music and Ambient buses attenuate to ~40% (Tuning Knobs, range 30–50%) — **never full silence**, the game should still feel "there." SFX and UI buses mute the world-combat family entirely (no world sound should continue accruing while gameplay is frozen). Both restore to pre-pause levels on `game_unpaused`.

**Crossfade freeze is the harder half of this story** (AC-15a): per `design/accessibility-requirements.md`'s stronger-than-Standard commitment ("the whole game must be pausable at any frame, with no penalty"), pausing mid-crossfade must never restart or cancel Story 002's in-flight crossfade — freeze it exactly where it is, resume exactly where it left off. This likely means Story 002's crossfade tween itself needs a `pause()`-equivalent hook (or this story reads/writes its progress directly) — coordinate with Story 002's actual implementation rather than assuming a specific Tween API shape here.

---

## Out of Scope

- Story 002: the crossfade mechanism itself (this story only adds pause-time freeze/resume on top of it)
- `event-bus.md`'s own edit to formally close its Key Subscribers placeholder (OQ-7) — a separate, optional follow-up, not blocking

---

## QA Test Cases

- **AC-15a**
  - Given: an in-flight Music crossfade at a known partial progress (e.g. 40% through)
  - When: `game_paused` fires
  - Then: crossfade progress is frozen at exactly that point (not 0%, not 100%, not cancelled)
  - When: `game_unpaused` fires
  - Then: the crossfade resumes and continues from the frozen 40% point, reaching completion at the same total elapsed active-time it would have taken without the pause
  - Edge cases: pause fires again before the crossfade fully resumes/completes (double-pause-cycle mid-transition)

- **AC-15b**
  - Given: normal (unpaused) bus levels
  - When: `game_paused` fires
  - Then: Music/Ambient read ~40% of their pre-pause level; SFX bus's world-combat content is muted (silent), UI-family content is unaffected
  - When: `game_unpaused` fires
  - Then: all affected levels restore to their exact pre-pause values (not merely "back to some non-zero value")
  - Edge cases: pause while a bus is already at a non-default player-set volume (e.g. Music at 40% before pause) — the ~40% pause-duck must apply relative to that value, not silently reset it to the accessibility default first

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/audio/pause-behavior_test.gd`

**Status**: [x] Created and passing — 9/9 test cases (8 original + 1 code-review regression test), 0 errors, 0 failures, 0 orphans (`tests/integration/audio/pause-behavior_test.gd`, run 2026-07-25). Real scene instantiation exercising the real `GEventBus`/`AudioServer` — not mocked.

---

## Dependencies

- Depends on: Story 001 (real buses to duck), Story 002 (a real crossfade mechanism to freeze/resume)
- Unlocks: None (final story in this epic)

---

## Completion Notes
**Completed**: 2026-07-25
**Criteria**: 2/2 passing (AC-15a, AC-15b)
**Deviations**: Required refactoring Story 002's `MusicAmbientController` off `Tween` (documented above); required a test-isolation fix for the always-alive `GAudioSystem` Autoload double-ducking shared `AudioServer` state
**Test Evidence**: Integration — `tests/integration/audio/pause-behavior_test.gd`, 9/9 passing, 0 orphans
**Code Review**: Complete (`/code-review` run 2026-07-25) — found and fixed a real BLOCKING bug (ducking corrupted the persisted volume preference, see Implementation note above); found and fixed a WARNING in `VoiceLimiter`'s typing (unrelated file, fixed in the same pass). Epic 12 (Audio System) is now formally Complete — all 6 stories implemented, tested, and reviewed.
