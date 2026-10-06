extends GdUnitTestSuite

## Unit tests for the Hero-side skill secondary effects (skill secondary
## effects spec 2026-10-07): chain extra hits and the lifesteal_bonus cast buff.

var _hero: Hero
var _hits: Array[HeroSkillAttackEvent] = []


func before_test() -> void:
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[&"physical_attack"] = 100.0
	_hero._base_stats[&"magic_attack"] = 100.0
	_hits.clear()
	GEventBus.hero_skill_attacked.connect(_record)


func after_test() -> void:
	GEventBus.hero_skill_attacked.disconnect(_record)
	if _hero != null and is_instance_valid(_hero):
		_hero.free()
	_hero = null


func _record(payload: HeroSkillAttackEvent) -> void:
	_hits.append(payload)


func _cache(entity_id: int, cell: Vector2i) -> void:
	_hero._monster_cache[entity_id] = {"cell": cell, "hp": 100.0, "monster_id": &"goblin", "tier": 0,
		"path_step": 0, "armor": 0.0, "evasion": 0.0, "elemental_resistances": {}}


func test_chain_hits_the_nearest_monsters_within_range_at_reduced_power() -> void:
	_cache(1, Vector2i(0, 0))
	_cache(2, Vector2i(2, 0))
	_cache(3, Vector2i(4, 0))
	_cache(4, Vector2i(9, 9))  # out of chain range
	var skill: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(&"elem_arc_lightning")

	_hero._resolve_chain(skill, &"elem_arc_lightning", 1)

	assert_int(_hits.size()).is_equal(2)  # 3 jumps allowed, only 2 monsters in range
	assert_int(_hits[0].target_id).is_equal(2)
	assert_int(_hits[1].target_id).is_equal(3)
	assert_float(_hits[0].skill_power_coefficient).is_equal_approx(skill.effect_data.skill_power_coefficient * 0.7, 0.0001)


func test_chain_never_hits_the_same_monster_twice() -> void:
	_cache(1, Vector2i(0, 0))
	_cache(2, Vector2i(1, 0))
	var skill: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(&"elem_arc_lightning")

	_hero._resolve_chain(skill, &"elem_arc_lightning", 1)

	assert_int(_hits.size()).is_equal(1)


func test_lifesteal_bonus_cast_adds_a_timed_flat_lifesteal_buff() -> void:
	var before: float = _hero.get_effective_stat(&"lifesteal")
	_hero._apply_cast_buff(&"phys_last_stand")
	assert_float(_hero.get_effective_stat(&"lifesteal") - before).is_equal_approx(0.10, 0.0001)
	_hero._tick_timed_flat_buffs(6.1)
	assert_float(_hero.get_effective_stat(&"lifesteal")).is_equal_approx(before, 0.0001)


func test_a_non_lifesteal_skill_adds_no_cast_buff() -> void:
	_hero._apply_cast_buff(&"phys_cleave")
	assert_bool(_hero._timed_flat_buffs.is_empty()).is_true()


func test_timed_buffs_are_cleared_by_reset() -> void:
	_hero._apply_cast_buff(&"phys_last_stand")
	_hero.reset_to_defaults()
	assert_bool(_hero._timed_flat_buffs.is_empty()).is_true()
