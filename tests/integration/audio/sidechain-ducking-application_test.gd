## Integration tests for the sidechain-ducking APPLICATION step (2026-08-06) --
## closes the real gap found while investigating a user-reported issue:
## Formula F3's attack/hold/release envelope was fully implemented and
## unit-tested in VoiceLimiter, and AudioCueDispatcher._process() was already
## ticking it every frame, but nothing ever read the resulting
## get_sidechain_db_offset() and applied it to real AudioServer output -- the
## math ran correctly in total isolation from anything audible. Formula F3's
## own envelope math itself is exhaustively covered by
## sidechain-ducking-envelope_test.gd (deterministic, VoiceLimiter-only); this
## suite proves the missing final step: AudioSystem._process() reads the
## current offset and writes it to the real bus dB every frame.
##
## Real scene instantiation (add_child()), exercising the real
## AudioSystem/AudioCueDispatcher/VoiceLimiter/AudioServer wiring, not mocked.
## Temporarily disables the real GAudioSystem Autoload's own processing for
## this suite's duration -- matches pause-behavior_test.gd's own established
## isolation precedent (that suite disconnects PauseDuckController's signal
## subscriptions for the identical reason: a second AudioSystem instance
## sharing the same global AudioServer would otherwise race against the real
## Autoload's own continuous reapplication every frame). A signal can be
## disconnected; a _process() override can't, so this suite uses
## PROCESS_MODE_DISABLED instead of a disconnect.
extends GdUnitTestSuite

var _audio: AudioSystem
var _real_audio: Node
var _real_audio_process_mode: int = Node.PROCESS_MODE_INHERIT


func before_test() -> void:
	_audio = AudioSystem.new()
	add_child(_audio)

	_real_audio = get_tree().root.get_node_or_null(^"GAudioSystem")
	if _real_audio != null:
		_real_audio_process_mode = _real_audio.process_mode
		_real_audio.process_mode = Node.PROCESS_MODE_DISABLED


func after_test() -> void:
	if get_tree().paused:
		get_tree().paused = false
	if _audio != null and is_instance_valid(_audio):
		_audio.free()
	_audio = null
	# Same reasoning as pause-behavior_test.gd's after_test(): Ambient's
	# volume_db is never reset by _configure_buses(), so a later test's
	# "resting" Ambient reading would otherwise be whatever this suite last
	# ducked it to, compounding across tests sharing the global AudioServer.
	for bus_name: StringName in [&"Ambient", &"UI", &"Voice", &"SFX", &"Music"]:
		var index: int = AudioServer.get_bus_index(bus_name)
		if index != -1:
			AudioServer.remove_bus(index)
	if _real_audio != null and is_instance_valid(_real_audio):
		_real_audio.process_mode = _real_audio_process_mode


func test_sfx_to_ambient_trigger_ducks_the_real_ambient_bus_output() -> void:
	_audio.cue_dispatcher.voice_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)

	for i in range(10):
		await get_tree().process_frame

	var ambient_index: int = AudioServer.get_bus_index(&"Ambient")
	assert_float(AudioServer.get_bus_volume_db(ambient_index)).is_equal_approx(VoiceLimiter.SFX_TO_AMBIENT_DUCK_DB, 1.0)


func test_ui_to_music_and_sfx_trigger_ducks_both_real_buses_relative_to_their_own_percent() -> void:
	_audio.set_bus_volume_percent(&"Music", 60.0)
	_audio.set_bus_volume_percent(&"SFX", 60.0)
	var base_db: float = linear_to_db(0.6)

	_audio.cue_dispatcher.voice_limiter.trigger_sidechain(VoiceLimiter.UI_TO_MUSIC_AND_SFX)
	for i in range(10):
		await get_tree().process_frame

	assert_float(_audio.get_bus_volume_db_direct(&"Music")).is_equal_approx(base_db + VoiceLimiter.UI_TO_MUSIC_AND_SFX_DUCK_DB, 1.0)
	assert_float(_audio.get_bus_volume_db_direct(&"SFX")).is_equal_approx(base_db + VoiceLimiter.UI_TO_MUSIC_AND_SFX_DUCK_DB, 1.0)


func test_offset_returns_to_baseline_after_full_release() -> void:
	_audio.cue_dispatcher.voice_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)
	# attack(15ms) + release_delay(150ms) + release_time(250ms) ~= 415ms;
	# 120 frames at 60fps ~= 2000ms, comfortably past full release even
	# accounting for headless test frame-delta variance.
	for i in range(120):
		await get_tree().process_frame

	var ambient_index: int = AudioServer.get_bus_index(&"Ambient")
	assert_float(AudioServer.get_bus_volume_db(ambient_index)).is_equal_approx(0.0, 0.5)


func test_persisted_preference_is_never_touched_by_sidechain_ducking() -> void:
	_audio.set_bus_volume_percent(&"Music", 45.0)

	_audio.cue_dispatcher.voice_limiter.trigger_sidechain(VoiceLimiter.UI_TO_MUSIC_AND_SFX)
	for i in range(10):
		await get_tree().process_frame

	assert_float(_audio.get_bus_volume_percent(&"Music")).is_equal_approx(45.0, 0.001)


## Real-world-verified via Godot MCP before this test was written: with
## SceneTree.paused set genuinely true (matching pause_menu.gd's own real
## order -- pause the tree, then fire the informational signal), a live
## running game held the ducked value rock-stable across every sampled frame.
func test_pause_freezes_the_sidechain_application_alongside_the_envelope() -> void:
	_audio.cue_dispatcher.voice_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)
	for i in range(10):
		await get_tree().process_frame
	var ambient_index: int = AudioServer.get_bus_index(&"Ambient")
	var during_db: float = AudioServer.get_bus_volume_db(ambient_index)

	get_tree().paused = true
	for i in range(10):
		await get_tree().process_frame
	var while_paused_db: float = AudioServer.get_bus_volume_db(ambient_index)
	get_tree().paused = false

	assert_float(while_paused_db).is_equal_approx(during_db, 0.01)
