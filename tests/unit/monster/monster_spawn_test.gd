## Unit tests for MonsterManager spawn logic (AC-1 to AC-7, excluding AC-1 which is integration).
##
## Tests call MonsterManager methods directly — no EventBus subscription needed.
## _grid and _pathfinding are injected as stubs via the public injection seam.
## GDScript 4 lambda closure rule: use Dictionary state boxes for mutable lambda state.
extends GdUnitTestSuite

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------

class _StubGrid extends RefCounted:
	var spawn_cell_type: int = Grid.CellType.SPAWN

	func get_cell_type(_cell: Vector2i) -> int:
		return spawn_cell_type

	func cell_to_world(cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x) * 64.0, float(cell.y) * 64.0)

	func world_to_cell(pos: Vector2) -> Vector2i:
		return Vector2i(int(pos.x / 64.0), int(pos.y / 64.0))

	func get_towers_in_range(_center: Vector2i, _radius: int) -> Array[int]:
		return []


class _StubPathfinding extends RefCounted:
	var return_empty: bool = false

	func find_path(_from: Vector2i, _tier: int) -> Array[Vector2i]:
		if return_empty:
			return []
		return [Vector2i(1,0), Vector2i(2,0), Vector2i(3,0), Vector2i(4,0), Vector2i(5,0)]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

const SPAWN_CELL := Vector2i(0, 0)

func _make_resource(
		id: StringName = &"goblin",
		base_hp: float = 100.0,
		base_speed: float = 1.0,
		tier: int = 0) -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = id
	res.display_name = "Test Monster"
	res.tier = tier
	res.base_hp = base_hp
	res.base_speed = base_speed
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
	# TD-monster-003 fix: add_child() BEFORE overriding DI seams — add_child()
	# triggers _ready(), which unconditionally sets _grid/_pathfinding to the
	# real GGrid/GPathfindingSystem autoloads; the stub overrides below must run
	# after that, matching the established pattern in combat_loop_test.gd etc.
	# Adding _mm to the tree is what lets spawned entities (now real children of
	# _mm via _spawn_entity()'s add_child()) be reachable from the live scene
	# tree — without this, entities would still show as orphans despite having
	# a parent, since that parent (_mm) itself was never in the tree.
	add_child(_mm)
	_mm._grid = _stub_grid
	_mm._pathfinding = _stub_path
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	# S5-01: _ready() (triggered by add_child() above) self-populates
	# _resource_table from the real GGameDataRegistry autoload when empty —
	# reset it back to {} here so every test in this file starts from a clean,
	# disk-independent table regardless of what production monster data
	# happens to exist. test_ready_self_populates_resource_table_from_game_data_registry_when_empty()
	# below is the one test that deliberately checks the pre-reset state
	# instead, via its own fresh MonsterManager instance.
	_mm._resource_table = {}


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
# AC-2: Unknown monster_id → null returned, active_monsters unchanged
# ---------------------------------------------------------------------------

func test_monster_spawn_unknown_id_returns_null() -> void:
	var result := _mm.spawn_monster(&"unknown_monster", SPAWN_CELL, 1, 1)
	assert_object(result).is_null()


func test_monster_spawn_unknown_id_does_not_add_to_active_list() -> void:
	_mm.spawn_monster(&"unknown_monster", SPAWN_CELL, 1, 1)
	assert_int(_mm.active_monsters.size()).is_equal(0)


# ---------------------------------------------------------------------------
# S5-01: _ready() self-populates _resource_table from GGameDataRegistry when
# empty (closes TD-data-001). Uses its own dedicated MonsterManager instance
# (not the shared _mm fixture, whose before_test() deliberately resets
# _resource_table back to {} after add_child() so the rest of this file's
# tests stay independent of real disk content) — this instance IS added to
# the tree specifically to exercise the production self-populate branch
# before anything resets it.
# ---------------------------------------------------------------------------

func test_ready_self_populates_resource_table_from_game_data_registry_when_empty() -> void:
	var mm := MonsterManager.new()
	add_child(mm)
	assert_bool(mm._resource_table.has(&"goblin_runner")).is_true()
	assert_bool(mm._resource_table.has(&"forest_troll_elite")).is_true()
	assert_bool(mm._resource_table.has(&"goblin_warlord_boss")).is_true()
	remove_child(mm)
	mm.free()

# ---------------------------------------------------------------------------
# AC-3: Non-SPAWN cell → null returned, active_monsters unchanged
# ---------------------------------------------------------------------------

func test_monster_spawn_path_cell_returns_null() -> void:
	var res := _make_resource()
	_mm._resource_table[res.monster_id] = res
	_stub_grid.spawn_cell_type = Grid.CellType.PATH
	var result := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	assert_object(result).is_null()


func test_monster_spawn_non_spawn_cell_does_not_add_entity() -> void:
	var res := _make_resource()
	_mm._resource_table[res.monster_id] = res
	_stub_grid.spawn_cell_type = Grid.CellType.GOAL
	_mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	assert_int(_mm.active_monsters.size()).is_equal(0)

# ---------------------------------------------------------------------------
# AC-4: HP scaling formula — wave 4, difficulty 1, rate 0.15 → 435.0 exactly
# ---------------------------------------------------------------------------

func test_monster_spawn_hp_scaling_wave4_normal_equals_435() -> void:
	# scaled_hp = 300 × (1 + 0.15 × 3) × (1 + 0.35 × 0) = 300 × 1.45 × 1.0 = 435.0
	# Use is_between to absorb float rounding in intermediate products.
	var res := _make_resource(&"elite", 300.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 4, 1)
	assert_float(entity.scaled_hp).is_between(434.99, 435.01)


func test_monster_spawn_hp_scaling_wave1_normal_equals_base_hp() -> void:
	var res := _make_resource(&"wave1", 200.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	assert_float(entity.scaled_hp).is_equal(200.0)


func test_monster_spawn_current_hp_initialized_to_scaled_hp() -> void:
	var res := _make_resource(&"hp_check", 300.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 4, 1)
	assert_float(entity.current_hp).is_equal(entity.scaled_hp)

# ---------------------------------------------------------------------------
# AC-5: Speed scaling formula — wave 4, rate 0.06, tarot 1.0 → 1.77 ±0.001
# ---------------------------------------------------------------------------

func test_monster_spawn_speed_scaling_wave4_no_tarot_approx_177() -> void:
	# scaled_speed = 1.5 × (1 + 0.06 × 3) × 1.0 = 1.5 × 1.18 = 1.77
	var res := _make_resource(&"speeder", 100.0, 1.5)
	_mm._resource_table[res.monster_id] = res
	_mm._tarot_speed_scalar = 1.0
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 4, 1)
	assert_float(entity.scaled_speed).is_between(1.769, 1.771)


func test_monster_spawn_speed_floor_prevents_zero() -> void:
	var res := _make_resource(&"stationary", 100.0, 0.0)
	_mm._resource_table[res.monster_id] = res
	_mm._tarot_speed_scalar = 0.0
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	assert_float(entity.scaled_speed).is_greater_equal(0.1)

# ---------------------------------------------------------------------------
# AC-6: Empty path from Pathfinding → stays SPAWNING, not in active_monsters
# ---------------------------------------------------------------------------

func test_monster_spawn_empty_path_stays_spawning() -> void:
	var res := _make_resource()
	_mm._resource_table[res.monster_id] = res
	_stub_path.return_empty = true
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	assert_int(entity.lifecycle_state).is_equal(MonsterEntity.State.SPAWNING)


func test_monster_spawn_empty_path_not_added_to_active_monsters() -> void:
	var res := _make_resource()
	_mm._resource_table[res.monster_id] = res
	_stub_path.return_empty = true
	_mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	assert_int(_mm.active_monsters.size()).is_equal(0)


func test_monster_spawn_empty_path_added_to_spawning_list() -> void:
	var res := _make_resource()
	_mm._resource_table[res.monster_id] = res
	_stub_path.return_empty = true
	_mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	assert_int(_mm.spawning_entities.size()).is_equal(1)

# ---------------------------------------------------------------------------
# AC-7: Five sequential spawns → entity_ids strictly ascending, no duplicates
# ---------------------------------------------------------------------------

func test_monster_spawn_five_sequential_ids_strictly_ascending() -> void:
	var res := _make_resource()
	_mm._resource_table[res.monster_id] = res
	var ids: Array[int] = []
	for i in 5:
		var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
		ids.append(entity.entity_id)
	for i in range(1, ids.size()):
		assert_int(ids[i]).is_greater(ids[i - 1])


func test_monster_spawn_five_sequential_ids_no_duplicates() -> void:
	var res := _make_resource()
	_mm._resource_table[res.monster_id] = res
	var ids: Array[int] = []
	for i in 5:
		var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
		ids.append(entity.entity_id)
	var unique := {}
	for id in ids:
		assert_bool(unique.has(id)).is_false()
		unique[id] = true

# ---------------------------------------------------------------------------
# MonsterInstance wiring — every spawned entity gets a configured presentation child
# ---------------------------------------------------------------------------

func test_monster_spawn_attaches_a_monster_instance_child() -> void:
	var res := _make_resource(&"goblin_runner")
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	var found: MonsterInstance = null
	for child in entity.get_children():
		if child is MonsterInstance:
			found = child
	assert_object(found).is_not_null()


func test_monster_spawn_monster_instance_child_is_configured_with_real_art() -> void:
	var res := _make_resource(&"goblin_runner")
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	var instance: MonsterInstance = entity.get_children().filter(
			func(c): return c is MonsterInstance)[0]
	assert_object(instance._sprite.texture).is_not_null()
