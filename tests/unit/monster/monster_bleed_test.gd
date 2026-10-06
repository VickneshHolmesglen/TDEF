extends GdUnitTestSuite

## Unit tests for bleed stacking and haemorrhage rupture (bleed/haemorrhage
## spec 2026-10-06). Stub/fixture pattern mirrors monster_apply_dot_test.gd.

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
		return [Vector2i(1, 0), Vector2i(2, 0)]


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


func _spawn(base_hp: float) -> MonsterEntity:
	var res := MonsterResource.new()
	res.monster_id = &"goblin"
	res.display_name = "Test Monster"
	res.tier = 0
	res.base_hp = base_hp
	res.base_speed = 1.0
	res.drop_table_id = &"goblin_drops"
	res.menagerie_attraction_drop_chance = 0.05
	_mm._resource_table[&"goblin"] = res
	return _mm.spawn_monster(&"goblin", SPAWN_CELL, 1, 1)


func _bleeds(entity: MonsterEntity) -> Array:
	return entity.active_status_effects.filter(func(e: ActiveStatusEffect) -> bool: return e.effect_type == "bleed")


func test_bleed_is_one_instance_whose_stacks_add_up() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	_mm.apply_bleed(m.entity_id, 0.04, 8.0, 1, false)
	_mm.apply_bleed(m.entity_id, 0.04, 8.0, 2, false)

	assert_int(_bleeds(m).size()).is_equal(1)
	assert_int(_mm.get_bleed_stacks(m.entity_id)).is_equal(3)
	var bleed: ActiveStatusEffect = _bleeds(m)[0]
	assert_float(bleed.tick_damage).is_equal_approx(bleed.per_stack_tick * 3.0, 0.0001)


func test_bleed_stacks_cap_at_the_maximum() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	for i: int in 4:
		_mm.apply_bleed(m.entity_id, 0.04, 8.0, 2, false)

	assert_int(_mm.get_bleed_stacks(m.entity_id)).is_equal(MonsterManager.BLEED_MAX_STACKS)


func test_a_new_application_refreshes_the_duration() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	_mm.apply_bleed(m.entity_id, 0.04, 8.0, 1, false)
	for i: int in 3:
		_mm._tick_dot_instances(m, 1.0)
	assert_int((_bleeds(m)[0] as ActiveStatusEffect).ticks_remaining).is_equal(5)

	_mm.apply_bleed(m.entity_id, 0.04, 8.0, 1, false)

	assert_int((_bleeds(m)[0] as ActiveStatusEffect).ticks_remaining).is_equal(8)


func test_bleed_ticks_deal_per_stack_damage_times_stacks() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	var before: float = m.current_hp
	_mm.apply_bleed(m.entity_id, 0.04, 8.0, 2, false)

	_mm._tick_dot_instances(m, 1.0)

	# 2 stacks x (0.04 * scaled_hp / 8 ticks) per tick
	assert_float(before - m.current_hp).is_equal_approx(2.0 * 0.04 * m.scaled_hp / 8.0, 0.001)


func test_tower_bleed_joins_the_same_stacking_instance() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	_mm._on_tower_attacked_status(1, m.entity_id, 0.0, false, false, "bleed", 0.04, 8.0, 0.0, false)
	_mm._on_tower_attacked_status(1, m.entity_id, 0.0, false, false, "bleed", 0.04, 8.0, 0.0, false)

	assert_int(_bleeds(m).size()).is_equal(1)
	assert_int(_mm.get_bleed_stacks(m.entity_id)).is_equal(2)


func test_burn_and_poison_still_stack_as_separate_instances() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	_mm._on_tower_attacked_status(1, m.entity_id, 0.0, false, false, "poison", 0.08, 4.0, 0.0, false)
	_mm._on_tower_attacked_status(1, m.entity_id, 0.0, false, false, "poison", 0.08, 4.0, 0.0, false)

	assert_int(m.active_status_effects.size()).is_equal(2)


func test_haemorrhage_ruptures_at_max_stacks_for_the_remaining_damage_times_the_multiplier() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	_mm.apply_bleed(m.entity_id, 0.04, 8.0, 4, false)
	var before: float = m.current_hp

	_mm.apply_bleed(m.entity_id, 0.04, 8.0, 1, true)

	var expected: float = 5.0 * (0.04 * m.scaled_hp / 8.0) * 8.0 * MonsterManager.HAEMORRHAGE_RUPTURE_MULTIPLIER
	assert_float(before - m.current_hp).is_equal_approx(expected, 0.01)
	assert_int(_mm.get_bleed_stacks(m.entity_id)).is_equal(0)


func test_haemorrhage_below_max_stacks_just_adds_stacks() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	var before: float = m.current_hp

	_mm.apply_bleed(m.entity_id, 0.04, 8.0, 2, true)

	assert_float(m.current_hp).is_equal(before)
	assert_int(_mm.get_bleed_stacks(m.entity_id)).is_equal(2)


func test_a_lethal_rupture_kills_and_credits_the_hero() -> void:
	var m: MonsterEntity = _spawn(10.0)
	_mm.apply_bleed(m.entity_id, 0.9, 8.0, 5, true, &"hero")

	assert_int(m.lifecycle_state).is_equal(MonsterEntity.State.DEAD)
	assert_str(String(m.last_hit_source)).is_equal("hero")


func test_bleed_on_an_unknown_or_dead_target_is_a_safe_no_op() -> void:
	_mm.apply_bleed(424242, 0.04, 8.0, 1, true)
	assert_int(_mm.get_bleed_stacks(424242)).is_equal(0)


# ---------------------------------------------------------------------------
# Hero skill hook and skill data
# ---------------------------------------------------------------------------

func _skill_hit(skill_id: StringName, target_id: int) -> HeroSkillAttackEvent:
	var payload := HeroSkillAttackEvent.new()
	payload.skill_id = skill_id
	payload.target_id = target_id
	return payload


func test_cleave_applies_one_bleed_stack_per_hit() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	_mm._on_hero_skill_attacked_status(_skill_hit(&"phys_cleave", m.entity_id))
	assert_int(_mm.get_bleed_stacks(m.entity_id)).is_equal(1)


func test_whirling_assault_applies_two_stacks_and_ruptures_at_max() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	_mm._on_hero_skill_attacked_status(_skill_hit(&"phys_whirling_assault", m.entity_id))
	_mm._on_hero_skill_attacked_status(_skill_hit(&"phys_whirling_assault", m.entity_id))
	assert_int(_mm.get_bleed_stacks(m.entity_id)).is_equal(4)
	var before: float = m.current_hp

	_mm._on_hero_skill_attacked_status(_skill_hit(&"phys_whirling_assault", m.entity_id))

	assert_int(_mm.get_bleed_stacks(m.entity_id)).is_equal(0)
	assert_float(m.current_hp).is_less(before)


func test_a_skill_without_a_bleed_secondary_applies_nothing() -> void:
	var m: MonsterEntity = _spawn(1000.0)
	_mm._on_hero_skill_attacked_status(_skill_hit(&"phys_rending_throw", m.entity_id))
	assert_int(m.active_status_effects.size()).is_equal(0)


func test_bleed_skill_data_validates_and_rejects_missing_values() -> void:
	var data := HeroSkillEffectResource.new()
	data.damage_type = "physical"
	data.delivery = "melee_arc"
	data.secondary_effect = "dot_bleed"
	var errors: Array[String] = data.validate()
	assert_bool(errors.any(func(e: String) -> bool: return e.contains("bleed_value"))).is_true()
	assert_bool(errors.any(func(e: String) -> bool: return e.contains("bleed_stacks"))).is_true()
	data.bleed_value = 0.04
	data.bleed_duration = 8.0
	data.bleed_stacks = 1
	assert_bool(data.validate().any(func(e: String) -> bool: return e.contains("bleed"))).is_false()
