# Hero System

> **Status**: Approved (`/design-review --depth lean` re-review 2026-08-28 — zero blocking items; fixed 3 stale cross-references found during the pass; remaining OQs are all legitimately deferred to playtest data/Art Bible, not design gaps. See `hero-review-log.md` for full history.)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-08-28
> **Implements Pillar**: Mastery-as-Vindication (The Architect-General)
> **Revision (2026-07-15)**: `/review-all-gdds` flagged Formula 4 as duplicating D&S's Formula D2 (double-multiplication risk — never marked superseded) and Formula 6 as using a stale pre-overkill-cap lifesteal basis vs. D&S's authoritative `absorbed`. Both fixed: Formula 4 now clearly marks itself as a full-pipeline reference, with Rule 6 (already correct) cited as the authoritative description of what Hero actually emits (`base_damage` unmultiplied); Formula 6 now uses `absorbed` (overkill-capped, matching D&S Rule VI.4) instead of raw `damage_dealt`, and renamed `effective_lifesteal`→`hero_lifesteal_fraction` to match the actual EventBus payload field. **Also found and fixed in the same pass** (not originally flagged, but the identical disease immediately adjacent): Formula 5 duplicated D&S's incoming-hero-damage armor formula without D&S's `max(1, ...)` floor guard, and its "Incoming damage" variable incorrectly cited "Formula 4 output" (Formula 4 is Hero's own outgoing damage — unrelated). All three formulas now explicitly split "what Hero computes/emits" from "what D&S computes," with Owner columns added. **`/review-all-gdds` re-run (same day) found the corresponding ACs weren't updated to match**: AC-06 still used the exact stale pre-overkill-cap lifesteal basis Formula 6's own revision note called out as the bug (its old numbers coincidentally landed at the overheal clamp ceiling, masking the error); the Tuning Knobs table still said `effective_lifesteal` instead of `hero_lifesteal_fraction`; AC-05 was missing the `max(1, floor(...))` guard added to Formula 5. All three fixed. **Also added OQ-9** (game-design-holism finding): Formula 2's Tower Affinity bonus rewards raw tower count with no cost/DPS weighting, in tension with Tower System's own cost-efficiency design — flagged as a tracked design question pending real playtest data, not redesigned unilaterally.

## Engine Risk Notes (Godot 4.6.2)

| API | Used for | Risk | Status |
|-----|---------|------|--------|
| `sqrt()` (Tower Affinity Formula 2) | Diminishing-returns bonus curve | LOW | **Already verified** — S4-12 session confirmed `sqrt()` works and `sqrtf()` does NOT exist in Godot 4.6.2 GDScript, via an actual engine run. |
| Shader uniform — Tower Affinity aura glow, low-HP vignette | VFX described in Visual/Audio Requirements | HIGH (Godot 4.6 glow rework) | **Partially characterized 2026-07-13** — live MCP test on the pinned 4.6.2.stable binary found no visible bloom on an overbright 2D element in the project's default (non-HDR) rendering path, and that enabling `Viewport.use_hdr_2d` (needed for glow to respond meaningfully) darkens the *entire* scene globally, not just the emissive element — confirmed independent of glow being on/off. This aura/vignette VFX will need `use_hdr_2d` opted in deliberately with a full scene brightness/contrast re-pass, not a simple glow-enable toggle. Still needs a follow-up test with real VFX assets before locking texture import presets — see `docs/engine-reference/godot/VERSION.md`. |
| Shader uniform — class palette hue rotation | Palette swap system (`assets/data/class_palettes.tres`) | LOW (shader texture-type changes were 4.4's risk area, not hue rotation on a uniform) | No verification needed unless palette texture sampling changes |

## Overview

The Hero System is the direct-action layer of Sanctuary Defenders: the player character the player moves, aims, and activates skills for in real-time during every mission. The hero is not optional — they are mandatory in all phases (SCOUT through OUTCOME), and boss fights can only be completed with the hero present, as hero attacks deal 150% damage to elite and boss enemies that towers cannot reliably remove alone. This design ensures that no tower-only strategy can win a mission; the player is always both the architect of the tower network and the general fighting alongside it.

Technically, the Hero System owns the hero's stats (health, damage, movement speed, cooldowns), the mapping of equipment affixes to those stats, real-time movement and collision, active skill activation, and the lifecycle events other systems subscribe to (health changes, death, position changes, skill use). It exposes its state changes exclusively through EventBus signals. It persists equipment loadout, tower mastery XP, and learned skill builds across sessions via Save & Persistence (restore_order 30). The hero's position, expressed as a world-space coordinate converted to grid cell via the Grid System's `world_to_cell()` function, is the spatial input that Tower Mastery uses to track proximity learning during missions.

## Player Fantasy

The hero is the one piece of your strategy that thinks. Towers are reliable but rigid — they do exactly what you designed them to do. The hero is your ability to be present in the moment: to read the field, improvise when the plan meets reality, and physically override a situation that static placement couldn't anticipate. The feeling is never "I am powerful." It is "I was the right person in the right place at the right time because I understood the battlefield" — and then, seconds later, "I somehow pulled that off."

At the same time, the hero is not separate from the tower strategy. The hero grows *through* it. Standing near a frost tower for three missions teaches you a frost skill. Running alongside your siege battery teaches you its targeting logic. One day you realise the synergy your equipment affix has with a skill your hero learned by proximity — and nobody told you that was possible; you discovered it by paying attention to where you stood. The hero is the Architect-General's education: a record, in lived skill, of how you chose to fight.

And sometimes the plan breaks. The boss is immune to fire and your entire kill corridor is built on fire towers. So you body-block. You drag the boss into the gap between lanes while your cooldowns reset, buying the ten seconds you need for the constellation bonus to proc. That moment — controlled desperation, solving a problem your past self created, with your own hands — is the hero's truest fantasy. Not the clean win, but the messy one. The one you weren't supposed to be able to pull off.

## Detailed Design

### Core Rules

#### Group 1: Stats

1. The hero has exactly **13 base stats**. Each has a floor of 0 and no hard ceiling unless noted. Equipment affixes, class perks, and skills modify these stats at the Sanctuary before a mission.

| # | Stat | Governs |
|---|------|---------|
| 1 | Health (HP) | Total hit points. Hero dies at 0 → DEFEAT immediately. |
| 2 | Physical Attack | Scales any ability whose damage_type is "physical", including auto-attack. Replaces the old "Damage" stat (Hero Combat & Stats Redesign, 2026-09-18). |
| 3 | Movement Speed | World-units per second, all directions. |
| 4 | Cooldown Reduction (CDR) | % reduction to skill cooldown durations. Cap: 75%. Does NOT affect auto-attack rate. |
| 5 | Crit Chance | Probability a hit applies the Crit Multiplier, via a diminishing-returns curve asymptotically approaching 85% (see Formulas) — no longer a flat 80% hard clamp. |
| 6 | Armor | Reduces incoming damage TO the Hero via a mitigation formula (see Formulas). Distinct from a monster's own Armor stat (design/gdd/monster.md), which reduces the Hero's outgoing Physical Attack damage instead. |
| 7 | Magic Attack | Scales any ability whose damage_type is fire/ice/poison/lightning/arcane. Replaces the old "Skill Power" stat (Hero Combat & Stats Redesign, 2026-09-18). |
| 8 | Attack Range | World-unit radius within which auto-attack acquires a target. |
| 9 | Elemental Resistances | Per-element % damage reduction TO the Hero (fire, frost, poison, lightning, arcane). Cap: 75% per element. Distinct from a monster's own elemental_resistances, which reduce the Hero's outgoing Magic Attack damage instead. |
| 10 | Lifesteal | % of auto-attack damage returned as HP. Cap: 40%. Cannot overheal. |
| 11 | Tower Affinity | % bonus to Physical Attack and Magic Attack per tower placed, using a square-root scaling curve (see Formulas). |
| 12 | Crit Multiplier | Damage multiplier when a crit is triggered, via a diminishing-returns curve. Base: 1.5× (was 1.75×). Cap: 3.5×. Equipment and perks add to the curve's raw input. |
| 13 | Luck | New stat (Hero Combat & Stats Redesign, 2026-09-18). Boosts monster drop-occurrence chance and contributes a secondary Crit Chance source, via its own diminishing-returns curve asymptotically approaching 35%. |

2. Effective stat resolution uses the additive-bucket model: `effective_stat = (base_stat + flat_bonus) × (1 + additive_bonus_total)`. All flat bonuses sum first, then all percentage bonuses are collapsed into a single multiplier. The additive total is clamped to [−0.75, +3.00].

#### Group 2: Auto-Attack

3. The hero auto-attacks without player input. One attack fires per attack cycle. Auto-attack rate is a fixed base value; CDR does not affect it.

4. Target priority (evaluated in order each cycle):
   - (1) The enemy closest to a GOAL cell (furthest along the active path) within Attack Range.
   - (2) If two enemies tie on path progress: the one with lower current HP.
   - (3) If still tied: first enemy in the internal enemy list.

5. Auto-attack always hits the current target. There is no miss chance. Dodge, if introduced, is resolved on the target's side.

6. On each swing the Hero System: (a) rolls crit against `hero_crit_chance`, (b) reads the target's archetype tags to determine `hero_bonus_tier: int` (0 = STANDARD, 1 = ELITE, 2 = BOSS), (c) resolves `crit_multiplier_effective` via `get_effective_stat(&"crit_multiplier")` — this already applies Formula 7's diminishing-returns curve (base 1.5×, curved bonus capped at +2.0×, hard ceiling 3.5×) internally, no separate base+bonus fold — and (d) emits `hero_auto_attacked` as a `HeroAutoAttackEvent` Resource with 6 fields: `base_damage`, `is_crit`, `target_id`, `crit_multiplier_effective`, `hero_lifesteal_fraction`, `hero_bonus_tier: int`. Actual damage arithmetic (tier multiplier, crit application, floor rounding) is performed by the Damage & Status System upon receiving this event — the Hero System does not resolve the final damage value itself.

7. A swing already in progress completes normally even if the hero moves out of range mid-animation.

#### Group 3: Skill System

8. The hero has **4 active skill slots** (A, B, C, D) and a dedicated **Ultimate slot** (U). All 5 are independent bindings.

9. Each active skill has its own passive slot pool (1–3 passive slots per skill, defined in skill data). Passive slots accept skill-modifier items.

10. The **Ultimate** is not a standalone skill. It is derived at adventure start from the combination of the 4 equipped active skills via a lookup table. Different combinations produce different Ultimates. When any active skill slot changes mid-adventure, the Ultimate recomputes immediately. The Ultimate has its own cooldown defined by its data entry.

11. Skills are **per-adventure**: they persist across all missions in a single playthrough and reset to empty on a new game.

12. CDR applies to active skill cooldowns: `effective_cooldown = base_cooldown × (1 − CDR_fraction)`. Minimum effective cooldown: **0.5 seconds** regardless of CDR.

#### Group 4: Tower-Synced Class System

13. The hero has no fixed class. Class identity is earned by accumulating proximity time near towers of a given type.

14. Proximity is measured via the Grid System's `world_to_cell(hero_world_pos)` call and Chebyshev distance. A tower of a given type contributes to proximity accumulation when it is within **3 cells** (Chebyshev) of the hero's current grid cell.

15. Proximity time **accumulates cumulatively across all missions in a playthrough** during WAVE_ACTIVE and INTERMISSION phases. Scout Phase proximity does not count. The unlock thresholds are:

| Unlock | Cumulative Time | Notes |
|--------|-----------------|-------|
| First class | 30 seconds | Achievable in 2–3 waves with deliberate positioning |
| Second class | 90 seconds | Requires multi-mission commitment |

16. When a class's time threshold is crossed, `hero_class_unlocked` is published to the EventBus (payload: `class_id: String`). The class is immediately available for designation but does not automatically overwrite the player's current Primary or Secondary choice.

17. **Class perks**: Each class has exactly two perks — a Primary Perk and a Secondary Perk.
   - A class designated as **Primary**: both Primary Perk and Secondary Perk are active.
   - A class designated as **Secondary**: Secondary Perk only is active.
   - All other unlocked classes: no perks active.

18. The player designates their Primary and Secondary class at Sanctuary between missions. Designations lock at the start of SCOUT Phase and cannot be changed mid-mission.

19. The player may hold any number of unlocked classes simultaneously but can only have one Primary and one Secondary active.

#### Group 5: Tower Affinity

20. Tower Affinity converts the number of live towers on the field into a bonus to the hero's Physical Attack and Magic Attack. It is recalculated whenever a tower is placed, voluntarily removed, or destroyed (triggered by `tower_placed`, `tower_removed`, and `tower_destroyed` EventBus events — not polled per frame).

21. The bonus uses square-root scaling (see Formulas). A hero with 0 towers placed has 0 affinity bonus regardless of the Tower Affinity stat value.

22. When the hero has a Primary class designated, **only towers whose archetype matches the Primary class contribute to the tower count**. If no Primary class is designated, all tower types count:

| Primary Class | Tower types that count |
|---|---|
| Warrior | Physical / melee towers |
| Archer | Ranged towers |
| Mage / Elemental | Elemental towers (fire, frost, acid, lightning, arcane) |
| Support / Engineer | Support and utility towers |
| No primary class | All tower types |

23. The full class list (all possible tower-synced classes and their perk definitions) is a separate design deliverable — the **class catalogue**. The Hero System GDD specifies the mechanics; the class catalogue specifies the content. The four archetypes above are the foundation-layer examples.

#### Group 6: Hero Death

24. Hero HP reaching 0 from any source triggers DEFEAT immediately. There is no respawn, revival item, or tower effect that can prevent this.

25. Lifesteal and healing skills apply before the HP-reaches-0 check; they cannot trigger on the killing hit to prevent it.

#### Group 7: Movement

26. The hero moves in continuous world space, omnidirectionally. Keyboard/Mouse is the primary input; gamepad is supported. Velocity: `velocity = direction.normalized() × movement_speed` (instantaneous — no acceleration curve for MVP; feel pass deferred to Polish phase).

27. Hero movement is blocked by `BLOCKED` cells and cells occupied by towers. The hero can traverse PATH, PLACEABLE (unoccupied), SPAWN, and GOAL cells freely.

28. Each physics frame, the Hero System calls `Grid.world_to_cell(hero_world_pos)` to determine the current grid cell. When the result changes from the previous frame (`prev_cell != current_cell`), `hero_position_changed` is emitted to the EventBus with `grid_position: Vector2i`. This resolves EventBus Open Question #5: per-cell-boundary emission with an O(1) guard is sufficient — no frame throttling needed.

#### Group 8: Hero Leveling

29. Hero Level is persistent across missions — part of the same persistent domain as equipment, tech tree, and menagerie state. It resets only on a full new-game/new-adventure reset, in lockstep with the Hero Skill Tree's own reset trigger. Surviving a DEFEAT does not reset level or XP.

30. XP sources: a monster kill within the Hero's current Attack Range grants full tier-based XP (STANDARD 5 / ELITE 15 / BOSS 100); a kill within 2x Attack Range but outside that inner band grants half that amount, floored; beyond 2x Attack Range grants none; a monster force-removed at wave-end (not a real kill) grants none. Wave completion grants a flat 25 XP; mission completion grants a flat 150 XP (withheld on DEFEAT).

31. The level curve is `xp_required(level) = floor(100 x 1.15^(level-1))` (see Formulas), capped at level 50. A single large XP grant may cross multiple level thresholds in one resolution; every crossed level's rewards apply independently, never just the first.

32. Every level grants +10 Max HP, +2 Physical Attack, +2 Magic Attack. Every 5th level additionally grants 1 Skill Tree point (credited to the archetype pool matching the Hero's current Primary class) and a small class-specific stat bonus, per Rule 33 — both skipped, not banked, for a qualifying level reached with no Primary class designated. Both the universal growth and the class bonus persist across missions, re-derived/re-applied from the persisted level and the persisted accumulated class-bonus total on every mission entry — never re-rolled or lost.

33. **Placeholder class-bonus mapping** (explicitly provisional — superseded whenever the real class catalogue, Rule 23, ships): Physical archetype -> +1 Physical Attack; Ranged archetype -> +0.5% Crit Chance; Elemental archetype -> +1 Magic Attack; Support archetype -> +1% CDR.

---

### States and Transitions

| Hero State | Active During | Entry | Exit |
|---|---|---|---|
| `IDLE_SANCTUARY` | SANCTUARY | Mission ends or game starts | SCOUT phase begins |
| `SCOUT` | SCOUT mission phase | `mission_phase_changed` → SCOUT | Timer expires or player confirms |
| `COMBAT` | WAVE_ACTIVE | `mission_phase_changed` → WAVE_ACTIVE | Wave cleared or `hero_died` fires |
| `INTERMISSION` | INTERMISSION | `mission_phase_changed` → INTERMISSION | Timer expires or player confirms |
| `DEAD` | DEFEAT | HP reaches 0 | Mission restart (SCOUT) resets hero |

Proximity accumulation is active only during `COMBAT` and `INTERMISSION`. Class designation is locked during `SCOUT`, `COMBAT`, and `INTERMISSION`.

---

### Interactions with Other Systems

| System | Direction | Data | Mechanism |
|---|---|---|---|
| **EventBus** | Hero → | `hero_auto_attacked`, `hero_health_changed`, `hero_died`, `hero_position_changed`, `hero_equipment_changed`, `hero_skill_activated`, `hero_skill_attacked`, `hero_class_unlocked`, `hero_xp_gained`, `hero_leveled_up` | Direct signal emission. Note: `hero_damage_taken` is owned by D&S (moved from Hero System per EventBus catalogue update). `hero_skill_attacked` added 2026-08-25 (`damage-status.md` Rule IX/Formula D7, closes `TD-hero-001`) — a distinct event from `hero_skill_activated`: the latter marks cast-start (Audio/HUD), the former marks a resolved hit on one target (one emission per target struck), the actual Damage & Status pipeline trigger. |
| **EventBus** | → Hero | `equipment_slot_changed`, `active_skill_equipped`, `ultimate_skill_changed`, `item_rune_imbued`, `mission_phase_changed`, `sanctuary_state_restored`, `tower_placed`, `tower_removed`, `tower_destroyed` | Signal subscriptions connected in `_ready()` |
| **Grid** | Hero → Grid | `world_to_cell(hero_world_pos)` per physics frame | Direct read API (Autoload call) |
| **Save & Persistence** | Bidirectional | `get_save_data()` / `restore_save_data()` / `reset_to_defaults()`; registers with `restore_order = 30` | Direct API call in `_ready()` |
| **Tower Mastery System** | → Tower Mastery | `hero_position_changed` drives proximity tracking for skill acquisition | EventBus subscription |
| **Damage & Status System** | → Hero | Processes incoming damage; applies armor reduction and status effects | EventBus (hero hit events) |
| **Hero Skill Build System** | → Hero | `active_skill_equipped`, `ultimate_skill_changed` update active slots and recompute Ultimate | EventBus subscription |
| **Mission HUD** | Hero → | Receives `hero_health_changed`, `hero_skill_activated` for real-time display | EventBus subscription |

## Formulas

### Formula 1: Effective Stat Calculation

Applies to all 13 stats. Flat bonuses resolve before percentage bonuses, which means flat affixes feel more impactful at low base values (early-game equipment matters). All percentage bonuses collapse into a single additive bucket to prevent multiplicative stacking spirals. For Crit Chance, Crit Multiplier, and Luck specifically, this formula's result becomes the "Raw" input to a further diminishing-returns curve (Formula 7) rather than a flat hard clamp — see that formula for the full mechanic.

```
effective_stat = (base_stat + flat_bonus) × (1 + additive_bonus_total)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base stat | `base_stat` | float | stat-dependent | Hero's unmodified stat from class/equipment baseline |
| Flat bonus | `flat_bonus` | float | −base_stat – unbounded | Sum of all flat +N bonuses from equipment affixes and class perks |
| Additive bonus total | `additive_bonus_total` | float | −0.75 – +3.00 | Sum of all additive % bonuses as decimals (e.g. +30% = +0.30); clamped |
| Effective stat | `effective_stat` | float | 0 – stat ceiling | Final resolved stat used by all game systems |

**Output range:** Floor: 0 (no stat goes negative). Ceiling per stat in Tuning Knobs. The additive cap of +3.00 means any stat can at most reach 4× its flat-adjusted base.

**Example (Physical Attack stat):**
```
base_physical_attack = 50, flat_bonus = +12 (equipment + class perk), additive_bonus_total = 0.45
effective_physical_attack = (50 + 12) × (1 + 0.45) = 62 × 1.45 = 89.9 → 90
```

---

### Formula 2: Tower Affinity Bonus

Converts Tower Affinity stat and live tower count into a bonus multiplier on Physical Attack and Magic Attack. Uses square-root scaling to reward early tower investment without creating a "place 30 towers" degenerate strategy.

```
tower_affinity_bonus = tower_affinity_stat × sqrt(qualifying_towers / TOWERS_AFFINITY_REFERENCE)

effective_physical_attack_final = effective_physical_attack × (1 + tower_affinity_bonus)
effective_magic_attack_final = effective_magic_attack × (1 + tower_affinity_bonus)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Tower affinity stat | `tower_affinity_stat` | float | 0.00 – 1.00 | Hero's Tower Affinity stat (0%–100%) |
| Qualifying towers | `qualifying_towers` | int | 0 – field max | Count of live towers matching the Primary class archetype; all towers if no Primary class |
| Affinity reference count | `TOWERS_AFFINITY_REFERENCE` | int | constant: 16 | Tower count at which the bonus equals the Tower Affinity stat face value |
| Tower affinity bonus | `tower_affinity_bonus` | float | 0.00 – 2.00 (clamped) | Fractional bonus; clamped at 2.00 |

**Output range:** At `TOWERS_AFFINITY_REFERENCE = 16`, a hero with 40% Tower Affinity placing 16 qualifying towers gains exactly +40% to Physical Attack and Magic Attack. Clamped at +200% maximum bonus.

**Example:**
```
tower_affinity_stat = 0.40, qualifying_towers = 20, TOWERS_AFFINITY_REFERENCE = 16
tower_affinity_bonus = 0.40 × sqrt(20/16) = 0.40 × 1.118 = 0.447
effective_physical_attack_final = 90 × 1.447 = 130
```

---

### Formula 3: Class Proximity Accumulation

Tracks cumulative time the hero spends near towers of a given type. Accumulated across all missions in a playthrough.

```
proximity_time[tower_type] += delta_time
    while chebyshev(hero_cell, nearest_tower_cell_of_type) ≤ CLASS_PROXIMITY_RADIUS
    and mission_phase ∈ {WAVE_ACTIVE, INTERMISSION}
```

Unlock condition:

```
class_unlocked[tower_type] = true  when proximity_time[tower_type] ≥ CLASS_UNLOCK_THRESHOLD
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Proximity time | `proximity_time` | float | 0 – unbounded | Cumulative seconds near towers of this type (per type, per playthrough) |
| Physics frame delta | `delta_time` | float | ~0.0167 | Godot `_physics_process` delta at 60 FPS |
| Hero cell | `hero_cell` | Vector2i | grid bounds | `Grid.world_to_cell(hero_world_pos)` |
| Proximity radius | `CLASS_PROXIMITY_RADIUS` | int | constant: 3 | Chebyshev cell radius for proximity accumulation |
| Unlock threshold | `CLASS_UNLOCK_THRESHOLD` | float | 30 / 90 (by tier) | Seconds required to unlock each class tier |

**Output range:** Binary unlock (bool). Accumulator is unbounded — it continues past the threshold to track mastery depth (usable by future Tower Mastery integration).

**Example (first class unlock):**
```
Mission 1: 12s near frost towers → proximity_time[frost] = 12
Mission 2: 22s near frost towers → proximity_time[frost] = 34 ≥ 30 → Frost class UNLOCKED
```

---

### Formula 4: Auto-Attack Damage (Full Pipeline — Reference Only, Split Ownership)

*(Corrected 2026-07-15 — flagged by `/review-all-gdds` as a double-multiplication risk. This formula previously read as if the Hero System computes and forwards the fully-multiplied `final_damage` shown below. It does not. Rule 6 (Group 2, above) is the authoritative description of what Hero actually emits: `HeroAutoAttackEvent.base_damage` = this formula's `effective_damage` term ONLY, with the elite/boss and crit multipliers left unapplied — Hero forwards `is_crit`, `crit_multiplier_effective`, and `hero_bonus_tier` as separate flags/values instead. The actual multiplication is performed by the **Damage & Status System**, which owns this arithmetic per its Formula D2 (`damage-status.md`, Pipeline III, steps 2–4) and owns the `hero_damage_bonus_multiplier` tuning constant (renamed below from this formula's old `elite_boss_multiplier` — same concept, same value, D&S is the single owner). This formula is retained here as a **full end-to-end reference** — useful for balance tuning to see the actual damage a player experiences across both systems — but it is not what Hero System code computes or sends. If Hero code ever computed and forwarded this formula's `final_damage` as `base_damage`, D&S's Pipeline III would apply the tier and crit multipliers a second time.)*

```
effective_damage      = [Hero System computes and emits this as `base_damage` — Formula 1 + Formula 2 output]
final_damage           = effective_damage × hero_damage_bonus_multiplier
                        × [crit_multiplier_effective if is_crit else 1.0]
                        [D&S computes this — see Formula D2, damage-status.md]
```

| Variable | Symbol | Type | Range | Description | Owner |
|----------|--------|------|-------|-------------|-------|
| Effective damage | `effective_damage` | float | 0 – unbounded | From Formula 1 + Formula 2 (after class perk and affinity). Sent to D&S as `HeroAutoAttackEvent.base_damage`, unmultiplied. | Hero System |
| Hero damage bonus multiplier | `hero_damage_bonus_multiplier` | float | 1.25 – 2.00 (default 1.50) | Applied if target tagged `[ELITE]` or `[BOSS]` (`hero_bonus_tier > 0`), else 1.0×. **Renamed from `elite_boss_multiplier`** — same value, owned and tuned by D&S (see `damage-status.md` Tuning Knobs), not Hero. Hero only reads the target's tags to set `hero_bonus_tier`; it does not apply this multiplier. | Damage & Status |
| Crit check | `is_crit` | bool | {0, 1} | `rand_float(0, 1) < effective_crit_chance`. Rolled by Hero, applied by D&S. | Hero rolls / D&S applies |
| Crit multiplier (effective) | `crit_multiplier_effective` | float | 1.5× – 3.5× | Hero's Crit Multiplier stat, already fully resolved via Formula 7's diminishing-returns curve (base 1.5× with a diminishing-curve bonus on top, hard ceiling 3.5×). **This redesign removed the old additive base+bonus fold** — `get_effective_stat(&"crit_multiplier")` returns this complete, ready-to-use multiplier directly; Hero forwards it as a single value and D&S applies it with no further folding. See Formula 7 for the full math and worked examples. | Hero System (Formula 7) / D&S applies |

**Output range:** Minimum 0. No hard cap on `final_damage` itself. Maximum crit multiplier: 3.5× (Formula 7's hard cap — base 1.5× plus a diminishing-curve bonus capped at 2.0×, never a flat addition).

**Example (elite hit, crit) — full pipeline result, spanning both systems:**
```
effective_damage = 90 (Hero computes, emits as base_damage)
hero_damage_bonus_multiplier = 1.5, is_crit = true (D&S applies)
crit_multiplier_effective = 2.5× (Hero resolves this via Formula 7 — Raw = 1.0 input, base 1.5× + curved bonus 1.0× = 2.5×, matching that formula's own worked example — and forwards the single ready-to-use value; D&S does no additional base/bonus fold)
final_damage = 90 × 1.5 × 2.5 = 337.5 → 337  (D&S computes this; Hero never sees this number)
```

---

### Formula 5: Armor Damage Reduction (Reference Only — D&S Owns Implementation)

*(Corrected 2026-07-15 — found while fixing Formula 4/6's ownership annotations, same disease: this formula duplicates the Damage & Status System's own incoming-hero-damage formula (`damage-status.md` Rule V) rather than deferring to it, and its "Incoming damage" variable wrongly cited "Formula 4 output" — Formula 4 is Hero's own OUTGOING auto-attack damage against monsters, not an incoming source. D&S's Rule V computes `effective_damage = max(1, floor(incoming × (100 / (hero_armor + 100))))` on the `hero_incoming_damage` event (scaffolding only at MVP — no active damage source exists yet) and emits `hero_damage_taken`; Hero System applies the result to its own HP but does not compute the reduction itself. D&S's version also has a `max(1, ...)` floor (no hit can be fully negated) that this formula previously omitted. Uses an asymptotic coefficient formula — armor approaches but never reaches 100% reduction. Prevents breakpoints where small armor increments produce outsized damage reduction.)*

```
effective_damage_taken = max(1, floor(incoming_damage × (ARMOR_COEFFICIENT / (armor + ARMOR_COEFFICIENT))))   [D&S computes this — Rule V, damage-status.md]
```

| Variable | Symbol | Type | Range | Description | Owner |
|----------|--------|------|-------|-------------|-------|
| Incoming damage | `incoming_damage` | float | 0 – unbounded | Raw damage from a `hero_incoming_damage` event (any future monster/boss attack source — scaffolding only, no active source at MVP). **Not** Formula 4's output — Formula 4 is Hero's outgoing damage, unrelated to this formula. | Attack source (future) |
| Armor | `armor` | float | 0 – 500 (soft cap) | Hero's effective armor stat | Hero System |
| Armor coefficient | `ARMOR_COEFFICIENT` | float | constant: 100 | Armor value at which the hero takes exactly 50% damage | Hero System (tunable, D&S reads it) |
| Damage taken | `effective_damage_taken` | float | 1 – incoming_damage | HP deducted from hero. Floored at 1 — armor cannot fully negate a hit. | Damage & Status |

**Reduction curve:**

| Armor | Damage taken % |
|-------|---------------|
| 0 | 100% |
| 100 | 50% |
| 200 | 33% |
| 300 | 25% |
| 500 | 17% |

**Example:**
```
incoming_damage = 270, armor = 120
effective_damage_taken = max(1, floor(270 × (100 / 220))) = max(1, floor(122.7)) = 122
```

---

### Formula 6: Lifesteal Healing

*(Corrected 2026-07-15 — flagged by `/review-all-gdds` as using a stale pre-overkill-cap basis. This formula previously computed healing from `damage_dealt`, the raw resolved damage before Monster System applies it to the target's HP — which can exceed the target's remaining HP on a killing blow (overkill). The actual, authoritative resolution is owned by the Damage & Status System (Rule VI, `damage-status.md`): D&S waits for `monster_hp_absorbed` from the Monster System, whose `absorbed: int` field is `min(amount_received, pre_hit_hp)` — the real HP removed, capped at what the monster had. Lifesteal off an overkill hit heals based on the monster's remaining HP, not the full (possibly much larger) damage number. Hero System does not compute `hp_recovered` itself at all — D&S computes `heal_amount` and emits `hero_healed`; Hero only applies the overheal clamp on receipt (Rule 6's sibling rule for `hero_healed` handling) and owns the `hero_lifesteal_cap` tuning constant. This formula is retained as a reference showing the actual healing math, corrected to the real basis and variable names.)*

```
heal_amount = floor(absorbed × hero_lifesteal_fraction)     [D&S computes this — Rule VI.4, damage-status.md]
hp_recovered = min(heal_amount, max_health − current_health) [Hero applies the overheal clamp on hero_healed receipt]
```

| Variable | Symbol | Type | Range | Description | Owner |
|----------|--------|------|-------|-------------|-------|
| Absorbed damage | `absorbed` | int | 0 – target's pre-hit HP | Actual HP removed from the target, overkill-capped: `min(amount_received, pre_hit_hp)`. Computed by Monster System, emitted in `monster_hp_absorbed`. **Replaces the old `damage_dealt` basis**, which used the uncapped raw damage number and over-healed on overkill hits. | Monster System computes / D&S consumes |
| Lifesteal fraction | `hero_lifesteal_fraction` | float | 0.00 – 0.40 | Hero's Lifesteal stat, clamped at `hero_lifesteal_cap = 0.40` (Hero-owned tuning knob). Forwarded to D&S in `HeroAutoAttackEvent.hero_lifesteal_fraction`, cached in D&S's `_lifesteal_pending` until the deferred `monster_hp_absorbed` arrives. **Renamed from `effective_lifesteal`** — same concept, matches the actual EventBus payload field name. | Hero System |
| Heal amount | `heal_amount` | int | 0 – `absorbed` | `floor(absorbed × hero_lifesteal_fraction)`. Suppressed (no `hero_healed` emitted) if 0. | Damage & Status |
| HP recovered | `hp_recovered` | float | 0 – `max_health − current_health` | HP actually added to the hero; cannot overheal. Applied by Hero System on `hero_healed` receipt. | Hero System |

**Defensive guard on `hero_healed` receipt** *(added 2026-07-15d — `/review-all-gdds` 5th pass)*: if `state == DEAD` when `hero_healed` is received, Hero System discards the event — no HP change, no visual/audio. D&S's own Rule VIII (`damage-status.md`) is verified to prevent a stale post-death heal from ever being emitted in the first place (clears `_lifesteal_pending` synchronously on `hero_died`), so this guard should never trigger in practice — it exists as defense-in-depth against a future refactor of either system's timing silently reopening the race, consistent with the `is_instance_valid` / zero-damage / sentinel guards used elsewhere across these GDDs for "should never happen but cheap to check" conditions.

**Example:**
```
A hero lands a killing blow: raw resolved damage = 270, but the target only had 180 HP remaining.
absorbed = min(270, 180) = 180 (Monster System caps it — this is the overkill case Formula 6 previously got wrong)
hero_lifesteal_fraction = 0.20
heal_amount = floor(180 × 0.20) = 36 HP (NOT 54 — the old formula would have used the full 270 raw damage: floor(270 × 0.20) = 54, over-healing by 18 HP on every overkill hit)
hp_recovered = min(36, remaining HP headroom)
```

---

### Formula 7: Diminishing-Returns Curve (Crit Chance / Crit Multiplier / Luck)

Replaces a flat hard clamp for exactly these 3 stats — every other capped stat (Lifesteal, CDR, Elemental Resist) keeps a flat clamp.

```
Actual = (Raw × HardCap) / (Raw + ScalingConstant)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Raw stat | `Raw` | float | ≥ 0 | The stat's Formula 1 result, before this curve applies |
| Hard cap | `HardCap` | float | stat-specific | The value Actual asymptotically approaches but never reaches |
| Scaling constant | `ScalingConstant` | float | stat-specific | Raw value at which Actual reaches exactly half of HardCap |
| Actual | `Actual` | float | 0 – HardCap | The final, game-facing value |

| Stat | Hard Cap | Scaling Constant |
|------|----------|-------------------|
| Crit Chance | 85% | 0.5 |
| Crit Multiplier (bonus portion only — 1.5× base added on top) | 2.0× (so 3.5× total) | 1.0 |
| Luck | 35% | 0.5 |

**Example (Crit Chance, Raw = 0.5):** `Actual = (0.5 × 0.85) / (0.5 + 0.5) = 0.425 / 1.0 = 42.5%`

**Example (Crit Multiplier, Raw = 1.0):** `Actual = 1.5 + (1.0 × 2.0) / (1.0 + 1.0) = 1.5 + 1.0 = 2.5×`

Luck also contributes a secondary Crit Chance source: `effective_crit_chance = min(Actual(crit_chance) + Actual(luck), 0.85)` — both curved independently, then summed and re-clamped so a maxed build never exceeds the 85% ceiling from combining both sources.

---

### Formula 8: XP Required Per Level

```
xp_required(level) = floor(100 x 1.15^(level - 1))
```

| Variable | Range | Description |
|---|---|---|
| `level` | 2-50 | The level being leveled up TO |
| Result | int >= 100 | XP needed, accumulated from 0, to complete this level |

**Example:** `xp_required(10) = floor(100 x 1.15^9) = 351` (computed with double-precision `pow()`/`floor()`, matching this project's own runtime semantics — do not hand-round the intermediate `1.15^9`, since floor-boundary calculations like this one can differ by 1 from hand arithmetic due to floating-point representation)

---

### Formula 9: Kill XP Band Resolution

```
distance = hero.global_position.distance_to(death_position)
if distance <= attack_range:       kill_xp = tier_base_xp[tier]
elif distance <= 2 x attack_range:  kill_xp = floor(tier_base_xp[tier] x 0.5)
else:                                kill_xp = 0
```

Where `tier_base_xp = {STANDARD: 5, ELITE: 15, BOSS: 100}`.

---

## Edge Cases

**Stat Clamping**

- **If `additive_bonus_total` is driven below −0.75 by stacked negative affixes**: clamp to −0.75 (minimum multiplier 0.25×). A hero cannot reduce their own stat below 25% of the flat-adjusted base via additive debuffs alone.

- **If `(base_stat + flat_bonus)` is negative before the additive multiplier applies**: clamp the intermediate value to 0 before applying the multiplier. Without this guard, a large negative flat affix multiplied by a positive additive could produce a negative effective stat.

**Class System**

- **If the player has no classes unlocked when SCOUT begins**: both designation slots are empty, no class perks are active, and Tower Affinity uses all tower types. This is a valid early-game state; the UI shows empty slots without blocking SCOUT entry.

- **If a tower type contributing to a class threshold is destroyed before the threshold is reached**: the `proximity_time` accumulator is not rolled back. Accumulation pauses while no qualifying tower exists within range; it resumes when another tower of the same type is placed within 3 cells.

- **If the player attempts to designate the same class as both Primary and Secondary**: reject the assignment. The UI disables the "set as Secondary" option for whichever class is already set as Primary, and vice versa.

- **If a save is loaded referencing a `class_id` that no longer exists in game data**: restore the proximity accumulator as orphaned data (do not discard — supports content re-addition). Mark the class `UNKNOWN` internally. Clear any Primary/Secondary designation pointing to the unknown class, treating the slot as empty. Log a warning. Never block the load.

**Tower Affinity**

- **If `qualifying_towers = 0`**: `tower_affinity_bonus = 0` exactly. No division-by-zero risk (0 is the numerator). Hero deals unmodified Physical Attack and Magic Attack. Intentional by Rule 21.

- **If all qualifying towers are destroyed mid-wave**: Tower Affinity bonus drops to 0 immediately on the `tower_destroyed` event — same frame, no grace period. This is a meaningful consequence of aggressive monster play, not a bug.

- **If `tower_affinity_stat` resolves to 0 via Formula 1**: `tower_affinity_bonus = 0 × sqrt(anything) = 0` regardless of tower count. A build with no Tower Affinity investment gains nothing from tower count. Correct and intentional.

**Ultimate Recompute**

- **If all 4 active skill slots are empty**: the Ultimate slot is set to `EMPTY`. The U binding is inactive. No error.

- **If the 4-skill combination has no entry in the lookup table**: the Ultimate resolves to `NONE` gracefully. Every reachable combination in the skill catalogue must either have a table entry or explicitly map to NONE. A combination that causes a lookup panic is a content authoring error, not a runtime-defensible case.

- **If a skill is removed from an active slot mid-adventure**: the Ultimate recomputes immediately from the new combination. Any active Ultimate cooldown timer is discarded. The old Ultimate cannot be used after its source skill is removed.

**Hero Death**

- **If lifesteal would overheal the hero**: `hp_recovered` is clamped to `max_health − current_health` before `hero_health_changed` fires. The HUD never displays >100% HP.

- **If the killing hit is dealt by a DoT tick**: DEFEAT triggers identically. There is no grace window. Lifesteal does not apply to DoT (DoT ticks are not auto-attacks), but the death outcome is the same: `hero_died` fires and the mission ends.

**Movement**

- **If the hero occupies a cell that monsters need to route through**: the hero does not alter cell walkability. Monsters and the hero share world space and can occupy the same cell simultaneously. Combat is resolved by the Damage & Status System, not by blocking movement. Body-blocking is an intentional gameplay mechanic referenced in the Player Fantasy.

- **If the hero stands on a GOAL cell**: permitted by Rule 27. The hero on a GOAL cell does NOT trigger a breach event — breach is triggered only by a monster reaching a GOAL cell. Implementors must not use a generic "entity-on-GOAL" handler that would incorrectly fire on the hero.

## Dependencies

### Upstream Dependencies (systems the Hero System depends on)

| System | Dependency Type | What Hero needs from it |
|--------|-----------------|-------------------------|
| **EventBus System** | Infrastructure | All cross-system communication; Hero subscribes to 9 events, publishes 8 events (per the Interactions table above — count corrected 2026-08-28, was stale at 8/7 since `hero_skill_attacked` was added 2026-08-25 without updating this row). First Autoload — must exist before Hero calls `_ready()`. |
| **Grid System** | Infrastructure | `world_to_cell(hero_world_pos)` called every physics frame for position tracking. Direct read API (Autoload). |
| **Save & Persistence System** | Infrastructure | Hero implements `get_save_data()`, `restore_save_data()`, `reset_to_defaults()` and registers with `restore_order = 30`. Second Autoload — must exist before Hero's `_ready()` calls `register()`. |

### Downstream Dependents (systems that depend on the Hero System)

| System | What it needs from Hero | Constraint on Hero |
|--------|-------------------------|--------------------|
| **Tower Mastery System** | `hero_position_changed` events drive proximity tracking for skill acquisition | Hero must emit position events per cell-boundary crossing (not per-frame) to stay within EventBus budget |
| **Hero Skill Build System** | Hero exposes 4 active skill slots and the resolved Ultimate; listens to `active_skill_equipped` and `ultimate_skill_changed` | Hero must recompute Ultimate immediately when any slot changes |
| **Damage & Status System** | Outgoing: Hero emits `hero_auto_attacked` (`HeroAutoAttackEvent` Resource, 6 fields) — D&S resolves final damage and emits `monster_damage_taken`. Incoming: D&S emits `hero_healed` (lifesteal) and `hero_damage_taken` (armor-reduced incoming); Hero System applies both. | Hero must emit the full 6-field `HeroAutoAttackEvent` payload. Hero owns lifesteal clamping (`hero_lifesteal_cap=0.40`) and overheal clamping; D&S owns the heal-amount calculation. |
| **Mission HUD** | Displays hero HP, skill cooldowns, active class — subscribes to `hero_health_changed`, `hero_skill_activated`, `hero_class_unlocked` | Hero must emit complete, accurate payloads on every HP change |
| **Equipment Forge System** | Reads hero equipment loadout and perk structure to offer relevant forge options | Hero's equipment state must be accurately serialized via Save & Persistence |
| **Tower Mastery System** (secondary) | `hero_class_unlocked` event — Tower Mastery may gate certain skill unlocks behind class ownership | Hero's class unlock event must carry the `class_id` string |

### Notes

- `hero_class_unlocked` is catalogued in `event-bus.md` (see OQ-4 for a residual payload-signature mismatch between the catalogue row and the shipped signal — not an "unadded event" gap, that part is stale and superseded).
- The Hero System and Tower Mastery System share the same proximity mechanic but serve different purposes: proximity → class identity (Hero System) vs proximity → skill acquisition (Tower Mastery System). These two systems must agree on the `CLASS_PROXIMITY_RADIUS` constant (3 cells) to avoid conflicting proximity radii.
- Dependencies on **Inventory System** and **Equipment Forge System** are soft: Hero reads equipment state but does not call those systems directly — state flows through `equipment_slot_changed` EventBus events.

## Tuning Knobs

| Parameter | Default | Safe Range | Too High | Too Low |
|---|---|---|---|---|
| Hero base health | (TBD at production) | 100–500 | Hero survives everything; DEFEAT feels impossible | Hero dies to 1–2 hits; DEFEAT feels punishing rather than meaningful |
| Hero base damage | (TBD at production) | 20–100 | Hero trivialises elites/bosses without tower support | Hero contribution feels irrelevant vs towers |
| Hero movement speed | (TBD at production) | 100–400 world units/sec | Hero crosses the field instantly; positioning decisions lose meaning | Hero too slow to plug gaps; body-blocking becomes impossible |
| Attack range | (TBD at production) | 60–180 world units | Hero can attack from across the field; tactical positioning irrelevant | Hero must enter melee range; high-damage enemies feel impossible |
| `CLASS_UNLOCK_THRESHOLD` — first class | 30 seconds | 15–60 | Class identity appears too late to matter per mission | Class unlocks in the first wave from any passing proximity |
| `CLASS_UNLOCK_THRESHOLD` — second class | 90 seconds | 60–180 | Second class effectively locked to extremely dedicated players | Second class unlocks in one mission; too easy to stack |
| `CLASS_PROXIMITY_RADIUS` | 3 cells (Chebyshev) | 2–5 | Hero barely needs to be near a tower; proximity is trivial | Hero must stand on the tower's cell; conflicts with combat movement |
| `TOWERS_AFFINITY_REFERENCE` | 16 towers | 8–24 | High tower counts needed for meaningful affinity bonus | Affinity maxes out at 8 towers; reward feels trivial |
| `CRIT_MULTIPLIER_BASE` | 1.5× | 1.5–2.5 | Crit builds feel overwhelmingly powerful vs non-crit | Crits feel like normal hits; crit_chance stat irrelevant |
| `ARMOR_COEFFICIENT` | 100 | 50–200 | Armor reduces damage steeply at low values; armor-stacking becomes dominant | Armor barely matters; survivability comes only from HP |
| `hero_lifesteal_cap` (`hero_lifesteal_fraction` ceiling) | 40% | 20–60% | Lifesteal sustain trivialises damage; hero is unkillable | Lifesteal stat has no observable impact on survivability |
| `effective_crit_chance` cap | 85% | 60–90% | High crit builds guarantee crits; variance disappears | Crit chance cap too low for crit-focused builds to feel distinct |
| CDR cap | 75% | 50–90% | Near-zero cooldowns; skill spam eliminates resource management | CDR affixes feel useless; skills feel too slow |
| Min effective cooldown | 0.5 seconds | 0.3–1.0 | Floor too high; CDR stops feeling useful before cap | Spammable skills with zero CDR; game becomes trivial |
| Tower affinity bonus cap | 200% (+2.00) | 100–300% | Tower-affinity builds dwarf all other build paths | Diminishing returns kick in too early; affinity feels like a minor bonus |
| Kill XP — STANDARD tier | 5 | 2–10 | Low-tier kills grant too little XP; grind feels endless | Early progression trivializes end-game; level cap reached too fast |
| Kill XP — ELITE tier | 15 | 8–25 | Elite kills feel unrewarding | Elite farming becomes dominant XP strategy |
| Kill XP — BOSS tier | 100 | 50–200 | Boss kills grant insufficient XP for their challenge | Boss grinding trivializes the progression curve |
| Kill XP — outer-band multiplier | 0.5× (floored) | 0.25–1.0 | Proximity doesn't matter; ranged builds get full XP from across the map | Too harsh; any miss punishes the player heavily |
| Kill XP — outer-band range | 2× attack_range | 1.5–3.0× | Outer band too wide; hero doesn't need to position tactically | Too narrow; ranged attacks almost never qualify for outer-band |
| Wave completion XP | 25 | 10–50 | Flat wave bonus feels negligible vs kill XP | Wave bonus trivializes kill-based progression; encourages tower-only play |
| Mission completion XP | 150 | 75–250 | Mission completion barely registers in level progression | Mission completion XP dominates; grinds out level too fast |
| Level curve base | 100 | 80–120 | Steep early curve; mid-game levels take forever | Early levels too cheap; endgame reached immediately |
| Level curve growth rate | 1.15× | 1.05–1.25 | Shallow scaling; levels never feel progressively harder | Exponential scaling makes late levels unreachable |
| Level cap | 50 | 25–100 | Level 50 reached trivially; endgame undefined | Level cap so high it's never reached; progression feels infinite |
| Per-level HP gain | +10 | +5–+20 | Hero never gains meaningful durability per level | Leveling trivializes early content due to survivability scaling |
| Per-level Physical Attack gain | +2 | +1–+5 | Physical builds scale weakly; damage per level feels irrelevant | Physical damage scales too fast; overshadows all other stats |
| Per-level Magic Attack gain | +2 | +1–+5 | Magic builds scale weakly; damage per level feels irrelevant | Magic damage scales too fast; overshadows all other stats |
| Skill Tree point interval | Every 5th level | Every 3rd–Every 5th | Skill tree fills too slowly; specialization feels locked in | Skill tree points come too fast; no meaningful build commitment |
| Class bonus grant interval | Every 5th level | Every 3rd–Every 5th | Class bonus applies too rarely; class choice feels irrelevant | Class bonus applies too often; bonus is negligible per instance |

**Note:** Hero base stat starting values (HP, damage, movement speed, attack range) are production-phase tuning decisions. These must be calibrated against the target wave difficulty curve defined in `design/gdd/game-concept.md` and will be set when the first playable mission is designed. Add them to `design/registry/entities.yaml` as constants once confirmed.

## Visual/Audio Requirements

### Event Feedback

| Event | VFX | Animation | Audio |
|---|---|---|---|
| **Auto-attack hit** | White impact flash on target, 2 frames (~33ms), 0.5× cell_size radius. One-shot at target position. No projectile trail. | 4-frame attack cycle on hero (wind-up → strike → follow-through → recover). Strike frame = hit event frame. | Short metallic tap, 3D positioned at target. Category: `SFX_Combat`. Sits below skill activations in mix. |
| **Critical hit** | Auto-attack flash + radial slash burst (4–6 lines, yellow-white, 6 frames, 1.5× normal flash size). Bold yellow-outlined damage number scales up to 120% then settles over 8 frames. | Same as auto-attack (hero animation unchanged). | Dedicated crit sound: normal impact + bright ringing overtone (metallic shatter / glass chime). 3D positioned at target. Category: `SFX_Combat_Crit`. 15–20% louder than normal hit. Overtone layer makes crits identifiable with eyes closed. |
| **Elite/boss hit** | Auto-attack flash with colored edge glow (class palette, or neutral white). 3 frames. Damage number at 110% scale, orange tint. If also a crit: crit VFX takes priority; orange tint applied to crit number outline. | None. | Normal hit + short low-frequency sub-thump (60–80 Hz, very short). 3D positioned at target. Category: `SFX_Combat`. |
| **Skill activation (A/B/C/D)** | Circular activation ring expands from hero feet, 1 cell_size radius, 8 frames (~133ms). Ring color = skill element (fire=orange-red, frost=ice-blue, poison=acid-green, lightning=electric-purple, arcane=magenta, physical=steel-grey). Skill icon flashes 3 frames at hero's HUD skill slot (UI-space). | 6-frame cast animation (arms raised / weapon flourish). Shared across all skills at MVP. Locks movement for duration (0.2–0.5s per skill data). | Layer 1: shared skill whoosh (2D stereo, always audible). Layer 2: per-element impact at AoE location, 3D positioned. Category: `SFX_Skill`. |
| **Ultimate activation (U)** | Full-screen white flash (15% opacity, 4 frames). Burst ring expands from hero to 3× cell_size radius over 12 frames. 12–16 motes drift outward, fade over 0.5s. Hero sprite briefly scales to 110% for 6 frames. Ring color = Primary class palette (or white). | Dedicated 10-frame Ultimate animation. Movement locked for duration. Auto-attack pauses. | Layer 1: power surge riser (0.3s, low-to-high sweep, 2D stereo, `SFX_Ultimate` — unique to Ultimates). Layer 2: per-Ultimate impact, 3D positioned. Layer 3: low-frequency rumble (0.2s). Loudest hero-originated sound; 30% above skill activations. |
| **Hero takes damage** | Hero sprite flashes red-white for 2 frames. 4–6 directional particles burst toward damage source, fade over 0.3s. If single hit > 25% max_health: flash extends to 4 frames + 2-pixel screen shake (6 frames, decaying sine). | 3-frame flinch recoil (opposite damage direction). Does NOT interrupt movement or auto-attack — cosmetic overlay only. | Short pain impact, 3D at hero. Category: `SFX_Combat_Hero`. Pitch varies ±5% per hit. Volume scales with damage proportion. |
| **Hero low HP (< 20%)** | Screen-edge dark red vignette (~15% inset from each edge), looping, pulses opacity 40%–70% on 1.5s sine cycle. Hero sprite desaturates 40% + slight red hue shift (shader uniform). **Primary signal — fully readable with audio muted.** | None. | Enhancement only: low heartbeat sound synced to vignette pulse (1.5s), 2D stereo, `SFX_UI`. Volume: 60% of normal hit. Fades in/out at HP threshold crossings. |
| **Hero death** | Hero flashes white (100%, 4 frames) then fades to 30% opacity over 12 frames. Shockwave ring expands to 2× cell_size, 16 frames. Screen desaturates to 60% over 0.5s. Low-HP vignette freezes at max opacity. | 12-frame death collapse animation. All inputs lock on HP = 0 frame. | Heavy resonant impact (3D at hero) + 0.5s descending minor tone (2D stereo, `SFX_Hero_Death`). All other combat SFX duck 40% for 1s. |
| **Class unlock** | Vertical light beam (class palette color, 2× hero height, 1.0s). 8–12 sparkle particles drift upward. Badge icon materializes with scale-up ease (0%→115%→100% over 8 frames). First unlock: beam 50% wider, 1.5s. | 6-frame power-up pose. Overlay track — does not interrupt combat. | Ascending 3-note major arpeggio chime (0.8s), 2D stereo, `SFX_UI_Progression`. Volume: 20% above combat to cut through wave chaos. |
| **Class perk active (mission start)** | Shimmer sweep up hero sprite over 12 frames (Primary class color). If both Primary + Secondary active: two sequential sweeps (0.3s gap). Perk name tooltip above hero (world-space, 2.0s auto-fades). | None (SCOUT idle state). | Soft activation hum (0.4s), 2D stereo, `SFX_UI`. Volume: 50% of normal hit. |
| **Tower Affinity bonus active** | Looping gold outline on hero sprite (1–2px). Opacity scales linearly with `tower_affinity_bonus`: 0.0 = invisible, 2.0 = 80% max. Shader uniform driven. Updates on `tower_placed`/`tower_destroyed`, not per-frame. | None. | None — passive persistent bonus; audio would cause listener fatigue. |
| **Lifesteal heal** | 3–5 green-white motes arc from enemy to hero over 0.3s (4–6px sprites). 2-frame green flash on hero on arrival. If heal pushes HP above 20%: vignette/tint fade out over 0.3s. | None. | Soft absorption chime (0.15s, single note), 3D at hero, `SFX_Combat_Heal`. Volume: 40% of normal hit. Audio cooldown: 0.3s between chime triggers (VFX still plays every proc). |

---

### Hero Idle Visual Identity

The hero must be identifiable within 0.2 seconds at full battlefield zoom. Three redundant signals ensure this: (1) a humanoid silhouette with visible weapon — asymmetric and character-shaped, distinct from tower geometry and monster organics; (2) a persistent bright green health bar always visible below the sprite (unique color vs. tower and monster bars); (3) a 2-pixel vertical idle bob on a 1.5-second cycle (towers are static; monsters use lateral sway — only the hero bobs). The hero sprite occupies approximately 1 cell_size footprint, matching small towers, but the silhouette differentiates them at a glance.

### Class Identity Display

**Palette shift:** Implemented as shader uniform swap. Single base spritesheet for all classes (silhouette and animation frames identical). Hue rotation and saturation adjustments per class defined in `assets/data/class_palettes.tres`. 0.2-second crossfade interpolation on any palette change. Persists across scene loads.

**Badge system:** 16×16 px source icon, rendered at 12×12 world-space. Anchored top-right of hero (+0.35 cell_size, −0.35 cell_size from center). Background tint = class accent color; icon in white. Both Primary and Secondary active: Primary badge top-right, Secondary badge top-left (mirrored). No badge if no class designated. Asset path: `assets/ui/class_badges/[class_id].png`. Foundation-layer required badges: `physical.png`, `ranged.png`, `elemental.png`, `support.png` — **corrected 2026-08-28** (`hero-class-catalogue.md`'s Naming Reconciliation finding): `class_id` is the raw archetype string the shipped `hero.gd`/`event-bus.md` actually use, not the flavor names (Warrior/Archer/Mage/Support) this list previously named; those remain the classes' `display_name` only, not their file-naming key.

### Art Bible Dependencies

> Requirements below cannot be fully specified until the art bible is approved:
> 1. Hero sprite pixel dimensions and proportions (requires cell_size reference and character scale standard)
> 2. Class palette lookup table values (requires master color palette and colorblind accessibility standards)
> 3. Damage number font, stroke weight, base size (requires UI typography standard)
> 4. Particle art style — behavior locked; visual style (pixel-hard, soft glow, hand-drawn) depends on art style guide
> 5. Blood/spark aesthetic on damage taken — violence tone decision (abstract sparks vs. stylized)
> 6. Post-processing parameters for low-HP vignette and death desaturation

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:hero` to produce per-asset descriptions, dimensions, and generation prompts from this section.

## UI Requirements

The Hero System has no HUD-chrome UI of its own — players do not click the hero, drag it, or
open a hero-specific menu screen at MVP. All hero-facing HUD elements (HP bar, skill buttons,
Ultimate button, low-HP vignette) are owned by the Mission HUD (`design/ux/mission-hud.md`),
which subscribes to Hero System events. Requirements listed here are forward specs: data that
must be available in event payloads for the Mission HUD to implement correctly, mirroring the
pattern already established in `monster.md`'s UI Requirements section.

### Data the Hero System Must Expose via Events

| UI Element (owned by Mission HUD) | Data source from Hero System | Event carrying it |
|---|---|---|
| Hero HP bar (Zone D) | `current_health: float`, `max_health: float` | `hero_health_changed` |
| Low-HP vignette (< 20% threshold) | Derived from `hero_health_changed` — HUD computes `current_health / max_health < 0.20` itself; Hero does not emit a separate threshold-crossing event | `hero_health_changed` |
| Skill buttons 1–4 cooldown fill (Zone D) | `skill_slot: int` (0-3), `cooldown_remaining: float`, `cooldown_max: float` | `hero_skill_cooldown_updated` — **wired 2026-07-08** (`TD-hero-003`, fixed): Hero broadcasts once per second for any of the 4 skill-slot timers currently running |
| Ultimate button "READY" state (Zone D) | Same mechanism as skill buttons — `cooldown_remaining == 0` for the ultimate's slot | `hero_skill_cooldown_updated`, `skill_slot = 4` (`Hero.ULTIMATE_SLOT_INDEX`) reserved for the Ultimate's own cooldown timer — **wired 2026-07-08** (`TD-hero-003`, fixed) |
| Ultimate activation trigger | *(reverse direction)* Mission HUD fires `hero_ultimate_activated` when the player presses the button; Hero System is the consumer, not the source — **wired 2026-07-08** (`TD-hero-003`, fixed): no-ops if no Ultimate is resolved or still on cooldown, otherwise starts the Ultimate's own cooldown Timer using its data-defined cooldown (`UltimateComboTable.ultimate_cooldowns`) — CDR does not apply here, per Rule 12's explicit "active skill cooldowns" scope. No effect resolution (same gap as skill activation — no consumer of the resulting effect exists anywhere yet). |
| Skill activation trigger | *(reverse direction)* Mission HUD fires `hero_skill_activated(skill_slot: int)` on button press; **payload mismatch flagged in `mission-hud.md` Open Question 2** — the shipped `hero_skill_activated` event currently carries `skill_id: String, target_position: Vector2`, not `skill_slot: int`. Must be resolved before Mission HUD's skill buttons can be implemented. |

### Hero-Owned World-Space Visuals (not Mission HUD chrome)

Some hero-facing visual feedback is **not** Mission HUD's responsibility — it renders directly
on the hero sprite in world-space and is fully specified in this GDD's Visual/Audio Requirements
section above, not delegated to a UI spec:

- **Tower Affinity bonus glow** (looping gold outline, opacity scales with `tower_affinity_bonus`) — driven by `tower_placed`/`tower_destroyed`, not a HUD element
- **Class palette shift** (shader uniform hue rotation) and **class badge** (top-right/top-left icon anchor) — both render on the hero sprite itself
- **Damage/crit/skill/death VFX** (flashes, particles, screen shake) — world-space and screen-space effects owned by this GDD, distinct from Mission HUD's floating damage numbers (D&S-owned, Pattern 8)

### No Hero Selection or Inspection UI

Unlike towers (which have a Contextual Info Panel, Pattern 2), the hero has no player-facing
inspection panel at MVP — there is no "click the hero to see stats" interaction. If a future
Sanctuary or pause-menu character sheet is added, it is out of this GDD's scope and belongs to
whichever system owns that screen.

## Acceptance Criteria

- **AC-01** — **GIVEN** a hero with `base_stat = 50`, `flat_bonus = +12`, and `additive_bonus_total = 0.45`, **WHEN** the effective stat is calculated, **THEN** the result equals `(50 + 12) × (1 + 0.45) = 89.9`, rounded per implementation convention. No other value is accepted.

- **AC-02** — **GIVEN** a hero with additive bonuses summing above `+3.00`, **WHEN** the effective stat formula is evaluated, **THEN** the additive total is clamped to `3.00` before multiplication — the maximum multiplier applied is `4.0×` the flat-adjusted base.

- **AC-03** — **GIVEN** a hero with `effective_damage = 90` attacking a standard enemy with `is_crit = true` and `crit_multiplier_effective = 2.5×` (Hero's Crit Multiplier stat resolved via Formula 7 — base 1.5× plus a diminishing-curve bonus of 1.0×, matching that formula's own Raw = 1.0 worked example), **WHEN** the auto-attack resolves, **THEN** `final_damage = 90 × 2.5 = 225`. *(Corrected 2026-09-18: this AC previously used the removed `CRIT_MULTIPLIER_BASE = 1.75` additive-fold mechanism — updated to the redesign's diminishing-curve `crit_multiplier_effective`, per Formula 7.)*

- **AC-04** — **GIVEN** a hero with `effective_damage = 90` attacking an enemy tagged `[BOSS]` or `[ELITE]` with `is_crit = false`, **WHEN** the auto-attack resolves, **THEN** `final_damage = 90 × 1.5 = 135` for both tags.

- **AC-05** — **GIVEN** a hero with `armor = 100` receiving `incoming_damage = 200`, **WHEN** armor reduction is applied, **THEN** `effective_damage_taken = max(1, floor(200 × (100 / 200))) = 100`. **AND** given `armor = 0`, the hero takes the full 200 — confirming the formula never reaches 100% reduction. *(Corrected 2026-07-15: added the `max(1, floor(...))` guard to match Formula 5's correction — does not change this AC's numeric result, but the AC previously omitted the guard entirely.)*

- **AC-06** — **GIVEN** a hero lands a killing blow dealing 270 raw resolved damage against a target with only 180 HP remaining (`absorbed = min(270, 180) = 180`), `hero_lifesteal_fraction = 0.20`, `max_health = 500`, `current_health = 450` (50 HP missing), **WHEN** lifesteal resolves on `monster_hp_absorbed`, **THEN** `heal_amount = floor(180 × 0.20) = 36`, `hp_recovered = min(36, 50) = 36` HP. *(Corrected 2026-07-15: this AC previously used the raw 270 as the healing basis — `hp_recovered = min(270 × 0.20, 50) = 50` — the exact pre-overkill-cap error Formula 6's revision fixed. The old AC's numbers coincidentally landed at the overheal clamp ceiling, masking the bug. This AC now matches Formula 6's corrected worked example and basis.)*

- **AC-07** — **GIVEN** a hero with `tower_affinity_stat = 0.40` and `qualifying_towers = 20` (`TOWERS_AFFINITY_REFERENCE = 16`), **WHEN** Tower Affinity is calculated, **THEN** `tower_affinity_bonus ≈ 0.447` and both `effective_physical_attack` and `effective_magic_attack` are multiplied by `1.447`. **AND** given `qualifying_towers = 0`, the bonus is exactly `0.0`.

- **AC-08** — **GIVEN** a hero has Mage as Primary class, with 6 elemental towers and 4 physical towers on the field, **WHEN** Tower Affinity recalculates after a `tower_placed` event, **THEN** `qualifying_towers = 6` (elemental only) — not 10. The physical towers contribute nothing to the count.

- **AC-09** — **GIVEN** a hero is in WAVE_ACTIVE phase standing within 3 Chebyshev cells of a frost tower, **WHEN** 30 cumulative seconds of proximity have elapsed across any number of missions, **THEN** `hero_class_unlocked` fires with the correct frost `class_id` payload — and does NOT fire before 30 seconds have elapsed.

- **AC-10** — **GIVEN** a hero stands within 3 cells of any tower during SCOUT phase, **WHEN** 30 seconds pass in that position, **THEN** the proximity accumulator does NOT increment — the class unlock threshold is not met from Scout time alone.

- **AC-11** — **GIVEN** the player designates a Primary class before SCOUT begins, **WHEN** SCOUT phase starts, **THEN** the class designation is locked for the mission — no UI action can change Primary or Secondary class until the next Sanctuary visit.

- **AC-12** — **GIVEN** a hero has skills A, B, C, D equipped resolving to Ultimate `U1` via the lookup table, **WHEN** skill B is removed from its slot mid-adventure, **THEN** the Ultimate recomputes immediately to the A/empty/C/D combination — `U1` is no longer available, its cooldown timer is discarded, and the U binding reflects the new Ultimate (or `NONE` if the combination has no table entry).

- **AC-13** — **GIVEN** a hero's HP reaches 0 by any source (direct hit, DoT tick, or environmental damage), **WHEN** HP reaches 0, **THEN** `hero_died` fires and the mission transitions to DEFEAT that same frame — no effect, item, or lifesteal application can intercept the outcome on the killing hit.

- **AC-14** `[Visual]` — **GIVEN** the hero is standing on a GOAL cell with no monsters present, **WHEN** the hero occupies that cell continuously, **THEN** the breach counter remains unchanged — a debug overlay must confirm no breach event fired from the hero's presence.

- **AC-15** *(added 2026-07-15d — defense-in-depth regression guard, `/review-all-gdds` 5th pass)* — **GIVEN** `state == DEAD` (test setup: force hero HP to 0 and let `hero_died` fire), **WHEN** a `hero_healed` event is subsequently received (test setup: emit directly, simulating a race the upstream D&S Rule VIII guard is expected to prevent), **THEN** Hero System discards it — no HP change, no `hero_health_changed` emission, no visual/audio triggered. This AC should never fail under normal D&S behavior; it exists to catch a regression if D&S's own `hero_died` cleanup (Rule VIII) is ever broken by a future change.

**Test file targets:** AC-01 through AC-09, AC-12, AC-13, AC-15 → `tests/unit/hero/` (Logic — BLOCKING). AC-10, AC-11 → `tests/integration/hero/` (Integration — BLOCKING). AC-14 → `production/qa/evidence/` (Visual — ADVISORY).

## Open Questions

1. **Class catalogue — PARTIALLY RESOLVED (2026-08-27, badge-filename drift fixed 2026-08-28).** The Hero System defines the mechanics of Tower-Synced Classes (Rules 13–23); the content itself is now drafted at `design/gdd/hero-class-catalogue.md` — 4 classes (one per existing tower archetype: physical/ranged/elemental/support), each with a Primary + Secondary perk (mechanism + safe range, per Formula 1's `flat_bonus`/`additive_bonus_total` model). **Not fully closed**: perk magnitudes are first-draft only, deferred to the same balance-calibration pass as OQ-2 below; `assets/data/class_palettes.tres` and the 4 badge assets remain unauthored (Art Bible-gated) — but the Class Identity Display section's badge-filename list now correctly names the real `class_id` values (`physical.png`/`ranged.png`/`elemental.png`/`support.png`), the naming drift the catalogue found is fixed, not just flagged. *Owner: Game Designer. Remaining work: perk value calibration (with OQ-2) and badge/palette art authoring.*

2. **Hero base stat values** — HP, damage, movement speed, and attack range are marked `(TBD at production)` in Tuning Knobs. These require a first playable mission to calibrate against the wave difficulty curve. *Owner: Systems Designer / Producer. Resolve at first prototype milestone.*

3. **Ultimate lookup table authorship — RESOLVED.** *(Found stale 2026-08-24, `/design-review --depth lean` re-review, S8-07 — `hero-skill-build.md` was Approved 2026-07-17 and closes this exactly, but this item was never marked resolved here.)* Rule 10 specifies that 4 active skills deterministically select one Ultimate via a lookup table; `hero-skill-build.md` authors it: a 4-skill category-count profile provably exhaustive over 35 raw profiles, collapsing to 19 fixed Ultimate IDs (independently re-derived and confirmed correct during that GDD's own `/design-review` pass — stars-and-bars `C(7,4)=35`, fan-in-collapse to 19). Every reachable combination has an entry; no lookup-panic path exists.

4. **EventBus catalogue update — RESOLVED, with a residual signature mismatch flagged.** *(Found stale 2026-08-24, `/design-review --depth lean` re-review, S8-07 — the "52-event catalogue" figure is itself long stale; the catalogue is 80 events as of this pass.)* `hero_class_unlocked` is catalogued in `event-bus.md` (row: `class_id: String`), but the actually-shipped signal (`event_bus.gd`) carries a different signature entirely — `hero_class_unlocked(archetype: StringName, is_deep: bool)`, no `class_id` field at all. The event exists and is wired; the catalogue row describing it is the stale side now, not this GDD's own requirement. Flagged for `event-bus.md`'s own next pass to reconcile — out of scope for this GDD to fix directly.

5. **`hero_position_changed` resolution** *(EventBus OQ-5 — RESOLVED)* — Emission fires per grid-cell boundary crossing via an O(1) `prev_cell != current_cell` guard each physics frame. No throttling beyond the cell-change guard is needed.

6. **Grid OQ-1 — RESOLVED.** *(Found stale 2026-08-24, `/design-review --depth lean` re-review, S8-07 — `tower-mastery.md` was authored and Approved before this pass but the resolution was never linked back here.)* `tower-mastery.md` Rule 1 confirms it uses the **same 3-cell Chebyshev radius** as this GDD's class-proximity accumulator — a deliberate shared value (both systems answer "is the hero standing close enough to a tower," and Grid's own Formula 3 note already recommended reuse over a second invisible radius). No Euclidean variant or new Grid API was needed.

7. **Proximity accumulation and Tower Mastery overlap — RESOLVED.** *(Found stale 2026-08-24, same pass as item 6.)* `tower-mastery.md` Rule 2 confirms two fully separate accumulators sharing only the `hero_position_changed` signal and the radius constant — different keying (Hero: `tower_type`/archetype only; Tower Mastery: full 4-slot `build_signature`), different thresholds, different EventBus emissions (`hero_class_unlocked` vs. `mastery_progress_updated`/`skill_tree_point_earned` — corrected 2026-08-31, third pass: Tower Mastery no longer emits `skill_unlocked` directly, per that document's own revision). Confirmed not one shared counter, as this item required.

8. **Movement feel — acceleration curve** — Rule 26 specifies instantaneous velocity for MVP. A feel pass may introduce easing if playtesting reveals responsiveness issues. Deferred to Polish phase. *Owner: Gameplay Programmer.*

9. **Tower Affinity rewards raw tower count, in tension with Tower System's own cost-efficiency curve** *(added 2026-07-15 — `/review-all-gdds` game-design-holism pass)* — Formula 2's `tower_affinity_bonus = tower_affinity_stat × sqrt(qualifying_towers / 16)` scales Hero Damage/Skill Power off the number of live qualifying towers, with no weighting for their cost or DPS contribution. `tower.md` deliberately makes T1/T2 cost-inefficient "budget-gating" tiers with "no mechanical niche" versus T3 (`tower.md` line ~395, D3-A). Because Tower Affinity only counts bodies, the mechanically rational strategy is spamming the cheapest qualifying tower (T1) to maximize count-per-gold — directly against Tower System's own designed efficiency curve, and against `game-pillars.md` Pillar 2's anti-pattern ("features that add options without adding meaningful decisions"). Neither GDD currently accounts for the other's design intent here. **Not resolved this session** — a redesign (e.g., weighting `qualifying_towers` by cost or DPS contribution) is a balance change that needs real playtesting data this project doesn't have yet, not a documentation fix; inventing a new weighting formula without that data would be guessing, not designing. Flagged here as a tracked design tension rather than silently left undocumented. *Owner: Game Designer / Economy Designer. Resolve during first balance-calibration pass (see hero.md OQ-2, which already defers hero base stats to the same milestone) — evaluate live playtest data on whether T1-spam-for-Affinity is actually a dominant strategy in practice before redesigning the formula.* **User confirmed 2026-07-15**: presented with 4 options (leave deferred / gate qualification by minimum tier-cost / weight by cost-DPS / declare intentional board-presence design) — explicitly chose to keep this deferred to the first balance-calibration pass rather than guess at a fix without playtest data. Not a gap in follow-through; a deliberate decision to wait for evidence.
