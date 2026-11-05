# Map Terrain (per-map placement zones and lane conditions)

Date: 2026-11-05. Status: **designed, not built**. Origin: user suggestion: "path generation conditions for each map; on a map with mountainous terrain, placing a tower there would give you +1 range, but it'll cost a little more."

## Overview

Each map gets its own terrain. When `MapGenerator` builds a layout at launch, it also scatters a few **terrain patches** chosen by that map's theme. A tower whose centre stands on a patch has its stats and placement price changed: High Ground on the Foothills gives +1 range for 30% more gold. One terrain, **Shallows**, sits on the lane itself and slows monsters. Patches are re-rolled with every layout, so placement changes from run to run, and the Daily Challenge seed keeps them fixed for the day.

## Player Fantasy

"This ridge overlooks the bend. If I can afford it, that's where the archer goes." Maps stop being the same field with a different lane and start to have places worth fighting over. A paid upgrade you can see on the map gives a positional choice early in a run: buy a cheaper tower on plain ground now, or save for the patch.

## Detailed Rules

1. **Terrain layer.** `GridConfig.terrain: Dictionary[Vector2i, StringName]` maps cells to a terrain id. It is a separate layer: `Grid.CellType` is untouched, so pathfinding, placement legality, covered cells and the grid visual keep working unchanged. Cells with no entry are plain ground.
2. **Catalogue** (`TerrainCatalog`, constants in code like `Temperament`):

   | Id | Where | Tower effect | Price |
   |---|---|---|---|
   | `high_ground` | PLACEABLE patches | +1 attack range (cells) | x1.30 |
   | `ley_crystal` | PLACEABLE patches | +15% damage | x1.20 |
   | `ruins` | PLACEABLE patches | none (old foundations) | x0.75 |
   | `bog` | PLACEABLE patches | -1 attack range (min 1) | x0.80 |
   | `shallows` | PATH stretches | monsters on it move at 85% speed | - |

   The trade-offs are deliberate: High Ground and Ley Crystal cost more for more power; Ruins are a straight discount; Bog is cheap but short, so it suits aura and support towers, whose aura radius it does not shrink.
3. **Which tower gets it.** A tower takes the terrain of the cell under its **centre point** (free placement, `place_tower_at`). One rule for every footprint, and it can be shown exactly in the placement preview. Hero and monsters are not affected by placement terrain.
4. **Range bonus scope.** +/-1 applies to **attack range** only (`_get_effective_range`), not to splash, aura, reveal or support radii. It stacks additively with Shaft and the cone bonus.
5. **Price.** Paid cost = `roundi(placement_cost x price_mult)`. Affordability, the gold spent and `TowerMissionState.placement_cost` all use the paid cost, so the 40% sell refund follows it.
6. **Per-map terrain** (`MissionEntry.terrain_patches: Dictionary[StringName, int]`, terrain id -> patch count):

   | Map | Terrain |
   |---|---|
   | The Gap | ruins 2 |
   | The Foothills | high_ground 2 |
   | The Narrows | shallows 1, ruins 1 |
   | The Hollow | ley_crystal 1, ruins 1 |
   | The Ashfields | high_ground 2 |
   | The Mirefen | bog 2, shallows 1 |
   | The Broodwarrens | ley_crystal 2 |
   | The Duskwood | high_ground 1, ruins 1 |
   | The Twinpass | high_ground 2 |
   | The Coilmarsh | bog 2, shallows 1 |
   | The Shardplain | ley_crystal 2, high_ground 1 |
   | The Rift Gate | ley_crystal 1, high_ground 1, bog 1 |

   Early maps get the friendly Ruins; mountain, crystal and marsh maps get their own terrain; the last two maps mix three.
7. **Generation** (in `MapGenerator.generate`, after the lane and the merging lane, using the same `rng` so a seed reproduces the whole board):
   - **Placement patch:** pick a seed cell among PLACEABLE cells within 2 cells (Chebyshev) of a PATH cell and not already terrain; grow it by random 4-neighbour steps over PLACEABLE, non-terrain cells to a size of 3-6 cells. A patch that cannot reach 3 cells is dropped and re-seeded (max 20 tries; give up quietly after that).
   - **Shallows:** pick a run of 3-5 consecutive PATH cells on the main lane, not touching SPAWN, GOAL or the merge point.
   - Patches never overlap. Placement patches keep at least one cell gap from each other so two zones never read as one.
8. **Feedback.**
   - **Scenery** (`Hd2dScenery`): each placement terrain draws on the ground plane: High Ground as a raised rock shelf with a lighter rim; Ley Crystal as small crystal props plus a faint glow; Ruins as flagstones; Bog as dark wet ground. Shallows use the existing lane shimmer limited to its cells. Tall props are kept off patches, as `_clear_above` already does for the lane.
   - **Placement preview:** while dragging, the tooltip names the terrain under the centre and its effect plus the actual price ("High Ground: +1 range, 39 gold"). The cost label turns gold/red the way it already does for affordability.
   - **Tower info:** placed towers on terrain show a small terrain line in their info panel.
   - **Mission Select card:** a "Terrain:" row listing the map's terrain names.
9. **Scope exclusions (v1).** Terrain does not change monsters except Shallows; it does not affect the Hero; it does not persist (re-rolled with the layout every launch); no Ascension scaling of patch counts.

## Formulas

- **F1 Paid cost:** `paid = roundi(base x TerrainCatalog.price_mult(id))`; plain ground `price_mult = 1.0`.
- **F2 Effective range:** `attack_range_cells + shaft_bonus + cone_bonus + terrain_range`, clamped to >= 1.
- **F3 Damage:** final hit damage x `(1 + terrain_damage)` (Ley Crystal 0.15), applied with the other damage multipliers (veterancy etc.).
- **F4 Shallows:** monster flow speed x 0.85 while its current cell is shallows; stacks multiplicatively with slows.
- **Value check (High Ground):** a monster's time in range grows about linearly with radius; range 3 -> 4 is radius (3.5 -> 4.5) x 64 x 1.128 = +29%, so about +29% damage per pass on a straight lane for +30% price. Fair on a straight; strong on a bend, which is where the player will put it.

## Edge Cases

- **Two-spawn maps:** patches may sit by either lane; Shallows only on the main lane.
- **Small grids (Narrows 14x8):** if fewer patches fit, generation places what it can; the board is still valid (terrain never affects connectivity).
- **Tower centre on a patch boundary:** the centre cell decides; the preview shows which.
- **Checkpoint resume:** the runtime `GridConfig` must carry `terrain` through the mid-mission checkpoint, or a resumed mission would lose its terrain and towers would keep stats they paid for. Verify during build.
- **Old saves:** nothing stored, nothing to migrate.

## Dependencies

- `MapGenerator` (generation), `GridConfig` (layer), `MissionEntry` (per-map data), `TowerSystem` (price, range, damage), `MonsterManager` (Shallows speed), `Hd2dScenery` (visuals), placement preview / tower info / Mission Select card (UI), `strings.csv` (terrain names + effect text).

## Tuning Knobs

`TerrainCatalog` price multipliers and effects; patch size 3-6; per-map patch counts in each `MissionEntry`; Shallows speed 0.85; seed-distance 2 from the lane.

## Acceptance Criteria

- AC-1 Same seed -> identical terrain (Daily Challenge board stable all day); different seeds -> different patches.
- AC-2 Every placement patch is 3-6 cells, all PLACEABLE, within reach of the lane, non-overlapping; Shallows cells are PATH only.
- AC-3 A tower centred on High Ground costs `roundi(base x 1.3)` and has +1 attack range; its aura/splash radius is unchanged; selling refunds 40% of the paid price.
- AC-4 Ruins discount and Bog's -1 range (floored at 1) apply; Ley Crystal raises hit damage by 15%.
- AC-5 A monster crossing Shallows takes ~1/0.85 longer over those cells.
- AC-6 The placement preview shows the terrain name, effect and real price; Mission Select lists the map's terrain.
- AC-7 Pathfinding, placement legality and path-block rules are byte-for-byte unchanged with terrain present.
- AC-8 Each of the 12 maps generates its listed terrain over 200 seeds without failure.

## Open Questions

- Should the Hero get a bonus on High Ground (e.g. +range for ranged heroes)? Default: no, keep v1 tower-only.
- Ascension scaling (fewer friendly patches, more hostile terrain at higher ranks)? Default: later.
- More lane conditions (ash vents that burn monsters, thorn stretches)? Default: later, once Shallows has been played.
