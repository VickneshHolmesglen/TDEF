## Unit tests for MonsterManager BOSS attack logic (AC-12, AC-13, AC-14).
##
## ADR-0006 Rule 17: Two sequential independent checks per pass —
##   (a) decrement boss_scan_frames_remaining if > 0
##   (b) check if <= 0 and execute scan
## boss_tower_attack_attempted fires after BOSS_ATTACK_PREPARE_FRAMES frames of prepare phase.
## GDScript 4 lambda closure rule: use Dictionary state boxes for mutable lambda state.
extends GdUnitTestSuite

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------

class _StubGrid extends RefCounted:
	var towers_in_range: Array[int] = [42]  # default: one tower in range

	func get_cell_type(_cell: Vector2i) -> int:
		return Grid.CellType.SPAWN

	func cell_to_world(cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x) * 64.0, float(cell.y) * 64.0)

	func world_to_cell(_pos: Vector2) -> Vector2i:
		return Vector2i(0, 0)

	func get_towers_in_range(_center: Vector2i, _radius: int) -> Array[int]:
		return towers_in_range


class _StubPathfinding extends RefCounted:
	func find_path(_from: Vector2i, _tier: int) -> Array[Vector2i]:
		return [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0),
				Vector2i(3,0), Vector2i(4,0), Vector2i(5,0),
				Vector2i(6,0), Vector2i(7,0), Vector2i(8,0), Vector2i(9,0)]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

const SPAWN_CELL := Vector2i(0, 0)
const DELTA := 1.0 / 60.0
const BOSS_PREPARE_FRAMES := 4  # matches MonsterManager.BOSS_ATTACK_PREPARE_FRAMES


func _make_boss_resource() -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = &"boss_test"
	res.display_name = "Test Boss"
	res.tier = 2
	res.base_hp = 1000.0
	res.base_speed = 0.5
	res.base_damage = 50.0
	res.base_attack_interval = 3.0
	res.boss_attack_range_cells = 3
	res.drop_table_id = &"boss_drops"
	res.menagerie_attraction_drop_chance = 0.1
	return res


var _mm: MonsterManager
var _stub_grid: _StubGrid
var _stub_path: _StubPathfinding


func before_test() -> void:
	_stub_grid = _StubGrid.new()
	_stub_path = _StubPathfinding.new()
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
# AC-12: boss_tower_attack_attempted fires after BOSS_ATTACK_PREPARE_FRAMES frames
# ---------------------------------------------------------------------------

func test_boss_attack_fires_after_prepare_frames() -> void:
	# Arrange
	var res := _make_boss_resource()
	_mm._resource_table[res.monster_id] = res
	var boss := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	# Boss spawns with scan_frames=0 and cooldown=0 — scan fires on first Pass 2
	# After scan: prepare phase entered (towers in range from stub)

	var state := {"attack_fired": false, "fired_on_frame": -1}
	GEventBus.boss_tower_attack_attempted.connect(
			func(_boss_id: int, _target_id: int, _dmg: float, _wave: int) -> void:
				state.attack_fired = true,
			CONNECT_ONE_SHOT)

	# Run BOSS_PREPARE_FRAMES - 1 frames — attack must NOT fire yet
	for _i in BOSS_PREPARE_FRAMES - 1:
		_mm._pass2_boss_logic(DELTA)
	assert_bool(state.attack_fired).is_false()

	# Run one more frame — attack must fire now
	_mm._pass2_boss_logic(DELTA)
	assert_bool(state.attack_fired).is_true()


func test_boss_attack_not_fired_before_prepare_frames_complete() -> void:
	var res := _make_boss_resource()
	_mm._resource_table[res.monster_id] = res
	_mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	var state := {"attack_fired": false}
	GEventBus.boss_tower_attack_attempted.connect(
			func(_boss_id: int, _target_id: int, _dmg: float, _wave: int) -> void:
				state.attack_fired = true,
			CONNECT_ONE_SHOT)

	# Run fewer than prepare frames — attack must not fire
	for _i in BOSS_PREPARE_FRAMES - 1:
		_mm._pass2_boss_logic(DELTA)

	assert_bool(state.attack_fired).is_false()

# ---------------------------------------------------------------------------
# AC-13: After attack fires, cooldown prevents second attack within base_attack_interval
# ---------------------------------------------------------------------------

func test_boss_attack_cooldown_prevents_immediate_second_attack() -> void:
	var res := _make_boss_resource()  # base_attack_interval = 3.0s
	_mm._resource_table[res.monster_id] = res
	_mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	var state := {"attack_count": 0}
	var _on_attack := func(_boss_id: int, _target_id: int, _dmg: float, _wave: int) -> void:
		state.attack_count += 1
	GEventBus.boss_tower_attack_attempted.connect(_on_attack)

	# First attack: run enough frames to trigger prepare and fire
	for _i in BOSS_PREPARE_FRAMES + 1:
		_mm._pass2_boss_logic(DELTA)

	assert_int(state.attack_count).is_equal(1)

	# Simulate less than base_attack_interval worth of frames (well within cooldown)
	# 3.0s cooldown at 60fps = 180 frames; run only 10 frames
	for _i in 10:
		_mm._pass2_boss_logic(DELTA)

	# Attack count must still be 1 — cooldown is blocking
	assert_int(state.attack_count).is_equal(1)

	GEventBus.boss_tower_attack_attempted.disconnect(_on_attack)


func test_boss_attack_fires_again_after_cooldown_expires() -> void:
	var res := _make_boss_resource()  # base_attack_interval = 3.0s
	_mm._resource_table[res.monster_id] = res
	_mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	var state := {"attack_count": 0}
	var _on_attack2 := func(_boss_id: int, _target_id: int, _dmg: float, _wave: int) -> void:
		state.attack_count += 1
	GEventBus.boss_tower_attack_attempted.connect(_on_attack2)

	# Trigger first attack
	for _i in BOSS_PREPARE_FRAMES + 1:
		_mm._pass2_boss_logic(DELTA)
	assert_int(state.attack_count).is_equal(1)

	# Drain cooldown: 3.0s / DELTA = 180 frames of large delta
	for _i in 200:
		_mm._pass2_boss_logic(DELTA)

	# Enough frames for second prepare cycle to complete
	for _i in BOSS_PREPARE_FRAMES + 2:
		_mm._pass2_boss_logic(DELTA)

	assert_int(state.attack_count).is_equal(2)
	GEventBus.boss_tower_attack_attempted.disconnect(_on_attack2)

# ---------------------------------------------------------------------------
# AC-14: BOSS movement never halted during attack sequence
# ---------------------------------------------------------------------------

func test_boss_movement_continues_during_attack_prepare() -> void:
	var res := _make_boss_resource()
	_mm._resource_table[res.monster_id] = res
	var boss := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	var initial_pos := boss.global_position

	# Trigger the prepare phase via boss logic
	_mm._pass2_boss_logic(DELTA)  # scan fires, prepare starts

	# Advance movement independently — boss must still move
	_mm._pass3_movement(DELTA)
	_mm._pass3_movement(DELTA)

	# Position must have changed (boss is not frozen during prepare)
	var moved := not boss.global_position.is_equal_approx(initial_pos)
	assert_bool(moved).is_true()


func test_boss_position_advances_while_attack_prepare_remaining_greater_than_zero() -> void:
	var res := _make_boss_resource()
	_mm._resource_table[res.monster_id] = res
	var boss := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	# Manually set prepare phase (simulates mid-prepare state)
	boss.boss_attack_prepare_remaining = BOSS_PREPARE_FRAMES
	boss.boss_locked_target_id = 42
	var pos_at_prepare_start := boss.global_position

	# Run movement (not boss logic — testing they're independent)
	for _i in 5:
		_mm._pass3_movement(DELTA)

	assert_bool(boss.global_position.is_equal_approx(pos_at_prepare_start)).is_false()
