# Hero Damage (Elite and Boss Attacks on the Hero)

**Date**: 2026-09-25
**Status**: Design approved by user in chat (threat scope, targeting, dodge rule, damage types, recovery, approach A, decomposition); Implemented (plan: `docs/superpowers/plans/2026-09-25-hero-damage.md`, 8 tasks); live verification pending.
**Scope**: Elites and bosses can hurt the Hero through a telegraphed, dodgeable attack. This spec covers the **simulation only**: attack logic in the Monster System, the Damage & Status incoming-damage pipeline, Hero recovery at wave clear, and data. The **visible wind-up indicator** is a separate follow-up spec (§10) and must land before playtesting. Builds on `design/gdd/hero.md` (Group 6 Hero Death, rule 24), `design/gdd/damage-status.md` Rule V, and `design/gdd/monster.md` Group 4.

## 1. Overview

Nothing in the shipped game damages the Hero. `damage-status.md` Rule V describes an incoming-damage pipeline but calls it scaffolding with no source; `damage_status.gd` has no handler for it, the `hero_incoming_damage` signal has no payload, and only the QA kill-hero key ever emits `hero_damage_taken`. As a result Hero armor, max HP, lifesteal and the elemental resists (from gear, runes and set bonuses) have no effect in play.

This spec gives the Hero a source of damage and finishes the pipeline:

1. Monster System: ELITE and BOSS monsters wind up and fire attacks at the Hero (bosses also keep attacking towers as today).
2. Event: `hero_incoming_damage` gains a Resource payload.
3. Damage & Status: implements Rule V (armor mitigation; elemental resist routing), then emits the existing `hero_damage_taken`.
4. Hero: existing HP handling and instant DEFEAT (Hero rule 24) are unchanged; Hero gains a partial heal at wave clear.

Everything downstream of `hero_damage_taken` (Hero HP, `hero_health_changed`, `hero_died`, DEFEAT, audio cue) already exists.

## 2. Player Fantasy and Pillar Check

The elite and boss waves stop being pure tower tests: the Hero has to be somewhere sensible. Standing in an elite's reach is a visible, avoidable risk (Pillar 1: difficulty must be diagnosable, preparation over reflexes), and armor, max HP, lifesteal and attack range become real answers to it (Pillar 2: everything connects, e.g. the Sentinel set's range buff becomes a defensive tool). There is **no randomness** in any hit: no crit, no variance, no accuracy roll.

## 3. Decisions (approved)

| Question | Decision |
|---|---|
| Who can hurt the Hero | ELITE and BOSS only; STANDARD never attacks (Monster rule 14 unchanged) |
| Targeting | Elites attack the Hero **only** (never towers). Bosses attack the **closest of Hero or tower** by Chebyshev cell distance; ties go to the tower |
| Dodge | Target locks at wind-up; the hit lands **only if the Hero is still within the attacker's range at fire time** |
| Damage types | Armor live now; payload carries `damage_type` (default `"physical"`), D&S routes fire/frost through the resist stat, **all authored attacks are physical this pass** |
| Recovery | Partial heal of max HP at each wave clear (first pass 25%); lifesteal remains the way to sustain beyond that |
| Approach | Extend the existing attack pass in `MonsterManager` (approach A); no new attack-system node |

## 4. Detailed Rules

### 4.1 Attack-capable monsters and data

`MonsterResource` (`src/core/monster/monster_resource.gd`) already carries `base_damage`, `base_attack_interval` and `boss_attack_range_cells`; validation only *requires* them for BOSS and does not forbid them on ELITE. This spec:

- Reuses those three fields for ELITE and BOSS **Hero** attacks (a boss deals the same `base_damage` to a Hero it deals to a tower). Field names are kept to avoid churn; the class doc comment and the `@export_group("BOSS Settings")` label are updated to say "attack-capable tiers (ELITE, BOSS)".
- Adds `@export var hero_attack_windup_seconds: float = 0.0`, the wind-up before a Hero-targeted attack fires, in seconds. `validate()` gains: for tier 1 or 2, if `base_damage > 0` then `base_attack_interval > 0`, `boss_attack_range_cells > 0` and `hero_attack_windup_seconds > 0` are required (an ELITE with `base_damage == 0` remains a valid non-attacker); STANDARD must have `base_damage == 0`. Existing BOSS requirements also gain `hero_attack_windup_seconds > 0`.
- The boss-to-tower wind-up (`BOSS_ATTACK_PREPARE_FRAMES = 4`, about 0.07 s) is **unchanged**. It is far too short to dodge, which is why Hero attacks use a separate seconds-based wind-up.

First-pass values (data in `assets/data/monsters/*.tres`; unplaytested):

| Monster | Tier | `base_damage` | `base_attack_interval` | `boss_attack_range_cells` | `hero_attack_windup_seconds` |
|---|---|---|---|---|---|
| bog_lurker_elite | 1 | 30 | 2.5 | 2 | 0.9 |
| forest_troll_elite | 1 | 45 | 3.0 | 2 | 1.0 |
| iron_colossus_elite | 1 | 70 | 4.0 | 2 | 1.2 |
| goblin_warlord_boss | 2 | 60 (existing) | 3.0 (existing) | 3 (existing) | 1.0 |
| rift_sentinel_boss | 2 | 20 (existing) | 2.2 (existing) | 2 (existing) | 0.8 |

STANDARD monsters keep all attack fields at 0.

### 4.2 Attack flow in `MonsterManager`

State added to `MonsterEntity`: `hero_windup_remaining: float` (seconds, 0 means no Hero wind-up in flight). The existing `boss_attack_cooldown_remaining` is reused as the shared attack cooldown for all attack-capable tiers. `boss_locked_target_id` gains a sentinel `HERO_TARGET_ID := -2` meaning "the Hero".

`MonsterManager` caches the Hero's grid cell from `hero_position_changed` (`_hero_cell: Vector2i`, initial `(-1, -1)`) and tracks `_hero_alive` (true on `wave_started`, false on `hero_died`). The cache is deliberately **not** cleared on mission or wave reset: Hero emits only when its cell changes, so clearing it would leave it unrefreshed.

A monster has **at most one wind-up in flight** (tower or Hero). Each physics frame, for every ACTIVE, non-DEAD monster of tier 1 or 2:

1. **Scan** (throttled by the existing `BOSS_SCAN_INTERVAL_FRAMES`), only when the cooldown is clear and no wind-up is in flight:
   - ELITE (with `base_damage > 0`): if `_hero_alive` and the Hero is within `boss_attack_range_cells` (Chebyshev distance between `_grid.world_to_cell(entity.global_position)` and `_hero_cell`), lock the Hero: `boss_locked_target_id = HERO_TARGET_ID`, `hero_windup_remaining = hero_attack_windup_seconds`, and emit `monster_hero_attack_winding_up(entity_id, windup_seconds)`.
   - BOSS: compute the closest tower (existing logic) and the Hero candidate (in range and `_hero_alive`). The Hero is chosen only when it is **strictly closer** than the closest tower; otherwise the existing tower path runs exactly as before. When no tower is in range but the Hero is, the Hero is chosen.
2. **Wind-up countdown** (Hero path): `hero_windup_remaining -= delta`. At 0, **re-check** `_hero_alive` and range from the monster's *current* cell to `_hero_cell`. If both hold, emit `hero_incoming_damage` (§4.3). Either way the cooldown restarts (`boss_attack_cooldown_remaining = base_attack_interval`), the lock clears, and `hero_windup_remaining = 0`. Out of range at fire time is a **whiff**: no damage, no event, cooldown still spent.
3. Monsters keep walking while winding up (existing rule for bosses). The attack pass runs before the movement pass, so a monster attacks on the frame it breaches (existing boss rule 19, now also for Hero attacks).

A DEAD monster is skipped, so a monster killed mid-wind-up never fires. `hero_died` clears every in-flight Hero wind-up.

### 4.3 The `hero_incoming_damage` event

`event_bus.gd` currently declares `signal hero_incoming_damage()` with no arguments. It becomes `signal hero_incoming_damage(payload: HeroIncomingDamageEvent)`. Only Damage & Status subscribes (it is undeclared in code today), so the arity change has no other consumers.

New Resource `src/foundation/event_bus/event_payloads/hero_incoming_damage_event.gd`, `class_name HeroIncomingDamageEvent`, `extends Resource` (Resource payload even though it has four fields, so new fields can be added later without another signature change):

- `@export var amount: float = 0.0` — raw damage before mitigation.
- `@export var damage_type: String = "physical"`.
- `@export var source_type: int = 0` — `0` = monster attack; `1` = status effect and `2` = environmental are reserved.
- `@export var source_entity_id: int = -1` — the attacking monster's entity id.

A second new event announces the telegraph: `signal monster_hero_attack_winding_up(entity_id: int, windup_seconds: float)`, emitted by `MonsterManager` when it locks the Hero (§4.2). It has **no subscriber in this spec**; it exists so the presentation follow-up (§10) and the tests can observe the wind-up without touching the attack logic. It is a cross-system event (Monster System to presentation and audio), so it belongs on the bus (ADR-0001 Rule 9).

### 4.4 Damage & Status: Rule V, implemented

`damage_status.gd` subscribes to `hero_incoming_damage` (added to `_ready()` and disconnected in `_exit_tree()`). It needs the Hero's armor and resists, so it receives a stat provider through **dependency injection** (matching `MonsterManager.set_swarm_renderer`): `set_hero_stats(provider: Object)`, where the provider exposes `get_effective_stat(stat: StringName) -> float`. Each mission root calls it once at assembly: `the_gap.gd` (which holds `_hero` and has a `DamageStatus` child in `the_gap.tscn` but no reference to it yet) gains `$DamageStatus.set_hero_stats(_hero)`, and `mission_scene.gd` gains `$GameplayRoot/DamageStatus.set_hero_stats(_hero)` (its `DamageStatus` node lives under `GameplayRoot` in `MissionScene.tscn`). With no provider set, armor and resists are treated as 0.

Mitigation by `damage_type`:
- `"physical"`: `effective = max(1, floor(amount × 100 / (armor + 100)))` (Rule V.1, coefficient `HERO_INCOMING_ARMOR_COEFFICIENT = 100.0`).
- `"fire"` / `"frost"`: `effective = max(1, floor(amount × (1 − clamp(resist, 0, 0.75))))` using `elemental_resist_fire` / `elemental_resist_frost`.
- Any other type: no mitigation, floored at 1.

D&S then defers one frame (`await get_tree().process_frame`, with `is_instance_valid(self)` immediately after, per Rule V.2) and emits `hero_damage_taken(effective, payload.source_type)`. Hero's existing `_on_hero_damage_taken()` applies it, including the phase guard (Rule 20: not attackable in IDLE_SANCTUARY, SCOUT or DEAD) and DEFEAT at 0 HP.

### 4.5 Hero recovery at wave clear

`hero.gd` already handles `wave_completed` (`_on_wave_completed`, for wave XP). It additionally heals `roundi(_max_hp × WAVE_CLEAR_HEAL_FRACTION)` through the existing `_on_hero_healed()` path so the phase guard and overheal clamp apply. `const WAVE_CLEAR_HEAL_FRACTION: float = 0.25` (tuning knob, first pass). No new revival path exists: a DEAD Hero is never healed (Hero rule 24).

## 5. Formulas

- **Physical mitigation**: `effective = max(1, floor(amount × 100 / (armor + 100)))`. Examples: 45 damage at armor 0 → 45; at armor 52 → `floor(45 × 100 / 152) = 29`; 70 damage at armor 52 → 46.
- **Elemental mitigation**: `effective = max(1, floor(amount × (1 − min(resist, 0.75))))`.
- **Range check**: `chebyshev(monster_cell, hero_cell) ≤ boss_attack_range_cells`.
- **Wave-clear heal**: `min(max_hp − hp, roundi(max_hp × 0.25))` via the existing clamp.

## 6. Edge Cases

- **Hero moves out of range during wind-up**: whiff (§4.2). This is the intended dodge.
- **Hero dies mid-wind-up or in the same frame as several hits**: `hero_died` clears wind-ups; Hero's phase guard ignores further `hero_damage_taken` once DEAD, so `hero_died` fires once.
- **Monster dies or breaches mid-wind-up**: DEAD monsters are skipped (no fire); a breaching monster still fires on that frame.
- **Boss with Hero and tower at equal distance**: tower wins (existing behavior preserved).
- **Stale Hero cell**: `hero_position_changed` is deferred and cell-granular, so the cache can lag by one frame or one cell; accepted.
- **`MonsterManager` created after Hero's first position emission**: the cache would stay at its `(-1, -1)` sentinel until the Hero changes cell. The plan includes a live check of both mission scenes (the_gap and MissionScene) to confirm the ordering holds.
- **Many attackers**: no cap; the attack pass touches only tier 1-2 monsters with `base_damage > 0`.
- **Unknown `damage_type`**: no mitigation, floor 1 (documented, not an error).
- **Kiting**: a Hero held beyond an elite's 2-cell range is never hit by that elite; bosses (range 2-3) likewise. This is intended: positioning and attack range are defensive tools.

## 7. Dependencies

`MonsterManager`, `MonsterEntity`, `MonsterResource` and the five monster `.tres` files; `DamageStatus`; `Hero` (`_on_wave_completed`, `_on_hero_healed`, `_on_hero_damage_taken`, `hero_position_changed`); `event_bus.gd` plus `design/gdd/event-bus.md`; `the_gap.gd` and `mission_scene.gd` (one wiring line each). GDDs to update in the plan: `damage-status.md` (Rule V no longer scaffolding), `monster.md` (rules 14/15/16-19 and the field table), `hero.md` (recovery, Formula for incoming damage now live), `event-bus.md` (payload change and the new event). ADR-0001's event catalogue is amended for the two event changes.

## 8. Tuning Knobs

All monster numbers in §4.1 (data). `WAVE_CLEAR_HEAL_FRACTION` (0.25). `HERO_INCOMING_ARMOR_COEFFICIENT` (100). Elite range vs Hero attack range (kiting margin). Hero base HP (500, still the unbalanced stopgap).

## 9. Acceptance Criteria

1. `MonsterResource.validate()`: an ELITE with `base_damage > 0` requires interval, range and wind-up > 0; a STANDARD with `base_damage > 0` is rejected; a BOSS also requires `hero_attack_windup_seconds > 0`; an ELITE with `base_damage == 0` stays valid. All five shipped attackers validate.
2. An in-range Hero starts a wind-up on an eligible ELITE (emits `monster_hero_attack_winding_up`); an out-of-range or dead Hero does not; STANDARD monsters and ELITEs with `base_damage == 0` never do.
3. Fire time: Hero still in range → exactly one `hero_incoming_damage` with the monster's `base_damage`, `damage_type "physical"`, `source_type 0` and its entity id; Hero out of range → no event; the cooldown is spent either way, and no second wind-up starts before it elapses.
4. BOSS targeting: Hero strictly closer than the closest tower → Hero locked; tower closer or tied → the existing tower path runs unchanged (`monster_boss_test.gd` unchanged and passing); only Hero in range → Hero locked; only a tower in range → tower.
5. A monster killed mid-wind-up never fires; `hero_died` clears in-flight wind-ups.
6. D&S: physical mitigation matches §5 examples including the floor at 1; fire/frost use the capped resist; an unknown type is unmitigated; no stat provider means armor 0; `hero_damage_taken` is emitted one frame later with the mitigated amount and forwarded `source_type`.
7. Hero: `hero_damage_taken` lowers HP, DEFEAT at 0 (existing tests unchanged); the wave-clear heal restores `roundi(max_hp × 0.25)` clamped to max HP, and never heals a DEAD Hero.
8. Determinism: identical inputs always produce identical damage (no randomness anywhere in the path).
9. `hero_incoming_damage` has exactly one subscriber (D&S), with its subscription disconnected in `_exit_tree()` (ADR-0001 Rule 6).
10. Live check in both mission scenes (the_gap and MissionScene): an elite in range winds up and hits; walking out of range during the wind-up avoids it; armor visibly reduces damage; wave clear heals.

## 10. Out of Scope

- **Visible wind-up indicator** (a danger marker, attacker tint, or audio telegraph driven by `monster_hero_attack_winding_up`) and hit or whiff feedback. Follow-up spec; **required before playtesting**, since the dodge rule is unfair without it.
- Elemental attackers and content (the pipeline supports them; none are authored), status effects on the Hero, environmental damage, and any revival.
- A real `HeroResource` pipeline and a rebalance of Hero base HP or armor against the wave curve.
- Changing the boss-to-tower 4-frame telegraph or the tower-side damage rules.
- Any attack by STANDARD monsters.

## 11. Open Questions

- All numbers (attack damage, intervals, ranges, wind-ups, the 25% heal) are first-pass and unplaytested; Hero's 500 HP is still an unbalanced stopgap.
- Kiting margin: elite range (2 cells) versus Hero attack range (220 px, about 3.4 cells) lets a ranged build avoid elites entirely. Intended for now; revisit with playtest data.
- Whether a whiffed attack should get its own feedback event (deferred with the presentation follow-up).
- The boss-to-tower telegraph (4 frames) is not readable by a player; out of scope here but likely worth its own pass.
