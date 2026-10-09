## Unit tests for Story 010 (TR-equipforge-001, ADR-0025): Equipment Crafting
## Resolution (AC-8/9/10) and Formula 1's material cost worked example (AC-11).
##
## Exercises the real, authored res://assets/data/equipment_recipes/ and
## res://assets/data/items/ content via the GGameDataRegistry Autoload.
## EquipmentForge is instantiated directly (EquipmentForge.new(), no
## add_child()). GInventory IS the real global Autoload (Criterion A) —
## reset in before_test()/after_test().
extends GdUnitTestSuite

const RECIPE_IRON_SWORD: StringName = &"recipe_iron_sword"                 # ungated, weapon, needs 4 Material
const RECIPE_STEEL_GREATSWORD: StringName = &"recipe_steel_greatsword"     # ungated, weapon T2, needs 13 Common + 6 Uncommon

var _forge: EquipmentForge
var _spy: EventBusSpy


func before_test() -> void:
	_forge = EquipmentForge.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_equipment_crafted)
	GInventory.reset_to_defaults()


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _forge != null and is_instance_valid(_forge):
		_forge.free()
	_forge = null
	GInventory.reset_to_defaults()


func _seed_material(quantity: int) -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"common_scrap")
	GInventory.add_stackable(def, quantity)


func _discover(recipe_id: StringName) -> void:
	_forge._equipment_discovery_ledger[recipe_id] = true


# ---------------------------------------------------------------------------
# AC-8: stale-UI insufficient-materials re-validation rejects cleanly
# ---------------------------------------------------------------------------

func test_resolve_craft_rejects_when_materials_insufficient() -> void:
	_discover(RECIPE_IRON_SWORD)
	_seed_material(2)  # needs 4

	var result: bool = _forge.resolve_craft(RECIPE_IRON_SWORD)

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("hero_equipment_crafted")).is_false()
	# Zero consumption — the 2 seeded materials are untouched.
	assert_bool(GInventory.has_items({&"Material": 2})).is_true()


func test_resolve_craft_rejects_undiscovered_recipe() -> void:
	_seed_material(4)
	var result: bool = _forge.resolve_craft(RECIPE_IRON_SWORD)  # never discovered
	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("hero_equipment_crafted")).is_false()


# ---------------------------------------------------------------------------
# AC-9: no-room pre-check rejects before any material is consumed
# ---------------------------------------------------------------------------

## Player-requested 2026-08-16: STARTING_SLOT_COUNT raised 14 -> 18
## (discretionary slots 4 -> 8) after a live playthrough found the old
## floor-exact capacity insufficient — this test's own "fill every
## discretionary slot" setup grows to match (1 slot from the seeded
## material + 7 filler items = 8).
##
## Seeds 5 against a cost of 4 so the stack survives consumption -- a stack
## the cost would fully empty frees its slot and counts as room (AC-9
## amended 2026-10-10, see the test below).
func test_resolve_craft_rejects_when_no_room_zero_consumption() -> void:
	_discover(RECIPE_IRON_SWORD)
	_seed_material(5)
	# Fill all 8 discretionary slots (1 used by the seeded material above, 7
	# more here) so no room remains for the crafted item.
	for i: int in 7:
		var filler := ItemDefinitionResource.new()
		filler.item_id = StringName("filler_%d" % i)
		filler.item_type = &"Equipment"
		filler.display_name = "Filler"
		filler.is_unique_instance = true
		GInventory.add_unique_item(filler)

	var result: bool = _forge.resolve_craft(RECIPE_IRON_SWORD)

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("hero_equipment_crafted")).is_false()
	# Materials untouched — step (b) rejects before step (c) ever runs.
	assert_bool(GInventory.has_items({&"Material": 5})).is_true()


func test_resolve_craft_succeeds_when_cost_frees_the_only_slot() -> void:
	_discover(RECIPE_IRON_SWORD)
	_seed_material(4)  # exactly the cost -- consuming it empties this slot
	for i: int in 7:
		var filler := ItemDefinitionResource.new()
		filler.item_id = StringName("filler_%d" % i)
		filler.item_type = &"Equipment"
		filler.display_name = "Filler"
		filler.is_unique_instance = true
		GInventory.add_unique_item(filler)
	assert_bool(GInventory.has_room_for("weapon", 1)).is_false()

	var result: bool = _forge.resolve_craft(RECIPE_IRON_SWORD)

	assert_bool(result).is_true()
	assert_bool(_spy.was_emitted("hero_equipment_crafted")).is_true()
	assert_bool(GInventory.has_items({&"Material": 1})).is_false()


# ---------------------------------------------------------------------------
# AC-10: successful craft, synchronous, item added with free rune slots
# ---------------------------------------------------------------------------

func test_resolve_craft_success_consumes_materials_and_emits_event() -> void:
	_discover(RECIPE_IRON_SWORD)
	_seed_material(4)

	var result: bool = _forge.resolve_craft(RECIPE_IRON_SWORD)

	assert_bool(result).is_true()
	assert_bool(GInventory.has_items({&"Material": 4})).is_false()  # consumed
	assert_int(_spy.count("hero_equipment_crafted")).is_equal(1)
	var args: Array = (_spy.emissions["hero_equipment_crafted"] as Array)[0]
	assert_str(args[0] as String).is_equal("iron_sword")
	assert_str(args[1] as String).is_equal("weapon")  # item_type = output_slot
	assert_int(args[2] as int).is_equal(1)  # quality_tier


func test_resolve_craft_success_places_item_with_free_rune_slots() -> void:
	_discover(RECIPE_IRON_SWORD)
	_seed_material(4)

	_forge.resolve_craft(RECIPE_IRON_SWORD)

	var contents: Dictionary = GInventory.get_slot_contents(0)
	assert_str(contents["item_id"] as String).is_equal("iron_sword")
	assert_int(contents["rune_slot_count"] as int).is_equal(2)  # weapon slot table
	assert_array(contents["imbued_runes"] as Array).is_empty()  # all free


func test_resolve_craft_rejects_second_confirmation_while_resolving() -> void:
	_discover(RECIPE_IRON_SWORD)
	_seed_material(8)  # enough for 2 crafts
	_forge._forge_resolving = true  # simulate an in-flight resolution (Story 015: shared guard, renamed from _craft_resolving)

	var result: bool = _forge.resolve_craft(RECIPE_IRON_SWORD)

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("hero_equipment_crafted")).is_false()


# ---------------------------------------------------------------------------
# AC-11: Formula 1 worked example — Tier-2 weapon-slot recipe
# ---------------------------------------------------------------------------

func test_formula_1_tier_2_weapon_worked_example() -> void:
	assert_int(EquipmentForge.material_qty("Common", 2)).is_equal(13)
	assert_int(EquipmentForge.material_qty("Uncommon", 2)).is_equal(6)
	assert_int(EquipmentForge.material_qty("Rare", 2)).is_equal(3)  # raw formula value; recipe simply omits Rare at T2


func test_formula_1_full_tier_table() -> void:
	assert_int(EquipmentForge.material_qty("Common", 1)).is_equal(8)
	assert_int(EquipmentForge.material_qty("Common", 3)).is_equal(19)
	assert_int(EquipmentForge.material_qty("Uncommon", 3)).is_equal(10)
	assert_int(EquipmentForge.material_qty("Common", 4)).is_equal(32)
	assert_int(EquipmentForge.material_qty("Uncommon", 4)).is_equal(16)
	assert_int(EquipmentForge.material_qty("Rare", 4)).is_equal(8)


func test_recipe_steel_greatsword_matches_formula_1_worked_example() -> void:
	var recipe: EquipmentRecipeResource = GGameDataRegistry.get_equipment_recipe(RECIPE_STEEL_GREATSWORD)
	assert_object(recipe).is_not_null()
	assert_int(recipe.inputs[&"Common"]).is_equal(13)
	assert_int(recipe.inputs[&"Uncommon"]).is_equal(6)
	assert_bool(recipe.inputs.has(&"Rare")).is_false()  # 0 Rare at T2, omitted from inputs
