## Unit tests for MonsterManager movement and DEAD-priority (AC-8, AC-9, AC-11, AC-17).
##
## Calls _pass1_damage() and _pass3_movement() directly to control frame simulation.
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

	func world_to_cell(pos: Vector2) -> Vector2i:
		return Vector2i(int(pos.x / 64.0), int(pos.y / 64.0))

	func get_towers_in_range(_center: Vector2i, _radius: int) -> Array[int]:
		return []


class _StubPathfinding extends RefCounted:
	var path: Array[Vector2i] = []

	func find_path(_from: Vector2i, _tier: int) -> Array[Vector2i]:
		return path


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

const SPAWN_CELL := Vector2i(0, 0)
const DELTA := 1.0 / 60.0

## 10-step path. Starts at Vector2i(1,0) — the first cell to MOVE TO.
## Spawn cell (0,0) is excluded; the entity begins at world(0,0) and this
## is the first movement target, consistent with PathfindingSystem contract.
const LONG_PATH: Array[Vector2i] = [
	Vector2i(1,0), Vector2i(2,0), Vector2i(3,0), Vector2i(4,0), Vector2i(5,0),
	Vector2i(6,0), Vector2i(7,0), Vector2i(8,0), Vector2i(9,0), Vector2i(10,0),
]


func _make_resource(speed: float = 1.0) -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = &"mover"
	res.display_name = "Mover"
	res.tier = 0
	res.base_hp = 100.0
	res.base_speed = speed
	res.drop_table_id = &"drops"
	res.menagerie_attraction_drop_chance = 0.0
	return res


var _mm: MonsterManager
var _stub_grid: _StubGrid
var _stub_path: _StubPathfinding


func before_test() -> void:
	_stub_grid = _StubGrid.new()
	_stub_path = _StubPathfinding.new()
	_stub_path.path = LONG_PATH.duplicate()
	_mm = MonsterManager.new()
	# TD-monster-003 fix: add_child() BEFORE overriding DI seams — see
	# monster_spawn_test.gd's before_test() comment for the full rationale.
	add_child(_mm)
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
# AC-8: 120 frames at delta=1/60, speed=2.0 cells/sec → path_step_index == 4
# ---------------------------------------------------------------------------

func test_monster_movement_120_frames_at_2_cells_per_sec_advances_4_steps() -> void:
	# Arrange
	var res := _make_resource(2.0)  # 2.0 cells/sec
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	# Entity spawns at world(0,0). path[0]=(64,0) = first movement target.
	# 120 frames × (1/60)s = 2.0s. 2.0 cells/sec × 2.0s = 4 cells → step_index 4.

	for _i in 120:
		_mm._pass3_movement(DELTA)

	# 4 arrivals: path[0]→1, path[1]→2, path[2]→3, path[3]→4
	assert_int(entity.path_step_index).is_equal(4)

# ---------------------------------------------------------------------------
# AC-9: Path exhausted with hp > 0 → BREACHED; monster_breached fires; monster_died NOT
# ---------------------------------------------------------------------------

func test_monster_movement_path_exhausted_alive_sets_breached_state() -> void:
	var res := _make_resource(100.0)  # Very fast — will reach goal in one frame
	_mm._resource_table[res.monster_id] = res
	_stub_path.path = [Vector2i(0,0), Vector2i(1,0)]
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	entity.current_hp = 50.0  # Alive

	_mm._pass3_movement(DELTA)

	assert_int(entity.lifecycle_state).is_equal(MonsterEntity.State.BREACHED)


func test_monster_movement_breach_emits_monster_breached_signal() -> void:
	var res := _make_resource(100.0)
	_mm._resource_table[res.monster_id] = res
	_stub_path.path = [Vector2i(0,0), Vector2i(1,0)]
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	entity.current_hp = 50.0

	var state := {"breached": false}
	GEventBus.monster_breached.connect(
			func(_id: int, _mid: StringName, _tier: int) -> void: state.breached = true,
			CONNECT_ONE_SHOT)
	_mm._pass3_movement(DELTA)

	assert_bool(state.breached).is_true()


func test_monster_movement_breach_does_not_emit_monster_died() -> void:
	var res := _make_resource(100.0)
	_mm._resource_table[res.monster_id] = res
	_stub_path.path = [Vector2i(0,0), Vector2i(1,0)]
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	entity.current_hp = 50.0

	var state := {"died": false}
	var _on_died := func(_ev: MonsterDiedEvent) -> void: state.died = true
	GEventBus.monster_died.connect(_on_died)
	_mm._pass3_movement(DELTA)

	assert_bool(state.died).is_false()
	GEventBus.monster_died.disconnect(_on_died)

# ---------------------------------------------------------------------------
# AC-11: Overshoot — high speed advances path_step_index by correct amount
# ---------------------------------------------------------------------------

func test_monster_movement_overshoot_increments_step_by_correct_amount() -> void:
	# speed=10 cells/sec, delta=1/60 → budget ≈ 0.167 cells worth of world units
	# Actually budget = 10 * 64 * (1/60) ≈ 10.67 world units
	# Path cells are 64 world units apart, so at speed=10 we travel ~10.67/64 ≈ 0.17 cells per frame
	# At speed=100: budget = 100 * 64 * (1/60) ≈ 106.7 units per frame → ~1.67 cells per frame
	# Use speed=200: budget = 200 * 64 / 60 ≈ 213 units → ~3.33 cells per frame (3 steps)
	var res := _make_resource(200.0)
	_mm._resource_table[res.monster_id] = res
	_stub_path.path = LONG_PATH.duplicate()
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	var initial_step := entity.path_step_index

	_mm._pass3_movement(DELTA)

	# Should have advanced at least 2 steps (overshoot confirmed)
	assert_int(entity.path_step_index).is_greater(initial_step + 1)


func test_monster_movement_overshoot_to_goal_triggers_breach() -> void:
	# Short path + high speed = goal reached within single frame
	var res := _make_resource(200.0)
	_mm._resource_table[res.monster_id] = res
	_stub_path.path = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)]
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	entity.current_hp = 50.0

	_mm._pass3_movement(DELTA)

	assert_int(entity.lifecycle_state).is_equal(MonsterEntity.State.BREACHED)

# ---------------------------------------------------------------------------
# AC-17: DEAD-priority — lethal hit in Pass 1 prevents breach in Pass 3
# ---------------------------------------------------------------------------

func test_monster_dead_priority_lethal_damage_prevents_breach() -> void:
	# Arrange: entity at last step of a short path
	var res := _make_resource(200.0)  # fast enough to reach goal in one frame
	_mm._resource_table[res.monster_id] = res
	_stub_path.path = [Vector2i(0,0), Vector2i(1,0)]
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	entity.current_hp = 10.0

	# Inject lethal damage into pending buffer
	var dmg := MonsterDamageTaken.new()
	dmg.entity_id = entity.entity_id
	dmg.amount = 9999
	dmg.source_type = 0
	_mm._pending_damage.append(dmg)

	# Track signals
	var state := {"breached": false, "died": false}
	var _on_breach := func(_id: int, _mid: StringName, _tier: int) -> void: state.breached = true
	var _on_died2 := func(_ev: MonsterDiedEvent) -> void: state.died = true
	GEventBus.monster_breached.connect(_on_breach)
	GEventBus.monster_died.connect(_on_died2, CONNECT_ONE_SHOT)

	# Act: Pass 1 sets DEAD, Pass 3 skips DEAD
	_mm._pass1_damage()
	_mm._pass3_movement(DELTA)

	# Assert
	assert_int(entity.lifecycle_state).is_equal(MonsterEntity.State.DEAD)
	assert_bool(state.breached).is_false()
	assert_bool(state.died).is_true()
	# Explicit disconnect for the negative-fire signal (CONNECT_ONE_SHOT only fires on emission)
	if GEventBus.monster_breached.is_connected(_on_breach):
		GEventBus.monster_breached.disconnect(_on_breach)


func test_monster_dead_priority_entity_removed_from_active_after_pass3() -> void:
	var res := _make_resource(1.0)
	_mm._resource_table[res.monster_id] = res
	_stub_path.path = LONG_PATH.duplicate()
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	var dmg := MonsterDamageTaken.new()
	dmg.entity_id = entity.entity_id
	dmg.amount = 9999
	dmg.source_type = 0
	_mm._pending_damage.append(dmg)

	_mm._pass1_damage()
	_mm._pass3_movement(DELTA)

	assert_int(_mm.active_monsters.size()).is_equal(0)
