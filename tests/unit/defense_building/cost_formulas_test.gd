## Unit tests for Story 025 (TR-defbuild-001, cost-formula half; ADR-0024):
## Formula 1 (tech node costs, derived), Formula 2 (Habitat Expansion, hand-
## tuned), Formula 3 (Watchtower, hand-tuned).
##
## Exercises the real, authored res://assets/data/defense_building/ content
## via the GGameDataRegistry Autoload (no fixture injection) — same rationale
## as every other defense_building test. These assert the AUTHORED values
## match Formula 1's derivation (round(base_qty[rarity] × node_tier_multiplier),
## round(50 × node_tier_multiplier)) and Formula 2/3's hand-tuned tables
## exactly — content-validation tests, not tests of a runtime formula
## function (TechNodeResource/StructureResource are static, boot-loaded data;
## Formula 1 is a content-authoring-time derivation, never computed at
## runtime — Rule 9's cost re-validate step reads these fields directly).
extends GdUnitTestSuite

const TECH_PRODUCTION_2: StringName = &"tech_production_2"
const TECH_PRODUCTION_3: StringName = &"tech_production_3"
const TECH_PRODUCTION_4: StringName = &"tech_production_4"
const TECH_STRUCTURAL_1: StringName = &"tech_structural_1"
const TECH_STRUCTURAL_2: StringName = &"tech_structural_2"
const HABITAT_TIER_1: StringName = &"habitat_expansion_tier_1"
const HABITAT_TIER_2: StringName = &"habitat_expansion_tier_2"
const HABITAT_TIER_3: StringName = &"habitat_expansion_tier_3"
const WATCHTOWER_TIER_1: StringName = &"watchtower_tier_1"


# ---------------------------------------------------------------------------
# AC-31/32/33: Formula 1 — branch_tier=1/2/3 tech node costs
# (round(base_qty[rarity] × node_tier_multiplier), round(50 × multiplier))
# ---------------------------------------------------------------------------

func test_branch_tier_1_common_node_costs_15_common_50_gold() -> void:
	var node: TechNodeResource = GGameDataRegistry.get_tech_node(TECH_PRODUCTION_2)
	assert_int(node.branch_tier).is_equal(1)
	assert_int(node.gold_cost).is_equal(50)
	assert_int(node.material_costs[&"Common"] as int).is_equal(15)
	assert_bool(node.material_costs.has(&"Uncommon")).is_false()
	assert_bool(node.material_costs.has(&"Rare")).is_false()


func test_branch_tier_2_node_costs_27_common_14_uncommon_90_gold() -> void:
	var node: TechNodeResource = GGameDataRegistry.get_tech_node(TECH_PRODUCTION_3)
	assert_int(node.branch_tier).is_equal(2)
	assert_int(node.gold_cost).is_equal(90)
	assert_int(node.material_costs[&"Common"] as int).is_equal(27)
	assert_int(node.material_costs[&"Uncommon"] as int).is_equal(14)
	assert_bool(node.material_costs.has(&"Rare")).is_false()


func test_branch_tier_3_node_costs_45_common_24_uncommon_12_rare_150_gold() -> void:
	var node: TechNodeResource = GGameDataRegistry.get_tech_node(TECH_PRODUCTION_4)
	assert_int(node.branch_tier).is_equal(3)
	assert_int(node.gold_cost).is_equal(150)
	assert_int(node.material_costs[&"Common"] as int).is_equal(45)
	assert_int(node.material_costs[&"Uncommon"] as int).is_equal(24)
	assert_int(node.material_costs[&"Rare"] as int).is_equal(12)


# ---------------------------------------------------------------------------
# AC-34: production_tech and structural_tech share one cost curve — both
# branch_tier=1 nodes cost identically, regardless of category.
# ---------------------------------------------------------------------------

func test_production_and_structural_branch_tier_1_nodes_cost_identically() -> void:
	var production_node: TechNodeResource = GGameDataRegistry.get_tech_node(TECH_PRODUCTION_2)
	var structural_node: TechNodeResource = GGameDataRegistry.get_tech_node(TECH_STRUCTURAL_1)
	assert_int(production_node.gold_cost).is_equal(structural_node.gold_cost)
	assert_int(production_node.material_costs[&"Common"] as int).is_equal(structural_node.material_costs[&"Common"] as int)


func test_production_and_structural_branch_tier_2_nodes_cost_identically() -> void:
	var production_node: TechNodeResource = GGameDataRegistry.get_tech_node(TECH_PRODUCTION_3)
	var structural_node: TechNodeResource = GGameDataRegistry.get_tech_node(TECH_STRUCTURAL_2)
	assert_int(production_node.gold_cost).is_equal(structural_node.gold_cost)
	assert_int(production_node.material_costs[&"Common"] as int).is_equal(structural_node.material_costs[&"Common"] as int)
	assert_int(production_node.material_costs[&"Uncommon"] as int).is_equal(structural_node.material_costs[&"Uncommon"] as int)


# ---------------------------------------------------------------------------
# AC-35: Habitat Expansion — hand-tuned table, exact per-tier values.
# ---------------------------------------------------------------------------

func test_habitat_tier_1_costs_20_common_60_gold() -> void:
	var structure: StructureResource = GGameDataRegistry.get_structure(HABITAT_TIER_1)
	assert_int(structure.gold_cost).is_equal(60)
	assert_int(structure.material_costs[&"Common"] as int).is_equal(20)


func test_habitat_tier_2_costs_35_common_12_uncommon_120_gold() -> void:
	var structure: StructureResource = GGameDataRegistry.get_structure(HABITAT_TIER_2)
	assert_int(structure.gold_cost).is_equal(120)
	assert_int(structure.material_costs[&"Common"] as int).is_equal(35)
	assert_int(structure.material_costs[&"Uncommon"] as int).is_equal(12)


func test_habitat_tier_3_costs_55_common_25_uncommon_8_rare_200_gold() -> void:
	var structure: StructureResource = GGameDataRegistry.get_structure(HABITAT_TIER_3)
	assert_int(structure.gold_cost).is_equal(200)
	assert_int(structure.material_costs[&"Common"] as int).is_equal(55)
	assert_int(structure.material_costs[&"Uncommon"] as int).is_equal(25)
	assert_int(structure.material_costs[&"Rare"] as int).is_equal(8)


# ---------------------------------------------------------------------------
# AC-36: Watchtower — fixed single-tier cost.
# ---------------------------------------------------------------------------

func test_watchtower_tier_1_costs_25_common_70_gold() -> void:
	var structure: StructureResource = GGameDataRegistry.get_structure(WATCHTOWER_TIER_1)
	assert_int(structure.gold_cost).is_equal(70)
	assert_int(structure.material_costs[&"Common"] as int).is_equal(25)
