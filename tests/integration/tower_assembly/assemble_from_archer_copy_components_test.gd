## Integration test proving the new blueprint-sourced crafting path (2026-08-17,
## Tower Components) feeds the EXISTING, unmodified TowerAssembly system with
## zero special-casing: craft all 4 Archer-copy components via the real
## Crafting flow, then assemble them via TowerAssembly.assemble_tower()
## exactly as any other crafted component would be.
##
## Exercises the real, authored res://assets/data/recipes/,
## res://assets/data/items/, and res://assets/data/tower_components/ content
## via the GGameDataRegistry Autoload.
extends GdUnitTestSuite

const RECIPE_ARCHER_FOUNDATION: StringName = &"recipe_archer_foundation"
const RECIPE_ARCHER_WEAPON: StringName = &"recipe_archer_weapon"
const RECIPE_ARCHER_FOCUS: StringName = &"recipe_archer_focus"
const RECIPE_ARCHER_POWER: StringName = &"recipe_archer_power"

var _crafting: Crafting
var _tower_assembly: TowerAssembly


func before_test() -> void:
	_crafting = Crafting.new()
	_tower_assembly = TowerAssembly.new()
	add_child(_tower_assembly)
	GInventory.reset_to_defaults()


func after_test() -> void:
	if _crafting != null and is_instance_valid(_crafting):
		_crafting.free()
	_crafting = null
	if _tower_assembly != null and is_instance_valid(_tower_assembly):
		remove_child(_tower_assembly)
		_tower_assembly.free()
	_tower_assembly = null
	GInventory.reset_to_defaults()


func _seed(item_id: StringName, quantity: int) -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(item_id)
	GInventory.add_stackable(def, quantity)


## Crafts all 4 Archer-copy components via the real Crafting flow and
## returns their 4 instance_ids in (foundation, weapon, focus, power) order.
func _craft_full_archer_copy_set() -> Array[int]:
	_crafting._discovery_ledger[RECIPE_ARCHER_FOUNDATION] = true
	_crafting._discovery_ledger[RECIPE_ARCHER_WEAPON] = true
	_crafting._discovery_ledger[RECIPE_ARCHER_FOCUS] = true
	_crafting._discovery_ledger[RECIPE_ARCHER_POWER] = true
	_seed(&"foundation_surplus", 3)
	_seed(&"weapon_surplus", 3)
	_seed(&"focus_surplus", 3)
	_seed(&"power_surplus", 3)

	assert_bool(_crafting.resolve_craft(RECIPE_ARCHER_FOUNDATION)).is_true()
	assert_bool(_crafting.resolve_craft(RECIPE_ARCHER_WEAPON)).is_true()
	assert_bool(_crafting.resolve_craft(RECIPE_ARCHER_FOCUS)).is_true()
	assert_bool(_crafting.resolve_craft(RECIPE_ARCHER_POWER)).is_true()

	var ids: Array[int] = [-1, -1, -1, -1]
	var wanted: Array[StringName] = [&"archer_foundation_component", &"archer_weapon_component", &"archer_focus_component", &"archer_power_component"]
	for i: int in range(GInventory.get_slot_count()):
		var contents: Dictionary = GInventory.get_slot_contents(i)
		if contents.is_empty():
			continue
		var idx: int = wanted.find(StringName(contents.get("item_id") as String))
		if idx != -1:
			ids[idx] = contents.get("instance_id") as int
	return ids


func test_assemble_tower_succeeds_from_crafted_archer_copy_components() -> void:
	var ids: Array[int] = _craft_full_archer_copy_set()
	assert_int(ids[0]).is_not_equal(-1)
	assert_int(ids[1]).is_not_equal(-1)
	assert_int(ids[2]).is_not_equal(-1)
	assert_int(ids[3]).is_not_equal(-1)

	var tower_id: StringName = _tower_assembly.assemble_tower(ids[0], ids[1], ids[2], ids[3], "My Archer Remix")
	assert_that(tower_id).is_not_equal(&"")

	var blueprint: TowerBlueprintData = _tower_assembly.get_assembled_blueprint(tower_id)
	assert_object(blueprint).is_not_null()
	assert_str(blueprint.display_name).is_equal("My Archer Remix")

	var source_blueprint: TowerBlueprintData = GGameDataRegistry.get_tower_blueprint(&"archer")
	assert_str(blueprint.foundation.archetype).is_equal(source_blueprint.foundation.archetype)
	assert_float(blueprint.weapon.weapon_damage).is_equal(source_blueprint.weapon.weapon_damage)
	assert_str(blueprint.focus.targeting_mode).is_equal(source_blueprint.focus.targeting_mode)
