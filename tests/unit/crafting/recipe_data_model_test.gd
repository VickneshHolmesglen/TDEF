## Unit tests for Story 001 (TR-craft-001, ADR-0023): RecipeResource schema
## and GameDataRegistry's loading/validation of it.
##
## Exercises the real, authored res://assets/data/recipes/ content via the
## GGameDataRegistry Autoload (no fixture injection) — same rationale as
## every other GameDataRegistry-backed test in this project. Two recipes are
## authored for this story: recipe_iron_foundation (tower_component) and
## recipe_healing_salve (crafted_good) — deliberately covering both
## categories' distinct validation rules (component_slot required vs.
## forbidden, output_quantity/quality_tier ranges).
##
## TD-craft-001: RecipeResource.inputs is keyed by item_type (Equipment/
## TowerComponent/Material/CraftedGood), NOT material_id, despite
## ADR-0023's own comment saying "material_id -> quantity" — that comment
## doesn't match Inventory.has_items()'s actual, already-shipped contract
## (inventory.md: "every item_type key in cost"). Fixed at authoring time,
## before it propagated past Story 001/002 — see the tech-debt register.
extends GdUnitTestSuite

const RECIPE_IRON_FOUNDATION: StringName = &"recipe_iron_foundation"
const RECIPE_HEALING_SALVE: StringName = &"recipe_healing_salve"


# ---------------------------------------------------------------------------
# RecipeResource.validate()
# ---------------------------------------------------------------------------

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


func test_recipe_validate_fully_valid_tower_component_returns_empty_array() -> void:
	assert_array(_make_valid_tower_component_recipe().validate()).is_empty()


func test_recipe_validate_empty_recipe_id_returns_error() -> void:
	var res: RecipeResource = _make_valid_tower_component_recipe()
	res.recipe_id = &""
	assert_array(res.validate()).contains("recipe_id must not be empty")


func test_recipe_validate_tower_component_requires_valid_component_slot() -> void:
	var res: RecipeResource = _make_valid_tower_component_recipe()
	res.component_slot = "not_a_real_slot"
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("component_slot must be one of"))).is_true()


func test_recipe_validate_crafted_good_forbids_component_slot() -> void:
	var res := RecipeResource.new()
	res.recipe_id = &"test_crafted_good"
	res.recipe_category = "crafted_good"
	res.component_slot = "foundation"  # invalid — must be empty for crafted_good
	res.inputs = {&"Material": 3}
	res.output_item_id = &"healing_salve"
	res.output_quantity = 3
	res.quality_tier = 0
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("component_slot must be empty"))).is_true()


func test_recipe_validate_inputs_below_range_returns_error() -> void:
	var res: RecipeResource = _make_valid_tower_component_recipe()
	res.inputs = {}
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("inputs must have 1-3 entries"))).is_true()


func test_recipe_validate_inputs_above_range_returns_error() -> void:
	var res: RecipeResource = _make_valid_tower_component_recipe()
	res.inputs = {&"Equipment": 1, &"TowerComponent": 1, &"Material": 1, &"CraftedGood": 1}
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("inputs must have 1-3 entries"))).is_true()


func test_recipe_validate_invalid_item_type_in_inputs_returns_error() -> void:
	var res: RecipeResource = _make_valid_tower_component_recipe()
	res.inputs = {&"NotARealItemType": 5}
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("inputs key") and e.contains("not a valid item_type"))).is_true()


func test_recipe_validate_unknown_output_item_id_returns_error() -> void:
	var res: RecipeResource = _make_valid_tower_component_recipe()
	res.output_item_id = &"item_does_not_exist"
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("output_item_id references unknown item_id"))).is_true()


func test_recipe_validate_tower_component_output_quantity_must_be_one() -> void:
	var res: RecipeResource = _make_valid_tower_component_recipe()
	res.output_quantity = 2
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("output_quantity must be exactly 1"))).is_true()


func test_recipe_validate_tower_component_quality_tier_out_of_range_returns_error() -> void:
	var res: RecipeResource = _make_valid_tower_component_recipe()
	res.quality_tier = 0
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("quality_tier must be 1-4"))).is_true()


func test_recipe_validate_crafted_good_quality_tier_must_be_zero() -> void:
	var res := RecipeResource.new()
	res.recipe_id = &"test_crafted_good_2"
	res.recipe_category = "crafted_good"
	res.inputs = {&"Material": 3}
	res.output_item_id = &"healing_salve"
	res.output_quantity = 3
	res.quality_tier = 1
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("quality_tier must be 0"))).is_true()


# ---------------------------------------------------------------------------
# GameDataRegistry: RecipeResource loading (AC-1 — real authored content)
# ---------------------------------------------------------------------------

func test_get_recipe_iron_foundation_has_correct_fields() -> void:
	var recipe: RecipeResource = GGameDataRegistry.get_recipe(RECIPE_IRON_FOUNDATION)
	assert_object(recipe).is_not_null()
	assert_str(recipe.recipe_category).is_equal("tower_component")
	assert_str(recipe.component_slot).is_equal("foundation")
	assert_int(recipe.inputs[&"Material"] as int).is_equal(5)
	assert_that(recipe.output_item_id).is_equal(&"iron_foundation_component")
	assert_int(recipe.output_quantity).is_equal(1)
	assert_int(recipe.quality_tier).is_equal(1)


func test_get_recipe_healing_salve_has_correct_fields() -> void:
	var recipe: RecipeResource = GGameDataRegistry.get_recipe(RECIPE_HEALING_SALVE)
	assert_object(recipe).is_not_null()
	assert_str(recipe.recipe_category).is_equal("crafted_good")
	assert_str(recipe.component_slot).is_equal("")
	assert_int(recipe.inputs[&"Material"] as int).is_equal(3)
	assert_that(recipe.output_item_id).is_equal(&"healing_salve")
	assert_int(recipe.output_quantity).is_equal(3)
	assert_int(recipe.quality_tier).is_equal(0)


func test_get_recipe_unknown_id_returns_null() -> void:
	assert_object(GGameDataRegistry.get_recipe(&"recipe_does_not_exist")).is_null()


func test_get_all_recipes_returns_isolated_copy() -> void:
	var all_recipes: Dictionary[StringName, RecipeResource] = GGameDataRegistry.get_all_recipes()
	var original_size: int = all_recipes.size()
	all_recipes[&"injected_after_the_fact"] = RecipeResource.new()
	assert_int(GGameDataRegistry.get_all_recipes().size()).is_equal(original_size)
