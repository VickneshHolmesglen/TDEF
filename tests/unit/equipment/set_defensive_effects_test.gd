extends GdUnitTestSuite

## Unit tests for the second-tier defensive set effects (set defensive effects
## spec, 2026-10-06, AC-1/3/4/5/6/7). Handlers are called directly (not via
## GEventBus) so autoload subscribers never react, matching
## set_effect_controller_test.gd.

var _hero: Hero
var _ctl: SetEffectController


func before_test() -> void:
	GInventory.reset_to_defaults()
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[&"max_hp"] = 600.0
	_hero._base_stats[&"armor"] = 20.0
	_hero._base_stats[&"physical_attack"] = 100.0
	_hero._base_stats[&"attack_range"] = 200.0
	_hero._max_hp = 600.0
	_hero._current_hp = 600.0
	_hero._phase = Hero.HeroPhase.COMBAT
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


func _apply(effects: Array) -> void:
	var typed: Array[Dictionary] = []
	for effect: Dictionary in effects:
		typed.append(effect)
	_ctl.apply_effects(typed)


func _kill(x: float, source: String = "") -> MonsterDiedEvent:
	var payload := MonsterDiedEvent.new()
	payload.world_position = Vector2(x, 0.0)
	payload.kill_source = source
	return payload


func _heal_effect() -> Dictionary:
	return _effect("set_troll:2", &"on_kill_heal", {&"heal_fraction": 0.015})


func _shield_effect() -> Dictionary:
	return _effect("set_brute:4", &"on_hurt_shield",
		{&"shield_fraction": 0.08, &"duration": 4.0, &"cooldown": 8.0})


func _last_stand() -> Dictionary:
	return _effect("set_reinforced:2", &"low_hp_state",
		{&"hp_fraction": 0.3, &"stats": {&"armor": 0.5, &"physical_attack": 0.2}})


# ---------------------------------------------------------------------------
# Hero: apply_heal and the shield layer
# ---------------------------------------------------------------------------

func test_hero_apply_heal_clamps_at_max_hp() -> void:
	_hero._current_hp = 590.0
	_hero.apply_heal(50)
	assert_float(_hero.get_current_hp()).is_equal(600.0)


func test_hero_apply_heal_does_nothing_outside_combat() -> void:
	_hero._current_hp = 300.0
	_hero._phase = Hero.HeroPhase.SCOUT
	_hero.apply_heal(50)
	assert_float(_hero.get_current_hp()).is_equal(300.0)


func test_hero_lifesteal_heal_still_routes_through_the_same_path() -> void:
	_hero._current_hp = 300.0
	_hero._on_hero_healed(25)
	assert_float(_hero.get_current_hp()).is_equal(325.0)


func test_hero_shield_absorbs_before_hp_and_remainder_hits_hp() -> void:
	_hero.set_shield(&"a", 40)
	_hero._on_hero_damage_taken(30, 0)
	assert_float(_hero.get_current_hp()).is_equal(600.0)
	assert_int(_hero.get_total_shield()).is_equal(10)
	_hero._on_hero_damage_taken(30, 0)
	assert_float(_hero.get_current_hp()).is_equal(580.0)
	assert_int(_hero.get_total_shield()).is_equal(0)


func test_hero_fully_absorbed_hit_emits_no_health_change() -> void:
	var emitted: Array[int] = [0]
	var on_changed := func(_c: float, _m: float) -> void: emitted[0] += 1
	GEventBus.hero_health_changed.connect(on_changed)
	_hero.set_shield(&"a", 50)
	_hero._on_hero_damage_taken(30, 0)
	GEventBus.hero_health_changed.disconnect(on_changed)
	assert_int(emitted[0]).is_equal(0)


func test_hero_shields_are_cleared_by_reset_and_absent_from_save_data() -> void:
	_hero.set_shield(&"a", 50)
	assert_str(str(_hero.get_save_data())).not_contains("shield")
	_hero.reset_to_defaults()
	assert_int(_hero.get_total_shield()).is_equal(0)


# ---------------------------------------------------------------------------
# on_kill_heal
# ---------------------------------------------------------------------------

func test_kill_heal_heals_a_fraction_of_max_hp_per_direct_kill() -> void:
	_apply([_heal_effect()])
	_hero._current_hp = 300.0
	_ctl._on_monster_died(_kill(50.0))
	assert_float(_hero.get_current_hp()).is_equal(309.0)  # roundi(0.015 * 600)


func test_kill_heal_ignores_wave_end_and_out_of_range_kills() -> void:
	_apply([_heal_effect()])
	_hero._current_hp = 300.0
	_ctl._on_monster_died(_kill(900.0))
	_ctl._on_monster_died(_kill(10.0, "wave_end"))
	assert_float(_hero.get_current_hp()).is_equal(300.0)


func test_kill_heal_heals_once_per_qualifying_batch_entry() -> void:
	_apply([_heal_effect()])
	_hero._current_hp = 300.0
	var batch: Array[MonsterDiedEvent] = [_kill(10.0), _kill(20.0), _kill(900.0)]
	_ctl._on_monsters_died_batch(batch)
	assert_float(_hero.get_current_hp()).is_equal(318.0)


# ---------------------------------------------------------------------------
# on_hurt_shield
# ---------------------------------------------------------------------------

func test_shield_is_granted_after_the_triggering_hit_not_during_it() -> void:
	_apply([_shield_effect()])
	_ctl._on_hero_damage_taken(40, 0)
	assert_int(_hero.get_total_shield()).is_equal(0)
	await await_idle_frame()
	assert_int(_hero.get_total_shield()).is_equal(48)  # roundi(0.08 * 600)


func test_shield_respects_its_cooldown() -> void:
	_apply([_shield_effect()])
	_ctl._on_hero_damage_taken(40, 0)
	await await_idle_frame()
	_hero.clear_all_shields()
	_ctl._on_hero_damage_taken(40, 0)
	await await_idle_frame()
	assert_int(_hero.get_total_shield()).is_equal(0)
	_ctl._process(8.0)
	_ctl._on_hero_damage_taken(40, 0)
	await await_idle_frame()
	assert_int(_hero.get_total_shield()).is_equal(48)


func test_shield_expires_after_its_duration() -> void:
	_apply([_shield_effect()])
	_ctl._on_hero_damage_taken(40, 0)
	await await_idle_frame()
	_ctl._process(4.0)
	assert_int(_hero.get_total_shield()).is_equal(0)


func test_removing_the_shield_effect_clears_its_shield() -> void:
	_apply([_shield_effect()])
	_ctl._on_hero_damage_taken(40, 0)
	await await_idle_frame()
	_apply([])
	assert_int(_hero.get_total_shield()).is_equal(0)


# ---------------------------------------------------------------------------
# low_hp_state
# ---------------------------------------------------------------------------

func test_low_hp_state_is_active_only_at_or_below_the_fraction() -> void:
	_apply([_last_stand()])
	_ctl._on_hero_health_changed(300.0, 600.0)
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(100.0, 0.0001)
	_ctl._on_hero_health_changed(180.0, 600.0)
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(120.0, 0.0001)
	assert_float(_hero.get_effective_stat(&"armor")).is_equal_approx(30.0, 0.0001)
	_ctl._on_hero_health_changed(400.0, 600.0)
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(100.0, 0.0001)


func test_low_hp_state_is_inactive_at_zero_hp() -> void:
	_apply([_last_stand()])
	_ctl._on_hero_health_changed(0.0, 600.0)
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(100.0, 0.0001)


func test_low_hp_state_applies_immediately_when_equipped_at_low_hp() -> void:
	_hero._current_hp = 100.0
	_apply([_last_stand()])
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(120.0, 0.0001)


# ---------------------------------------------------------------------------
# Validation (AC-1)
# ---------------------------------------------------------------------------

func _set_with(effect: Dictionary) -> EquipmentSetResource:
	var res := EquipmentSetResource.new()
	res.set_id = &"set_x"
	res.display_name = "X"
	res.member_item_ids = [&"a", &"b", &"c"]
	res.bonuses = {2: {&"max_hp": 10.0}}
	res.effects = {2: effect}
	return res


func test_validation_accepts_the_three_new_types() -> void:
	for effect: Dictionary in [_heal_effect(), _shield_effect(), _last_stand()]:
		var clean: Dictionary = {&"name": "N", &"type": effect[&"type"], &"params": effect[&"params"]}
		assert_array(_set_with(clean).validate()).is_empty()


func test_validation_rejects_fractions_out_of_range_and_max_hp_in_low_hp_state() -> void:
	var bad_heal: Dictionary = {&"name": "N", &"type": &"on_kill_heal", &"params": {&"heal_fraction": 1.5}}
	assert_array(_set_with(bad_heal).validate()).is_not_empty()
	var bad_shield: Dictionary = {&"name": "N", &"type": &"on_hurt_shield",
		&"params": {&"shield_fraction": 0.1, &"duration": 4.0, &"cooldown": 0.0}}
	assert_array(_set_with(bad_shield).validate()).is_not_empty()
	var bad_state: Dictionary = {&"name": "N", &"type": &"low_hp_state",
		&"params": {&"hp_fraction": 0.3, &"stats": {&"max_hp": 0.2}}}
	assert_array(_set_with(bad_state).validate()).is_not_empty()
