extends GdUnitTestSuite

## Integration test: WaveManager driving MonsterManager through a full
## spawn -> monster_spawned -> monster_died -> INTERMISSION cycle.
## Design source: production/stories/core/s3-06-wave-manager-phase1.md
##
## Uses add_child() on both managers to trigger _ready() so EventBus
## subscriptions are live on both sides (mirrors monster_spawn_integration_test.gd).

# ---------------------------------------------------------------------------
# Stubs (same shape as tests/integration/monster/monster_spawn_integration_test.gd)
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
		return [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

const SPAWN_CELL := Vector2i(0, 0)

var _wm: WaveManager
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
	add_child(_mm)  # triggers _ready() — MonsterManager subscriptions are live
	_mm._grid = _stub_grid
	_mm._pathfinding = _stub_path
	_mm._resource_table[&"goblin"] = _make_resource()
	_mm._is_wave_active = true
	_mm._current_wave_index = 1

	_wm = WaveManager.new()
	add_child(_wm)  # triggers _ready() — WaveManager subscriptions are live
	# Story 007 (round-robin-spawn-cells): _resolve_spawn_cell() now requires a
	# non-empty _spawn_cells (previously this suite relied on the flat, now-dead
	# _spawn_cell placeholder field).
	_wm._spawn_cells = [SPAWN_CELL]
	_wm._templates_ready = true


func after_test() -> void:
	for e: MonsterEntity in _mm.active_monsters:
		if is_instance_valid(e):
			e.free()
	for e: MonsterEntity in _mm.spawning_entities:
		if is_instance_valid(e):
			e.free()
	remove_child(_mm)
	_mm.free()
	remove_child(_wm)
	_wm.free()

# ---------------------------------------------------------------------------
# Full spawn cycle: WAVE_ACTIVE entry -> monster_spawn_requested ->
# MonsterManager spawns entity -> monster_spawned -> WaveManager increments
# _enemies_alive.
# ---------------------------------------------------------------------------

func test_wave_active_entry_spawns_monster_via_monster_manager() -> void:
	_wm._wave_spawn_entries = [WaveSpawnEntry.new(&"goblin", 0.0)]

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_int(_mm.active_monsters.size()).is_equal(1)
	assert_int(_wm._enemies_alive).is_equal(1)
	assert_bool(_wm._all_spawns_fired).is_true()


func test_full_spawn_cycle_multiple_entries_tracks_enemies_alive() -> void:
	_wm._wave_spawn_entries = [
		WaveSpawnEntry.new(&"goblin", 0.0),
		WaveSpawnEntry.new(&"goblin", 0.0),
	]

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_int(_mm.active_monsters.size()).is_equal(2)
	assert_int(_wm._enemies_alive).is_equal(2)

# ---------------------------------------------------------------------------
# Full cycle including death: kill the spawned entity through MonsterManager's
# real damage pipeline (_on_monster_damage_taken + _pass1_damage) and confirm
# WaveManager decrements _enemies_alive and transitions to INTERMISSION.
# ---------------------------------------------------------------------------

func test_full_spawn_cycle_monster_death_triggers_intermission() -> void:
	_wm._wave_spawn_entries = [WaveSpawnEntry.new(&"goblin", 0.0)]
	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_int(_wm._enemies_alive).is_equal(1)
	assert_bool(_wm._all_spawns_fired).is_true()

	var entity: MonsterEntity = _mm.active_monsters[0]
	var dmg := MonsterDamageTaken.new()
	dmg.entity_id = entity.entity_id
	dmg.amount = 9999
	dmg.source_type = 1

	_mm._on_monster_damage_taken(dmg)
	# Run the full 4-pass cycle (not just _pass1_damage) so pass 3's swap-buffer
	# rebuild removes the now-DEAD entity from active_monsters in the same call.
	# Calling _pass1_damage() alone leaves a stale reference in active_monsters;
	# the entity's queue_free() resolves before the next real physics frame,
	# and MonsterManager's own _physics_process() then touches a freed object.
	_mm._physics_process(0.016)

	assert_int(_wm._enemies_alive).is_equal(0)
	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)
