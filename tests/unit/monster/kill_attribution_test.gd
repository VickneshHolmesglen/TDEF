## Tower veterancy kill attribution: MonsterManager credits a death to the last
## tower whose direct hit landed (DoT ticks keep that credit); hero kills
## credit no tower.
extends GdUnitTestSuite


class _StubGrid extends RefCounted:
	func get_cell_type(_cell: Vector2i) -> int:
		return Grid.CellType.SPAWN

	func cell_to_world(cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x) * 64.0, float(cell.y) * 64.0)

	func world_to_cell(pos: Vector2) -> Vector2i:
		return Vector2i(int(pos.x / 64.0), int(pos.y / 64.0))

	func get_towers_in_range(_center: Vector2i, _radius: int) -> Array[int]:
		return []


class _StubPathfinding extends RefCounted:
	func find_path(_from: Vector2i, _tier: int) -> Array[Vector2i]:
		return [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]


var _mm: MonsterManager


func before_test() -> void:
	_mm = MonsterManager.new()
	add_child(_mm)
	_mm._grid = _StubGrid.new()
	_mm._pathfinding = _StubPathfinding.new()
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	_mm._resource_table = {}
	_mm.set_physics_process(false)


func after_test() -> void:
	for e: MonsterEntity in _mm.active_monsters:
		if is_instance_valid(e):
			e.free()
	_mm._pending_deaths.clear()
	remove_child(_mm)
	_mm.free()


func _spawn(hp: float) -> MonsterEntity:
	var res := MonsterResource.new()
	res.monster_id = &"dummy"
	res.display_name = "dummy"
	res.base_hp = hp
	res.base_speed = 1.0
	res.drop_table_id = &"goblin_drops"
	_mm._resource_table[res.monster_id] = res
	return _mm.spawn_monster(res.monster_id, Vector2i(0, 0), 1, 1)


func _hit(entity: MonsterEntity, amount: int, source_type: int, tower_id: int) -> void:
	var ev := MonsterDamageTaken.new()
	ev.entity_id = entity.entity_id
	ev.amount = amount
	ev.source_type = source_type
	ev.source_tower_id = tower_id
	_mm._on_monster_damage_taken(ev)


func test_kill_attribution_tower_kill_credits_last_tower() -> void:
	# Arrange
	var m := _spawn(100.0)
	_hit(m, 10, 0, 3)
	_hit(m, 100000, 0, 5)
	# Act
	_mm._pass1_damage()
	# Assert
	assert_int(_mm._pending_deaths.size()).is_equal(1)
	assert_int(_mm._pending_deaths[0].killer_tower_id).is_equal(5)


func test_kill_attribution_hero_kill_credits_no_tower() -> void:
	var m := _spawn(100.0)
	_hit(m, 10, 0, 3)
	_hit(m, 100000, 1, -1)
	_mm._pass1_damage()
	assert_int(_mm._pending_deaths[0].killer_tower_id).is_equal(-1)


func test_kill_attribution_dot_kill_keeps_the_towers_credit() -> void:
	var m := _spawn(100.0)
	_hit(m, 10, 0, 8)
	_mm._pass1_damage()
	_mm._apply_status_damage(m, 100000.0, &"tower")
	assert_int(_mm._pending_deaths.size()).is_equal(1)
	assert_int(_mm._pending_deaths[0].killer_tower_id).is_equal(8)
