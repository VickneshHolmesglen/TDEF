## Integration tests for MonsterManager — EventBus-driven spawn path (AC-1).
##
## Uses add_child() to trigger _ready() so EventBus subscriptions are live.
## GGrid and GPathfindingSystem are overridden with stubs after _ready() runs.
## GDScript 4 lambda closure rule: use Dictionary state boxes for mutable lambda state.
extends GdUnitTestSuite

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------

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
		return [Vector2i(1,0), Vector2i(2,0), Vector2i(3,0),
				Vector2i(4,0), Vector2i(5,0)]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

const SPAWN_CELL := Vector2i(0, 0)


func _make_resource(id: StringName = &"goblin") -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = id
	res.display_name = "Goblin"
	res.tier = 0
	res.base_hp = 100.0
	res.base_speed = 1.0
	res.drop_table_id = &"goblin_drops"
	res.menagerie_attraction_drop_chance = 0.05
	return res


var _mm: MonsterManager
var _stub_grid: _StubGrid
var _stub_path: _StubPathfinding


func before_test() -> void:
	_stub_grid = _StubGrid.new()
	_stub_path = _StubPathfinding.new()
	_mm = MonsterManager.new()
	add_child(_mm)  # triggers _ready() — EventBus subscriptions are live
	# Override injected autoloads with stubs after _ready() runs
	_mm._grid = _stub_grid
	_mm._pathfinding = _stub_path
	_mm._is_wave_active = true
	_mm._current_wave_index = 1


func after_test() -> void:
	for e: MonsterEntity in _mm.active_monsters:
		if is_instance_valid(e):
			e.free()
	for e: MonsterEntity in _mm.spawning_entities:
		if is_instance_valid(e):
			e.free()
	remove_child(_mm)
	_mm.free()

# ---------------------------------------------------------------------------
# AC-1: Valid monster_spawn_requested → entity in active_monsters, ACTIVE state,
#        monster_spawned fired exactly once with correct entity_id
# ---------------------------------------------------------------------------

func test_integration_valid_spawn_request_adds_entity_to_active_monsters() -> void:
	var res := _make_resource()
	_mm._resource_table[res.monster_id] = res

	var payload := MonsterSpawnRequest.new()
	payload.monster_id = res.monster_id
	payload.spawn_cell = SPAWN_CELL
	payload.wave_index = 1
	payload.difficulty_tier = 1
	payload.wave_reward_scalar = 1.0

	GEventBus.monster_spawn_requested.emit(payload)

	assert_int(_mm.active_monsters.size()).is_equal(1)


func test_integration_valid_spawn_request_entity_is_active_state() -> void:
	var res := _make_resource()
	_mm._resource_table[res.monster_id] = res

	var payload := MonsterSpawnRequest.new()
	payload.monster_id = res.monster_id
	payload.spawn_cell = SPAWN_CELL
	payload.wave_index = 1
	payload.difficulty_tier = 1
	payload.wave_reward_scalar = 1.0

	GEventBus.monster_spawn_requested.emit(payload)

	assert_int(_mm.active_monsters[0].lifecycle_state).is_equal(MonsterEntity.State.ACTIVE)


func test_integration_valid_spawn_request_emits_monster_spawned_with_valid_id() -> void:
	var res := _make_resource()
	_mm._resource_table[res.monster_id] = res

	var state := {"spawned_id": -1, "spawned_count": 0}
	GEventBus.monster_spawned.connect(
			func(ev: MonsterSpawnedEvent) -> void:
				state.spawned_id = ev.entity_id
				state.spawned_count += 1,
			CONNECT_ONE_SHOT)

	var payload := MonsterSpawnRequest.new()
	payload.monster_id = res.monster_id
	payload.spawn_cell = SPAWN_CELL
	payload.wave_index = 1
	payload.difficulty_tier = 1
	payload.wave_reward_scalar = 1.0

	GEventBus.monster_spawn_requested.emit(payload)

	assert_int(state.spawned_count).is_equal(1)
	assert_int(state.spawned_id).is_greater(0)


func test_integration_spawn_monster_id_in_event_matches_resource_id() -> void:
	var res := _make_resource(&"unique_goblin")
	_mm._resource_table[res.monster_id] = res

	var state := {"received_id": &""}
	GEventBus.monster_spawned.connect(
			func(ev: MonsterSpawnedEvent) -> void:
				state.received_id = ev.monster_id,
			CONNECT_ONE_SHOT)

	var payload := MonsterSpawnRequest.new()
	payload.monster_id = res.monster_id
	payload.spawn_cell = SPAWN_CELL
	payload.wave_index = 1
	payload.difficulty_tier = 1
	payload.wave_reward_scalar = 1.0

	GEventBus.monster_spawn_requested.emit(payload)

	assert_str(state.received_id).is_equal("unique_goblin")


func test_integration_invalid_spawn_request_unknown_id_emits_no_monster_spawned() -> void:
	var state := {"fired": false}
	GEventBus.monster_spawned.connect(
			func(_ev: MonsterSpawnedEvent) -> void: state.fired = true,
			CONNECT_ONE_SHOT)

	var payload := MonsterSpawnRequest.new()
	payload.monster_id = &"does_not_exist"
	payload.spawn_cell = SPAWN_CELL
	payload.wave_index = 1
	payload.difficulty_tier = 1
	payload.wave_reward_scalar = 1.0

	GEventBus.monster_spawn_requested.emit(payload)

	assert_bool(state.fired).is_false()
	assert_int(_mm.active_monsters.size()).is_equal(0)
