class_name Hd2dTownBackdrop
extends SubViewport

## HD-2D Sanctuary town backdrop (ADR-0042, dioramas pass 2026-10-12).
##
## Renders an Hd2dScenery into its own SubViewport (own World3D) so the
## Sanctuary diorama -- a UI Control, not a gameplay scene -- can show it as
## the texture of its Background TextureRect. The town buildings stay the
## diorama's own 2D TownBuildingView buttons on top, untouched: the scenery
## camera frames exactly the diorama's rect, so each building stands on the
## dirt pad laid out for it here.
##
## Layout (town_cells): grass everywhere, a tree-lined blocked border, a dirt
## pad under every building with an L-shaped path to the castle, a flagstone
## plaza at the castle (a GOAL landmark) and a gate road leaving through the
## bottom edge (a SPAWN landmark, so the road runs off-screen).

const PROFILE_PATH: String = "res://assets/data/hd2d/sanctuary_town_scenery.tres"
## Town grid cell in diorama px (smaller than a mission's 64 so paths are
## narrow lanes rather than roads).
const CELL: float = 40.0
const CASTLE_ID: StringName = &"castle"

var _scenery: Hd2dScenery
var _built_size: Vector2i = Vector2i.ZERO


## (Re)builds for a diorama of `size_px` with these buildings. Cheap to call
## on every resize: it only rebuilds when the pixel size actually changed.
func setup(size_px: Vector2, buildings: Array[SanctuaryBuildingResource]) -> bool:
	var target := Vector2i(maxi(1, roundi(size_px.x)), maxi(1, roundi(size_px.y)))
	if target == _built_size:
		return false
	var profile: Hd2dSceneryProfile = load(PROFILE_PATH) as Hd2dSceneryProfile
	if profile == null:
		push_warning("[Hd2dTownBackdrop] no profile at %s" % PROFILE_PATH)
		return false
	own_world_3d = true
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	size = target
	if _scenery == null:
		_scenery = Hd2dScenery.new()
		_scenery.name = "Hd2dScenery"
		add_child(_scenery)
	_scenery.profile = profile
	var cols: int = ceili(target.x / CELL)
	var rows: int = ceili(target.y / CELL)
	_scenery.build(cols, rows, CELL, town_cells(cols, rows, CELL, buildings))
	_scenery.frame_rect(Rect2(Vector2.ZERO, Vector2(target)))
	_built_size = target
	return true


func get_scenery() -> Hd2dScenery:
	return _scenery


## Pure layout: Vector2i -> Grid.CellType for a cols x rows town.
static func town_cells(cols: int, rows: int, cell: float, buildings: Array[SanctuaryBuildingResource]) -> Dictionary:
	var cells: Dictionary = {}
	for y in rows:
		for x in cols:
			var border: bool = x == 0 or y == 0 or x == cols - 1 or y == rows - 1
			cells[Vector2i(x, y)] = Grid.CellType.BLOCKED if border else Grid.CellType.PLACEABLE
	var castle: Vector2i = Vector2i(cols / 2, rows / 3)
	for b: SanctuaryBuildingResource in buildings:
		if b.building_id == CASTLE_ID:
			castle = _base_cell(b, cell, cols, rows)
	# Dirt pad under each building and an L-shaped path to the castle.
	for b: SanctuaryBuildingResource in buildings:
		var base: Vector2i = _base_cell(b, cell, cols, rows)
		var half_w: int = maxi(1, floori(b.footprint.x * 0.5 / cell))
		for dx in range(-half_w, half_w + 1):
			_set_path(cells, Vector2i(clampi(base.x + dx, 1, cols - 2), base.y))
		_path_l(cells, base, castle)
	# Gate road: straight down from the castle's column out of the bottom edge.
	var gate := Vector2i(castle.x, rows - 1)
	_path_l(cells, Vector2i(castle.x, rows - 2), castle)
	cells[gate] = Grid.CellType.SPAWN
	cells[castle] = Grid.CellType.GOAL
	return cells


static func _base_cell(b: SanctuaryBuildingResource, cell: float, cols: int, rows: int) -> Vector2i:
	# `position` is the footprint's bottom centre; the pad sits just above it.
	var p: Vector2 = b.position - Vector2(0.0, cell * 0.4)
	return Vector2i(clampi(floori(p.x / cell), 1, cols - 2), clampi(floori(p.y / cell), 1, rows - 2))


static func _set_path(cells: Dictionary, c: Vector2i) -> void:
	var t: int = cells.get(c, Grid.CellType.PLACEABLE)
	if t != Grid.CellType.SPAWN and t != Grid.CellType.GOAL:
		cells[c] = Grid.CellType.PATH


## Horizontal leg along `from`'s row, then vertical leg along `to`'s column.
static func _path_l(cells: Dictionary, from: Vector2i, to: Vector2i) -> void:
	var x: int = from.x
	var step_x: int = signi(to.x - from.x)
	while x != to.x:
		_set_path(cells, Vector2i(x, from.y))
		x += step_x
	var y: int = from.y
	var step_y: int = signi(to.y - from.y)
	while y != to.y:
		_set_path(cells, Vector2i(to.x, y))
		y += step_y
