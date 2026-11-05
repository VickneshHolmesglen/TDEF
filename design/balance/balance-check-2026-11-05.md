# Balance Check: 2026-11-04/05 features

Scope: Hero Skill Tree expansion, elite affixes, tower veterancy, early wave call.
Health: **CONCERNS** before fixes; all four recommendations applied the same day (see Outcome).

## Data sources

- `tools/balance/progression_sim.py --missions 120 --ascend-after 65`
- `assets/data/hero_tree/hero_tree_catalog.tres` (66 nodes)
- `src/core/monster/monster_manager.gd` (affix constants, HP scaling), `src/core/tower/tower_system.gd` (veterancy, placement cost)
- `src/core/resource_economy/resource_economy.gd`, `src/gameplay/wave_manager.gd` (early call, 30 s intermission)
- `assets/data/waves/*`, `assets/data/monsters/*`, `assets/data/tower_components/weapon_advanced.tres`
- `design/balance/equipment-set-bonuses.md`, the four quick specs

## Findings

| Item | Spec claim | Actual | Issue |
|---|---|---|---|
| Veterancy 10/30/60 | "60 kills is a well-placed tower's share of a mid-campaign mission" | Whole missions average ~58 kills (Rift Gate 100) | Rank 3 unreachable, rank 2 only on the largest maps |
| Early call 0.35 g/s | "never worth more than the wave" | Instant call = ~50% of that wave's gold; ~+35% mission gold if used every intermission | Waves never overlap, so the only cost is build time: calling at once is nearly always right |
| Tree permanent physical_attack | "comparable to one 4-piece set" | Best permanent path +71% (all gear: ~+18% flat-equivalent) | Largest hero attack source; welcome in the endgame (see below) |
| Regenerating affix 1.5% max HP/s | — | +18% effective HP at a 10 s kill, x2 at 33 s, immortal at >= 67 s | Strongest affix late; fine as a threat |
| Affix rewards | — | None | Risk with no return; The Hollow has 17 elites/run |

Progression: without the tree the hero's "rank to match" stalled at Ascension 9 of 15 from mission 60. With the tree modelled (1 purchase per mission, permanent stat nodes only) it reaches 13 by mission 60. The tree fills a real endgame gap rather than breaking pacing. Tree completes at visit ~46-52, inside its 45-55 target and before level 50.

## Outcome (applied 2026-11-05)

| # | Fix | Where |
|---|---|---|
| 1 | Veterancy thresholds 10/30/60 -> **5/15/30** | `TowerSystem.VETERANCY_KILL_THRESHOLDS`; tower.md Formula 1d; veterancy spec |
| 2 | Early call 0.35 -> **0.2** gold/s (~+20% mission gold) | `ResourceEconomy.EARLY_CALL_GOLD_PER_SECOND`; resource-economy.md 10b; early-call spec |
| 3 | Simulator models the tree's permanent attack (`--no-tree` for the old view) | `progression_sim.py` `load_tree_attack()` |
| 4 | Affixed elites pay **x1.5** kill XP and drop quantity | `MonsterManager.AFFIX_REWARD_MULT`, `MonsterDiedEvent.affix`; monster.md 19c; affix spec |

Not addressed (pre-existing, outside scope): the simulator's bag model assumes no discard/salvage and reports 80% of income lost to a full bag; run with `--salvage`/`--discard` for the realistic case.

Re-run `/balance-check` after the next playtest.
