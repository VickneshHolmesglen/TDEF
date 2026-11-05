## Unit tests for Story 009 (TR-equipforge-001, ADR-0025): EquipmentRecipeResource
## field completeness (AC-4/AC-5) and the Equipment Recipe Discovery/Craftability
## state machine (AC-6/AC-7) — mirrors Crafting's own discovery pattern
## verbatim (tests/unit/crafting/recipe_discovery_state_machine_test.gd) for
## recipe_category="hero_equipment".
##
## Exercises the real, authored res://assets/data/equipment_recipes/ and
## res://assets/data/items/ content via the GGameDataRegistry Autoload — no
## fixture injection. EquipmentForge is instantiated directly
## (EquipmentForge.new(), no add_child()) so _ready() never fires. GInventory
## and GDefenseBuilding ARE the real global Autoloads (Criterion A/B) —
## reset in before_test()/after_test() to avoid leaking state into other tests.
extends GdUnitTestSuite

const RECIPE_IRON_SWORD: StringName = &"recipe_iron_sword"                    # ungated, weapon, costs Material
const RECIPE_LUCKY_CHARM: StringName = &"recipe_lucky_charm_trinket"          # ungated, trinket, costs Material
const RECIPE_REINFORCED_PLATE: StringName = &"recipe_reinforced_plate"        # gated on tech_production_2, armor, costs Common + Uncommon
const TECH_PRODUCTION_2: StringName = &"tech_production_2"

var _forge: EquipmentForge
var _spy: EventBusSpy


## Forge actions cost Sanctuary gold (SanctuaryGold); fund the autoload, restore after.
var _saved_sanctuary_gold: int = 0


func before_test() -> void:
	_saved_sanctuary_gold = GSanctuaryGold.get_balance()
	GSanctuaryGold._balance = 100000
	_forge = EquipmentForge.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.recipe_discovered)
	GInventory.reset_to_defaults()


func after_test() -> void:
	GSanctuaryGold._balance = _saved_sanctuary_gold
	_spy.disconnect_all()
	_spy = null
	if _forge != null and is_instance_valid(_forge):
		_forge.free()
	_forge = null
	GInventory.reset_to_defaults()


func _seed_material(quantity: int) -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"common_scrap")
	GInventory.add_stackable(def, quantity)


## Seeds exactly `recipe_id`'s authored inputs (2026-11-02 shop-spread pass):
## Material/Common keys as common_scrap (Common, Material), Uncommon and
## iron_ore keys as iron_ore (Uncommon, Material). Tests seed from the recipe
## instead of a hardcoded number so a re-price does not break them.
func _seed_recipe_inputs(recipe_id: StringName) -> void:
	var recipe: EquipmentRecipeResource = GGameDataRegistry.get_equipment_recipe(recipe_id)
	for key: StringName in recipe.inputs:
		var item_id: StringName = &"iron_ore" if key in [&"Uncommon", &"iron_ore"] else &"common_scrap"
		GInventory.add_stackable(GGameDataRegistry.get_item_definition(item_id), recipe.inputs[key] as int)


## The recipe's single "Material" cost (starter recipes cost only Material).
func _material_cost(recipe_id: StringName) -> int:
	return GGameDataRegistry.get_equipment_recipe(recipe_id).inputs[&"Material"] as int


# ---------------------------------------------------------------------------
# AC-4: all 7 fields present and typed as specified
# ---------------------------------------------------------------------------

func test_equipment_recipe_has_all_7_fields_correctly_typed() -> void:
	var recipe: EquipmentRecipeResource = GGameDataRegistry.get_equipment_recipe(RECIPE_IRON_SWORD)
	assert_object(recipe).is_not_null()
	assert_str(String(recipe.recipe_id)).is_equal("recipe_iron_sword")
	assert_str(recipe.recipe_category).is_equal("hero_equipment")
	assert_str(recipe.output_slot).is_equal("weapon")
	assert_bool(recipe.inputs is Dictionary).is_true()
	assert_str(String(recipe.tech_prerequisite)).is_equal("")
	assert_str(String(recipe.output_item_id)).is_equal("iron_sword")
	assert_int(recipe.quality_tier).is_between(1, 4)
	assert_array(recipe.validate()).is_empty()


func test_rune_slot_count_derived_from_output_slot_table() -> void:
	var weapon: EquipmentRecipeResource = GGameDataRegistry.get_equipment_recipe(RECIPE_IRON_SWORD)
	assert_int(weapon.rune_slot_count).is_equal(2)
	var armor: EquipmentRecipeResource = GGameDataRegistry.get_equipment_recipe(RECIPE_REINFORCED_PLATE)
	assert_int(armor.rune_slot_count).is_equal(2)
	var trinket: EquipmentRecipeResource = GGameDataRegistry.get_equipment_recipe(RECIPE_LUCKY_CHARM)
	assert_int(trinket.rune_slot_count).is_equal(1)


func test_validate_rejects_mismatched_rune_slot_count() -> void:
	var recipe := EquipmentRecipeResource.new()
	recipe.recipe_id = &"bad_recipe"
	recipe.output_slot = "weapon"
	recipe.inputs = {&"Material": 1}
	recipe.output_item_id = &"bad_item"
	recipe.rune_slot_count = 1  # weapon requires 2 — mismatch

	assert_bool(recipe.validate().is_empty()).is_false()


# ---------------------------------------------------------------------------
# AC-5: quality_tier is a fixed author-set integer in 1-4, never computed
# ---------------------------------------------------------------------------

func test_quality_tier_is_fixed_author_set_value() -> void:
	var recipe: EquipmentRecipeResource = GGameDataRegistry.get_equipment_recipe(RECIPE_REINFORCED_PLATE)
	assert_int(recipe.quality_tier).is_equal(2)
	# Reading it twice returns the identical value — nothing recomputes it.
	assert_int(recipe.quality_tier).is_equal(2)


# ---------------------------------------------------------------------------
# AC-6: two-gate discovery, permanent
# ---------------------------------------------------------------------------

## Seeded quantity deliberately capped at 6 (reinforced_plate's own threshold)
## rather than checking a global "zero discoveries" count — recipe_iron_sword
## (4) and recipe_lucky_charm_trinket (3) are both ungated, so 6 material
## legitimately (and correctly) discovers them too; this test isolates the
## claim under test (the tech-gated recipe specifically) rather than
## asserting a blanket zero-emissions count, mirroring Crafting's own
## discovery test's documented seed-calibration caution.
func test_item_added_does_not_discover_tech_gated_recipe_before_tech_unlocked() -> void:
	_seed_material(6)
	_forge._on_item_added("common_scrap", "Material", 6)

	assert_bool(_forge.is_discovered(RECIPE_REINFORCED_PLATE)).is_false()
	for emission: Array in (_spy.emissions.get("recipe_discovered", []) as Array):
		assert_str(emission[0] as String).is_not_equal(String(RECIPE_REINFORCED_PLATE))


## Re-derived 2026-11-02 (shop-spread re-price): seeding exactly
## reinforced_plate's inputs (140 Common + 13 Uncommon) then unlocking
## tech_production_2 sweeps only the recipes gated on that tech and discovers
## the 6 whose inputs fit: the pieces priced at or below reinforced_plate.
## Steel greatsword, iron_band, silver_pendant and Steelwrought cost more and
## stay undiscovered. Listing the full set keeps a new qualifying recipe loud.
func test_tech_unlocked_discovers_recipe_once_materials_already_sufficient() -> void:
	_seed_recipe_inputs(RECIPE_REINFORCED_PLATE)
	_forge._on_tech_unlocked(String(TECH_PRODUCTION_2), "production_tech")

	assert_bool(_forge.is_discovered(RECIPE_REINFORCED_PLATE)).is_true()
	var emissions: Array = _spy.emissions["recipe_discovered"] as Array
	var discovered_ids: Array = []
	var category_by_id: Dictionary = {}
	for emission: Array in emissions:
		var id: String = emission[0] as String
		discovered_ids.append(id)
		category_by_id[id] = emission[1] as String
	var expected_ids: Array[String] = [
		"recipe_reinforced_helm", "recipe_reinforced_boots", "recipe_reinforced_gauntlets",
		"recipe_iron_greaves", "recipe_iron_buckler", "recipe_reinforced_plate",
	]
	for expected_id: String in expected_ids:
		assert_bool(discovered_ids.has(expected_id)).append_failure_message(
			"expected recipe '%s' to be discovered in this scenario, but it wasn't" % expected_id
		).is_true()
	assert_int(discovered_ids.size()).is_equal(expected_ids.size())
	assert_str(category_by_id[String(RECIPE_REINFORCED_PLATE)] as String).is_equal("hero_equipment")


func test_item_added_discovers_ungated_recipe_directly() -> void:
	_seed_material(_material_cost(RECIPE_IRON_SWORD))
	_forge._on_item_added("common_scrap", "Material", _material_cost(RECIPE_IRON_SWORD))

	assert_bool(_forge.is_discovered(RECIPE_IRON_SWORD)).is_true()
	var iron_sword_emissions: int = 0
	for emission: Array in (_spy.emissions.get("recipe_discovered", []) as Array):
		if (emission[0] as String) == String(RECIPE_IRON_SWORD):
			iron_sword_emissions += 1
	assert_int(iron_sword_emissions).is_equal(1)


func test_discovery_is_permanent_despite_later_material_gate_loss() -> void:
	_seed_material(_material_cost(RECIPE_IRON_SWORD))
	_forge._on_item_added("common_scrap", "Material", _material_cost(RECIPE_IRON_SWORD))
	assert_bool(_forge.is_discovered(RECIPE_IRON_SWORD)).is_true()

	# Material stock drops back to 0 (simulated) — discovery must not revert.
	GInventory.reset_to_defaults()

	assert_bool(_forge.is_discovered(RECIPE_IRON_SWORD)).is_true()


func test_recipe_discovered_fires_exactly_once_across_two_crossings() -> void:
	GDefenseBuilding._tech_ledger[TECH_PRODUCTION_2] = true
	_seed_recipe_inputs(RECIPE_REINFORCED_PLATE)
	_forge._on_item_added("common_scrap", "Material", 1)
	_forge._on_item_added("common_scrap", "Material", 1)  # second crossing, already discovered

	var reinforced_plate_emissions: int = 0
	for emission: Array in (_spy.emissions.get("recipe_discovered", []) as Array):
		if (emission[0] as String) == String(RECIPE_REINFORCED_PLATE):
			reinforced_plate_emissions += 1
	assert_int(reinforced_plate_emissions).is_equal(1)
	GDefenseBuilding._tech_ledger.erase(TECH_PRODUCTION_2)


# ---------------------------------------------------------------------------
# AC-7: craftability flag flips independently of the one-time discovery event
# ---------------------------------------------------------------------------

func test_craftability_flips_true_on_item_added_alone_after_discovery() -> void:
	var cost: int = _material_cost(RECIPE_IRON_SWORD)
	_seed_material(cost)
	_forge._on_item_added("common_scrap", "Material", cost)
	assert_bool(_forge.is_discovered(RECIPE_IRON_SWORD)).is_true()
	assert_bool(_forge.is_craftable(RECIPE_IRON_SWORD)).is_true()

	# Consume materials back below threshold — still discovered, no longer craftable.
	GInventory.consume_by_type("Material", cost)
	assert_bool(_forge.is_discovered(RECIPE_IRON_SWORD)).is_true()
	assert_bool(_forge.is_craftable(RECIPE_IRON_SWORD)).is_false()

	# Re-add materials — craftability flips back true, no new recipe_discovered.
	_spy.clear()
	_seed_material(cost)
	assert_bool(_forge.is_craftable(RECIPE_IRON_SWORD)).is_true()
	assert_int(_spy.count("recipe_discovered")).is_equal(0)


func test_undiscovered_recipe_is_never_craftable_regardless_of_materials() -> void:
	_seed_recipe_inputs(RECIPE_REINFORCED_PLATE)  # would satisfy its inputs
	assert_bool(_forge.is_craftable(RECIPE_REINFORCED_PLATE)).is_false()


# ---------------------------------------------------------------------------
# 2026-11-02: specific-material cost axis + next-locked query
# ---------------------------------------------------------------------------

## Regression: recipes costed in a specific material (here iron_plating) used
## to be checked as an item_type and could never be discovered or crafted.
func test_forge_material_id_recipe_discovers_and_crafts() -> void:
	# Arrange: brute_gauntlets is gated on tech_production_3 and costs iron_plating + Uncommon
	var recipe: EquipmentRecipeResource = GGameDataRegistry.get_equipment_recipe(&"recipe_brute_gauntlets")
	GDefenseBuilding._tech_ledger[recipe.tech_prerequisite] = true
	for key: StringName in recipe.inputs:
		var item_id: StringName = &"iron_ore" if key == &"Uncommon" else key
		GInventory.add_stackable(GGameDataRegistry.get_item_definition(item_id), recipe.inputs[key] as int)
	# Act
	_forge._on_item_added("iron_plating", "Material", 1)
	var crafted: bool = _forge.resolve_craft(recipe.recipe_id)
	# Assert
	assert_bool(_forge.is_discovered(recipe.recipe_id)).is_true()
	assert_bool(crafted).is_true()
	assert_int(GInventory.count_by_material_id(&"iron_plating")).is_equal(0)
	GDefenseBuilding._tech_ledger.erase(recipe.tech_prerequisite)


func test_forge_next_locked_recipes_put_open_gates_and_cheapest_first() -> void:
	# Act
	var locked: Array[EquipmentRecipeResource] = _forge.get_next_locked_recipes(3)
	# Assert: with no tech researched, the 3 cheapest ungated starter recipes lead
	assert_int(locked.size()).is_equal(3)
	assert_str(String(locked[0].recipe_id)).is_equal(String(RECIPE_IRON_SWORD))
	for recipe: EquipmentRecipeResource in locked:
		assert_bool(_forge.is_tech_gate_open(recipe)).is_true()
	assert_int(EquipmentForge.total_input_quantity(locked[0])).is_less_equal(EquipmentForge.total_input_quantity(locked[2]))


func test_forge_input_progress_caps_have_at_need() -> void:
	_seed_material(500)
	var progress: Array[Dictionary] = EquipmentForge.get_input_progress(GGameDataRegistry.get_equipment_recipe(RECIPE_IRON_SWORD))
	assert_int(progress[0]["have"] as int).is_equal(progress[0]["need"] as int)


## Regression (2026-11-02 Forge live check): a loaded save with NO
## "equipment_forge" key restores the Forge through reset_to_defaults(), which
## never ran the boot sweep, so an affordable recipe stayed locked ("Iron Sword
## 20/20 Material") until the next item_added. _ready() now re-sweeps whenever
## a save is loaded. Seeding happens before the Forge enters the tree, so only
## the sweep can discover it.
func test_registering_after_a_load_without_forge_data_sweeps_affordable_recipes() -> void:
	var had_loaded: bool = GSavePersistence._has_loaded_data
	var last_loaded: Dictionary = GSavePersistence._last_loaded_data
	GSavePersistence._has_loaded_data = true
	GSavePersistence._last_loaded_data = {}
	_seed_material(_material_cost(RECIPE_IRON_SWORD))

	add_child(_forge)

	assert_bool(_forge.is_discovered(RECIPE_IRON_SWORD)).is_true()
	GSavePersistence._has_loaded_data = had_loaded
	GSavePersistence._last_loaded_data = last_loaded
