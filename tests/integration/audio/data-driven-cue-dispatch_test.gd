## Integration tests for Story 003 (epic-12-audio-system): Data-Driven Cue
## Dispatch -- AC Group 3 (Core Rules 3-4).
##
## Uses real scene instantiation (`add_child()`) so `AudioCueDispatcher`
## actually connects to the real `GEventBus`, and injects test-authored
## `AudioCueEntry` fixtures via `set_cue_map()` (no real content exists yet,
## per OQ-2 -- matches this story's own Implementation Notes).
extends GdUnitTestSuite

var _dispatcher: AudioCueDispatcher


func before_test() -> void:
	_dispatcher = AudioCueDispatcher.new()
	add_child(_dispatcher)


func after_test() -> void:
	if _dispatcher != null and is_instance_valid(_dispatcher):
		_dispatcher.free()
	_dispatcher = null


func _fixture_entry(event_name: StringName, bus: StringName, polyphony_group: StringName, spatial: bool) -> AudioCueEntry:
	var entry := AudioCueEntry.new()
	entry.event_name = event_name
	entry.bus = bus
	entry.polyphony_group = polyphony_group
	entry.spatial = spatial
	entry.volume_db_offset = 0.0
	return entry


# ---------------------------------------------------------------------------
# AC-7: boss_died plays its mapped Discovery/Milestone Fanfare cue.
# ---------------------------------------------------------------------------

func test_boss_died_dispatches_its_mapped_fanfare_cue() -> void:
	var map := AudioCueMap.new()
	map.entries = [_fixture_entry(&"boss_died", &"SFX", &"discovery_fanfare", false)]
	_dispatcher.set_cue_map(map)

	GEventBus.boss_died.emit(1, &"test_boss", 3, "killed")

	assert_that(_dispatcher.get_last_played_event()).is_equal(&"boss_died")
	assert_that(_dispatcher.get_last_played_bus()).is_equal(&"SFX")
	assert_int(_dispatcher.get_dispatch_count()).is_equal(1)


# ---------------------------------------------------------------------------
# AC-8: tower_attacked applies Formula F2 world-space distance attenuation.
# ---------------------------------------------------------------------------

func test_tower_attacked_spatial_cue_applies_formula_f2_worked_example() -> void:
	var entry := _fixture_entry(&"tower_attacked", &"SFX", &"combat_impact", true)
	entry.volume_db_offset = linear_to_db(0.7)
	var map := AudioCueMap.new()
	map.entries = [entry]
	_dispatcher.set_cue_map(map)

	# GDD worked example: V_base=0.7, d=8, R=15 -> 0.7 * clamp(1-8/15,0,1) = 0.327
	_dispatcher.dispatch_cue(&"tower_attacked", 8.0)

	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(0.327, 0.001)


func test_spatial_cue_at_zero_distance_plays_at_full_base_volume() -> void:
	var entry := _fixture_entry(&"tower_attacked", &"SFX", &"combat_impact", true)
	var map := AudioCueMap.new()
	map.entries = [entry]
	_dispatcher.set_cue_map(map)

	_dispatcher.dispatch_cue(&"tower_attacked", 0.0)

	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(1.0, 0.001)


func test_spatial_cue_beyond_max_audible_radius_is_silent() -> void:
	var entry := _fixture_entry(&"tower_attacked", &"SFX", &"combat_impact", true)
	var map := AudioCueMap.new()
	map.entries = [entry]
	_dispatcher.set_cue_map(map)

	_dispatcher.dispatch_cue(&"tower_attacked", AudioCueDispatcher.MAX_AUDIBLE_RADIUS + 5.0)

	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(0.0, 0.001)


func test_negative_distance_is_clamped_to_zero_not_treated_as_an_error() -> void:
	var entry := _fixture_entry(&"tower_attacked", &"SFX", &"combat_impact", true)
	var map := AudioCueMap.new()
	map.entries = [entry]
	_dispatcher.set_cue_map(map)

	_dispatcher.dispatch_cue(&"tower_attacked", -5.0)

	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(1.0, 0.001)


# ---------------------------------------------------------------------------
# AC-9: sanctuary_structure_built ignores Formula F2 even at real distance.
# ---------------------------------------------------------------------------

func test_sanctuary_structure_built_plays_full_volume_regardless_of_distance() -> void:
	var entry := _fixture_entry(&"sanctuary_structure_built", &"SFX", &"progress_blip", false)
	var map := AudioCueMap.new()
	map.entries = [entry]
	_dispatcher.set_cue_map(map)

	GEventBus.sanctuary_structure_built.emit("watchtower_01", "watchtower")

	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(1.0, 0.001)


func test_non_spatial_cue_ignores_distance_argument_entirely() -> void:
	var entry := _fixture_entry(&"sanctuary_structure_built", &"SFX", &"progress_blip", false)
	var map := AudioCueMap.new()
	map.entries = [entry]
	_dispatcher.set_cue_map(map)

	# Even called directly with a huge distance, a non-spatial cue never attenuates.
	_dispatcher.dispatch_cue(&"sanctuary_structure_built", 999.0)

	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(1.0, 0.001)


# ---------------------------------------------------------------------------
# AC-10: generic dispatch works across genuinely different events via the
# same lookup path.
# ---------------------------------------------------------------------------

func test_two_different_events_each_dispatch_their_own_mapped_cue() -> void:
	var map := AudioCueMap.new()
	map.entries = [
		_fixture_entry(&"boss_died", &"SFX", &"discovery_fanfare", false),
		_fixture_entry(&"component_crafted", &"UI", &"activation_confirm", false),
	]
	_dispatcher.set_cue_map(map)

	GEventBus.boss_died.emit(1, &"test_boss", 3, "killed")
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"boss_died")
	assert_that(_dispatcher.get_last_played_bus()).is_equal(&"SFX")

	GEventBus.component_crafted.emit("iron_plate", "armor", 2)
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"component_crafted")
	assert_that(_dispatcher.get_last_played_bus()).is_equal(&"UI")

	assert_int(_dispatcher.get_dispatch_count()).is_equal(2)


# ---------------------------------------------------------------------------
# AC-10a: no matching entry is a silent no-op.
# ---------------------------------------------------------------------------

func test_event_with_no_map_entry_is_a_silent_no_op() -> void:
	var map := AudioCueMap.new()
	map.entries = [_fixture_entry(&"boss_died", &"SFX", &"discovery_fanfare", false)]
	_dispatcher.set_cue_map(map)

	# hero_damage_taken is in the 16-event subscription list but has no map
	# entry -- the realistic OQ-2 case (most events have no content yet).
	GEventBus.hero_damage_taken.emit(10, 0)

	assert_int(_dispatcher.get_dispatch_count()).is_equal(0)
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"")


func test_dispatch_with_empty_cue_map_never_errors() -> void:
	GEventBus.game_paused.emit()
	GEventBus.game_unpaused.emit()

	assert_int(_dispatcher.get_dispatch_count()).is_equal(0)


# ---------------------------------------------------------------------------
# Story 004 wiring: real dispatch registers a voice against its family's cap.
# ---------------------------------------------------------------------------

func test_dispatched_cue_registers_a_voice_against_its_polyphony_group() -> void:
	var map := AudioCueMap.new()
	map.entries = [_fixture_entry(&"boss_died", &"SFX", &"discovery_fanfare", false)]
	_dispatcher.set_cue_map(map)

	GEventBus.boss_died.emit(1, &"test_boss", 3, "killed")

	assert_int(_dispatcher.voice_limiter.get_active_voice_count(&"discovery_fanfare")).is_equal(1)
	assert_int(_dispatcher.get_last_dispatch_voice_id()).is_greater(-1)


func test_dispatching_beyond_a_familys_cap_steals_the_oldest_voice_through_real_dispatch() -> void:
	# Discovery Fanfare's real cap is 1 (VoiceLimiter.DEFAULT_FAMILY_CAPS) --
	# a second real dispatch through the same family must steal, not stack.
	var map := AudioCueMap.new()
	map.entries = [
		_fixture_entry(&"boss_died", &"SFX", &"discovery_fanfare", false),
		_fixture_entry(&"sanctuary_structure_built", &"SFX", &"discovery_fanfare", false),
	]
	_dispatcher.set_cue_map(map)

	GEventBus.boss_died.emit(1, &"test_boss", 3, "killed")
	var first_voice_id: int = _dispatcher.get_last_dispatch_voice_id()

	GEventBus.sanctuary_structure_built.emit("watchtower_01", "watchtower")

	assert_int(_dispatcher.voice_limiter.get_active_voice_count(&"discovery_fanfare")).is_equal(1)
	assert_int(_dispatcher.voice_limiter.get_last_stolen_voice_id()).is_equal(first_voice_id)


func test_a_cue_with_no_polyphony_group_never_registers_a_voice() -> void:
	var map := AudioCueMap.new()
	map.entries = [_fixture_entry(&"boss_died", &"SFX", &"", false)]
	_dispatcher.set_cue_map(map)

	GEventBus.boss_died.emit(1, &"test_boss", 3, "killed")

	assert_int(_dispatcher.get_last_dispatch_voice_id()).is_equal(-1)
