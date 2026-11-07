extends GdUnitTestSuite

## Hill towers reach further on every range, hero class proximity included
## (spec 2026-11-07-3d-terrain §4.2): radius CLASS_PROXIMITY_RADIUS + level.

var _hero: Hero


func after_test() -> void:
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


func _make_hero() -> Hero:
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[&"move_speed"] = 0.0
	_hero.set_process(false)
	return _hero


func _place(id: int, cell: Vector2i, level: int) -> void:
	var payload := TowerPlacedEvent.make(id, cell, "FROST", Vector2i.ONE, true, "")
	payload.terrain_level = level
	GEventBus.tower_placed.emit(payload)


func test_class_proximity_radius_plus_level() -> void:
	var hero := _make_hero()
	hero.global_position = GGrid.cell_to_world(Vector2i(5, 5))
	_place(2001, Vector2i(9, 5), 1)  # Chebyshev 4 = radius 3 + 1
	hero._proximity_active = true
	hero._physics_process(1.0)
	assert_float(hero._proximity_time.get(&"FROST", 0.0)).is_equal_approx(1.0, 0.0001)


func test_class_proximity_flat_tower_at_four_not_counted() -> void:
	var hero := _make_hero()
	hero.global_position = GGrid.cell_to_world(Vector2i(5, 5))
	_place(2002, Vector2i(9, 5), 0)
	hero._proximity_active = true
	hero._physics_process(1.0)
	assert_float(hero._proximity_time.get(&"FROST", 0.0)).is_equal_approx(0.0, 0.0001)
