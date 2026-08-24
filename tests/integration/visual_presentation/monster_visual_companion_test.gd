extends GdUnitTestSuite

## Regression suite for the RETIREMENT of the legacy ADR-0037 monster 3D
## mesh companion (originally Epic 15 Story 004). ADR-0038's migration is
## now complete for every monster tier: STANDARD/ELITE moved to
## MonsterSwarmRenderer3D in Epic 16 Story 7, and BOSS moved to
## BossCreaturePresenter3D in Story 9 — see
## `docs/architecture/hybrid-swarm-rendering-implementation-blueprint.md`'s
## Migration step 8 ("Replace monster_visual_companion_test.gd expectations
## with swarm tests; retain all non-monster ADR-0037 tests").
##
## This file previously asserted the legacy companion WAS built (first for
## all tiers, then — after Story 7 — for BOSS only, as a deliberate interim
## fix keeping real coverage on the path that was still live). Story 9
## retired that path for BOSS too, so this suite's job flips: prove the
## legacy path stays dead for every tier, a real regression guard against
## an accidental future reintroduction (e.g. someone flips
## build_legacy_3d_companion back to true "to fix a bug" without realizing
## the swarm/boss-presenter paths are now authoritative).
##
## Real per-tier presentation coverage now lives in:
##   - tests/integration/visual_presentation/monster_swarm_migration_test.gd
##     (STANDARD/ELITE registration/sync/unregister)
##   - tests/integration/visual_presentation/monster_swarm_channel_test.gd
##     (hit-flash/status-mask/facing channels)
##   - tests/integration/visual_presentation/boss_creature_presenter_test.gd
##     (BOSS pool registration/update/unregister, capacity, attack-telegraph)
##
## The "no new _process()/_physics_process() callback" source-scan guard
## (ADR-0006's per_monster_physics_process forbidden pattern) is still
## fully valid and kept unchanged — that constraint applies regardless of
## which presentation path a tier uses.

const MonsterInstanceScriptPath: String = "res://src/core/monster/monster_instance.gd"
const MonsterEntityScriptPath: String = "res://src/core/monster/monster_entity.gd"
const DELTA := 1.0 / 60.0

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


const SPAWN_CELL := Vector2i(0, 0)
const LONG_PATH: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0),
]


func _make_resource(monster_id: StringName, tier: int, speed: float = 1.0) -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = monster_id
	res.display_name = "Test Monster"
	res.tier = tier
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
# No tier builds the legacy VisualCompanion3D subtree anymore
# ---------------------------------------------------------------------------

func test_standard_monster_spawn_builds_no_legacy_companion() -> void:
	var res := _make_resource(&"goblin_runner", 0, 2.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	assert_object(entity.monster_instance).is_not_null()
	assert_object(entity.monster_instance.get_node_or_null("VisualCompanion3D")).is_null()


func test_elite_monster_spawn_builds_no_legacy_companion() -> void:
	var res := _make_resource(&"forest_troll_elite", 1, 2.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	assert_object(entity.monster_instance.get_node_or_null("VisualCompanion3D")).is_null()


func test_boss_monster_spawn_builds_no_legacy_companion() -> void:
	var res := _make_resource(&"goblin_warlord_boss", 2, 1.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	assert_object(entity.monster_instance.get_node_or_null("VisualCompanion3D")).is_null()


func test_no_orphaned_legacy_companion_survives_repeated_physics_frames() -> void:
	var res := _make_resource(&"goblin_runner", 0, 2.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	for frame: int in range(10):
		_mm._physics_process(DELTA)
	assert_object(entity.monster_instance.get_node_or_null("VisualCompanion3D")).is_null()


# ---------------------------------------------------------------------------
# ADR-0006's per_monster_physics_process forbidden pattern — still fully
# valid regardless of which presentation path a tier uses.
# ---------------------------------------------------------------------------

func test_monster_instance_and_monster_entity_scripts_declare_no_process_callback() -> void:
	var instance_source: String = FileAccess.get_file_as_string(MonsterInstanceScriptPath)
	assert_bool(instance_source.find("func _process(") != -1).is_false()
	assert_bool(instance_source.find("func _physics_process(") != -1).is_false()

	var entity_source: String = FileAccess.get_file_as_string(MonsterEntityScriptPath)
	assert_bool(entity_source.find("func _process(") != -1).is_false()
	assert_bool(entity_source.find("func _physics_process(") != -1).is_false()
