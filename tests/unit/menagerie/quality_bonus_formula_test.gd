## Unit tests for Story 010 (TR-menag-002, aggregate formula half; ADR-0026):
## Formula 3 — menagerie_quality_bonus, HABITAT-only, floor/ceiling clamped.
extends GdUnitTestSuite

var _menagerie: Menagerie


func before_test() -> void:
	_menagerie = Menagerie.new()


func after_test() -> void:
	if _menagerie != null and is_instance_valid(_menagerie):
		_menagerie.free()
	_menagerie = null


func _add_creature(state: CreatureInstance.CreatureState, happiness: float) -> CreatureInstance:
	var creature := CreatureInstance.new()
	creature.creature_id = _menagerie._next_creature_id
	_menagerie._next_creature_id += 1
	creature.state = state
	creature.happiness = happiness
	_menagerie._creatures.append(creature)
	return creature


# ---------------------------------------------------------------------------
# AC-8/AC-9: only HABITAT-state creatures count.
# ---------------------------------------------------------------------------

func test_reserve_creature_happiness_has_no_effect() -> void:
	_add_creature(CreatureInstance.CreatureState.HABITAT, 80.0)
	_add_creature(CreatureInstance.CreatureState.RESERVE, 80.0)
	assert_float(_menagerie.compute_quality_bonus()).is_equal_approx(1.40, 0.001)


func test_breeding_pen_creature_fully_excluded() -> void:
	_add_creature(CreatureInstance.CreatureState.HABITAT, 80.0)
	_add_creature(CreatureInstance.CreatureState.BREEDING_PEN, 80.0)
	assert_float(_menagerie.compute_quality_bonus()).is_equal_approx(1.40, 0.001)


# ---------------------------------------------------------------------------
# AC-33: zero HABITAT creatures -> exactly 1.0, no divide-by-zero.
# ---------------------------------------------------------------------------

func test_zero_habitat_creatures_returns_exactly_one() -> void:
	assert_float(_menagerie.compute_quality_bonus()).is_equal(1.0)


func test_zero_habitat_creatures_with_other_states_present_still_returns_one() -> void:
	_add_creature(CreatureInstance.CreatureState.RESERVE, 90.0)
	_add_creature(CreatureInstance.CreatureState.BREEDING_PEN, 90.0)
	assert_float(_menagerie.compute_quality_bonus()).is_equal(1.0)


# ---------------------------------------------------------------------------
# AC-34: 3 HABITAT creatures (82, 70, 55) -> H_avg=69.0 -> 1.345.
# ---------------------------------------------------------------------------

func test_three_habitat_creatures_average_computed_correctly() -> void:
	_add_creature(CreatureInstance.CreatureState.HABITAT, 82.0)
	_add_creature(CreatureInstance.CreatureState.HABITAT, 70.0)
	_add_creature(CreatureInstance.CreatureState.HABITAT, 55.0)
	assert_float(_menagerie.compute_quality_bonus()).is_equal_approx(1.345, 0.001)


# ---------------------------------------------------------------------------
# AC-35: single HABITAT creature at happiness floor (20) -> 1.10.
# ---------------------------------------------------------------------------

func test_single_habitat_creature_at_happiness_floor() -> void:
	_add_creature(CreatureInstance.CreatureState.HABITAT, 20.0)
	assert_float(_menagerie.compute_quality_bonus()).is_equal_approx(1.10, 0.001)


# ---------------------------------------------------------------------------
# AC-36: clamp to [1.0, 1.5] under any drift.
# ---------------------------------------------------------------------------

func test_result_clamped_to_ceiling_1_5() -> void:
	# Happiness alone (max 100) can only reach 1.5 exactly at H_avg=100 — a
	# direct test of the clamp's ceiling boundary holding, not exceeding it.
	_add_creature(CreatureInstance.CreatureState.HABITAT, 100.0)
	assert_float(_menagerie.compute_quality_bonus()).is_equal_approx(1.5, 0.001)


func test_result_never_below_floor_1_0() -> void:
	_add_creature(CreatureInstance.CreatureState.HABITAT, 0.0)  # below the real 20 floor, still must not go under 1.0
	assert_float(_menagerie.compute_quality_bonus()).is_greater_equal(1.0)
