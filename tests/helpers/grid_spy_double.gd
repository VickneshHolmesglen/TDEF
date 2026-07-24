class_name GridSpyDouble
extends RefCounted

## Lightweight Grid test double for Constellation tests (Stories 001-003).
## Exposes only the read-only subset Constellation actually calls
## (get_occupied_cells_in_radius(), get_occupant()), plus get_all_occupied_cells()
## purely as a call-counter tripwire — Constellation must never call it on the
## hot recheck path (Core Rule 8, AC-17).
##
## Usage:
##   var grid := GridSpyDouble.new()
##   grid.place(1, Vector2i(2, 4))
##   _constellation._grid = grid

var _occupancy: Dictionary[Vector2i, int] = {}
var get_all_occupied_cells_call_count: int = 0


func place(tower_id: int, cell: Vector2i) -> void:
	_occupancy[cell] = tower_id


func remove(cell: Vector2i) -> void:
	_occupancy.erase(cell)


func get_occupant(cell: Vector2i) -> int:
	return _occupancy.get(cell, -1)


## Default-permissive bounds check (16x12, matching GridConfig's default) —
## Constellation/Tower Mastery tests only need this to differ for their own
## explicit out-of-bounds edge cases; everything else should pass through.
func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < 16 and cell.y >= 0 and cell.y < 12


## Chebyshev(a,b) = max(|a.x-b.x|, |a.y-b.y|) — mirrors grid.gd's real semantics.
func get_occupied_cells_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _occupancy:
		var dist: int = maxi(absi(cell.x - center.x), absi(cell.y - center.y))
		if dist <= radius:
			result.append(cell)
	return result


## Constellation must never call this on the hot recheck path (AC-17) — tests
## assert this counter stays 0 across any sequence of tower_placed/removed/
## destroyed events.
func get_all_occupied_cells() -> Array[Vector2i]:
	get_all_occupied_cells_call_count += 1
	var result: Array[Vector2i] = []
	for cell: Vector2i in _occupancy:
		result.append(cell)
	return result


## Mirrors Grid.cell_to_world()'s real formula (cell_size=64.0, the fixed
## project-wide constant per mission-select.md's own OQ-4 resolution) — used
## by TowerMasteryFeedback tests (Story 013) to verify arc world positioning.
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * 64.0 + 32.0, cell.y * 64.0 + 32.0)
