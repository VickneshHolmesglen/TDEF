# Audio Cue Listening Pass

**Status**: NOT YET RUN (requires a person listening in the running game)

For each shipped cue, confirm: audible at default volume, distinct within its family,
not fatiguing at expected repetition, sounds correct for its trigger.

**Known weak matches to judge first** (flagged in `assets/audio/sfx/SOURCES.md`):
`hero_skill_activated` (blade whoosh, not a magic cast), `boss_died` (plate impact + bell,
not a victory sting), `wave_countdown_warning` (bell toll, not a horn), `tower_placed`
(no rising chime), `constellation_activated` (1.16 s, under the 1.5-3.0 s fanfare range).

| Event | Audible | Distinct in family | Not fatiguing | Notes |
|---|---|---|---|---|
| tower_attacked | | | | |
| hero_damage_taken | | | | |
| hero_skill_activated | | | | |
| tower_placed | | | | |
| wave_countdown_warning | | | | |
| boss_died | | | | |
| component_crafted | | | | |
| hero_equipment_crafted | | | | |
| component_repaired | | | | |
| sanctuary_structure_built | | | | |
| structure_upgraded | | | | |
| constellation_activated | | | | |
| pre_placement_perk_activated | | | | |
| hero_class_unlocked | | | | |
| game_paused | | | | |
| game_unpaused | | | | |

## UI cues (added 2026-09-27; ALL are placeholders chosen by measurement, never auditioned)

Audition in the running game (click across Sanctuary, HUD, Mission Select, Pause Menu). Known caveat:
`ui_click` has only 2 variants, so judge whether repetition is fatiguing at typical click rates.

| Cue | Audible | Distinct in family | Not fatiguing | Notes |
|---|---|---|---|---|
| ui_click | | | | |
| ui_confirm | | | | |
| ui_cancel | | | | |
| ui_denied | | | | |

## Music and ambient stems (added 2026-09-20; ALL are synthesized placeholders)

Confirm in the running game: each stem is audible and fits its state; crossfades
(Sanctuary -> Scout -> Wave) feel smooth and the countdown crossfade lands with the
first wave spawn; the wave-clear duck feels like "a held breath released"; the ambient
base bed sits under everything; the combat layer swells in with the wave and recedes
after; no loop click is audible on any stem; pausing ducks (not stops) music and ambient.

| Stem | Audible | Fits its state | No loop click | Notes |
|---|---|---|---|---|
| contemplative | | | | |
| measured | | | | |
| urgent | | | | |
| measured_urgent | | | | |
| ambient_base_bed | | | | |
| ambient_combat_layer | | | | |
