## Integration test for the Tower Components blueprint-sourced recipes
## (2026-08-17): crafting recipe_archer_foundation end-to-end must produce a
## component whose stats match blueprint_archer.tres's embedded
## Foundation_archer sub-resource EXACTLY.
##
## This is the regression test that would catch future stat drift between
## the two .tres files (assets/data/towers/blueprints/blueprint_archer.tres
## and assets/data/tower_components/foundation_archer_copy.tres) — nothing
## else structurally enforces the two staying in sync, since
## recipe_resource.gd's source_blueprint_tower_id field is descriptive
## metadata only, never consulted by Crafting.resolve_craft() at craft time.
##
## Exercises the real, authored res://assets/data/recipes/ and
## res://assets/data/items/ content via the GGameDataRegistry Autoload.
extends GdUnitTestSuite

const RECIPE_ARCHER_FOUNDATION: StringName = &"recipe_archer_foundation"

var _crafting: Crafting


func before_test() -> void:
	_crafting = Crafting.new()
	GInventory.reset_to_defaults()


func after_test() -> void:
	if _crafting != null and is_instance_valid(_crafting):
		_crafting.free()
	_crafting = null
	GInventory.reset_to_defaults()


func _seed(item_id: StringName, quantity: int) -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(item_id)
	GInventory.add_stackable(def, quantity)


func test_crafting_archer_foundation_matches_blueprint_archer_exactly() -> void:
	_crafting._discovery_ledger[RECIPE_ARCHER_FOUNDATION] = true
	_seed(&"foundation_surplus", 3)

	var result: bool = _crafting.resolve_craft(RECIPE_ARCHER_FOUNDATION)
	assert_bool(result).is_true()

	# Locate the crafted instance and resolve its real component via the
	# same path TowerAssembly itself uses.
	var crafted_instance_id: int = -1
	for i: int in range(GInventory.get_slot_count()):
		var contents: Dictionary = GInventory.get_slot_contents(i)
		if not contents.is_empty() and contents.get("item_id") == "archer_foundation_component":
			crafted_instance_id = contents.get("instance_id")
			break
	assert_int(crafted_instance_id).is_not_equal(-1)

	var crafted_definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"archer_foundation_component")
	var crafted_component: FoundationComponent = load(crafted_definition.component_resource_path) as FoundationComponent
	assert_object(crafted_component).is_not_null()

	var blueprint: TowerBlueprintData = GGameDataRegistry.get_tower_blueprint(&"archer")
	assert_object(blueprint).is_not_null()
	var source: FoundationComponent = blueprint.foundation

	assert_str(crafted_component.archetype).is_equal(source.archetype)
	assert_float(crafted_component.hp_base).is_equal(source.hp_base)
	assert_int(crafted_component.tier).is_equal(source.tier)
	assert_float(crafted_component.tier_multiplier).is_equal(source.tier_multiplier)
	assert_float(crafted_component.tier_dps_multiplier).is_equal(source.tier_dps_multiplier)
	assert_float(crafted_component.tier_cost_factor).is_equal(source.tier_cost_factor)
	assert_float(crafted_component.tier_boss_dps_multiplier).is_equal(source.tier_boss_dps_multiplier)
	assert_that(crafted_component.footprint).is_equal(source.footprint)
	assert_str(crafted_component.pre_placement_perk).is_equal(source.pre_placement_perk)
	assert_float(crafted_component.archetype_cost_factor).is_equal(source.archetype_cost_factor)


## Regression test for a real bug found 2026-08-17: the 4 surplus materials
## share item_type="Material" with every other Material-tab item (so they
## still display in the existing Materials tab) — but this makes them
## vulnerable to Inventory.consume_by_type()'s generic "Material" sweep,
## which doesn't distinguish WHICH material it draws from. The fix was to
## keep the archer recipes' inputs keyed ONLY by the specific surplus
## material_id (never mixed with a generic "Material" cost) — this test
## proves crafting recipe_archer_foundation does not touch an unrelated
## surplus material (weapon_surplus) sitting in a different slot.
func test_crafting_archer_foundation_does_not_touch_unrelated_surplus_material() -> void:
	_crafting._discovery_ledger[RECIPE_ARCHER_FOUNDATION] = true
	_seed(&"foundation_surplus", 3)
	_seed(&"weapon_surplus", 3)

	var result: bool = _crafting.resolve_craft(RECIPE_ARCHER_FOUNDATION)
	assert_bool(result).is_true()

	assert_bool(GInventory.has_items_by_material_id({&"weapon_surplus": 3})).is_true()
