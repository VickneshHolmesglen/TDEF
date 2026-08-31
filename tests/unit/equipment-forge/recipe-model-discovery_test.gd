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

const RECIPE_IRON_SWORD: StringName = &"recipe_iron_sword"                    # ungated, weapon, needs 4 Material
const RECIPE_LUCKY_CHARM: StringName = &"recipe_lucky_charm_trinket"          # ungated, trinket, needs 3 Material
const RECIPE_REINFORCED_PLATE: StringName = &"recipe_reinforced_plate"        # gated on tech_production_2, armor, needs 6 Material
const TECH_PRODUCTION_2: StringName = &"tech_production_2"

var _forge: EquipmentForge
var _spy: EventBusSpy


func before_test() -> void:
	_forge = EquipmentForge.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.recipe_discovered)
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


## Corrected 2026-08-26, then again 2026-08-31 (live gdUnit4 run + Godot MCP
## diagnostic each time) — this assertion keeps going stale because new
## equipment content keeps legitimately satisfying the same discovery
## criteria (gated on tech_production_2 or ungated, needs <=6 common_scrap),
## not because of any bug. 2026-08-26 found recipe_iron_greaves had joined
## recipe_reinforced_plate (2 total). 2026-08-31's full equipment-batch pass
## (alternate T3/T4 recipes across every slot) added several more real
## recipes that also clear this bar — live-verified via run_script against
## the real registry: this exact scenario now fires exactly 8
## recipe_discovered events (recipe_iron_band, recipe_iron_buckler,
## recipe_iron_greaves, recipe_reinforced_boots, recipe_reinforced_gauntlets,
## recipe_reinforced_helm, recipe_reinforced_plate, recipe_silver_pendant).
## All 8 are real, correctly-discovered recipes, not a bug. Checking the full
## real set (not just the two originally singled out) so the next new
## qualifying recipe fails loudly here instead of silently inflating an
## un-asserted count.
func test_tech_unlocked_discovers_recipe_once_materials_already_sufficient() -> void:
	_seed_material(6)
	_forge._on_tech_unlocked(String(TECH_PRODUCTION_2), "production_tech")

	assert_bool(_forge.is_discovered(RECIPE_REINFORCED_PLATE)).is_true()
	assert_int(_spy.count("recipe_discovered")).is_equal(8)
	var emissions: Array = _spy.emissions["recipe_discovered"] as Array
	var discovered_ids: Array = []
	var category_by_id: Dictionary = {}
	for emission: Array in emissions:
		var id: String = emission[0] as String
		discovered_ids.append(id)
		category_by_id[id] = emission[1] as String
	var expected_ids: Array[String] = [
		"recipe_iron_band", "recipe_iron_buckler", "recipe_iron_greaves",
		"recipe_reinforced_boots", "recipe_reinforced_gauntlets",
		"recipe_reinforced_helm", "recipe_reinforced_plate", "recipe_silver_pendant",
	]
	for expected_id: String in expected_ids:
		assert_bool(discovered_ids.has(expected_id)).append_failure_message(
			"expected recipe '%s' to be discovered in this scenario, but it wasn't" % expected_id
		).is_true()
	assert_str(category_by_id[String(RECIPE_REINFORCED_PLATE)] as String).is_equal("hero_equipment")


func test_item_added_discovers_ungated_recipe_directly() -> void:
	_seed_material(4)
	_forge._on_item_added("common_scrap", "Material", 4)

	assert_bool(_forge.is_discovered(RECIPE_IRON_SWORD)).is_true()
	var iron_sword_emissions: int = 0
	for emission: Array in (_spy.emissions.get("recipe_discovered", []) as Array):
		if (emission[0] as String) == String(RECIPE_IRON_SWORD):
			iron_sword_emissions += 1
	assert_int(iron_sword_emissions).is_equal(1)


func test_discovery_is_permanent_despite_later_material_gate_loss() -> void:
	_seed_material(4)
	_forge._on_item_added("common_scrap", "Material", 4)
	assert_bool(_forge.is_discovered(RECIPE_IRON_SWORD)).is_true()

	# Material stock drops back to 0 (simulated) — discovery must not revert.
	GInventory.reset_to_defaults()

	assert_bool(_forge.is_discovered(RECIPE_IRON_SWORD)).is_true()


func test_recipe_discovered_fires_exactly_once_across_two_crossings() -> void:
	GDefenseBuilding._tech_ledger[TECH_PRODUCTION_2] = true
	_seed_material(6)
	_forge._on_item_added("common_scrap", "Material", 6)
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
	_seed_material(4)
	_forge._on_item_added("common_scrap", "Material", 4)
	assert_bool(_forge.is_discovered(RECIPE_IRON_SWORD)).is_true()
	assert_bool(_forge.is_craftable(RECIPE_IRON_SWORD)).is_true()

	# Consume materials back below threshold — still discovered, no longer craftable.
	GInventory.consume_by_type("Material", 4)
	assert_bool(_forge.is_discovered(RECIPE_IRON_SWORD)).is_true()
	assert_bool(_forge.is_craftable(RECIPE_IRON_SWORD)).is_false()

	# Re-add materials — craftability flips back true, no new recipe_discovered.
	_spy.clear()
	_seed_material(4)
	assert_bool(_forge.is_craftable(RECIPE_IRON_SWORD)).is_true()
	assert_int(_spy.count("recipe_discovered")).is_equal(0)


func test_undiscovered_recipe_is_never_craftable_regardless_of_materials() -> void:
	_seed_material(6)  # would satisfy recipe_reinforced_plate's inputs
	assert_bool(_forge.is_craftable(RECIPE_REINFORCED_PLATE)).is_false()
