## Integration tests for Story 014 (TR-equipforge-002, ADR-0025/ADR-0026):
## Creature Sacrifice Resolution (AC-17-22).
##
## Exercises the real, authored res://assets/data/sacrifice_recipes/,
## res://assets/data/species/, and res://assets/data/items/ content via
## GGameDataRegistry. EquipmentForge is instantiated directly
## (EquipmentForge.new(), no add_child()). GInventory and GMenagerie ARE the
## real global Autoloads — GMenagerie.request_sacrifice()/get_creature() are
## only reachable as bare globals (ADR-0026 Decision), matching
## sacrifice_validation_test.gd's own established convention. Both reset in
## before_test()/after_test().
extends GdUnitTestSuite

var _forge: EquipmentForge
var _spy: EventBusSpy


func before_test() -> void:
	_forge = EquipmentForge.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_equipment_crafted)
	_spy.watch(GEventBus.item_rune_imbued)
	_spy.watch(GEventBus.item_added)
	GInventory.reset_to_defaults()
	GMenagerie.reset_to_defaults()


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _forge != null and is_instance_valid(_forge):
		_forge.free()
	_forge = null
	GInventory.reset_to_defaults()
	GMenagerie.reset_to_defaults()


## Lures a real creature of the given species via the real GMenagerie
## Autoload (seeds enough menagerie_lure to cover Formula 4's tier-scaled
## cost) and returns its creature_id.
func _lure(species_id: StringName) -> int:
	var species: SpeciesResource = GGameDataRegistry.get_species(species_id)
	var lure_def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"menagerie_lure")
	GInventory.add_stackable(lure_def, Menagerie.lure_cost(species.species_tier))
	return GMenagerie.lure_creature(species_id)


# ---------------------------------------------------------------------------
# AC-17: happy path, exact ordering
# ---------------------------------------------------------------------------

func test_sacrifice_happy_path_creates_item_and_fires_events_in_order() -> void:
	var creature_id: int = _lure(&"aurora_stag")

	# item_added (from add_unique_item) -> hero_equipment_crafted -> item_rune_imbued,
	# in that exact order (AC-17) — recorded via local connects, since
	# EventBusSpy tracks per-signal counts/args but not cross-signal ordering.
	var order: Array = []
	var on_item_added := func(_a, _b, _c) -> void: order.append("item_added")
	var on_crafted := func(_a, _b, _c) -> void: order.append("hero_equipment_crafted")
	var on_imbued := func(_a, _b, _c) -> void: order.append("item_rune_imbued")
	GEventBus.item_added.connect(on_item_added)
	GEventBus.hero_equipment_crafted.connect(on_crafted)
	GEventBus.item_rune_imbued.connect(on_imbued)

	var result: bool = _forge.resolve_sacrifice(&"sacrifice_aurora_stag", creature_id)

	GEventBus.item_added.disconnect(on_item_added)
	GEventBus.hero_equipment_crafted.disconnect(on_crafted)
	GEventBus.item_rune_imbued.disconnect(on_imbued)

	assert_bool(result).is_true()
	assert_that(GMenagerie.get_creature(creature_id).state).is_equal(CreatureInstance.CreatureState.SACRIFICED)
	assert_array(order).contains_exactly(["item_added", "hero_equipment_crafted", "item_rune_imbued"])

	assert_int(_spy.count("hero_equipment_crafted")).is_equal(1)
	var crafted_args: Array = (_spy.emissions["hero_equipment_crafted"] as Array)[0]
	assert_str(crafted_args[0] as String).is_equal("iron_sword")
	assert_str(crafted_args[1] as String).is_equal("weapon")
	assert_int(crafted_args[2] as int).is_equal(4)  # Formula 2: clamp(3+1, 1, 4) = 4

	assert_int(_spy.count("item_rune_imbued")).is_equal(1)
	var imbue_args: Array = (_spy.emissions["item_rune_imbued"] as Array)[0]
	assert_str(imbue_args[1] as String).is_equal("rune_menagerie_aurora_stag")
	assert_str(imbue_args[2] as String).is_equal("menagerie")

	# The item arrives with 1 of 2 rune slots pre-filled (weapon = 2 per Rule 11).
	var slot0: Dictionary = GInventory.get_slot_contents(0)
	assert_array(slot0["imbued_runes"] as Array).contains_exactly(["rune_menagerie_aurora_stag"])
	assert_int(slot0["rune_slot_count"] as int).is_equal(2)


# ---------------------------------------------------------------------------
# AC-18: species mismatch rejected pre-call
# ---------------------------------------------------------------------------

func test_sacrifice_rejected_for_species_mismatch_before_any_menagerie_call() -> void:
	var creature_id: int = _lure(&"glimmer_hare")  # recipe requires aurora_stag
	_spy.clear()  # discard _lure()'s own item_added (menagerie_lure seeding)

	var result: bool = _forge.resolve_sacrifice(&"sacrifice_aurora_stag", creature_id)

	assert_bool(result).is_false()
	assert_that(GMenagerie.get_creature(creature_id).state).is_not_equal(CreatureInstance.CreatureState.SACRIFICED)
	assert_bool(_spy.was_emitted("item_added")).is_false()


# ---------------------------------------------------------------------------
# AC-19: creature in BREEDING_PEN rejected, zero side effects
# ---------------------------------------------------------------------------

func test_sacrifice_rejected_for_breeding_pen_creature() -> void:
	var creature_id: int = _lure(&"aurora_stag")
	GMenagerie.move_to_breeding_pen(creature_id)
	_spy.clear()  # discard _lure()'s own item_added (menagerie_lure seeding)

	var result: bool = _forge.resolve_sacrifice(&"sacrifice_aurora_stag", creature_id)

	assert_bool(result).is_false()
	assert_that(GMenagerie.get_creature(creature_id).state).is_equal(CreatureInstance.CreatureState.BREEDING_PEN)
	assert_bool(_spy.was_emitted("item_added")).is_false()
	assert_bool(_spy.was_emitted("hero_equipment_crafted")).is_false()


# ---------------------------------------------------------------------------
# AC-20: room check strictly precedes creature consumption
# ---------------------------------------------------------------------------

func test_sacrifice_rejected_when_no_inventory_room_creature_never_touched() -> void:
	var creature_id: int = _lure(&"aurora_stag")
	var filler: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"iron_sword")
	for i in range(10):
		GInventory.add_unique_item(filler)  # fill all 10 slots (5 discretionary + 5 equipment)

	var result: bool = _forge.resolve_sacrifice(&"sacrifice_aurora_stag", creature_id)

	assert_bool(result).is_false()
	assert_that(GMenagerie.get_creature(creature_id).state).is_not_equal(CreatureInstance.CreatureState.SACRIFICED)


# ---------------------------------------------------------------------------
# AC-21/AC-22: Formula 2 worked examples
# ---------------------------------------------------------------------------

func test_formula_2_maximum_tier_3_species_produces_quality_tier_4() -> void:
	assert_int(EquipmentForge.sacrifice_quality_tier(3)).is_equal(4)


func test_formula_2_minimum_tier_1_species_produces_quality_tier_2_never_1() -> void:
	assert_int(EquipmentForge.sacrifice_quality_tier(1)).is_equal(2)


func test_sacrifice_of_tier_1_species_produces_quality_tier_2_end_to_end() -> void:
	var creature_id: int = _lure(&"glimmer_hare")

	var result: bool = _forge.resolve_sacrifice(&"sacrifice_glimmer_hare", creature_id)

	assert_bool(result).is_true()
	var crafted_args: Array = (_spy.emissions["hero_equipment_crafted"] as Array)[0]
	assert_int(crafted_args[2] as int).is_equal(2)
