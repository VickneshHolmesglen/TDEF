## Unit tests for Formula F3 (design/quick-specs/sidechain-ducking-timing-2026-07-31.md):
## sidechain ducking attack/hold/release envelope, wired into VoiceLimiter.
##
## Deterministic, delta-driven -- ticks are passed explicitly rather than
## reading wall-clock time, matching this project's own "use delta time for
## all time-dependent calculations" rule and keeping these tests exact rather
## than timing-flaky.
extends GdUnitTestSuite

var _limiter: VoiceLimiter


func before_test() -> void:
	_limiter = VoiceLimiter.new()


func after_test() -> void:
	_limiter = null


# ---------------------------------------------------------------------------
# Attack phase
# ---------------------------------------------------------------------------

func test_first_trigger_from_resting_starts_attacking() -> void:
	_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)

	assert_int(_limiter.get_sidechain_state(VoiceLimiter.SFX_TO_AMBIENT)).is_equal(VoiceLimiter.SidechainState.ATTACKING)
	assert_float(_limiter.get_sidechain_db_offset(VoiceLimiter.SFX_TO_AMBIENT)).is_equal_approx(0.0, 0.0001)


func test_attack_ramps_linearly_to_full_duck_over_attack_time() -> void:
	# SFX_TO_AMBIENT defaults: duck_db=-6.0, attack_time=0.015s.
	_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)

	_limiter.tick_sidechain(0.0075)  # halfway through attack

	assert_float(_limiter.get_sidechain_db_offset(VoiceLimiter.SFX_TO_AMBIENT)).is_equal_approx(-3.0, 0.01)
	assert_int(_limiter.get_sidechain_state(VoiceLimiter.SFX_TO_AMBIENT)).is_equal(VoiceLimiter.SidechainState.ATTACKING)


func test_attack_completes_and_transitions_to_held() -> void:
	_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)

	_limiter.tick_sidechain(0.015)  # exactly the full attack time

	assert_float(_limiter.get_sidechain_db_offset(VoiceLimiter.SFX_TO_AMBIENT)).is_equal_approx(-6.0, 0.0001)
	assert_int(_limiter.get_sidechain_state(VoiceLimiter.SFX_TO_AMBIENT)).is_equal(VoiceLimiter.SidechainState.HELD)


# ---------------------------------------------------------------------------
# Hold / retrigger (the anti-"pumping" rule)
# ---------------------------------------------------------------------------

func test_retrigger_while_held_resets_hold_timer_without_reattacking() -> void:
	_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)
	_limiter.tick_sidechain(0.015)  # now HELD, release_delay=0.15 counting down

	_limiter.tick_sidechain(0.1)  # 0.05s left on the original hold window
	_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)  # resets hold timer to 0.15
	_limiter.tick_sidechain(0.1)  # would have released under the ORIGINAL timer, but not the reset one

	assert_int(_limiter.get_sidechain_state(VoiceLimiter.SFX_TO_AMBIENT)).is_equal(VoiceLimiter.SidechainState.HELD)
	assert_float(_limiter.get_sidechain_db_offset(VoiceLimiter.SFX_TO_AMBIENT)).is_equal_approx(-6.0, 0.0001)


func test_retrigger_mid_attack_does_not_restart_the_ramp() -> void:
	_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)
	_limiter.tick_sidechain(0.0075)  # halfway through attack, offset == -3.0

	_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)  # retrigger mid-attack

	# Still ATTACKING from where it was -- not reset back to a fresh 0.0 start.
	assert_int(_limiter.get_sidechain_state(VoiceLimiter.SFX_TO_AMBIENT)).is_equal(VoiceLimiter.SidechainState.ATTACKING)
	assert_float(_limiter.get_sidechain_db_offset(VoiceLimiter.SFX_TO_AMBIENT)).is_equal_approx(-3.0, 0.01)


# ---------------------------------------------------------------------------
# Release phase
# ---------------------------------------------------------------------------

func test_release_begins_after_hold_delay_expires_with_no_new_trigger() -> void:
	_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)
	_limiter.tick_sidechain(0.015)  # HELD

	_limiter.tick_sidechain(0.15)  # exactly the release_delay, no retrigger

	assert_int(_limiter.get_sidechain_state(VoiceLimiter.SFX_TO_AMBIENT)).is_equal(VoiceLimiter.SidechainState.RELEASING)


func test_release_ramps_linearly_back_to_zero_and_rests() -> void:
	_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)
	_limiter.tick_sidechain(0.015)  # HELD
	_limiter.tick_sidechain(0.15)  # RELEASING begins

	_limiter.tick_sidechain(0.125)  # halfway through release_time (0.25)
	assert_float(_limiter.get_sidechain_db_offset(VoiceLimiter.SFX_TO_AMBIENT)).is_equal_approx(-3.0, 0.01)
	assert_int(_limiter.get_sidechain_state(VoiceLimiter.SFX_TO_AMBIENT)).is_equal(VoiceLimiter.SidechainState.RELEASING)

	_limiter.tick_sidechain(0.125)  # remainder of release_time
	assert_float(_limiter.get_sidechain_db_offset(VoiceLimiter.SFX_TO_AMBIENT)).is_equal_approx(0.0, 0.0001)
	assert_int(_limiter.get_sidechain_state(VoiceLimiter.SFX_TO_AMBIENT)).is_equal(VoiceLimiter.SidechainState.RESTING)


func test_trigger_mid_release_reenters_held_from_current_partial_value_not_full_duck() -> void:
	_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)
	_limiter.tick_sidechain(0.015)  # HELD
	_limiter.tick_sidechain(0.15)  # RELEASING begins
	_limiter.tick_sidechain(0.125)  # halfway through release -- offset == -3.0

	_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)

	assert_int(_limiter.get_sidechain_state(VoiceLimiter.SFX_TO_AMBIENT)).is_equal(VoiceLimiter.SidechainState.HELD)
	# Must NOT snap back to the full -6.0 duck amount -- stays at the partial value.
	assert_float(_limiter.get_sidechain_db_offset(VoiceLimiter.SFX_TO_AMBIENT)).is_equal_approx(-3.0, 0.01)


# ---------------------------------------------------------------------------
# The 2 relationships run independently
# ---------------------------------------------------------------------------

func test_the_two_relationships_are_fully_independent() -> void:
	_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)
	_limiter.tick_sidechain(0.015)  # SFX_TO_AMBIENT now HELD at -6.0

	# UI_TO_MUSIC_AND_SFX was never triggered -- must still be at rest.
	assert_int(_limiter.get_sidechain_state(VoiceLimiter.UI_TO_MUSIC_AND_SFX)).is_equal(VoiceLimiter.SidechainState.RESTING)
	assert_float(_limiter.get_sidechain_db_offset(VoiceLimiter.UI_TO_MUSIC_AND_SFX)).is_equal_approx(0.0, 0.0001)


func test_ui_relationship_uses_its_own_faster_defaults() -> void:
	# UI_TO_MUSIC_AND_SFX defaults: duck_db=-4.0, attack_time=0.01s.
	_limiter.trigger_sidechain(VoiceLimiter.UI_TO_MUSIC_AND_SFX)
	_limiter.tick_sidechain(0.01)

	assert_float(_limiter.get_sidechain_db_offset(VoiceLimiter.UI_TO_MUSIC_AND_SFX)).is_equal_approx(-4.0, 0.0001)
	assert_int(_limiter.get_sidechain_state(VoiceLimiter.UI_TO_MUSIC_AND_SFX)).is_equal(VoiceLimiter.SidechainState.HELD)


# ---------------------------------------------------------------------------
# Pause-freeze (Core Rule 7): simply not calling tick_sidechain() must leave
# state exactly where it was -- no bespoke pause-handling exists or should
# exist inside VoiceLimiter itself; AudioCueDispatcher's _process() simply
# stops firing while get_tree().paused is true.
# ---------------------------------------------------------------------------

func test_not_ticking_leaves_state_exactly_frozen() -> void:
	_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)
	_limiter.tick_sidechain(0.0075)
	var frozen_offset: float = _limiter.get_sidechain_db_offset(VoiceLimiter.SFX_TO_AMBIENT)
	var frozen_state: VoiceLimiter.SidechainState = _limiter.get_sidechain_state(VoiceLimiter.SFX_TO_AMBIENT)

	# No tick_sidechain() call here -- simulating a paused frame being skipped.

	assert_float(_limiter.get_sidechain_db_offset(VoiceLimiter.SFX_TO_AMBIENT)).is_equal_approx(frozen_offset, 0.0001)
	assert_int(_limiter.get_sidechain_state(VoiceLimiter.SFX_TO_AMBIENT)).is_equal(frozen_state)
