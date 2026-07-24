## Unit tests for Story 011 (TR-menag-002, highest-risk rule; ADR-0026):
## the single-call-site aggregate recompute-and-push, and the HABITAT/
## BREEDING_PEN move actions that trigger (or deliberately don't trigger) it.
extends GdUnitTestSuite

var _menagerie: Menagerie
var _spy: EventBusSpy


func before_test() -> void:
	_menagerie = Menagerie.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.creature_happiness_changed)
	_spy.watch(GEventBus.creature_moved_to_breeding_pen)
	_spy.watch(GEventBus.creature_returned_from_breeding_pen)
	_spy.watch(GEventBus.creature_sacrificed)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _menagerie != null and is_instance_valid(_menagerie):
		_menagerie.free()
	_menagerie = null


func _add_creature(state: CreatureInstance.CreatureState, happiness: float = 70.0) -> CreatureInstance:
	var creature := CreatureInstance.new()
	creature.creature_id = _menagerie._next_creature_id
	_menagerie._next_creature_id += 1
	creature.state = state
	creature.happiness = happiness
	_menagerie._creatures.append(creature)
	return creature


# ---------------------------------------------------------------------------
# AC-10: RESERVE -> HABITAT triggers immediate recompute + push.
# ---------------------------------------------------------------------------

func test_move_to_habitat_triggers_aggregate_recompute() -> void:
	var creature: CreatureInstance = _add_creature(CreatureInstance.CreatureState.RESERVE, 80.0)
	var result: bool = _menagerie.move_to_habitat(creature.creature_id)

	assert_bool(result).is_true()
	assert_that(creature.state).is_equal(CreatureInstance.CreatureState.HABITAT)
	assert_int(_spy.count("creature_happiness_changed")).is_equal(1)
	var args: Array = (_spy.emissions["creature_happiness_changed"] as Array)[0] as Array
	assert_int(args[0] as int).is_equal(creature.creature_id)
	assert_float(args[2] as float).is_equal_approx(1.40, 0.001)


# ---------------------------------------------------------------------------
# AC-11: HABITAT -> BREEDING_PEN recomputes excluding the departed creature.
# ---------------------------------------------------------------------------

func test_move_to_breeding_pen_recomputes_excluding_departed_creature() -> void:
	var stays: CreatureInstance = _add_creature(CreatureInstance.CreatureState.HABITAT, 80.0)
	var leaves: CreatureInstance = _add_creature(CreatureInstance.CreatureState.HABITAT, 20.0)

	var result: bool = _menagerie.move_to_breeding_pen(leaves.creature_id)

	assert_bool(result).is_true()
	assert_that(leaves.state).is_equal(CreatureInstance.CreatureState.BREEDING_PEN)
	assert_bool(_spy.was_emitted("creature_moved_to_breeding_pen")).is_true()
	assert_int(_spy.count("creature_happiness_changed")).is_equal(1)
	# Only `stays` (80.0) remains in HABITAT — bonus reflects that alone.
	var args: Array = (_spy.emissions["creature_happiness_changed"] as Array)[0] as Array
	assert_float(args[2] as float).is_equal_approx(1.40, 0.001)
	assert_int(args[0] as int).is_equal(stays.creature_id)


# ---------------------------------------------------------------------------
# AC-12: BREEDING_PEN -> RESERVE fires the return notification only — no
# aggregate recompute, no creature_happiness_changed.
# ---------------------------------------------------------------------------

func test_return_from_breeding_pen_to_reserve_no_aggregate_recompute() -> void:
	var creature: CreatureInstance = _add_creature(CreatureInstance.CreatureState.BREEDING_PEN, 80.0)
	var result: bool = _menagerie.return_from_breeding_pen_to_reserve(creature.creature_id)

	assert_bool(result).is_true()
	assert_that(creature.state).is_equal(CreatureInstance.CreatureState.RESERVE)
	assert_bool(_spy.was_emitted("creature_returned_from_breeding_pen")).is_true()
	assert_bool(_spy.was_emitted("creature_happiness_changed")).is_false()


# ---------------------------------------------------------------------------
# AC-13/AC-14: sacrifice-triggered recompute (or skip, if HABITAT emptied).
# ---------------------------------------------------------------------------

func test_sacrifice_with_remaining_habitat_creature_recomputes_for_it() -> void:
	var remaining: CreatureInstance = _add_creature(CreatureInstance.CreatureState.HABITAT, 80.0)
	var sacrificed: CreatureInstance = _add_creature(CreatureInstance.CreatureState.HABITAT, 20.0)

	var result: bool = _menagerie.request_sacrifice(sacrificed.creature_id, 999)

	assert_bool(result).is_true()
	assert_bool(_spy.was_emitted("creature_sacrificed")).is_true()
	assert_int(_spy.count("creature_happiness_changed")).is_equal(1)
	var args: Array = (_spy.emissions["creature_happiness_changed"] as Array)[0] as Array
	assert_int(args[0] as int).is_equal(remaining.creature_id)


func test_sacrifice_of_last_habitat_creature_skips_recompute_this_frame() -> void:
	var only: CreatureInstance = _add_creature(CreatureInstance.CreatureState.HABITAT, 80.0)

	var result: bool = _menagerie.request_sacrifice(only.creature_id, 999)

	assert_bool(result).is_true()
	assert_bool(_spy.was_emitted("creature_sacrificed")).is_true()
	assert_bool(_spy.was_emitted("creature_happiness_changed")).is_false()  # skip clause
	# Next natural event correctly reports the floor value (1.0, empty HABITAT).
	assert_float(_menagerie.compute_quality_bonus()).is_equal(1.0)


# ---------------------------------------------------------------------------
# AC-15: two back-to-back HABITAT-composition changes each get their own
# independent recompute, no stale read.
# ---------------------------------------------------------------------------

func test_two_back_to_back_transitions_each_recompute_independently() -> void:
	var first: CreatureInstance = _add_creature(CreatureInstance.CreatureState.RESERVE, 20.0)
	var second: CreatureInstance = _add_creature(CreatureInstance.CreatureState.RESERVE, 100.0)

	_menagerie.move_to_habitat(first.creature_id)
	var first_bonus: float = (_spy.emissions["creature_happiness_changed"] as Array)[0][2] as float
	assert_float(first_bonus).is_equal_approx(1.10, 0.001)  # only `first` (20.0) in HABITAT

	_menagerie.move_to_habitat(second.creature_id)
	assert_int(_spy.count("creature_happiness_changed")).is_equal(2)
	var second_bonus: float = (_spy.emissions["creature_happiness_changed"] as Array)[1][2] as float
	assert_float(second_bonus).is_equal_approx(1.30, 0.001)  # avg(20,100)=60 -> 1.0+0.5*0.6=1.30


# ---------------------------------------------------------------------------
# AC-41: HABITAT -> BREEDING_PEN -> HABITAT round-trip, clean recompute
# each time, creature's own happiness unaffected by the toggle.
# ---------------------------------------------------------------------------

func test_round_trip_habitat_to_breeding_pen_and_back_recomputes_cleanly() -> void:
	var creature: CreatureInstance = _add_creature(CreatureInstance.CreatureState.HABITAT, 80.0)
	var original_happiness: float = creature.happiness

	_menagerie.move_to_breeding_pen(creature.creature_id)
	assert_float(_menagerie.compute_quality_bonus()).is_equal(1.0)  # HABITAT now empty

	_menagerie.return_from_breeding_pen_to_reserve(creature.creature_id)
	_menagerie.move_to_habitat(creature.creature_id)

	assert_that(creature.state).is_equal(CreatureInstance.CreatureState.HABITAT)
	assert_float(creature.happiness).is_equal(original_happiness)  # unaffected by the toggle
	assert_float(_menagerie.compute_quality_bonus()).is_equal_approx(1.40, 0.001)
