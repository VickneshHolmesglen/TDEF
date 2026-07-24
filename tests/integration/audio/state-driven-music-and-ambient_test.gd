## Integration tests for Story 002 (epic-12-audio-system): State-Driven
## Music and Ambient -- AC Group 2 (Core Rule 2, States and Transitions).
##
## Uses real scene instantiation (`add_child()`, matching this project's own
## "Integration story" convention -- e.g. `diorama_test.gd`) so
## `MusicAmbientController._ready()` actually connects to the real
## `GEventBus`. Crossfade/duck timing is exercised via the real `Tween`
## mechanism and forced to completion with `force_finish_transition()`
## (a test seam) rather than real waits, per this project's own
## "no time-dependent assertions" test standard.
extends GdUnitTestSuite

var _controller: MusicAmbientController


func before_test() -> void:
	_controller = MusicAmbientController.new()
	add_child(_controller)


func after_test() -> void:
	if _controller != null and is_instance_valid(_controller):
		_controller.free()
	_controller = null


# ---------------------------------------------------------------------------
# AC-3: SCOUT -> WAVE_ACTIVE anticipatory crossfade, scheduled to finish
# exactly when the countdown reaches 0.
# ---------------------------------------------------------------------------

func test_countdown_warning_during_measured_state_begins_a_crossfade_to_urgent() -> void:
	GEventBus.mission_phase_changed.emit("SANCTUARY", "SCOUT", 0.0)
	assert_that(_controller.get_music_state()).is_equal(MusicAmbientController.MusicState.MEASURED)

	GEventBus.wave_countdown_warning.emit(10)

	assert_bool(_controller.is_transitioning()).is_true()
	assert_float(_controller.get_last_transition_duration()).is_equal_approx(10.0, 0.001)
	assert_bool(_controller.get_last_transition_was_hard_cut()).is_false()


func test_countdown_warning_with_short_remaining_time_still_schedules_matching_duration() -> void:
	GEventBus.mission_phase_changed.emit("SANCTUARY", "SCOUT", 0.0)

	GEventBus.wave_countdown_warning.emit(2)

	assert_float(_controller.get_last_transition_duration()).is_equal_approx(2.0, 0.001)


func test_countdown_warning_outside_measured_state_is_ignored() -> void:
	# Fresh controller defaults to CONTEMPLATIVE, not MEASURED.
	GEventBus.wave_countdown_warning.emit(10)

	assert_bool(_controller.is_transitioning()).is_false()


# ---------------------------------------------------------------------------
# AC-4: WAVE_ACTIVE -> INTERMISSION is a fast duck/cut (0.2-0.5s), never a
# multi-second crossfade.
# ---------------------------------------------------------------------------

func test_wave_clear_to_intermission_is_a_hard_cut_within_tuning_bounds() -> void:
	GEventBus.mission_phase_changed.emit("SANCTUARY", "SCOUT", 0.0)
	GEventBus.mission_phase_changed.emit("SCOUT", "WAVE_ACTIVE", 0.0)
	_controller.force_finish_transition()
	assert_that(_controller.get_music_state()).is_equal(MusicAmbientController.MusicState.URGENT)

	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "INTERMISSION", 0.0)

	assert_bool(_controller.get_last_transition_was_hard_cut()).is_true()
	assert_float(_controller.get_last_transition_duration()).is_between(0.2, 0.5)


func test_wave_clear_hard_cut_is_not_a_multi_second_crossfade() -> void:
	GEventBus.mission_phase_changed.emit("SANCTUARY", "SCOUT", 0.0)
	GEventBus.mission_phase_changed.emit("SCOUT", "WAVE_ACTIVE", 0.0)
	_controller.force_finish_transition()

	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "INTERMISSION", 0.0)

	assert_float(_controller.get_last_transition_duration()).is_less(1.0)


# ---------------------------------------------------------------------------
# AC-5: identical previous/new phase never retriggers.
# ---------------------------------------------------------------------------

func test_identical_phase_transition_does_not_retrigger_in_measured_state() -> void:
	GEventBus.mission_phase_changed.emit("SANCTUARY", "SCOUT", 0.0)
	_controller.force_finish_transition()
	var epoch_before: int = _controller.get_stem_epoch()

	GEventBus.mission_phase_changed.emit("SCOUT", "SCOUT", 0.0)

	assert_int(_controller.get_stem_epoch()).is_equal(epoch_before)
	assert_bool(_controller.is_transitioning()).is_false()


func test_identical_phase_transition_does_not_retrigger_in_urgent_state() -> void:
	GEventBus.mission_phase_changed.emit("SANCTUARY", "SCOUT", 0.0)
	GEventBus.mission_phase_changed.emit("SCOUT", "WAVE_ACTIVE", 0.0)
	_controller.force_finish_transition()
	var epoch_before: int = _controller.get_stem_epoch()

	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "WAVE_ACTIVE", 0.0)

	assert_int(_controller.get_stem_epoch()).is_equal(epoch_before)
	assert_bool(_controller.is_transitioning()).is_false()


# ---------------------------------------------------------------------------
# AC-6: the Ambient base bed is never interrupted/restarted; only layers
# change.
# ---------------------------------------------------------------------------

func test_ambient_base_bed_is_never_restarted_across_any_transition() -> void:
	GEventBus.mission_phase_changed.emit("SANCTUARY", "SCOUT", 0.0)
	GEventBus.mission_phase_changed.emit("SCOUT", "WAVE_ACTIVE", 0.0)
	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "INTERMISSION", 0.0)
	GEventBus.mission_phase_changed.emit("INTERMISSION", "WAVE_ACTIVE", 0.0)

	assert_int(_controller.get_ambient_base_bed_start_count()).is_equal(1)


func test_next_wave_during_combat_layer_fade_out_reactivates_it_without_touching_base_bed() -> void:
	GEventBus.mission_phase_changed.emit("SANCTUARY", "SCOUT", 0.0)
	GEventBus.mission_phase_changed.emit("SCOUT", "WAVE_ACTIVE", 0.0)
	assert_bool(_controller.is_ambient_combat_layer_active()).is_true()

	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "INTERMISSION", 0.0)
	assert_bool(_controller.is_ambient_combat_layer_fading_out()).is_true()

	# Next wave begins mid-fade -- combat layer reactivates, base bed untouched.
	GEventBus.mission_phase_changed.emit("INTERMISSION", "WAVE_ACTIVE", 0.0)

	assert_bool(_controller.is_ambient_combat_layer_active()).is_true()
	assert_bool(_controller.is_ambient_combat_layer_fading_out()).is_false()
	assert_int(_controller.get_ambient_base_bed_start_count()).is_equal(1)


func test_intermission_after_full_settle_still_leaves_base_bed_untouched() -> void:
	GEventBus.mission_phase_changed.emit("SANCTUARY", "SCOUT", 0.0)
	GEventBus.mission_phase_changed.emit("SCOUT", "WAVE_ACTIVE", 0.0)
	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "INTERMISSION", 0.0)
	_controller.force_finish_transition()

	assert_int(_controller.get_ambient_base_bed_start_count()).is_equal(1)
