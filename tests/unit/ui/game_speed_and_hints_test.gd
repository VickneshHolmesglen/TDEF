## Unit tests for GameSpeed (mission fast-forward) and FirstMissionHints
## (first-mission coaching card), both added 2026-11-02. Handlers are called
## directly rather than emitting real GEventBus phase events: those reach every
## autoload and leaked state into later suites (recipe-model-discovery_test).
extends GdUnitTestSuite


var _speed: GameSpeed
var _hints: FirstMissionHints


func before_test() -> void:
	FirstMissionHints.reset_completed()


func after_test() -> void:
	if is_instance_valid(_speed):
		_speed.free()
	if is_instance_valid(_hints):
		_hints.free()
	Engine.time_scale = 1.0
	FirstMissionHints.reset_completed()


# --- GameSpeed ---------------------------------------------------------------

func test_game_speed_cycle_wraps_1_2_3_then_back_to_1() -> void:
	# Arrange
	_speed = GameSpeed.new()
	add_child(_speed)
	# Act / Assert
	assert_float(_speed.cycle()).is_equal(2.0)
	assert_float(Engine.time_scale).is_equal(2.0)
	assert_float(_speed.cycle()).is_equal(3.0)
	assert_float(_speed.cycle()).is_equal(1.0)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_game_speed_mission_end_restores_normal_speed() -> void:
	# Arrange
	_speed = GameSpeed.new()
	add_child(_speed)
	_speed.set_speed_index(2)
	# Act
	_speed._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)
	# Assert
	assert_float(_speed.get_multiplier()).is_equal(1.0)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_game_speed_leaving_tree_restores_normal_speed() -> void:
	# Arrange
	_speed = GameSpeed.new()
	add_child(_speed)
	_speed.set_speed_index(1)
	# Act
	remove_child(_speed)
	# Assert
	assert_float(Engine.time_scale).is_equal(1.0)


func test_game_speed_find_returns_the_grouped_node() -> void:
	# Arrange
	_speed = GameSpeed.new()
	add_child(_speed)
	# Act / Assert
	assert_object(GameSpeed.find(get_tree())).is_same(_speed)


# --- FirstMissionHints --------------------------------------------------------

func test_first_mission_hints_advance_through_build_ready_hero_intermission() -> void:
	# Arrange
	_hints = FirstMissionHints.new()
	add_child(_hints)
	# Act / Assert
	_hints._on_mission_phase_changed("SANCTUARY", "SCOUT", 0.0)
	assert_int(_hints.get_step()).is_equal(FirstMissionHints.Step.BUILD)
	_hints._on_tower_placed(TowerPlacedEvent.new())
	assert_int(_hints.get_step()).is_equal(FirstMissionHints.Step.READY)
	_hints._on_wave_started(1, 5, 1.0)
	assert_int(_hints.get_step()).is_equal(FirstMissionHints.Step.HERO)
	_hints._on_wave_completed(1, 0, false)
	assert_int(_hints.get_step()).is_equal(FirstMissionHints.Step.INTERMISSION)


func test_first_mission_hints_mission_end_marks_completed() -> void:
	# Arrange
	_hints = FirstMissionHints.new()
	add_child(_hints)
	_hints._on_mission_phase_changed("SANCTUARY", "SCOUT", 0.0)
	# Act
	_hints._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)
	# Assert
	assert_int(_hints.get_step()).is_equal(FirstMissionHints.Step.DONE)
	assert_bool(FirstMissionHints.is_completed()).is_true()


func test_first_mission_hints_stay_hidden_once_completed() -> void:
	# Arrange
	FirstMissionHints.mark_completed()
	_hints = FirstMissionHints.new()
	add_child(_hints)
	# Act
	_hints._on_mission_phase_changed("SANCTUARY", "SCOUT", 0.0)
	# Assert
	assert_int(_hints.get_step()).is_equal(FirstMissionHints.Step.DONE)
	assert_bool(_hints.visible).is_false()


func test_first_mission_hints_every_step_has_localized_keys() -> void:
	for step: FirstMissionHints.Step in [FirstMissionHints.Step.BUILD, FirstMissionHints.Step.READY,
			FirstMissionHints.Step.HERO, FirstMissionHints.Step.INTERMISSION]:
		for key: StringName in FirstMissionHints.keys_for(step):
			assert_str(tr(key)).is_not_equal(String(key))
