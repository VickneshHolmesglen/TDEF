## Unit tests for Story 008 (TR-menag-001, placement half; ADR-0026):
## HABITAT/RESERVE routing on Lure acquisition — direct HABITAT placement
## when a slot is open (AC-4, triggers aggregate recompute), RESERVE
## overflow when full (AC-5, no recompute).
##
## Exercises the real, authored res://assets/data/species/ and
## res://assets/data/items/ content via GGameDataRegistry. Menagerie
## instantiated directly (no add_child()); GInventory is the real Autoload,
## reset before/after.
extends GdUnitTestSuite

const GLIMMER_HARE: StringName = &"glimmer_hare"  # Tier 1, cost 3

var _menagerie: Menagerie
var _spy: EventBusSpy


func before_test() -> void:
	_menagerie = Menagerie.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.creature_acquired)
	_spy.watch(GEventBus.creature_happiness_changed)
	GInventory.reset_to_defaults()


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _menagerie != null and is_instance_valid(_menagerie):
		_menagerie.free()
	_menagerie = null
	GInventory.reset_to_defaults()


func _seed_lure(quantity: int) -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"menagerie_lure")
	GInventory.add_stackable(def, quantity)


# ---------------------------------------------------------------------------
# AC-4: HABITAT has an open slot -> new creature placed directly into
# HABITAT, aggregate recompute + creature_happiness_changed fire.
# ---------------------------------------------------------------------------

func test_lure_places_directly_into_habitat_when_slot_open() -> void:
	_seed_lure(3)
	var creature_id: int = _menagerie.lure_creature(GLIMMER_HARE)

	assert_bool(_spy.was_emitted("creature_acquired")).is_true()
	var creature: CreatureInstance = _menagerie.get_creature(creature_id)
	assert_that(creature.state).is_equal(CreatureInstance.CreatureState.HABITAT)
	assert_bool(_spy.was_emitted("creature_happiness_changed")).is_true()


func test_lure_places_into_habitat_with_exactly_one_open_slot() -> void:
	# Fill 3 of the 4 base HABITAT slots first.
	for i: int in range(3):
		_seed_lure(3)
		_menagerie.lure_creature(GLIMMER_HARE)
	_spy.clear()

	_seed_lure(3)
	var creature_id: int = _menagerie.lure_creature(GLIMMER_HARE)
	var creature: CreatureInstance = _menagerie.get_creature(creature_id)
	assert_that(creature.state).is_equal(CreatureInstance.CreatureState.HABITAT)


# ---------------------------------------------------------------------------
# AC-5: HABITAT at full capacity -> RESERVE overflow, creature_acquired
# fires, no aggregate recompute / creature_happiness_changed.
# ---------------------------------------------------------------------------

func test_lure_places_into_reserve_when_habitat_full() -> void:
	# Fill all 4 base HABITAT slots.
	for i: int in range(4):
		_seed_lure(3)
		_menagerie.lure_creature(GLIMMER_HARE)
	_spy.clear()

	_seed_lure(3)
	var creature_id: int = _menagerie.lure_creature(GLIMMER_HARE)

	assert_bool(_spy.was_emitted("creature_acquired")).is_true()
	var creature: CreatureInstance = _menagerie.get_creature(creature_id)
	assert_that(creature.state).is_equal(CreatureInstance.CreatureState.RESERVE)
	assert_bool(_spy.was_emitted("creature_happiness_changed")).is_false()
