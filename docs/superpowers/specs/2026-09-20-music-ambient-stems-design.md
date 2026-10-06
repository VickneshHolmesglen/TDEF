# Music and Ambient Stems (Playback + Synthesized Placeholder Content)

**Date**: 2026-09-20
**Content update (2026-10-07)**: the §3.4 synthesized placeholder content is fully replaced by real CC0 audio (music: tools/audio/build_music_stems.py; ambient: tools/audio/build_ambient_beds.py; sources in assets/audio/sfx/SOURCES.md) and synth_stems.sh is removed. The playback design below is unchanged.
**Status**: Approved by user (design presented and approved in chat), pending spec review and implementation plan
**Scope**: Give `MusicAmbientController` real audio playback (it is currently a pure state machine with no `AudioStreamPlayer` at all) and author placeholder stems for it. Implements the playback half of `design/gdd/audio-system.md` Core Rule 2 (state-driven Music and Ambient) and follows `2026-09-20-audio-cue-list-design.md` §9 follow-up #1. Content is SYNTHESIZED PLACEHOLDERS generated with ffmpeg (user decision, 2026-09-20: Kenney has no music-loop pack, and picking real music without listening risks setting the wrong mood); real music later replaces them by editing one data file, with no code change.

## 1. Overview

`MusicAmbientController` already owns the Music Energy state machine (`CONTEMPLATIVE` / `MEASURED` / `URGENT` / `MEASURED_URGENT`), crossfade/duck timing (including the countdown-length anticipatory crossfade and the 0.4 s hard duck), the pause freeze, and the ambient combat-layer active/fading flags, all covered by existing tests. What it lacks is any sound. This spec adds: a data resource mapping each state to a stream; player nodes and a per-frame level ramp inside the controller; and six synthesized loopable stems.

## 2. Player Fantasy

The game stops being a silent room between sound effects. The Sanctuary hums with a warm, contemplative bed; a scouting phase has a slow expectant pulse; a wave arrives as the pulse quickens into a driving rhythm timed to the countdown, and the relief when a wave clears lands as a sharp drop into a tense-but-calm bed, with the rough clash of battle receding after it.

## 3. Detailed Rules

### 3.1 Data: `MusicAmbientMap`

New Resource `src/core/audio/music_ambient_map.gd`, `class_name MusicAmbientMap`, `extends Resource`, with six `@export var ...: AudioStream = null` fields: `contemplative`, `measured`, `urgent`, `measured_urgent`, `ambient_base_bed`, `ambient_combat_layer`. Content file: `assets/data/audio/music_ambient_map.tres`. A null field means "no stream for this slot": silent, never an error (same spirit as AC-10a for unmapped cues). Adding the `class_name` requires a class-cache rebuild (`Godot.exe --headless --editor --path <project> --quit`) before tests or MCP runs.

### 3.2 Wiring

`AudioSystem._ready()` (not the controller) loads `res://assets/data/audio/music_ambient_map.tres` if it exists and calls `music_ambient.set_stream_map(map)` after the controller is added. The controller never loads content itself, so every existing test that does `MusicAmbientController.new()` keeps its no-audio behavior unchanged. A missing map file leaves the game silent, as today.

### 3.3 Controller playback

New in `MusicAmbientController`:

- **API:** `set_stream_map(map: MusicAmbientMap) -> void` builds the players (idempotent: calling it again replaces streams on the existing players and re-applies the current state), and the test accessors in §3.7.
- **Players:** one `AudioStreamPlayer` per non-null music stem on bus `Music`, plus `ambient_base_bed` and `ambient_combat_layer` players on bus `Ambient`. All players use `process_mode = Node.PROCESS_MODE_ALWAYS`: the GDD's pause rule (Core Rule 7) ducks Music/Ambient to about 40% rather than stopping them, and a default-mode `AudioStreamPlayer` would stop with the tree. The bus-level pause duck (`PauseDuckController`) is untouched and stacks with these per-player levels; the two never touch the same value (levels here are per-player `volume_db`, the duck is bus volume).
- **Looping:** on assignment each stream is made loopable at runtime: `AudioStreamOggVorbis` gets `loop = true`; `AudioStreamWAV` gets `loop_mode = LOOP_FORWARD`, `loop_begin = 0`, `loop_end` = frame count. No per-file `.import` loop settings are relied on.
- **Levels:** each music stem has `level: float` in [0, 1]. Each frame `advance_time(delta)` moves every level toward its target (1.0 for the stem matching `_music_state`, 0.0 for the rest) by at most `delta / duration`, where `duration = maxf(_last_transition_duration, 0.01)`. This reuses the existing transition timing verbatim (standard 1.0 s crossfades, the countdown-length anticipatory crossfade, the 0.4 s hard duck). The audible player volume is `linear_to_db(sqrt(level))` (equal-power: with linear levels summing to 1, total power stays constant through a crossfade). Because levels always slew toward the CURRENT target, a new transition arriving mid-fade retargets smoothly from wherever the levels are; there is no per-transition bookkeeping to corrupt.
- **Start/stop:** a stem player is `play()`ed when its level rises above 0 while stopped, and `stop()`ped once its level is 0 and its target is 0. At map load the current state's stem starts at level 1.0 (initial state is `CONTEMPLATIVE`, per the GDD's "initial boot" entry condition).
- **Ambient base bed:** started once at map load and never stopped or restarted (extends AC-6, `_ambient_base_bed_start_count` still never exceeds 1). It has no level ramp; it plays at unity.
- **Ambient combat layer:** its own level in [0, 1]. Target is 1 while `_ambient_combat_layer_active` and not fading out; while `_ambient_combat_layer_fading_out` it ramps down linearly over `AMBIENT_COMBAT_LAYER_FADE_OUT_SECONDS` (2.0, existing); when it becomes active it ramps up over a new `AMBIENT_COMBAT_LAYER_FADE_IN_SECONDS = 1.5`. The player starts above level 0 and stops at 0.
- **Freeze:** `advance_time()` already returns immediately while `_paused`; level ramps therefore freeze in place exactly like the existing transition timers (AC-15a). Players keep playing at their frozen levels (pause duck lowers the bus).
- **Determinism for tests:** all level math lives in `advance_time()` and pure helpers, never in `_process` timing or `Tween`s, matching this controller's existing "no time-dependent assertions" convention.

### 3.4 Placeholder stems (synthesized)

Generated by a checked-in, reproducible `tools/audio/synth_stems.sh` (ffmpeg only, no third-party audio, so no license to track; recorded in `SOURCES.md` as "synthesized"). Output: Ogg Vorbis (`libvorbis`, about q5), 48 kHz stereo, into `assets/audio/music/` (four stems) and `assets/audio/ambient/` (two). Filenames match the map fields: `contemplative.ogg`, `measured.ogg`, `urgent.ogg`, `measured_urgent.ogg`, `ambient_base_bed.ogg`, `ambient_combat_layer.ogg`.

| Stem | Character | Construction |
|---|---|---|
| contemplative | warm, still detuned pad | 3-4 sine partials (A2/E3/A3 family), each with a +/- detuned partner, slow amplitude LFO, low-passed about 800 Hz |
| measured | expectant slow pulse over a pad | pad in a different chord, plus a soft tone gated by a 1 Hz tremolo |
| urgent | driving rhythm | low tone gated at 2 Hz plus a higher minor-chord tone gated at 4 Hz, brighter filter |
| measured_urgent | tense but calm, "held breath released" | tense minor pad plus a 1 Hz gated tone, darker than urgent |
| ambient_base_bed | room tone | very quiet low-passed noise plus a faint slow-moving band-passed layer |
| ambient_combat_layer | rough battle clash bed | band-passed noise with a 3 Hz gate and a low rumble |

**Loop seams.** Tonal stems (pads, pulses) use a 16 s loop with every partial and LFO/tremolo frequency an exact multiple of 1/16 Hz, so each completes a whole number of cycles and the loop point is phase-continuous. Noise-based stems (the two ambient beds) are generated 12 s long, then made seamless by crossfading the last 1 s onto the first 1 s (result 11 s), so the wrap is continuous. Levels: about -14 dBFS peak for music stems, lower for ambient beds, so the SFX and UI buses stay dominant. The script is the source of truth; the `.ogg` files are its committed output.

### 3.5 Buses and levels

Music stems play on `Music`, ambient on `Ambient` (a child of `Music`), both already configured by `AudioSystem._configure_buses()`. Player-facing volume sliders, the sidechain ducking (`SFX_TO_AMBIENT`, `UI_TO_MUSIC_AND_SFX`) and the pause duck all continue to work unchanged.

### 3.6 Localization/UI

None. No player-facing text is added.

### 3.7 Test accessors

On the controller: `get_stem_level(state: MusicState) -> float`, `is_stem_playing(state: MusicState) -> bool`, `get_ambient_combat_level() -> float`, `is_ambient_combat_playing() -> bool`, `is_ambient_base_playing() -> bool`. Pure helper `static func level_to_volume_db(level: float) -> float` (`linear_to_db(sqrt(level))`, with a floor to avoid -inf) for direct unit testing.

## 4. Formulas

Crossfade level slew: `level_next = move_toward(level, target, delta / duration)`, with `duration = maxf(_last_transition_duration, 0.01)`. Equal-power output: `volume_db = linear_to_db(sqrt(level))` (level 1.0 gives 0 dB; level 0.5 gives about -3 dB; level 0 is muted/stopped). Combat layer level: `move_toward(level, target, delta / fade_seconds)` where `fade_seconds` is `AMBIENT_COMBAT_LAYER_FADE_IN_SECONDS` (1.5) going up and `AMBIENT_COMBAT_LAYER_FADE_OUT_SECONDS` (2.0) going down. No changes to the existing transition-duration rules.

## 5. Edge Cases

- **Null stream slot or missing map file:** that slot/the whole system is silent, no error.
- **A transition interrupted mid-fade** (e.g. countdown warning starts an anticipatory crossfade, then `WAVE_ACTIVE` arrives early): levels continue from where they are toward the new target; the existing resync-fallback snap in `_on_mission_phase_changed` still applies to `_transitioning`, and levels simply finish slewing at the current rate (or are snapped by `force_finish_transition()` in tests, which must also set levels to their targets; see §3.3 test seam note in AC-8).
- **`set_stream_map()` called twice** (or with a different map): existing players are reused/updated, no duplicate players, the ambient base bed is not restarted if its stream is unchanged.
- **Pause:** frozen levels hold; players keep playing; the bus duck attenuates; on resume, ramps continue exactly where they left off.
- **Hard duck to `MEASURED_URGENT`:** uses the existing 0.4 s duration, so `URGENT`'s level falls to 0 in 0.4 s while `MEASURED_URGENT` rises, equal-power.
- **Same-phase retrigger:** no change (existing AC-5); nothing new is started.
- **Stream shorter than a transition:** irrelevant; looping handles it.
- **Headless/dummy audio driver (tests, CI):** `AudioStreamPlayer.play()` works with the dummy driver, so `is_stem_playing()` reflects real player state without audible output.

## 6. Dependencies

- **`MusicAmbientController`**: extended (players, levels, accessors); all existing behavior and accessors preserved.
- **`AudioSystem`**: loads the map and calls `set_stream_map()`.
- **`PauseDuckController`**: unchanged.
- **`VoiceLimiter` / `AudioCueDispatcher`**: unchanged (one-shots are separate from music).
- **ffmpeg** (`C:\ffmpeg-8.0.1-full_build\bin\ffmpeg`, already used by `tools/audio/`) with `libvorbis`.
- **`design/gdd/audio-system.md`**: OQ-2 note updated when this lands; Core Rule 2's four state-layer ambient design is only partially realized (base + combat), see §9.

## 7. Tuning Knobs

`AMBIENT_COMBAT_LAYER_FADE_IN_SECONDS = 1.5` (new). Existing: `WAVE_ACTIVE_TO_INTERMISSION_DUCK_SECONDS = 0.4`, `AMBIENT_COMBAT_LAYER_FADE_OUT_SECONDS = 2.0`, the standard 1.0 s crossfade. Stem peak levels are constants in `synth_stems.sh`.

## 8. Acceptance Criteria

- AC-1: `MusicAmbientMap` exists with the six fields; `assets/data/audio/music_ambient_map.tres` loads with all six fields non-null.
- AC-2: With a fixture map, after `set_stream_map()` the `CONTEMPLATIVE` stem is playing at level 1.0, the other three stems are not playing, the ambient base bed is playing, and the combat layer is not.
- AC-3: A `SCOUT` phase change followed by `advance_time()` totalling the transition duration takes `MEASURED`'s level to 1.0 and `CONTEMPLATIVE`'s to 0.0 (stopped); at half the duration both levels are 0.5 and the volumes are about -3 dB each (equal-power).
- AC-4: The anticipatory crossfade (`wave_countdown_warning`) reaches `URGENT` level 1.0 exactly when `advance_time()` has consumed `seconds_remaining`.
- AC-5: The `WAVE_ACTIVE` -> `INTERMISSION` hard duck takes `URGENT` to 0 and `MEASURED_URGENT` to 1.0 within 0.4 s of `advance_time()`.
- AC-6: A transition interrupted mid-fade retargets smoothly: levels never jump, never exceed [0, 1], and settle at the new target.
- AC-7: While frozen (`freeze_transition()`), `advance_time()` leaves all levels unchanged; after `resume_transition()` they continue from the same values.
- AC-8: `force_finish_transition()` sets every stem's level to its target and stops zero-level players (so deterministic tests can assert post-transition state).
- AC-9: The ambient base bed's `_ambient_base_bed_start_count` never exceeds 1 across any sequence of phase changes and repeated `set_stream_map()` calls; the base player never restarts.
- AC-10: The combat layer ramps up over 1.5 s on `WAVE_ACTIVE` and down over 2.0 s after `INTERMISSION`, and stops at level 0.
- AC-11: A null slot or null map produces no players for that slot and no errors; existing controller tests (which never set a map) pass unmodified.
- AC-12: All players have `process_mode == PROCESS_MODE_ALWAYS` and use the `Music` (stems) or `Ambient` (ambient) bus.
- AC-13: The generated stems loop seamlessly: `synth_stems.sh` verifies, per stem, that the first and last 10 ms of PCM differ by less than a stated threshold (a click-free-seam check), and the check is part of the script's self-test.
- AC-14: `SOURCES.md` records the six stems as synthesized (script + parameters), and `tools/audio/synth_stems.sh` regenerates them byte-for-byte deterministic enough to diff-check the parameters (Ogg encoder output may vary; the script's parameter set is the source of truth).
- AC-15: Existing audio suites (`tests/unit/audio`, `tests/integration/audio`, including pause-behavior and volume-preference tests) pass.
- AC-16 (manual, not automatable): a listening pass in the running game confirms the stems are audible, the crossfades and the wave-clear duck feel right, and no loop click is heard. Recorded in `production/qa/audio-cue-listening-pass.md` (extended with a music/ambient section).

## 9. Out of Scope (named follow-ups)

1. **Real music** to replace the placeholders (a data-only swap of the six stream slots).
2. **The remaining ambient state layers** named in `audio-system.md` Core Rule 2: the SANCTUARY dust-mote hush, the SCOUT grid-hum, and the INTERMISSION lingering smoke-crackle. The controller only models the combat layer today; adding the others needs state-machine additions plus content.
3. **Adaptive stem layering** (vertical mixing) and beat-synchronized transitions.
4. **Per-mission or per-biome music variants.**
5. **Music for menus/Mission Select** beyond the existing `CONTEMPLATIVE` mapping.
