extends GdUnitTestSuite

## Water slows ground monsters while they stand in it (spec 2026-11-07-3d-terrain
## §4.3): ×water_monster_speed_mult, multiplicative with slows; flyers ignore it.
## Uses the grid_terrain_test fixture: (4,2) water, (2,1) a ford.

var _mm: MonsterManager
var _entities: Array[MonsterEntity] = []


func before_test() -> void:
	GGrid.initialize(load("res://tests/unit/grid/grid_terrain_test.gd").make_config())
	_mm = MonsterManager.new()


func after_test() -> void:
	for e: MonsterEntity in _entities:
		e.free()
	_entities.clear()
	_mm.free()
	GGrid.initialize(GridConfig.new())


func _entity(cell: Vector2i, movement: String = "ground") -> MonsterEntity:
	var e := MonsterEntity.new()
	e.resource = MonsterResource.new()
	e.resource.movement_type = movement
	e.scaled_speed = 2.0
	e.path_anchor = GGrid.cell_to_world(cell)
	_entities.append(e)
	return e


func test_ground_monster_in_water_speed_times_0_6() -> void:
	assert_float(_mm._effective_speed(_entity(Vector2i(4, 2)))).is_equal_approx(1.2, 0.0001)
	assert_float(_mm._effective_speed(_entity(Vector2i(2, 1)))).is_equal_approx(1.2, 0.0001)


func test_water_stacks_with_slow_multiplicatively() -> void:
	var e: MonsterEntity = _entity(Vector2i(4, 2))
	var slow := ActiveSlowEffect.new()
	slow.speed_multiplier = 0.5
	slow.remaining_duration = 1.0
	e.active_slow_effects.append(slow)
	assert_float(_mm._effective_speed(e)).is_equal_approx(2.0 * 0.3, 0.0001)


func test_flying_monster_ignores_water() -> void:
	assert_float(_mm._effective_speed(_entity(Vector2i(4, 2), "flying"))).is_equal_approx(2.0, 0.0001)


func test_monster_out_of_water_full_speed() -> void:
	assert_float(_mm._effective_speed(_entity(Vector2i(0, 1)))).is_equal_approx(2.0, 0.0001)
