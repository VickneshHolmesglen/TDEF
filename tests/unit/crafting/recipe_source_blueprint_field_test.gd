## Unit tests for RecipeResource.source_blueprint_tower_id (2026-08-17, Tower
## Components blueprint-sourced recipes). Exercises the real,
## authored res://assets/data/towers/blueprints/ and res://assets/data/recipes/
## content via the GGameDataRegistry Autoload — same rationale as
## recipe_data_model_test.gd.
extends GdUnitTestSuite


func _make_valid_tower_component_recipe() -> RecipeResource:
	var res := RecipeResource.new()
	res.recipe_id = &"test_recipe"
	res.recipe_category = "tower_component"
	res.component_slot = "foundation"
	res.inputs = {&"Material": 5}
	res.tech_prerequisite = &""
	res.output_item_id = &"iron_foundation_component"
	res.output_quantity = 1
	res.quality_tier = 1
	return res


func test_source_blueprint_tower_id_empty_is_valid() -> void:
	var res: RecipeResource = _make_valid_tower_component_recipe()
	res.source_blueprint_tower_id = &""
	assert_array(res.validate()).is_empty()


func test_source_blueprint_tower_id_valid_known_tower_is_valid() -> void:
	var res: RecipeResource = _make_valid_tower_component_recipe()
	res.source_blueprint_tower_id = &"archer"
	assert_array(res.validate()).is_empty()


func test_source_blueprint_tower_id_unknown_tower_returns_error() -> void:
	var res: RecipeResource = _make_valid_tower_component_recipe()
	res.source_blueprint_tower_id = &"not_a_real_tower"
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("source_blueprint_tower_id references unknown tower_id"))).is_true()


func test_source_blueprint_tower_id_forbidden_on_crafted_good() -> void:
	var res := RecipeResource.new()
	res.recipe_id = &"test_crafted_good"
	res.recipe_category = "crafted_good"
	res.component_slot = ""
	res.inputs = {&"Material": 3}
	res.output_item_id = &"healing_salve"
	res.output_quantity = 3
	res.quality_tier = 0
	res.source_blueprint_tower_id = &"archer"
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("source_blueprint_tower_id must be empty"))).is_true()


## The real Archer recipes authored alongside this feature must themselves
## validate cleanly — a live check against the actual shipped content, not
## just synthetic fixtures.
func test_real_archer_component_recipes_validate_with_no_errors() -> void:
	for recipe_id: StringName in [&"recipe_archer_foundation", &"recipe_archer_weapon", &"recipe_archer_focus", &"recipe_archer_power"]:
		var recipe: RecipeResource = GGameDataRegistry.get_recipe(recipe_id)
		assert_object(recipe).is_not_null()
		assert_array(recipe.validate()).is_empty()
		assert_that(recipe.source_blueprint_tower_id).is_equal(&"archer")
