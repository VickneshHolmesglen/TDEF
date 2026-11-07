extends GdUnitTestSuite

## Hero water debuff (spec 2026-11-07-3d-terrain §4.3): ×water_hero_speed_mult
## move speed while in water and for water_hero_linger_seconds after leaving,
## refreshed (never stacked) on re-entry; a true multiplier after the additive
## fold. Fixture: grid_terrain_test (4,2) is water, (0,3) is dry.

const WET := Vector2i(4, 2)
const DRY := Vector2i(0, 3)

var _hero: Hero
var _spy: EventBusSpy


func before_test() -> void:
	GGrid.initialize(load("res://tests/unit/grid/grid_terrain_test.gd").make_config())
	_hero = Hero.new()
	add_child(_hero)
	_hero.set_process(false)
	_hero.set_physics_process(false)
	_hero._base_stats[&"move_speed"] = 100.0


func after_test() -> void:
	if _spy != null:
		_spy.disconnect_all()
		_spy = null
	remove_child(_hero)
	_hero.free()
	GGrid.initialize(GridConfig.new())


func _at(cell: Vector2i, delta: float) -> void:
	_hero.global_position = GGrid.cell_to_world(cell)
	_hero._tick_water_debuff(delta)


func test_hero_in_water_move_speed_times_0_7() -> void:
	_at(WET, 0.1)
	assert_bool(_hero.is_water_debuffed()).is_true()
	assert_float(_hero.get_effective_stat(&"move_speed")).is_equal_approx(70.0, 0.001)


func test_hero_dry_full_speed() -> void:
	_at(DRY, 0.1)
	assert_bool(_hero.is_water_debuffed()).is_false()
	assert_float(_hero.get_effective_stat(&"move_speed")).is_equal_approx(100.0, 0.001)


func test_hero_debuff_lingers_3s_after_leaving() -> void:
	_at(WET, 0.1)
	_at(DRY, 2.9)
	assert_bool(_hero.is_water_debuffed()).is_true()
	assert_float(_hero.get_effective_stat(&"move_speed")).is_equal_approx(70.0, 0.001)
	_at(DRY, 0.2)
	assert_bool(_hero.is_water_debuffed()).is_false()
	assert_float(_hero.get_effective_stat(&"move_speed")).is_equal_approx(100.0, 0.001)


func test_hero_water_reentry_refreshes_not_stacks() -> void:
	_at(WET, 0.1)
	_at(DRY, 2.0)
	_at(WET, 5.0)  # standing in water for a long time keeps it topped up
	assert_float(_hero.get_effective_stat(&"move_speed")).is_equal_approx(70.0, 0.001)
	_at(DRY, 0.0)
	assert_float(_hero.water_debuff_remaining).is_equal_approx(3.0, 0.001)
	_at(DRY, 2.9)
	assert_bool(_hero.is_water_debuffed()).is_true()
	_at(DRY, 0.2)
	assert_bool(_hero.is_water_debuffed()).is_false()


func test_hero_water_multiplier_after_gear() -> void:
	_hero._additive_bonuses[&"move_speed"] = 0.3
	_at(WET, 0.1)
	assert_float(_hero.get_effective_stat(&"move_speed")).is_equal_approx(100.0 * 1.3 * 0.7, 0.001)


func test_water_immunity_clears_and_blocks() -> void:
	_at(WET, 0.1)
	_hero.set_water_immunity(true)
	assert_bool(_hero.is_water_debuffed()).is_false()
	_at(WET, 0.1)
	assert_bool(_hero.is_water_debuffed()).is_false()
	_hero.set_water_immunity(false)
	_at(WET, 0.1)
	assert_bool(_hero.is_water_debuffed()).is_true()


func test_debuff_signal_fires_on_edges_only() -> void:
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_water_debuff_changed)
	_at(WET, 0.1)
	_at(WET, 0.1)
	_at(DRY, 3.5)
	assert_int(_spy.count("hero_water_debuff_changed")).is_equal(2)
	var calls: Array = _spy.emissions["hero_water_debuff_changed"] as Array
	assert_bool((calls[0] as Array)[0] as bool).is_true()
	assert_bool((calls[1] as Array)[0] as bool).is_false()
