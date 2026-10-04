## Unit tests for Story 007 (TR-menag-001, roster/acquisition half; ADR-0026):
## the 5-species roster (no discovery gate, AC-1), deterministic Lure
## acquisition (AC-2/AC-3), and Formula 4's exact tier-scaled cost
## (AC-37/AC-38).
##
## Exercises the real, authored res://assets/data/species/ content via the
## GGameDataRegistry Autoload. Menagerie is instantiated directly (no
## add_child()) — deliberately NOT registered as an Autoload yet (deferred
## to whichever later story actually needs request_sacrifice() to be a bare
## global — mirrors Story 018/019's DefenseBuilding precedent). GInventory
## is the real Autoload, reset before/after.
extends GdUnitTestSuite

const GLIMMER_HARE: StringName = &"glimmer_hare"    # Tier 1
const MOSSBACK_TOAD: StringName = &"mossback_toad"  # Tier 1
const EMBERWING_MOTH: StringName = &"emberwing_moth"  # Tier 2
const DUSKFANG_FOX: StringName = &"duskfang_fox"    # Tier 2
const AURORA_STAG: StringName = &"aurora_stag"      # Tier 3

var _menagerie: Menagerie
var _spy: EventBusSpy


func before_test() -> void:
	_menagerie = Menagerie.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.materials_spent)
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
# AC-1: no discovery/unlock gate beyond material cost — all 5 species valid.
# ---------------------------------------------------------------------------

func test_all_five_species_are_lure_able_with_sufficient_materials() -> void:
	for species_id: StringName in [GLIMMER_HARE, MOSSBACK_TOAD, EMBERWING_MOTH, DUSKFANG_FOX, AURORA_STAG]:
		_seed_lure(9)  # covers even Tier 3's cost of 9
		var creature_id: int = _menagerie.lure_creature(species_id)
		assert_int(creature_id).is_greater_equal(0)
		GInventory.reset_to_defaults()


# ---------------------------------------------------------------------------
# AC-2/AC-4: sufficient materials -> materials_spent fires exact cost, one
# creature created at happiness=70, deterministic, and placed directly into
# HABITAT since an open slot exists (habitat_base_capacity=4, fresh
# Menagerie, this is the only creature luring in this test).
# ---------------------------------------------------------------------------

func test_lure_creature_success_full_flow() -> void:
	_seed_lure(3)  # exact Tier 1 cost
	var creature_id: int = _menagerie.lure_creature(GLIMMER_HARE)

	assert_int(creature_id).is_greater_equal(0)
	assert_int(_spy.count("materials_spent")).is_equal(1)
	var args: Array = (_spy.emissions["materials_spent"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal("menagerie_lure")
	assert_int(args[1] as int).is_equal(3)
	assert_int(_spy.count("creature_acquired")).is_equal(1)

	var creature: CreatureInstance = _menagerie.get_creature(creature_id)
	assert_object(creature).is_not_null()
	assert_float(creature.happiness).is_equal(70.0)
	# AC-4: HABITAT has an open slot (default capacity 4, nothing else
	# occupying it in this test) -- the new creature is placed directly into
	# HABITAT, not RESERVE. Real bug in this test, not in lure_creature():
	# TD-menag-006 (logged 2026-07-18) found this assertion contradicted the
	# GDD's own AC-4; the production code was already correct.
	assert_that(creature.state).is_equal(CreatureInstance.CreatureState.HABITAT)
	assert_that(creature.species).is_equal(GLIMMER_HARE)


## Regression (2026-10-04 smoke check): a Lure must charge its cost exactly
## once. It used to consume directly AND emit materials_spent, which Inventory
## also consumes on -- seeding the exact cost hid the double charge.
func test_lure_creature_charges_the_cost_exactly_once() -> void:
	_seed_lure(10)
	_menagerie.lure_creature(GLIMMER_HARE)  # Tier 1, cost 3

	assert_bool(GInventory.has_item_quantity(&"menagerie_lure", 7)).is_true()
	assert_bool(GInventory.has_item_quantity(&"menagerie_lure", 8)).is_false()


# ---------------------------------------------------------------------------
# AC-3: insufficient materials -> rejected, zero state change, no
# materials_spent.
# ---------------------------------------------------------------------------

func test_lure_creature_rejected_when_insufficient_lure_material() -> void:
	_seed_lure(2)  # below Tier 1's cost of 3
	var creature_id: int = _menagerie.lure_creature(GLIMMER_HARE)

	assert_int(creature_id).is_equal(-1)
	assert_bool(_spy.was_emitted("materials_spent")).is_false()
	assert_bool(_spy.was_emitted("creature_acquired")).is_false()
	assert_int(_menagerie._creatures.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-37/AC-38: Formula 4 — lure_cost(tier) = base_lure_cost(3) × tier.
# ---------------------------------------------------------------------------

func test_lure_cost_tier_1_is_3() -> void:
	assert_int(Menagerie.lure_cost(1)).is_equal(3)


func test_lure_cost_tier_3_is_9() -> void:
	assert_int(Menagerie.lure_cost(3)).is_equal(9)


func test_lure_cost_tier_2_is_6() -> void:
	assert_int(Menagerie.lure_cost(2)).is_equal(6)
