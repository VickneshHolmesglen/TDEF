extends GdUnitTestSuite

## Hero Skill Tree screen, expanded tree (expansion spec §7.6, §6a UI):
## branch panels under their opening skill, purchase by press, retrain,
## bridge tiles. Uses an injected detached HeroSkillTree.

const SCENE: String = "res://src/gameplay/ui/hero_skill_tree_screen/HeroSkillTreeScreen.tscn"

var _tree: HeroSkillTree
var _screen: Control


func before_test() -> void:
	_tree = HeroSkillTree.new()
	_tree.reset_to_defaults()


func after_test() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.disconnect_own_subscriptions()
		remove_child(_screen)
		_screen.free()
	_tree.free()


func _open() -> void:
	_screen = (load(SCENE) as PackedScene).instantiate()
	_screen.hero_skill_tree = _tree
	add_child(_screen)


func _buy_spine(archetype: String, through: int) -> void:
	for node_index: int in through + 1:
		_tree.skill_tree_points[archetype] += 1
		var skill: String = "" if node_index == 0 else _tree.get_tier_skill_ids(archetype, node_index)[0]
		_tree.purchase_node(archetype, node_index, skill)
		_tree.visit_spend_count = 0


func test_tree_screen_branch_buttons_show_effects_and_buy_on_press() -> void:
	# Arrange
	_buy_spine("physical", 1)
	_tree.skill_tree_points["physical"] = 1
	_open()
	var button: Button = _screen.get_branch_button("physical", "fork_1", "L", 0)
	# Assert: readable, purchasable; Fork II still closed.
	assert_object(button).is_not_null()
	assert_str(button.text).contains("Bulwark I")
	assert_bool(button.disabled).is_false()
	assert_bool(_screen.get_branch_button("physical", "fork_2", "L", 0).disabled).is_true()
	# Act
	button.pressed.emit()
	await await_idle_frame()
	# Assert: bought; other side greyed; retrain offered but the visit is spent.
	assert_dict(_tree.get_branch_state("physical", "fork_1")).is_equal({"side": "L", "depth": 1})
	assert_bool(_screen.get_branch_button("physical", "fork_1", "R", 0).disabled).is_true()
	assert_bool(_screen.get_retrain_button("physical", "fork_1").disabled).is_true()


func test_tree_screen_retrain_button_swaps_side() -> void:
	# Arrange
	_buy_spine("ranged", 1)
	_tree.skill_tree_points["ranged"] = 1
	_tree.purchase_branch_node("ranged", "fork_1", "L")
	_tree.visit_spend_count = 0
	_open()
	# Act
	_screen.get_retrain_button("ranged", "fork_1").pressed.emit()
	await await_idle_frame()
	# Assert
	assert_str(String(_tree.get_branch_state("ranged", "fork_1")["side"])).is_equal("R")


func test_tree_screen_bridge_tile_buys_when_open() -> void:
	# Arrange
	_buy_spine("elemental", 2)
	_buy_spine("support", 2)
	_tree.skill_tree_points["elemental"] = 1
	_tree.skill_tree_points["support"] = 1
	_open()
	var tile: Button = _screen.get_bridge_button("bridge_elemental_support")
	assert_bool(tile.disabled).is_false()
	assert_bool(_screen.get_bridge_button("bridge_physical_ranged").disabled).is_true()
	# Act
	tile.pressed.emit()
	await await_idle_frame()
	# Assert
	assert_array(_tree.get_owned_bridges()).contains_exactly(["bridge_elemental_support"])


func test_tree_screen_root_node_shows_its_effect() -> void:
	_open()
	assert_str(_screen.get_node_button("physical", 0).text).contains("Hardened")
