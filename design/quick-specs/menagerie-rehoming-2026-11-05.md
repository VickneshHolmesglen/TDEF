# Menagerie Rehoming (endgame Sanctuary gold sink)

Date: 2026-11-05. Status: **built** (2026-11-05). Origin: the balance sim shows ~200 Sanctuary gold banked per mission once the gear catalogue saturates (~mission 60) and ~14,800 unspent by mission 120 (`sanctuary-gold-2026-11-05.md`); rune slots absorb at most ~7,500 and are shard-gated. User suggestion: replacing animals in the Menagerie.

## Overview

Every creature gets a **Temperament**: one trait from its species' pool plus a **grade** of 1-5 stars, rolled when it is lured, bred or rehomed. HABITAT creatures' temperaments add small economy bonuses on top of the existing happiness-driven quality bonus. **Rehoming** (unlocked by the first Ascension clear) spends Sanctuary gold to release a creature and take in a fresh one of the same species with a newly rolled temperament. Chasing a habitat of high-grade, well-matched temperaments is a long, optional, gold-hungry goal with diminishing returns: a sink that never runs dry but never gates progress.

## Player Fantasy

"My sanctuary is home to *these* animals, not just five species." A 5-star Shardbound stag is a trophy the player went looking for, and arranging the habitat (which traits, which species, which slots) becomes a late-game hobby that pays a little back into every run. It extends the tending fantasy the Menagerie already has rather than adding an unrelated shop.

## Detailed Rules

1. **Temperament.** Each `CreatureInstance` carries `trait_id` and `grade` (1-5). Rolled once at creation: Lure, breeding offspring, Rehome. Never changes otherwise (tending, moving, breeding do not alter it). Shown on the creature card as "<Trait> ★★★☆☆".
2. **Trait pools by species tier** (the species' tier already sets lure cost and breeding time):

   | Tier | Species | Pool (equal weight) |
   |---|---|---|
   | 1 Common | glimmer_hare, mossback_toad | Forager (Common), Scholar |
   | 2 Uncommon | emberwing_moth, duskfang_fox | Forager (Uncommon), Scholar, Hoarder |
   | 3 Rare | aurora_stag | Forager (Rare), Hoarder, Shardbound |

3. **Effects (HABITAT only, like the quality bonus, Rule 5 of `menagerie.md`).** Each trait's bonus is the sum of `trait_value(grade)` over HABITAT creatures with that trait, capped per trait (Formula 2):
   - **Forager (rarity)**: + drop quantity of that material rarity (multiplies with `menagerie_quality_bonus`).
   - **Scholar**: + hero XP from kills, waves and mission clears.
   - **Hoarder**: + Sanctuary gold banked at mission end (applied after the Treasury rate).
   - **Shardbound**: + Ascendant Shards per win.
   Effects are economy-only by design: no combat stats, so Rehoming can never become the strongest power lever.
4. **Rehoming.** A Sanctuary action on a HABITAT or RESERVE creature, not in a breeding pen. Costs Sanctuary gold (Formula 1). The creature is released and replaced *in the same slot* by a new creature of the same species: new temperament, happiness `STARTING_HAPPINESS` (70), new `creature_id`, `missions_since_tended` 0. No lure is consumed. One confirmation dialog showing the current temperament and the price.
5. **Bad-luck protection.** A persisted counter `rehomes_since_high_grade` increments on every Rehome that rolls below 4 stars and resets on 4+. At `PITY_THRESHOLD` (10) the next Rehome rolls at least 4 stars.
6. **Unlock.** Rehoming is available once the player has cleared any map at Ascension rank 1 (`GMissionSelect.get_highest_ascension_rank() >= 1`, the existing endgame door, model ~mission 70). Before that the button shows "Unlocks at Ascension 1". Temperaments roll and apply from the start, so early creatures already differ, but gold cannot be poured into rerolls while the Forge still needs it.
7. **Rolls are not save-scummable.** Rehome rolls draw from a Menagerie-owned RNG whose state is saved with the Menagerie, so reloading a save replays the same next roll.
8. **Legacy creatures.** Creatures restored from a save without temperament data get one rolled from a seed of their `creature_id` (deterministic), grade capped at 3 stars.

## Formulas

### Formula 1: Rehome cost

```
rehome_cost(tier) = REHOME_COST_BASE x tier
```

| Symbol | Type | Range | Default | Description |
|---|---|---|---|---|
| `tier` | int | 1-3 | | Species tier |
| `REHOME_COST_BASE` | int | 100-300 | 200 | Gold per tier |

Output: 200 / 400 / 600. Example: rehoming an aurora_stag costs 600.

### Formula 2: Trait value and cap

```
trait_value(grade) = GRADE_VALUES[grade - 1]          GRADE_VALUES = [0.01, 0.02, 0.03, 0.05, 0.08]
trait_bonus(trait) = min(TRAIT_CAP, sum of trait_value over HABITAT creatures with that trait)
```

| Symbol | Range | Default | Description |
|---|---|---|---|
| `GRADE_VALUES` | per grade | 1/2/3/5/8 % | Bonus per creature by stars |
| `TRAIT_CAP` | 0.15-0.40 | 0.25 | Max total per trait |

Example: three HABITAT creatures with Scholar at 5, 4 and 2 stars: 0.08 + 0.05 + 0.02 = +15% XP. Twelve 5-star Foragers of one rarity: 0.96, capped to +25%.

### Formula 3: Grade roll

```
P(grade) = GRADE_WEIGHTS / sum   GRADE_WEIGHTS = [40, 30, 18, 9, 3]   (1-5 stars)
```

With pity, the next roll after 10 straight sub-4-star rolls is drawn from grades 4-5 only (weights 9:3).

Expected sink, at the default 200 x tier (single target: a 4+ star of one chosen trait):
- P(4+ stars) = 12% per roll; with pity at 10, one 4+ every `(1 - 0.88^10) / 0.12` ≈ 6.0 rolls.
- A 4+ star of a *chosen* trait: tier 1 (2-trait pool) ≈ 12 rolls x 200 = ~2,400 gold; tier 2 (3 traits) ≈ 18 x 400 = ~7,200; aurora_stag (3 traits) ≈ 18 x 600 = ~10,800.
- A full 12-slot habitat of 4-5 star chosen traits costs ~60,000-90,000 gold, far beyond the ~12,000 the model banks between missions 60 and 120. The sink never runs dry, and every roll still has a chance to help.

Value check against existing levers: one 5-star Forager (+8% of one rarity) is smaller than one Menagerie happiness band (+0.5 x happiness) and far smaller than the difficulty-tier reward multiplier (x1.3 / x1.7). Capped at +25% per trait, a perfect habitat is a long-term economy boost, not a power spike.

## Edge Cases

- **Creature in a breeding pen:** Rehome is unavailable (button disabled, tooltip "Return it from the pen first"), so a pair's breeding counter is never orphaned.
- **Not enough gold:** button disabled, shows the price; nothing is spent.
- **Rehoming the representative creature for the aggregate push (menagerie.md Rule 6):** the replacement creature becomes the representative; the aggregate is recomputed and pushed in the same frame (happiness drops to 70, so the quality bonus can dip; shown in the confirm text).
- **Rehoming in RESERVE:** allowed (a way to roll without disturbing the habitat). The new creature stays in RESERVE.
- **Sacrifice:** unchanged; a sacrificed creature's temperament is simply lost. The Forge does not read temperament.
- **Two creatures with the same trait at different grades:** both count (sum), up to the cap.
- **Pity counter at threshold when the player stops rehoming:** persists; the next Rehome (any species) gets the guarantee.
- **Save from before this feature:** see Rule 8; the RNG state starts from a fixed seed.

## Dependencies

- **Menagerie** (`menagerie.md`): owns temperament, Rehome, pity counter, RNG state; Rule 6 aggregate push on Rehome. Must add a note pointing here.
- **Sanctuary gold** (`SanctuaryGold`, `resource-economy.md` Rule 11): `spend(cost, &"menagerie_rehome")`; Hoarder adds to the banked amount.
- **Resource Economy** (drop quantity): applies Forager per rarity alongside `menagerie_quality_bonus`.
- **Hero** (XP): applies Scholar to kill/wave/mission XP.
- **Ascension rewards** (`AscensionRewards`): applies Shardbound to shards per win.
- **Mission Select**: `get_highest_ascension_rank()` for the unlock.
- **Save & Persistence**: Menagerie save gains `trait_id`, `grade` per creature, `rehomes_since_high_grade`, `rng_state`.
- **Balance sim** (`tools/balance/progression_sim.py`): model Rehome spend after the unlock to confirm the late balance drains.
- **EventBus**: new `creature_rehomed(old_creature_id, new_creature_id, species_id, trait_id, grade)`; `sanctuary_gold_changed` source `menagerie_rehome`.

## Tuning Knobs

| Knob | Safe range | Affects |
|---|---|---|
| `REHOME_COST_BASE` | 100-300 | How fast endgame gold drains; above ~300 a roll feels punitive |
| `GRADE_WEIGHTS` | top grade 2-5% | Rarity of 5-star creatures (trophy feel vs frustration) |
| `GRADE_VALUES` | top 5-10% | Size of the payoff per creature |
| `TRAIT_CAP` | 15-40% | Ceiling of the whole system; keep below the tier reward multipliers |
| `PITY_THRESHOLD` | 6-15 | Worst-case dry streak |
| Unlock (Ascension rank) | 1-3 | When the sink opens relative to gear saturation |

## Acceptance Criteria

- AC-1: Lure, breeding and Rehome each create a creature with a `trait_id` from its species tier's pool and a grade 1-5; over 10,000 seeded rolls the grade distribution matches `GRADE_WEIGHTS` within 1 percentage point.
- AC-2: With HABITAT creatures Scholar 5★, Scholar 4★, Scholar 2★, kill/wave/mission XP is multiplied by 1.15; RESERVE/BREEDING_PEN creatures contribute nothing.
- AC-3: Twelve 5★ Common Foragers in HABITAT give exactly +25% Common drop quantity (cap).
- AC-4: Rehoming a tier-3 creature with 600+ gold spends exactly 600, replaces it in the same slot with a new id, happiness 70, a fresh temperament, emits `creature_rehomed` and `sanctuary_gold_changed(-600, menagerie_rehome)`.
- AC-5: With 599 gold, Rehome on a tier-3 creature is rejected and nothing changes.
- AC-6: After 10 consecutive sub-4-star Rehomes, the 11th yields 4 or 5 stars; the counter resets.
- AC-7: Rehome is rejected for a creature in a breeding pen, and before any Ascension rank 1 clear.
- AC-8: Saving, rehoming, reloading and rehoming again produces the same temperament both times (RNG state persisted).
- AC-9: A pre-feature save loads; every creature gets a deterministic temperament of at most 3 stars.
- AC-10: Balance sim: with Rehome modelled from the unlock, unspent Sanctuary gold at mission 120 drops below 2,000 for a player who rehomes whenever they can afford it.

## Build notes (2026-11-05)

- Code: `Temperament` (`src/core/menagerie/temperament.gd`: pools, weights, values, cap, roll); `CreatureInstance.trait_id/grade`; `Menagerie` rolls on lure/breed, `trait_bonus()`, `forager_bonus()`, `rehome_cost_for()`, `can_rehome()`, `rehome_creature()`, persisted `rng_state` + pity counter, legacy roll. Hooks: `Hero._grant_xp` (Scholar), `ResourceEconomy._forager_bonus` (Forager, by item rarity), `SanctuaryGold` bank (Hoarder), `MissionSelect._award_ascension_shards` (Shardbound; Daily Challenge shards excluded). Menagerie screen: temperament on cards (Forager shown without its rarity, which the species implies) and in the detail panel, Rehome button + confirm dialog. EventBus `creature_rehomed`.
- Rehome removes the old creature from the roster array (the new one takes its index), so released creatures never accumulate.
- Tests: `tests/unit/menagerie/menagerie_rehoming_test.gd` (AC-1, AC-3..AC-9), `temperament_effects_test.gd` (all four payouts, AC-2 by sum test).
- AC-10 (sim): Rehoming from the first Ascension clear (model: mission 66) at tier 2 -> 37 rehomes, 14,800 gold, **10 unspent at mission 120** (was 14,810). Tier 1: 74 rehomes; tier 3: 24 rehomes, 410 unspent. Temperament payoffs are not modelled (capped, economy-only).
- Live (real save, creatures lured in memory, save restored): locked "Rehome: unlocks at Ascension 1"; after unlock "Rehome (600 gold)", stag rehomed Forager (Rare) 1★ -> Shardbound 4★, gold 1,500 -> 900.

## Alternatives considered

- **Forge reforge (reroll an item's stats for gold):** strong sink, but stats feed combat directly, so it competes with crafting and risks power creep.
- **Tower prestige (gold to permanently raise a blueprint's veterancy start rank):** ties gold to combat power and to per-mission veterancy, which was just tuned.
- **Cosmetic purchases:** clean, but this project has no cosmetic layer yet, and a sink with no gameplay payoff tends to be ignored.
- **Rehoming (chosen):** the user's direction; economy-only payoff with a cap, unbounded but optional, and it builds on the Menagerie's existing care loop.
