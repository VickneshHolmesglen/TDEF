## Unit tests for Story 015 (TR-menag-001, breeding half; ADR-0026):
## same-species pairing (AC-23/AC-24), Formula 5 (AC-25/AC-26/AC-39),
## breeding-tick offspring production (AC-27), fixed pen capacity (AC-28),
## and offspring always RESERVE (AC-45).
##
## AC-43 (save/load round-trip mid-timer) is DEFERRED to Story 017
## (Persistence) — this story's pen/timer mechanics are exercised directly
## here; the actual SaveRestorer round-trip is that story's scope.
extends GdUnitTestSuite

var _menagerie: Menagerie


func before_test() -> void:
	_menagerie = Menagerie.new()


func after_test() -> void:
	if _menagerie != null and is_instance_valid(_menagerie):
		_menagerie.free()
	_menagerie = null


func _add_creature(species: StringName, state: CreatureInstance.CreatureState = CreatureInstance.CreatureState.HABITAT) -> CreatureInstance:
	var creature := CreatureInstance.new()
	creature.creature_id = _menagerie._next_creature_id
	_menagerie._next_creature_id += 1
	creature.species = species
	creature.state = state
	creature.happiness = 70.0
	_menagerie._creatures.append(creature)
	return creature


# ---------------------------------------------------------------------------
# AC-23/AC-24: same-species pairing succeeds; cross-species rejected
# outright, zero state change.
# ---------------------------------------------------------------------------

func test_same_species_pairing_succeeds_both_transition_to_breeding_pen() -> void:
	var a: CreatureInstance = _add_creature(&"glimmer_hare")
	var b: CreatureInstance = _add_creature(&"glimmer_hare")

	var result: bool = _menagerie.pair_for_breeding(a.creature_id, b.creature_id)

	assert_bool(result).is_true()
	assert_that(a.state).is_equal(CreatureInstance.CreatureState.BREEDING_PEN)
	assert_that(b.state).is_equal(CreatureInstance.CreatureState.BREEDING_PEN)
	assert_int(_menagerie._breeding_pens[0].breeding_missions_remaining).is_equal(2)  # Tier 1


func test_cross_species_pairing_rejected_zero_state_change() -> void:
	var a: CreatureInstance = _add_creature(&"glimmer_hare")
	var b: CreatureInstance = _add_creature(&"aurora_stag")

	var result: bool = _menagerie.pair_for_breeding(a.creature_id, b.creature_id)

	assert_bool(result).is_false()
	assert_that(a.state).is_equal(CreatureInstance.CreatureState.HABITAT)
	assert_that(b.state).is_equal(CreatureInstance.CreatureState.HABITAT)


## Regression test (code review, 2026-07-18): a creature cannot pair with
## itself. Prior to the fix, pairing a creature_id with itself trivially
## passed the species-equality check (same object), and the second
## move_to_breeding_pen() call's false return was silently ignored,
## producing a pen with occupant_ids = [id, id] that would breed
## indefinitely from a single creature at zero cost.
func test_self_pairing_rejected_zero_state_change() -> void:
	var a: CreatureInstance = _add_creature(&"glimmer_hare")

	var result: bool = _menagerie.pair_for_breeding(a.creature_id, a.creature_id)

	assert_bool(result).is_false()
	assert_that(a.state).is_equal(CreatureInstance.CreatureState.HABITAT)
	assert_that(_menagerie._breeding_pens[0].occupant_ids).is_empty()
	assert_that(_menagerie._breeding_pens[1].occupant_ids).is_empty()


# ---------------------------------------------------------------------------
# AC-25/AC-26/AC-39: Formula 5 — 2, 3, 4 for Tiers 1/2/3.
# ---------------------------------------------------------------------------

func test_breeding_duration_tier_1_is_2() -> void:
	assert_int(Menagerie.breeding_duration(1)).is_equal(2)


func test_breeding_duration_tier_2_is_3() -> void:
	assert_int(Menagerie.breeding_duration(2)).is_equal(3)


func test_breeding_duration_tier_3_is_4() -> void:
	assert_int(Menagerie.breeding_duration(3)).is_equal(4)


# ---------------------------------------------------------------------------
# AC-27: counter reaches 0 -> exactly 1 offspring in RESERVE, creature_bred
# fires once, both parents remain BREEDING_PEN unconsumed, countdown
# restarts automatically (Rule 11: "may be bred again").
# ---------------------------------------------------------------------------

func test_breeding_tick_at_one_remaining_produces_offspring_and_restarts() -> void:
	var a: CreatureInstance = _add_creature(&"glimmer_hare")
	var b: CreatureInstance = _add_creature(&"glimmer_hare")
	_menagerie.pair_for_breeding(a.creature_id, b.creature_id)
	_menagerie._breeding_pens[0].breeding_missions_remaining = 1

	var spy := EventBusSpy.new()
	spy.watch(GEventBus.creature_bred)

	_menagerie._tick_breeding_pens()

	assert_int(spy.count("creature_bred")).is_equal(1)
	assert_that(a.state).is_equal(CreatureInstance.CreatureState.BREEDING_PEN)  # unconsumed
	assert_that(b.state).is_equal(CreatureInstance.CreatureState.BREEDING_PEN)
	assert_int(_menagerie._breeding_pens[0].breeding_missions_remaining).is_equal(2)  # restarted, Tier 1

	var offspring_args: Array = (spy.emissions["creature_bred"] as Array)[0] as Array
	var offspring_id: int = offspring_args[0] as int
	var offspring: CreatureInstance = _menagerie.get_creature(offspring_id)
	assert_object(offspring).is_not_null()
	assert_that(offspring.state).is_equal(CreatureInstance.CreatureState.RESERVE)  # AC-45
	spy.disconnect_all()


# ---------------------------------------------------------------------------
# AC-28: both pens fully occupied (2 pairs, 4 creatures) -> a 5th pairing
# attempt is rejected, no partial/queued state.
# ---------------------------------------------------------------------------

func test_fifth_pairing_attempt_rejected_when_both_pens_full() -> void:
	var a1: CreatureInstance = _add_creature(&"glimmer_hare")
	var a2: CreatureInstance = _add_creature(&"glimmer_hare")
	_menagerie.pair_for_breeding(a1.creature_id, a2.creature_id)
	var b1: CreatureInstance = _add_creature(&"aurora_stag")
	var b2: CreatureInstance = _add_creature(&"aurora_stag")
	_menagerie.pair_for_breeding(b1.creature_id, b2.creature_id)

	var c1: CreatureInstance = _add_creature(&"mossback_toad")
	var c2: CreatureInstance = _add_creature(&"mossback_toad")
	var result: bool = _menagerie.pair_for_breeding(c1.creature_id, c2.creature_id)

	assert_bool(result).is_false()
	assert_that(c1.state).is_equal(CreatureInstance.CreatureState.HABITAT)
	assert_that(c2.state).is_equal(CreatureInstance.CreatureState.HABITAT)
