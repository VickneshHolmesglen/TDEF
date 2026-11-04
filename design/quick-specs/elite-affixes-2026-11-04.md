# Elite affixes

Date: 2026-11-04. Status: **built** (overnight autonomy pass). Source idea: randomly rolled elite modifiers from action RPGs (Diablo, Path of Exile), which matches the "think Path of Exile" direction the user set for hero skills. Elites stop being a fixed stat block: each one asks the player to read it.

## Rules

- Every ELITE (tier 1) spawned by a wave rolls **one affix**, uniformly from four. Split children never roll. Direct `spawn_monster()` calls (tests, QA drivers) do not roll unless they pass `roll_affix = true`.

| Affix | Effect | Ring |
|---|---|---|
| Swift | `scaled_speed` x1.25 at spawn | cyan, dashed |
| Fortified | `scaled_hp` x1.4 at spawn | silver, thick |
| Regenerating | heals 1.5% of max HP per second (Pass 2c), capped at max | green, thin |
| Vengeful | on death, hastes every other monster within 2 cells x1.4 for 4 s (drummer refresh-not-stack rule) | red, double |

- The ring is a flattened ellipse at the monster's feet, drawn under the sprite like a ground aura. Each affix has its own stroke, so the cue is not colour-only.
- Not saved; no new events.

## Counters (why each is fair)

- Swift: slows and stuns (multiplicative with the affix).
- Fortified: armor-shred vulnerability, focus fire, veteran towers.
- Regenerating: burst damage and DoTs; 1.5%/s means a stalled kill, not an unkillable one.
- Vengeful: kill it away from the pack, or ahead of it (towers with long range, the Hero).

## Verification

`tests/unit/monster/elite_affixes_test.gd`: only wave-spawned elites roll, splits/standard/boss never; all four reachable; Swift/Fortified stat scaling + ring set; regen rate and cap; Vengeful hastes near, not far. Live on the_gap via `monster_spawn_requested`: 8 elites rolled all four affixes, rings visible and distinct while walking the path.
