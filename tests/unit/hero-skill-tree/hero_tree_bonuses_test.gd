extends GdUnitTestSuite

## Expanded Hero Skill Tree feeding the Hero (expansion spec §7.4/§7.5,
## AC-X3/X6/X7): tree stat bucket and tree effects in SetEffectController.
## Drives the real GHeroSkillTree autoload and resets it after every test.

var _hero: Hero
var _ctl: SetEffectController


func before_test() -> void:
	GHeroSkillTree.reset_to_defaults()
	GInventory.reset_to_defaults()
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[&"attack_range"] = 200.0
	_hero._base_stats[&"physical_attack"] = 100.0
	_hero._base_stats[&"max_hp"] = 500.0
	_ctl = SetEffectController.new()
	_hero.add_child(_ctl)


func after_test() -> void:
	GHeroSkillTree.reset_to_defaults()
	GInventory.reset_to_defaults()
	if _hero != null and is_instance_valid(_hero):
		remove_child(_hero)
		_hero.free()
	_hero = null


func _buy_spine(archetype: String, through: int) -> void:
	for node_index: int in through + 1:
		GHeroSkillTree.skill_tree_points[archetype] += 1
		var skill: String = ""
		if node_index > 0:
			skill = GHeroSkillTree.get_tier_skill_ids(archetype, node_index)[0]
		GHeroSkillTree.purchase_node(archetype, node_index, skill)
		GHeroSkillTree.visit_spend_count = 0


func _buy_branch(archetype: String, slot: String, side: String) -> void:
	GHeroSkillTree.skill_tree_points[archetype] += 1
	assert_bool(GHeroSkillTree.purchase_branch_node(archetype, slot, side)).is_true()
	GHeroSkillTree.visit_spend_count = 0


func test_tree_bonus_root_gives_flat_armor() -> void:
	# Arrange
	var before: float = _hero.get_effective_stat(&"armor")
	# Act: Physical Root (Hardened, armor +4 flat).
	_buy_spine("physical", 0)
	# Assert
	assert_float(_hero.get_effective_stat(&"armor")).is_equal_approx(before + 4.0, 0.0001)


func test_tree_bonus_fork_additive_and_retrain_swaps_it_same_visit() -> void:
	# Arrange
	_buy_spine("physical", 1)
	var base_hp: float = _hero.get_effective_stat(&"max_hp")
	var base_atk: float = _hero.get_effective_stat(&"physical_attack")
	# Act: Bulwark I (+6% max HP).
	_buy_branch("physical", "fork_1", "L")
	# Assert
	assert_float(_hero.get_effective_stat(&"max_hp")).is_equal_approx(base_hp * 1.06, 0.01)
	# Act: retrain to Onslaught I (+5% physical attack) (AC-X3).
	assert_bool(GHeroSkillTree.retrain("physical", "fork_1")).is_true()
	assert_float(_hero.get_effective_stat(&"max_hp")).is_equal_approx(base_hp, 0.01)
	assert_float(_hero.get_effective_stat(&"physical_attack")).is_equal_approx(base_atk * 1.05, 0.01)


func test_tree_bonus_keystone_penalty_lowers_a_stat() -> void:
	# Arrange
	_buy_spine("physical", 3)
	var base_hp: float = _hero.get_effective_stat(&"max_hp")
	# Act: Berserker's Pact (+30% attack, -20% max HP).
	_buy_branch("physical", "keystone", "B")
	# Assert
	assert_float(_hero.get_effective_stat(&"max_hp")).is_equal_approx(base_hp * 0.8, 0.01)


func test_tree_bonus_notable_runs_in_set_effect_controller() -> void:
	# Arrange: Ranged Fork I L to Steady Aim (on_wave_start_buff).
	_buy_spine("ranged", 1)
	for i: int in 3:
		_buy_branch("ranged", "fork_1", "L")
	var range_before: float = _hero.get_effective_stat(&"attack_range")
	# Act
	_ctl._on_wave_started(1, 5, 1.0)
	# Assert (AC-X7)
	assert_bool(_hero.has_effect_modifier(&"tree:ranged_fork_1_L2")).is_true()
	assert_float(_hero.get_effective_stat(&"attack_range")).is_greater(range_before)
