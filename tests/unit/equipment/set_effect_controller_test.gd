extends GdUnitTestSuite

## Unit tests for SetEffectController (equipment-set-effects spec §3.4, AC-5/6/8/12).
## Handlers are called directly (not via GEventBus) so autoload subscribers
## never react. Effects are injected through apply_effects(), isolating the
## controller from inventory content.

var _hero: Hero
var _ctl: SetEffectController


func before_test() -> void:
	GInventory.reset_to_defaults()
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[&"physical_attack"] = 100.0
	_hero._base_stats[&"attack_range"] = 200.0
	_hero.global_position = Vector2.ZERO
	_ctl = SetEffectController.new()
	_hero.add_child(_ctl)


func after_test() -> void:
	GInventory.reset_to_defaults()
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null
	_ctl = null


func _effect(key: String, type: StringName, params: Dictionary) -> Dictionary:
	return {&"key": StringName(key), &"set_id": &"set_test", &"threshold": 2,
		&"name": "Test", &"type": type, &"params": params}


func _wave_buff() -> Dictionary:
	return _effect("set_test:2", &"on_wave_start_buff",
		{&"stats": {&"physical_attack": 0.35}, &"duration": 10.0})


func _skill_buff() -> Dictionary:
	return _effect("set_test2:2", &"on_skill_cast_buff",
		{&"stats": {&"physical_attack": 0.15}, &"duration": 5.0})


func _apply(effects: Array) -> void:
	var typed: Array[Dictionary] = []
	for effect: Dictionary in effects:
		typed.append(effect)
	_ctl.apply_effects(typed)


func _atk() -> float:
	return _hero.get_effective_stat(&"physical_attack")


func test_controller_subscribes_to_every_listed_signal() -> void:
	for pair: Array in _ctl._subscriptions():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		assert_bool(sig.is_connected(handler)).is_true()


func test_controller_disconnects_everything_on_exit() -> void:
	var baseline: int = GEventBus.equipment_slot_changed.get_connections().size()
	_hero.remove_child(_ctl)
	_ctl.free()
	assert_int(GEventBus.equipment_slot_changed.get_connections().size()).is_equal(baseline - 1)
	_ctl = null


func test_wave_start_buff_grants_then_expires() -> void:
	_apply([_wave_buff()])
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)
	_ctl._on_wave_started(1, 5, 1.0)
	assert_float(_atk()).is_equal_approx(135.0, 0.0001)
	_ctl._process(9.9)
	assert_float(_atk()).is_equal_approx(135.0, 0.0001)
	_ctl._process(0.2)
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_wave_start_buff_refreshes_and_never_stacks() -> void:
	_apply([_wave_buff()])
	_ctl._on_wave_started(1, 5, 1.0)
	_ctl._on_wave_started(2, 5, 1.0)
	assert_float(_atk()).is_equal_approx(135.0, 0.0001)
	_ctl._process(6.0)
	_ctl._on_wave_started(3, 5, 1.0)
	_ctl._process(6.0)
	assert_float(_atk()).is_equal_approx(135.0, 0.0001)
	_ctl._process(5.0)
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_skill_cast_buff_grants_and_expires() -> void:
	_apply([_skill_buff()])
	_ctl._on_hero_skill_activated("skill_x", Vector2.ZERO)
	assert_float(_atk()).is_equal_approx(115.0, 0.0001)
	_ctl._process(5.1)
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_a_wave_buff_ignores_skill_casts_and_vice_versa() -> void:
	_apply([_wave_buff()])
	_ctl._on_hero_skill_activated("skill_x", Vector2.ZERO)
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_removing_an_effect_clears_its_modifier_immediately() -> void:
	_apply([_wave_buff()])
	_ctl._on_wave_started(1, 5, 1.0)
	_apply([])
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)
	_ctl._on_wave_started(2, 5, 1.0)
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_unchanged_effect_keeps_its_timer_across_a_rebuild() -> void:
	_apply([_wave_buff()])
	_ctl._on_wave_started(1, 5, 1.0)
	_ctl._process(4.0)
	_apply([_wave_buff()])
	_ctl._process(5.0)
	assert_float(_atk()).is_equal_approx(135.0, 0.0001)
	_ctl._process(2.0)
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_hero_died_clears_every_modifier() -> void:
	_apply([_wave_buff(), _skill_buff()])
	_ctl._on_wave_started(1, 5, 1.0)
	_ctl._on_hero_skill_activated("skill_x", Vector2.ZERO)
	_ctl._on_hero_died()
	assert_float(_atk()).is_equal_approx(100.0, 0.0001)


func test_processing_is_only_enabled_while_a_timer_is_live() -> void:
	_apply([_wave_buff()])
	assert_bool(_ctl.is_processing()).is_false()
	_ctl._on_wave_started(1, 5, 1.0)
	assert_bool(_ctl.is_processing()).is_true()
	_ctl._process(11.0)
	assert_bool(_ctl.is_processing()).is_false()
