# Progression targets

**Decided 2026-10-15 (user):** *Campaign + endgame* pacing, with each map
replayed about 5–8 times before it feels done.

Measure every tuning change with `tools/balance/progression_sim.py`. The
current numbers are in `progression-baseline.md`.

## Targets

At about 20 minutes per mission (`game-concept.md`: 15–25 min), mission
counts convert to hours at roughly 3 missions per hour.

| Milestone | Target | Today (baseline) |
|---|---|---|
| Hero level cap (50) | ~mission 65 (~22 h) | ~mission 1,500 |
| Skill tree points from levels | 10 by the cap, about 1 per 6–7 missions | 4 by mission 40 |
| Sanctuary shop | spread evenly until ~mission 60: about 1–2 meaningful purchases per return | 47/88 by mission 4, 75/88 by mission 20 |
| Boss gear sets | the endgame chase: last pieces after the cap, via Brutal and tarot | mostly unreachable by mission 40 |
| Hard / Brutal | pay noticeably more than Normal, so harder runs are the fastest path | pay the same as Normal |

## What it takes (checked in the simulator)

- **Level curve:** `100 × 1.06^(L−1)`, cap 50, reaches the cap at about
  mission 67. Run: `--xp-growth 1.06`.
- **Map count:** about 65 missions at 5–8 plays per map needs **8–12
  maps**. There are 4 today, so 4 or more new missions are a content
  requirement of this pacing, not an extra.
- **Shop shape, not drop rate:** a flat drop cut does not slow the shop.
  - At ×0.25 drops, 25 items are still bought by mission 4. The cheap tier
    is costed in "any Material" and tower surplus, not kill drops.
  - The same cut pushes the boss sets out of reach.
  - The catalogue has a cheap tier (costs 3–8) and a boss tier, with little
    in between. The tuning pass needs to add a mid-tier price band, and
    possibly gate items by campaign progress.
- **Difficulty rewards:** a reward multiplier per tier of 1 / 1.3 / 1.7
  makes Brutal the fastest route. Run: `--difficulty 3 --tier-reward
  1,1.3,1.7`. It needs a code change, since the game has no tier multiplier.
- **Gold:** 18 purchases list gold costs that are never charged, because
  gold resets every mission. Remove those costs or add a persistent
  Sanctuary gold balance.

## Open

- [x] Shop spread (2026-11-02): new Steelwrought mid line, then a re-price of
      all gear (`tools/balance/reprice_equipment.py`; equipment-forge.md
      Formula 1 is now a floor). Sim, Normal: gear 1/54 at mission 1, 10 at
      8, 23 at 20, 37 at 40, 50 at 60, 53 at 70 (one boss piece left for the
      post-cap chase); Brutal finishes by ~60. Not re-priced on purpose:
      consumables (repeat buys), tower components (spent to build towers) and
      Defense Building (formula-locked), so total purchases still start at
      21/97 after mission 1. The sim ignores bag capacity (18 slots, 99 per
      stack); the dearest recipe needs ~4 slots.
- [x] Difficulty reward multiplier 1 / 1.3 / 1.7 (`DifficultyRewards`,
      2026-11-02): scales hero XP, material drops and mission-end surplus;
      gold is not scaled. The sim reads it from the code.
- [x] Level curve: 1.15 -> 1.067 (`Hero.XP_CURVE_GROWTH`). With the 8-map,
      7-10 wave campaign, level 50 lands at mission ~65 on Normal and ~38 on
      Brutal.
- [x] Sanctuary gold: dropped (2026-11-03); Sanctuary costs are materials only.
- [x] 4 new missions (2026-11-02), each introducing an archetype: The
      Ashfields (Ashwing Moth, flying), The Mirefen (Goblin Mender, healer),
      The Broodwarrens (Brood Sac, splits on death), The Duskwood (Shade
      Stalker, stealth). Existing missions extended to 7-9 waves.
- [ ] Calibrate the simulator against real playtest runs: hero kill share,
      towers placed, and win rate are guesses today.
- [x] Campaign unlocks + Ascension (2026-11-03): maps open in campaign_order,
      tiers open one at a time, Ascension ranks 1-15 above Brutal (HP x1.15
      and rewards x1.12 per rank). Also fixed: clears were never recorded.
- [x] Research re-priced (2026-11-03): 100 / 220+30U / 380+50U+32R per
      branch tier (was 15 / 27+14U / 45+24U+12R).
- [x] Simulator "Hero power vs enemy HP" table (2026-11-03): hero attack
      (level + best gear per slot) against Brutal and Ascension HP. Level 50
      hero alone needs about Ascension 9 to feel like mission 1; towers,
      skills and tarot are not modelled, so the real number is higher (cap 15).
- [x] Simulator models the endgame and the bag (2026-11-03): `--ascend-after N`
  climbs one Ascension rank per map visit up to the rank the hero's power
  supports, paying AscensionRewards shards and the per-rank reward multiplier;
  the bag uses Inventory's 18 slots, SlotExpansionCostTable (bought like any
  purchase) and per-item stack caps; generic Material costs skip
  excluded_from_type_costs items. Report: `production/balance/progression-endgame.md`
  (`--missions 160 --ascend-after 65`).
  Findings: (1) the bag is full by ~mission 60 with materials nothing still
  needs, and from then on most income is lost (82% over 160 missions); held
  shards never get room, so the Ascendant set is never bought. The game has
  no discard or sell for materials. (2) With `--discard` (a player who throws
  away stacks no remaining purchase uses) the set is complete ~mission 115,
  about 6 Ascension visits per map, inside the 5-8 replay target; best rank 7.
- [x] Bag clog, part 1 (2026-11-03): discard (right-click / Del / pad X on a
  bag slot, confirm). `design/quick-specs/inventory-discard-2026-11-03.md`.
  The sim's `--discard` models a tidy player using it.
- [ ] Bag clog, part 2: salvage surplus stacks into something useful.

