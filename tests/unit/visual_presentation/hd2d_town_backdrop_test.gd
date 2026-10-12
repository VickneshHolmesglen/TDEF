extends GdUnitTestSuite

## ADR-0042 dioramas pass: the Sanctuary town layout (Hd2dTownBackdrop.town_cells).

const COLS := 24
const ROWS := 17
const CELL := 40.0


func _building(id: StringName, pos: Vector2) -> SanctuaryBuildingResource:
	var b := SanctuaryBuildingResource.new()
	b.building_id = id
	b.position = pos
	b.footprint = Vector2(120, 150)
	return b


func _buildings() -> Array[SanctuaryBuildingResource]:
	return [_building(&"castle", Vector2(480, 280)), _building(&"armoury", Vector2(110, 440)),
		_building(&"seers_tower", Vector2(800, 280)), _building(&"keep", Vector2(650, 585))]


func _reachable(cells: Dictionary, from: Vector2i, to: Vector2i) -> bool:
	var walk := [Grid.CellType.PATH, Grid.CellType.GOAL, Grid.CellType.SPAWN]
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			return true
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if not seen.has(n) and cells.has(n) and walk.has(cells[n]):
				seen[n] = true
				queue.append(n)
	return false


func test_town_cells_castle_is_the_plaza_landmark() -> void:
	var cells: Dictionary = Hd2dTownBackdrop.town_cells(COLS, ROWS, CELL, _buildings())
	var castle := Hd2dTownBackdrop._base_cell(_buildings()[0], CELL, COLS, ROWS)
	assert_int(cells[castle]).is_equal(Grid.CellType.GOAL)


func test_town_cells_gate_sits_on_the_bottom_edge() -> void:
	var cells: Dictionary = Hd2dTownBackdrop.town_cells(COLS, ROWS, CELL, _buildings())
	var gates: Array = cells.keys().filter(func(c: Vector2i) -> bool: return cells[c] == Grid.CellType.SPAWN)
	assert_int(gates.size()).is_equal(1)
	assert_int((gates[0] as Vector2i).y).is_equal(ROWS - 1)


func test_town_cells_every_building_and_the_gate_connect_to_the_castle() -> void:
	var cells: Dictionary = Hd2dTownBackdrop.town_cells(COLS, ROWS, CELL, _buildings())
	var castle := Hd2dTownBackdrop._base_cell(_buildings()[0], CELL, COLS, ROWS)
	for b: SanctuaryBuildingResource in _buildings():
		var base := Hd2dTownBackdrop._base_cell(b, CELL, COLS, ROWS)
		assert_bool(_reachable(cells, base, castle)).override_failure_message("%s not connected" % b.building_id).is_true()
	assert_bool(_reachable(cells, Vector2i(castle.x, ROWS - 1), castle)).is_true()


func test_town_cells_border_is_blocked_except_the_gate() -> void:
	var cells: Dictionary = Hd2dTownBackdrop.town_cells(COLS, ROWS, CELL, _buildings())
	for c: Vector2i in cells:
		var border: bool = c.x == 0 or c.y == 0 or c.x == COLS - 1 or c.y == ROWS - 1
		if border and cells[c] != Grid.CellType.SPAWN:
			assert_int(cells[c]).override_failure_message("border cell %s" % c).is_equal(Grid.CellType.BLOCKED)
