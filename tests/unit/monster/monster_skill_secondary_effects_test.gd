extends GdUnitTestSuite

## Unit tests for hero skill secondary effects applied by MonsterManager
## (skill secondary effects spec 2026-10-07): burn/poison/slow reuse the tower
## machinery; stun, armor shred (vulnerability) and knockback are new.
## Stub/fixture pattern mirrors monster_bleed_test.gd.

class _StubGrid extends RefCounted:
	func get_cell_type(_cell: Vector2i) -> int:
		return Grid.CellType.SPAWN

	func cell_to_world(cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x) * 64.0, float(cell.y) * 64.0)

	func world_to_cell(pos: Vector2) -> Vector2i:
		return Vector2i(int(pos.x / 64.0), int(pos.y / 64.0))

	func get_towers_in_range(_center: Vector2i, _radius: int) -> Array[int]:
		return []


class _StubPathfinding extends RefCounted:
	func find_path(_from: Vector2i, _tier: int) -> Array[Vector2i]:
		return [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]


const SPAWN_CELL := Vector2i(0, 0)

var _mm: MonsterManager


func before_test() -> void:
	_mm = MonsterManager.new()
	add_child(_mm)
	_mm._grid = _StubGrid.new()
	_mm._pathfinding = _StubPathfinding.new()
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	_mm._resource_table = {}
	_mm.set_physics_process(false)


func after_test() -> void:
	for e: MonsterEntity in _mm.active_monsters:
		if is_instance_valid(e):
			e.free()
	remove_child(_mm)
	_mm.free()


func _spawn(base_hp: float, tier: int = 0) -> MonsterEntity:
	var res := MonsterResource.new()
	res.monster_id = &"goblin"
	res.display_name = "Test Monster"
	res.tier = tier
	res.base_hp = base_hp
	res.base_speed = 1.0
	res.drop_table_id = &"goblin_drops"
	res.menagerie_attraction_drop_chance = 0.05
	if tier > 0:
		res.base_damage = 10.0
		res.hero_attack_windup_seconds = 1.0
	_mm._resource_table[&"goblin"] = res
	return _mm.spawn_monster(&"goblin", SPAWN_CELL, 1, 1)


func _hit(skill_id: StringName, target_id: int) -> void:
	var payload := HeroSkillAttackEvent.new()
	payload.skill_id = skill_id
	payload.target_id = target_id
	_mm._on_hero_skill_attacked_status(payload)


func test_burn_skill_applies_a_burn_dot_credited_to_the_hero() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	_hit(&"elem_firestorm", m.entity_id)
	assert_int(m.active_status_effects.size()).is_equal(1)
	var effect: ActiveStatusEffect = m.active_status_effects[0]
	assert_str(effect.effect_type).is_equal("burn")
	assert_str(String(effect.source)).is_equal("hero")


func test_poison_skill_applies_poison() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	_hit(&"elem_poison_nova", m.entity_id)
	assert_str((m.active_status_effects[0] as ActiveStatusEffect).effect_type).is_equal("poison")


func test_slow_skill_reduces_effective_speed() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	var before: float = _mm._effective_speed(m)
	_hit(&"elem_frostbolt", m.entity_id)
	assert_float(_mm._effective_speed(m)).is_equal_approx(before * 0.7, 0.0001)


func test_stun_stops_movement_until_it_wears_off() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	_hit(&"phys_shatter_slam", m.entity_id)
	assert_float(_mm._effective_speed(m)).is_equal(0.0)
	_mm._pass1b_status_effects(1.3)
	assert_float(_mm._effective_speed(m)).is_greater(0.0)


func test_stun_is_halved_on_bosses() -> void:
	var boss: MonsterEntity = _spawn(1000.0, 2)
	_mm.apply_stun(boss.entity_id, 2.0)
	assert_float(boss.stun_remaining).is_equal_approx(1.0, 0.0001)


func test_stun_freezes_an_elite_wind_up() -> void:
	var elite: MonsterEntity = _spawn(1000.0, 1)
	elite.hero_windup_remaining = 0.5
	_mm.apply_stun(elite.entity_id, 1.0)
	_mm._pass2b_hero_attacks(0.4)
	assert_float(elite.hero_windup_remaining).is_equal_approx(0.5, 0.0001)


func test_armor_shred_makes_hits_and_ticks_hurt_more_then_expires() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	_hit(&"phys_rending_throw", m.entity_id)
	assert_float(_mm._vulnerability_multiplier(m)).is_equal_approx(1.2, 0.0001)
	var before: float = m.current_hp
	_mm._apply_status_damage(m, 10.0, &"hero")
	assert_float(before - m.current_hp).is_equal_approx(12.0, 0.0001)
	_mm._pass1b_status_effects(5.1)
	assert_float(_mm._vulnerability_multiplier(m)).is_equal(1.0)


func test_knockback_pushes_the_monster_back_along_its_path() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	m.path_step_index = 3
	m.global_position = Vector2(3.0 * 64.0, 0.0)
	_mm.apply_knockback(m.entity_id, 1.5)
	assert_float(m.global_position.x).is_equal_approx(1.5 * 64.0, 0.01)
	# path_step_index is the NEXT cell to walk to: at x=1.5 cells that is path[1] = (2, 0).
	assert_int(m.path_step_index).is_equal(1)


func test_bosses_ignore_knockback() -> void:
	var boss: MonsterEntity = _spawn(1000.0, 2)
	boss.path_step_index = 3
	boss.global_position = Vector2(3.0 * 64.0, 0.0)
	_mm.apply_knockback(boss.entity_id, 1.5)
	assert_float(boss.global_position.x).is_equal_approx(3.0 * 64.0, 0.01)


func test_chain_and_lifesteal_skills_do_nothing_on_the_monster() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	_hit(&"elem_arc_lightning", m.entity_id)
	_hit(&"sup_healing_ground", m.entity_id)
	assert_int(m.active_status_effects.size()).is_equal(0)
	assert_float(m.stun_remaining).is_equal(0.0)


func test_every_skill_with_a_secondary_effect_validates() -> void:
	for skill: SkillDefinitionResource in GGameDataRegistry.get_all_skill_definitions().values():
		if skill.effect_data == null:
			continue
		assert_array(skill.effect_data.validate()).override_failure_message(String(skill.skill_id)).is_empty()
