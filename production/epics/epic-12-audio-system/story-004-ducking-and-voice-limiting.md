# Story 004: Ducking and Voice Limiting — Per-Family Caps, Oldest-Voice Stealing, Sidechain Ducking

> **Epic**: Audio System
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-07-25

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

- [ ] **AC-11**: GIVEN a family's voice cap (e.g. Combat Impact, 12) is already at capacity, WHEN one more trigger fires, THEN the oldest-started voice on that family stops and the new trigger plays — the newest trigger is never silently dropped.
- [ ] **AC-12**: GIVEN 6 simultaneous SFX-bus voices are active, WHEN Formula F1 is evaluated with the Tuning Knobs' default `k=0.05`/`D_floor=0.3`, THEN each voice's ducked volume matches the formula's worked example (`0.60` for `V_base=0.8`).

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (voice-limiting operates on cues Story 003's dispatch mechanism fires)
- Unlocks: None
