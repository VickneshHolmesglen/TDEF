# Audio Cue List (20 Wired Events)

**Date**: 2026-09-20
**Status**: Approved by user (design and cue table presented and approved in chat), pending spec review and implementation plan
**Scope**: Author real audio content for the 20 event cues `AudioCueDispatcher` already wires. Data-only: `.tres` `AudioCueEntry` files plus sourced audio files, zero code changes. Follows the pipeline decided in `production/qa/audio-content-pipeline-decision.md` (licensed/CC0 packs) and `design/gdd/audio-system.md` (Core Rules 3-5). Music/ambient stems, unwired UI-click/denial cues, spatial distance wiring, and per-element/per-skill variants are OUT of scope (§9).

## 1. Overview

Today only 3 of 20 wired cue names have content (`skill_unlocked`, `tower_mastery_proximity_entered`, `tower_mastery_proximity_exited`); the rest dispatch into an empty `AudioCueMap` and are correctly silent (AC-10a no-op-if-unmapped). This spec defines, for each remaining event: its cue family (voice cap), bus, spatial flag, volume offset, the character of the sound to source, and CC0 search keywords, plus file/format/licensing standards and a priority order. Mapping is one event to one `AudioStream`; repetition-prone cues use Godot's built-in `AudioStreamRandomizer` as that stream so no code change is needed.

## 2. Player Fantasy

The game stops being silent. Placing a tower thunks, towers and hero hits have weight, a boss kill lands as a spotlight moment, and crafting or building rewards you with a distinct satisfied sound: each of the sanctuary's actions has its own voice rather than one generic click.

## 3. Detailed Rules

### 3.1 Entry authoring

Each cue is one `assets/data/audio/cues/<event_name>.tres` (`script_class="AudioCueEntry"`) with fields: `event_name` (exactly the dispatch name), `stream`, `bus`, `polyphony_group`, `volume_db_offset`, `spatial`. Each is appended to the `entries` array of `assets/data/audio/audio_cue_map.tres` (add an `ext_resource` line and extend `entries`, same pattern as the 3 existing entries). No `#` comments inside the `.tres` (project rule). `polyphony_group` values are exactly the `VoiceLimiter.DEFAULT_FAMILY_CAPS` keys: `discovery_fanfare`, `progress_blip`, `denial_rejection`, `activation_confirm`, `ui_confirm_cancel`, `combat_impact`.

### 3.2 Repeated-cue variation (no code change)

For cues marked "randomizer" in §4, `stream` is an `AudioStreamRandomizer` sub-resource (not a bare `AudioStreamWAV`) holding 3-5 variant streams with `random_pitch` about 1.06 and `random_volume_offset_db` about 1.5. Godot's `AudioStreamPlayer` plays any `AudioStream`, and `AudioCueDispatcher._play_stream()` already assigns `entry.stream` generically, so no dispatcher change is needed.

### 3.3 The spatial flag, and a known limitation

`AudioCueDispatcher.dispatch_cue(event_name, distance = 0.0)` is currently called by every wire with no distance argument, so Formula F2's world-space attenuation is never applied and `spatial = true` cues play at full volume. This spec sets `spatial` per the GDD's intent (world-diegetic cues true, UI/HUD cues false) so authored data is correct when distance wiring is added later; until then `spatial = true` is inert. Wiring real distances is a code follow-up (§9).

### 3.4 Pipeline standards

- **Sources:** CC0 packs only by default (Kenney.nl, Freesound.org CC0, itch.io CC0 packs). CC-BY is allowed only if its attribution line is added to `assets/audio/sfx/LICENSE.txt` in the same commit. Each pack's license is verified at the pack's page before use; nothing with an unclear license is committed. No AI-generated or ripped audio.
- **Format:** `.wav`, 44.1 kHz, 16-bit. Mono for world cues (`spatial = true`), stereo allowed for UI cues. Trimmed of leading/trailing silence, peak-normalized to about -3 dBFS, no baked-in reverb tails longer than the cue's target length.
- **Naming:** `assets/audio/sfx/<event_name>.wav`; randomizer variants `assets/audio/sfx/<event_name>_v1.wav` ... `_v5.wav`. Godot's `.import` sidecars are committed (existing convention).
- **Length limits:** combat_impact under 0.4 s (skill cast under 0.8 s); ui/activation cues under 1.2 s; progress_blip under 1.0 s; discovery_fanfare 1.5-3.0 s.
- **Loudness targets (via `volume_db_offset`, tuned by ear at authoring time):** cues start at the offsets in §4; final levels are a listening pass, not a spec constant.
- **Sourcing log:** every chosen sound is recorded in `assets/audio/sfx/SOURCES.md` (event, source pack, original filename, license, URL, edits applied) so provenance is auditable.

## 4. Cue Table (authoritative)

`Randomizer` = use §3.2. Volume offsets are starting values.

| Event | Family (cap) | Bus | Spatial | Randomizer | Start dB | Sound character | CC0 search keywords |
|---|---|---|---|---|---|---|---|
| `tower_attacked` | combat_impact (12) | SFX | true | 4 variants | -8 | short muted shot/twang, under 0.3 s | "bow release", "crossbow", "arrow shot", "light impact" |
| `hero_damage_taken` | combat_impact | SFX | true | 3 variants | -3 | dull body thud, under 0.3 s | "body hit", "punch thud", "damage grunt-free" |
| `hero_skill_activated` | combat_impact | SFX | true | no | -4 | magical whoosh-cast; one generic cue for all 32 skills | "spell cast", "magic whoosh", "energy swell" |
| `tower_placed` | activation_confirm (4) | SFX | true | no | -4 | solid stone/wood thunk plus a small rising chime | "stone place", "wood thunk", "build confirm" |
| `pre_placement_perk_activated` | activation_confirm | SFX | false | no | -6 | bright short ascending sparkle | "sparkle up", "power up short", "magic chime" |
| `wave_countdown_warning` | combat_impact | SFX | false | no | -6 | low horn or drum tick, ominous | "war horn", "low drum hit", "warning tick" |
| `boss_died` | discovery_fanfare (1) | UI | false | no | 0 | big layered impact resolving into a sting, 2-3 s | "boss defeat", "victory sting", "big explosion cinematic hit" |
| `constellation_activated` | discovery_fanfare | UI | false | no | -2 | starry ignition swell, "pattern lights up" | "star chime swell", "magic reveal", "ethereal ignite" |
| `hero_class_unlocked` | progress_blip (4) | UI | false | no | -4 | short bright three-note ascending blip | "achievement blip", "level up short", "unlock chime" |
| `component_crafted` | progress_blip | UI | false | no | -4 | anvil clink plus satisfied chime | "anvil hit", "craft complete", "smith clink" |
| `hero_equipment_crafted` | progress_blip | UI | false | no | -3 | heavier forge clang plus chime, clearly distinct from component_crafted | "heavy anvil", "forge finish", "metal clang chime" |
| `component_repaired` | ui_confirm_cancel (6) | UI | false | no | -6 | quick light metal tap-tap | "metal tap", "repair click", "tool tap" |
| `sanctuary_structure_built` | activation_confirm | UI | false | no | -4 | bright ascending confirm with a construction feel | "build complete", "confirm ascending", "wood hammer chime" |
| `structure_upgraded` | activation_confirm | UI | false | no | -3 | higher, brighter version of structure_built | "upgrade chime", "power up bright", "level up tier" |
| `game_paused` | ui_confirm_cancel | UI | false | no | -8 | soft down-tick | "ui pause", "soft click down", "menu open soft" |
| `game_unpaused` | ui_confirm_cancel | UI | false | no | -8 | matching soft up-tick | "ui resume", "soft click up", "menu close soft" |

Already mapped (untouched): `skill_unlocked`, `tower_mastery_proximity_entered`, `tower_mastery_proximity_exited`.

**Deliberately unmapped: `mission_phase_changed`.** One stream cannot represent six mission phases, and `MusicAmbientController` owns phase-driven audio (Core Rule 2). It stays out of the cue map; the dispatcher's no-op-if-unmapped rule keeps it silent.

That is 16 new cues + 3 done + 1 unmapped = 20 wired names. (`game_paused`/`game_unpaused` count separately; `tower_mastery_proximity_changed` is one signal producing two cue names, both already mapped.)

### 4.1 Family and bus rationale (judgment calls, flagged)

- `boss_died` is assigned to `discovery_fanfare` (cap 1) on the UI bus so a boss kill gets the GDD's "genuine spotlight moment" treatment and never overlaps another fanfare; the alternative (combat_impact/SFX) would bury it among ordinary hits.
- `wave_countdown_warning` is assigned to `combat_impact` because no family fits an ominous alert better; it is non-spatial and rare, so the cap-12 pool is not a concern.
- `component_crafted` and `hero_equipment_crafted` share `progress_blip` (cap 4) but MUST sound distinct (component: lighter; equipment: heavier).

## 5. Priority Order

- **P1 (felt constantly, do first):** `tower_attacked`, `hero_damage_taken`, `tower_placed`, `hero_skill_activated`, `wave_countdown_warning`, `boss_died`.
- **P2:** `component_crafted`, `hero_equipment_crafted`, `component_repaired`, `sanctuary_structure_built`, `structure_upgraded`, `constellation_activated`.
- **P3:** `pre_placement_perk_activated`, `hero_class_unlocked`, `game_paused`, `game_unpaused`.

Each priority tier is independently shippable: a tier's cues are added to the map only when all of that tier's files are sourced and verified.

## 6. Formulas

No new formulas. Existing behavior applies unchanged: Formula F1 (concurrent-cue ducking, per-family caps and oldest-voice stealing, Core Rule 5), Formula F3 (SFX->Ambient and UI->Music/SFX sidechain ducking triggered by `bus`), and Formula F2 (spatial attenuation, inert until distance is wired, §3.3).

## 7. Edge Cases

- **A cue's audio file is missing at load:** the `.tres` `ext_resource` fails to load; the cue is omitted and the audio system stays a silent no-op for that event (Godot logs the resource error). The content test (AC-2) catches this before commit.
- **`tower_attacked` fires in bursts (12+ towers):** the combat_impact cap (12) steals the oldest voice; the randomizer's pitch/volume spread prevents a phasing "machine-gun" sound.
- **Two discovery fanfares in one frame** (`boss_died` + `constellation_activated`): cap 1 steals the oldest voice per Core Rule 5.
- **A mapped cue whose `stream` is null:** `dispatch_cue()` still runs its routing/ducking math but plays nothing; the content test rejects null streams for the 16 new entries.
- **Pause:** `game_paused`/`game_unpaused` cues play on the UI bus; the pause duck behavior (Core Rule 7) is separate and unchanged.
- **License uncertainty about a candidate sound:** it is not used; source another (the sourcing log requires a verifiable license).

## 8. Dependencies

- **Audio System** (`src/core/audio/`): consumed unchanged (`AudioCueEntry`, `AudioCueMap`, `AudioCueDispatcher`, `VoiceLimiter`).
- **`assets/audio/sfx/LICENSE.txt`**: extended when a non-Kenney pack is used.
- **Human-in-the-loop:** choosing and auditioning sounds from packs is a listening/licensing task that needs a person (Vicknesh) or a sourcing session with network access; Claude can author the `.tres` entries, the content test, and the sourcing log skeleton, and wire files once they exist.

## 9. Out of Scope (named follow-ups)

1. **Music and ambient stems** (4 Energy-level music stems, ambient bed and layers): `MusicAmbientController` currently has no stream slots, so this needs a code change plus content.
2. **UI-click, tab-switch and denial cues** (families 3 and 5's UI events): those interactions have no EventBus events; needs new hooks or a UI-sound helper.
3. **Distance wiring for spatial cues:** pass real distances from emitters into `dispatch_cue()` so Formula F2 takes effect.
4. **Per-element tower attack variants** (event payload carries `element`) and **per-skill cast variants** (32 skills): the one-event-one-stream mapping needs an extension, or per-variant event names.
5. **Voice bus content** (the Voice slider exists; no voiced content is planned).

## 10. Acceptance Criteria

- AC-1: For each of the 16 new cues, `assets/data/audio/cues/<event_name>.tres` exists, is listed in `audio_cue_map.tres`, and matches the §4 row's `event_name`, `polyphony_group`, `bus`, and `spatial` exactly.
- AC-2: Content test (new `tests/unit/audio/audio-cue-content_test.gd`) loads `audio_cue_map.tres` and asserts: every entry's `event_name` is unique; every `stream` is non-null and an `AudioStream`; every `bus` is one of `SFX`/`UI`; every `polyphony_group` is a `DEFAULT_FAMILY_CAPS` key; the 16 new events plus the 3 existing are all present; `mission_phase_changed` is NOT present.
- AC-3: Cues marked "randomizer" in §4 have an `AudioStreamRandomizer` stream with at least 3 variants.
- AC-4: Every referenced audio file exists under `assets/audio/sfx/` with the naming in §3.4 and has an entry in `SOURCES.md` (event, source, license, URL).
- AC-5: `LICENSE.txt` includes attribution for any CC-BY source used; no source without a verifiable CC0/CC-BY license is present.
- AC-6: Existing audio tests (`tests/unit/audio`, `tests/integration/audio` if present) still pass, showing dispatch behavior is unchanged.
- AC-7: A short manual listening pass (recorded as a note in `production/qa/`) confirms each shipped cue is audible, distinct within its family, and not fatiguing at expected repetition; this is the only non-automatable criterion.
