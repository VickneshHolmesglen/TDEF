## Unit tests for Story 014 (TR-menag-002, tend half; ADR-0026): Formula 2 —
## the Tend action, no cooldown, HABITAT-only.
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
	creature.missions_since_tended = 3
	_menagerie._creatures.append(creature)
	return creature


# ---------------------------------------------------------------------------
# AC-20: 54+20=74, resets missions_since_tended to 0.
# ---------------------------------------------------------------------------

func test_tend_boosts_happiness_and_resets_counter() -> void:
	var creature: CreatureInstance = _add_creature(CreatureInstance.CreatureState.HABITAT, 54.0)
	var result: bool = _menagerie.tend_creature(creature.creature_id)

	assert_bool(result).is_true()
	assert_float(creature.happiness).is_equal(74.0)
	assert_int(creature.missions_since_tended).is_equal(0)


# ---------------------------------------------------------------------------
# AC-21: 90+20=110 clamps to exactly 100.
# ---------------------------------------------------------------------------

func test_tend_clamps_at_100_not_110() -> void:
	var creature: CreatureInstance = _add_creature(CreatureInstance.CreatureState.HABITAT, 90.0)
	_menagerie.tend_creature(creature.creature_id)
	assert_float(creature.happiness).is_equal(100.0)


func test_tend_at_exactly_100_still_resets_counter() -> void:
	var creature: CreatureInstance = _add_creature(CreatureInstance.CreatureState.HABITAT, 100.0)
	_menagerie.tend_creature(creature.creature_id)
	assert_float(creature.happiness).is_equal(100.0)
	assert_int(creature.missions_since_tended).is_equal(0)


# ---------------------------------------------------------------------------
# AC-22: repeat Tend, same session, no cooldown — 5 rapid Tends all succeed.
# ---------------------------------------------------------------------------

func test_repeated_tend_no_cooldown_all_succeed() -> void:
	var creature: CreatureInstance = _add_creature(CreatureInstance.CreatureState.HABITAT, 20.0)
	for i: int in range(5):
		var result: bool = _menagerie.tend_creature(creature.creature_id)
		assert_bool(result).is_true()
	assert_float(creature.happiness).is_equal(100.0)  # 20+20*4=100, clamps by the 4th


func test_tend_rejected_for_reserve_creature() -> void:
	var creature: CreatureInstance = _add_creature(CreatureInstance.CreatureState.RESERVE, 54.0)
	var result: bool = _menagerie.tend_creature(creature.creature_id)
	assert_bool(result).is_false()
	assert_float(creature.happiness).is_equal(54.0)
