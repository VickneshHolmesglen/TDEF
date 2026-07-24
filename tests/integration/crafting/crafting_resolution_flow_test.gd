## Integration tests for Story 004 (TR-craft-003, ADR-0023 Rule 8): the
## Crafting Resolution Flow — steps (a)-(e), the tower_component room
## pre-check (AC-4), successful resolution (AC-5), the shared
## `_craft_resolving` double-confirm guard (AC-7), stale-UI rejection
## (AC-12), and crafted_good's consume-before-placement-failure ordering
## (AC-13).
##
## Exercises the real, authored res://assets/data/recipes/ and
## res://assets/data/items/ content via the GGameDataRegistry Autoload.
## Crafting is instantiated directly (no add_child()); GInventory is the
## real Autoload, reset before/after each test.
extends GdUnitTestSuite

const RECIPE_IRON_FOUNDATION: StringName = &"recipe_iron_foundation"  # tower_component, needs 5 Material
const RECIPE_HEALING_SALVE: StringName = &"recipe_healing_salve"      # crafted_good, needs 3 Material

var _crafting: Crafting
var _spy: EventBusSpy


func before_test() -> void:
	_crafting = Crafting.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.component_crafted)
	_spy.watch(GEventBus.item_added)
	_spy.watch(GEventBus.item_removed)
	_spy.watch(GEventBus.item_pickup_rejected)
	GInventory.reset_to_defaults()


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _crafting != null and is_instance_valid(_crafting):
		_crafting.free()
	_crafting = null
	GInventory.reset_to_defaults()


func _seed_material(quantity: int) -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"common_scrap")
	GInventory.add_stackable(def, quantity)


func _fill_all_slots_with_unrelated_unique_items() -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"iron_foundation_component")
	for i: int in range(GInventory.get_slot_count()):
		GInventory.add_unique_item(def, {})


# ---------------------------------------------------------------------------
# AC-4: tower_component, materials sufficient, no room -> reject, zero
# materials consumed, no component_crafted.
# ---------------------------------------------------------------------------

func test_resolve_craft_tower_component_rejected_when_inventory_full() -> void:
	_crafting._discovery_ledger[RECIPE_IRON_FOUNDATION] = true
	_seed_material(5)
	# Fill the remaining slots so no empty slot is left.
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"iron_foundation_component")
	while GInventory.has_room_for("TowerComponent", 1):
		GInventory.add_unique_item(def, {})

	var result: bool = _crafting.resolve_craft(RECIPE_IRON_FOUNDATION)

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("component_crafted")).is_false()
	assert_bool(_spy.was_emitted("item_removed")).is_false()  # zero materials consumed


func test_resolve_craft_tower_component_succeeds_with_exactly_one_free_slot() -> void:
	_crafting._discovery_ledger[RECIPE_IRON_FOUNDATION] = true
	_seed_material(5)  # occupies 1 slot
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"iron_foundation_component")
	# Fill down to exactly 1 free slot remaining.
	while GInventory.has_room_for("TowerComponent", 2):
		GInventory.add_unique_item(def, {})

	var result: bool = _crafting.resolve_craft(RECIPE_IRON_FOUNDATION)
	assert_bool(result).is_true()
	assert_bool(_spy.was_emitted("component_crafted")).is_true()


# ---------------------------------------------------------------------------
# AC-5: fully craftable recipe -> materials consumed, item_added for output,
# component_crafted fires exactly once.
# ---------------------------------------------------------------------------

func test_resolve_craft_tower_component_success_full_flow() -> void:
	_crafting._discovery_ledger[RECIPE_IRON_FOUNDATION] = true
	_seed_material(5)

	var result: bool = _crafting.resolve_craft(RECIPE_IRON_FOUNDATION)

	assert_bool(result).is_true()
	assert_int(_spy.count("component_crafted")).is_equal(1)
	var args: Array = (_spy.emissions["component_crafted"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal("iron_foundation_component")
	assert_str(args[1] as String).is_equal("tower_component")
	assert_int(args[2] as int).is_equal(1)
	assert_bool(_spy.was_emitted("item_added")).is_true()
	assert_bool(_spy.was_emitted("item_removed")).is_true()


func test_resolve_craft_crafted_good_success_full_flow() -> void:
	_crafting._discovery_ledger[RECIPE_HEALING_SALVE] = true
	_seed_material(3)

	var result: bool = _crafting.resolve_craft(RECIPE_HEALING_SALVE)

	assert_bool(result).is_true()
	assert_int(_spy.count("component_crafted")).is_equal(1)
	assert_bool(_spy.was_emitted("item_added")).is_true()


# ---------------------------------------------------------------------------
# AC-7: shared _craft_resolving guard rejects a second same-frame confirm.
# ---------------------------------------------------------------------------

func test_second_confirmation_rejected_outright_while_craft_resolving_is_true() -> void:
	_crafting._discovery_ledger[RECIPE_IRON_FOUNDATION] = true
	_seed_material(5)
	_crafting._craft_resolving = true

	var result: bool = _crafting.resolve_craft(RECIPE_IRON_FOUNDATION)

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("component_crafted")).is_false()
	assert_bool(_spy.was_emitted("item_removed")).is_false()


func test_guard_releases_after_successful_resolve() -> void:
	_crafting._discovery_ledger[RECIPE_HEALING_SALVE] = true
	_seed_material(3)
	_crafting.resolve_craft(RECIPE_HEALING_SALVE)
	assert_bool(_crafting._craft_resolving).is_false()


# ---------------------------------------------------------------------------
# AC-12: stale UI — materials insufficient at confirm time -> rejected,
# zero side effects.
# ---------------------------------------------------------------------------

func test_resolve_craft_rejected_by_stale_ui_insufficient_materials() -> void:
	_crafting._discovery_ledger[RECIPE_IRON_FOUNDATION] = true
	_seed_material(2)  # below the required 5

	var result: bool = _crafting.resolve_craft(RECIPE_IRON_FOUNDATION)

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("component_crafted")).is_false()
	assert_bool(_spy.was_emitted("item_removed")).is_false()
	assert_bool(_crafting._craft_resolving).is_false()  # guard released, not stuck


# ---------------------------------------------------------------------------
# AC-13: crafted_good skips the room pre-check — materials ARE consumed even
# when the output-add attempt subsequently fails (genuinely no room).
# ---------------------------------------------------------------------------

func test_resolve_craft_crafted_good_consumes_materials_even_when_placement_fails() -> void:
	_crafting._discovery_ledger[RECIPE_HEALING_SALVE] = true
	# Seed MORE than the recipe needs (10, not 3) so consuming exactly 3
	# leaves 7 remaining in the same slot — the slot does NOT hit zero and
	# free up, which would otherwise accidentally open room for the output
	# and invalidate this "genuinely no room anywhere" scenario.
	_seed_material(10)
	_fill_all_slots_with_unrelated_unique_items()  # fills all remaining slots

	var result: bool = _crafting.resolve_craft(RECIPE_HEALING_SALVE)

	assert_bool(result).is_false()  # placement failed
	assert_bool(_spy.was_emitted("item_removed")).is_true()  # materials WERE consumed (step c ran)
	assert_bool(_spy.was_emitted("component_crafted")).is_false()  # no event for the failed placement
	assert_bool(_spy.was_emitted("item_pickup_rejected")).is_true()  # Inventory's existing rejection policy
