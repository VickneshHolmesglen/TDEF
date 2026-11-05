## Regression: MonsterManager used to drop its monsters silently on wave start
## and on mission_launched (Retry), while entity ids restart at wave 1. Tower
## System and Hero kept the dropped ids in their target caches and fired at
## ghosts. Now every silent drop emits monsters_cleared and both caches reset.
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
var _spy: EventBusSpy


func before_test() -> void:
	_mm = MonsterManager.new()
	add_child(_mm)
	_mm._grid = _StubGrid.new()
	_mm._pathfinding = _StubPathfinding.new()
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	var res := MonsterResource.new()
	res.monster_id = &"grunt"
	res.display_name = "grunt"
	res.tier = 0
	res.base_hp = 100.0
	res.base_speed = 1.0
	_mm._resource_table = {&"grunt": res}
	_mm.set_physics_process(false)
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.monsters_cleared)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	_mm.clear_all_entities()
	_mm._pending_deaths.clear()
	remove_child(_mm)
	_mm.free()


func _spawn() -> MonsterEntity:
	return _mm.spawn_monster(&"grunt", Vector2i(0, 0), 1, 1, 1.0)


func test_monsters_cleared_mission_launch_with_live_monsters_announces_clear() -> void:
	# Arrange
	_spawn()
	# Act: Retry after a mid-wave defeat re-emits mission_launched
	_mm._on_mission_launched("m", PackedStringArray(), 1)
	# Assert
	assert_int(_spy.count("monsters_cleared")).is_equal(1)
	assert_bool(_mm.active_monsters.is_empty() and _mm.spawning_entities.is_empty()).is_true()


func test_monsters_cleared_wave_start_with_leftovers_releases_and_announces() -> void:
	# Arrange: a monster spawned outside a wave
	var leftover: MonsterEntity = _spawn()
	# Act
	_mm._on_wave_started(1, 5, 1.0)
	# Assert
	assert_int(_spy.count("monsters_cleared")).is_equal(1)
	assert_bool(leftover.is_queued_for_deletion()).is_true()
	assert_bool(_mm._entity_lookup.is_empty()).is_true()


func test_monsters_cleared_wave_start_with_nothing_left_stays_quiet() -> void:
	# Act
	_mm._on_wave_started(2, 5, 1.0)
	# Assert
	assert_int(_spy.count("monsters_cleared")).is_equal(0)


func test_monsters_cleared_tower_system_and_hero_forget_cached_monsters() -> void:
	# Arrange
	var ts := TowerSystem.new()
	var hero := Hero.new()
	ts._monster_cache[7] = {"cell": Vector2i(1, 0), "hp": 10.0}
	hero._monster_cache[7] = {"cell": Vector2i(1, 0)}
	# Act
	ts._on_monsters_cleared()
	hero._on_monsters_cleared()
	# Assert
	assert_bool(ts._monster_cache.is_empty()).is_true()
	assert_bool(hero._monster_cache.is_empty()).is_true()
	ts.free()
	hero.free()
