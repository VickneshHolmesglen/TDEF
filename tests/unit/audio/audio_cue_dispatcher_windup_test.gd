extends GdUnitTestSuite

## Wind-up presentation Task 4: wind-up warning (rate-limited), whiff, and Hero death cues.

var _dispatcher: AudioCueDispatcher
var _original_mission_path: String
var _original_sanctuary_path: String


func before_test() -> void:
	# hero_died also reaches the live GSceneManager: stub its paths and skip the death hold so the
	# emit below cannot leave a delayed real Sanctuary transition behind.
	_original_mission_path = GSceneManager._mission_scene_path
	_original_sanctuary_path = GSceneManager._sanctuary_scene_path
	GSceneManager._inject("res://tests/fixtures/scene_manager/StubScene.tscn", "res://tests/fixtures/scene_manager/StubScene.tscn")
	GSceneManager._death_hold_seconds = 0.0
	_dispatcher = AudioCueDispatcher.new()
	add_child(_dispatcher)
	var map := AudioCueMap.new()
	map.entries = [
		_entry(&"monster_windup_warning"),
		_entry(&"monster_attack_whiff"),
		_entry(&"hero_died"),
	]
	_dispatcher.set_cue_map(map)


func after_test() -> void:
	if GSceneManager._transition_in_progress:
		await GEventBus.scene_transition_completed
	GSceneManager._death_hold_seconds = GSceneManager.HERO_DEATH_HOLD_SECONDS
	GSceneManager._inject(_original_mission_path, _original_sanctuary_path)
	GSceneManager._transition_in_progress = false
	if _dispatcher != null and is_instance_valid(_dispatcher):
		_dispatcher.free()
	_dispatcher = null


func _entry(event_name: StringName) -> AudioCueEntry:
	var entry := AudioCueEntry.new()
	entry.event_name = event_name
	entry.bus = &"SFX"
	entry.polyphony_group = &""
	entry.spatial = false
	entry.volume_db_offset = 0.0
	return entry


func test_windup_warning_is_rate_limited_to_one_per_gap() -> void:
	GEventBus.monster_hero_attack_winding_up.emit(1, 0.5)
	GEventBus.monster_hero_attack_winding_up.emit(2, 0.5)
	assert_int(_dispatcher.get_dispatch_count()).is_equal(1)
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"monster_windup_warning")
	_dispatcher._last_windup_warning_msec = Time.get_ticks_msec() - AudioCueDispatcher.WINDUP_WARNING_MIN_GAP_MSEC - 1
	GEventBus.monster_hero_attack_winding_up.emit(3, 0.5)
	assert_int(_dispatcher.get_dispatch_count()).is_equal(2)


func test_whiff_dispatches_only_on_miss() -> void:
	GEventBus.monster_hero_attack_resolved.emit(1, true)
	assert_int(_dispatcher.get_dispatch_count()).is_equal(0)
	GEventBus.monster_hero_attack_resolved.emit(1, false)
	assert_int(_dispatcher.get_dispatch_count()).is_equal(1)
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"monster_attack_whiff")


func test_hero_died_dispatches_its_cue() -> void:
	GEventBus.hero_died.emit()
	assert_int(_dispatcher.get_dispatch_count()).is_equal(1)
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"hero_died")


func test_real_cue_map_contains_all_three_events() -> void:
	var map: AudioCueMap = load("res://assets/data/audio/audio_cue_map.tres") as AudioCueMap
	var names: Array[StringName] = []
	for entry: AudioCueEntry in map.entries:
		names.append(entry.event_name)
	for event: StringName in [&"monster_windup_warning", &"monster_attack_whiff", &"hero_died"]:
		assert_bool(names.has(event)).override_failure_message("%s missing from real map" % event).is_true()
