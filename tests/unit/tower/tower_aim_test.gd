## Unit tests for TowerAim: the crown's aim/sentry-sweep maths for 3D towers
## (docs/superpowers/specs/2026-11-07-3d-towers-design.md §5.3).
extends GdUnitTestSuite


func test_yaw_for_direction_straight_down_screen_is_zero() -> void:
	assert_float(TowerAim.yaw_for_direction(Vector2(0, 1), 1.3)).is_equal_approx(0.0, 0.0001)


func test_yaw_for_direction_right_is_quarter_turn() -> void:
	assert_float(TowerAim.yaw_for_direction(Vector2(1, 0), 1.3)).is_equal_approx(PI / 2, 0.0001)


func test_turn_toward_wraps_the_short_way() -> void:
	var r: float = TowerAim.turn_toward(deg_to_rad(350), deg_to_rad(10), deg_to_rad(5))
	assert_float(wrapf(r, 0, TAU)).is_equal_approx(deg_to_rad(355), 0.0001)


func test_turn_toward_does_not_overshoot() -> void:
	assert_float(TowerAim.turn_toward(0.0, 0.1, 1.0)).is_equal_approx(0.1, 0.0001)


func test_idle_sweeps_at_idle_speed() -> void:
	var aim := TowerAim.new(0.0, 60.0, 270.0, true)
	assert_float(aim.step(1.0)).is_equal_approx(deg_to_rad(60), 0.0001)


func test_tracking_turn_rate_is_capped() -> void:
	var aim := TowerAim.new(0.0, 60.0, 270.0, true)
	aim.set_target(Vector2(0, -1), 2.0)  # straight up the screen = PI away
	assert_float(absf(aim.step(0.1))).is_equal_approx(deg_to_rad(27), 0.0001)


func test_hold_expiry_returns_to_idle_from_current_yaw() -> void:
	var aim := TowerAim.new(0.0, 60.0, 270.0, true)
	aim.set_target(Vector2(1, 0), 0.5)
	aim.step(1.0)  # reaches PI/2; the 0.5 s hold expires within this step
	var before: float = aim.yaw
	assert_bool(aim.is_tracking()).is_false()
	assert_float(aim.step(0.1) - before).is_equal_approx(deg_to_rad(6), 0.0001)


func test_clear_target_resumes_idle_without_jump() -> void:
	var aim := TowerAim.new(1.0, 60.0, 270.0, true)
	aim.set_target(Vector2(1, 0), 5.0)
	aim.clear_target()
	assert_float(aim.step(0.0)).is_equal_approx(1.0, 0.0001)


func test_non_aiming_crown_ignores_targets() -> void:
	var aim := TowerAim.new(0.0, 60.0, 270.0, false)
	aim.set_target(Vector2(1, 0), 5.0)
	assert_bool(aim.is_tracking()).is_false()


func test_z_stretch_changes_diagonal_yaw() -> void:
	var aim := TowerAim.new(0.0, 60.0, 270.0, true)
	aim.z_stretch = 2.0
	aim.set_target(Vector2(1, 1), 5.0)
	aim.step(10.0)  # long enough to arrive
	assert_float(aim.yaw).is_equal_approx(atan2(1.0, 2.0), 0.0001)
