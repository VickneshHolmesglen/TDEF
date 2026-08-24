## Integration tests for BossCreaturePresenter3D (ADR-0038, Epic 16 Story 9
## — "Boss/elite exceptional path") and its MonsterManager wiring: register/
## update/unregister against the pool directly, capacity/duplicate/unmapped
## rejection, attack-telegraph overlay visibility, and the full spawn ->
## sync -> death lifecycle through a real MonsterManager.
extends GdUnitTestSuite

const RendererScenePath: String = "res://src/core/visual_presentation/monster_swarm_renderer_3d.tscn"
const DELTA := 1.0 / 60.0
const SPAWN_CELL := Vector2i(0, 0)
const LONG_PATH: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]

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
	var path: Array[Vector2i] = []

	func find_path(_from: Vector2i, _tier: int) -> Array[Vector2i]:
		return path


func _make_boss_resource(monster_id: StringName = &"goblin_warlord_boss", speed: float = 1.0) -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = monster_id
	res.display_name = "Test Boss"
	res.tier = 2
	res.base_hp = 1000.0
	res.base_speed = speed
	res.drop_table_id = &"drops"
	res.menagerie_attraction_drop_chance = 0.0
	return res


var _renderer: MonsterSwarmRenderer3D


func before_test() -> void:
	var packed: PackedScene = load(RendererScenePath)
	_renderer = packed.instantiate() as MonsterSwarmRenderer3D
	add_child(_renderer)


func after_test() -> void:
	remove_child(_renderer)
	_renderer.free()


# ---------------------------------------------------------------------------
# Direct pool tests
# ---------------------------------------------------------------------------

func test_register_boss_succeeds_and_returns_valid_handle() -> void:
	var handle: MonsterPresentationHandle = _renderer.register_boss(1, &"goblin_warlord_boss", Transform3D.IDENTITY)
	assert_object(handle).is_not_null()
	assert_int(handle.entity_id).is_equal(1)
	assert_int(_renderer.get_boss_live_count()).is_equal(1)


func test_register_boss_duplicate_entity_id_rejected() -> void:
	_renderer.register_boss(1, &"goblin_warlord_boss", Transform3D.IDENTITY)
	var second: MonsterPresentationHandle = _renderer.register_boss(1, &"goblin_warlord_boss", Transform3D.IDENTITY)
	assert_object(second).is_null()
	assert_int(_renderer.get_boss_live_count()).is_equal(1)


func test_register_boss_beyond_capacity_rejected() -> void:
	# BossCreaturePresenter3D.CAPACITY == 2 — register 3, the 3rd must fail.
	var h1: MonsterPresentationHandle = _renderer.register_boss(1, &"goblin_warlord_boss", Transform3D.IDENTITY)
	var h2: MonsterPresentationHandle = _renderer.register_boss(2, &"rift_sentinel_boss", Transform3D.IDENTITY)
	var h3: MonsterPresentationHandle = _renderer.register_boss(3, &"goblin_warlord_boss", Transform3D.IDENTITY)
	assert_object(h1).is_not_null()
	assert_object(h2).is_not_null()
	assert_object(h3).is_null()
	assert_int(_renderer.get_boss_live_count()).is_equal(2)


func test_register_boss_unmapped_monster_id_rejected() -> void:
	var handle: MonsterPresentationHandle = _renderer.register_boss(1, &"nonexistent_boss", Transform3D.IDENTITY)
	assert_object(handle).is_null()
	assert_int(_renderer.get_boss_live_count()).is_equal(0)


func test_update_boss_toggles_overlay_visibility_with_attack_telegraph() -> void:
	var handle: MonsterPresentationHandle = _renderer.register_boss(1, &"goblin_warlord_boss", Transform3D.IDENTITY)
	var moved := Transform3D(Basis(), Vector3(5.0, 0.0, 5.0))

	var ok_on: bool = _renderer.update_boss(handle, moved, true)
	assert_bool(ok_on).is_true()
	var slot: int = _renderer._boss_presenter._entity_to_slot[handle.entity_id]
	assert_bool(_renderer._boss_presenter._overlay_layers[slot].visible).is_true()
	assert_vector(_renderer._boss_presenter._slots[slot].global_position).is_equal(moved.origin)

	var ok_off: bool = _renderer.update_boss(handle, moved, false)
	assert_bool(ok_off).is_true()
	assert_bool(_renderer._boss_presenter._overlay_layers[slot].visible).is_false()


func test_update_boss_stale_handle_returns_false() -> void:
	var handle: MonsterPresentationHandle = _renderer.register_boss(1, &"goblin_warlord_boss", Transform3D.IDENTITY)
	_renderer.unregister_boss(handle)
	var updated: bool = _renderer.update_boss(handle, Transform3D.IDENTITY, false)
	assert_bool(updated).is_false()


func test_unregister_boss_frees_slot_and_hides_layers() -> void:
	var handle: MonsterPresentationHandle = _renderer.register_boss(1, &"goblin_warlord_boss", Transform3D.IDENTITY)
	var slot: int = _renderer._boss_presenter._entity_to_slot[handle.entity_id]

	var removed: bool = _renderer.unregister_boss(handle)
	assert_bool(removed).is_true()
	assert_int(_renderer.get_boss_live_count()).is_equal(0)
	assert_bool(_renderer._boss_presenter._slots[slot].visible).is_false()
	assert_bool(_renderer._boss_presenter._overlay_layers[slot].visible).is_false()

	# The freed slot must be reusable by a fresh registration.
	var reused: MonsterPresentationHandle = _renderer.register_boss(2, &"rift_sentinel_boss", Transform3D.IDENTITY)
	assert_object(reused).is_not_null()


# ---------------------------------------------------------------------------
# Full MonsterManager integration: spawn -> sync -> death
# ---------------------------------------------------------------------------

var _mm: MonsterManager
var _stub_grid: _StubGrid
var _stub_path: _StubPathfinding


func _spawn_mm() -> void:
	_stub_grid = _StubGrid.new()
	_stub_path = _StubPathfinding.new()
	_stub_path.path = LONG_PATH.duplicate()
	_mm = MonsterManager.new()
	add_child(_mm)
	_mm._grid = _stub_grid
	_mm._pathfinding = _stub_path
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	_mm.set_swarm_renderer(_renderer)


func _free_mm() -> void:
	for e: MonsterEntity in _mm.active_monsters:
		if is_instance_valid(e):
			e.free()
	for e: MonsterEntity in _mm.spawning_entities:
		if is_instance_valid(e):
			e.free()
	remove_child(_mm)
	_mm.free()


func test_boss_spawn_registers_with_presenter_pool_not_swarm_batches() -> void:
	_spawn_mm()
	var res := _make_boss_resource()
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	assert_object(entity.boss_presenter_handle).is_not_null()
	assert_object(entity.swarm_handle).is_null()
	assert_int(_renderer.get_boss_live_count()).is_equal(1)
	assert_int(_renderer.get_total_live_count()).is_equal(0)
	_free_mm()


func test_boss_attack_prepare_shows_overlay_via_physics_process() -> void:
	_spawn_mm()
	var res := _make_boss_resource(&"goblin_warlord_boss", 0.001)  # negligible movement
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	entity.boss_attack_prepare_remaining = 4
	_mm._physics_process(DELTA)

	var slot: int = _renderer._boss_presenter._entity_to_slot[entity.entity_id]
	assert_bool(_renderer._boss_presenter._overlay_layers[slot].visible).is_true()

	entity.boss_attack_prepare_remaining = 0
	_mm._physics_process(DELTA)
	assert_bool(_renderer._boss_presenter._overlay_layers[slot].visible).is_false()
	_free_mm()


func test_boss_death_unregisters_from_presenter_pool() -> void:
	_spawn_mm()
	var res := _make_boss_resource()
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	assert_int(_renderer.get_boss_live_count()).is_equal(1)

	var dmg := MonsterDamageTaken.new()
	dmg.entity_id = entity.entity_id
	dmg.amount = 99999
	dmg.source_type = 0
	_mm._pending_damage.append(dmg)
	_mm._pass1_damage()

	assert_object(entity.boss_presenter_handle).is_null()
	assert_int(_renderer.get_boss_live_count()).is_equal(0)
	_free_mm()
