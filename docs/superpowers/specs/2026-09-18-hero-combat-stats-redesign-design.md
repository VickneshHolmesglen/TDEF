# Hero Combat & Stats Redesign

**Date**: 2026-09-18
**Status**: Approved by user, pending implementation plan
**Source**: `design/combat_formula_and_stats.txt` (player-supplied reference doc), reconciled against the currently-shipped Hero/Damage & Status/Monster systems.
**Scope**: Hero's outgoing-damage formula and the stat set that feeds it. Does NOT touch Hero's incoming-damage/HP/DEFEAT pipeline. Hero leveling is a separate, follow-up design (not covered here) — one section below has a placeholder pending that work.

## 1. Overview

The player supplied a reference doc (`combat_formula_and_stats.txt`) describing a one-way (Hero → Monster) damage formula with diminishing-returns soft caps on Crit Chance/Crit Damage/a new Luck stat, an Evasion roll, a Physical/Magical/True damage-type split, and a numeric per-monster Armor stat scaled by Hero Level. This spec reconciles that doc against the actually-shipped system (`hero.md` Formula 1, `damage_status.gd`'s D2/D7 formulas, `MonsterResource`) and resolves every conflict/gap found during reconciliation. The doc is adopted in full, with player-directed corrections (Luck's hard cap, no flat skill-base-value) and explicit answers to every place the source doc was silent or contradicted shipped mechanics.

## 2. Player Fantasy

No change to player fantasy — this is a combat-math foundation pass, not a new mechanic the player directly perceives as new content. It replaces flat hard caps with soft, satisfying diminishing curves ("stacking crit chance keeps helping, just less each time") and gives monsters real numeric defenses instead of a binary armored/not-armored flag, setting up the numeric depth the future Corrupting-Damage-style stat additions and the leveling system will build on.

## 3. Detailed Rules

### 3.1 Hero stat list changes

| # | Stat | Change |
|---|------|--------|
| 1 | Health (HP) | unchanged |
| 2 | **Physical Attack** (was Damage) | renamed; scales any ability whose `damage_type == "physical"`, including auto-attack |
| — | **Magic Attack** (was Skill Power) | renamed/repurposed; scales any ability whose `damage_type` is `fire`/`ice`/`poison`/`lightning`/`arcane` |
| 3 | Movement Speed | unchanged |
| 4 | Cooldown Reduction | unchanged |
| 5 | Crit Chance | same stat; cap mechanism changes to a diminishing curve (3.2) |
| 6 | Armor (Hero's own, defensive) | **unchanged** — still mitigates incoming damage to Hero; untouched by this doc, which only concerns Hero's outgoing damage |
| 7 | Attack Range | unchanged |
| 8 | Elemental Resistances (fire/frost) | unchanged — Hero's own incoming resistance; separate concept from monster resistances to Hero's Magic Attack |
| 9 | Lifesteal | unchanged |
| 10 | Tower Affinity | unchanged mechanism (Formula 2, sqrt-scaling); now multiplies Physical Attack and Magic Attack instead of Damage/Skill Power |
| 11 | Crit Multiplier | same stat; base changes 1.75× → 1.5×; cap mechanism changes to a diminishing curve (3.2) |
| 12 | **Luck** (new) | drives a drop-rate bonus and a secondary Crit Chance contribution (3.4) |

Stat storage stays the existing `Dictionary[StringName, float]` model (`_base_stats`/`_flat_bonuses`/`_additive_bonuses`) — no structural change, so future stats (e.g. a future Corrupting Damage stat, explicitly flagged by the player as coming later, out of scope here) are just new dictionary entries, not a schema change.

### 3.2 Diminishing-returns curves

Replaces the flat hard-clamp cap for exactly 3 stats: Crit Chance, Crit Multiplier, Luck. Every other capped stat (Lifesteal, CDR, Elemental Resist) keeps its existing flat `minf(value, CAP)` clamp — unchanged.

Formula: `Actual = (Raw × HardCap) / (Raw + ScalingConstant)`, where `Raw` is the stat's Formula-1-resolved value (`(base + flat) × (1 + additive)`) *before* any cap is applied — this curve **replaces** `_apply_stat_cap()`'s existing hard-clamp branch for these 3 stats only.

| Stat | Hard Cap | Scaling Constant | Notes |
|------|----------|-------------------|-------|
| Crit Chance | 85% (was 80% hard clamp) | 100 | |
| Crit Multiplier | base 1.5× (was 1.75×), formula `1.5 + (Raw × 2.0) / (Raw + 200)` | 200 | hard cap 3.5× |
| Luck | **35%** (player-corrected from the doc's 75%) | 150 (unchanged from doc, player's explicit choice) | |

### 3.3 Monster-side new stats

Added to `MonsterResource`:

- **Armor** (new numeric field, default 0.0) — mitigates Hero's outgoing **Physical Attack** damage only. `Mitigation% = Monster Armor / (Monster Armor + 50 × Hero Level)`. **Hero Level is hardcoded to `1`** until the leveling system (a separate, follow-up design) exists — swapping the constant for Hero's real level is a one-line change at that point, no formula rework. This field **replaces** the current `archetype_tag == &"armored"` boolean + flat `ARMORED_MITIGATION_MULTIPLIER` (0.5) mechanism entirely.
- **Evasion** (new numeric field, default 0.0, range [0, 100]) — a flat percentage roll. Rolled first, before any damage math: if `roll(0,100) < Evasion`, the Hero's attack (any damage_type, including True) misses entirely — 0 damage, no further steps run.

Monster's existing `elemental_resistances: Dictionary` (already generic-keyed, no schema change needed) continues to mitigate Hero's **Magic Attack** damage by the ability's specific element.

`damage_type == "true"` (not currently authored on any skill — a dormant capability this design formalizes but does not require new content for) bypasses both Armor and elemental_resistances.

### 3.4 Luck stat mechanics

Two mechanical hooks (player-selected; the source doc's third listed use, "random environmental triggers," has no system to hook into and is out of scope):

1. **Drop-rate bonus**: the diminished Luck value nudges `ResourceEconomy`'s drop-table rarity-tier rolls upward — a roll that would land on a given tier below the table's top tier has a `Luck Bonus%` chance to be promoted to the next tier up instead. Exactly one promotion step per roll (never cascading — a promoted roll is not re-rolled against Luck a second time to potentially promote again). Only affects tier selection; drop occurrence/quantity math (existing Formula 9) is untouched.
2. **Secondary Crit Chance contributor**: `effective_crit_chance = diminished(Crit Chance) + diminished(Luck)`, both curves computed independently (3.2) then summed. The **summed** result is then clamped to the same 85% ceiling (not just each stat individually) so a heavily-stacked build can never exceed the "never quite guaranteed" cap.

### 3.5 Combat resolution flow (per Hero attack, replacing D2/D7)

Runs identically for auto-attack and every skill cast — auto-attack is treated as a `damage_type == "physical"` ability with its own base value/coefficient (unchanged from today):

1. **Evasion roll** (3.3) — miss check against the target's Evasion. Miss ⇒ 0 damage, stop.
2. **Base damage** = `Attack Stat × Skill Scaling Factor`, where Attack Stat is Physical Attack or Magic Attack per the ability's `damage_type`, and Scaling Factor is the ability's existing `skill_power_coefficient`. **No flat "Skill Base Value" addend** (player-corrected — the current, already-balanced catalogue has no such field and none is added; this is a deliberate simplification of the source doc, not an oversight).
3. **Crit roll** — against `effective_crit_chance` (3.4, includes Luck). Hit ⇒ multiply by diminished Crit Multiplier (3.2).
4. **Target mitigation** — Armor curve (3.3) if `physical`; `elemental_resistances[damage_type]` if magic; none if `true`.
5. **Combat variance** — multiply by a random float in `[0.95, 1.05]`.
6. Existing BOSS/elite tier multiplier (Formula 4, `HERO_DAMAGE_BONUS_MULTIPLIER`) and Tower Affinity (Formula 2) still apply on top, unchanged in mechanism — just now operating on Physical/Magic Attack instead of Damage/Skill Power.
7. `floor()` at the end — unchanged convention from today's D2/D7.

### 3.6 Required plumbing (not a design decision — mechanical prerequisite)

`SkillResource` (the resource actually loaded and consumed by the live combat path, `assets/data/skills/*.tres`) currently has **no `damage_type` field** — only `skill_id`/`base_cooldown`/`skill_power_coefficient`. `damage_type` exists today only on the separate `SkillDefinitionResource`/`HeroSkillEffectResource` "catalogue" resource, which is explicitly documented as never read by combat. Practical consequence found during this design: elemental skills currently deal damage with **zero elemental-resistance mitigation applied** — a real pre-existing gap, independent of this redesign, that this work now must close since routing to Physical vs. Magic Attack requires knowing each skill's damage_type at combat time.

Required: add `damage_type` to `SkillResource` (mirroring the value already authored on the catalogue side for each of the 32 skills), and thread it through `HeroSkillAttackEvent` into `damage_status.gd`.

## 4. Formulas

All formulas are stated in full in sections 3.2, 3.3, 3.4, and 3.5 above. Summary of new/changed constants:

| Constant | Old value | New value |
|---|---|---|
| `CRIT_CHANCE_CAP` | 0.80 (hard clamp) | 85% via diminishing curve, scaling constant 100 |
| `CRIT_MULTIPLIER_BASE` | 1.75 | 1.5 |
| Crit Multiplier cap | none (only additive-bucket ±0.75/+3.00 clamp) | 3.5× via diminishing curve, scaling constant 200 |
| `ARMORED_MITIGATION_MULTIPLIER` | flat 0.5 (boolean-gated) | replaced by numeric Armor / diminishing curve, `50 × hero_level` denominator term, `hero_level` hardcoded to 1 |
| Luck cap | n/a (stat didn't exist) | 35%, scaling constant 150 |
| Skill Base Value | n/a (never existed) | not added — deliberately kept at the current purely-multiplicative model |

## 5. Edge Cases

- **Combined Crit Chance from Crit Chance stat + Luck exceeds 85% before summing**: each is independently curved to its own cap first (Crit Chance curve tops out at 85%, Luck curve tops out at 35%), then summed and re-clamped to 85% — a maxed build never exceeds 85% combined chance.
- **A monster with Armor = 0 and no elemental_resistances entry for a given element**: mitigation resolves to 0% (formula naturally returns 0 when Armor is 0; a missing dict key reads as 0 resistance, matching the dict's existing `.get(key, 0.0)`-style convention elsewhere in the codebase) — full damage applies, no special-case needed.
- **A skill authored with `damage_type == "true"`**: bypasses Armor and elemental_resistances entirely, per 3.3. No skill currently uses this value; formalized as dormant capability, not new content.
- **Evasion roll succeeds on a skill with secondary effects (e.g. a DoT-applying skill)**: the entire attack whiffs — 0 damage AND no secondary effect applies, since the miss is checked before any damage/effect resolution (step 1 of 3.5, before step 2's base damage calc).
- **Hero Level hardcoded to 1**: until leveling lands, every monster's Armor mitigation is computed as if Hero is permanently level 1 — this is a known, deliberate placeholder (3.3), not a bug; the eventual leveling design must include swapping this constant for Hero's real current level as one of its own acceptance criteria.

## 6. Dependencies

- **Damage & Status System** (`damage_status.gd`): D2/D7 formulas fully replaced by the unified flow in 3.5. Depends on `SkillResource` gaining `damage_type` (3.6).
- **Hero System** (`hero.gd`): stat renames (Physical Attack/Magic Attack/Luck), `_apply_stat_cap()` gains the diminishing-curve branch for Crit Chance/Crit Multiplier/Luck, Tower Affinity bonus application unchanged in mechanism.
- **Monster System** (`monster_resource.gd`, `monster_manager.gd`): new `armor`/`evasion` fields on `MonsterResource`; `archetype_tag == "armored"` mitigation path removed from `tower_system.gd`'s cache-building and wherever else it's consumed (note: `is_armored` is also used for **tower** damage mitigation, per `monster_resource.gd`'s own doc comment "50% tower damage mitigation" — this redesign only concerns **Hero's** outgoing damage; the tower-damage use of `is_armored` is a separate, untouched system and must NOT be removed, only Hero's own consumption of it).
- **Resource Economy** (`resource_economy.gd`): drop-table tier-roll promotion hook for Luck (3.4).
- **Hero Skill Build System**: `SkillDefinitionResource`/`HeroSkillEffectResource`'s existing `damage_type` field becomes the source of truth copied onto `SkillResource` at content-authoring time (3.6) — no change to that resource itself.
- **Future Hero Leveling System** (not designed yet): must supply the real `hero_level` value to replace the hardcoded `1` in the Armor mitigation formula (3.3) as one of its own requirements.

## 7. Tuning Knobs

| Knob | Safe range | Affects |
|---|---|---|
| Crit Chance hard cap | 50–95% | ceiling on crit frequency |
| Crit Chance scaling constant | 50–300 | how quickly raw crit chance approaches its cap |
| Crit Multiplier base | 1.0–2.0× | floor of crit damage |
| Crit Multiplier cap | 2.0–5.0× | ceiling of crit damage |
| Crit Multiplier scaling constant | 100–400 | how quickly raw crit damage approaches its cap |
| Luck hard cap | player-fixed at 35% for now | ceiling on both drop-rate and secondary-crit contribution |
| Luck scaling constant | player-fixed at 150 for now | curve shape |
| Combat variance range | fixed at ±5% per source doc | pure game-feel, not meant to be re-tuned casually |
| Monster Armor per-creature value | 0–500+ (content-authoring, per monster tier) | how much Physical Attack a given monster resists |
| Monster Evasion per-creature value | 0–100% (content-authoring) | miss chance against that monster |
| `50 × hero_level` denominator constant | fixed per source doc | overall pace of Armor's diminishing curve as Hero levels |

## 8. Acceptance Criteria

- AC-1: Every one of the 12(+1 new) hero stats resolves through `get_effective_stat()` using its correct name (Physical Attack/Magic Attack replacing Damage/Skill Power; Luck added).
- AC-2: Crit Chance, Crit Multiplier, and Luck each resolve via the diminishing-returns curve (3.2), verified against the doc's own worked examples where the constants match (Crit Chance/Multiplier); Luck verified against the player-corrected 35%/150 constants.
- AC-3: A monster with Armor > 0 mitigates Hero Physical Attack damage per the curve in 3.3, with `hero_level` fixed at 1; a monster with an `elemental_resistances` entry for a skill's damage_type mitigates that skill's Magic Attack damage by that percentage; a `true` damage_type skill (once authored) bypasses both.
- AC-4: A monster with Evasion > 0 has a matching chance to fully negate a Hero attack (0 damage, no secondary effect), verified statistically over repeated rolls in a test.
- AC-5: Combat variance applies a ±5% multiplier to final damage on every hit.
- AC-6: Luck's drop-rate hook measurably shifts `ResourceEconomy`'s tier-roll distribution toward rarer tiers as Luck increases, without changing drop occurrence/quantity math.
- AC-7: Every one of the 32 catalogued skills has a `damage_type` on the live-combat `SkillResource` (not just the catalogue resource) matching its already-authored classification, and elemental skills now show real damage reduction against a monster with matching `elemental_resistances` (closing the pre-existing zero-mitigation gap, 3.6).
- AC-8: Tower-damage mitigation's own consumption of `MonsterResource.is_armored`/`archetype_tag` (a separate system, `tower_system.gd`) is unaffected by this redesign — only Hero's own consumption of monster armor changes.
- AC-9: `hero.md`'s Formula 1 (flat/additive-bucket stacking) is otherwise unchanged for every stat this design doesn't explicitly modify.
