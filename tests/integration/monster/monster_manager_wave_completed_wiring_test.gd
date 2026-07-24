extends GdUnitTestSuite

## Regression test: GEventBus.wave_completed -> MonsterManager._on_wave_completed
## signal wiring survives the current 3-arg signature (was_boss_breached: bool
## added by Story 002, epic-04-wave-manager).
##
## Flagged by Story 002's code review: monster_manager.gd had NO test coverage
## at all prior to this file (tests/unit/monster/*.gd call MonsterManager
## methods directly and never add_child() it, so _ready()'s EventBus
## subscriptions are never exercised). The exact class of bug this story
## caught mid-session — a signal signature change silently breaking a
## downstream subscriber's handler arity — had no automated guard for
## MonsterManager. This test goes through the REAL GEventBus.wave_completed
## signal (not a direct _on_wave_completed() call) so a future arity mismatch
## fails here instead of only being caught by manually running the full suite.
##
## Follows tests/integration/monster/monster_spawn_integration_test.gd's stub
## conventions (same _StubGrid / _StubPathfinding shape) and its add_child()
## pattern for triggering real _ready() EventBus subscriptions.

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
		return [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]


const SPAWN_CELL := Vector2i(0, 0)

var _mm: MonsterManager
var _stub_grid: _StubGrid
var _stub_path: _StubPathfinding


func _make_resource(id: StringName = &"goblin") -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = id
	res.display_name = "Goblin"
	res.tier = 0
	res.base_hp = 50.0
	res.base_speed = 1.0
	res.drop_table_id = &"goblin_drops"
	res.menagerie_attraction_drop_chance = 0.05
	return res


func before_test() -> void:
	_stub_grid = _StubGrid.new()
	_stub_path = _StubPathfinding.new()

	_mm = MonsterManager.new()
	add_child(_mm)  # triggers _ready() — GEventBus.wave_completed subscription is live
	_mm._grid = _stub_grid
	_mm._pathfinding = _stub_path
	_mm._resource_table[&"goblin"] = _make_resource()


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
# Real-signal wiring: emitting GEventBus.wave_completed with the current 3-arg
# signature must not raise "Method expected N argument(s)" and must actually
# invoke MonsterManager's real state changes.
# ---------------------------------------------------------------------------

func test_wave_completed_real_signal_sets_wave_inactive() -> void:
	_mm._is_wave_active = true

	GEventBus.wave_completed.emit(1, 0, false)

	assert_bool(_mm._is_wave_active).is_false()


## Proves the wiring survives with an active monster present too — the
## handler's downstream logic (force-removal death emission, entity cleanup)
## must still run correctly through the real signal path.
func test_wave_completed_real_signal_force_removes_active_monsters() -> void:
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	var entity: MonsterEntity = _mm.spawn_monster(&"goblin", SPAWN_CELL, 1, 0, 1.0)
	assert_that(entity).is_not_null()
	assert_int(_mm.active_monsters.size()).is_equal(1)

	var spy := EventBusSpy.new()
	spy.watch(GEventBus.monster_died)

	GEventBus.wave_completed.emit(1, 0, false)

	assert_bool(_mm._is_wave_active).is_false()
	assert_int(_mm.active_monsters.size()).is_equal(0)
	assert_bool(spy.was_emitted("monster_died")).is_true()
	var args: Array = (spy.emissions["monster_died"] as Array)[0]
	var payload: MonsterDiedEvent = args[0]
	assert_str(payload.kill_source).is_equal("wave_end")

	spy.disconnect_all()
