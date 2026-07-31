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


# ---------------------------------------------------------------------------
# Formula F1 wiring: real dispatch applies bus-wide concurrent-cue ducking.
# ---------------------------------------------------------------------------

func test_sixth_concurrent_voice_ducks_to_the_gdds_worked_example() -> void:
	# GDD worked example: V_base=0.8, N=6, k=0.05, D_floor=0.3 -> 0.60.
	# Pre-existing voices are spread across two other families (4 +
	# progress_blip's own cap, 1 denial_rejection) rather than piled onto
	# one, both to stay under each family's own cap (so none get stolen and
	# silently undercount) and to prove Formula F1's N is bus-wide, not
	# scoped to a single family's VoiceLimiter bucket.
	var entry := _fixture_entry(&"tower_attacked", &"SFX", &"combat_impact", false)
	entry.volume_db_offset = linear_to_db(0.8)
	var map := AudioCueMap.new()
	map.entries = [entry]
	_dispatcher.set_cue_map(map)

	for i in range(4):
		_dispatcher.voice_limiter.trigger_voice(&"progress_blip")
	_dispatcher.voice_limiter.trigger_voice(&"denial_rejection")

	_dispatcher.dispatch_cue(&"tower_attacked")

	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(0.60, 0.001)


func test_a_single_active_voice_receives_no_ducking() -> void:
	var entry := _fixture_entry(&"tower_attacked", &"SFX", &"combat_impact", false)
	entry.volume_db_offset = linear_to_db(0.8)
	var map := AudioCueMap.new()
	map.entries = [entry]
	_dispatcher.set_cue_map(map)

	_dispatcher.dispatch_cue(&"tower_attacked")

	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(0.8, 0.001)


func test_ducking_never_drops_below_the_duck_floor_through_real_dispatch() -> void:
	# Fill every other family to its own cap (1+4+3+4+6 = 18 pre-existing
	# voices, each within its family's own cap so none get stolen) --
	# comfortably past the ~15 voices needed to hit the duck floor, and
	# without relying on any single family absorbing an unrealistic count.
	var entry := _fixture_entry(&"tower_attacked", &"SFX", &"combat_impact", false)
	entry.volume_db_offset = linear_to_db(0.8)
	var map := AudioCueMap.new()
	map.entries = [entry]
	_dispatcher.set_cue_map(map)

	_dispatcher.voice_limiter.trigger_voice(&"discovery_fanfare")
	for i in range(4):
		_dispatcher.voice_limiter.trigger_voice(&"progress_blip")
	for i in range(3):
		_dispatcher.voice_limiter.trigger_voice(&"denial_rejection")
	for i in range(4):
		_dispatcher.voice_limiter.trigger_voice(&"activation_confirm")
	for i in range(6):
		_dispatcher.voice_limiter.trigger_voice(&"ui_confirm_cancel")

	_dispatcher.dispatch_cue(&"tower_attacked")

	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(0.8 * VoiceLimiter.DUCK_FLOOR, 0.001)


func test_a_cue_with_no_polyphony_group_is_never_ducked_regardless_of_other_active_voices() -> void:
	var entry := _fixture_entry(&"sanctuary_structure_built", &"SFX", &"", false)
	entry.volume_db_offset = linear_to_db(0.8)
	var map := AudioCueMap.new()
	map.entries = [entry]
	_dispatcher.set_cue_map(map)

	for i in range(5):
		_dispatcher.voice_limiter.trigger_voice(&"progress_blip")

	_dispatcher.dispatch_cue(&"sanctuary_structure_built")

	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(0.8, 0.001)


# ---------------------------------------------------------------------------
# Formula F3 wiring: real dispatch triggers the correct sidechain relationship
# based on the dispatched entry's bus. Envelope math itself is covered
# exhaustively by tests/unit/audio/sidechain-ducking-envelope_test.gd -- these
# only prove dispatch_cue() routes to the right relationship.
# ---------------------------------------------------------------------------

func test_sfx_bus_dispatch_triggers_the_sfx_to_ambient_sidechain_relationship() -> void:
	var entry := _fixture_entry(&"tower_attacked", &"SFX", &"combat_impact", false)
	var map := AudioCueMap.new()
	map.entries = [entry]
	_dispatcher.set_cue_map(map)

	_dispatcher.dispatch_cue(&"tower_attacked")

	assert_int(_dispatcher.voice_limiter.get_sidechain_state(VoiceLimiter.SFX_TO_AMBIENT)).is_equal(VoiceLimiter.SidechainState.ATTACKING)
	assert_int(_dispatcher.voice_limiter.get_sidechain_state(VoiceLimiter.UI_TO_MUSIC_AND_SFX)).is_equal(VoiceLimiter.SidechainState.RESTING)


func test_ui_bus_dispatch_triggers_the_ui_to_music_and_sfx_sidechain_relationship() -> void:
	var entry := _fixture_entry(&"component_crafted", &"UI", &"activation_confirm", false)
	var map := AudioCueMap.new()
	map.entries = [entry]
	_dispatcher.set_cue_map(map)

	_dispatcher.dispatch_cue(&"component_crafted")

	assert_int(_dispatcher.voice_limiter.get_sidechain_state(VoiceLimiter.UI_TO_MUSIC_AND_SFX)).is_equal(VoiceLimiter.SidechainState.ATTACKING)
	assert_int(_dispatcher.voice_limiter.get_sidechain_state(VoiceLimiter.SFX_TO_AMBIENT)).is_equal(VoiceLimiter.SidechainState.RESTING)


func test_dispatch_on_a_bus_other_than_sfx_or_ui_triggers_no_sidechain_relationship() -> void:
	var entry := _fixture_entry(&"mission_phase_changed", &"Music", &"", false)
	var map := AudioCueMap.new()
	map.entries = [entry]
	_dispatcher.set_cue_map(map)

	_dispatcher.dispatch_cue(&"mission_phase_changed")

	assert_int(_dispatcher.voice_limiter.get_sidechain_state(VoiceLimiter.SFX_TO_AMBIENT)).is_equal(VoiceLimiter.SidechainState.RESTING)
	assert_int(_dispatcher.voice_limiter.get_sidechain_state(VoiceLimiter.UI_TO_MUSIC_AND_SFX)).is_equal(VoiceLimiter.SidechainState.RESTING)


func test_dispatchers_own_process_actually_ticks_the_sidechain_envelope_over_a_real_frame() -> void:
	# Proves end-to-end wiring: _process() genuinely calls tick_sidechain()
	# every frame, not just that trigger_sidechain() was called synchronously
	# (already proven by the tests above). A real frame's delta is
	# non-deterministic, so this only asserts the offset moved off 0.0 --
	# exact envelope math is exhaustively covered by
	# sidechain-ducking-envelope_test.gd's deterministic delta-driven tests.
	var entry := _fixture_entry(&"tower_attacked", &"SFX", &"combat_impact", false)
	var map := AudioCueMap.new()
	map.entries = [entry]
	_dispatcher.set_cue_map(map)

	_dispatcher.dispatch_cue(&"tower_attacked")
	await get_tree().process_frame

	assert_float(_dispatcher.voice_limiter.get_sidechain_db_offset(VoiceLimiter.SFX_TO_AMBIENT)).is_less(0.0)
