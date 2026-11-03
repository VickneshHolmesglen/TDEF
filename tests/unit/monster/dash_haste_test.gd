extends GdUnitTestSuite

## Dash and haste archetype behaviours (2026-11-04, design/quick-specs/
## dash-haste-enemies-2026-11-04.md). Rift Hound bursts to dash_speed_multiplier
## on a timer; a stun cancels the burst. Goblin Drummer hastes OTHER monsters
## in its radius; pulses refresh, never stack. Stub pattern mirrors
## monster_skill_secondary_effects_test.gd.

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


func _spawn(res: MonsterResource, cell: Vector2i) -> MonsterEntity:
	_mm._resource_table[res.monster_id] = res
	return _mm.spawn_monster(res.monster_id, cell, 1, 1)


func _plain(id: StringName) -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = id
	res.display_name = String(id)
	res.base_hp = 100.0
	res.base_speed = 1.0
	res.drop_table_id = &"goblin_drops"
	return res


func _hound() -> MonsterResource:
	var res := _plain(&"hound")
	res.dash_speed_multiplier = 2.5
	res.dash_duration_seconds = 0.5
	res.dash_interval_seconds = 2.0
	return res


func _drummer() -> MonsterResource:
	var res := _plain(&"drummer")
	res.haste_radius_cells = 2
	res.haste_speed_multiplier = 1.4
	res.haste_duration_seconds = 2.0
	res.haste_interval_seconds = 1.0
	return res


func test_monster_dasher_bursts_after_interval_then_returns_to_base_speed() -> void:
	# Arrange
	var m := _spawn(_hound(), Vector2i(0, 0))
	var base: float = _mm._effective_speed(m)
	# Act: just short of the interval, then past it
	_mm._pass2c_archetype_behaviours(1.9)
	assert_float(_mm._effective_speed(m)).is_equal_approx(base, 0.0001)
	_mm._pass2c_archetype_behaviours(0.2)
	# Assert: dashing at 2.5x, then back to base once the 0.5 s burst ends
	assert_float(_mm._effective_speed(m)).is_equal_approx(base * 2.5, 0.0001)
	_mm._pass2c_archetype_behaviours(0.6)
	assert_float(_mm._effective_speed(m)).is_equal_approx(base, 0.0001)


func test_monster_stun_cancels_a_dash() -> void:
	var m := _spawn(_hound(), Vector2i(0, 0))
	_mm._pass2c_archetype_behaviours(2.1)
	assert_float(m.dash_remaining).is_greater(0.0)
	m.stun_remaining = 1.0
	_mm._pass2c_archetype_behaviours(0.01)
	assert_float(m.dash_remaining).is_equal(0.0)


func test_monster_drummer_hastes_allies_in_radius_but_not_itself() -> void:
	# Arrange: ally 2 cells away (in radius), another 4 away (out)
	var drummer := _spawn(_drummer(), Vector2i(0, 0))
	var near := _spawn(_plain(&"near"), Vector2i(2, 0))
	var far := _spawn(_plain(&"far"), Vector2i(4, 0))
	var base: float = _mm._effective_speed(near)
	# Act
	_mm._pass2c_archetype_behaviours(1.0)
	# Assert
	assert_float(_mm._effective_speed(near)).is_equal_approx(base * 1.4, 0.0001)
	assert_float(far.haste_remaining).is_equal(0.0)
	assert_float(drummer.haste_remaining).is_equal(0.0)


func test_monster_haste_refreshes_without_stacking_and_expires() -> void:
	_spawn(_drummer(), Vector2i(0, 0))
	var ally := _spawn(_plain(&"ally"), Vector2i(1, 0))
	var base: float = _mm._effective_speed(ally)
	_mm._pass2c_archetype_behaviours(1.0)
	_mm._pass2c_archetype_behaviours(1.0)  # second pulse
	assert_float(_mm._effective_speed(ally)).is_equal_approx(base * 1.4, 0.0001)
	# Drummer dies; the last haste wears off after its duration.
	_mm.active_monsters[0].lifecycle_state = MonsterEntity.State.DEAD
	_mm._pass2c_archetype_behaviours(2.1)
	assert_float(_mm._effective_speed(ally)).is_equal_approx(base, 0.0001)


func test_monster_haste_shows_a_status_pip() -> void:
	var ally := _spawn(_plain(&"ally"), Vector2i(1, 0))
	ally.haste_remaining = 1.0
	assert_array(MonsterInstance.statuses_from_bits(MonsterManager.status_bits_for(ally))) \
			.contains_exactly([&"haste"])


func test_monster_dash_haste_content_is_valid_and_flagged() -> void:
	var hound: MonsterResource = load("res://assets/data/monsters/rift_hound.tres")
	var drummer: MonsterResource = load("res://assets/data/monsters/goblin_drummer.tres")
	for res: MonsterResource in [hound, drummer]:
		assert_array(res.validate()).is_empty()
		assert_bool(MonsterInstance.MONSTER_TEXTURES.has(res.monster_id)).is_true()
	assert_bool(hound.is_dasher()).is_true()
	assert_bool(drummer.is_haster()).is_true()
	assert_bool(hound.is_haster() or drummer.is_dasher()).is_false()


func test_monster_resource_rejects_out_of_range_dash_and_haste() -> void:
	var res := _plain(&"bad")
	res.dash_speed_multiplier = 9.0
	res.haste_speed_multiplier = 0.5
	assert_int(res.validate().size()).is_equal(2)
