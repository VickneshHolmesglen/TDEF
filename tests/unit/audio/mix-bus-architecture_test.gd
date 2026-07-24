## Unit tests for Story 001 (epic-12-audio-system): Mix Bus Architecture --
## 4 player-facing buses (Music, SFX, Voice, UI), independently settable
## 0-100%, defaulting to 80%, plus the internal Ambient bus routed as a
## child of Music (GDD Core Rule 1, AC Group 1).
##
## AudioSystem is instantiated directly (`AudioSystem.new()`, no
## add_child()) so `_ready()` never fires -- this suite calls
## `_configure_buses()` directly instead, matching this project's own
## established direct-instantiation unit-test convention. The real
## `AudioServer` bus graph IS exercised for real (this is not a mock) --
## Godot's headless mode still runs a real (dummy-driver) AudioServer, so
## bus creation/naming/routing/volume_db all behave identically to a real
## boot.
##
## Bus state persists on the real, global AudioServer across test runs
## within the same process (buses are not test-scoped) -- after_test()
## removes every bus this suite creates so later suites in the same
## headless run see a clean AudioServer, matching this project's own
## "reset shared Autoload/singleton state between tests" discipline
## (e.g. GMissionEconomy/GGrid resets in other test files).
extends GdUnitTestSuite

var _audio: AudioSystem


func before_test() -> void:
	_audio = AudioSystem.new()


func after_test() -> void:
	if _audio != null and is_instance_valid(_audio):
		_audio.free()
	_audio = null
	# Real AudioServer state outlives this instance -- remove every bus this
	# suite's _configure_buses() call created, highest index first (removing
	# a lower index would shift every bus above it).
	for bus_name: StringName in [&"Ambient", &"UI", &"Voice", &"SFX", &"Music"]:
		var index: int = AudioServer.get_bus_index(bus_name)
		if index != -1:
			AudioServer.remove_bus(index)


# ---------------------------------------------------------------------------
# AC-1: 4 player-facing buses exist, independently settable 0-100%, default 80%
# ---------------------------------------------------------------------------

func test_all_4_player_facing_buses_exist_after_configuration() -> void:
	_audio._configure_buses()

	for bus_name: StringName in [&"Music", &"SFX", &"Voice", &"UI"]:
		assert_bool(_audio.bus_exists(bus_name)).is_true()


func test_all_4_player_facing_buses_default_to_80_percent() -> void:
	_audio._configure_buses()

	for bus_name: StringName in [&"Music", &"SFX", &"Voice", &"UI"]:
		assert_float(_audio.get_bus_volume_percent(bus_name)).is_equal(80.0)


func test_setting_one_bus_to_0_and_another_to_100_leaves_both_correct() -> void:
	_audio._configure_buses()

	_audio.set_bus_volume_percent(&"Music", 0.0)
	_audio.set_bus_volume_percent(&"SFX", 100.0)

	assert_float(_audio.get_bus_volume_percent(&"Music")).is_equal(0.0)
	assert_float(_audio.get_bus_volume_percent(&"SFX")).is_equal(100.0)
	# Untouched buses remain at their own default, confirming no cross-bus leak.
	assert_float(_audio.get_bus_volume_percent(&"Voice")).is_equal(80.0)
	assert_float(_audio.get_bus_volume_percent(&"UI")).is_equal(80.0)


func test_volume_percent_is_clamped_to_0_100_range() -> void:
	_audio._configure_buses()

	_audio.set_bus_volume_percent(&"Music", -50.0)
	assert_float(_audio.get_bus_volume_percent(&"Music")).is_equal(0.0)

	_audio.set_bus_volume_percent(&"Music", 250.0)
	assert_float(_audio.get_bus_volume_percent(&"Music")).is_equal(100.0)


func test_setting_a_non_player_facing_bus_name_is_rejected() -> void:
	_audio._configure_buses()

	_audio.set_bus_volume_percent(&"Ambient", 50.0)

	# Ambient is not in PLAYER_BUSES -- the call is a no-op (logged error),
	# never silently treated as a 5th player slider (GDD Core Rule 1).
	assert_float(_audio.get_bus_volume_percent(&"Ambient")).is_equal(80.0)  # falls back to the dictionary default, never actually set


# ---------------------------------------------------------------------------
# AC-2: adjusting one bus's volume never affects another bus's real
# AudioServer volume_db
# ---------------------------------------------------------------------------

func test_adjusting_music_volume_does_not_affect_sfx_bus_volume_db() -> void:
	_audio._configure_buses()
	var sfx_index: int = AudioServer.get_bus_index(&"SFX")
	var sfx_db_before: float = AudioServer.get_bus_volume_db(sfx_index)

	_audio.set_bus_volume_percent(&"Music", 20.0)

	assert_float(AudioServer.get_bus_volume_db(sfx_index)).is_equal_approx(sfx_db_before, 0.001)


func test_adjusting_sfx_volume_does_not_affect_ui_bus_volume_db() -> void:
	_audio._configure_buses()
	var ui_index: int = AudioServer.get_bus_index(&"UI")
	var ui_db_before: float = AudioServer.get_bus_volume_db(ui_index)

	_audio.set_bus_volume_percent(&"SFX", 10.0)

	assert_float(AudioServer.get_bus_volume_db(ui_index)).is_equal_approx(ui_db_before, 0.001)


func test_adjusting_voice_volume_does_not_affect_music_bus_volume_db() -> void:
	_audio._configure_buses()
	var music_index: int = AudioServer.get_bus_index(&"Music")
	var music_db_before: float = AudioServer.get_bus_volume_db(music_index)

	_audio.set_bus_volume_percent(&"Voice", 0.0)

	assert_float(AudioServer.get_bus_volume_db(music_index)).is_equal_approx(music_db_before, 0.001)


# ---------------------------------------------------------------------------
# Ambient bus: internal, routed as a child of Music, not a 5th player slider
# ---------------------------------------------------------------------------

func test_ambient_bus_exists_and_sends_to_music() -> void:
	_audio._configure_buses()

	assert_bool(_audio.bus_exists(&"Ambient")).is_true()
	assert_that(_audio.get_bus_send(&"Ambient")).is_equal(&"Music")


func test_player_facing_buses_send_to_master() -> void:
	_audio._configure_buses()

	for bus_name: StringName in [&"Music", &"SFX", &"Voice", &"UI"]:
		assert_that(_audio.get_bus_send(bus_name)).is_equal(&"Master")


# ---------------------------------------------------------------------------
# Idempotent bus creation
# ---------------------------------------------------------------------------

func test_configuring_buses_twice_does_not_duplicate_them() -> void:
	_audio._configure_buses()
	var count_before: int = AudioServer.bus_count

	_audio._configure_buses()

	assert_int(AudioServer.bus_count).is_equal(count_before)
