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

- [~] Mid band: user chose **new mid-tier items** over re-pricing (2026-11-02).
      Added the 9-piece Steelwrought line (30-48 Common, 7-12 Uncommon,
      0-8 iron_ore; tech_production_2); the sim buys it across missions 3-13.
      The cheap tier is still unchanged, so 60/97 purchases are owned by
      mission 4 (the longer missions pay more). Still open: gate or re-price
      the 3-8 Material starter tier if the shop target is to be met.
- [x] Difficulty reward multiplier 1 / 1.3 / 1.7 (`DifficultyRewards`,
      2026-11-02): scales hero XP, material drops and mission-end surplus;
      gold is not scaled. The sim reads it from the code.
- [x] Level curve: 1.15 -> 1.067 (`Hero.XP_CURVE_GROWTH`). With the 8-map,
      7-10 wave campaign, level 50 lands at mission ~65 on Normal and ~38 on
      Brutal.
- [ ] Decide on Sanctuary gold: drop the costs, or make gold persist.
- [x] 4 new missions (2026-11-02), each introducing an archetype: The
      Ashfields (Ashwing Moth, flying), The Mirefen (Goblin Mender, healer),
      The Broodwarrens (Brood Sac, splits on death), The Duskwood (Shade
      Stalker, stealth). Existing missions extended to 7-9 waves.
- [ ] Calibrate the simulator against real playtest runs: hero kill share,
      towers placed, and win rate are guesses today.
