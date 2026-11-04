# Free-flow movement and placement: options (exploration only)

Date: 2026-11-04. Status: **options A and B built 2026-11-04** (ADR-0006, ADR-0005, ADR-0008 amendments). C not scheduled.
B as built: towers block every cell their square overlaps (no clipping) and the ghost outlines those
cells; range/constellation stay cell-based from the square's rounded block; 0.2-cell snap magnet.
Question from the user: "Can we swap from grid based to free flow based?"

## What the grid does today

| Job | Where | Grid-bound how |
|---|---|---|
| Tower placement | `tower_system.gd` `place_tower(blueprint_id, top_left: Vector2i)`, `grid.gd` occupancy | Towers snap to cells; footprint 1x1 or 2x2 |
| Mazing | `pathfinding_system.gd` `would_block_all_paths` | Towers make PLACEABLE cells non-walkable; placement refused if it severs every SPAWN from GOAL |
| Routes | `pathfinding_system.gd` (ADR-0004), AStar2D per spawn, path weight 1 / placeable 10 | Route = list of cells |
| Enemy movement | `monster_manager.gd` `_advance_entity` (ADR-0006) | Walks cell centre to cell centre; emits `monster_cell_entered` per cell |
| Ranges | `FocusComponent.attack_range_cells`, healer/drummer radii, fog `is_revealed(cell)` | Chebyshev distance in cells |
| Saves / UI | `top_left` in diorama, planning cluster, tower instance | Cell coordinates |

Scale: 17 `src` files call `GGrid`, ~494 `Vector2i` references in `src`, 83 test
files touch cells. ADRs 0004, 0005, 0006, 0008 all assume the grid.

## Options

### A. Smooth enemy flow (grid stays as the navigation backbone)
Enemies steer along the route instead of stopping at each cell centre: look ahead
1-2 cells and move toward a blended point (or follow a flow field: each cell stores
a direction to the goal, built from the same Dial pass the spawn assignment uses).
Add light separation so crowds spread across the lane.

- Changes: `_advance_entity`, plus the path-step bookkeeping it owns
  (`path_step_index`, `monster_cell_entered`, knockback reverse at line ~420).
- Untouched: placement, mazing, routing rules, saves, ranges, all tower code.
- Risks: `monster_cell_entered` timing shifts slightly (fires when the enemy's
  cell changes, not when it hits the centre); tests that assert exact positions
  per frame need updating. Corner cutting must not clip BLOCKED cells: clamp the
  look-ahead target to cells that are walkable.
- Cost: small to medium. Needs an ADR-0006 amendment.

### B. Free tower placement (grid stays underneath)
Towers are placed at any world position with a circular footprint. Placement still
rasterises the circle into the cells it covers, so mazing and routing keep working
exactly as now.

- Changes: placement API (world position instead of `top_left`), overlap test
  (circle vs circle + circle vs non-PLACEABLE cells), placement preview,
  defense-building screen, save format (needs a migration for existing saves),
  tower range from the true centre.
- Risks: a circle that covers part of a cell must still block the whole cell, so
  players will see gaps that enemies cannot use. That reads as a bug unless the
  preview shows the blocked cells.
- Cost: medium. ADR-0005 and ADR-0008 amendments, save migration.

### C. Fully gridless
Navmesh walking area, Godot NavigationServer2D for routes, obstacles carved per
tower, all ranges and auras in world units.

- Changes: grid, pathfinding, monster movement, tower placement, fog, every
  cell-radius ability, map generator, scenery, saves, most GDDs and ADRs, a large
  share of the 83 cell-based test files.
- Risks: mazing becomes hard. "Would this tower cut off every route?" needs a
  navmesh rebake per candidate placement, and narrow gaps between towers behave
  unpredictably (agent radius vs gap width). Most free-placement TDs drop mazing
  and use fixed lanes for this reason.
- Cost: very large; effectively a new core. Only worth it if the game moves away
  from mazing.

## Recommendation
Start with **A**: it removes most of the "grid look" (the visible stop-turn-go at
cell centres) at a fraction of the cost and keeps the mazing design intact. Decide
on **B** after playtesting A. Treat **C** as a design pivot, not a refactor.

## If A goes ahead
1. Amend ADR-0006 (movement): steering along the route, separation, cell-entry
   event semantics.
2. Implement in `_advance_entity`; keep `current_path` as the source of truth.
3. Live-check on Twinpass (two lanes merging) and a winding map (Coilmarsh) for
   corner clipping and crowding.
