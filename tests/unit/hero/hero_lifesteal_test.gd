extends GdUnitTestSuite

## Unit tests for Hero's lifesteal overheal clamp (TD-story-001 AC-06, fixed 2026-07-08).
## GDD Formula 6: D&S computes heal_amount and emits hero_healed only when > 0
## (event_bus.gd doc comment); Hero's sole responsibility is the overheal clamp
## (design/gdd/damage-status.md: "Hero owns lifesteal clamping... and overheal
## clamping; D&S owns the heal-amount calculation").

var _hero: Hero


func before_test() -> void:
	_hero = Hero.new()
	add_child(_hero)  # triggers _ready(): collision shape, timers, EventBus subscriptions
	_hero.set_process(false)
	_hero._phase = Hero.HeroPhase.COMBAT
	_hero._max_hp = 100.0


func after_test() -> void:
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


func test_heal_within_missing_hp_applies_full_amount() -> void:
	_hero._current_hp = 80.0  # 20 missing

	GEventBus.hero_healed.emit(15)

	assert_float(_hero._current_hp).is_equal_approx(95.0, 0.0001)


func test_heal_exceeding_missing_hp_clamps_to_max_hp_no_overheal() -> void:
	_hero._current_hp = 80.0  # 20 missing

	GEventBus.hero_healed.emit(40)

	assert_float(_hero._current_hp).is_equal_approx(100.0, 0.0001)


func test_heal_at_full_hp_is_a_no_op() -> void:
	_hero._current_hp = 100.0

	GEventBus.hero_healed.emit(25)

	assert_float(_hero._current_hp).is_equal_approx(100.0, 0.0001)


func test_heal_emits_hero_health_changed_with_clamped_value() -> void:
	_hero._current_hp = 80.0
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.hero_health_changed)

	GEventBus.hero_healed.emit(40)

	assert_int(spy.count("hero_health_changed")).is_equal(1)
	var args: Array = (spy.emissions["hero_health_changed"] as Array)[0] as Array
	assert_float(args[0]).is_equal_approx(100.0, 0.0001)
	assert_float(args[1]).is_equal_approx(100.0, 0.0001)
	spy.disconnect_all()


func test_heal_outside_combat_or_intermission_is_a_no_op() -> void:
	_hero._phase = Hero.HeroPhase.SCOUT
	_hero._current_hp = 80.0

	GEventBus.hero_healed.emit(15)

	assert_float(_hero._current_hp).is_equal_approx(80.0, 0.0001)
