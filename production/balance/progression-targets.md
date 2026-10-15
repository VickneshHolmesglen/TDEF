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

- [ ] Re-cost the shop into early / mid / late bands that meet the shop target.
- [ ] Implement the difficulty reward multiplier, then retune.
- [ ] Decide on Sanctuary gold: drop the costs, or make gold persist.
- [ ] Scope 4 or more new missions, each bringing a new monster or rule.
- [ ] Calibrate the simulator against real playtest runs: hero kill share,
      towers placed, and win rate are guesses today.
