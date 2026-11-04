## Free-flow movement (ADR-0006 amendment 2026-11-04): monsters round corners
## inside the corner cell and spread sideways across the lane, while the route
## anchor (path_step_index, monster_cell_entered) keeps walking cell centres.
extends GdUnitTestSuite

class _StubGrid extends RefCounted:
	func get_cell_type(_cell: Vector2i) -> int:
		return Grid.CellType.SPAWN

	func cell_to_world(cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x) * 64.0, float(cell.y) * 64.0)

	func world_to_cell(pos: Vector2) -> Vector2i:
		return Vector2i(roundi(pos.x / 64.0), roundi(pos.y / 64.0))

	func get_towers_in_range(_center: Vector2i, _radius: int) -> Array[int]:
		return []


class _StubPathfinding extends RefCounted:
	var path: Array[Vector2i] = []

	func find_path(_from: Vector2i, _tier: int) -> Array[Vector2i]:
		return path


const SPAWN_CELL := Vector2i(0, 0)
const DELTA := 1.0 / 60.0
const CELL := 64.0
## Turns at the very first route cell, then zigzags: every kind of corner.
const ZIGZAG: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
	Vector2i(3, 1), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0),
]
const STRAIGHT: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]

var _mm: MonsterManager
var _stub_path: _StubPathfinding


func before_test() -> void:
	_stub_path = _StubPathfinding.new()
	_mm = MonsterManager.new()
	add_child(_mm)
	_mm._grid = _StubGrid.new()
	_mm._pathfinding = _stub_path
	_mm._is_wave_active = true
	_mm._current_wave_index = 1


func after_test() -> void:
	for e: MonsterEntity in _mm.active_monsters:
		if is_instance_valid(e):
			e.free()
	remove_child(_mm)
	_mm.free()


func _spawn(path: Array[Vector2i], tier: int = 0) -> MonsterEntity:
	_stub_path.path = path.duplicate()
	var res := MonsterResource.new()
	res.monster_id = &"flow_mover"
	res.display_name = "Flow Mover"
	res.tier = tier
	res.base_hp = 100.0
	res.base_speed = 1.0
	res.drop_table_id = &"drops"
	res.menagerie_attraction_drop_chance = 0.0
	_mm._resource_table[res.monster_id] = res
	return _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)


## Chebyshev distance (in world units) from `pos` to the nearest route cell
## centre, spawn included. <= half a cell means the position is inside a route cell.
func _distance_outside_route(pos: Vector2, path: Array[Vector2i]) -> float:
	var best: float = INF
	for cell: Vector2i in [SPAWN_CELL] + path:
		var c := Vector2(cell) * CELL
		best = minf(best, maxf(absf(pos.x - c.x), absf(pos.y - c.y)))
	return best


func test_free_flow_straight_route_without_spread_matches_the_anchor() -> void:
	_mm.lane_spread_cells = 0.0
	var m := _spawn(STRAIGHT)
	for _i in 90:
		_mm._pass3_movement(DELTA)
		if m.lifecycle_state != MonsterEntity.State.ACTIVE:
			break
		assert_vector(m.global_position).is_equal_approx(m.path_anchor, Vector2(0.001, 0.001))


func test_free_flow_corner_is_rounded_not_sharp() -> void:
	_mm.lane_spread_cells = 0.0
	var path: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	var m := _spawn(path)
	var corner := Vector2(2, 0) * CELL
	var closest: float = INF
	for _i in 200:
		_mm._pass3_movement(DELTA)
		if m.lifecycle_state != MonsterEntity.State.ACTIVE:
			break
		closest = minf(closest, m.global_position.distance_to(corner))
	# Bezier apex sits r * sqrt(2) / 4 from the corner centre (r = half a cell).
	assert_float(closest).is_equal_approx(0.5 * CELL * sqrt(2.0) / 4.0, 0.6)


func test_free_flow_never_leaves_the_route_cells_with_full_spread() -> void:
	for id_offset: int in 8:
		_mm._entity_id_counter = id_offset  # walk a range of lane offsets
		var m := _spawn(ZIGZAG)
		for _i in 700:
			_mm._pass3_movement(DELTA)
			if m.lifecycle_state != MonsterEntity.State.ACTIVE:
				break
			var outside: float = _distance_outside_route(m.global_position, ZIGZAG)
			assert_float(outside).override_failure_message(
					"lane %.2f left the route at %s" % [m.lane_offset, m.global_position]
			).is_less_equal(CELL * 0.5 + 0.01)


func test_free_flow_moves_continuously_through_every_corner() -> void:
	_mm._entity_id_counter = 2
	var m := _spawn(ZIGZAG)
	var last: Vector2 = m.global_position
	var step_budget: float = _mm._effective_speed(m) * CELL * DELTA
	for _i in 700:
		_mm._pass3_movement(DELTA)
		if m.lifecycle_state != MonsterEntity.State.ACTIVE:
			break
		# Corners make the curve shorter than the anchor's walk, and the lane offset
		# swings round them, so allow headroom, but never a teleport.
		assert_float(m.global_position.distance_to(last)).is_less(step_budget * 2.0)
		last = m.global_position


func test_free_flow_route_anchor_still_steps_cell_centres() -> void:
	var m := _spawn(ZIGZAG)
	var entered: Array[Vector2i] = []
	var record := func(_id: int, cell: Vector2i, _step: int) -> void: entered.append(cell)
	GEventBus.monster_cell_entered.connect(record)
	for _i in 700:
		_mm._pass3_movement(DELTA)
		if m.lifecycle_state != MonsterEntity.State.ACTIVE:
			break
	GEventBus.monster_cell_entered.disconnect(record)
	assert_array(entered).is_equal(ZIGZAG)


func test_free_flow_lane_offsets_spread_and_bosses_walk_the_centre() -> void:
	var offsets: Array[float] = []
	for id: int in range(1, 6):
		var o: float = MonsterManager.lane_offset_for(id, 0)
		assert_float(o).is_between(-1.0, 1.0)
		offsets.append(o)
	offsets.sort()
	for i: int in range(1, offsets.size()):
		assert_float(offsets[i] - offsets[i - 1]).is_greater(0.1)
	assert_float(MonsterManager.lane_offset_for(3, 2)).is_equal(0.0)
	assert_float(MonsterManager.lane_offset_for(7, 0)).is_equal(MonsterManager.lane_offset_for(7, 0))
