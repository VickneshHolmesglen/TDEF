extends GdUnitTestSuite

## Integration tests for real playback in MusicAmbientController (music-
## ambient-stems spec §3.3/§8, AC-2..AC-12). Levels are driven only via
## advance_time()/force_finish_transition() (no real waiting). Streams are
## tiny silent AudioStreamWAV fixtures.

const S := MusicAmbientController.MusicState

var _controller: MusicAmbientController


func before_test() -> void:
	_controller = MusicAmbientController.new()
	add_child(_controller)


func after_test() -> void:
	if _controller != null and is_instance_valid(_controller):
		remove_child(_controller)
		_controller.free()
	_controller = null


func _fixture_stream() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(4410 * 2)
	wav.data = data
	return wav


func _fixture_map() -> MusicAmbientMap:
	var map := MusicAmbientMap.new()
	map.contemplative = _fixture_stream()
	map.measured = _fixture_stream()
	map.urgent = _fixture_stream()
	map.measured_urgent = _fixture_stream()
	map.ambient_base_bed = _fixture_stream()
	map.ambient_combat_layer = _fixture_stream()
	return map


func _phase(previous: String, new_phase: String) -> void:
	GEventBus.mission_phase_changed.emit(previous, new_phase, 0.0)


func test_level_to_volume_db_is_equal_power() -> void:
	assert_float(MusicAmbientController.level_to_volume_db(1.0)).is_equal_approx(0.0, 0.001)
	assert_float(MusicAmbientController.level_to_volume_db(0.5)).is_equal_approx(-3.0103, 0.01)
	assert_float(MusicAmbientController.level_to_volume_db(0.0)).is_less(-60.0)


func test_set_stream_map_starts_contemplative_and_ambient_base_only() -> void:
	_controller.set_stream_map(_fixture_map())
	assert_float(_controller.get_stem_level(S.CONTEMPLATIVE)).is_equal_approx(1.0, 0.0001)
	assert_bool(_controller.is_stem_playing(S.CONTEMPLATIVE)).is_true()
	for state: int in [S.MEASURED, S.URGENT, S.MEASURED_URGENT]:
		assert_bool(_controller.is_stem_playing(state)).is_false()
		assert_float(_controller.get_stem_level(state)).is_equal_approx(0.0, 0.0001)
	assert_bool(_controller.is_ambient_base_playing()).is_true()
	assert_bool(_controller.is_ambient_combat_playing()).is_false()


func test_scout_crossfade_is_equal_power_and_completes() -> void:
	_controller.set_stream_map(_fixture_map())
	_phase("SANCTUARY", "SCOUT")
	_controller.advance_time(0.5)
	assert_float(_controller.get_stem_level(S.MEASURED)).is_equal_approx(0.5, 0.001)
	assert_float(_controller.get_stem_level(S.CONTEMPLATIVE)).is_equal_approx(0.5, 0.001)
	assert_float(_controller.get_stem_volume_db(S.MEASURED)).is_equal_approx(-3.0103, 0.05)
	_controller.advance_time(0.5)
	assert_float(_controller.get_stem_level(S.MEASURED)).is_equal_approx(1.0, 0.001)
	assert_float(_controller.get_stem_level(S.CONTEMPLATIVE)).is_equal_approx(0.0, 0.001)
	assert_bool(_controller.is_stem_playing(S.CONTEMPLATIVE)).is_false()


func test_countdown_anticipatory_crossfade_lands_exactly_at_countdown_end() -> void:
	_controller.set_stream_map(_fixture_map())
	_phase("SANCTUARY", "SCOUT")
	_controller.force_finish_transition()
	GEventBus.wave_countdown_warning.emit(10)
	_controller.advance_time(5.0)
	assert_float(_controller.get_stem_level(S.URGENT)).is_equal_approx(0.5, 0.001)
	_controller.advance_time(5.0)
	assert_float(_controller.get_stem_level(S.URGENT)).is_equal_approx(1.0, 0.001)
	assert_float(_controller.get_stem_level(S.MEASURED)).is_equal_approx(0.0, 0.001)


func test_wave_clear_hard_duck_takes_urgent_to_measured_urgent_in_point_four_seconds() -> void:
	_controller.set_stream_map(_fixture_map())
	_phase("SCOUT", "WAVE_ACTIVE")
	_controller.force_finish_transition()
	_phase("WAVE_ACTIVE", "INTERMISSION")
	_controller.advance_time(0.4)
	assert_float(_controller.get_stem_level(S.URGENT)).is_equal_approx(0.0, 0.001)
	assert_float(_controller.get_stem_level(S.MEASURED_URGENT)).is_equal_approx(1.0, 0.001)


func test_interrupted_crossfade_retargets_smoothly_without_jumps() -> void:
	_controller.set_stream_map(_fixture_map())
	_phase("SANCTUARY", "SCOUT")
	_controller.advance_time(0.4)
	var measured_before: float = _controller.get_stem_level(S.MEASURED)
	var contemplative_before: float = _controller.get_stem_level(S.CONTEMPLATIVE)
	_phase("SCOUT", "WAVE_ACTIVE")
	assert_float(_controller.get_stem_level(S.MEASURED)).is_equal_approx(measured_before, 0.0001)
	assert_float(_controller.get_stem_level(S.CONTEMPLATIVE)).is_equal_approx(contemplative_before, 0.0001)
	for i: int in range(20):
		_controller.advance_time(0.1)
		for state: int in [S.CONTEMPLATIVE, S.MEASURED, S.URGENT, S.MEASURED_URGENT]:
			assert_float(_controller.get_stem_level(state)).is_between(0.0, 1.0)
	assert_float(_controller.get_stem_level(S.URGENT)).is_equal_approx(1.0, 0.001)


func test_freeze_holds_levels_and_resume_continues_from_the_same_point() -> void:
	_controller.set_stream_map(_fixture_map())
	_phase("SANCTUARY", "SCOUT")
	_controller.advance_time(0.3)
	var held: float = _controller.get_stem_level(S.MEASURED)
	_controller.freeze_transition()
	_controller.advance_time(5.0)
	assert_float(_controller.get_stem_level(S.MEASURED)).is_equal_approx(held, 0.0001)
	_controller.resume_transition()
	_controller.advance_time(0.7)
	assert_float(_controller.get_stem_level(S.MEASURED)).is_equal_approx(1.0, 0.001)


func test_force_finish_transition_snaps_levels_and_stops_zero_level_players() -> void:
	_controller.set_stream_map(_fixture_map())
	_phase("SANCTUARY", "SCOUT")
	_controller.force_finish_transition()
	assert_float(_controller.get_stem_level(S.MEASURED)).is_equal_approx(1.0, 0.0001)
	assert_float(_controller.get_stem_level(S.CONTEMPLATIVE)).is_equal_approx(0.0, 0.0001)
	assert_bool(_controller.is_stem_playing(S.CONTEMPLATIVE)).is_false()
	assert_bool(_controller.is_stem_playing(S.MEASURED)).is_true()


func test_ambient_base_bed_starts_once_and_never_restarts() -> void:
	var map: MusicAmbientMap = _fixture_map()
	_controller.set_stream_map(map)
	var base: AudioStreamPlayer = _controller.get_ambient_base_player()
	_phase("SANCTUARY", "SCOUT")
	_phase("SCOUT", "WAVE_ACTIVE")
	_phase("WAVE_ACTIVE", "INTERMISSION")
	_controller.set_stream_map(map)
	assert_int(_controller.get_ambient_base_bed_start_count()).is_equal(1)
	assert_object(_controller.get_ambient_base_player()).is_same(base)
	assert_bool(_controller.is_ambient_base_playing()).is_true()


func test_combat_layer_fades_in_over_one_and_a_half_seconds_and_out_over_two() -> void:
	_controller.set_stream_map(_fixture_map())
	_phase("SCOUT", "WAVE_ACTIVE")
	_controller.advance_time(0.75)
	assert_float(_controller.get_ambient_combat_level()).is_equal_approx(0.5, 0.001)
	assert_bool(_controller.is_ambient_combat_playing()).is_true()
	_controller.advance_time(0.75)
	assert_float(_controller.get_ambient_combat_level()).is_equal_approx(1.0, 0.001)
	_phase("WAVE_ACTIVE", "INTERMISSION")
	_controller.advance_time(1.0)
	assert_float(_controller.get_ambient_combat_level()).is_equal_approx(0.5, 0.001)
	_controller.advance_time(1.0)
	assert_float(_controller.get_ambient_combat_level()).is_equal_approx(0.0, 0.001)
	assert_bool(_controller.is_ambient_combat_playing()).is_false()


func test_null_map_and_null_slots_are_silent_and_error_free() -> void:
	_controller.set_stream_map(null)
	for state: int in [S.CONTEMPLATIVE, S.MEASURED, S.URGENT, S.MEASURED_URGENT]:
		assert_bool(_controller.is_stem_playing(state)).is_false()
		assert_float(_controller.get_stem_level(state)).is_equal_approx(0.0, 0.0001)
	assert_bool(_controller.is_ambient_base_playing()).is_false()
	var partial := MusicAmbientMap.new()
	partial.contemplative = _fixture_stream()
	_controller.set_stream_map(partial)
	assert_bool(_controller.is_stem_playing(S.CONTEMPLATIVE)).is_true()
	assert_object(_controller.get_stem_player(S.URGENT)).is_null()
	_phase("SANCTUARY", "SCOUT")
	_controller.advance_time(2.0)
	assert_bool(_controller.is_stem_playing(S.MEASURED)).is_false()


func test_players_are_pause_proof_and_on_the_right_buses() -> void:
	_controller.set_stream_map(_fixture_map())
	for state: int in [S.CONTEMPLATIVE, S.MEASURED, S.URGENT, S.MEASURED_URGENT]:
		var player: AudioStreamPlayer = _controller.get_stem_player(state)
		assert_int(player.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
		assert_str(String(player.bus)).is_equal("Music")
	for player: AudioStreamPlayer in [_controller.get_ambient_base_player(), _controller.get_ambient_combat_player()]:
		assert_int(player.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
		assert_str(String(player.bus)).is_equal("Ambient")


func test_streams_are_made_loopable() -> void:
	var map: MusicAmbientMap = _fixture_map()
	_controller.set_stream_map(map)
	var wav: AudioStreamWAV = map.contemplative as AudioStreamWAV
	assert_int(wav.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int(wav.loop_end).is_equal(4410)
