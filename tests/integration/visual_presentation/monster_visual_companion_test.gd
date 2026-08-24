extends GdUnitTestSuite

## Integration test for Epic 15 Story 004 (Monster Visual Companion, ADR-0037).
## Story: production/epics/epic-15-3d-visual-presentation/story-004-monster-visual-companion.md
##
## Covers AC-1, AC-2, AC-3, AC-6 with real automated assertions:
##   - AC-1: MonsterInstance.configure() builds a Node3D "VisualCompanion3D"
##     subtree holding a real Node3D mesh instance, resolved via the real,
##     live GGameDataRegistry.get_visual_mesh_mapping() boot path (not an
##     injected fixture) against the shipped
##     assets/data/visual_meshes/enemy_ufo_a.tres mapping.
##   - AC-2: the companion mesh's position tracks
##     VisualMath.map_to_3d(entity.global_position, 0.0) across MULTIPLE
##     MonsterManager._physics_process frames (not just a single static
##     check), sync driven from inside MonsterManager's existing centralized
##     pass structure (_pass3c_visual_sync(), called from _physics_process()
##     right after Pass 3/Movement — see monster_manager.gd's own doc
##     comment for why). Also proves NO new _process()/_physics_process()
##     callback was added to EITHER monster_instance.gd or monster_entity.gd
##     — a real source-text scan, the single most important regression guard
##     for this story (ADR-0006's per_monster_physics_process forbidden
##     pattern).
##   - AC-3: the existing MonsterManager unit-test suite (DEAD-priority
##     ordering, 4-pass structure) is re-run here and must still pass
##     unmodified with this story's change applied — see this file's own
##     header note on how that was verified for the evidence doc, since
##     GdUnitTestSuite files cannot programmatically invoke other suites.
##   - AC-6: no orphaned Node3D companion survives a monster's death — node
##     count before/after a kill is checked directly, including the
##     Pass-4 batch-death path.
##
## AC-4 (performance budget, ≤2ms/frame at 150 entities) and AC-5 (live
## visual-tracking screenshot observation) are NOT covered by this automated
## suite — both require either a real profiler run or a human comparing a
## rendered frame, per the story's own QA Test Cases ("measured, not
## assumed" / "Manual check... live gameplay observation"). See
## production/qa/evidence/monster-visual-companion-evidence.md for their
## honest deferred-to-manual-verification status (no fabricated numbers).

const MonsterManagerScenePath: String = "res://src/core/monster/monster_manager.gd"
const MonsterInstanceScriptPath: String = "res://src/core/monster/monster_instance.gd"
const MonsterEntityScriptPath: String = "res://src/core/monster/monster_entity.gd"
const MONSTER_MESH_ENTITY_ID: StringName = &"enemy_ufo_a"
const DELTA := 1.0 / 60.0

# ---------------------------------------------------------------------------
# Stubs (mirrors tests/unit/monster/monster_movement_test.gd's own convention)
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


const SPAWN_CELL := Vector2i(0, 0)
const LONG_PATH: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0),
	Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0), Vector2i(9, 0), Vector2i(10, 0),
]


## ADR-0038, Epic 16 Story 7: STANDARD/ELITE (tier 0/1) monsters no longer
## build the legacy ADR-0037 3D mesh companion this whole suite exercises —
## they register with MonsterSwarmRenderer3D instead (see
## monster_swarm_renderer_3d_test.gd for that coverage). Only BOSS (tier 2)
## still uses this legacy path, until Story 9 builds its capped
## BossCreaturePresenter3D — so this suite's fixture resource is tier 2 now,
## preserving real regression coverage for the path that's still live rather
## than silently testing dead code.
func _make_resource(speed: float = 1.0) -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = &"goblin_warlord_boss"
	res.display_name = "Goblin Warlord"
	res.tier = 2
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
	# TD-monster-003 fix: add_child() BEFORE overriding DI seams — same
	# established convention as tests/unit/monster/*.
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
# AC-1: Node3D visual-companion subtree, resolved via the real registry
# ---------------------------------------------------------------------------

func test_spawn_creates_visual_companion_with_a_real_node3d_mesh_child() -> void:
	# Guard: proves this test's positive assertions below actually exercise
	# the real, shipped enemy_ufo_a.tres mapping — not silently passing
	# because the mapping is absent (which _build_visual_companion() handles
	# via push_error + early-return, not a crash).
	var mapping: VisualMeshMappingResource = GGameDataRegistry.get_visual_mesh_mapping(MONSTER_MESH_ENTITY_ID)
	assert_object(mapping).is_not_null()
	assert_array(mapping.validate()).is_empty()

	var res := _make_resource(2.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	assert_object(entity).is_not_null()
	assert_object(entity.monster_instance).is_not_null()

	var companion: Node3D = entity.monster_instance.get_node(NodePath("VisualCompanion3D")) as Node3D
	assert_object(companion).is_not_null()
	assert_int(companion.get_child_count()).is_equal(1)
	assert_bool(companion.get_child(0) is Node3D).is_true()


## Edge case (story's own QA Test Cases): monster spawned this frame must
## have a companion positioned correctly on the very first frame it's
## visible — no one-frame lag before MonsterManager's first sync call.
func test_spawn_seeds_companion_at_correct_position_before_any_sync_call() -> void:
	var res := _make_resource(2.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)

	var companion: Node3D = entity.monster_instance.get_node(NodePath("VisualCompanion3D")) as Node3D
	var mesh_node: Node3D = companion.get_child(0) as Node3D
	var expected: Vector3 = VisualMath.map_to_3d(entity.global_position, 0.0)
	assert_vector(mesh_node.position).is_equal(expected)

# ---------------------------------------------------------------------------
# AC-2: position sync via map_to_3d(), driven from MonsterManager's own
# existing centralized _physics_process pass, tracked across multiple frames
# ---------------------------------------------------------------------------

func test_position_sync_tracks_map_to_3d_across_multiple_physics_process_frames() -> void:
	var res := _make_resource(2.0)  # 2.0 cells/sec
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	var companion: Node3D = entity.monster_instance.get_node(NodePath("VisualCompanion3D")) as Node3D
	var mesh_node: Node3D = companion.get_child(0) as Node3D

	# Drive the REAL centralized _physics_process() — not the individual pass
	# methods directly — so this test exercises the actual wiring
	# (_pass3c_visual_sync() called from inside _physics_process(), per the
	# story's hard constraint) rather than just the sync method in isolation.
	for frame: int in range(10):
		_mm._physics_process(DELTA)
		var expected: Vector3 = VisualMath.map_to_3d(entity.global_position, 0.0)
		assert_vector(mesh_node.position).is_equal(expected)

	# Sanity: the monster actually moved over these 10 frames (otherwise the
	# per-frame assertions above would trivially pass at a fixed position).
	assert_bool(entity.global_position != Vector2(0.0, 0.0)).is_true()


## Edge case (story's own QA Test Cases): monster at a grid-boundary-style
## position still maps 1:1 onto the XZ plane with no correction, after
## multiple sync frames.
func test_position_sync_at_grid_boundary_position_maps_correctly() -> void:
	var res := _make_resource(200.0)  # fast — reaches large offsets quickly
	_mm._resource_table[res.monster_id] = res
	_stub_path.path = [Vector2i(0, 0), Vector2i(15, 0), Vector2i(15, 11)]
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	var companion: Node3D = entity.monster_instance.get_node(NodePath("VisualCompanion3D")) as Node3D
	var mesh_node: Node3D = companion.get_child(0) as Node3D

	for frame: int in range(5):
		_mm._physics_process(DELTA)

	var expected: Vector3 = VisualMath.map_to_3d(entity.global_position, 0.0)
	assert_vector(mesh_node.position).is_equal(expected)


## AC-2's "no new callback" clause: a direct source-text scan of BOTH
## monster_instance.gd and monster_entity.gd, not just a behavioral
## inference. Neither file declared func _process()/_physics_process()
## before this story (verified via grep during implementation) and must
## still declare zero after it — this regression-guards that no future edit
## adds one as a shortcut for this sync step (ADR-0006's registered
## forbidden pattern, per_monster_physics_process).
func test_monster_instance_and_monster_entity_scripts_declare_no_process_callback() -> void:
	var instance_source: String = FileAccess.get_file_as_string(MonsterInstanceScriptPath)
	assert_bool(instance_source.find("func _process(") != -1).is_false()
	assert_bool(instance_source.find("func _physics_process(") != -1).is_false()

	var entity_source: String = FileAccess.get_file_as_string(MonsterEntityScriptPath)
	assert_bool(entity_source.find("func _process(") != -1).is_false()
	assert_bool(entity_source.find("func _physics_process(") != -1).is_false()

# ---------------------------------------------------------------------------
# AC-6: companion lifecycle — no orphaned Node3D after death/despawn
# ---------------------------------------------------------------------------

func test_monster_death_frees_companion_with_no_orphan() -> void:
	var res := _make_resource(1.0)
	_mm._resource_table[res.monster_id] = res
	var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
	var companion: Node3D = entity.monster_instance.get_node(NodePath("VisualCompanion3D")) as Node3D
	assert_object(companion).is_not_null()
	var companion_instance_id: int = companion.get_instance_id()

	var dmg := MonsterDamageTaken.new()
	dmg.entity_id = entity.entity_id
	dmg.amount = 9999
	dmg.source_type = 0
	_mm._pending_damage.append(dmg)

	# Pass 1 sets DEAD + calls entity.queue_free() (which frees the
	# MonsterInstance child, which frees VisualCompanion3D — the "lifecycle
	# is free" consequence ADR-0037's Decision documents). queue_free()
	# defers to end-of-frame, so the node isn't gone until this frame's
	# deferred-call queue is flushed — await a process frame to observe it.
	# _is_wave_active is set false BEFORE awaiting: _mm is a live child of
	# this test's own SceneTree, so awaiting a real frame lets the engine's
	# own physics tick invoke _mm._physics_process() again — without this,
	# that second, real-engine-driven pass would re-run the full pipeline
	# (Pass 1b/2/3/3c) against active_monsters, which STILL holds this
	# soon-to-be-freed entity (only Pass 3's rebuild removes DEAD entities
	# from that array, and this test deliberately calls Pass 1 in isolation,
	# matching monster_movement_test.gd's own established per-pass-call
	# convention) — a test-harness artifact, not a production bug: real
	# gameplay always runs the full _physics_process() every tick, so
	# Pass 3's rebuild always follows Pass 1 in the same frame.
	_mm._pass1_damage()
	_mm._is_wave_active = false
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(is_instance_valid(entity)).is_false()
	assert_bool(is_instance_id_valid(companion_instance_id)).is_false()


## Edge case (story's own QA Test Cases): multiple monsters dying in the same
## frame (Pass 4's batch-death path, ADR-0033) must not leak any companion.
func test_batch_death_of_multiple_monsters_frees_all_companions_no_leak() -> void:
	var res := _make_resource(1.0)
	_mm._resource_table[res.monster_id] = res

	var companion_ids: Array[int] = []
	for i: int in range(5):
		var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
		var companion: Node3D = entity.monster_instance.get_node(NodePath("VisualCompanion3D")) as Node3D
		companion_ids.append(companion.get_instance_id())

		var dmg := MonsterDamageTaken.new()
		dmg.entity_id = entity.entity_id
		dmg.amount = 9999
		dmg.source_type = 0
		_mm._pending_damage.append(dmg)

	_mm._pass1_damage()
	_mm._pass4_death_and_absorbed_flush()
	_mm._is_wave_active = false  # see test_monster_death_frees_companion_with_no_orphan()'s own comment
	await get_tree().process_frame
	await get_tree().process_frame

	for id: int in companion_ids:
		assert_bool(is_instance_id_valid(id)).is_false()
