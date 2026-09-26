## Terminal-phase / Retry cleanup for MonsterManager (Mission Outcome Screen
## review findings I3/I4). Handlers are called directly -- never emit the real
## global-bus signals (live autoloads react to them).
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
		return [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]


const SPAWN_CELL := Vector2i(0, 0)

var _mm: MonsterManager


func _make_resource() -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = &"goblin"
	res.display_name = "Test Monster"
	res.tier = 0
	res.base_hp = 100.0
	res.base_speed = 1.0
	res.drop_table_id = &"goblin_drops"
	res.menagerie_attraction_drop_chance = 0.05
	return res


func before_test() -> void:
	_mm = MonsterManager.new()
	add_child(_mm)
	_mm._grid = _StubGrid.new()
	_mm._pathfinding = _StubPathfinding.new()
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	_mm._resource_table = {&"goblin": _make_resource()}
	_mm.set_physics_process(false)


func after_test() -> void:
	for e: MonsterEntity in _mm.active_monsters:
		if is_instance_valid(e):
			e.free()
	remove_child(_mm)
	_mm.free()


func _spawn_three() -> Array[MonsterEntity]:
	var out: Array[MonsterEntity] = []
	for i in 3:
		out.append(_mm.spawn_monster(&"goblin", SPAWN_CELL, 1, 1))
	return out


func test_mission_launched_frees_all_entities_and_clears_lookup() -> void:
	var ents := _spawn_three()
	assert_int(_mm.active_monsters.size()).is_equal(3)
	_mm._on_mission_launched("m", PackedStringArray(), 1)
	await get_tree().process_frame
	for e in ents:
		assert_bool(is_instance_valid(e)).is_false()
	assert_int(_mm.active_monsters.size()).is_equal(0)
	assert_int(_mm.spawning_entities.size()).is_equal(0)
	assert_int(_mm._entity_lookup.size()).is_equal(0)
	assert_bool(_mm._is_wave_active).is_false()


func test_mission_launched_does_not_emit_monster_died() -> void:
	_spawn_three()
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.monster_died)
	_mm._on_mission_launched("m", PackedStringArray(), 1)
	assert_int(spy.count("monster_died")).is_equal(0)
	spy.disconnect_all()
	await get_tree().process_frame


func test_wave_completed_still_emits_wave_end_deaths_and_frees() -> void:
	var ents := _spawn_three()
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.monster_died)
	_mm._on_wave_completed(1, 0, false)
	assert_int(spy.count("monster_died")).is_equal(3)
	await get_tree().process_frame
	for e in ents:
		assert_bool(is_instance_valid(e)).is_false()
	assert_int(_mm.active_monsters.size()).is_equal(0)
	assert_int(_mm._entity_lookup.size()).is_equal(0)
	spy.disconnect_all()


func test_terminal_phase_stops_simulation_and_wave_started_rearms() -> void:
	var ents := _spawn_three()
	for phase in ["DEFEAT", "MISSION_COMPLETE"]:
		_mm._is_wave_active = true
		_mm._on_mission_phase_changed("WAVE_ACTIVE", phase, 0.0)
		assert_bool(_mm._is_wave_active).is_false()
	var before: Vector2 = ents[0].global_position
	_mm._physics_process(1.0)
	assert_vector(ents[0].global_position).is_equal(before)
	_mm._on_wave_started(1, 3, 1.0)
	assert_bool(_mm._is_wave_active).is_true()
	for e in ents:  # _on_wave_started clears the lists without freeing (unchanged behaviour)
		e.free()


func test_non_terminal_phase_change_leaves_wave_active() -> void:
	_mm._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	assert_bool(_mm._is_wave_active).is_true()


func test_exit_tree_disconnects_new_subscriptions() -> void:
	var mm := MonsterManager.new()
	add_child(mm)
	assert_bool(GEventBus.mission_launched.is_connected(mm._on_mission_launched)).is_true()
	assert_bool(GEventBus.mission_phase_changed.is_connected(mm._on_mission_phase_changed)).is_true()
	remove_child(mm)
	assert_bool(GEventBus.mission_launched.is_connected(mm._on_mission_launched)).is_false()
	assert_bool(GEventBus.mission_phase_changed.is_connected(mm._on_mission_phase_changed)).is_false()
	mm.free()
