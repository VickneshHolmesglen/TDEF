## Integration tests for Story 005 (epic-12-audio-system): Volume Preference
## Persistence -- AC-14 (AC-13 is covered separately by a real scripted
## process-relaunch harness, per this story's own Implementation Notes:
## `tools/audio-relaunch-harness/run_harness.sh` +
## `production/qa/evidence/story-005-ac13-relaunch-evidence.md`, since this
## project's normal in-process gdUnit4 runner cannot exercise a genuine
## process kill/relaunch).
##
## Uses real scene instantiation (`add_child()`) so `AudioSystem._ready()`
## actually runs its real disk-load path, and calls the real
## `GSavePersistence.load_slot()` -- not a mock.
extends GdUnitTestSuite

var TEST_SETTINGS_PATH: String = UserDataPaths.root() + "audio_settings.cfg"

var _audio: AudioSystem
var _pre_existing_settings_backup: PackedByteArray = PackedByteArray()
var _had_pre_existing_settings: bool = false


func before_test() -> void:
	# Isolate from any real settings file left by a previous run/harness --
	# back it up and restore in after_test(), matching this project's own
	# "reset shared state between tests" discipline for other global
	# resources (e.g. AudioServer bus cleanup in mix-bus-architecture_test.gd).
	_had_pre_existing_settings = FileAccess.file_exists(TEST_SETTINGS_PATH)
	if _had_pre_existing_settings:
		_pre_existing_settings_backup = FileAccess.get_file_as_bytes(TEST_SETTINGS_PATH)
		DirAccess.remove_absolute(TEST_SETTINGS_PATH)

	_audio = AudioSystem.new()
	add_child(_audio)


func after_test() -> void:
	if _audio != null and is_instance_valid(_audio):
		_audio.free()
	_audio = null

	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(TEST_SETTINGS_PATH)
	if _had_pre_existing_settings:
		var f := FileAccess.open(TEST_SETTINGS_PATH, FileAccess.WRITE)
		f.store_buffer(_pre_existing_settings_backup)
		f.close()


# ---------------------------------------------------------------------------
# AC-14: neither loading a save slot nor a fresh game start touches audio
# volume settings.
# ---------------------------------------------------------------------------

func test_loading_a_save_slot_does_not_alter_bus_volume() -> void:
	_audio.set_bus_volume_percent(&"Music", 40.0)

	# Real call against the real GSavePersistence -- AudioSystem never
	# registers a SaveRestorer (Core Rule 6's own forbidden-pattern rule),
	# so this can't touch it regardless of whether the slot itself exists.
	GSavePersistence.load_slot(99)

	assert_float(_audio.get_bus_volume_percent(&"Music")).is_equal(40.0)


func test_sanctuary_state_restored_signal_does_not_alter_bus_volume() -> void:
	_audio.set_bus_volume_percent(&"SFX", 25.0)

	# The real signal GSavePersistence's own restore cycle broadcasts on a
	# successful slot load -- AudioSystem has no subscriber for it at all.
	GEventBus.sanctuary_state_restored.emit(1)

	assert_float(_audio.get_bus_volume_percent(&"SFX")).is_equal(25.0)


func test_audio_system_is_never_registered_as_a_save_restorer() -> void:
	# Structural proof (Core Rule 6's explicit "Forbidden" manifest rule):
	# AudioSystem exposes no get_save_key()/get_save_data()/
	# restore_save_data() SaveRestorer interface at all, so GSavePersistence
	# has no mechanism to ever call into it during a slot load or save.
	assert_bool(_audio.has_method(&"get_save_key")).is_false()
	assert_bool(_audio.has_method(&"restore_save_data")).is_false()


# ---------------------------------------------------------------------------
# Fresh-install default + disk round-trip (in-process portion of AC-13's own
# mechanism -- the real cross-process relaunch itself is the separate
# harness referenced above).
# ---------------------------------------------------------------------------

func test_fresh_install_with_no_settings_file_keeps_the_80_percent_default() -> void:
	assert_bool(FileAccess.file_exists(TEST_SETTINGS_PATH)).is_false()

	assert_float(_audio.get_bus_volume_percent(&"Music")).is_equal(80.0)


func test_save_then_load_round_trips_a_non_default_volume() -> void:
	_audio.set_bus_volume_percent(&"Music", 40.0)
	var save_err: Error = _audio.save_settings_to_disk()
	assert_int(save_err).is_equal(OK)

	var fresh_audio := AudioSystem.new()
	add_child(fresh_audio)

	assert_float(fresh_audio.get_bus_volume_percent(&"Music")).is_equal(40.0)
	# Untouched buses still fall back to the 80% default from Story 001.
	assert_float(fresh_audio.get_bus_volume_percent(&"SFX")).is_equal(80.0)

	fresh_audio.free()
