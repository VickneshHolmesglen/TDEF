## Unit tests for Story 003 (TR-craft-002, craftability half; ADR-0023):
## Crafting.is_craftable() — a pure, on-demand read, structurally separate
## from the one-time Discovery Ledger (AC-3).
##
## Exercises the real, authored res://assets/data/recipes/ content via the
## GGameDataRegistry Autoload. Crafting is instantiated directly, no
## add_child() — GInventory is the real Autoload, reset before/after.
extends GdUnitTestSuite

const RECIPE_HEALING_SALVE: StringName = &"recipe_healing_salve"  # ungated, needs 3 Material

var _crafting: Crafting


func before_test() -> void:
	_crafting = Crafting.new()
	GInventory.reset_to_defaults()


func after_test() -> void:
	if _crafting != null and is_instance_valid(_crafting):
		_crafting.free()
	_crafting = null
	GInventory.reset_to_defaults()


func _seed_material(quantity: int) -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"common_scrap")
	GInventory.add_stackable(def, quantity)


func test_is_craftable_false_for_undiscovered_recipe_even_with_sufficient_materials() -> void:
	_seed_material(10)
	assert_bool(_crafting.is_craftable(RECIPE_HEALING_SALVE)).is_false()


func test_is_craftable_true_for_discovered_recipe_with_sufficient_materials() -> void:
	_seed_material(3)
	_crafting._discovery_ledger[RECIPE_HEALING_SALVE] = true
	assert_bool(_crafting.is_craftable(RECIPE_HEALING_SALVE)).is_true()


func test_is_craftable_false_when_materials_drop_below_inputs_recipe_stays_discovered() -> void:
	_crafting._discovery_ledger[RECIPE_HEALING_SALVE] = true
	_seed_material(1)  # below the required 3

	assert_bool(_crafting.is_craftable(RECIPE_HEALING_SALVE)).is_false()
	assert_bool(_crafting.is_discovered(RECIPE_HEALING_SALVE)).is_true()  # unaffected — still DISCOVERED


func test_is_craftable_flips_back_true_when_materials_rise_again_no_redisovery() -> void:
	_crafting._discovery_ledger[RECIPE_HEALING_SALVE] = true
	assert_bool(_crafting.is_craftable(RECIPE_HEALING_SALVE)).is_false()

	_seed_material(3)
	assert_bool(_crafting.is_craftable(RECIPE_HEALING_SALVE)).is_true()
	# Discovery Ledger entry unchanged — still exactly the one entry it
	# already had, no new/duplicate write.
	assert_int(_crafting._discovery_ledger.size()).is_equal(1)


func test_is_craftable_unknown_recipe_id_returns_false_not_crash() -> void:
	_crafting._discovery_ledger[&"recipe_does_not_exist"] = true
	assert_bool(_crafting.is_craftable(&"recipe_does_not_exist")).is_false()
