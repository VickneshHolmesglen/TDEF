extends GdUnitTestSuite

## Unit tests for MissionOutcomeScreen (mission outcome screen Task 2).
## Terminal events are driven by calling the screen's handlers directly so the live
## GSceneManager autoload never reacts; only non-terminal signals go on the global bus.

const SCENE_PATH: String = "res://src/presentation/mission_outcome/MissionOutcomeScreen.tscn"

var _screen: MissionOutcomeScreen
var _retry_calls: int = 0
var _sanctuary_calls: int = 0


func before_test() -> void:
	_retry_calls = 0
	_sanctuary_calls = 0
	_screen = load(SCENE_PATH).instantiate()
	_screen._defeat_delay = 0.0
	_screen._victory_delay = 0.0
	_screen._retry_action = func() -> void: _retry_calls += 1
	_screen._sanctuary_action = func() -> void: _sanctuary_calls += 1
	add_child(_screen)


func after_test() -> void:
	get_tree().paused = false
	if is_instance_valid(_screen):
		if _screen.get_parent() != null:
			_screen.get_parent().remove_child(_screen)
		_screen.free()


func _btn(node_name: String) -> Button:
	return _screen.find_child(node_name, true, false) as Button


func _label(node_name: String) -> Label:
	return _screen.find_child(node_name, true, false) as Label


func test_static_helpers() -> void:
	assert_str(MissionOutcomeScreen.title_key(MissionOutcomeScreen.Mode.DEFEAT)).is_equal("OUTCOME_TITLE_DEFEAT")
	assert_str(MissionOutcomeScreen.title_key(MissionOutcomeScreen.Mode.VICTORY)).is_equal("OUTCOME_TITLE_VICTORY")
	assert_str(MissionOutcomeScreen.title_key(MissionOutcomeScreen.Mode.NONE)).is_equal("")
	assert_array(MissionOutcomeScreen.buttons_for(MissionOutcomeScreen.Mode.DEFEAT)).is_equal([&"retry", &"sanctuary"])
	assert_array(MissionOutcomeScreen.buttons_for(MissionOutcomeScreen.Mode.VICTORY)).is_equal([&"sanctuary"])
	assert_array(MissionOutcomeScreen.buttons_for(MissionOutcomeScreen.Mode.NONE)).is_empty()


func test_group_and_hidden_by_default() -> void:
	assert_bool(_screen.is_in_group(MissionOutcomeScreen.GROUP_NAME)).is_true()
	assert_bool(_screen.is_showing()).is_false()
	assert_int(_screen.get_mode()).is_equal(MissionOutcomeScreen.Mode.NONE)
	assert_int(_screen.layer).is_equal(MissionOutcomeScreen.OUTCOME_LAYER)


func test_defeat_phase_shows_with_retry_focused() -> void:
	_screen._on_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)
	assert_bool(_screen.is_showing()).is_true()
	assert_int(_screen.get_mode()).is_equal(MissionOutcomeScreen.Mode.DEFEAT)
	assert_bool(_btn("RetryButton").visible).is_true()
	assert_bool(_btn("RetryButton").has_focus()).is_true()
	assert_str(_label("TitleLabel").text).is_equal("Defeat")


func test_hero_died_first_event_wins() -> void:
	_screen._on_hero_died()
	assert_int(_screen.get_mode()).is_equal(MissionOutcomeScreen.Mode.DEFEAT)
	_screen._on_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)
	assert_int(_screen.get_mode()).is_equal(MissionOutcomeScreen.Mode.DEFEAT)
	_screen._on_terminal_event(MissionOutcomeScreen.Mode.VICTORY)
	assert_int(_screen.get_mode()).is_equal(MissionOutcomeScreen.Mode.DEFEAT)


func test_victory_shows_only_sanctuary_button_focused() -> void:
	_screen._on_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)
	assert_int(_screen.get_mode()).is_equal(MissionOutcomeScreen.Mode.VICTORY)
	assert_bool(_btn("RetryButton").visible).is_false()
	assert_bool(_btn("SanctuaryButton").visible).is_true()
	assert_bool(_btn("SanctuaryButton").has_focus()).is_true()
	assert_str(_label("TitleLabel").text).is_equal("Mission Complete")


func test_delayed_show_is_pending_then_shows() -> void:
	_screen._defeat_delay = 0.2
	_screen._on_hero_died()
	assert_bool(_screen.is_show_pending()).is_true()
	assert_bool(_screen.is_showing()).is_false()
	await get_tree().create_timer(0.35).timeout
	assert_bool(_screen.is_showing()).is_true()
	assert_bool(_screen.is_show_pending()).is_false()


func test_mission_launched_cancels_pending_and_resets_stats() -> void:
	_screen._defeat_delay = 0.2
	_screen.get_stats().monsters_slain = 7
	_screen._on_hero_died()
	_screen._on_mission_launched("m1", PackedStringArray(), 1)
	assert_bool(_screen.is_show_pending()).is_false()
	assert_int(_screen.get_stats().monsters_slain).is_equal(0)
	await get_tree().create_timer(0.35).timeout
	assert_bool(_screen.is_showing()).is_false()


func test_non_terminal_phase_hides_showing_screen() -> void:
	_screen._on_hero_died()
	assert_bool(_screen.is_showing()).is_true()
	_screen._on_phase_changed("DEFEAT", "PRE_WAVE", 0.0)
	assert_bool(_screen.is_showing()).is_false()
	assert_int(_screen.get_mode()).is_equal(MissionOutcomeScreen.Mode.NONE)


func test_retry_pressed_invokes_once_and_hides_on_relaunch() -> void:
	_screen._on_hero_died()
	_btn("RetryButton").pressed.emit()
	assert_int(_retry_calls).is_equal(1)
	assert_int(_sanctuary_calls).is_equal(0)
	assert_bool(_screen.is_showing()).is_true()
	_screen._on_mission_launched("m1", PackedStringArray(), 1)
	assert_bool(_screen.is_showing()).is_false()


func test_retry_hides_on_non_terminal_phase() -> void:
	_screen._on_hero_died()
	_btn("RetryButton").pressed.emit()
	_screen._on_phase_changed("DEFEAT", "PRE_WAVE", 0.0)
	assert_bool(_screen.is_showing()).is_false()


func test_second_retry_press_before_relaunch_is_ignored() -> void:
	_screen._on_hero_died()
	_btn("RetryButton").pressed.emit()
	_btn("RetryButton").pressed.emit()
	assert_int(_retry_calls).is_equal(1)


func test_failed_retry_keeps_panel_and_return_works() -> void:
	_screen._retry_action = func() -> void: pass
	_screen._on_hero_died()
	_btn("RetryButton").pressed.emit()
	assert_bool(_screen.is_showing()).is_true()
	_btn("SanctuaryButton").pressed.emit()
	assert_int(_sanctuary_calls).is_equal(1)


func test_sanctuary_pressed_invokes_action() -> void:
	_screen._on_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)
	_btn("SanctuaryButton").pressed.emit()
	assert_int(_sanctuary_calls).is_equal(1)


func test_stats_feed_through_real_signals() -> void:
	GEventBus.wave_started.emit(1, 5, 1.0)
	GEventBus.wave_completed.emit(1, 0, false)
	GEventBus.monster_died.emit(MonsterDiedEvent.new())
	GEventBus.monster_died.emit(MonsterDiedEvent.new())
	GEventBus.monster_breached.emit(1, &"x", 1)
	_screen._on_hero_died()
	assert_str(_label("WavesValue").text).is_equal("1 / 5")
	assert_str(_label("SlainValue").text).is_equal("2")
	assert_str(_label("BreachesValue").text).is_equal("1")
	assert_str(_label("TimeValue").text).is_equal("0:00")


func test_exit_tree_disconnects_bus_signals() -> void:
	remove_child(_screen)
	var screen: MissionOutcomeScreen = _screen
	_screen = null
	assert_bool(GEventBus.mission_phase_changed.is_connected(screen._on_phase_changed)).is_false()
	assert_bool(GEventBus.hero_died.is_connected(screen._on_hero_died)).is_false()
	assert_bool(GEventBus.mission_launched.is_connected(screen._on_mission_launched)).is_false()
	assert_bool(GEventBus.wave_started.is_connected(screen._on_wave_started)).is_false()
	screen.free()


func test_paused_tree_does_not_tick_elapsed_time() -> void:
	_screen._on_mission_launched("m1", PackedStringArray(), 1)
	_screen._process(1.0)
	assert_float(_screen.get_stats().elapsed_seconds).is_equal(1.0)
	get_tree().paused = true
	_screen._process(1.0)
	get_tree().paused = false
	assert_float(_screen.get_stats().elapsed_seconds).is_equal(1.0)


func test_ui_cancel_returns_to_sanctuary_only_while_showing() -> void:
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	_screen._unhandled_input(cancel)
	assert_int(_sanctuary_calls).is_equal(0)
	_screen._on_hero_died()
	_screen._unhandled_input(cancel)
	assert_int(_sanctuary_calls).is_equal(1)
