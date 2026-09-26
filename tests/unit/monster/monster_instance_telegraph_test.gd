extends GdUnitTestSuite

## Unit tests for MonsterInstance's wind-up telegraph (wind-up presentation spec §4.1/§4.2).

const SCENE: PackedScene = preload("res://src/core/monster/MonsterInstance.tscn")

var _inst: MonsterInstance


func before_test() -> void:
	_inst = SCENE.instantiate() as MonsterInstance
	add_child(_inst)
	_inst.configure(&"forest_troll_elite", 1, "Troll")


func after_test() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, null)
	if is_instance_valid(_inst):
		_inst.free()


func test_progress_is_zero_at_start_one_at_end_and_clamped() -> void:
	assert_float(MonsterInstance.windup_progress(1.0, 1.0)).is_equal(0.0)
	assert_float(MonsterInstance.windup_progress(0.5, 1.0)).is_equal_approx(0.5, 0.0001)
	assert_float(MonsterInstance.windup_progress(0.0, 1.0)).is_equal(1.0)
	assert_float(MonsterInstance.windup_progress(-0.2, 1.0)).is_equal(1.0)
	assert_float(MonsterInstance.windup_progress(2.0, 1.0)).is_equal(0.0)
	assert_float(MonsterInstance.windup_progress(0.5, 0.0)).is_equal(1.0)


func test_reach_half_extent_is_a_square_of_2r_plus_1_cells() -> void:
	assert_float(MonsterInstance.reach_half_extent(2)).is_equal(160.0)  # 5 cells * 64 / 2
	assert_float(MonsterInstance.reach_half_extent(3)).is_equal(224.0)


func test_pulse_amount_stays_in_range_and_completes_two_cycles_per_second() -> void:
	for i in range(0, 100):
		var a: float = MonsterInstance.pulse_amount(float(i) * 0.013)
		assert_bool(a >= 0.0 and a <= 1.0).is_true()
	assert_float(MonsterInstance.pulse_amount(0.0)).is_equal_approx(MonsterInstance.pulse_amount(0.5), 0.0001)


func test_pulse_is_steady_under_reduced_motion() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, true)
	assert_float(MonsterInstance.pulse_amount(0.0)).is_equal(MonsterInstance.pulse_amount(0.13))


func test_set_activates_and_clear_deactivates_the_telegraph() -> void:
	_inst.set_windup_telegraph(0.4, 2, Vector2.ZERO, 0.016)
	assert_bool(_inst.is_windup_telegraph_active()).is_true()
	assert_float(_inst.get_windup_progress()).is_equal_approx(0.4, 0.0001)
	_inst.clear_windup_telegraph()
	assert_bool(_inst.is_windup_telegraph_active()).is_false()


func test_clear_restores_the_sprite_tint() -> void:
	_inst.set_windup_telegraph(0.4, 2, Vector2.ZERO, 0.1)
	_inst.clear_windup_telegraph()
	assert_object(_inst.get_node("Sprite2D").modulate).is_equal(Color.WHITE)


func test_resolved_starts_a_fade_that_a_clear_does_not_cancel() -> void:
	_inst.set_windup_telegraph(1.0, 2, Vector2.ZERO, 0.016)
	_inst.play_windup_resolved(true)
	_inst.clear_windup_telegraph()  # the manager clears in the same frame the wind-up resolves
	assert_float(_inst.get_resolve_alpha()).is_greater(0.0)


func test_a_new_telegraph_cancels_a_running_resolve_fade() -> void:
	_inst.play_windup_resolved(false)
	_inst.set_windup_telegraph(0.1, 2, Vector2.ZERO, 0.016)
	assert_float(_inst.get_resolve_alpha()).is_equal(0.0)


func test_resolve_fade_reaches_zero() -> void:
	_inst.set_windup_telegraph(1.0, 2, Vector2.ZERO, 0.016)
	_inst.play_windup_resolved(false)
	await get_tree().create_timer(MonsterInstance.RESOLVE_WHIFF_DURATION + 0.1).timeout
	assert_float(_inst.get_resolve_alpha()).is_equal(0.0)


func test_freeing_mid_resolve_does_not_error() -> void:
	_inst.play_windup_resolved(true)
	_inst.free()
	_inst = null
	await get_tree().process_frame
	assert_bool(true).is_true()


func test_play_windup_resolved_outside_the_tree_is_a_safe_no_op() -> void:
	var m: MonsterInstance = auto_free(SCENE.instantiate() as MonsterInstance)
	m.play_windup_resolved(true)
	assert_bool(m.is_inside_tree()).is_false()
