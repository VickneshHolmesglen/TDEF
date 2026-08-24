## Integration tests for real per-instance channel wiring (ADR-0038, Epic 16
## Story 8 — "Hit/status/death presentation migration"). Covers hit_flash
## decay, status_mask (DoT/slow presence), and facing_variant for
## swarm-registered (STANDARD/ELITE) monsters — replacing Story 7's
## hardcoded 0.0 placeholders with real manager-computed state.
##
## Death presentation is explicitly NOT covered here — see this story's own
## Out of Scope section: MonsterDeathVFX (src/scenes/monster_death_vfx.gd)
## already provides fully independent, per-tier death VFX spawned from
## mission_scene.gd's monster_died/monsters_died_batch handlers, completely
## decoupled from MonsterManager/MonsterInstance/the swarm renderer — there
## is nothing for this story to migrate there.
##
## Reads back real MultiMesh custom-data via the renderer's own batch
## internals (reach-in on underscore-prefixed state — established test
## convention in this project, e.g. game_data_registry_test.gd's own header
## note) to prove the computed channel values actually reach the render
## buffer, not just that the manager-side computation looks right in
## isolation.
extends GdUnitTestSuite

const RendererScenePath: String = "res://src/core/visual_presentation/monster_swarm_renderer_3d.tscn"
const DELTA := 1.0 / 60.0
const SPAWN_CELL := Vector2i(0, 0)
const RIGHTWARD_PATH: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const LEFTWARD_PATH: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(-2, 0), Vector2i(-3, 0)]

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
	res.monster_id = &"goblin_runner"
	res.display_name = "Goblin Runner"
	res.tier = 0
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
	_stub_path.path = RIGHTWARD_PATH.duplicate()

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


## Reads INSTANCE_CUSTOM back for entity's own slot, straight from the real
## body MultiMesh the renderer allocated for it.
func _read_custom_data(entity: MonsterEntity) -> Color:
	var handle: MonsterPresentationHandle = entity.swarm_handle
	var batch: MonsterSwarmBatch = _renderer._batches[handle.batch_key]
	var slot: int = batch._entity_to_slot[handle.entity_id]
	return batch._body_multimesh.get_instance_custom_data(slot)


# ---------------------------------------------------------------------------
# hit_flash channel
# ---------------------------------------------------------------------------

func test_hit_sets_and_the_frame_after_slightly_decays_swarm_hit_flash() -> void:
	var res := _make_standard_resource(1.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	var dmg := MonsterDamageTaken.new()
	dmg.entity_id = entity.entity_id
	dmg.amount = 10.0
	dmg.source_type = 0
	_mm._pending_damage.append(dmg)
	_mm._physics_process(DELTA)

	var custom := _read_custom_data(entity)
	# One frame of decay has already been applied inside _pass3c_visual_sync()
	# this same tick, so the readback is just under 1.0, not exactly 1.0.
	assert_float(custom.y).is_between(0.9, 1.0)


func test_hit_flash_reaches_zero_after_the_full_duration_elapses() -> void:
	var res := _make_standard_resource(0.001)  # negligible movement so path doesn't finish mid-test
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	var dmg := MonsterDamageTaken.new()
	dmg.entity_id = entity.entity_id
	dmg.amount = 10.0
	dmg.source_type = 0
	_mm._pending_damage.append(dmg)

	var frames_needed: int = ceili(MonsterInstance.HIT_FLASH_DURATION / DELTA) + 2
	for i: int in range(frames_needed):
		_mm._physics_process(DELTA)

	var custom := _read_custom_data(entity)
	assert_float(custom.y).is_equal_approx(0.0, 0.001)


# ---------------------------------------------------------------------------
# status_mask channel
# ---------------------------------------------------------------------------

func test_status_mask_set_while_a_dot_effect_is_active() -> void:
	var res := _make_standard_resource(0.001)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	entity.active_status_effects.append(_make_dot_effect())
	_mm._physics_process(DELTA)

	var custom := _read_custom_data(entity)
	assert_float(custom.z).is_equal_approx(1.0, 0.001)


func test_status_mask_set_while_a_slow_effect_is_active() -> void:
	var res := _make_standard_resource(0.001)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	var slow := ActiveSlowEffect.new()
	slow.remaining_duration = 5.0
	slow.speed_multiplier = 0.5
	entity.active_slow_effects.append(slow)
	_mm._physics_process(DELTA)

	var custom := _read_custom_data(entity)
	assert_float(custom.z).is_equal_approx(1.0, 0.001)


func test_status_mask_clears_once_no_effects_remain() -> void:
	var res := _make_standard_resource(0.001)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	_mm._physics_process(DELTA)  # no effects at all this frame

	var custom := _read_custom_data(entity)
	assert_float(custom.z).is_equal_approx(0.0, 0.001)


func _make_dot_effect() -> ActiveStatusEffect:
	var effect := ActiveStatusEffect.new()
	effect.effect_type = "burn"
	effect.ticks_remaining = 5
	effect.tick_interval_remaining = 1.0
	effect.tick_damage = 1.0
	return effect


# ---------------------------------------------------------------------------
# facing_variant channel
# ---------------------------------------------------------------------------

func test_facing_variant_is_right_facing_moving_toward_positive_x() -> void:
	_stub_path.path = RIGHTWARD_PATH.duplicate()
	var res := _make_standard_resource(2.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	_mm._physics_process(DELTA)

	assert_bool(entity.facing_left).is_false()
	var custom := _read_custom_data(entity)
	assert_float(custom.w).is_equal_approx(0.0, 0.001)


func test_facing_variant_is_left_facing_moving_toward_negative_x() -> void:
	_stub_path.path = LEFTWARD_PATH.duplicate()
	var res := _make_standard_resource(2.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	_mm._physics_process(DELTA)

	assert_bool(entity.facing_left).is_true()
	var custom := _read_custom_data(entity)
	assert_float(custom.w).is_equal_approx(1.0, 0.001)
