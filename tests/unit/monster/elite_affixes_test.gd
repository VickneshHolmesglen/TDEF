## Elite affixes (design/quick-specs/elite-affixes-2026-11-04.md): every ELITE
## spawn rolls Swift / Fortified / Regenerating / Vengeful.
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
		return [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]


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


func _res(id: StringName, tier: int) -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = id
	res.display_name = String(id)
	res.tier = tier
	res.base_hp = 100.0
	res.base_speed = 1.0
	res.drop_table_id = &"goblin_drops"
	_mm._resource_table[id] = res
	return res


func _spawn(id: StringName, roll_affix: bool = true) -> MonsterEntity:
	return _mm.spawn_monster(id, Vector2i(0, 0), 1, 1, 1.0, roll_affix)


func test_elite_affix_only_elites_roll_and_splits_do_not() -> void:
	assert_str(String(_mm._roll_affix(_res(&"grunt", 0), false))).is_empty()
	assert_str(String(_mm._roll_affix(_res(&"king", 2), false))).is_empty()
	assert_str(String(_mm._roll_affix(_res(&"elite", 1), true))).is_empty()
	assert_bool(MonsterManager.ELITE_AFFIXES.has(_mm._roll_affix(_res(&"elite2", 1), false))).is_true()


func test_elite_affix_every_affix_is_reachable() -> void:
	_res(&"elite", 1)
	var seen: Dictionary = {}
	_mm.affix_rng.seed = 7
	for i: int in 40:
		seen[_mm._roll_affix(_mm._resource_table[&"elite"], false)] = true
	assert_int(seen.size()).is_equal(MonsterManager.ELITE_AFFIXES.size())


func test_elite_affix_swift_and_fortified_scale_spawn_stats() -> void:
	# Arrange: spawn elites until both stat affixes have appeared.
	_res(&"elite", 1)
	_res(&"grunt", 0)
	var base: MonsterEntity = _spawn(&"grunt")
	assert_str(String(_spawn(&"elite", false).affix)).is_empty()  # direct spawns never roll
	var checked: Dictionary = {}
	_mm.affix_rng.seed = 11
	for i: int in 40:
		var m: MonsterEntity = _spawn(&"elite")
		# Assert per affix
		match m.affix:
			&"swift":
				assert_float(m.scaled_speed).is_equal_approx(base.scaled_speed * MonsterManager.AFFIX_SWIFT_SPEED_MULT, 0.0001)
				checked[&"swift"] = true
			&"fortified":
				assert_float(m.scaled_hp).is_equal_approx(base.scaled_hp * MonsterManager.AFFIX_FORTIFIED_HP_MULT, 0.0001)
				assert_float(m.current_hp).is_equal_approx(m.scaled_hp, 0.0001)
				checked[&"fortified"] = true
			_:
				assert_float(m.scaled_hp).is_equal_approx(base.scaled_hp, 0.0001)
		assert_str(String(m.monster_instance.get_affix())).is_equal(String(m.affix))
		if checked.size() == 2:
			break
	assert_int(checked.size()).is_equal(2)


func test_elite_affix_regenerating_heals_over_time_capped_at_max() -> void:
	# Arrange
	_res(&"elite", 1)
	var m: MonsterEntity = _spawn(&"elite")
	m.affix = &"regenerating"
	m.lifecycle_state = MonsterEntity.State.ACTIVE
	m.current_hp = m.scaled_hp * 0.5
	# Act: 2 s at 1.5 %/s
	_mm._pass2c_archetype_behaviours(2.0)
	# Assert
	assert_float(m.current_hp).is_equal_approx(m.scaled_hp * 0.53, 0.001)
	_mm._pass2c_archetype_behaviours(1000.0)
	assert_float(m.current_hp).is_equal_approx(m.scaled_hp, 0.0001)


func test_elite_affix_vengeful_death_hastes_nearby_monsters_only() -> void:
	# Arrange
	_res(&"elite", 1)
	_res(&"grunt", 0)
	var elite: MonsterEntity = _spawn(&"elite")
	elite.affix = &"vengeful"
	var near: MonsterEntity = _spawn(&"grunt")
	var far: MonsterEntity = _spawn(&"grunt")
	for m: MonsterEntity in [elite, near, far]:
		m.lifecycle_state = MonsterEntity.State.ACTIVE
	elite.global_position = Vector2(100.0, 100.0)
	near.global_position = Vector2(160.0, 100.0)
	far.global_position = Vector2(900.0, 100.0)
	var near_base: float = _mm._effective_speed(near)
	# Act
	_mm._apply_status_damage(elite, 1.0e9, &"tower")
	# Assert
	assert_float(_mm._effective_speed(near)).is_equal_approx(near_base * MonsterManager.AFFIX_VENGEFUL_HASTE_MULT, 0.0001)
	assert_float(far.haste_remaining).is_equal(0.0)


func test_elite_affix_death_event_carries_affix_and_reward_multiplier() -> void:
	# Arrange
	_res(&"elite", 1)
	var elite: MonsterEntity = _spawn(&"elite")
	elite.affix = &"fortified"
	elite.lifecycle_state = MonsterEntity.State.ACTIVE
	# Act
	_mm._apply_status_damage(elite, 1.0e9, &"tower")
	# Assert
	var ev: MonsterDiedEvent = _mm._pending_deaths.back()
	assert_str(String(ev.affix)).is_equal("fortified")
	assert_float(MonsterManager.affix_reward_multiplier(ev.affix)).is_equal(MonsterManager.AFFIX_REWARD_MULT)
	assert_float(MonsterManager.affix_reward_multiplier(&"")).is_equal(1.0)
