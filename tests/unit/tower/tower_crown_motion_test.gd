## Unit tests for TowerCrownMotion: per-crown idle/aim motion data for 3D
## towers (docs/superpowers/specs/2026-11-07-3d-towers-design.md §5.3).
extends GdUnitTestSuite


func test_crown_motion_unknown_crown_returns_defaults() -> void:
	var motion: TowerCrownMotion = TowerCrownMotion.for_crown(&"no_such_crown")
	assert_int(motion.idle_mode).is_equal(TowerCrownMotion.IdleMode.SWEEP)
	assert_float(motion.idle_speed_deg).is_equal(60.0)
	assert_bool(motion.aims).is_true()
	assert_float(motion.track_speed_deg).is_equal(270.0)


func test_crown_motion_authored_crown_loads_file() -> void:
	var motion: TowerCrownMotion = TowerCrownMotion.for_crown(&"siege")
	assert_str(motion.resource_path).ends_with("siege.tres")


func test_crown_motion_unknown_crowns_get_separate_instances() -> void:
	var a: TowerCrownMotion = TowerCrownMotion.for_crown(&"no_such_crown")
	var b: TowerCrownMotion = TowerCrownMotion.for_crown(&"no_such_crown")
	assert_bool(a == b).is_false()


func test_crown_motion_spin_crown_loads_spin_node() -> void:
	var motion: TowerCrownMotion = TowerCrownMotion.for_crown(&"top_stonemound")
	assert_int(motion.idle_mode).is_equal(TowerCrownMotion.IdleMode.SPIN)
	assert_str(String(motion.spin_node)).is_equal("Crystal")
	assert_bool(motion.aims).is_false()
