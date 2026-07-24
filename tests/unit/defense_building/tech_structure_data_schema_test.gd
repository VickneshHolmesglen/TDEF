## Unit tests for Story 018 (TR-defbuild-001, ADR-0024): TechNodeResource /
## StructureResource schemas, GameDataRegistry's loading of both, and
## DefenseBuilding's two independent ledgers.
##
## GameDataRegistry tests intentionally exercise the real, authored
## res://assets/data/defense_building/tech_nodes/ content (no fixture
## injection for that seam) — AC-3 is specifically about the actual
## five-node table this story authors, not a synthetic stand-in. The other
## GameDataRegistry loader seams (monsters/towers/missions/skills/drop
## tables) are left at their defaults; any push_error() noise they produce
## (e.g. the real project has no res://assets/data/drop_tables/ content yet)
## is unrelated to this story's scope and does not affect these assertions,
## mirroring how GameDataRegistry's own does-not-abort boot policy already
## tolerates partial content across every existing loader.
##
## Deliberately NOT duplicated here: duplicate-tech_id / malformed-.tres /
## missing-directory loader edge cases for _load_tech_nodes()/_load_structures().
## Those code paths are byte-for-byte identical to the five already-covered
## loaders in game_data_registry_test.gd (S5-01/S5-02/TD-hero-002/Story 010) —
## re-proving the same templated logic per new resource type would be
## repetition, not new risk surface.
extends GdUnitTestSuite

const TECH_PRODUCTION_2: StringName = &"tech_production_2"
const TECH_PRODUCTION_3: StringName = &"tech_production_3"
const TECH_PRODUCTION_4: StringName = &"tech_production_4"
const TECH_STRUCTURAL_1: StringName = &"tech_structural_1"
const TECH_STRUCTURAL_2: StringName = &"tech_structural_2"

var _registry: GameDataRegistry


func after_test() -> void:
	if _registry != null and is_instance_valid(_registry):
		if _registry.is_inside_tree():
			_registry.get_parent().remove_child(_registry)
		_registry.free()
	_registry = null


# ---------------------------------------------------------------------------
# TechNodeResource.validate()
# ---------------------------------------------------------------------------

func _make_valid_tech_node() -> TechNodeResource:
	var res := TechNodeResource.new()
	res.tech_id = &"tech_production_2"
	res.tech_category = "production_tech"
	res.prerequisite_tech_id = &""
	res.branch_tier = 1
	return res


func test_tech_node_validate_fully_valid_returns_empty_array() -> void:
	var res: TechNodeResource = _make_valid_tech_node()
	assert_array(res.validate()).is_empty()


func test_tech_node_validate_empty_tech_id_returns_error() -> void:
	var res: TechNodeResource = _make_valid_tech_node()
	res.tech_id = &""
	assert_array(res.validate()).contains("tech_id must not be empty")


func test_tech_node_validate_invalid_category_returns_error() -> void:
	var res: TechNodeResource = _make_valid_tech_node()
	res.tech_category = "not_a_real_category"
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("tech_category must be one of"))).is_true()


func test_tech_node_validate_empty_category_returns_error() -> void:
	var res: TechNodeResource = _make_valid_tech_node()
	res.tech_category = ""
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("tech_category must be one of"))).is_true()


func test_tech_node_validate_branch_tier_below_range_returns_error() -> void:
	var res: TechNodeResource = _make_valid_tech_node()
	res.branch_tier = 0
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("branch_tier must be 1-3"))).is_true()


func test_tech_node_validate_branch_tier_above_range_returns_error() -> void:
	var res: TechNodeResource = _make_valid_tech_node()
	res.branch_tier = 4
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("branch_tier must be 1-3"))).is_true()


func test_tech_node_validate_structural_category_is_valid() -> void:
	var res: TechNodeResource = _make_valid_tech_node()
	res.tech_category = "structural_tech"
	assert_array(res.validate()).is_empty()


# ---------------------------------------------------------------------------
# StructureResource.validate()
# ---------------------------------------------------------------------------

func _make_valid_structure() -> StructureResource:
	var res := StructureResource.new()
	res.structure_id = &"habitat_expansion_tier_1"
	res.structure_type = "habitat_expansion"
	res.tier = 1
	res.prerequisite_structure_id = &""
	res.tech_gate = &""
	return res


func test_structure_validate_fully_valid_returns_empty_array() -> void:
	var res: StructureResource = _make_valid_structure()
	assert_array(res.validate()).is_empty()


func test_structure_validate_empty_structure_id_returns_error() -> void:
	var res: StructureResource = _make_valid_structure()
	res.structure_id = &""
	assert_array(res.validate()).contains("structure_id must not be empty")


func test_structure_validate_empty_structure_type_returns_error() -> void:
	var res: StructureResource = _make_valid_structure()
	res.structure_type = ""
	assert_array(res.validate()).contains("structure_type must not be empty")


func test_structure_validate_tier_below_one_returns_error() -> void:
	var res: StructureResource = _make_valid_structure()
	res.tier = 0
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("tier must be >= 1"))).is_true()


func test_structure_validate_negative_tier_returns_error() -> void:
	var res: StructureResource = _make_valid_structure()
	res.tier = -1
	assert_bool(res.validate().any(func(e: String) -> bool: return e.begins_with("tier must be >= 1"))).is_true()


# ---------------------------------------------------------------------------
# GameDataRegistry: TechNodeResource loading (AC-3 — real authored content)
# ---------------------------------------------------------------------------

func test_ready_loads_exactly_five_tech_nodes() -> void:
	_registry = GameDataRegistry.new()
	_registry._ready()
	var all_nodes: Dictionary[StringName, TechNodeResource] = _registry.get_all_tech_nodes()
	assert_int(all_nodes.size()).is_equal(5)


func test_ready_tech_node_category_mapping_matches_gdd_table() -> void:
	_registry = GameDataRegistry.new()
	_registry._ready()
	assert_str(_registry.get_tech_node(TECH_PRODUCTION_2).tech_category).is_equal("production_tech")
	assert_str(_registry.get_tech_node(TECH_PRODUCTION_3).tech_category).is_equal("production_tech")
	assert_str(_registry.get_tech_node(TECH_PRODUCTION_4).tech_category).is_equal("production_tech")
	assert_str(_registry.get_tech_node(TECH_STRUCTURAL_1).tech_category).is_equal("structural_tech")
	assert_str(_registry.get_tech_node(TECH_STRUCTURAL_2).tech_category).is_equal("structural_tech")


func test_ready_tech_node_prerequisite_chain_matches_gdd_table() -> void:
	_registry = GameDataRegistry.new()
	_registry._ready()
	assert_that(_registry.get_tech_node(TECH_PRODUCTION_2).prerequisite_tech_id).is_equal(&"")
	assert_that(_registry.get_tech_node(TECH_PRODUCTION_3).prerequisite_tech_id).is_equal(TECH_PRODUCTION_2)
	assert_that(_registry.get_tech_node(TECH_PRODUCTION_4).prerequisite_tech_id).is_equal(TECH_PRODUCTION_3)
	assert_that(_registry.get_tech_node(TECH_STRUCTURAL_1).prerequisite_tech_id).is_equal(&"")
	assert_that(_registry.get_tech_node(TECH_STRUCTURAL_2).prerequisite_tech_id).is_equal(TECH_STRUCTURAL_1)


func test_get_tech_node_unknown_id_returns_null() -> void:
	_registry = GameDataRegistry.new()
	_registry._ready()
	assert_object(_registry.get_tech_node(&"tech_does_not_exist")).is_null()


func test_get_tech_node_known_id_returns_correct_resource() -> void:
	_registry = GameDataRegistry.new()
	_registry._ready()
	var result: TechNodeResource = _registry.get_tech_node(TECH_STRUCTURAL_1)
	assert_object(result).is_not_null()
	assert_str(String(result.tech_id)).is_equal("tech_structural_1")


func test_get_all_tech_nodes_returns_isolated_copy() -> void:
	_registry = GameDataRegistry.new()
	_registry._ready()
	var all_nodes: Dictionary[StringName, TechNodeResource] = _registry.get_all_tech_nodes()
	all_nodes[&"injected_after_the_fact"] = TechNodeResource.new()
	assert_int(_registry.get_all_tech_nodes().size()).is_equal(5)


# ---------------------------------------------------------------------------
# GameDataRegistry: StructureResource loading
# ---------------------------------------------------------------------------

func test_ready_loads_exactly_four_structures() -> void:
	# res://assets/data/defense_building/structures/ now holds the 3 Habitat
	# Expansion tiers (Story 020) plus watchtower_tier_1 (Story 021) — this
	# supersedes both the original "deliberately empty directory" assertion
	# from Story 018 and Story 020's "exactly three" count.
	_registry = GameDataRegistry.new()
	_registry._ready()
	assert_int(_registry.get_all_structures().size()).is_equal(4)


func test_get_structure_unknown_id_returns_null() -> void:
	# habitat_expansion_tier_1 was originally used here as a "known-not-to-
	# exist" placeholder ID (Story 018, when the structures directory was
	# still deliberately empty) — Story 020 authored it as real content,
	# which silently made this assertion false. Caught during the epic-wide
	# code review. Uses a genuinely nonexistent ID now, matching the
	# analogous tech-node test's convention (test_get_tech_node_unknown_id_returns_null).
	_registry = GameDataRegistry.new()
	_registry._ready()
	assert_object(_registry.get_structure(&"structure_does_not_exist")).is_null()


func test_get_structure_known_id_returns_correct_resource() -> void:
	# No StructureResource content is authored by this story (Story 020/021
	# scope) — this test injects a small dedicated fixture (not the real,
	# deliberately-empty production directory) purely to prove the
	# get_structure() lookup API itself works end-to-end through the loader.
	_registry = GameDataRegistry.new()
	_registry._inject(
		GameDataRegistry.DEFAULT_MONSTERS_DIR,
		GameDataRegistry.DEFAULT_PERK_REGISTRY_PATH,
		GameDataRegistry.DEFAULT_TOWER_BLUEPRINTS_DIR,
		GameDataRegistry.DEFAULT_MISSIONS_DIR,
		GameDataRegistry.DEFAULT_SKILLS_DIR,
		GameDataRegistry.DEFAULT_ULTIMATE_COMBO_TABLE_PATH,
		GameDataRegistry.DEFAULT_DROP_TABLES_DIR,
		GameDataRegistry.DEFAULT_TECH_NODES_DIR,
		"res://tests/fixtures/defense_building/structures_valid/"
	)
	_registry._ready()
	var result: StructureResource = _registry.get_structure(&"habitat_expansion_tier_1")
	assert_object(result).is_not_null()
	assert_str(result.structure_type).is_equal("habitat_expansion")


# ---------------------------------------------------------------------------
# DefenseBuilding: two independent ledgers (AC-1)
# ---------------------------------------------------------------------------

func test_defense_building_ledgers_start_empty() -> void:
	var defense_building := DefenseBuilding.new()
	assert_int(defense_building._tech_ledger.size()).is_equal(0)
	assert_int(defense_building._structure_ledger.size()).is_equal(0)
	defense_building.free()


func test_defense_building_ledgers_are_structurally_independent_dictionaries() -> void:
	var defense_building := DefenseBuilding.new()
	# Mutating one ledger must never be reflected in the other — they are
	# two separate Dictionary instances, not two views over shared storage
	# (ADR-0024: "no shared progression point currency").
	defense_building._tech_ledger[&"tech_production_2"] = true
	assert_int(defense_building._tech_ledger.size()).is_equal(1)
	assert_int(defense_building._structure_ledger.size()).is_equal(0)
	defense_building._structure_ledger[&"habitat_expansion_tier_1"] = true
	assert_int(defense_building._structure_ledger.size()).is_equal(1)
	assert_int(defense_building._tech_ledger.size()).is_equal(1)
	defense_building.free()


func test_defense_building_is_registered_as_autoload() -> void:
	# Flipped in Story 019 (TD-defbuild-001): Story 018 guarded that
	# DefenseBuilding was NOT yet registered as an Autoload; Story 019 is
	# the story that actually performs that registration (Autoload #10,
	# ADR-0024), so this guard now asserts the opposite.
	var text: String = FileAccess.get_file_as_string("res://project.godot")
	assert_bool(text.contains("defense_building.gd")).is_true()
