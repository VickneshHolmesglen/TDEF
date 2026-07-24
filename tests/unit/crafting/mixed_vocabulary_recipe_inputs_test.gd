## Unit tests for Crafting._has_recipe_inputs()/_consume_recipe_inputs()
## (TD-craft-001 RESOLVED, Sprint 6 S6-06b): a recipe's `inputs` Dictionary
## may mix item_type keys (has_items()/consume_by_type()) and rarity keys
## (has_items_by_rarity()/consume_by_rarity()) in the SAME Dictionary — see
## crafting.gd's _has_recipe_inputs() doc comment. No currently-authored
## res://assets/data/recipes/*.tres content actually mixes both vocabularies
## in one recipe (recipe_iron_foundation/recipe_healing_salve are pure
## item_type; recipe_tier4_component is pure rarity) — RecipeResource.
## validate() permits it, so this exercises the split logic directly against
## a synthetic mixed inputs Dictionary, matching this project's established
## convention of testing Crafting's underscore-prefixed methods directly
## (see recipe_discovery_state_machine_test.gd's _on_tech_unlocked()/
## _on_item_added() calls).
##
## Seeds the REAL GInventory Autoload with genuinely registered items:
## menagerie_lure (item_type=Material, rarity="" — satisfies the item_type
## half without ALSO counting toward any rarity total) and common_scrap
## (item_type=Material, rarity=Common — satisfies the rarity half). Using two
## items that don't share both axes avoids a separate, out-of-scope edge case
## (a single item counted toward both an item_type total AND a rarity total
## from the same recipe, which no real content does today — has_items()/
## has_items_by_rarity() are independent sums, so consumption ordering
## between overlapping halves is not this fix's concern).
##
## has_items()/has_items_by_rarity() resolve a slot's item_type/rarity via
## GGameDataRegistry.get_item_definition(), never from an ad hoc
## ItemDefinitionResource object — a fabricated item_id would silently never
## count (a real bug found and fixed this same pass — see
## currency_dual_gate_test.gd's class doc comment).
extends GdUnitTestSuite

var _crafting: Crafting


func before_test() -> void:
	_crafting = Crafting.new()
	GInventory.reset_to_defaults()


func after_test() -> void:
	if _crafting != null and is_instance_valid(_crafting):
		_crafting.free()
	_crafting = null
	GInventory.reset_to_defaults()


func test_has_recipe_inputs_true_when_both_item_type_and_rarity_halves_satisfied() -> void:
	var lure_def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"menagerie_lure")
	var common_def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"common_scrap")
	GInventory.add_stackable(lure_def, 5)    # item_type=Material, rarity=""
	GInventory.add_stackable(common_def, 8)  # rarity=Common

	var mixed_inputs: Dictionary = {&"Material": 5, &"Common": 8}
	assert_bool(_crafting._has_recipe_inputs(mixed_inputs)).is_true()


func test_has_recipe_inputs_false_when_rarity_half_insufficient() -> void:
	var lure_def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"menagerie_lure")
	var common_def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"common_scrap")
	GInventory.add_stackable(lure_def, 5)
	GInventory.add_stackable(common_def, 7)  # one short of the 8 required below

	var mixed_inputs: Dictionary = {&"Material": 5, &"Common": 8}
	assert_bool(_crafting._has_recipe_inputs(mixed_inputs)).is_false()


func test_has_recipe_inputs_false_when_item_type_half_insufficient() -> void:
	# common_scrap is ALSO item_type=Material (it participates in both axes),
	# so the Material requirement must exceed lure+common_scrap COMBINED to
	# isolate a genuine item_type-half failure — 20 exceeds 1+8=9, while
	# Common:8 stays exactly satisfied by common_scrap alone.
	var lure_def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"menagerie_lure")
	var common_def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"common_scrap")
	GInventory.add_stackable(lure_def, 1)
	GInventory.add_stackable(common_def, 8)

	var mixed_inputs: Dictionary = {&"Material": 20, &"Common": 8}
	assert_bool(_crafting._has_recipe_inputs(mixed_inputs)).is_false()


func test_consume_recipe_inputs_deducts_both_halves_correctly() -> void:
	var lure_def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"menagerie_lure")
	var common_def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"common_scrap")
	GInventory.add_stackable(lure_def, 5)
	GInventory.add_stackable(common_def, 10)

	_crafting._consume_recipe_inputs({&"Material": 5, &"Common": 8})

	# The Material:5 request is drawn from lure first (slot order), fully
	# depleting its 5 units — but common_scrap's own 2 leftover units are
	# ALSO item_type=Material (it participates in both axes), so the
	# remaining Material total is common_scrap's leftover, not zero.
	assert_bool(GInventory.has_items({&"Material": 3})).is_false()          # only common_scrap's leftover 2 remain
	assert_bool(GInventory.has_items({&"Material": 2})).is_true()
	assert_bool(GInventory.has_items_by_rarity({&"Common": 3})).is_false()  # 8 of 10 Common consumed
	assert_bool(GInventory.has_items_by_rarity({&"Common": 2})).is_true()   # 2 Common remain
