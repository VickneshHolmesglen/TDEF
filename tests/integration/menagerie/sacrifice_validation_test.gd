## Integration tests for Story 016 (TR-menag-001, sacrifice half; ADR-0026):
## request_sacrifice()'s validation (rejects BREEDING_PEN, AC-30), success
## path from RESERVE/HABITAT (AC-29), no minimum-age check (AC-31), and
## SACRIFICED as a verified terminal state (AC-44).
##
## Menagerie is now registered as Autoload #11 (GMenagerie) — this story is
## the one that required it (Engine Notes: request_sacrifice() must be
## callable as a bare global from Equipment Forge, Criterion B/ADR-0020).
## Tests still instantiate Menagerie directly (no add_child()) to avoid
## polluting GSavePersistence's real registered-systems list, matching this
## project's established test convention — the Autoload registration
## itself is a project.godot/boot-order concern, not something these
## per-test instances need to exercise.
extends GdUnitTestSuite

var _menagerie: Menagerie
var _spy: EventBusSpy


func before_test() -> void:
	_menagerie = Menagerie.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.creature_sacrificed)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _menagerie != null and is_instance_valid(_menagerie):
		_menagerie.free()
	_menagerie = null


func _add_creature(state: CreatureInstance.CreatureState) -> CreatureInstance:
	var creature := CreatureInstance.new()
	creature.creature_id = _menagerie._next_creature_id
	_menagerie._next_creature_id += 1
	creature.state = state
	creature.happiness = 70.0
	_menagerie._creatures.append(creature)
	return creature


# ---------------------------------------------------------------------------
# AC-29: RESERVE or HABITAT -> SACRIFICED, creature_sacrificed fires with
# target_item_id passed through unchanged.
# ---------------------------------------------------------------------------

func test_sacrifice_from_reserve_succeeds() -> void:
	var creature: CreatureInstance = _add_creature(CreatureInstance.CreatureState.RESERVE)
	var result: bool = _menagerie.request_sacrifice(creature.creature_id, 42)

	assert_bool(result).is_true()
	assert_that(creature.state).is_equal(CreatureInstance.CreatureState.SACRIFICED)
	assert_int(_spy.count("creature_sacrificed")).is_equal(1)
	var args: Array = (_spy.emissions["creature_sacrificed"] as Array)[0] as Array
	assert_int(args[0] as int).is_equal(creature.creature_id)
	assert_int(args[1] as int).is_equal(42)


func test_sacrifice_from_habitat_succeeds() -> void:
	var creature: CreatureInstance = _add_creature(CreatureInstance.CreatureState.HABITAT)
	var result: bool = _menagerie.request_sacrifice(creature.creature_id, 7)

	assert_bool(result).is_true()
	assert_that(creature.state).is_equal(CreatureInstance.CreatureState.SACRIFICED)


# ---------------------------------------------------------------------------
# AC-30: BREEDING_PEN -> rejected outright, zero state change, zero events.
# Only becomes sacrifice-eligible after being separately removed from the
# pen first.
# ---------------------------------------------------------------------------

func test_sacrifice_rejected_for_breeding_pen_creature() -> void:
	var creature: CreatureInstance = _add_creature(CreatureInstance.CreatureState.BREEDING_PEN)
	var result: bool = _menagerie.request_sacrifice(creature.creature_id, 42)

	assert_bool(result).is_false()
	assert_that(creature.state).is_equal(CreatureInstance.CreatureState.BREEDING_PEN)
	assert_bool(_spy.was_emitted("creature_sacrificed")).is_false()


func test_sacrifice_succeeds_after_removal_from_breeding_pen() -> void:
	var creature: CreatureInstance = _add_creature(CreatureInstance.CreatureState.BREEDING_PEN)
	_menagerie.return_from_breeding_pen_to_reserve(creature.creature_id)

	var result: bool = _menagerie.request_sacrifice(creature.creature_id, 42)
	assert_bool(result).is_true()
	assert_that(creature.state).is_equal(CreatureInstance.CreatureState.SACRIFICED)


# ---------------------------------------------------------------------------
# AC-31: no minimum-age check anywhere in the call path.
# ---------------------------------------------------------------------------

func test_same_session_acquisition_can_be_sacrificed_immediately() -> void:
	var creature: CreatureInstance = _add_creature(CreatureInstance.CreatureState.RESERVE)
	assert_int(creature.missions_since_tended).is_equal(0)  # zero missions since creation

	var result: bool = _menagerie.request_sacrifice(creature.creature_id, 1)
	assert_bool(result).is_true()


# ---------------------------------------------------------------------------
# AC-44: SACRIFICED is a verified terminal state — no further transition
# ever succeeds against the same creature_id.
# ---------------------------------------------------------------------------

func test_sacrificed_creature_cannot_be_moved_or_tended_or_sacrificed_again() -> void:
	var creature: CreatureInstance = _add_creature(CreatureInstance.CreatureState.HABITAT)
	_menagerie.request_sacrifice(creature.creature_id, 1)

	assert_bool(_menagerie.move_to_habitat(creature.creature_id)).is_false()
	assert_bool(_menagerie.move_to_breeding_pen(creature.creature_id)).is_false()
	assert_bool(_menagerie.tend_creature(creature.creature_id)).is_false()
	assert_bool(_menagerie.request_sacrifice(creature.creature_id, 2)).is_false()
	assert_that(creature.state).is_equal(CreatureInstance.CreatureState.SACRIFICED)
