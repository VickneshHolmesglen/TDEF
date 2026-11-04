## Gridless gameplay ranges (option C, ADR-0005 amendment 2026-11-04).
##
## Every range, aura, splash and reveal radius is authored in cells (the data
## and balance tables keep their `*_cells` fields) but is tested as a circle in
## world units between true positions: tower square centres, monster flow
## positions and the Hero's global_position.
##
## The old rule was Chebyshev distance <= R between cell centres, which covers
## a square of half-extent (R + 0.5) cells. The circle keeps that square's AREA
## (radius = half-extent * 2 / sqrt(pi)), so a tower covers about as much ground
## as before: a little more along the axes, less in the far corners.
##
## Usage:
##   if WorldRange.within(tower_center, monster_pos, focus.attack_range_cells): ...
##   var px: float = WorldRange.radius_px(weapon.aoe_radius_cells)
class_name WorldRange
extends RefCounted

## World units per cell. Every shipped GridConfig uses 64 (MonsterManager.CELL_SIZE).
const CELL_PX: float = 64.0
## 2 / sqrt(pi): turns a square's half-extent into the radius of a circle of equal area.
const AREA_SCALE: float = 1.1283791671


## World-unit radius of an authored `cells` range.
## Usage: WorldRange.radius_px(3) -> 252.7 (the old 7x7-cell square, as a circle).
static func radius_px(cells: float) -> float:
	return (cells + 0.5) * CELL_PX * AREA_SCALE


## True when `b` lies within the `cells` range circle centred on `a`.
## Usage: WorldRange.within(Vector2(96, 96), monster.global_position, 2)
static func within(a: Vector2, b: Vector2, cells: float) -> bool:
	var r: float = radius_px(cells)
	return a.distance_squared_to(b) <= r * r
