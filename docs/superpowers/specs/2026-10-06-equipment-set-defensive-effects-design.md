# Equipment Set Defensive Effects (Second-Tier Set Effects)

**Date**: 2026-10-06
**Status**: Approved by the user 2026-10-06 and implemented the same day (live-verified: shield, kill heal, low-HP state, info panel). Scope decision made by the user in chat: "Add as 2nd-tier effects" (keep all nine capstones; give defensive sets a second effect at a lower threshold).
**Scope**: Builds the three effect types that `2026-09-25-equipment-set-effects-design.md` §10 designed but shelved because nothing could damage the Hero: `on_kill_heal`, `on_hurt_shield`, `low_hp_state`. Hero damage has since shipped (`3f562cd`..`2693b97`: elite and boss telegraphed attacks, armor/resist mitigation in Damage & Status Rule V), so all three now have live triggers. Three sets gain one **second-tier effect** each, at a threshold below their capstone. Capstones and stat bonuses are unchanged. Values are authoritative in §4; `design/balance/equipment-set-effects.md` is updated as the tuning mirror.

## 1. Overview

The capstone system (`SetEffectResolver`, `SetEffectController`, the Hero transient modifier layer, `effects` on `EquipmentSetResource`) already supports any number of effects per set, keyed by threshold. Only two things hold one-per-set in place: a content test (`test_every_set_has_exactly_one_capstone_at_its_top_threshold`) and the info panel's "Capstone" label. This spec relaxes the convention to "one capstone at the top threshold, plus at most one second-tier effect at a lower threshold", adds the three types to the vocabulary, and adds two small Hero hooks (a heal entry and a damage-absorb layer) that the controller drives.

## 2. Player Fantasy

The tanky families finally feel tanky. Troll gear knits you back together as you cut through a wave; Brute plate shrugs off the next blow after a big hit lands; a Reinforced fighter gets harder to kill the closer they are to dying. Committing two or four pieces to a defensive set now buys survival against elites and bosses, not just a bigger HP number.

## 3. Detailed Rules

### 3.1 Vocabulary additions

Three new types join the five in the 2026-09-25 spec §3.1. Same shape: `{name: String, type: StringName, params: Dictionary}`.

| Type | Trigger | Params | Behaviour |
|---|---|---|---|
| `on_kill_heal` | `monster_died`, `monsters_died_batch` | `heal_fraction: float` | Each **direct kill** (`Hero.is_direct_kill()`, same rule as `on_kill_stack_buff`) heals `heal_fraction` of the Hero's effective `max_hp`. A batch heals once per qualifying entry. Clamped at max HP. |
| `on_hurt_shield` | `hero_damage_taken` with `amount > 0` | `shield_fraction: float`, `duration: float`, `cooldown: float` | Grants a damage-absorbing shield of `shield_fraction` x effective `max_hp` for `duration` seconds. Cannot re-trigger until `cooldown` seconds after the last grant. The shield never absorbs the hit that triggered it (§3.4). Re-grant replaces (never stacks). |
| `low_hp_state` | `hero_health_changed` | `hp_fraction: float`, `stats: {StringName: float}` | Modifier is active while `0 < current_hp / max_hp <= hp_fraction`, using Hero's cached max HP (`get_max_hp()`, the value the HP bar shows). No timer. |

`stats` follows the existing rule: additive fractions in Hero's additive bucket, keys in `EquipmentBonuses.FAN_OUT_STATS`, `additive_bonus_total` not permitted. **New restriction for `low_hp_state`:** `max_hp` is not a permitted stat key. Raising max HP would lower the HP fraction and could toggle the state on and off every frame.

### 3.2 Data and validation (`EquipmentSetResource`)

- `EFFECT_TYPES` gains the three types; `REQUIRED_PARAMS` gains `on_kill_heal: [heal_fraction]`, `on_hurt_shield: [shield_fraction, duration, cooldown]`, `low_hp_state: [hp_fraction, stats]`.
- Existing rules apply unchanged (unknown/missing params rejected, numeric values > 0, `stats` keys in `FAN_OUT_STATS`).
- New: `heal_fraction`, `shield_fraction` and `hp_fraction` must be `<= 1.0`; `low_hp_state.stats` must not contain `max_hp`.
- No schema change: `effects: Dictionary[int, Dictionary]` already holds several thresholds.

### 3.3 Convention change: one capstone plus at most one second-tier effect

The content test changes from "exactly one effect, at the top threshold" to:
- exactly one effect at the set's top `bonuses` threshold (the capstone), and
- at most one further effect, at a lower threshold that is also a `bonuses` threshold, and
- every effect validates.

The test that locks capstones by exact value keeps its nine entries; a new table locks the three second-tier effects in §4 the same way.

### 3.4 `SetEffectController` additions

- **`on_kill_heal`**: in the existing kill handlers, after the stack-buff loop, for each active `on_kill_heal` effect and each qualifying kill call `hero.apply_heal(roundi(heal_fraction * hero.get_effective_stat(&"max_hp")))`. Kills that don't pass `is_direct_kill()` heal nothing.
- **`on_hurt_shield`**: connect `hero_damage_taken`. On a hit with `amount > 0`, for each active shield effect off cooldown, schedule the grant with `call_deferred`. Reason: the controller is a child of Hero, so its `_ready()` connects before Hero's own and its handler runs first; granting synchronously would let the shield absorb the very hit that triggered it. The deferred grant calls `hero.set_shield(key, roundi(shield_fraction * max_hp))` and starts `duration` and `cooldown` timers in the existing `_process` timer bookkeeping. On expiry, `hero.clear_shield(key)`.
- **`low_hp_state`**: connect `hero_health_changed(current, max)`. Toggle the effect's modifier via the existing `set_effect_modifier`/`clear_effect_modifier`. `_rebuild()` evaluates it immediately from `hero.get_current_hp()` and `get_effective_stat(&"max_hp")`, so equipping at low HP applies it at once.
- **Clearing**: the existing clear paths (`hero_died`, mission end, `_exit_tree`, effect removed on rebuild) also clear shields (`hero.clear_all_shields()`) and cooldowns.
- The controller still emits no EventBus signals.

### 3.5 Hero additions (`hero.gd`)

- `get_current_hp() -> float`: public read of `_current_hp` (none exists today).
- `apply_heal(amount: int) -> void`: the body of today's `_on_hero_healed` (phase guard: COMBAT/INTERMISSION only; clamp at `_max_hp`; emit `hero_health_changed`). `_on_hero_healed` becomes a one-line call to it, so lifesteal healing and set healing share one path. No `hero_healed` emission from `apply_heal` (that signal is D&S's output, and the "must not re-emit" note stands).
- **Absorb layer**: `_shields: Dictionary[StringName, int]`, with `set_shield(key, amount)`, `clear_shield(key)`, `clear_all_shields()` and `get_total_shield() -> int`. In `_on_hero_damage_taken`, after the phase guard, absorb from shields first (in insertion order, removing emptied entries) and subtract only the remainder from HP. `hero_health_changed` is emitted only when HP actually changes. Shields are never saved and are cleared by `reset_to_defaults()` / `apply_placeholder_base_stats()`, like effect modifiers.
- Absorption happens after armor/resist mitigation (D&S has already reduced `amount`), so armor and shields stack multiplicatively, not additively. This is intended.

### 3.6 UI and localization

- Info panel Set Bonuses section: the line label depends on the threshold. Top threshold keeps `SET_EFFECT_CAPSTONE_LINE` ("Capstone (%d pieces): ..."). A lower threshold uses new `SET_EFFECT_TIER_LINE` ("Set effect (%d pieces): %s - %s"). Earned vs muted styling unchanged.
- New description keys:
  - `SET_EFFECT_ON_KILL_HEAL`: "Each nearby kill heals %d%% of max HP."
  - `SET_EFFECT_ON_HURT_SHIELD`: "When hit, gain a shield worth %d%% of max HP for %s (once every %s)."
  - `SET_EFFECT_LOW_HP_STATE`: "Below %d%% HP: %s."
- After editing `strings.csv`, run the editor-mode reimport before live verification (project gotcha).
- No HUD shield readout in this spec (§10). Absorbed hits still trigger the existing hit flash, because `hero_damage_taken` still fires.

### 3.7 Persistence

None. Same as capstones.

## 4. Second-Tier Values (authoritative, first pass, unplaytested)

Scale references: Hero base `max_hp` 500; set HP bonuses bring defensive builds to roughly 560-720. Elite/boss hits are 20-70 before armor (`bog_lurker_elite` 30, `forest_troll_elite` 45, `goblin_warlord_boss` 60, `iron_colossus_elite` 70, `rift_sentinel_boss` 20), every 2.2-4.0 s, and only while the Hero is in reach. HeroFeedback's low-HP vignette starts at 20% (`LOW_HP_FRACTION`).

| Set | Threshold | Name | Type | Params | Rough effect |
|---|---|---|---|---|---|
| Troll | 2 | Troll Blood | `on_kill_heal` | `heal_fraction 0.015` | ~8-9 HP per kill at 560 HP; a 15-kill wave returns ~130 HP, about three elite hits |
| Brute | 4 | Iron Hide | `on_hurt_shield` | `shield_fraction 0.08`, `duration 4.0`, `cooldown 8.0` | ~50-58 shield at 620-720 HP: absorbs most of the next elite hit, roughly every other hit |
| Reinforced | 2 | Last Stand | `low_hp_state` | `hp_fraction 0.30`, `stats {armor: 0.50, physical_attack: 0.20}` | Below 30% HP: +50% armor, +20% physical attack |

Why these three sets: Troll's capstone was originally meant to be `on_kill_heal` (2026-09-25 §2.1), so its lower tier restores that identity. Brute's bonuses are HP and armor, and its 4-piece tier is the armor tier. Reinforced is the plate-and-HP set whose capstone (Braced Stance) is not defensive. **Not chosen:** Iron (its identity is skill casting, and Steel Reflex already covers it) and Sentinel (range/CDR/resist, not a damage-taking set). Both were named in the scope question as candidates; this narrowing is flagged for review.

Brute's 4-piece tier also becomes reachable before its 5-piece capstone, so a 4/5 Brute player now has an effect too.

## 5. Formulas

- Heal per kill: `heal = roundi(heal_fraction * max_hp_effective)`, then `hp = min(hp + heal, max_hp)`.
- Shield: `shield = roundi(shield_fraction * max_hp_effective)`. Incoming mitigated hit `d`: `absorbed = min(d, total_shield)`; `hp -= d - absorbed`.
- Low-HP state: active iff `0 < hp / max_hp_effective <= hp_fraction`.

## 6. Edge Cases

- **Shield and the triggering hit**: the deferred grant means the triggering hit is never absorbed. A second hit in the same frame (two attackers) is also not absorbed, which is accepted: it is rare and errs toward the player taking damage.
- **Shield expiry mid-fight**: unused shield is simply dropped; no refund.
- **Overkill into a shield**: a hit larger than the shield breaks it and the remainder hits HP.
- **Lethal hit with a shield up**: absorbed first, so a shield can prevent death. Intended.
- **Heal at full HP**: clamps; no event spam (`hero_health_changed` still fires, matching today's heal path).
- **Heal outside COMBAT/INTERMISSION**: `apply_heal` no-ops (same guard as today).
- **Low-HP state at 0 HP**: excluded (`0 <`), so a dead Hero never shows the buff; death clears everything anyway.
- **Max HP changes while in low-HP state** (equipping HP gear): the state re-evaluates on the next `hero_health_changed` or rebuild; `max_hp` is not a permitted stat for the state itself (§3.1).
- **Unequip below the tier**: the effect, its modifier, its shield and its cooldown are cleared on the same rebuild.
- **Wave-end force-clears**: `kill_source == "wave_end"` never heals (direct-kill rule).

## 7. Dependencies

The 2026-09-25 capstone system (resolver, controller, modifier layer, `is_direct_kill`); Damage & Status Rule V (mitigation before `hero_damage_taken`); `hero_health_changed`; `Hero` (new `get_current_hp`, `apply_heal`, absorb layer); equipment info panel; `strings.csv`.

## 8. Tuning Knobs

All values in §4 are data (`.tres`). Knobs: `heal_fraction` (Troll); `shield_fraction`, `duration`, `cooldown` (Brute); `hp_fraction` and `stats` (Reinforced).

## 9. Acceptance Criteria

1. `validate()` accepts the three new effects and rejects: missing/unknown params, fractions `<= 0` or `> 1`, non-positive duration/cooldown, `max_hp` in `low_hp_state.stats`.
2. Content test: every set has exactly one effect at its top threshold and at most one more at a lower `bonuses` threshold; the nine capstones are unchanged; the three second-tier effects match §4 exactly.
3. `on_kill_heal`: a direct kill heals `roundi(0.015 * max_hp)`; a batch of N qualifying kills heals N times; a `wave_end` or out-of-range kill heals nothing; heal clamps at max HP; no heal in SCOUT.
4. `on_hurt_shield`: a hit grants the shield next frame, not absorbing the triggering hit; the next hit is absorbed up to the shield; the remainder reaches HP; no re-grant within `cooldown`; the shield expires after `duration`.
5. Hero absorb layer: shields absorb before HP; emptied shields are removed; `hero_health_changed` is not emitted when a hit is fully absorbed; shields are absent from save data and cleared by `reset_to_defaults()`.
6. `low_hp_state`: active at or below `hp_fraction`, inactive above it and at 0 HP; evaluated immediately on equip; cleared on unequip.
7. `apply_heal` is shared by D&S lifesteal (`_on_hero_healed`) and set healing; existing lifesteal/heal tests pass unchanged.
8. Info panel: capstones keep "Capstone (n pieces)"; second-tier effects show "Set effect (n pieces)", earned vs muted, with translated text.
9. The controller still emits no EventBus signals and disconnects everything in `_exit_tree()`.

## 10. Out of Scope

- HUD buff/shield indicators (the obvious follow-up; both shield and low-HP state are invisible except through the info panel and their effect).
- Proc VFX/audio for heals and shields.
- Second-tier effects for the other six sets.
- Effect lines in the swap preview.
- Any change to which monsters can damage the Hero or how hard.

## 11. Open Questions

- **Iron and Sentinel** were named as candidates in the scope question but are not given a second tier here (§4). Confirm or name a set to add.
- **HUD feedback**: without a shield indicator, a player may not notice Iron Hide working. If playtests say so, the follow-up is a small HUD buff row.
- **Shield vs. multiple attackers in one frame** (§6) errs toward damage; revisit only if it shows up in play.
- All §4 numbers are first-pass and unplaytested.
