## Regression guard for the tower_component recipe output collision found
## and fixed 2026-08-07 (commit 89aa082): recipe_iron_foundation (foundation,
## T1), recipe_advanced_component (weapon, T2), and recipe_tier4_component
## (power, T4) all set output_item_id to the same shared item
## ("iron_foundation_component") -- crafting the weapon or power component
## recipe incorrectly handed the player a Foundation item.
## RecipeResource.validate() cannot catch this on its own: it only checks
## that output_item_id references SOME real item, never that distinct
## component_slot recipes produce distinct items.
##
## Exercises the real GGameDataRegistry Autoload (recipes are static,
## boot-loaded content).
extends GdUnitTestSuite


## Two tower_component recipes for two DIFFERENT component_slot values must
## never share an output_item_id -- each slot needs its own distinct item.
func test_tower_component_recipes_with_different_slots_have_distinct_outputs() -> void:
	var recipes: Dictionary[StringName, RecipeResource] = GGameDataRegistry.get_all_recipes()
	var output_by_slot: Dictionary = {}  # component_slot -> {output_item_id -> recipe_id}
	for recipe_id: StringName in recipes:
		var recipe: RecipeResource = recipes[recipe_id]
		if recipe.recipe_category != "tower_component":
			continue
		var slot: String = recipe.component_slot
		var output: StringName = recipe.output_item_id
		if not output_by_slot.has(slot):
			output_by_slot[slot] = {}
		(output_by_slot[slot] as Dictionary)[output] = recipe_id

	# Collect every (slot, output_item_id) pair seen, then assert no
	# output_item_id is shared across two DIFFERENT slots.
	var owner_slot_by_output: Dictionary = {}  # output_item_id -> first slot that claimed it
	for slot: String in output_by_slot:
		for output: StringName in (output_by_slot[slot] as Dictionary):
			if owner_slot_by_output.has(output):
				var other_slot: String = owner_slot_by_output[output]
				assert_str(slot) \
					.override_failure_message("output_item_id '%s' is produced by both component_slot '%s' and '%s' — two different tower component slots must never share an output item" % [output, other_slot, slot]) \
					.is_equal(other_slot)
			else:
				owner_slot_by_output[output] = slot


## Sanity check the fix actually landed: the 3 real tower_component recipes
## authored today each resolve to a distinct, correctly-slotted item.
func test_the_three_real_tower_component_recipes_have_distinct_outputs() -> void:
	var foundation: RecipeResource = GGameDataRegistry.get_recipe(&"recipe_iron_foundation")
	var weapon: RecipeResource = GGameDataRegistry.get_recipe(&"recipe_advanced_component")
	var power: RecipeResource = GGameDataRegistry.get_recipe(&"recipe_tier4_component")

	assert_object(foundation).is_not_null()
	assert_object(weapon).is_not_null()
	assert_object(power).is_not_null()

	assert_str(String(foundation.output_item_id)).is_equal("iron_foundation_component")
	assert_str(String(weapon.output_item_id)).is_equal("advanced_weapon_component")
	assert_str(String(power.output_item_id)).is_equal("tier4_power_component")

	var outputs: Array[String] = [
		String(foundation.output_item_id), String(weapon.output_item_id), String(power.output_item_id),
	]
	assert_int(outputs.size()).is_equal(3)
	var unique: Dictionary = {}
	for o: String in outputs:
		unique[o] = true
	assert_int(unique.size()).is_equal(3)
