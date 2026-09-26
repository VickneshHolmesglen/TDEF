extends GdUnitTestSuite

## Unit tests for MissionOutcomeStats (mission outcome screen Task 1).

var _stats: MissionOutcomeStats


func before_test() -> void:
	_stats = MissionOutcomeStats.new()


func test_defaults_are_zero() -> void:
	assert_int(_stats.waves_cleared).is_equal(0)
	assert_int(_stats.total_waves).is_equal(0)
	assert_int(_stats.monsters_slain).is_equal(0)
	assert_int(_stats.breaches).is_equal(0)
	assert_float(_stats.elapsed_seconds).is_equal(0.0)


func test_reset_zeroes_everything() -> void:
	_stats.on_wave_started(1, 5, 1.0)
	_stats.on_wave_completed(4, 0, false)
	_stats.on_monster_died(MonsterDiedEvent.new())
	_stats.on_monster_breached(1, &"x", 1)
	_stats.tick(12.5)
	_stats.reset()
	assert_int(_stats.waves_cleared).is_equal(0)
	assert_int(_stats.total_waves).is_equal(0)
	assert_int(_stats.monsters_slain).is_equal(0)
	assert_int(_stats.breaches).is_equal(0)
	assert_float(_stats.elapsed_seconds).is_equal(0.0)


func test_wave_completed_keeps_max() -> void:
	_stats.on_wave_completed(3, 0, false)
	_stats.on_wave_completed(2, 0, false)
	assert_int(_stats.waves_cleared).is_equal(3)


func test_wave_started_sets_total() -> void:
	_stats.on_wave_started(1, 7, 1.0)
	assert_int(_stats.total_waves).is_equal(7)


func test_monsters_slain_increments() -> void:
	_stats.on_monster_died(MonsterDiedEvent.new())
	_stats.on_monster_died(MonsterDiedEvent.new())
	assert_int(_stats.monsters_slain).is_equal(2)


func test_breaches_increment() -> void:
	_stats.on_monster_breached(1, &"a", 1)
	_stats.on_monster_breached(2, &"b", 2)
	assert_int(_stats.breaches).is_equal(2)


func test_tick_accumulates_and_ignores_negative() -> void:
	_stats.tick(1.5)
	_stats.tick(2.0)
	_stats.tick(-4.0)
	assert_float(_stats.elapsed_seconds).is_equal_approx(3.5, 0.0001)


func test_format_time_cases() -> void:
	assert_str(MissionOutcomeStats.format_time(0.0)).is_equal("0:00")
	assert_str(MissionOutcomeStats.format_time(65.9)).is_equal("1:05")
	assert_str(MissionOutcomeStats.format_time(3600.0)).is_equal("60:00")
	assert_str(MissionOutcomeStats.format_time(-5.0)).is_equal("0:00")
