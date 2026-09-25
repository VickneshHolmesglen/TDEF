# Equipment Set Effects

**Authored**: 2026-09-25 (spec: `docs/superpowers/specs/2026-09-25-equipment-set-effects-design.md`; stat bonuses: `equipment-set-bonuses.md`).
**Status**: first-pass numbers, unplaytested. Not yet seen in the running game.

## Rules

- Exactly five effect types: `on_kill_stack_buff`, `on_crit_status`, `on_wave_start_buff`, `on_skill_cast_buff`, `phase_state`.
- Each set has one capstone effect, at its highest `bonuses` threshold (top-threshold-only). Stat bonuses are unchanged.
- Every `stats` value is an additive fraction (`0.20` = +20%) folded into Hero's additive bucket, inside the existing `clamp(1 + additive_total, -0.75, 3.0)`. Keys must be in `EquipmentBonuses.FAN_OUT_STATS`.
- Timed buffs refresh, never stack (wave-start and skill-cast re-triggers reset the timer). Only kill-stack effects stack, up to `max_stacks`, and every qualifying kill refreshes the expiry of the whole stack.
- Direct kill = a `monster_died` inside Hero's effective attack range whose `kill_source` is not `wave_end` (`Hero.is_direct_kill()`, the same inner band as kill XP).
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

Troll's capstone is a kill-stack damage buff rather than a heal: nothing can damage the Hero today, so a heal would be inert (see open questions).

## DoT scale reference

Tower DoTs: poison `0.08` of target scaled HP over `4s` (`blueprint_venomdart_turret.tres`), burn `0.10` over `3s` (`blueprint_firebolt_turret.tres`), applied on every tower hit. The Hero versions apply on crits only and are set lower (Lurker poison `0.06`/4s, Goblin burn `0.08`/3s). Tick damage is `effect_value * target.scaled_hp / num_ticks`.

## Open questions

- **Inert defensive stats**: `armor`, `max_hp`, `lifesteal` and elemental resists (from gear, runes and set bonuses) do nothing while the Hero cannot be damaged. Needs a design decision on whether/when monsters can hurt the Hero. NOT addressed here.
- **Evaded crits**: crit status procs before evasion, so an evaded crit can still apply its DoT. If that feels wrong, move the trigger to the post-mitigation `monster_damage_taken`.
- **Controller created after the last phase event**: `phase_state` stays inactive until the next phase transition. If this proves real, add a phase getter on WaveManager for the controller's initial read.
- **Cross-set stacking** remains open (see `equipment-set-bonuses.md`); top-threshold-only capstones limit it but do not remove it.
- All numbers above are unplaytested.
