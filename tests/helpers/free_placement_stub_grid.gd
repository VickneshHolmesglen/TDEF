extends RefCounted

## Base for TowerSystem test stub grids (free placement, 2026-11-04).
## TowerSystem now places by world centre (Grid.place_tower_at /
## is_square_placeable / covered_cells ...). Stubs written against the
## grid-aligned API extend this and keep overriding is_footprint_placeable()
## and place_tower(): the free-placement calls round the square to its
## logical top-left and delegate to them, so existing stub flags and spies
## keep working. 64-unit cells, centres at +32, like the real Grid default.
##
## Usage:
##   class _StubGrid extends "res://tests/helpers/free_placement_stub_grid.gd":
##       func is_footprint_placeable(_tl: Vector2i, _s: Vector2i) -> bool:
##           return true

const STUB_CELL: float = 64.0


func is_footprint_placeable(_top_left: Vector2i, _size: Vector2i) -> bool:
	return true


func place_tower(_tower_id: int, _top_left: Vector2i, _size: Vector2i) -> int:
	return OK


func footprint_center(top_left: Vector2i, size: Vector2i) -> Vector2:
	return Vector2(top_left) * STUB_CELL + Vector2(size) * STUB_CELL * 0.5


func logical_top_left(center: Vector2, size: Vector2i) -> Vector2i:
	var corner: Vector2 = (center - Vector2(size) * STUB_CELL * 0.5) / STUB_CELL
	return Vector2i(roundi(corner.x), roundi(corner.y))


func square_rect(center: Vector2, size: Vector2i) -> Rect2:
	var extent: Vector2 = Vector2(size) * STUB_CELL
	return Rect2(center - extent * 0.5, extent)


func covered_cells(rect: Rect2) -> Array[Vector2i]:
	var first := Vector2i((rect.position / STUB_CELL + Vector2.ONE * 0.01).floor())
	var last := Vector2i((rect.end / STUB_CELL - Vector2.ONE * 0.01).floor())
	var result: Array[Vector2i] = []
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			result.append(Vector2i(x, y))
	return result


func is_square_placeable(center: Vector2, size: Vector2i) -> bool:
	return is_footprint_placeable(logical_top_left(center, size), size)


func place_tower_at(tower_id: int, center: Vector2, size: Vector2i) -> int:
	return place_tower(tower_id, logical_top_left(center, size), size)
