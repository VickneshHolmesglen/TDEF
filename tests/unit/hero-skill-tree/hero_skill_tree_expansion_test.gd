extends GdUnitTestSuite

## Expanded Hero Skill Tree (design/quick-specs/hero-skill-tree-expansion-2026-11-04.md):
## forks, keystones, retraining, bridges, overflow, save v2, catalogue data.
## Uses a detached HeroSkillTree (never added to the tree, so it holds no
## EventBus subscriptions and the GHeroSkillTree autoload is untouched).

var _tree: HeroSkillTree


func before_test() -> void:
	_tree = HeroSkillTree.new()
	_tree.reset_to_defaults()


func after_test() -> void:
	_tree.free()
	_tree = null


## Buys spine nodes 0..`through` in `archetype`, one visit each.
func _buy_spine(archetype: String, through: int) -> void:
	for node_index: int in through + 1:
		_tree.skill_tree_points[archetype] += 1
		var skill: String = ""
		if node_index > 0:
			skill = _tree.get_tier_skill_ids(archetype, node_index)[0]
		assert_bool(_tree.purchase_node(archetype, node_index, skill)).is_true()
		_tree.visit_spend_count = 0


func _buy_branch(archetype: String, slot: String, side: String) -> bool:
	_tree.skill_tree_points[archetype] += 1
	var ok: bool = _tree.purchase_branch_node(archetype, slot, side)
	_tree.visit_spend_count = 0
	return ok


func test_tree_catalog_loads_and_validates_with_66_nodes() -> void:
	var catalog: HeroTreeCatalog = _tree.get_catalog()
	assert_int(catalog.nodes.size()).is_equal(66)
	assert_array(catalog.validate()).is_empty()
	assert_int(catalog.bridges().size()).is_equal(6)


func test_tree_node_validate_rejects_additive_on_zero_base_stat() -> void:
	# Arrange: armor's base is 0, so an additive % would do nothing (AC-X6).
	var node := HeroTreeNodeResource.new()
	node.id = &"bad"
	node.display_name = "Bad"
	node.archetype = "physical"
	node.slot = &"root"
	node.additive_stats = {&"armor": 0.10}
	# Act / Assert
	assert_str(" ".join(node.validate())).contains("base is 0")


func test_tree_fork_needs_its_spine_skill_and_first_purchase_locks_other_side() -> void:
	# Arrange
	_tree.skill_tree_points["physical"] = 5
	# Assert: Fork I closed until Skill I (spine node 1).
	assert_bool(_tree.is_branch_purchasable("physical", "fork_1", "L")).is_false()
	_buy_spine("physical", 1)
	assert_bool(_tree.is_branch_purchasable("physical", "fork_1", "L")).is_true()
	assert_bool(_tree.is_branch_open("physical", "fork_2")).is_false()
	# Act
	assert_bool(_buy_branch("physical", "fork_1", "L")).is_true()
	# Assert (AC-X1)
	assert_bool(_tree.is_branch_purchasable("physical", "fork_1", "R")).is_false()
	assert_dict(_tree.get_branch_state("physical", "fork_1")).is_equal({"side": "L", "depth": 1})


func test_tree_fork_side_fills_to_three_and_visit_cap_blocks_second_purchase() -> void:
	# Arrange
	_buy_spine("physical", 1)
	_tree.skill_tree_points["physical"] = 5
	# Act: one purchase uses the visit (AC-X2).
	assert_bool(_tree.purchase_branch_node("physical", "fork_1", "L")).is_true()
	assert_bool(_tree.purchase_branch_node("physical", "fork_1", "L")).is_false()
	assert_bool(_tree.is_node_purchasable("physical", 2)).is_false()
	_tree.visit_spend_count = 0
	_tree.purchase_branch_node("physical", "fork_1", "L")
	_tree.visit_spend_count = 0
	_tree.purchase_branch_node("physical", "fork_1", "L")
	_tree.visit_spend_count = 0
	# Assert: side is full at 3.
	assert_int(int(_tree.get_branch_state("physical", "fork_1")["depth"])).is_equal(3)
	assert_bool(_tree.is_branch_purchasable("physical", "fork_1", "L")).is_false()
	assert_int(_tree.skill_tree_points["physical"]).is_equal(2)


func test_tree_retrain_moves_depth_to_other_side_and_spends_visit_only() -> void:
	# Arrange
	_buy_spine("ranged", 1)
	_buy_branch("ranged", "fork_1", "L")
	_buy_branch("ranged", "fork_1", "L")
	var points_before: int = _tree.skill_tree_points["ranged"]
	# Act (AC-X3)
	assert_bool(_tree.retrain("ranged", "fork_1")).is_true()
	# Assert
	assert_dict(_tree.get_branch_state("ranged", "fork_1")).is_equal({"side": "R", "depth": 2})
	assert_int(_tree.visit_spend_count).is_equal(1)
	assert_int(_tree.skill_tree_points["ranged"]).is_equal(points_before)
	assert_bool(_tree.retrain("ranged", "fork_1")).is_false()
	var ids: Array[StringName] = []
	for node: HeroTreeNodeResource in _tree.active_tree_nodes():
		ids.append(node.id)
	assert_array(ids).contains([&"ranged_fork_1_R0", &"ranged_fork_1_R1"])
	assert_array(ids).not_contains([&"ranged_fork_1_L0"])


func test_tree_keystone_opens_at_skill_three_and_picks_one_of_two() -> void:
	# Arrange
	_buy_spine("elemental", 3)
	# Act
	assert_bool(_buy_branch("elemental", "keystone", "B")).is_true()
	# Assert
	assert_bool(_tree.is_branch_purchasable("elemental", "keystone", "A")).is_false()
	_tree.skill_tree_points["elemental"] += 1
	assert_bool(_tree.is_branch_purchasable("elemental", "keystone", "B")).is_false()
	assert_bool(_tree.retrain("elemental", "keystone")).is_true()
	assert_str(String(_tree.get_branch_state("elemental", "keystone")["side"])).is_equal("A")


func test_tree_overflow_starts_only_after_eleven_purchases() -> void:
	# Arrange: spine done (4) is no longer "fully unlocked".
	_buy_spine("support", 3)
	_tree._on_skill_tree_point_earned("support", 1)
	assert_int(_tree.overflow_points).is_equal(0)
	assert_int(_tree.skill_tree_points["support"]).is_equal(1)
	# Act: fill both forks and the keystone (AC-X4).
	for i: int in 3:
		_buy_branch("support", "fork_1", "R")
		_buy_branch("support", "fork_2", "L")
	_buy_branch("support", "keystone", "A")
	# Assert
	assert_int(_tree.get_purchase_count("support")).is_equal(11)
	assert_bool(_tree.is_archetype_fully_unlocked("support")).is_true()
	_tree._on_skill_tree_point_earned("support", 1)
	assert_int(_tree.overflow_points).is_equal(1)


func test_tree_bridge_needs_skill_two_in_both_and_takes_one_point_each() -> void:
	# Arrange
	_buy_spine("physical", 2)
	_buy_spine("ranged", 1)
	_tree.skill_tree_points["physical"] = 1
	_tree.skill_tree_points["ranged"] = 1
	assert_bool(_tree.is_bridge_purchasable("bridge_physical_ranged")).is_false()
	_tree.skill_tree_points["ranged"] += 1
	assert_bool(_tree.purchase_node("ranged", 2, _tree.get_tier_skill_ids("ranged", 2)[0])).is_true()
	_tree.visit_spend_count = 0
	# Act (AC-X8)
	assert_bool(_tree.purchase_bridge("bridge_physical_ranged")).is_true()
	# Assert
	assert_int(_tree.skill_tree_points["physical"]).is_equal(0)
	assert_int(_tree.skill_tree_points["ranged"]).is_equal(0)
	assert_int(_tree.visit_spend_count).is_equal(1)
	assert_array(_tree.get_owned_bridges()).contains_exactly(["bridge_physical_ranged"])


func test_tree_bridge_is_atomic_and_overflow_stands_in() -> void:
	# Arrange: physical has a point, ranged has none.
	_buy_spine("physical", 2)
	_buy_spine("ranged", 2)
	_tree.skill_tree_points["physical"] = 1
	# Assert: nothing spent when a point is missing.
	assert_bool(_tree.purchase_bridge("bridge_physical_ranged")).is_false()
	assert_int(_tree.skill_tree_points["physical"]).is_equal(1)
	# Act: overflow covers ranged.
	_tree.overflow_points = 1
	assert_bool(_tree.purchase_bridge("bridge_physical_ranged")).is_true()
	assert_int(_tree.skill_tree_points["physical"]).is_equal(0)
	assert_int(_tree.overflow_points).is_equal(0)


func test_tree_third_bridge_refused_and_retrain_bridge_swaps() -> void:
	# Arrange: three archetypes at Skill II open three bridges.
	for archetype: String in ["physical", "ranged", "elemental"]:
		_buy_spine(archetype, 2)
	_tree.overflow_points = 10
	for bridge_id: String in ["bridge_physical_ranged", "bridge_physical_elemental"]:
		assert_bool(_tree.purchase_bridge(bridge_id)).is_true()
		_tree.visit_spend_count = 0
	# Act / Assert (AC-X9)
	assert_bool(_tree.is_bridge_purchasable("bridge_ranged_elemental")).is_false()
	var overflow_before: int = _tree.overflow_points
	assert_bool(_tree.retrain_bridge("bridge_physical_ranged", "bridge_ranged_elemental")).is_true()
	assert_array(_tree.get_owned_bridges()).contains_exactly(["bridge_ranged_elemental", "bridge_physical_elemental"])
	assert_int(_tree.overflow_points).is_equal(overflow_before)
	assert_int(_tree.visit_spend_count).is_equal(1)


func test_tree_terminal_no_op_needs_all_purchases_and_two_bridges() -> void:
	# Arrange: fill every archetype.
	for archetype: String in HeroSkillTree.ARCHETYPES:
		_buy_spine(archetype, 3)
		for i: int in 3:
			_buy_branch(archetype, "fork_1", "L")
			_buy_branch(archetype, "fork_2", "R")
		_buy_branch(archetype, "keystone", "A")
	assert_bool(_tree.is_fully_complete()).is_false()
	_tree._on_skill_tree_point_earned("physical", 1)
	assert_int(_tree.overflow_points).is_equal(1)
	# Act: two bridges, every point from overflow (all pools are empty).
	_tree.overflow_points = 4
	_tree.purchase_bridge("bridge_physical_ranged")
	_tree.visit_spend_count = 0
	_tree.purchase_bridge("bridge_elemental_support")
	# Assert
	assert_bool(_tree.is_fully_complete()).is_true()
	_tree._on_skill_tree_point_earned("physical", 1)
	assert_int(_tree.overflow_points).is_equal(0)


func test_tree_save_round_trip_keeps_branches_and_bridges() -> void:
	# Arrange
	_buy_spine("physical", 2)
	_buy_spine("support", 2)
	_buy_branch("physical", "fork_2", "R")
	_tree.overflow_points = 2
	_tree.purchase_bridge("bridge_physical_support")
	var data: Dictionary = _tree.get_save_data()
	var restored := HeroSkillTree.new()
	restored.reset_to_defaults()
	# Act
	assert_bool(restored.restore_save_data(data)).is_true()
	# Assert
	assert_dict(restored.get_branch_state("physical", "fork_2")).is_equal({"side": "R", "depth": 1})
	assert_array(restored.get_owned_bridges()).contains_exactly(["bridge_physical_support"])
	restored.free()


func test_tree_v1_save_restores_with_branches_locked() -> void:
	# Arrange: a v1 payload has no branches/bridges keys (AC-X5).
	_buy_spine("ranged", 1)
	_tree.skill_tree_points["ranged"] = 3
	var data: Dictionary = _tree.get_save_data()
	data.erase("branches")
	data.erase("bridges")
	data.erase("schema_version")
	var restored := HeroSkillTree.new()
	# Act
	assert_bool(restored.restore_save_data(data)).is_true()
	# Assert
	assert_bool(restored.get_node_state("ranged", 1)["unlocked"] as bool).is_true()
	assert_int(restored.skill_tree_points["ranged"]).is_equal(3)
	assert_dict(restored.get_branch_state("ranged", "fork_1")).is_equal({"side": "", "depth": 0})
	assert_array(restored.get_owned_bridges()).is_empty()
	restored.free()


func test_tree_restore_rejects_three_bridges_and_unopened_slots() -> void:
	# Arrange
	for archetype: String in ["physical", "ranged", "elemental"]:
		_buy_spine(archetype, 2)
	var data: Dictionary = _tree.get_save_data()
	var restored := HeroSkillTree.new()
	restored.reset_to_defaults()
	# Act / Assert: too many bridges.
	data["bridges"] = ["bridge_physical_ranged", "bridge_physical_elemental", "bridge_ranged_elemental"]
	assert_bool(restored.restore_save_data(data)).is_false()
	# A bridge whose archetype lacks Skill II.
	data["bridges"] = ["bridge_physical_support"]
	assert_bool(restored.restore_save_data(data)).is_false()
	# A keystone bought without Skill III.
	data["bridges"] = []
	data["branches"]["physical"]["keystone"] = {"side": "A", "depth": 1}
	assert_bool(restored.restore_save_data(data)).is_false()
	restored.free()


func test_tree_active_effects_use_tree_keys() -> void:
	# Arrange: Physical Fork I L to the Notable (Iron Resolve).
	_buy_spine("physical", 1)
	for i: int in 3:
		_buy_branch("physical", "fork_1", "L")
	# Act
	var effects: Array[Dictionary] = _tree.active_tree_effects()
	# Assert (AC-X7)
	assert_int(effects.size()).is_equal(1)
	assert_str(String(effects[0][&"key"])).is_equal("tree:physical_fork_1_L2")
	assert_str(String(effects[0][&"type"])).is_equal("on_hurt_shield")
