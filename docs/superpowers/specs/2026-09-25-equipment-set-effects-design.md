# Equipment Set Effects (Capstone Special Effects, 9 Sets)

**Date**: 2026-09-25
**Status**: Design approved by user in chat (vocabulary, architecture, data flow); one approved item amended during spec writing (see §2.1). Implemented: all 11 plan tasks are complete and pushed (see the plan and session state). Plan: `docs/superpowers/plans/2026-09-25-equipment-set-effects.md`.
**Scope**: Each of the nine equipment sets gains one **capstone effect** at its top threshold, drawn from a fixed five-type vocabulary. Builds on `2026-09-20-equipment-set-bonuses-design.md` (sets, thresholds, `EquipmentBonuses`), `2026-09-20-equipment-stats-wiring-design.md` (Hero recompute-on-equip) and `2026-09-20-equipment-display-design.md` (info panel). Stat bonuses are unchanged. Values are authoritative in §4; `design/balance/equipment-set-effects.md` is created alongside the implementation as the tuning mirror.

## 1. Overview

Sets currently grant flat stats only. `EquipmentBonuses.compute()` folds those into the flat/additive buckets, which cannot express a conditional or triggered effect. This spec adds a second, separate channel: a set can carry `effects` (one per threshold, in practice only the top one) that a new `SetEffectController` turns into live behaviour by subscribing to EventBus signals that already exist. No new EventBus events are added.

The design has four parts: (1) `effects` data on `EquipmentSetResource`; (2) `SetEffectResolver`, a pure static class that answers "which effects are active for this equipment"; (3) `SetEffectController`, a node under Hero that runs the effects; (4) two small, targeted additions to existing systems (a transient modifier layer on Hero and a public DoT entry on MonsterManager).

## 2. Player Fantasy

Committing to a family pays off in play, not just in the stat sheet. A full Brute set makes you hit harder at the start of every wave; four Sentinel pieces stretch your reach whenever monsters are on the field; a Lurker's crits leave poison behind. The capstone is the reason to finish a set rather than dabble in two.

### 2.1 Amendment to the approved vocabulary (why)

The approved vocabulary contained `on_hurt_shield`, `low_hp_state` and `on_kill_heal`. **Nothing in the shipped game damages the Hero**: `design/gdd/damage-status.md` states incoming hero damage is "scaffolded but has no active sources at MVP", and the only production emitter of `hero_damage_taken` is the QA-only kill-hero key (`the_gap.gd`). The first two were replaced on that basis at the design stage (user decision: "swap to live triggers"). During spec writing the same reasoning was found to apply to `on_kill_heal` (healing an unhurtable Hero is a no-op), so **Troll's capstone is changed from `on_kill_heal` to `on_kill_stack_buff`**. This applies the user's own decision consistently; it is flagged here so it can be vetoed at spec review. The three dormant types are listed under §10 for when a hero-damage source exists.

Related finding (not fixed here): `armor`, `max_hp`, `lifesteal` and the elemental resists granted by gear and set stat bonuses have no live effect for the same reason. Tracked in §11.

## 3. Detailed Rules

### 3.1 Vocabulary

Exactly five effect types. Each effect is `{name: String, type: StringName, params: Dictionary}`.

| Type | Trigger | Params | Behaviour |
|---|---|---|---|
| `on_kill_stack_buff` | `monster_died`, `monsters_died_batch` | `stats: {StringName: float}` per stack, `max_stacks: int`, `duration: float` | Each **direct kill** (§3.4) adds one stack (a batch adds one per qualifying entry). Modifier = `stats * stacks`. Every qualifying kill refreshes the expiry timer for the whole stack; on expiry all stacks drop. |
| `on_crit_status` | `hero_auto_attacked`, `hero_skill_attacked` with `is_crit` | `effect_type: "burn"\|"poison"`, `effect_value: float`, `effect_duration: float` | On a crit hit, applies one DoT instance to `target_id` via `MonsterManager.apply_dot()`. Stacks with other instances (existing `ActiveStatusEffect` rule). |
| `on_wave_start_buff` | `wave_started` | `stats: {StringName: float}`, `duration: float` | Grants the modifier for `duration` seconds. Re-trigger refreshes, never stacks. |
| `on_skill_cast_buff` | `hero_skill_activated` | `stats: {StringName: float}`, `duration: float` | Grants the modifier for `duration` seconds on each cast. Re-cast refreshes, never stacks. |
| `phase_state` | `mission_phase_changed` | `stats: {StringName: float}`, `phases: Array[String]` | Modifier is active while the current phase name (a `WaveManager.Phase` key, e.g. `"WAVE_ACTIVE"`) is in `phases`. No timer. |

All `stats` values are **additive fractions** in Hero's existing additive bucket (`effective = (base + flat) * clamp(1 + additive, -0.75, 3.0)`, `hero.gd`), so `0.20` means +20%. Keys must be in `EquipmentBonuses.FAN_OUT_STATS`; `additive_bonus_total` is not permitted here.

### 3.2 Data: `EquipmentSetResource`

Add `@export var effects: Dictionary[int, Dictionary] = {}` mapping `pieces_required` to `{name, type, params}`. `validate()` gains: threshold is an int within `[2, member count]`; `name` non-empty; `type` in the vocabulary; `params` match that type's schema (required keys present, unknown keys rejected, types correct, numeric values > 0, `stats` keys in `FAN_OUT_STATS`, `phases` non-empty and each a known phase name, `effect_type` in `{"burn","poison"}`). `effects` may be empty (a set with no capstone stays valid). The stat `bonuses` are unchanged and remain required non-empty.

The convention "one capstone, at the top threshold" is enforced by the content test (§3.9), not the schema, so a future design can relax it without a migration.

### 3.3 `SetEffectResolver` (pure, static)

New `src/core/equipment/set_effect_resolver.gd`, `class_name SetEffectResolver`, `extends RefCounted`, static-only, no state, no signals, no autoload access beyond `GGameDataRegistry` (same access pattern as `EquipmentBonuses`).

- `active_effects(slot_contents: Array[Dictionary]) -> Array[Dictionary]`: uses `EquipmentBonuses.set_piece_counts()`; returns one entry `{key, set_id, threshold, name, type, params}` per effect whose threshold is met. `key` is `&"<set_id>:<threshold>"`.
- `effects_for_set(set_id: StringName) -> Dictionary[int, Dictionary]`: the set's declared effects, for the info panel's muted (unearned) rendering.

The controller and the info panel both call the resolver, so the panel cannot disagree with combat. The player-facing description is built by `EquipmentInfoPanel.describe_effect()` (UI layer), not the resolver.

### 3.4 `SetEffectController` (node under Hero)

New `src/core/equipment/set_effect_controller.gd`, added as a child node `SetEffectController` in `Hero.tscn` (no `#` comments inside the `.tscn`). It resolves its Hero as `get_parent() as Hero`.

- **Lifecycle**: connects in `_ready()` and disconnects in `_exit_tree()` (ADR-0001 Rules 6/7). Always connected: `equipment_slot_changed`, `item_rune_imbued` (both rebuild the active list). Trigger signals (`wave_started`, `hero_skill_activated`, `monster_died`, `monsters_died_batch`, `hero_auto_attacked`, `hero_skill_attacked`, `mission_phase_changed`) are connected always and cheaply early-return when no matching effect is active, matching the tolerant-subscriber style already in `hero.gd`.
- **Rebuild**: `_rebuild()` calls `SetEffectResolver.active_effects(EquipmentBonuses.equipped_contents())`. Effects no longer present have their modifier cleared immediately and their timer/stacks discarded; effects newly present are initialised (a `phase_state` effect is evaluated against the last seen phase at once). Effects present before and after keep their timers and stacks.
- **Timers**: the controller owns all remaining-duration state in `_process(delta)` (processing is enabled only while a timed effect is live). Pausing therefore pauses buffs. Hero never sees durations.
- **Modifier keys**: each effect owns exactly one modifier on Hero, keyed by its `key`.
- **Direct kill** (used by `on_kill_stack_buff`): a `MonsterDiedEvent` counts if `kill_source != "wave_end"` and the distance from Hero to `world_position` is within Hero's effective `attack_range` (the same inner band as kill XP). This rule is exposed as a new `Hero.is_direct_kill(payload) -> bool`, and `_resolve_kill_xp_band()` is changed to call it for its inner-band comparison (the early `wave_end` return stays, since the outer band still needs it) so the rule lives in one place (the `wave_end` filter has already been a review finding once). XP behaviour is unchanged.
- **Crit status**: on a crit event, resolves MonsterManager through the `monster_manager` group (`MonsterManager.GROUP_NAME`), with a `monster_manager` field as a test seam, and calls `apply_dot(target_id, effect_type, effect_value, effect_duration)` on it. Both auto-attack and skill-hit events carry `is_crit`. The proc keys off the emitted crit flag, before Damage & Status rolls evasion, so an evaded crit can still proc (see §11).
- **Cascade**: the controller emits no EventBus signals, so it adds no cascade depth.
- **Clearing**: the controller clears all modifiers on `hero_died`, on `mission_phase_changed` into `MISSION_COMPLETE`/`DEFEAT`, and in `_exit_tree()`.

### 3.5 Hero: transient modifier layer

Add to `hero.gd`:

- `var _effect_modifiers: Dictionary[StringName, Dictionary] = {}` (source key -> `{stat: additive}`) and a cached fold `_effect_additive: Dictionary[StringName, float]`, recomputed only on set/clear.
- `set_effect_modifier(source_key, stat_additive: Dictionary)`, `clear_effect_modifier(source_key)`, `clear_all_effect_modifiers()`.
- `get_effective_stat()` reads `additive = _additive_bonuses.get(stat, 0.0) + _effect_additive.get(stat, 0.0)`. Everything downstream (caps, curves, affinity) is unchanged.
- Never saved; not touched by `get_save_data()`/`restore_save_data()`. Cleared by `reset_to_defaults()` and `apply_placeholder_base_stats()` (both already reset transient state at mission entry).
- `_recompute_equipment_bonuses()` is untouched, so equipment changes cannot wipe a live buff.

### 3.6 MonsterManager: public DoT entry

Add `apply_dot(target_monster_id: int, effect_type: String, effect_value: float, effect_duration: float) -> void`, a thin public wrapper over the existing private `_apply_dot_effect()` (which already guards null/dead targets). MonsterManager joins group `monster_manager` in `_ready()`. `_on_tower_attacked_status` keeps calling the private form. No behaviour change for towers.

### 3.7 UI and localization

The equipment info panel's Set Bonuses section gains one line per set that has an effect: `Capstone (n pieces): <name> - <description>`. Earned uses the same styling as earned thresholds; unearned is muted. Description text comes from `EquipmentInfoPanel.describe_effect()` via new `strings.csv` keys, one template per type. Capstone `name` is rendered as-is, matching `display_name`'s convention. After editing `strings.csv`, run the editor-mode reimport before live verification (project gotcha). The item card and swap preview are unchanged (§10).

### 3.8 Persistence

None. Effects and their runtime state are derived from equipped items and live events.

### 3.9 Content invariants (enforced by a content test)

- Every set's `effects`, if any, has exactly one entry, at that set's highest `bonuses` threshold.
- The nine capstones in §4 are locked by exact type and params.
- Every effect validates.

## 4. Capstone Values (authoritative, first pass, unplaytested)

Scale references: existing tower DoTs are poison `0.08` over `4s` and burn `0.10` over `3s` (`blueprint_venomdart_turret.tres`, `blueprint_firebolt_turret.tres`), applied on every tower hit; the Hero versions apply on crits only and are set lower.

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

## 5. Formulas

- **Modifier fold**: `_effect_additive[stat] = sum over active modifiers of modifier[stat]`; consumed as `additive_total = _additive_bonuses[stat] + _effect_additive[stat]` inside the existing `clamp(1 + additive_total, -0.75, 3.0)`.
- **Kill stacks**: `stacks = min(max_stacks, stacks + qualifying_kills_in_event)`; modifier `= stats * stacks`; expiry resets to `duration` on any qualifying kill.
- **DoT**: unchanged, `tick_damage = effect_value * target.scaled_hp / num_ticks` (`MonsterManager._apply_dot_effect`).

## 6. Edge Cases

- **Unequip below threshold**: effect and its modifier are cleared on the same `equipment_slot_changed` rebuild; no stale buff.
- **Re-trigger**: timed buffs refresh, never stack (only kill stacks stack, capped).
- **Batched deaths**: `monsters_died_batch` counts qualifying entries individually, so large waves do not lose stacks (ADR-0001 Rule 5). Both signals are handled.
- **Force-cleared monsters** (`kill_source == "wave_end"`) never count.
- **Equip mid-phase**: `phase_state` evaluates against the last phase the controller saw. If the controller was created after the last phase event, it stays inactive until the next transition (accepted, §11).
- **Two capstones at once**: possible with roughly 6+ matched pieces across two sets; effects are independent (separate keys, separate timers).
- **Pause**: timers are `_process`-driven and freeze while paused.
- **Evaded or overkilled hits** on crit-status: the DoT wrapper guards null/dead targets.
- **Unknown type in data**: rejected by `validate()` at boot; the controller also ignores any unknown type defensively.
- **Stat clamp**: stacked modifiers are bounded by Hero's existing additive floor/cap.

## 7. Dependencies

`EquipmentSetResource` / `EquipmentBonuses` (set counting); `GGameDataRegistry` (sets); `Hero` (`is_direct_kill`, modifier layer, `get_effective_stat`); `MonsterManager` (`apply_dot`); `GEventBus` signals listed in §3.4; `WaveManager.Phase` key names; the equipment info panel; `strings.csv`.

## 8. Tuning Knobs

All values in §4 are data (`.tres`), not code. Knobs: per-stack stat, stack cap and window (Troll), DoT value/duration (Lurker, Goblin), buff stat/duration (Brute, Warlord, Iron, Reinforced), phase list and stat (Sentinel, Leather).

## 9. Acceptance Criteria

1. `EquipmentSetResource.validate()` accepts all nine capstones and rejects: unknown type, missing/extra param, non-positive value, unknown stat key, threshold out of range, empty `name`, empty `phases`, bad `effect_type`.
2. `SetEffectResolver.active_effects()` returns each capstone only at/above its threshold, keyed `<set_id>:<threshold>`, and returns `[]` with no set pieces.
3. `on_kill_stack_buff`: one direct kill adds one stack; a batch of N qualifying deaths adds N (capped); a `wave_end` kill and an out-of-range kill add none; stacks expire `duration` s after the last qualifying kill; each new kill refreshes.
4. `on_crit_status`: a crit auto-attack and a crit skill hit each apply one DoT of the configured type/value/duration to `target_id`; a non-crit applies none; a dead/unknown target is a no-op.
5. `on_wave_start_buff`: `wave_started` grants the modifier for `duration`; a second `wave_started` refreshes rather than stacks; expiry clears it.
6. `on_skill_cast_buff`: same refresh/expiry behaviour on `hero_skill_activated`.
7. `phase_state`: active only while the phase name is in `phases`; cleared on transition out; applied immediately on equip when already in a listed phase.
8. Unequipping a piece below a threshold clears that effect's modifier immediately, and re-equipping restores it on the next trigger.
9. `Hero.get_effective_stat()` reflects modifiers, honours the additive floor/cap, and is unaffected by `_recompute_equipment_bonuses()`; modifiers are absent from `get_save_data()` and cleared by `reset_to_defaults()`.
10. `Hero.is_direct_kill()` matches the previous inline XP rule exactly; existing kill-XP tests pass unchanged.
11. `MonsterManager.apply_dot()` produces the same `ActiveStatusEffect` as the tower path; existing tower-status tests pass unchanged.
12. The controller emits no EventBus signals and disconnects every subscription in `_exit_tree()`.
13. The info panel shows a Capstone line per set with an effect, earned vs muted by piece count, with translated text (no raw keys after reimport).
14. Content test locks all nine capstones and the one-capstone-at-top-threshold rule.

## 10. Out of Scope

- **Dormant effect types** for when a hero-damage source exists: `on_kill_heal`, `on_hurt_shield`, `low_hp_state`. Designed but deliberately not built.
- Effect gain/loss lines in the swap preview (`preview_swap()` reports stats only).
- Effects at non-top thresholds, per-effect UI icons or HUD buff indicators, VFX and audio for procs (worth a follow-up; an active-buff HUD is the obvious next step).
- Any change to Hero's incoming-damage pipeline or to which entities can damage the Hero.

## 11. Open Questions

- **Inert defensive stats**: `armor`, `max_hp`, `lifesteal`, elemental resists (from gear, runes and set bonuses) do nothing while the Hero cannot be damaged. Needs a design decision on whether/when monsters can hurt the Hero; outside this spec.
- **Evaded crits**: crit-status keys off the emitted crit flag, before Damage & Status rolls evasion. If that feels wrong, move the trigger to the post-mitigation `monster_damage_taken` (verify its payload carries a crit flag and source).
- **Controller created after the last phase event** leaves `phase_state` inactive until the next transition. If this proves real, add a phase getter on WaveManager for the controller's initial read.
- **Cross-set stacking** remains open (see `design/balance/equipment-set-bonuses.md`); top-threshold-only capstones limit it but do not remove it.
- All §4 numbers are first-pass and unplaytested.
