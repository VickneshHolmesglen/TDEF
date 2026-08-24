## Integration tests for MonsterManager's swarm migration (ADR-0038, Epic 16
## Story 7 — "MonsterManager standard swarm migration"). Covers the story's
## own scope: STANDARD/ELITE monsters register with a real
## MonsterSwarmRenderer3D at spawn, sync position through the existing
## centralized _pass3c_visual_sync() pass, and unregister on death/breach/
## wave-clear (no leaked batch slots) — while BOSS keeps the legacy
## ADR-0037 3D mesh companion untouched, per this story's own tier gating.
##
## Uses the real, live GGameDataRegistry.get_creature_atlas_mapping()
## fixture (&"goblin_runner", standard-class, added Story 5) rather than an
## injected fake — MonsterSwarmRenderer3D has no injection seam by design
## (Story 6's own scope), matching this project's "end-to-end via the live
## autoload" precedent for cases that need real registry-backed lookups.
extends GdUnitTestSuite

const RendererScenePath: String = "res://src/core/visual_presentation/monster_swarm_renderer_3d.tscn"
const DELTA := 1.0 / 60.0
const SPAWN_CELL := Vector2i(0, 0)
const LONG_PATH: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0),
]

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


func _make_standard_resource(speed: float = 1.0) -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = &"goblin_runner"  # real Story 5 fixture: standard-class, presentation_class == standard
	res.display_name = "Goblin Runner"
	res.tier = 0
	res.base_hp = 100.0
	res.base_speed = speed
	res.drop_table_id = &"drops"
	res.menagerie_attraction_drop_chance = 0.0
	return res


func _make_boss_resource(speed: float = 1.0) -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = &"goblin_warlord_boss"  # real Story 5 fixture: exceptional-class
	res.display_name = "Goblin Warlord"
	res.tier = 2
	res.base_hp = 100.0
	res.base_speed = speed
	res.drop_table_id = &"drops"
	res.menagerie_attraction_drop_chance = 0.0
	return res


var _mm: MonsterManager
var _renderer: MonsterSwarmRenderer3D
var _stub_grid: _StubGrid
var _stub_path: _StubPathfinding


func before_test() -> void:
	_stub_grid = _StubGrid.new()
	_stub_path = _StubPathfinding.new()
	_stub_path.path = LONG_PATH.duplicate()

	var packed: PackedScene = load(RendererScenePath)
	_renderer = packed.instantiate() as MonsterSwarmRenderer3D
	add_child(_renderer)

	_mm = MonsterManager.new()
	add_child(_mm)
	_mm._grid = _stub_grid
	_mm._pathfinding = _stub_path
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	_mm.set_swarm_renderer(_renderer)


func after_test() -> void:
	for e: MonsterEntity in _mm.active_monsters:
		if is_instance_valid(e):
			e.free()
	for e: MonsterEntity in _mm.spawning_entities:
		if is_instance_valid(e):
			e.free()
	remove_child(_mm)
	_mm.free()
	remove_child(_renderer)
	_renderer.free()


# ---------------------------------------------------------------------------
# STANDARD/ELITE registers with the swarm renderer; BOSS does not
# ---------------------------------------------------------------------------

func test_standard_monster_spawn_registers_with_swarm_renderer() -> void:
	var res := _make_standard_resource(2.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	assert_object(entity).is_not_null()
	assert_object(entity.swarm_handle).is_not_null()
	assert_int(_renderer.get_total_live_count()).is_equal(1)


func test_standard_monster_spawn_builds_no_legacy_visual_companion() -> void:
	var res := _make_standard_resource(2.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	assert_object(entity.monster_instance).is_not_null()
	assert_object(entity.monster_instance.get_node_or_null("VisualCompanion3D")).is_null()


func test_boss_monster_spawn_does_not_register_with_swarm_renderer() -> void:
	var res := _make_boss_resource(1.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	assert_object(entity).is_not_null()
	assert_object(entity.swarm_handle).is_null()
	assert_int(_renderer.get_total_live_count()).is_equal(0)


func test_boss_monster_spawn_still_builds_legacy_visual_companion() -> void:
	var res := _make_boss_resource(1.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	assert_object(entity.monster_instance.get_node_or_null("VisualCompanion3D")).is_not_null()


# ---------------------------------------------------------------------------
# Position sync via the real centralized _physics_process()
# ---------------------------------------------------------------------------

func test_swarm_position_sync_moves_batch_slot_across_frames() -> void:
	var res := _make_standard_resource(2.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	var handle: MonsterPresentationHandle = entity.swarm_handle
	assert_object(handle).is_not_null()

	for frame: int in range(10):
		_mm._physics_process(DELTA)

	# Sanity: the monster actually moved (otherwise a position-sync bug that
	# just never updates anything would trivially "pass").
	assert_bool(entity.global_position != Vector2(0.0, 0.0)).is_true()
	assert_int(_renderer.get_live_count_for_batch(handle.batch_key)).is_equal(1)


# ---------------------------------------------------------------------------
# Unregistration on death / breach / wave-clear — no leaked batch slots
# ---------------------------------------------------------------------------

func test_death_unregisters_swarm_handle_no_leaked_slot() -> void:
	var res := _make_standard_resource(1.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	var batch_key: String = entity.swarm_handle.batch_key
	assert_int(_renderer.get_live_count_for_batch(batch_key)).is_equal(1)

	var dmg := MonsterDamageTaken.new()
	dmg.entity_id = entity.entity_id
	dmg.amount = 9999
	dmg.source_type = 0
	_mm._pending_damage.append(dmg)
	_mm._pass1_damage()

	assert_object(entity.swarm_handle).is_null()
	assert_int(_renderer.get_live_count_for_batch(batch_key)).is_equal(0)
	assert_int(_renderer.get_total_live_count()).is_equal(0)


func test_breach_unregisters_swarm_handle_no_leaked_slot() -> void:
	var res := _make_standard_resource(500.0)  # fast enough to reach GOAL in one Pass 3 call
	_mm._resource_table[res.monster_id] = res
	_stub_path.path = [Vector2i(1, 0)]
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	var batch_key: String = entity.swarm_handle.batch_key

	_mm._pass3_movement(DELTA)

	assert_int(entity.lifecycle_state).is_equal(MonsterEntity.State.BREACHED)
	assert_int(_renderer.get_live_count_for_batch(batch_key)).is_equal(0)


func test_wave_completed_unregisters_all_remaining_swarm_handles() -> void:
	var res := _make_standard_resource(1.0)
	_mm._resource_table[res.monster_id] = res
	for i: int in range(3):
		_mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	assert_int(_renderer.get_total_live_count()).is_equal(3)

	_mm._on_wave_completed(1, 0, false)

	assert_int(_renderer.get_total_live_count()).is_equal(0)


func test_batch_death_of_multiple_standard_monsters_leaks_no_slots() -> void:
	var res := _make_standard_resource(1.0)
	_mm._resource_table[res.monster_id] = res

	var entities: Array[MonsterEntity] = []
	for i: int in range(5):
		var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
		entities.append(entity)
		var dmg := MonsterDamageTaken.new()
		dmg.entity_id = entity.entity_id
		dmg.amount = 9999
		dmg.source_type = 0
		_mm._pending_damage.append(dmg)

	_mm._pass1_damage()

	for entity: MonsterEntity in entities:
		assert_object(entity.swarm_handle).is_null()
	assert_int(_renderer.get_total_live_count()).is_equal(0)
