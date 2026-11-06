# 3D Terrain — Design

Date: 2026-11-07
Status: Draft, awaiting user approval
Follows: ADR-0043 (3D towers, built 2026-11-07). Visual base: ADR-0042 (Hd2dScenery).

## 1. Intent

The game is moving to 3D in steps: towers (done), then terrain (this
document), then hero and monsters. The user wants terrain that **changes how a
mission plays**, not just how it looks: "depending on the map, the hilly
terrain would have some high ground. Each map should have its own quirks like
that." This document covers the first two quirks, **hills (high ground)** and
**rivers**. "There will be other elements in other maps, we'll focus on this
one for now."

Success: launching a hilly map shows rolling 3D hills you can build on for
extra range at extra cost. Monsters route around the hills. On a wet map a
river winds across the board; monsters wade it slowly, and the hero is slowed
too. The terrain is different on every launch, but each map always keeps its
character.

## 2. Decisions the user made

| Topic | Decision |
|---|---|
| Look | **Rolling hills** (mockup B): one smooth 3D ground surface with natural slopes and curving rivers. Chosen over sheer-cliff terraces and soft terraces. |
| Height readability | Colour shows height ("we'll play with the colours to show the height difference"). The tint must be tunable. |
| Generation | Terrain is **regenerated every launch, together with the path**. Each map has a fixed *character*; the layout changes each time. |
| High ground: building | Allowed. **Costs more, raises the tower's range.** |
| High ground: monsters | **Off-limits**, including when rerouting around towers. |
| High ground: path | **Hills never sit on the monster path**, but may sit right alongside it. |
| Rivers: monsters | Monsters **can wade** rivers, slowed while in the water. |
| Rivers: building | **No building on water.** |
| Rivers: hero | The hero is slowed by water, and the slow **lasts a while after leaving it**, like a debuff. |
| Camera | Unchanged fixed tilted view (decided for 3D towers). |
| Scope split | Terrain first. **Aquatic monsters** (speed boost or armour in water) and **water-crossing hero equipment** are a later project. |

## 3. Goals, non-goals, anti-goals

**Goals**
- Per-cell height levels (0 = ground, 1 = hill, 2 = high hill) and per-cell
  water, generated with the path each launch, driven by each map's character.
- Rules: hill build cost and range bonus; hills block monster walking; water
  is walkable but slows monsters; water blocks building; hero water slow with
  a lingering debuff.
- A smooth 3D ground mesh and water surface replacing the flat painted ground
  in `Hd2dScenery`, with a height colour tint. Grass, trees and props sit on the
  surface.
- 3D towers on hills stand on the hilltop. Everything 2D that belongs to a
  raised spot is drawn and clicked where it appears on screen.

**Non-goals (later projects)**
- Aquatic monsters and water-crossing equipment (project 2 of terrain).
- Other map quirks (the user will name them later).
- 3D hero and monsters. Units stay 2D sprites drawn on top. Accepted for towers
  already: "keep sprites on top until units go 3D". A sprite behind a hill
  stays drawn over it.
- 3D Sanctuary town buildings (a separate project the user requested
  2026-11-07, see §10).
- Camera rotation or free camera.

**Anti-goals: failures even if it technically works**
- A generated map where hills cut spawn off from goal, or leave too little
  room to build. Each map must stay playable on every seed.
- High ground you can't read at a glance. If players can't tell which spots
  are hills, the cost and range rule feels random.
- Clicking a hilltop and placing the tower on the cell behind it, or a range
  ring or hero sprite floating off the ground it stands on.
- Terrain that looks different between a Daily Challenge run and its retry on
  the same seed.

## 4. Gameplay rules

### 4.1 Cell terrain data
Each grid cell gets two terrain facts alongside its existing `Grid.CellType`:
- `height_level: int` in {0, 1, 2}
- `water: bool`

Constraints:
- PATH, SPAWN and GOAL cells are always height 0.
- Water cells are always height 0.
- A PATH cell may be water: that's a **ford**, where the river crosses the
  lane.
- BLOCKED border cells stay BLOCKED; their height only matters for looks.

### 4.2 Hills (height ≥ 1)
- **Monsters:** not walkable. The pathfinder treats them like an obstacle, and
  "would this placement block all paths" must account for them.
- **Building:** allowed. A tower's level is the height of its cells. With free
  placement (ADR-0005 amendment) a tower's square can cover several cells.
  **My call:** placement is valid only if every covered cell has the same
  height level and none is water. This means no towers straddling a slope.
- **Cost:** `placement_cost × (1 + HILL_COST_PER_LEVEL × level)`, rounded.
  **My call:** the tower records the price actually paid, and selling
  refunds 40% of that. Upgrade costs get no hill premium.
  Starting value is `HILL_COST_PER_LEVEL = 0.25`, so level 1 costs +25% and
  level 2 costs +50%. The build panel and placement preview show the real cost
  for the hovered spot.
- **Range (user decision: every range):** `+HILL_RANGE_PER_LEVEL × level`
  cells, added to **every** range a tower on a hill has:
  - attack range (`attack_range_cells`, after the Shaft bonus and the
    RANGE_BOOST perk);
  - aura radius;
  - chain and cone reach;
  - the radii used for the hero's Tower Affinity and class proximity.

  The bonus goes on top of the existing 8-cell cap, so a capped tower still
  gains. Starting value: 1 cell per level. Every range read goes through one
  helper that adds the tower's terrain bonus, so no range site is missed.
- **Hero:** can walk on hills (my call; hills only block monsters).

### 4.3 Water
- **Monsters:** walkable. While a monster stands in water its speed is
  multiplied by `WATER_MONSTER_SPEED_MULT` (start 0.6). This is positional,
  not a timed status: it applies only while the monster is in water, and
  stacks multiplicatively with slows under the existing speed floor
  (`MonsterManager.SPEED_MULTIPLIER_FLOOR`).
- **Pathfinding cost:** a ford keeps PATH cost. Off-path water costs the same
  as PLACEABLE (10). My call; tunable.
- **Building:** not allowed on any water cell, including fords.
- **Hero:** entering water applies a move-speed debuff,
  ×`WATER_HERO_SPEED_MULT` (start 0.7). It stays while the hero is in water and
  for `WATER_HERO_LINGER_SECONDS` (start 3.0) after leaving, refreshed on
  re-entry. **My call:** this is a true multiplier, applied after the
  additive move-speed fold in `get_effective_stat`, not an additive -0.3
  effect-modifier entry. An additive entry would be cancelled by +30% gear.
  The later water-crossing equipment cancels it by name. The hero HUD shows
  it as a debuff.
- **Flying monsters** (`movement_type` "flying", straight-line
  `flight_path`): **my call:** they ignore terrain. They fly over hills and
  water, aren't slowed, and their path doesn't change. Their sprites stay at
  their current fixed screen offset.

All five numbers live in one tunable data resource, not as code constants
spread around.

## 5. Generation

### 5.1 Map character
Each map gets a **terrain profile** (data, one per map). Fields, at minimum:
- `hill_coverage`: share of non-path interior cells raised
- `max_height_level`: 0, 1 or 2
- `hill_clusters`: a count range; hills come in blobs, not speckle
- `river_count`: 0, 1 or 2
- `river_width_cells`: 1 or 2

A map with no profile is flat and dry, as today. The proposed characters
below are **my call** from the map names; the user can change any of them.

| Map | Character |
|---|---|
| The Gap | Light hills (level 1) flanking the lane, no river. Gentle first map. |
| The Foothills | Heavy hills, level 2 peaks, no river. |
| The Hollow | Hills ringing the edges (a bowl), level 1–2. |
| The Narrows | One river and light hills. |
| The Duskwood | One narrow stream, few hills. |
| The Ashfields | Low scattered hills, dry. |
| The Mirefen | Wet: two rivers, no hills. |
| The Coilmarsh | Wet: one wide winding river, light hills. |
| The Broodwarrens | Many small level-1 mounds. |
| The Riftgate | Hills plus one river. |
| The Shardplain | Mostly flat, one or two low hills. |
| The Twinpass | Hills between its two lanes, one river. |

### 5.2 Generation rules
- Terrain is generated **after** `MapGenerator` has walked the path(s), from
  the same `RandomNumberGenerator`. The same seed always gives the same map,
  including Daily Challenge (dated seed) and retry.
- Hills are placed only on interior PLACEABLE cells. Never on PATH, SPAWN or
  GOAL, but they may touch the path. Level 2 cells sit inside level 1 blobs.
- Rivers run edge to edge across the board and cross the lane at least once.
  Where a river meets a PATH cell, that cell becomes a ford.
- Guarantees, checked by tests over many seeds for every profile:
  - Spawn(s) always reach the goal over walkable cells. Path cells are never
    hills, so the lane itself is always a route, but this is still tested.
  - At least `MIN_BUILDABLE_SHARE` (start 40%) of interior cells stay
    buildable: not path, not water.
- Regeneration happens wherever the path is generated today
  (`confirm_launch`, Daily Challenge). A **retry keeps the same map**,
  terrain included: `retry_current_mission()` already reuses the generated
  `GridConfig` (AC-23), so terrain is stored inside `GridConfig`. If a
  mid-mission checkpoint stores the grid, it stores the terrain too.

## 6. Visuals

### 6.1 Ground
- Replace `Hd2dScenery`'s flat ground plane with a **heightfield mesh** over
  the grid plus its margin.
  - Each cell's height level becomes a target height. Water cells get a
    sunken bed.
  - The field is smoothed into rolling slopes, matching mockup B, which
    smoothed over roughly one cell.
  - Path cells stay flat at height 0 so the lane reads clearly.
- **Height per level, my call:** about half a cell (`HEIGHT_PER_LEVEL`,
  tunable). Taller hills hide more of the board behind them under the 50°
  camera.
- **Height tint:** the ground shader tints by real surface height, from a
  tunable gradient per scenery profile. Lowland stays the current grass, hills
  shift toward a lighter or warmer tone, and slopes steeper than a threshold
  show rock. The look target is "readable at a glance"; the exact colours get
  tuned live with the user.
- The existing lane mask, lane edges and per-map scenery profile
  (`Hd2dSceneryProfile`) keep working on the new surface.

### 6.2 Water
- A water surface sits just below ground level over the river cells, with
  soft banks from the smoothing, gentle motion, and a slightly darker,
  visible ford under the lane.
- The shader is new and must be **live-checked** in a running scene; headless
  tests can't compile shaders (project rule).

### 6.3 Props
- Grass cards, flowers, bushes, trees, rocks, ruins and other dressing take
  their height from the surface.
- No dressing in water except bank debris and reeds, which are optional
  (builder's call).

### 6.4 Raised things in 2D (screen alignment)
`Hd2dScenery` aligns 3D and 2D for ground at height 0. A point raised by
height `h` appears on screen **higher by `h × cos(pitch)`**. So:
- **3D towers** on hills are raised to the surface height. `TowerModel3D`
  already takes a world position; this adds a height.
- **2D things tied to a raised spot are lifted by that screen offset:** tower
  range rings, rank and perk badges, HP and hit effects on towers, the
  placement ghost and footprint, and the hero sprite. The hero's offset follows
  the smooth surface height under them, so they visibly walk up slopes.
- **Clicking and hovering are height-aware.** The cell under the cursor is the
  front-most cell whose raised top covers that screen point, not the flat 2D
  cell. This applies to placement, tower selection and anything else that
  converts screen to cell.
- Monsters never stand on hills and water sits near height 0, so monster
  sprites need no lift.
- **Hidden spots (user decision: fade/outline what's hidden).** Hills hide
  what is directly behind them, up to about 0.6 cell for a level-2 hill under
  the 50° camera. Anything hidden stays readable:
  - **3D towers** partly behind terrain show their hidden part as a
    see-through silhouette or outline, drawn over the hill.
  - **The lane and build cells** behind a hill stay readable where the hill
    covers them, for example through a lane and grid overlay drawn above the
    terrain while placing.
  - **Clicking** a hidden cell still works, for example by favouring the
    cell behind when the cursor is on a hill's back slope, or through the
    overlay.

  The exact technique is the builder's call. It must be live-checked with a
  tower and a lane cell placed right behind a level-2 hill.
- The 2D grid view used where there's no scenery profile tints hill cells by
  level and water cells blue, so the rules still read.

## 7. Constraints
- Godot 4.6.2, typed GDScript, gdUnit4. Targeted test suites only; never the
  full suite unless the user asks.
- Gameplay stays 2D and authoritative. Terrain data lives with the grid
  (`Grid` / `GridConfig`), not in the presentation layer, so it works headless
  and in tests.
- Presentation follows ADR-0042:
  - every `VisualInstance3D` sits on `Hd2dScenery.RENDER_LAYER`;
  - the light sits on the camera's layer;
  - tower models live under `get_dynamic_root()`.
- No `#` comments inside `.tscn`/`.tres` blocks (project rule).
- Performance: 60 FPS and 200 draw calls. The ground stays one mesh (or a few
  chunks) and water one mesh.
- Existing missions without a terrain profile must look and play exactly as
  today.

## 8. Testing expectations
- **Generator:**
  - no hills on path, spawn or goal;
  - fords exist where rivers cross;
  - spawn reaches goal;
  - the minimum buildable share holds, over many seeds per profile;
  - same seed gives the same terrain.
- **Pathfinding:** hills are not walkable; water is walkable;
  `would_block_all_paths` accounts for hills.
- **Placement:** no building on water; a mixed-height footprint is rejected;
  the hill cost formula holds.
- **Range:** the hill bonus applies on top of the cap.
- **Monster:** speed in water and out; stacking with a slow.
- **Hero:** debuff while in water, its linger, and refresh on re-entry.
- **Live checks** in a real mission launch: hills, water, a tower on a
  hilltop, clicking a hilltop places there, a range ring sits on the hill, the
  hero walks up a slope, monsters wade a ford and route around hills, and a
  flat map is unchanged.

## 9. Left to the builder
- Smoothing method, mesh resolution and chunking.
- Exact hill blob growth algorithm and river curve method, within §5.2.
- Water shader details and how the ford looks.
- Where the terrain profile hangs: on `MissionEntry`, or a field on the
  existing per-map scenery data.
- Tint gradient defaults (tuned live with the user later).

## 10. Next project, queued by the user (not in this document)
**3D Sanctuary town buildings.** The user said: "You'll need to generate the
buildings to replace the ones in the overview. They must get more intricate
and bigger the higher their level."
- Today the Overview diorama shows 7 buildings with painted art for 5 tiers
  each:
  - armoury
  - blacksmith
  - castle
  - keep
  - menagerie
  - seers_tower
  - training_hall
- The art lives in `assets/art/sanctuary/town/*_tier_N.png` and is shown by
  `TownBuildingView`.
- Same approach as the towers: Blender-generated models, with detail and size
  growing per tier.
- It gets its own design once the terrain design is approved.
