extends GdUnitTestSuite

## Unit tests for MonsterManager.apply_dot() and its group membership
## (equipment-set-effects spec §3.6, AC-11). Stub/fixture pattern mirrors
## monster_status_effect_test.gd exactly.

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
		return [Vector2i(1, 0), Vector2i(2, 0)]


const SPAWN_CELL := Vector2i(0, 0)

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
	remove_child(_mm)
	_mm.free()


func _spawn(base_hp: float) -> MonsterEntity:
	var res := MonsterResource.new()
	res.monster_id = &"goblin"
	res.display_name = "Test Monster"
	res.tier = 0
	res.base_hp = base_hp
	res.base_speed = 1.0
	res.drop_table_id = &"goblin_drops"
	res.menagerie_attraction_drop_chance = 0.05
	_mm._resource_table[&"goblin"] = res
	return _mm.spawn_monster(&"goblin", SPAWN_CELL, 1, 1)


func test_manager_joins_the_monster_manager_group() -> void:
	assert_bool(_mm.is_in_group(MonsterManager.GROUP_NAME)).is_true()
	assert_bool(MonsterManager.GROUP_NAME == &"monster_manager").is_true()


func test_apply_dot_creates_the_same_instance_as_the_tower_path() -> void:
	var via_tower: MonsterEntity = _spawn(200.0)
	_mm._on_tower_attacked_status(1, via_tower.entity_id, 0.0, false, false, "burn", 0.10, 3.0, 0.0, false)
	var via_api: MonsterEntity = _spawn(200.0)
	_mm.apply_dot(via_api.entity_id, "burn", 0.10, 3.0)
	assert_int(via_api.active_status_effects.size()).is_equal(1)
	var expected: ActiveStatusEffect = via_tower.active_status_effects[0]
	var actual: ActiveStatusEffect = via_api.active_status_effects[0]
	assert_str(actual.effect_type).is_equal(expected.effect_type)
	assert_int(actual.ticks_remaining).is_equal(expected.ticks_remaining)
	assert_float(actual.tick_damage).is_equal_approx(expected.tick_damage, 0.0001)


func test_apply_dot_stacks_with_existing_instances() -> void:
	var entity: MonsterEntity = _spawn(200.0)
	_mm.apply_dot(entity.entity_id, "poison", 0.06, 4.0)
	_mm.apply_dot(entity.entity_id, "poison", 0.06, 4.0)
	assert_int(entity.active_status_effects.size()).is_equal(2)


func test_apply_dot_ignores_an_unrecognized_effect_type() -> void:
	var entity: MonsterEntity = _spawn(200.0)
	_mm.apply_dot(entity.entity_id, "nonsense", 0.06, 4.0)
	assert_int(entity.active_status_effects.size()).is_equal(0)


func test_apply_dot_on_an_unknown_target_is_a_no_op() -> void:
	_mm.apply_dot(99999, "burn", 0.10, 3.0)
	assert_int(_mm.active_monsters.size()).is_equal(0)
