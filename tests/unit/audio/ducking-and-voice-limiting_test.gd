## Unit tests for Story 004 (epic-12-audio-system): Ducking and Voice
## Limiting -- AC Group 4 (Core Rule 5, Formula F1).
##
## VoiceLimiter is a pure RefCounted (no scene tree/EventBus dependency) --
## direct instantiation, matching this project's own Story 001 convention.
extends GdUnitTestSuite

var _limiter: VoiceLimiter


func before_test() -> void:
	_limiter = VoiceLimiter.new()


func after_test() -> void:
	_limiter = null


# ---------------------------------------------------------------------------
# AC-11: oldest-voice stealing beyond a family's cap.
# ---------------------------------------------------------------------------

func test_combat_impact_family_steals_oldest_voice_beyond_cap() -> void:
	var first_voice_id: int = -1
	for i in range(12):
		var voice_id: int = _limiter.trigger_voice(&"combat_impact")
		if i == 0:
			first_voice_id = voice_id

	assert_int(_limiter.get_active_voice_count(&"combat_impact")).is_equal(12)

	_limiter.trigger_voice(&"combat_impact")

	# The newest trigger always gets a voice -- count never exceeds the cap.
	assert_int(_limiter.get_active_voice_count(&"combat_impact")).is_equal(12)
	# The oldest-started voice (the very first one) was the one stolen.
	assert_int(_limiter.get_last_stolen_voice_id()).is_equal(first_voice_id)


func test_discovery_fanfare_cap_of_1_replaces_rather_than_ignores_new_trigger() -> void:
	var first_voice_id: int = _limiter.trigger_voice(&"discovery_fanfare")

	var second_voice_id: int = _limiter.trigger_voice(&"discovery_fanfare")

	assert_int(_limiter.get_active_voice_count(&"discovery_fanfare")).is_equal(1)
	assert_int(_limiter.get_last_stolen_voice_id()).is_equal(first_voice_id)
	assert_int(second_voice_id).is_not_equal(first_voice_id)


func test_trigger_below_cap_does_not_steal_anything() -> void:
	_limiter.trigger_voice(&"progress_blip")
	_limiter.trigger_voice(&"progress_blip")

	assert_int(_limiter.get_last_stolen_voice_id()).is_equal(-1)
	assert_int(_limiter.get_active_voice_count(&"progress_blip")).is_equal(2)


func test_default_family_caps_match_the_gdd_tuning_knobs() -> void:
	assert_int(_limiter.get_family_cap(&"discovery_fanfare")).is_equal(1)
	assert_int(_limiter.get_family_cap(&"progress_blip")).is_equal(4)
	assert_int(_limiter.get_family_cap(&"denial_rejection")).is_equal(3)
	assert_int(_limiter.get_family_cap(&"activation_confirm")).is_equal(4)
	assert_int(_limiter.get_family_cap(&"ui_confirm_cancel")).is_equal(6)
	assert_int(_limiter.get_family_cap(&"combat_impact")).is_equal(12)


func test_family_cap_can_be_overridden() -> void:
	_limiter.set_family_cap(&"progress_blip", 2)

	assert_int(_limiter.get_family_cap(&"progress_blip")).is_equal(2)


func test_release_voice_removes_it_from_the_active_family_count() -> void:
	var voice_id: int = _limiter.trigger_voice(&"ui_confirm_cancel")
	_limiter.trigger_voice(&"ui_confirm_cancel")

	_limiter.release_voice(&"ui_confirm_cancel", voice_id)

	assert_int(_limiter.get_active_voice_count(&"ui_confirm_cancel")).is_equal(1)


# ---------------------------------------------------------------------------
# AC-12: Formula F1, bus-wide concurrent-cue ducking.
# ---------------------------------------------------------------------------

func test_formula_f1_matches_the_gdds_worked_example() -> void:
	# V_base=0.8, N=6, k=0.05, D_floor=0.3 -> 0.8 * max(0.3, 1-0.05*5) = 0.60
	var result: float = VoiceLimiter.compute_ducked_volume(0.8, 6)

	assert_float(result).is_equal_approx(0.60, 0.001)


func test_formula_f1_with_a_single_voice_applies_no_ducking() -> void:
	var result: float = VoiceLimiter.compute_ducked_volume(0.8, 1)

	assert_float(result).is_equal_approx(0.8, 0.001)


func test_formula_f1_never_goes_below_the_duck_floor() -> void:
	# A very high voice count would drive the raw factor deeply negative
	# without the floor clamp -- confirm the floor is respected exactly.
	var result: float = VoiceLimiter.compute_ducked_volume(0.8, 100)

	assert_float(result).is_equal_approx(0.8 * VoiceLimiter.DUCK_FLOOR, 0.001)


# ---------------------------------------------------------------------------
# Sidechain ducking constants (Core Rule 5) -- a separate, cross-bus
# mechanism from Formula F1.
# ---------------------------------------------------------------------------

func test_sfx_to_ambient_sidechain_duck_matches_gdd_value() -> void:
	assert_float(VoiceLimiter.SFX_TO_AMBIENT_DUCK_DB).is_equal_approx(-6.0, 0.001)


func test_ui_to_music_and_sfx_sidechain_duck_matches_gdd_value() -> void:
	assert_float(VoiceLimiter.UI_TO_MUSIC_AND_SFX_DUCK_DB).is_equal_approx(-4.0, 0.001)
