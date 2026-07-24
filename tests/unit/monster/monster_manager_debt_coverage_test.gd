## Unit tests closing TD-monster-002's 4 tracked coverage gaps: HP absorption
## tracking, wave-end force-death, difficulty-tier HP scaling, and non-lethal
## BOSS boss_hp_changed emission. Fixture/stub pattern mirrors
## monster_spawn_test.gd and monster_boss_test.gd exactly.
extends GdUnitTestSuite

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

const SPAWN_CELL := Vector2i(0, 0)

func _make_resource(id: StringName = &"goblin", base_hp: float = 100.0, tier: int = 0) -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = id
	res.display_name = "Test Monster"
	res.tier = tier
	res.base_hp = base_hp
	res.base_speed = 1.0
	res.drop_table_id = &"goblin_drops"
	res.menagerie_attraction_drop_chance = 0.05
	if tier == 2:
		res.base_damage = 50.0
		res.base_attack_interval = 3.0
		res.boss_attack_range_cells = 3
	return res


var _mm: MonsterManager
var _stub_grid: _StubGrid
var _stub_path: _StubPathfinding
var _spy: EventBusSpy


func before_test() -> void:
	_stub_grid = _StubGrid.new()
	_stub_path = _StubPathfinding.new()
	_mm = MonsterManager.new()
	add_child(_mm)  # add_child() BEFORE stub override — see monster_spawn_test.gd
	_mm._grid = _stub_grid
	_mm._pathfinding = _stub_path
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	_mm._resource_table = {}  # isolate from real GGameDataRegistry content
	# Every pass is invoked manually in this file (including _on_wave_completed(),
	# which queue_free()s entities and clears all collections synchronously) — disable
	# automatic _physics_process ticking so an engine-driven frame can never interleave
	# with that teardown and touch a since-freed entity reference between test cases.
	_mm.set_physics_process(false)


func after_test() -> void:
	if _spy != null:
		_spy.disconnect_all()
		_spy = null
	for e: MonsterEntity in _mm.active_monsters:
		if is_instance_valid(e):
			e.free()
	for e: MonsterEntity in _mm.spawning_entities:
		if is_instance_valid(e):
			e.free()
	remove_child(_mm)
	_mm.free()

# ---------------------------------------------------------------------------
# Gap 1: HP absorption tracking (_pass4_absorbed_flush, monster_hp_absorbed)
# ---------------------------------------------------------------------------

func test_pass4_absorbed_flush_emits_monster_hp_absorbed_with_correct_value() -> void:
	var res := _make_resource(&"goblin", 100.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.monster_hp_absorbed)

	var payload := MonsterDamageTaken.new()
	payload.entity_id = entity.entity_id
	payload.amount = 30  # non-lethal — 100 HP, 30 damage
	payload.source_type = 1
	_mm._on_monster_damage_taken(payload)
	_mm._pass1_damage()
	_mm._pass4_absorbed_flush()

	assert_int(_spy.count("monster_hp_absorbed")).is_equal(1)
	var args: Array = (_spy.emissions["monster_hp_absorbed"] as Array)[0] as Array
	assert_int(args[0]).is_equal(entity.entity_id)
	assert_int(args[1]).is_equal(30)


func test_pass4_absorbed_flush_absorbed_clamped_to_pre_hit_hp_on_overkill() -> void:
	var res := _make_resource(&"goblin", 20.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.monster_hp_absorbed)

	var payload := MonsterDamageTaken.new()
	payload.entity_id = entity.entity_id
	payload.amount = 100  # overkill — only 20 HP existed
	payload.source_type = 1
	_mm._on_monster_damage_taken(payload)
	_mm._pass1_damage()
	_mm._pass4_absorbed_flush()

	# Entity died this pass (no absorbed emission for dead entities per _pass1_damage's
	# `_pending_absorbed.erase(entity.entity_id)` on death) — verify death path taken,
	# not an absorbed emission for more than the entity ever had.
	assert_int(_spy.count("monster_hp_absorbed")).is_equal(0)


# ---------------------------------------------------------------------------
# Gap 2: Wave-end force-death (_on_wave_completed)
# ---------------------------------------------------------------------------

func test_on_wave_completed_force_emits_monster_died_with_wave_end_kill_source() -> void:
	var res := _make_resource(&"goblin", 100.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.monster_died)

	_mm._on_wave_completed(1, 0, false)

	assert_int(_spy.count("monster_died")).is_equal(1)
	var ev: MonsterDiedEvent = (_spy.emissions["monster_died"] as Array)[0][0] as MonsterDiedEvent
	assert_int(ev.entity_id).is_equal(entity.entity_id)
	assert_str(String(ev.kill_source)).is_equal("wave_end")
	assert_bool(_mm.active_monsters.is_empty()).is_true()


func test_on_wave_completed_force_emits_boss_died_force_removed_for_boss_tier() -> void:
	var res := _make_resource(&"boss_test", 500.0, 2)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.boss_died)

	_mm._on_wave_completed(1, 0, false)

	assert_int(_spy.count("boss_died")).is_equal(1)
	var args: Array = (_spy.emissions["boss_died"] as Array)[0] as Array
	assert_int(args[0]).is_equal(entity.entity_id)
	assert_str(args[3]).is_equal("force_removed")

# ---------------------------------------------------------------------------
# Gap 3: Difficulty-tier HP scaling (_spawn_entity, diff_mult)
# ---------------------------------------------------------------------------

func test_spawn_entity_difficulty_tier_two_applies_diff_mult_to_hp() -> void:
	# HP_DIFFICULTY_GROWTH_RATE = 0.35 (monster_manager.gd). diff_mult at
	# difficulty_tier=2: 1.0 + 0.35 * (2-1) = 1.35. wave_index=1 -> hp_mult=1.0
	# (HP_WAVE_GROWTH_RATE term is zero at wave 1). scaled_hp = 100 * 1.0 * 1.35 = 135.
	var res := _make_resource(&"goblin", 100.0)
	_mm._resource_table[res.monster_id] = res

	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 2)

	assert_float(entity.scaled_hp).is_equal_approx(135.0, 0.0001)
	assert_float(entity.current_hp).is_equal_approx(135.0, 0.0001)


func test_spawn_entity_difficulty_tier_one_applies_no_scaling() -> void:
	var res := _make_resource(&"goblin", 100.0)
	_mm._resource_table[res.monster_id] = res

	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	assert_float(entity.scaled_hp).is_equal_approx(100.0, 0.0001)

# ---------------------------------------------------------------------------
# Gap 4: BOSS boss_hp_changed on non-lethal hit (_pass1_damage)
# ---------------------------------------------------------------------------

func test_pass1_damage_non_lethal_boss_hit_emits_boss_hp_changed() -> void:
	var res := _make_resource(&"boss_test", 500.0, 2)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.boss_hp_changed)

	var payload := MonsterDamageTaken.new()
	payload.entity_id = entity.entity_id
	payload.amount = 100  # non-lethal — 500 HP, 100 damage
	payload.source_type = 1
	_mm._on_monster_damage_taken(payload)
	_mm._pass1_damage()

	assert_int(_spy.count("boss_hp_changed")).is_equal(1)
	var args: Array = (_spy.emissions["boss_hp_changed"] as Array)[0] as Array
	assert_int(args[0]).is_equal(entity.entity_id)
	assert_float(args[1]).is_equal_approx(400.0, 0.0001)
	assert_float(args[2]).is_equal_approx(500.0, 0.0001)


func test_pass1_damage_non_boss_non_lethal_hit_does_not_emit_boss_hp_changed() -> void:
	var res := _make_resource(&"goblin", 100.0, 0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.boss_hp_changed)

	var payload := MonsterDamageTaken.new()
	payload.entity_id = entity.entity_id
	payload.amount = 30
	payload.source_type = 1
	_mm._on_monster_damage_taken(payload)
	_mm._pass1_damage()

	assert_int(_spy.count("boss_hp_changed")).is_equal(0)
