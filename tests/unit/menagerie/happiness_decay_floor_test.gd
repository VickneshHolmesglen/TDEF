## Unit tests for Story 012 (TR-menag-002, decay half; ADR-0026): starting
## happiness (AC-16) and Formula 1's floor-not-death decay (AC-17, AC-18,
## AC-40).
extends GdUnitTestSuite

var _menagerie: Menagerie


func before_test() -> void:
	_menagerie = Menagerie.new()
	GInventory.reset_to_defaults()


func after_test() -> void:
	if _menagerie != null and is_instance_valid(_menagerie):
		_menagerie.free()
	_menagerie = null
	GInventory.reset_to_defaults()


func _make_habitat_creature(happiness: float) -> CreatureInstance:
	var creature := CreatureInstance.new()
	creature.creature_id = _menagerie._next_creature_id
	_menagerie._next_creature_id += 1
	creature.state = CreatureInstance.CreatureState.HABITAT
	creature.happiness = happiness
	_menagerie._creatures.append(creature)
	return creature


# ---------------------------------------------------------------------------
# AC-16: newly-Lured creature starts at exactly 70.
# ---------------------------------------------------------------------------

func test_newly_lured_creature_starts_at_exactly_70() -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"menagerie_lure")
	GInventory.add_stackable(def, 3)
	var creature_id: int = _menagerie.lure_creature(&"glimmer_hare")
	var creature: CreatureInstance = _menagerie.get_creature(creature_id)
	assert_float(creature.happiness).is_equal(70.0)


# ---------------------------------------------------------------------------
# AC-17: 24 - 8 = 16, floored to 20 (not 16).
# ---------------------------------------------------------------------------

func test_decay_from_24_floors_to_20_not_16() -> void:
	var creature: CreatureInstance = _make_habitat_creature(24.0)
	_menagerie._apply_decay(creature)
	assert_float(creature.happiness).is_equal(20.0)


# ---------------------------------------------------------------------------
# AC-18: already at floor, another tick -> stays 20, no state change.
# ---------------------------------------------------------------------------

func test_decay_at_floor_stays_at_floor() -> void:
	var creature: CreatureInstance = _make_habitat_creature(20.0)
	_menagerie._apply_decay(creature)
	assert_float(creature.happiness).is_equal(20.0)
	assert_that(creature.state).is_equal(CreatureInstance.CreatureState.HABITAT)


# ---------------------------------------------------------------------------
# AC-40: multiple consecutive un-tended ticks past the floor -> still a
# fully functional HABITAT creature, no removal/eviction.
# ---------------------------------------------------------------------------

func test_multiple_ticks_past_floor_creature_remains_functional_habitat() -> void:
	var creature: CreatureInstance = _make_habitat_creature(24.0)
	for i: int in range(5):
		_menagerie._apply_decay(creature)
	assert_float(creature.happiness).is_equal(20.0)
	assert_that(creature.state).is_equal(CreatureInstance.CreatureState.HABITAT)
	assert_int(_menagerie._creatures.size()).is_equal(1)  # never removed
	# Still contributes to Formula 3 at its minimum share.
	assert_float(_menagerie.compute_quality_bonus()).is_equal_approx(1.10, 0.001)
