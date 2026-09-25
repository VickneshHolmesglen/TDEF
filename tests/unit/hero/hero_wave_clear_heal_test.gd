extends GdUnitTestSuite

## Unit tests for Hero's wave-clear partial heal (hero-damage spec §4.5, AC-7).

var _hero: Hero


func before_test() -> void:
	GInventory.reset_to_defaults()
	_hero = Hero.new()
	add_child(_hero)
	_hero.set_process(false)
	_hero._max_hp = 500.0


func after_test() -> void:
	GInventory.reset_to_defaults()
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


func test_wave_clear_heals_a_quarter_of_max_hp() -> void:
	_hero._phase = Hero.HeroPhase.COMBAT
	_hero._current_hp = 100.0
	_hero._on_wave_completed(1, 0, false)
	assert_float(_hero._current_hp).is_equal_approx(225.0, 0.0001)


func test_wave_clear_heal_is_clamped_to_max_hp() -> void:
	_hero._phase = Hero.HeroPhase.COMBAT
	_hero._current_hp = 450.0
	_hero._on_wave_completed(1, 0, false)
	assert_float(_hero._current_hp).is_equal_approx(500.0, 0.0001)


func test_wave_clear_heal_applies_during_intermission() -> void:
	_hero._phase = Hero.HeroPhase.INTERMISSION
	_hero._current_hp = 100.0
	_hero._on_wave_completed(1, 0, false)
	assert_float(_hero._current_hp).is_equal_approx(225.0, 0.0001)


func test_wave_clear_never_heals_a_dead_hero() -> void:
	_hero._phase = Hero.HeroPhase.DEAD
	_hero._current_hp = 0.0
	_hero._on_wave_completed(1, 0, false)
	assert_float(_hero._current_hp).is_equal_approx(0.0, 0.0001)


func test_wave_clear_heal_emits_hero_health_changed() -> void:
	_hero._phase = Hero.HeroPhase.COMBAT
	_hero._current_hp = 100.0
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.hero_health_changed)
	_hero._on_wave_completed(1, 0, false)
	assert_int(spy.count("hero_health_changed")).is_equal(1)
	spy.disconnect_all()


func test_wave_clear_with_zero_max_hp_is_a_no_op() -> void:
	_hero._max_hp = 0.0
	_hero._phase = Hero.HeroPhase.COMBAT
	_hero._current_hp = 0.0
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.hero_health_changed)
	_hero._on_wave_completed(1, 0, false)
	assert_int(spy.count("hero_health_changed")).is_equal(0)
	spy.disconnect_all()


func test_the_heal_fraction_constant_is_a_quarter() -> void:
	assert_float(Hero.WAVE_CLEAR_HEAL_FRACTION).is_equal_approx(0.25, 0.0001)
