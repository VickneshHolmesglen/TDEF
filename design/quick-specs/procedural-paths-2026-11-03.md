# Quick Spec: Per-map generated paths, and missions 9-12

Date: 2026-11-03. Status: implemented, live-checked.
Player request: "add 4 more maps to reach 12. make sure each map does
autogenerate a new pathway each time".

## Generated paths (all 12 maps)

Every launch already built a new layout with `MapGenerator` (since
2026-08-15; the authored `grid_config.cells` only supply the grid size).
Retry keeps the current layout. Two per-map settings on `MissionEntry` now
give each map its own path character:

| Field | Range | Meaning |
|---|---|---|
| `spawn_count` | 1-2 | 2 adds an entrance on the top or bottom edge whose lane joins the main lane |
| `path_winding` | 0-1 | 0 nearly straight, 0.5 the original generator, 1 coils back on itself |

Rules:
- `forward_weight(w)`: 0-0.5 keeps the original curve (5.0 to 3.0); above
  0.5 it falls below 1 (1.0 -> 0.4), so steps away from the target become
  likelier. 0.5 = 3.0 exactly, so maps 1-8 are unchanged.
- Second lane: entrance on the top/bottom interior row, middle half of the
  width first; it may only join the main lane's later two thirds and keeps
  clear of its first third, and never touches the main lane except at the
  join (same no-shortcut rule as the main walk), so painted lanes = A* route.
- Waves spread across entrances round-robin (existing WaveManager rule).

Measured on 16x12, 300 seeds:

| winding | 0.15 | 0.5 | 0.7 | 0.9 | 1.0 |
|---|---|---|---|---|---|
| average main-lane cells | 22.2 | 24.7 | 27.2 | 33.8 | 41.1 |

Second lane: about 7 cells on average (min 1 on rare seeds where the main
lane hugs both edge rows).

## Missions 9-12

| # | Map | Entrances | Winding | Waves | Theme |
|---|---|---|---|---|---|
| 9 | The Twinpass | 2 | 0.5 | 9 | two passes, lanes meet: build at the join |
| 10 | The Coilmarsh | 1 | 1.0 | 10 | one long coiling lane; swarms and menders |
| 11 | The Shardplain | 2 | 0.15 | 9 | two short straight roads; armoured columns |
| 12 | The Rift Gate | 2 | 0.7 | 11 | finale: every archetype, two bosses |

Medallions and scenery are recolours/tints of maps 1-4 (placeholders,
candidates for Amuse). Campaign order continues the unlock chain.

## Acceptance criteria

- `map_generator_test.gd`: both entrances reach the goal along lane cells
  only (100 seeds); second entrance on the top/bottom edge; winding raises
  lane length; second lane averages > 4 cells.
- `mission_catalogue_completeness_test.gd`: 12 maps; each map's generated
  layout has its entrance count and differs between two launches.
- Live: each new map launched twice in the real game, different layouts,
  pathfinding ready, both entrances visible; Mission Select shows 12 cards.

## Amendment 2026-11-04: entrance warning and routing

- **Entrance warning.** On a map with more than one SPAWN, the mission HUD shows a banner at mission start: "N entrances: enemies come from each of them. Build where the lanes meet." (`HUD_ENTRANCES_WARNING`). It stays up 6 s (`MissionHud.ENTRANCES_BANNER_SECONDS`), longer than the 3 s used for other banners, and fires only in SCOUT, so intermission route rebuilds don't repeat it. Single-spawn maps show nothing. Tests: `tests/integration/mission-hud/entrances-warning_test.gd`.
- **Routing.** PathfindingSystem now assigns cells to a spawn by path cost (pathfinding.md Rule 3), which retires the multi-spawn gate (AC-13d). Live check on The Twinpass: no path cell falls back to A*.
