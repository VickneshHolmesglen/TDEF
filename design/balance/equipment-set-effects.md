# Equipment Set Effects

**Authored**: 2026-09-25 (spec: `docs/superpowers/specs/2026-09-25-equipment-set-effects-design.md`; stat bonuses: `equipment-set-bonuses.md`).
**Status**: first-pass numbers, unplaytested. Not yet seen in the running game.

## Rules

- Exactly five effect types: `on_kill_stack_buff`, `on_crit_status`, `on_wave_start_buff`, `on_skill_cast_buff`, `phase_state`.
- Each set has one capstone effect, at its highest `bonuses` threshold (top-threshold-only). Stat bonuses are unchanged.
- Every `stats` value is an additive fraction (`0.20` = +20%) folded into Hero's additive bucket, inside the existing `clamp(1 + additive_total, -0.75, 3.0)`. Keys must be in `EquipmentBonuses.FAN_OUT_STATS`.
- Timed buffs refresh, never stack (wave-start and skill-cast re-triggers reset the timer). Only kill-stack effects stack, up to `max_stacks`, and every qualifying kill refreshes the expiry of the whole stack.
- Direct kill = a `monster_died` (or an entry in `monsters_died_batch`; the monster manager emits one or the other per frame, never both for the same death, and both are counted) inside Hero's effective attack range whose `kill_source` is not `wave_end` (`Hero.is_direct_kill()`, the same inner band as kill XP).
- Crit status procs on the emitted crit flag of auto-attack and skill-hit events, before evasion is rolled.
- Effects and their runtime state are derived, never saved.

## Values

| Set | Threshold | Name | Type | Params |
|---|---|---|---|---|
| Troll | 4 | Troll's Frenzy | `on_kill_stack_buff` | `stats {physical_attack: 0.03}`, `max_stacks 10`, `duration 6.0` |
| Lurker | 2 | Venom Strike | `on_crit_status` | poison, `0.06`, `4.0` |
| Goblin | 4 | Ember Raid | `on_crit_status` | burn, `0.08`, `3.0` |
| Brute | 5 | Juggernaut | `on_wave_start_buff` | `stats {physical_attack: 0.35, attack_range: 0.15}`, `duration 10.0` |
| Warlord | 5 | Battle Cry | `on_wave_start_buff` | `stats {physical_attack: 0.20, magic_attack: 0.20}`, `duration 15.0` |
| Iron | 4 | Steel Reflex | `on_skill_cast_buff` | `stats {physical_attack: 0.15}`, `duration 5.0` |
| Reinforced | 4 | Braced Stance | `on_skill_cast_buff` | `stats {attack_range: 0.20}`, `duration 6.0` |
| Sentinel | 4 | Overwatch | `phase_state` | `stats {attack_range: 0.20}`, `phases ["WAVE_ACTIVE"]` |
| Leather | 3 | Fleet-Footed | `phase_state` | `stats {move_speed: 0.30}`, `phases ["SCOUT","INTERMISSION"]` |

Troll's capstone is a kill-stack damage buff rather than a heal: when capstones were designed nothing could damage the Hero. Hero damage has since shipped, so the heal now lives on as Troll's second-tier effect (below).

## Second-tier effects (2026-10-06, `docs/superpowers/specs/2026-10-06-equipment-set-defensive-effects-design.md`)

One capstone stays at each set's top threshold; three defensive sets also carry one effect at a lower threshold.

| Set | Threshold | Name | Type | Params |
|---|---|---|---|---|
| Troll | 2 | Troll Blood | `on_kill_heal` | `heal_fraction 0.015` (of effective max HP, per direct kill) |
| Brute | 4 | Iron Hide | `on_hurt_shield` | `shield_fraction 0.08`, `duration 4.0`, `cooldown 8.0` |
| Reinforced | 2 | Last Stand | `low_hp_state` | `hp_fraction 0.30`, `stats {armor: 0.50, physical_attack: 0.20}` |

Scale: elite/boss hits are 20-70 before armor every 2.2-4.0 s; Hero base max HP 500. Live check 2026-10-06 (944 max HP, 99 armor): a 50 hit landed as 25, granted a 76 shield next frame, which then absorbed the following two hits. Shields absorb after armor/resist, so the two multiply.

## DoT scale reference

Tower DoTs: poison `0.08` of target scaled HP over `4s` (`blueprint_venomdart_turret.tres`), burn `0.10` over `3s` (`blueprint_firebolt_turret.tres`), applied on every tower hit. The Hero versions apply on crits only and are set lower (Lurker poison `0.06`/4s, Goblin burn `0.08`/3s). Tick damage is `effect_value * target.scaled_hp / num_ticks`.

## Open questions

- **Defensive stats** (`armor`, `max_hp`, `lifesteal`, resists) are live since Hero damage shipped (elite/boss telegraphed attacks); the second-tier effects above build on that.
- **Evaded crits**: crit status procs before evasion, so an evaded crit can still apply its DoT. If that feels wrong, move the trigger to the post-mitigation `monster_damage_taken`.
- **Controller created after the last phase event**: `phase_state` stays inactive until the next phase transition. If this proves real, add a phase getter on WaveManager for the controller's initial read.
- **Cross-set stacking** remains open (see `equipment-set-bonuses.md`); top-threshold-only capstones limit it but do not remove it.
- All numbers above are unplaytested.

## Constraints for future capstones

- **`max_hp` does not work as an effect stat.** Hero caches `_max_hp` and refreshes it only in `reset_to_defaults()` and on level-up (see the comment near `hero.gd:303`), and the HP bar and overheal clamp read that cache. A modifier on `max_hp` changes `get_effective_stat(&"max_hp")` but not the displayed or clamped HP. No shipped capstone uses it; avoid it (validation currently permits it).
- **`attack_range` capstones also widen kill-XP bands.** Sentinel Overwatch, Reinforced Braced Stance and Brute Juggernaut deliberately widen the kill-XP inner band and the direct-kill radius too (both read `get_effective_stat(&"attack_range")`), which also widens Troll's Frenzy stacking radius. Kill XP is therefore no longer identical with those buffs active; this is intended.
- **Direct kill counts both death signals.** See the Direct kill rule line above: both `monster_died` and `monsters_died_batch` are counted.
