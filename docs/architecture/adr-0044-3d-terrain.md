# ADR-0044: 3D Terrain (Hills and Rivers)

## Status

Accepted (user-approved spec, 2026-11-07; built 2026-11-08). Second step toward a 3D game after ADR-0043 (towers). Supersedes the unbuilt quick-spec `design/quick-specs/map-terrain-2026-11-05.md` (terrain patches).

## Date

2026-11-08

## Last Verified

2026-11-08. Live via Godot MCP on 4.6.2.stable:
- The Foothills: hills with rims, a tower placed by clicking a level-2 hilltop, the hero lifted on a slope, monsters routing around hills.
- The Mirefen and The Coilmarsh: rivers and fords, a ground monster wading at ×0.6.
- The Gap with no profile: unchanged.

## Decision Makers

User (rules, look, scope); Claude Code (architecture).

## Context

The user wanted terrain that changes play, not just looks, with each map having its own quirks:
- **Hills** are high ground. Building on a hill costs more and extends range. Monsters can never walk on hills, and hills never sit on the path.
- **Rivers** can be waded by monsters, slowly. Players can't build on water. The hero is slowed, and the slow lingers after leaving the water.
- **Generation:** terrain is regenerated every launch together with the path.
- **Look:** rolling hills (mockup B). Colour shows height.

The full spec is `docs/superpowers/specs/2026-11-07-3d-terrain-design.md`.

## Decision

1. **Terrain is gameplay data on the grid.**
   - `GridConfig.heights` (level 0..2) and `GridConfig.water` are exported dictionaries.
   - The `Grid` autoload mirrors them:
     - `get_height_level`, `is_water`, `square_height_level` (returns -1 when the cells are mixed or wet);
     - hills are left out of `get_walkable_cell_map()`, the single walkable source for pathfinding;
     - `is_square_placeable()` rejects water and mixed heights.
   - Retry keeps the map because it reuses the same `GridConfig`. The runtime grid is not checkpointed, so there's nothing to serialize.
2. **Generation uses the same RNG.**
   - `MapGenerator.generate(..., terrain: TerrainProfile)` calls `TerrainGenerator.apply` with the RNG that carved the lanes, so the same seed always gives the same terrain (Daily Challenge, tests).
   - Rivers come first: top-to-bottom bands whose consecutive rows overlap, so they always cross the lane. The crossings become fords. Rivers also flow into the BLOCKED border rows; that water is for looks only.
   - Hills grow afterwards as random blobs on dry PLACEABLE cells. Level 2 is a hill cell whose 4 neighbours are all hills.
   - The buildable floor counts hill cells as buildable, so only water is trimmed to meet it.
   - There are 12 per-map profiles, `assets/data/terrain/<id>_terrain.tres`, attached through `MissionEntry.terrain_profile`.
3. **One tuning resource holds all tunables:** `assets/data/terrain/terrain_tuning.tres` (`TerrainTuning`). It holds the hill cost +25%/level, the range +1/level, monster water ×0.6, hero water ×0.7 with a 3 s linger, the 40% buildable floor, and the visual height of 0.5 cell per level.
4. **Rules:**
   - `TowerSystem.terrain_cost` and `terrain_range_bonus` are applied at placement. The price paid is stored, and selling refunds 40% of it.
   - The range bonus applies to every range read: targeting, aura radius and pulse event, and hero class proximity (carried on `TowerPlacedEvent.terrain_level`). It goes on top of the 8-cell cap.
   - `MonsterManager._effective_speed` applies the water multiplier positionally; flyers are exempt.
   - The hero's water slow is a true multiplier after the additive fold. `set_water_immunity()` is the hook for future water-crossing equipment, `hero_water_debuff_changed` drives a HUD line, and the debuff is named by `WATER_DEBUFF_KEY`.
   - Terrain queries read the `GGrid` autoload directly rather than an injected grid, which keeps dozens of test stub grids unchanged.
5. **`TerrainSurface` handles presentation only.**
   - It builds a smooth height field: 8 samples per cell, Gaussian blur with sigma 0.45 cell, the lane blended flat, and sunken river and ford beds.
   - It provides `height_at`, `screen_lift` (h × cos pitch), height-aware `screen_to_ground` (the front-most solution), and `occludes`.
6. **`Hd2dScenery`:**
   - `set_terrain()` must be called before `build()`. With terrain, the ground is a single ArrayMesh heightfield (4 vertices per cell plus a flat skirt) and props sit on the surface via `_on_ground()`.
   - Water is one plane drawn with `hd2d_water.gdshader`.
   - The ground shader gains a height tint, slope shading, contour rims at each level's mid-height, and slope rock. All of them are no-ops on flat maps.
   - Profile knobs: `height_tint`, `slope_shade`, `contour_strength`, `rock_slope_threshold` and `water_color`, all tuned live.
7. **Raised 2D things:**
   - `TowerInstance.set_ground_position()` lifts the node by the screen lift, so its badges, rings and projectile origins rise with it, while the 3D model stands at the ground height.
   - The placement cursor and cover markers are lifted through `tower_placement_preview_updated(..., screen_lift, cost)`.
   - The hero sprite and shadow are lifted each frame through `Hero.set_visual_lift()`.
   - Picking goes through `screen_to_ground`.
8. **Hidden spots: no x-ray.**
   - At the shipped tuning the steepest slope is about 0.9 px/px. A slope must be steeper than 1/cos(50°) ≈ 1.56 to hide anything behind it, so rolling hills hide nothing.
   - A `depth_test_inverted` overlay was tried live. It compiles on 4.6.2, but the tower's own overlapping pieces self-occlude, so it washes the whole tower.
   - The guard test `test_shipped_maps_hide_nothing` fails if a future tuning makes hills steep enough to hide things. At that point a stencil-masked silhouette is the way to build it.

## Consequences

- Maps without a profile, and The Gap's direct boot, look and play exactly as before (tested).
- Aquatic monsters and water-crossing equipment are deferred to the next terrain project. The hooks for them exist: `is_water`, `set_water_immunity`, `WATER_DEBUFF_KEY`.
- **Draw calls:** The Foothills measures about 845 with terrain and 942 flat. The HD-2D dressing already exceeds the 200 budget, and terrain doesn't add to it. This is a separate performance item.
- The art style may change (the user is choosing a hand-painted plus flat-vector blend). Terrain colour lives in the shaders and profile, so a style change replaces materials, not this architecture.

## ADR Dependencies

| Relation | ADR |
|---|---|
| Depends on | ADR-0042 (Hd2dScenery), ADR-0043 (3D tower models), ADR-0005 (Grid, free placement), ADR-0008 (placement gates) |
| Amends | ADR-0042 (ground may be a heightfield) |

## Engine Compatibility

| Field | Value |
|---|---|
| Engine | Godot 4.6.2 |
| Domain | Rendering (ArrayMesh via SurfaceTool, spatial shaders), gameplay data |
| Knowledge risk | LOW: SurfaceTool, GradientTexture1D (`use_hdr`), typed Dictionaries |
| Verification | Shaders live-compiled on 4.6.2.stable (no errors). `depth_test_inverted` is accepted by 4.6.2 (tried, then removed). |
| Gotcha | MultiMesh instance transforms read back as zero under the headless dummy renderer, so grass placement can't be asserted in headless tests. |

## GDD Requirements Addressed

- `design/gdd/grid-system.md`: terrain facts per cell; hills are not walkable; no building on water or across mixed heights.
- `design/gdd/pathfinding.md`: hills are excluded at the walkable source; water is walkable at normal cost.
- `design/gdd/tower.md`: the hill price and the hill range bonus.
- `design/gdd/hero.md`: the water slow debuff.
