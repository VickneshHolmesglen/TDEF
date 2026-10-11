extends GdUnitTestSuite

## End-to-end chain (hero-damage spec §9 AC-3/AC-6/AC-7): elite wind-up -> hero_incoming_damage ->
## DamageStatus mitigation (Hero armor via injection) -> hero_damage_taken -> Hero HP.
## The lethal/DEFEAT branch is already covered by hero_lifecycle_test.gd and is not repeated here
## (it would drive the real WaveManager DEFEAT transition).

class _StubGrid extends RefCounted:
	func get_cell_type(_cell: Vector2i) -> int:
		return Grid.CellType.SPAWN

	func cell_to_world(cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x) * 64.0, float(cell.y) * 64.0)

	func world_to_cell(_pos: Vector2) -> Vector2i:
		return Vector2i(0, 0)

	func get_towers_in_range(_center: Vector2i, _radius: int) -> Array[int]:
		return []


class _StubPathfinding extends RefCounted:
	func find_path(_from: Vector2i, _tier: int) -> Array[Vector2i]:
		return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]


var _hero: Hero
var _ds: DamageStatus
var _mm: MonsterManager


func before_test() -> void:
	GInventory.reset_to_defaults()
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[&"move_speed"] = 0.0
	_hero._base_stats[&"armor"] = 52.0
	_hero.set_process(false)
	# The real Hero would otherwise emit hero_position_changed on its first physics frame and
	# overwrite the MonsterManager's hand-set _hero_cell during the test's awaits.
	_hero.set_physics_process(false)
	_hero._phase = Hero.HeroPhase.COMBAT
	_hero._max_hp = 500.0
	_hero._current_hp = 500.0
	_ds = DamageStatus.new()
	add_child(_ds)
	_ds.set_hero_stats(_hero)
	_mm = MonsterManager.new()
	add_child(_mm)
	_mm._grid = _StubGrid.new()
	_mm._pathfinding = _StubPathfinding.new()
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	_mm._hero_alive = true
	_mm._hero_cell = Vector2i(1, 0)


func after_test() -> void:
	GInventory.reset_to_defaults()
	for e: MonsterEntity in _mm.active_monsters:
		if is_instance_valid(e):
			e.free()
	for e: MonsterEntity in _mm.spawning_entities:
		if is_instance_valid(e):
			e.free()
	remove_child(_mm)
	_mm.free()
	_mm = null
	# TD-test-009: clear every member that points at a freed node. gdUnit4's
	# orphan monitor scans this suite's member variables and errored ("Trying
	# to cast a freed object") on the dangling _ds after the await below.
	if is_instance_valid(_ds):
		_ds.queue_free()
		_ds = null
		await get_tree().process_frame
	_ds = null
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


func _spawn_elite(damage: float) -> MonsterEntity:
	var res := MonsterResource.new()
	res.monster_id = &"chain_elite"
	res.display_name = "Chain Elite"
	res.tier = 1
	res.base_hp = 300.0
	res.base_speed = 0.5
	res.base_damage = damage
	res.base_attack_interval = 3.0
	res.boss_attack_range_cells = 2
	res.hero_attack_windup_seconds = 1.0
	res.drop_table_id = &"goblin_drops"
	_mm._resource_table[res.monster_id] = res
	return _mm.spawn_monster(res.monster_id, Vector2i(0, 0), 1, 1)


func test_an_elite_hit_reduces_hero_hp_by_the_armor_mitigated_amount() -> void:
	_spawn_elite(45.0)
	_mm._pass2b_hero_attacks(0.5)  # scan + wind-up starts
	_mm._pass2b_hero_attacks(0.5)  # wind-up completes -> hero_incoming_damage
	await get_tree().process_frame  # D&S defers one frame
	await get_tree().process_frame
	# floor(45 x 100 / (52 + 100)) = 29
	assert_float(_hero._current_hp).is_equal_approx(471.0, 0.0001)


func test_a_dodged_attack_leaves_hero_hp_untouched() -> void:
	_spawn_elite(45.0)
	_mm._pass2b_hero_attacks(0.5)
	_mm._hero_cell = Vector2i(9, 9)  # the Hero steps out of range during the wind-up
	_mm._pass2b_hero_attacks(0.5)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(_hero._current_hp).is_equal_approx(500.0, 0.0001)


func test_the_wave_clear_heal_recovers_part_of_the_damage() -> void:
	_spawn_elite(45.0)
	_mm._pass2b_hero_attacks(0.5)
	_mm._pass2b_hero_attacks(0.5)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(_hero._current_hp).is_equal_approx(471.0, 0.0001)
	_hero._on_wave_completed(1, 0, false)  # +25% of 500 = 125, clamped to max HP
	assert_float(_hero._current_hp).is_equal_approx(500.0, 0.0001)
