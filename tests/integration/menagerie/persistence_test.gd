## Integration tests for Story 017 (TR-menag-003, ADR-0026): creature_acquired
## fires exactly once regardless of placement outcome (AC-32), and the full
## SaveRestorer round-trip (creatures, breeding pens, habitat capacity,
## next_creature_id).
##
## Menagerie is instantiated directly (no add_child()) so _ready() never
## fires — GSavePersistence.register() is never called, avoiding pollution
## of the real Autoload's _registered_systems list. Round-trips call
## get_save_data()/restore_save_data() directly between two local instances,
## matching this project's established persistence-test convention.
extends GdUnitTestSuite

var _menagerie: Menagerie
var _spy: EventBusSpy


func before_test() -> void:
	_menagerie = Menagerie.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.creature_acquired)
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
# AC-32: creature_acquired fires exactly once, regardless of HABITAT vs
# RESERVE placement outcome.
# ---------------------------------------------------------------------------

func test_creature_acquired_fires_once_when_placed_in_habitat() -> void:
	_seed_lure(3)
	_menagerie.lure_creature(&"glimmer_hare")
	assert_int(_spy.count("creature_acquired")).is_equal(1)


func test_creature_acquired_fires_once_when_overflows_to_reserve() -> void:
	for i: int in range(4):
		_seed_lure(3)
		_menagerie.lure_creature(&"glimmer_hare")
	_spy.clear()

	_seed_lure(3)
	_menagerie.lure_creature(&"glimmer_hare")  # HABITAT full, overflows to RESERVE
	assert_int(_spy.count("creature_acquired")).is_equal(1)


# ---------------------------------------------------------------------------
# Persistence round-trip: creatures (mixed states/happiness), breeding pens,
# habitat capacity, next_creature_id all survive save/restore exactly.
# ---------------------------------------------------------------------------

func test_save_reload_round_trip_preserves_full_state() -> void:
	_seed_lure(9)
	_menagerie.lure_creature(&"aurora_stag")  # HABITAT, happiness 70
	_menagerie._on_sanctuary_structure_built("habitat_expansion_tier_1", "habitat_expansion")  # capacity -> 6

	var a: CreatureInstance = CreatureInstance.new()
	a.creature_id = _menagerie._next_creature_id
	_menagerie._next_creature_id += 1
	a.species = &"glimmer_hare"
	a.state = CreatureInstance.CreatureState.RESERVE
	a.happiness = 55.0
	a.missions_since_tended = 2
	_menagerie._creatures.append(a)

	var b: CreatureInstance = CreatureInstance.new()
	b.creature_id = _menagerie._next_creature_id
	_menagerie._next_creature_id += 1
	b.species = &"glimmer_hare"
	b.state = CreatureInstance.CreatureState.RESERVE
	b.happiness = 60.0
	_menagerie._creatures.append(b)
	_menagerie.pair_for_breeding(a.creature_id, b.creature_id)

	var data: Dictionary = _menagerie.get_save_data()

	var restored := Menagerie.new()
	var ok: bool = restored.restore_save_data(data)

	assert_bool(ok).is_true()
	assert_int(restored._creatures.size()).is_equal(3)
	assert_int(restored._habitat_capacity).is_equal(6)
	assert_int(restored._next_creature_id).is_equal(_menagerie._next_creature_id)

	var restored_a: CreatureInstance = restored.get_creature(a.creature_id)
	assert_that(restored_a.state).is_equal(CreatureInstance.CreatureState.BREEDING_PEN)
	assert_float(restored_a.happiness).is_equal(55.0)
	assert_int(restored_a.missions_since_tended).is_equal(2)

	assert_int(restored._breeding_pens[0].occupant_ids.size()).is_equal(2)
	assert_int(restored._breeding_pens[0].breeding_missions_remaining).is_equal(2)  # Tier 1
	restored.free()


## Regression test (code review, 2026-07-18): restore_save_data() must clamp
## an out-of-range happiness value (corrupted/hand-edited save) to
## [HAPPINESS_FLOOR, HAPPINESS_CEILING], per the defensive clamp documented
## in restore_save_data()'s own comment. No prior test exercised an
## out-of-range value — only in-range round-trips were covered.
func test_restore_save_data_clamps_out_of_range_happiness() -> void:
	var malformed_data: Dictionary = {
		"creatures": [
			{"creature_id": 0, "species": "glimmer_hare", "state": CreatureInstance.CreatureState.RESERVE, "happiness": 150.0, "missions_since_tended": 0},
			{"creature_id": 1, "species": "glimmer_hare", "state": CreatureInstance.CreatureState.RESERVE, "happiness": -30.0, "missions_since_tended": 0},
		],
		"breeding_pens": [
			{"occupant_ids": [], "breeding_missions_remaining": -1},
			{"occupant_ids": [], "breeding_missions_remaining": -1},
		],
		"habitat_capacity": 4,
		"next_creature_id": 2,
	}

	var restored := Menagerie.new()
	var ok: bool = restored.restore_save_data(malformed_data)

	assert_bool(ok).is_true()
	assert_float(restored.get_creature(0).happiness).is_equal(Menagerie.HAPPINESS_CEILING)
	assert_float(restored.get_creature(1).happiness).is_equal(Menagerie.HAPPINESS_FLOOR)
	restored.free()


func test_get_save_data_returns_only_primitive_types() -> void:
	_seed_lure(3)
	_menagerie.lure_creature(&"glimmer_hare")
	var data: Dictionary = _menagerie.get_save_data()

	var creatures: Array = data["creatures"] as Array
	for entry: Variant in creatures:
		var dict: Dictionary = entry as Dictionary
		assert_bool(dict["species"] is String).is_true()
		assert_bool(dict["state"] is int).is_true()


func test_restore_save_data_rejects_malformed_payload() -> void:
	var ok: bool = _menagerie.restore_save_data({"creatures": "not_an_array", "breeding_pens": [], "habitat_capacity": 4, "next_creature_id": 0})
	assert_bool(ok).is_false()


func test_reset_to_defaults_clears_all_state() -> void:
	_seed_lure(3)
	_menagerie.lure_creature(&"glimmer_hare")
	_menagerie._on_sanctuary_structure_built("habitat_expansion_tier_1", "habitat_expansion")

	_menagerie.reset_to_defaults()

	assert_int(_menagerie._creatures.size()).is_equal(0)
	assert_int(_menagerie._habitat_capacity).is_equal(4)
	assert_int(_menagerie._next_creature_id).is_equal(0)
	assert_int(_menagerie._breeding_pens.size()).is_equal(2)
	assert_int(_menagerie._breeding_pens[0].occupant_ids.size()).is_equal(0)
