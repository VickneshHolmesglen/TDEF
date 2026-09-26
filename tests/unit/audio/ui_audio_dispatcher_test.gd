extends GdUnitTestSuite

## UI audio cues Task 2: binder creation, denial events (rate-limited), paused playback, real content.

const CUE_MAP_PATH: String = "res://assets/data/audio/audio_cue_map.tres"

var _dispatcher: AudioCueDispatcher


func before_test() -> void:
	_dispatcher = AudioCueDispatcher.new()
	add_child(_dispatcher)
	var map := AudioCueMap.new()
	map.entries = [_entry(&"ui_denied", &"UI")]
	_dispatcher.set_cue_map(map)


func after_test() -> void:
	if _dispatcher != null and is_instance_valid(_dispatcher):
		_dispatcher.free()
	_dispatcher = null


func _entry(event_name: StringName, bus: StringName) -> AudioCueEntry:
	var entry := AudioCueEntry.new()
	entry.event_name = event_name
	entry.bus = bus
	entry.polyphony_group = &""
	entry.spatial = false
	entry.volume_db_offset = 0.0
	return entry


func test_dispatcher_creates_a_ui_audio_binder_child() -> void:
	var binder: Node = _dispatcher.get_node_or_null("UiAudioBinder")
	assert_object(binder).is_not_null()
	assert_bool(binder is UiAudioBinder).is_true()


func test_tower_placement_blocked_dispatches_ui_denied() -> void:
	GEventBus.tower_placement_blocked.emit([], Vector2i(1, 1))
	assert_int(_dispatcher.get_dispatch_count()).is_equal(1)
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"ui_denied")


func test_item_pickup_rejected_dispatches_ui_denied() -> void:
	GEventBus.item_pickup_rejected.emit("x", "y", 1, "full")
	assert_int(_dispatcher.get_dispatch_count()).is_equal(1)
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"ui_denied")


func test_denial_events_are_rate_limited() -> void:
	GEventBus.tower_placement_blocked.emit([], Vector2i(1, 1))
	GEventBus.tower_placement_blocked.emit([], Vector2i(2, 1))
	GEventBus.item_pickup_rejected.emit("x", "y", 1, "full")
	assert_int(_dispatcher.get_dispatch_count()).is_equal(1)
	_dispatcher._last_denied_event_msec = Time.get_ticks_msec() - AudioCueDispatcher.DENIED_EVENT_MIN_GAP_MSEC - 1
	GEventBus.tower_placement_blocked.emit([], Vector2i(3, 1))
	assert_int(_dispatcher.get_dispatch_count()).is_equal(2)


func test_gap_constant_is_300_msec() -> void:
	assert_int(AudioCueDispatcher.DENIED_EVENT_MIN_GAP_MSEC).is_equal(300)


func test_ui_bus_cue_plays_while_the_tree_is_paused() -> void:
	# A stream-bearing UI cue must be audible on the Pause Menu: its pooled player must keep processing.
	var entry: AudioCueEntry = _entry(&"ui_denied", &"UI")
	entry.stream = load("res://assets/audio/sfx/ui_denied.wav") as AudioStream
	var map := AudioCueMap.new()
	map.entries = [entry]
	_dispatcher.set_cue_map(map)
	get_tree().paused = true
	_dispatcher.dispatch_cue(&"ui_denied")
	var playing_mode: int = -1
	for player: AudioStreamPlayer in _dispatcher._players:
		if player.playing:
			playing_mode = player.process_mode
	get_tree().paused = false
	assert_int(playing_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_binder_processes_while_paused() -> void:
	var binder: Node = _dispatcher.get_node("UiAudioBinder")
	assert_int(binder.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_real_map_has_the_four_ui_cues() -> void:
	var map: AudioCueMap = load(CUE_MAP_PATH) as AudioCueMap
	var by_event: Dictionary = {}
	for entry: AudioCueEntry in map.entries:
		by_event[entry.event_name] = entry
	var expected: Dictionary[StringName, StringName] = {
		&"ui_click": &"ui_confirm_cancel",
		&"ui_confirm": &"activation_confirm",
		&"ui_cancel": &"ui_confirm_cancel",
		&"ui_denied": &"denial_rejection",
	}
	for event: StringName in expected:
		assert_bool(by_event.has(event)).override_failure_message("%s missing" % event).is_true()
		var entry: AudioCueEntry = by_event[event]
		assert_that(entry.bus).is_equal(&"UI")
		assert_that(entry.polyphony_group).is_equal(expected[event])
		assert_bool(entry.spatial).is_false()
		assert_object(entry.stream).is_not_null()
	assert_bool((by_event[&"ui_click"] as AudioCueEntry).stream is AudioStreamRandomizer).is_true()


func test_voice_limiter_has_the_three_ui_families() -> void:
	for family: StringName in [&"ui_confirm_cancel", &"activation_confirm", &"denial_rejection"]:
		assert_bool(VoiceLimiter.DEFAULT_FAMILY_CAPS.has(family)).is_true()
