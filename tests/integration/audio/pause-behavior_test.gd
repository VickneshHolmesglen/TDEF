## Integration tests for Story 006 (epic-12-audio-system): Pause Behavior --
## AC Group 6 (Core Rule 7). ADR-0014 governs game_paused/game_unpaused as
## informational-only signals; this suite fires them directly (not via
## SceneTree.paused) since that's the real mechanism PauseDuckController
## reacts to.
##
## Uses real scene instantiation (`add_child()`) exercising the real
## AudioSystem/MusicAmbientController/PauseDuckController wiring and the
## real GEventBus/AudioServer -- not mocked.
extends GdUnitTestSuite

var _audio: AudioSystem

## The real `GAudioSystem` Autoload is always alive during any headless test
## run (it's registered in project.godot) and has its own `PauseDuckController`
## subscribed to the same `game_paused`/`game_unpaused` signals this suite
## fires directly. Left connected, it independently ducks the same shared
## `AudioServer` bus state this suite's own `_audio` instance also ducks,
## corrupting the raw Ambient bus readback (Ambient has no per-instance
## percent abstraction the way Music/SFX/UI do, so it's the one bus where a
## second, unrelated ducker actually shows up as wrong data). Temporarily
## disconnecting the real Autoload's subscriptions for this suite's
## duration isolates it, matching this project's own "reset shared
## Autoload/singleton state between tests" discipline.
var _real_audio_pause_duck: PauseDuckController = null


func before_test() -> void:
	_audio = AudioSystem.new()
	add_child(_audio)

	var real_audio: Node = get_tree().root.get_node_or_null(^"GAudioSystem")
	if real_audio != null and real_audio.get(&"pause_duck") != null:
		_real_audio_pause_duck = real_audio.pause_duck
		if GEventBus.game_paused.is_connected(_real_audio_pause_duck._on_game_paused):
			GEventBus.game_paused.disconnect(_real_audio_pause_duck._on_game_paused)
		if GEventBus.game_unpaused.is_connected(_real_audio_pause_duck._on_game_unpaused):
			GEventBus.game_unpaused.disconnect(_real_audio_pause_duck._on_game_unpaused)


func after_test() -> void:
	if _audio != null and is_instance_valid(_audio):
		_audio.free()
	_audio = null
	# Ambient bus's volume_db is never reset by _configure_buses() (only
	# player buses get their volume re-applied) -- without removing every
	# bus this suite touches, a later test's "pre-pause" Ambient reading
	# would be whatever the previous test last ducked it to, compounding
	# across tests that share the same global AudioServer.
	for bus_name: StringName in [&"Ambient", &"UI", &"Voice", &"SFX", &"Music"]:
		var index: int = AudioServer.get_bus_index(bus_name)
		if index != -1:
			AudioServer.remove_bus(index)

	if _real_audio_pause_duck != null and is_instance_valid(_real_audio_pause_duck):
		if not GEventBus.game_paused.is_connected(_real_audio_pause_duck._on_game_paused):
			GEventBus.game_paused.connect(_real_audio_pause_duck._on_game_paused)
		if not GEventBus.game_unpaused.is_connected(_real_audio_pause_duck._on_game_unpaused):
			GEventBus.game_unpaused.connect(_real_audio_pause_duck._on_game_unpaused)
	_real_audio_pause_duck = null


# ---------------------------------------------------------------------------
# AC-15a: pause freezes an in-flight crossfade exactly where it is; unpause
# resumes from exactly that point.
# ---------------------------------------------------------------------------

func test_pause_mid_crossfade_freezes_progress_exactly_in_place() -> void:
	GEventBus.mission_phase_changed.emit("SANCTUARY", "SCOUT", 0.0)
	GEventBus.wave_countdown_warning.emit(10)
	_audio.music_ambient.advance_time(6.0)
	assert_float(_audio.music_ambient.get_crossfade_remaining_seconds()).is_equal_approx(4.0, 0.001)

	GEventBus.game_paused.emit()
	assert_bool(_audio.music_ambient.is_frozen()).is_true()

	# Time "passing" while paused (a real _process delta, if one ever fired)
	# must not move the frozen countdown at all.
	_audio.music_ambient.advance_time(2.0)

	assert_float(_audio.music_ambient.get_crossfade_remaining_seconds()).is_equal_approx(4.0, 0.001)
	assert_bool(_audio.music_ambient.is_transitioning()).is_true()


func test_unpause_resumes_the_crossfade_from_the_frozen_point() -> void:
	GEventBus.mission_phase_changed.emit("SANCTUARY", "SCOUT", 0.0)
	GEventBus.wave_countdown_warning.emit(10)
	_audio.music_ambient.advance_time(6.0)

	GEventBus.game_paused.emit()
	_audio.music_ambient.advance_time(100.0)  # frozen -- must have no effect
	GEventBus.game_unpaused.emit()

	assert_bool(_audio.music_ambient.is_frozen()).is_false()
	assert_float(_audio.music_ambient.get_crossfade_remaining_seconds()).is_equal_approx(4.0, 0.001)

	_audio.music_ambient.advance_time(4.0)
	assert_bool(_audio.music_ambient.is_transitioning()).is_false()


func test_double_pause_cycle_mid_transition_still_resumes_correctly() -> void:
	GEventBus.mission_phase_changed.emit("SANCTUARY", "SCOUT", 0.0)
	GEventBus.wave_countdown_warning.emit(10)
	_audio.music_ambient.advance_time(3.0)  # 7.0 remaining

	GEventBus.game_paused.emit()
	GEventBus.game_unpaused.emit()
	_audio.music_ambient.advance_time(2.0)  # 5.0 remaining
	GEventBus.game_paused.emit()
	GEventBus.game_unpaused.emit()
	_audio.music_ambient.advance_time(5.0)

	assert_bool(_audio.music_ambient.is_transitioning()).is_false()


# ---------------------------------------------------------------------------
# AC-15b: pause ducks Music/Ambient to ~40% of pre-pause level, mutes SFX
# entirely; unpause restores exact pre-pause values.
#
# `get_bus_volume_percent()` reads the *persisted preference* (`_bus_volumes`)
# -- it must stay completely unchanged throughout a pause cycle (a real bug
# found in code review: routing the duck through `set_bus_volume_percent()`
# would let a `save_settings_to_disk()` call made while paused permanently
# write the ducked value to disk). The *real, audible* level is checked
# separately via `get_bus_volume_db_direct()` against the raw `AudioServer`.
# ---------------------------------------------------------------------------

func _linear_from_db_direct(bus_name: StringName) -> float:
	return db_to_linear(_audio.get_bus_volume_db_direct(bus_name))


func test_pause_ducks_music_and_ambient_to_40_percent_of_pre_pause_level() -> void:
	_audio.set_bus_volume_percent(&"Music", 50.0)
	var ambient_index: int = AudioServer.get_bus_index(&"Ambient")
	var pre_pause_ambient_db: float = AudioServer.get_bus_volume_db(ambient_index)

	GEventBus.game_paused.emit()

	assert_float(_linear_from_db_direct(&"Music")).is_equal_approx(0.5 * 0.4, 0.001)
	var ducked_ambient_linear: float = db_to_linear(AudioServer.get_bus_volume_db(ambient_index))
	var pre_pause_ambient_linear: float = db_to_linear(pre_pause_ambient_db)
	assert_float(ducked_ambient_linear).is_equal_approx(pre_pause_ambient_linear * 0.4, 0.001)


func test_pause_mutes_sfx_bus_entirely_and_leaves_ui_bus_untouched() -> void:
	_audio.set_bus_volume_percent(&"SFX", 90.0)
	_audio.set_bus_volume_percent(&"UI", 65.0)

	GEventBus.game_paused.emit()

	assert_float(_linear_from_db_direct(&"SFX")).is_equal_approx(0.0, 0.001)
	assert_float(_linear_from_db_direct(&"UI")).is_equal_approx(0.65, 0.001)


func test_unpause_restores_exact_pre_pause_values_not_just_any_nonzero_value() -> void:
	_audio.set_bus_volume_percent(&"Music", 40.0)
	_audio.set_bus_volume_percent(&"SFX", 73.0)

	GEventBus.game_paused.emit()
	GEventBus.game_unpaused.emit()

	assert_float(_linear_from_db_direct(&"Music")).is_equal_approx(0.40, 0.001)
	assert_float(_linear_from_db_direct(&"SFX")).is_equal_approx(0.73, 0.001)


func test_pause_while_music_already_at_a_non_default_player_set_volume_ducks_relative_to_it() -> void:
	# Player had already set Music to 40% before pausing -- the ~40% pause
	# duck must apply relative to that value, not silently reset to the
	# 80% accessibility default first.
	_audio.set_bus_volume_percent(&"Music", 40.0)

	GEventBus.game_paused.emit()

	assert_float(_linear_from_db_direct(&"Music")).is_equal_approx(0.4 * 0.4, 0.001)


func test_repeated_pause_without_intervening_unpause_does_not_re_duck_an_already_ducked_value() -> void:
	_audio.set_bus_volume_percent(&"Music", 50.0)

	GEventBus.game_paused.emit()
	GEventBus.game_paused.emit()  # a second pause signal, no unpause between

	# Still 0.5*0.4 -- not 0.5*0.4*0.4, proving the second pause was a
	# no-op, not a re-duck of the already-ducked value.
	assert_float(_linear_from_db_direct(&"Music")).is_equal_approx(0.5 * 0.4, 0.001)


# ---------------------------------------------------------------------------
# Regression test for the code-review-found bug: ducking must never corrupt
# the persisted preference.
# ---------------------------------------------------------------------------

func test_persisted_preference_is_never_touched_while_paused_even_across_a_save() -> void:
	const SETTINGS_PATH: String = "user://audio_settings.cfg"
	var had_pre_existing: bool = FileAccess.file_exists(SETTINGS_PATH)
	var backup: PackedByteArray = FileAccess.get_file_as_bytes(SETTINGS_PATH) if had_pre_existing else PackedByteArray()

	_audio.set_bus_volume_percent(&"Music", 55.0)

	GEventBus.game_paused.emit()
	# The real-world scenario this guards against: the player quits to
	# desktop from the pause menu, triggering a save while still paused.
	var save_err: Error = _audio.save_settings_to_disk()
	assert_int(save_err).is_equal(OK)

	var fresh_audio := AudioSystem.new()
	add_child(fresh_audio)

	# Must read back the real 55% preference, never the ducked 22%.
	assert_float(fresh_audio.get_bus_volume_percent(&"Music")).is_equal_approx(55.0, 0.001)

	fresh_audio.free()

	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)
	if had_pre_existing:
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
