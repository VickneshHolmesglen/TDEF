# Story 004: Ducking and Voice Limiting — Per-Family Caps, Oldest-Voice Stealing, Sidechain Ducking

> **Epic**: Audio System
> **Status**: Complete (2026-07-25)
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-07-31

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-audio-???` (no TR-ID registered — scoped from GDD Core Rule 5, Formula F1, and AC Group 4)

**ADR Governing Implementation**: N/A — see Story 001's identical note.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: None beyond standard signal/state-tracking discipline.

**Control Manifest Rules (this layer)**:
- Guardrail: voice-cap bookkeeping must be O(1) or O(family-cap) per dispatch, never a full-scan of all active audio players — this runs on the same hot path as Combat Impact cues during dense WAVE_ACTIVE moments

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, AC Group 4:*

- [x] **AC-11**: GIVEN a family's voice cap (e.g. Combat Impact, 12) is already at capacity, WHEN one more trigger fires, THEN the oldest-started voice on that family stops and the new trigger plays — the newest trigger is never silently dropped. Verified via `test_combat_impact_family_steals_oldest_voice_beyond_cap`, `test_discovery_fanfare_cap_of_1_replaces_rather_than_ignores_new_trigger`, `test_trigger_below_cap_does_not_steal_anything`.
- [x] **AC-12**: GIVEN 6 simultaneous SFX-bus voices are active, WHEN Formula F1 is evaluated with the Tuning Knobs' default `k=0.05`/`D_floor=0.3`, THEN each voice's ducked volume matches the formula's worked example (`0.60` for `V_base=0.8`). Verified via `test_formula_f1_matches_the_gdds_worked_example`, `test_formula_f1_with_a_single_voice_applies_no_ducking`, `test_formula_f1_never_goes_below_the_duck_floor`.

**Note**: `VoiceLimiter` is a standalone Logic class (`src/core/audio/voice_limiter.gd`). Originally not wired into `AudioCueDispatcher`'s live dispatch path (matching this story's own Out of Scope boundary at the time — Story 003 owns triggering a new voice; this story only owns what happens once a family is at/beyond capacity). **Wired in 2026-07-25 (follow-up session)**: `AudioCueDispatcher.dispatch_cue()` now calls `voice_limiter.trigger_voice(entry.polyphony_group)` on every real dispatch — see Story 003's own file for the wiring detail and its 3 new regression tests. **`compute_ducked_volume()` (Formula F1) wired in 2026-07-31**: added `VoiceLimiter.get_total_active_voice_count()` (bus-wide, summed across every family) and `dispatch_cue()` now applies it to any cue with a `polyphony_group`, evaluated after that dispatch's own voice is registered per Formula F1's "including this one" definition. 4 new tests prove the GDD's worked example (`V_base=0.8, N=6 → 0.60`), the duck floor clamp, N=1 no-op, and that non-polyphony cues are never ducked — see `tests/integration/audio/data-driven-cue-dispatch_test.gd`.

**Sidechain ducking gap found in code review (2026-07-25) — closed 2026-07-31**: the sidechain ducking constants (`SFX_TO_AMBIENT_DUCK_DB = -6.0`, `UI_TO_MUSIC_AND_SFX_DUCK_DB = -4.0`, per Core Rule 5's Implementation Notes) existed but were never applied to any real `AudioServer` bus anywhere in this codebase — distinct from the VoiceLimiter-dispatch-wiring gap above (that gap was about *connection*; this one was about the sidechain *mechanism itself* not being built at all). Blocked at the time because the GDD specified only the dB magnitude for each duck, not the attack/release timing a real implementation needs. **Unblocked and implemented 2026-07-31**: `design/quick-specs/sidechain-ducking-timing-2026-07-31.md` (a `/quick-design` Addition spec, approved and applied to `audio-system.md` as new Formula F3 — attack/hold/release envelope, 6 new Tuning Knobs, 3 new Edge Cases) specified the missing timing, then `VoiceLimiter` gained a delta-driven `ATTACKING → HELD → RELEASING` state machine per relationship (retriggering resets the hold countdown rather than re-attacking, preventing audible "pumping"; a trigger mid-release re-enters HELD from the current partial value rather than snapping back to full duck). `AudioCueDispatcher.dispatch_cue()` now calls `trigger_sidechain()` based on `entry.bus`, and a new `_process(delta)` ticks both envelopes once per frame — pause-freeze required no bespoke handling since `_process()` simply stops firing while `get_tree().paused` (this project's existing `PROCESS_MODE_INHERIT` convention). 15 new tests: 11 deterministic unit tests in `tests/unit/audio/sidechain-ducking-envelope_test.gd`, 4 integration tests proving real-dispatch wiring. The 2 original "sidechain" tests in `tests/unit/audio/ducking-and-voice-limiting_test.gd` (relabeled 2026-07-25 to note they only checked tuning constants) now have their comment block updated to point at the real mechanism's test coverage.

---

## Implementation Notes

**Per-family voice caps** (Tuning Knobs, all 6 non-Ambient families now specified): Discovery Fanfare = 1 (fixed, never exceed — reuses Tarot's "never stack two reveal cards" precedent), Progress Blip = 4, Denial/Rejection = 3, Activation/Deactivation Confirm = 4, UI Confirm/Cancel = 6, Combat Impact = 12. **4 of these 6 are explicitly flagged placeholders** (OQ-8) — implement the mechanism generically against whatever cap value is configured per family, do not hardcode assumptions that only Combat Impact/Discovery Fanfare have caps.

**Oldest-voice stealing**: beyond a family's cap, the oldest-started voice on that family is stopped and replaced — never silently drop the newest trigger (Edge Cases' own explicit reasoning: the player's most recent action must produce feedback).

**Formula F1** (Concurrent-Cue Ducking, per SFX-bus voice): `ducked_volume = base_volume × max(duck_floor, 1 − duck_coefficient × (active_voice_count − 1))`, clamped to `[duck_floor, base_volume]`. Tuning Knobs defaults: `k=0.05` (range 0.02–0.10), `D_floor=0.3` (range 0.2–0.4).

**Scope clarification** (Core Rule 5): per-family caps and Formula F1's bus-wide ducking are independent, composing mechanisms — a family can be at its own cap while the bus-wide ducking formula is also actively attenuating. Do not conflate them into one system.

**Sidechain ducking**: SFX bus ducks Ambient by ~-6dB on any SFX trigger; UI bus ducks both Music and SFX by ~-4dB on any UI trigger (so UI feedback always cuts through). This is a separate mechanism from Formula F1 — F1 operates *within* the SFX bus across its own voices, sidechain ducking operates *across* buses.

---

## Out of Scope

- Story 003: the cue dispatch that triggers a new voice in the first place (this story only governs what happens once a family is at/beyond capacity, or how many voices exist for F1's `N`)
- Story 002: Ambient's own continuous playback (family #7 is explicitly outside this story's per-family cap system, per Core Rule 3's own text)

---

## QA Test Cases

- **AC-11**
  - Given: a family (e.g. Combat Impact) at its configured cap (12 active voices)
  - When: one more trigger fires for that family
  - Then: the oldest-started of the 12 stops; the new trigger's voice plays; the family's active count stays at exactly the cap, never exceeding it
  - Edge cases: test with a family whose cap is 1 (Discovery Fanfare) — the single existing voice must stop and be replaced, not simply ignored

- **AC-12**
  - Given: 6 simultaneous SFX-bus voices, `V_base=0.8`, default `k=0.05`, `D_floor=0.3`
  - When: Formula F1 is evaluated for one of those voices
  - Then: result equals `0.60` (the GDD's own worked example), not merely "some reduced value"
  - Edge cases: `N=1` (no ducking, full `V_base`), `N` large enough to hit the floor exactly (confirm `D_floor` is respected, never goes below it)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio/ducking-and-voice-limiting_test.gd`

**Status**: [x] Created and passing — 11/11 test cases, 0 errors, 0 failures, 0 orphans (`tests/unit/audio/ducking-and-voice-limiting_test.gd`, run 2026-07-25). **Extended 2026-07-31**: Formula F1 wiring evidence lives in `tests/integration/audio/data-driven-cue-dispatch_test.gd` (4 new tests); Formula F3 sidechain envelope evidence is a new file, `tests/unit/audio/sidechain-ducking-envelope_test.gd` (11 deterministic unit tests) plus 4 more integration tests in `data-driven-cue-dispatch_test.gd` proving real-dispatch wiring. Full project regression at time of the F3 wiring: 1784/1784, 0 errors, 0 failures.

---

## Dependencies

- Depends on: Story 003 (voice-limiting operates on cues Story 003's dispatch mechanism fires)
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-07-25
**Criteria**: 2/2 passing (AC-11, AC-12)
**Deviations**: `VoiceLimiter` was not originally wired into `AudioCueDispatcher`'s live dispatch path (documented, in-scope deferral) — wired in as a 2026-07-25 follow-up, see Story 003's own file. Formula F1 (`compute_ducked_volume()`) and sidechain ducking (Formula F3) were both real, distinct, honestly-tracked gaps at Complete time — **both closed 2026-07-31**: F1 wired once a dispatch-time concurrent-voice-count concept existed; sidechain ducking unblocked by writing the missing attack/release timing spec (`design/quick-specs/sidechain-ducking-timing-2026-07-31.md`) and then implementing its envelope state machine. See the Note/gap-closure paragraphs above for full detail.
**Test Evidence**: Logic — `tests/unit/audio/ducking-and-voice-limiting_test.gd`, 11/11 passing, 0 orphans
**Code Review**: Complete (`/code-review` run 2026-07-25) — qa-tester flagged the sidechain-ducking gap as BLOCKING for testability confidence; addressed by relabeling the 2 sidechain tests to make clear they check tuning constants only, and documenting the gap explicitly above rather than fixing it with unspecified behavior
