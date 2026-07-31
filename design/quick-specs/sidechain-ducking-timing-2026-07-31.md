# Quick Design Spec: Sidechain Ducking — Attack/Release Timing

**Type**: Addition
**System**: Audio System
**GDD Reference**: `design/gdd/audio-system.md` — Core Rule 5
**Date**: 2026-07-31

## Change Summary

Defines the missing attack/release envelope behavior for the sidechain ducking mechanism Core Rule 5 already names (SFX triggers duck Ambient by -6dB; UI triggers duck Music+SFX by -4dB) but never specifies the timing of. This is the exact gap `voice_limiter.gd`'s own test file flags as the reason the mechanism has never been wired into live dispatch: the dB amounts exist as constants, but nothing says how fast the duck engages, how it behaves under a rapid stream of triggers, or how fast it releases.

## Motivation

Without attack/release timing, "duck Ambient by -6dB on any SFX trigger" is not implementable — a programmer would have to invent the envelope behavior themselves (instant snap? fade? does every trigger re-attack the duck, causing audible "pumping" during dense combat?). This has already caused the mechanism to sit unbuilt through multiple sessions rather than risk shipping guessed-at behavior. Closing this unblocks Audio System's Core Rule 5 from being fully implementable and gives `AudioCueDispatcher` a concrete hook to wire against, the same dispatch-time hook Formula F1 (concurrent-cue ducking) already uses.

## Design Delta

Current GDD says (`design/gdd/audio-system.md`, Core Rule 5, final sentence):

> Sidechain ducking: the SFX bus ducks Ambient by roughly -6dB on any SFX trigger; the UI bus ducks both Music and SFX by roughly -4dB on any UI trigger, so UI feedback always cuts through combat chaos, never the reverse.

This spec replaces that sentence with a fully specified envelope model (below), and adds a new Formula (F3) and Tuning Knobs entries for the attack/release values.

## New Rules / Values

**Trigger definition**: A qualifying trigger is any `AudioCueDispatcher.dispatch_cue()` call whose resolved `AudioCueEntry.bus` matches the source bus for a given duck relationship — `&"SFX"` for the SFX→Ambient relationship, `&"UI"` for the UI→Music+SFX relationship. Ambient-family cues (Core Rule 3 family #7, continuous, outside the one-shot dispatch system) never count as triggers themselves — they are only ever a duck *target*, never a duck *source*.

**Envelope behavior** (applies independently to each of the 2 duck relationships — SFX→Ambient and UI→Music+SFX — each with its own attack/release state):

1. **Attack**: On the first qualifying trigger while the relationship is at rest (not currently ducked or releasing), the target bus(es) ramp linearly from their current `volume_db` to `current_db - duck_amount_db` over `attack_time`.
2. **Hold / retrigger**: Every subsequent qualifying trigger that arrives *while already ducked* (including mid-attack or mid-release) resets a `release_delay` countdown rather than re-running the attack ramp. This is the mechanism that prevents audible "pumping" — a dense stream of Combat Impact cues during WAVE_ACTIVE holds Ambient continuously ducked rather than re-attacking on every individual hit.
3. **Release**: `release_delay` after the *last* qualifying trigger (no new one arriving in that window), the bus(es) ramp linearly back from the ducked level to their pre-duck level over `release_time`. A new qualifying trigger arriving mid-release cancels the release and re-enters the held-duck state at the bus's current (partially-released) level — it does not snap back to the full duck level first.

**Formula F3 — Sidechain Duck State (per relationship, evaluated per-frame while active)**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `duck_amount_db` | `D` | float | -8 to -2 | Target attenuation once fully ducked (Core Rule 5's existing -6dB/-4dB values) |
| `attack_time` | `T_a` | float (sec) | 0.005–0.05 | Time to ramp from unducked to fully ducked |
| `release_delay` | `T_h` | float (sec) | 0.05–0.3 | Time after the last trigger before release begins (the "hold") |
| `release_time` | `T_r` | float (sec) | 0.1–0.4 | Time to ramp from fully ducked back to unducked, once release begins |
| `current_db_offset` | `V_t` | float | `[D, 0]` | The actual dB offset applied at time `t` — 0 at rest, `D` when fully ducked |

**Expression** (state machine, not a closed-form formula — matches this GDD's own precedent of a state-driven rule where a single equation doesn't apply, e.g. Core Rule 2's crossfade/duck-cut state model):
```
on qualifying_trigger:
  if state == RESTING:
    state = ATTACKING; attack_start_db = current_db_offset; attack_start_time = now
  reset release_timer to T_h  # always, regardless of state

per-frame:
  if state == ATTACKING:
    V_t = lerp(attack_start_db, D, clamp((now - attack_start_time) / T_a, 0, 1))
    if V_t reaches D: state = HELD
  if state == HELD and release_timer expired:
    state = RELEASING; release_start_db = current_db_offset; release_start_time = now
  if state == RELEASING:
    V_t = lerp(release_start_db, 0, clamp((now - release_start_time) / T_r, 0, 1))
    if V_t reaches 0: state = RESTING
```

**Worked example** (SFX→Ambient, default values): a `tower_attacked` cue dispatches (bus=SFX) while Ambient is at rest. Ambient's `volume_db` ramps from `0` to `-6dB` over `15ms` (`T_a`). Three more Combat Impact cues dispatch over the next `400ms` — each resets the `150ms` hold timer (`T_h`) rather than re-attacking. `150ms` after the last of those four triggers, Ambient begins ramping back from `-6dB` to `0dB` over `250ms` (`T_r`) — total time from last trigger to fully restored: `400ms`.

## Composition with Existing Mechanisms

- **Bus-hierarchy stacking is intentional, not a bug**: per Core Rule 1, Ambient is a true child bus under Music. If a UI trigger ducks Music by -4dB (via the UI→Music+SFX relationship) at the same moment an SFX trigger ducks Ambient by -6dB directly (via the SFX→Ambient relationship), the player hears Ambient's *combined* attenuation as -10dB (Godot's bus graph sums a child's own `volume_db` with every ancestor bus's `volume_db` along the signal chain) — both duck relationships are independently correct and are expected to stack when they overlap. This is the same "peer-bus reality, not a nested-category assumption" Core Rule 1 already establishes for SFX/UI routing.
- **Independent of Formula F1**: F1 attenuates a cue's *own* volume based on concurrent SFX-bus voice count (Core Rule 5's existing scope clarification). Sidechain ducking attenuates a *different* bus's fader entirely. They compose multiplicatively (in dB terms, additively) with no special-cased interaction needed — the same "the two mechanisms compose, they don't replace each other" language Core Rule 5 already uses for per-family caps vs. F1.
- **Interaction with Core Rule 7 (Pause)**: while paused, the SFX bus's world-combat content is muted entirely (Core Rule 7), so no new SFX-sourced qualifying triggers can fire during pause — any sidechain duck already in HELD or RELEASING state at the moment of `game_paused` should freeze in place (same "resume exactly where it left off" discipline Core Rule 7 already requires for music crossfades), not release early just because no new triggers are arriving while frozen.

## Edge Cases (new, added to the GDD's existing Edge Cases section)

- **If a qualifying trigger arrives while a duck relationship is mid-RELEASING**: cancel the release and re-enter HELD at the current (partially-released) `current_db_offset` — do not snap back to full `D` first and do not let the release continue underneath the new hold.
- **If `game_paused` fires while a relationship is ATTACKING, HELD, or RELEASING**: freeze `current_db_offset` exactly where it is (matching Core Rule 7's crossfade-freeze precedent) until `game_unpaused`, then resume the same state.
- **If both SFX→Ambient and UI→Music+SFX are simultaneously active**: no special handling needed — see Composition note above; the stacking is a correct outcome of the bus graph, not an interaction to suppress.

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| Audio System (`audio-system.md`) | Core Rule 5 gains a fully specified envelope model, new Formula F3, 6 new Tuning Knobs entries, 3 new Edge Cases | Update GDD (pending approval below) |
| `src/core/audio/voice_limiter.gd` | Currently holds only the 2 dB constants (`SFX_TO_AMBIENT_DUCK_DB`, `UI_TO_MUSIC_AND_SFX_DUCK_DB`) with no envelope logic | Implementation follow-up (new story, not part of this spec) — this spec unblocks it, doesn't implement it |
| `src/core/audio/audio_cue_dispatcher.gd` | `dispatch_cue()` already has the exact hook point (post voice-registration) Formula F1 uses; sidechain triggers would hook in the same place | Implementation follow-up |
| `tests/unit/audio/ducking-and-voice-limiting_test.gd` | Its own comment currently states sidechain ducking is "not wired into any bus... not implemented this pass because the GDD specifies no attack/release timing for it" — that blocking reason is closed by this spec | Test file's comment should be updated once implementation lands (not part of this spec) |

## Acceptance Criteria

- [ ] A qualifying SFX-bus trigger ramps Ambient's `volume_db` from 0 to -6dB over 15ms (default `T_a`), not an instant snap
- [ ] A second qualifying trigger arriving 100ms after the first (while still within the 150ms hold window) resets the hold timer without re-running the attack ramp — Ambient's dB stays at -6dB throughout, no audible re-dip
- [ ] 150ms after the last qualifying trigger with no new one arriving, Ambient begins releasing back to 0dB over 250ms
- [ ] A qualifying trigger arriving mid-release re-enters HELD from the current partially-released dB value, not from -6dB
- [ ] `game_paused` freezes the current duck state exactly where it is; `game_unpaused` resumes from that exact point
- [ ] No regression: Formula F1's per-cue ducking (a separate mechanism, same SFX bus) continues to apply independently and composes correctly with any active sidechain duck

## GDD Update Required?

**Yes** — `design/gdd/audio-system.md`:
- Core Rule 5: replace the final sentence (quoted in Design Delta above) with a reference to the new envelope model + Formula F3
- New **Formula F3** section (state machine + worked example, as drafted above)
- **Tuning Knobs** table: 6 new rows (`duck_amount_db` ×2 relationships already exist as the current -6/-4dB values, restated with Safe Range; `attack_time`, `release_delay`, `release_time` ×2 relationships)
- **Edge Cases** section: 3 new bullets (drafted above)
