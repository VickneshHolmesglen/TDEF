## Unit tests for Story 006 (TR-craft-001, Formulas 1-3; ADR-0023): Tower
## Component tier scaling (AC-8), Crafted Goods authored content (AC-10).
##
## Exercises the real, authored res://assets/data/recipes/ content via the
## GGameDataRegistry Autoload. Formula 1/3 numbers are content-authored
## directly into RecipeResource fields (mirroring Defense Building Story
## 025's precedent) — these tests validate the AUTHORED values match the
## formula's expected output, not a separate runtime formula function.
##
## TD-craft-001 note: recipe_tier4_component's inputs use rarity keys
## (Common/Uncommon/Rare), which RecipeResource.validate() now accepts
## alongside item_type keys (see recipe_resource.gd's VALID_RARITIES doc
## comment) — content-accurate to Formula 1, but not yet has_items()-
## compatible (a genuine, tracked, open gap). These tests validate the DATA
## only; they do not exercise craftability for this specific recipe.
extends GdUnitTestSuite

const RECIPE_TIER4_COMPONENT: StringName = &"recipe_tier4_component"
const RECIPE_HEALING_SALVE_BULK: StringName = &"recipe_healing_salve_bulk"


# ---------------------------------------------------------------------------
# AC-8: Formula 1 — Tier 4 tower_component cost matches
# round(base_qty[rarity] × tier_dps_multiplier(4)=4.0) exactly.
# ---------------------------------------------------------------------------

func test_tier4_component_costs_32_common_16_uncommon_8_rare() -> void:
	var recipe: RecipeResource = GGameDataRegistry.get_recipe(RECIPE_TIER4_COMPONENT)
	assert_object(recipe).is_not_null()
	assert_int(recipe.quality_tier).is_equal(4)
	assert_int(recipe.inputs[&"Common"] as int).is_equal(32)
	assert_int(recipe.inputs[&"Uncommon"] as int).is_equal(16)
	assert_int(recipe.inputs[&"Rare"] as int).is_equal(8)


# ---------------------------------------------------------------------------
# AC-10: Formula 2 (crafted_good) is hand-authored, not derived — exact
# match to the recipe's own authored content, quality_tier always 0.
# ---------------------------------------------------------------------------

func test_healing_salve_bulk_costs_6_common_produces_3_quality_tier_zero() -> void:
	var recipe: RecipeResource = GGameDataRegistry.get_recipe(RECIPE_HEALING_SALVE_BULK)
	assert_object(recipe).is_not_null()
	assert_int(recipe.inputs[&"Common"] as int).is_equal(6)
	assert_int(recipe.output_quantity).is_equal(3)
	assert_int(recipe.quality_tier).is_equal(0)
