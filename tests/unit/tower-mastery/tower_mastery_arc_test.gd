## Unit tests for Story 013's TowerMasteryArc (pure view component): progress
## clamping, state transitions, the destroyed-fade completion signal, and
## the auto-clearing unlock pulse.
##
## TowerMasteryArc is instantiated directly (no add_child()) so its own
## _process() never runs automatically — tests drive time forward by
## calling _process(delta) manually, matching this project's established
## convention for testing time-driven behavior without a live scene tree.
extends GdUnitTestSuite

var _arc: TowerMasteryArc


func before_test() -> void:
	_arc = TowerMasteryArc.new()


func after_test() -> void:
	if _arc != null and is_instance_valid(_arc):
		_arc.free()
	_arc = null


func test_set_progress_clamps_to_0_100_range() -> void:
	_arc.set_progress(150.0)
	assert_float(_arc.progress_percent).is_equal_approx(100.0, 0.0001)

	_arc.set_progress(-10.0)
	assert_float(_arc.progress_percent).is_equal_approx(0.0, 0.0001)

	_arc.set_progress(42.0)
	assert_float(_arc.progress_percent).is_equal_approx(42.0, 0.0001)


func test_default_state_is_accruing() -> void:
	assert_int(_arc.state).is_equal(TowerMasteryArc.State.ACCRUING)


func test_set_state_paused_out_of_range() -> void:
	_arc.set_state(TowerMasteryArc.State.PAUSED_OUT_OF_RANGE)
	assert_int(_arc.state).is_equal(TowerMasteryArc.State.PAUSED_OUT_OF_RANGE)


# ---------------------------------------------------------------------------
# Destroyed-fade: resets on entry, progresses over time, completes at
# DESTROYED_FADE_SECONDS, never overshoots.
# ---------------------------------------------------------------------------

func test_destroyed_fade_is_not_complete_immediately_on_entry() -> void:
	_arc.set_state(TowerMasteryArc.State.PAUSED_DESTROYED)
	assert_bool(_arc.is_fade_complete()).is_false()


func test_destroyed_fade_completes_after_its_full_duration() -> void:
	_arc.set_state(TowerMasteryArc.State.PAUSED_DESTROYED)
	_arc._process(TowerMasteryArc.DESTROYED_FADE_SECONDS)
	assert_bool(_arc.is_fade_complete()).is_true()


func test_destroyed_fade_not_complete_partway_through() -> void:
	_arc.set_state(TowerMasteryArc.State.PAUSED_DESTROYED)
	_arc._process(TowerMasteryArc.DESTROYED_FADE_SECONDS * 0.5)
	assert_bool(_arc.is_fade_complete()).is_false()


func test_re_entering_destroyed_state_resets_fade_progress() -> void:
	_arc.set_state(TowerMasteryArc.State.PAUSED_DESTROYED)
	_arc._process(TowerMasteryArc.DESTROYED_FADE_SECONDS)
	assert_bool(_arc.is_fade_complete()).is_true()

	_arc.set_state(TowerMasteryArc.State.PAUSED_DESTROYED)  # a fresh destroy event
	assert_bool(_arc.is_fade_complete()).is_false()


# ---------------------------------------------------------------------------
# Unlock pulse: plays for its full duration, then auto-clears back to
# ACCRUING (GDD: "pulses once... then clears").
# ---------------------------------------------------------------------------

func test_unlock_pulse_stays_in_pulse_state_partway_through() -> void:
	_arc.set_state(TowerMasteryArc.State.UNLOCKED_PULSE)
	_arc._process(TowerMasteryArc.PULSE_DURATION_SECONDS * 0.5)
	assert_int(_arc.state).is_equal(TowerMasteryArc.State.UNLOCKED_PULSE)


func test_unlock_pulse_auto_clears_to_accruing_after_full_duration() -> void:
	_arc.set_state(TowerMasteryArc.State.UNLOCKED_PULSE)
	_arc._process(TowerMasteryArc.PULSE_DURATION_SECONDS)
	assert_int(_arc.state).is_equal(TowerMasteryArc.State.ACCRUING)
