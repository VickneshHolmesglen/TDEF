extends GdUnitTestSuite

## Integration test for Epic 15 Story 006 (Projectile Visual Companion,
## ADR-0037/ADR-0019).
## Story: production/epics/epic-15-3d-visual-presentation/story-006-projectile-visual-companion.md
##
## *** REDIRECTED SCOPE -- READ BEFORE EDITING THIS FILE ***
##
## Story 006 and ADR-0019 ("Projectile Pooling Strategy," Accepted) describe
## and test against a 192-slot POOLED `Projectile`/`ProjectileManager` system
## -- reused node instances toggled visible/process_mode on release/reuse,
## synced from one centralized ProjectileManager._physics_process() pass.
## Verified during this story's implementation (2026-08-20): THAT SYSTEM WAS
## NEVER IMPLEMENTED IN THIS CODEBASE. No ProjectileManager class, no pooled
## Projectile class, and no test file for either exists anywhere in src/ or
## tests/ (confirmed by grep for "class_name ProjectileManager", "POOL_SIZE",
## "_free_indices" -- zero matches). ADR-0019 itself says under its own
## Migration Plan: "Greenfield -- no existing Projectile/ProjectileManager
## code to migrate," and that remains true today. TowerSystem._try_attack()
## still emits tower_attacked immediately and unconditionally for every
## weapon type -- there is no flight-time delay, no pool, no branching on
## projectile_type. TR-tower-007 (the requirement ADR-0019 exists to close)
## remains open. This gap is logged as a separate, still-open item outside
## this epic's scope -- see production/qa/evidence/
## projectile-visual-companion-evidence.md's "ADR-0019 Gap Finding" section.
##
## User-confirmed decision (this session): building ADR-0019's real pooling
## system first was explicitly considered and REJECTED for this story's
## scope, because it would be a substantive gameplay TIMING change
## (introducing a real flight delay before damage lands, where today damage
## is instant) -- not a visual-presentation change, and directly against
## this epic's own non-negotiable "zero changes to gameplay simulation
## logic" boundary (ADR-0037's Constraints). This story was therefore
## redirected to test the companion against the REAL projectile lifecycle
## that exists in this codebase: `ProjectileVisual` (src/scenes/
## projectile_visual.gd), a purely cosmetic Node2D, freshly instantiate()'d
## per shot by mission_scene.gd's _on_tower_attacked() handler and
## queue_free()'d once its flight completes -- a create-per-shot/
## destroy-per-shot lifecycle, the opposite of a reused pool.
##
## Coverage in THIS file (real automated assertions against the real
## per-shot lifecycle):
##   - Companion creation + mesh resolution via the real, live
##     GGameDataRegistry.get_visual_mesh_mapping() boot path (not an injected
##     fixture) against the shipped assets/data/visual_meshes/
##     projectile_bolt.tres mapping.
##   - Companion seeded at the correct start position before any _process()
##     sync call (no one-frame lag on first visible frame).
##   - Position sync via map_to_3d() tracked across MULTIPLE real _process()
##     frames, for both BALLISTIC and HOMING projectile_type (including a
##     HOMING target that moves mid-flight and a HOMING target that dies
##     mid-flight).
##   - Companion freed with no orphan when ProjectileVisual itself
##     queue_free()'s at end-of-flight -- the "lifecycle is free" consequence
##     ADR-0037's Decision documents, exercised here on the real
##     create-per-shot/destroy-per-shot path (not a pool release).
##   - Source-text scan: ProjectileVisual still declares exactly ONE
##     _process() (pre-existing before this story) and ZERO _physics_process()
##     -- i.e. this story added a line inside the existing _process(), not a
##     new callback. ADR-0037's "no new callback" constraint, verified the
##     same way every prior story in this epic verified it.
##   - Multiple independent ProjectileVisual instances processed in the same
##     frame do not cross-contaminate each other's companion position (the
##     closest real analog this codebase has to the story's "multiple slots
##     releasing/reusing in the same frame" edge case -- see the explicit
##     N/A note below for why the actual pool-cycling scenario cannot be
##     tested).
##
## EXPLICITLY MARKED N/A -- DO NOT ADD FABRICATED COVERAGE FOR THESE:
##   - Pool release/reuse visibility toggling (AC-3/AC-4 as literally
##     written): N/A. There is no pool. A ProjectileVisual is never released
##     back to a free-list or reused for a second shot -- it is
##     instantiate()'d once and queue_free()'d once, always.
##   - Rapid release-reuse cycling within a small number of frames (the
##     story's own explicitly-called-out mass-kill stress edge case): N/A,
##     same reason -- no reuse exists to cycle rapidly.
##   - Multiple pool slots releasing/reusing in the same frame: N/A, same
##     reason. (The "multiple independent instances in one frame" test above
##     covers a DIFFERENT, real scenario -- concurrent independent
##     instances, not shared-slot reuse -- and should not be read as
##     satisfying this criterion.)
##
## AC-6-equivalent (performance budget) and AC-7-equivalent (live visual
## tracking) are NOT covered by this automated suite -- both require either
## a real profiler run or a human comparing a rendered frame, per the
## story's own QA Test Cases. See production/qa/evidence/
## projectile-visual-companion-evidence.md for their honest deferred-to-
## manual-verification status (no fabricated numbers/screenshots).

const ProjectileVisualScenePath: String = "res://src/scenes/ProjectileVisual.tscn"
const ProjectileVisualScriptPath: String = "res://src/scenes/projectile_visual.gd"
const PROJECTILE_MESH_ENTITY_ID: StringName = &"projectile_bolt"
const DELTA := 1.0 / 60.0

var _spawned: Array[ProjectileVisual] = []


func after_test() -> void:
	for p: ProjectileVisual in _spawned:
		if is_instance_valid(p):
			if p.is_inside_tree():
				p.get_parent().remove_child(p)
			p.free()
	_spawned.clear()


func _make_projectile() -> ProjectileVisual:
	var packed: PackedScene = load(ProjectileVisualScenePath)
	var p: ProjectileVisual = packed.instantiate() as ProjectileVisual
	add_child(p)
	_spawned.append(p)
	return p


func _make_target(pos: Vector2) -> Node2D:
	var target := Node2D.new()
	target.global_position = pos
	add_child(target)
	return target

# ---------------------------------------------------------------------------
# Companion creation + mesh resolution (mirrors Story 003/004/005's AC-1
# precedent, against the real, live GGameDataRegistry boot path)
# ---------------------------------------------------------------------------

func test_configure_creates_visual_companion_with_a_real_node3d_mesh_child() -> void:
	# Guard: proves this test's positive assertions below actually exercise
	# the real, shipped projectile_bolt.tres mapping -- not silently passing
	# because the mapping is absent (which _build_visual_companion() handles
	# via push_error + early-return, not a crash).
	var mapping: VisualMeshMappingResource = GGameDataRegistry.get_visual_mesh_mapping(PROJECTILE_MESH_ENTITY_ID)
	assert_object(mapping).is_not_null()
	assert_array(mapping.validate()).is_empty()

	var p := _make_projectile()
	var target := _make_target(Vector2(200.0, 0.0))
	p.configure("physical", "BALLISTIC", Vector2.ZERO, target)

	var companion: Node3D = p.get_node(NodePath("VisualCompanion3D")) as Node3D
	assert_object(companion).is_not_null()
	assert_int(companion.get_child_count()).is_equal(1)
	assert_bool(companion.get_child(0) is Node3D).is_true()


## Edge case (story's own QA Test Cases): "projectile fired this frame
## (companion correctly positioned from first active frame)" -- checked here
## BEFORE any _process() call runs.
func test_configure_seeds_companion_at_start_position_before_any_process_call() -> void:
	var p := _make_projectile()
	var target := _make_target(Vector2(500.0, 100.0))
	var start_pos := Vector2(64.0, -32.0)
	p.configure("elemental", "BALLISTIC", start_pos, target, 0.0, "fire")

	var companion: Node3D = p.get_node(NodePath("VisualCompanion3D")) as Node3D
	var mesh_node: Node3D = companion.get_child(0) as Node3D
	var expected: Vector3 = VisualMath.map_to_3d(start_pos, ProjectileVisual.PROJECTILE_LAYER_HEIGHT)
	assert_vector(mesh_node.position).is_equal(expected)

# ---------------------------------------------------------------------------
# Position sync via map_to_3d(), from the existing _process(), tracked
# across multiple real frames -- both BALLISTIC and HOMING
# ---------------------------------------------------------------------------

func test_position_sync_tracks_map_to_3d_across_multiple_process_frames_ballistic() -> void:
	var p := _make_projectile()
	var target := _make_target(Vector2(600.0, 0.0))
	p.configure("physical", "BALLISTIC", Vector2.ZERO, target)

	var companion: Node3D = p.get_node(NodePath("VisualCompanion3D")) as Node3D
	var mesh_node: Node3D = companion.get_child(0) as Node3D

	# Drive the REAL _process() -- not _sync_visual_companion_position() in
	# isolation -- so this test exercises the actual wiring (the one line
	# added to ProjectileVisual's existing _process()) rather than just the
	# sync method called directly. Stop short of _flight_duration so the node
	# is not queue_free()'d mid-loop.
	for _frame: int in range(5):
		p._process(DELTA)
		var expected: Vector3 = VisualMath.map_to_3d(p.global_position, ProjectileVisual.PROJECTILE_LAYER_HEIGHT)
		assert_vector(mesh_node.position).is_equal(expected)

	# Sanity: the projectile actually moved over these frames (otherwise the
	# per-frame assertions above would trivially pass at a fixed position).
	assert_bool(p.global_position != Vector2.ZERO).is_true()


func test_position_sync_tracks_map_to_3d_across_multiple_process_frames_homing_moving_target() -> void:
	var p := _make_projectile()
	var target := _make_target(Vector2(400.0, 0.0))
	p.configure("elemental", "HOMING", Vector2.ZERO, target, 0.0, "arcane")

	var companion: Node3D = p.get_node(NodePath("VisualCompanion3D")) as Node3D
	var mesh_node: Node3D = companion.get_child(0) as Node3D

	for frame: int in range(5):
		target.global_position = Vector2(400.0 - float(frame) * 10.0, 20.0)  # target drifts each frame
		p._process(DELTA)
		var expected: Vector3 = VisualMath.map_to_3d(p.global_position, ProjectileVisual.PROJECTILE_LAYER_HEIGHT)
		assert_vector(mesh_node.position).is_equal(expected)


## Edge case (story's own QA Test Cases, reframed against the real lifecycle):
## "projectile re-acquiring a target mid-flight (position continues updating
## correctly through re-acquisition)" -- this codebase's real HOMING behavior
## on target death is dissipate-in-place (Rule 19 full re-acquisition is
## explicitly out of scope per projectile_visual.gd's own class doc comment),
## not re-acquisition -- confirming the companion still tracks correctly
## through THAT real transition (target freed mid-flight) is the closest
## real analog.
func test_position_sync_remains_correct_when_homing_target_dies_mid_flight() -> void:
	var p := _make_projectile()
	var target := _make_target(Vector2(300.0, 0.0))
	p.configure("elemental", "HOMING", Vector2.ZERO, target, 0.0, "frost")

	var companion: Node3D = p.get_node(NodePath("VisualCompanion3D")) as Node3D
	var mesh_node: Node3D = companion.get_child(0) as Node3D

	p._process(DELTA)
	target.get_parent().remove_child(target)
	target.free()

	for _frame: int in range(3):
		p._process(DELTA)
		var expected: Vector3 = VisualMath.map_to_3d(p.global_position, ProjectileVisual.PROJECTILE_LAYER_HEIGHT)
		assert_vector(mesh_node.position).is_equal(expected)

# ---------------------------------------------------------------------------
# Companion lifecycle -- freed with no orphan alongside ProjectileVisual's
# OWN existing queue_free() at end-of-flight (the real, non-pooled release
# path in this codebase)
# ---------------------------------------------------------------------------

func test_process_frees_companion_at_end_of_flight_with_no_orphan() -> void:
	var p := _make_projectile()
	var target := _make_target(Vector2(50.0, 0.0))
	p.configure("physical", "BALLISTIC", Vector2.ZERO, target)
	# BEAM_DURATION-scale short flight -- BALLISTIC's flight_duration here is
	# distance(50)/FLIGHT_SPEED(900) ~= 0.055s, clamped to a 0.05s floor.
	var companion: Node3D = p.get_node(NodePath("VisualCompanion3D")) as Node3D
	var companion_id: int = companion.get_instance_id()
	var projectile_id: int = p.get_instance_id()

	for _frame: int in range(10):  # 10 * DELTA (~0.167s) comfortably exceeds the ~0.05s flight_duration
		if not is_instance_valid(p):
			break
		p._process(DELTA)

	# queue_free() defers to end-of-frame -- await to observe the actual free.
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(is_instance_id_valid(projectile_id)).is_false()
	assert_bool(is_instance_id_valid(companion_id)).is_false()
	_spawned.clear()  # already freed -- after_test() must not double-free


## Edge case: multiple independent ProjectileVisual instances processed in
## the same frame must not cross-contaminate each other's companion
## position. This is the closest REAL analog this codebase has to the
## story's "multiple slots releasing/reusing in the same frame" edge case --
## it is NOT the same scenario (these are distinct instances, never a shared
## pool slot) and must not be read as satisfying that N/A'd criterion (see
## this file's header doc comment).
func test_multiple_independent_projectiles_in_the_same_frame_do_not_cross_contaminate() -> void:
	var p1 := _make_projectile()
	var t1 := _make_target(Vector2(1000.0, 0.0))
	p1.configure("physical", "BALLISTIC", Vector2.ZERO, t1)

	var p2 := _make_projectile()
	var t2 := _make_target(Vector2(0.0, 1000.0))
	p2.configure("physical", "BALLISTIC", Vector2(500.0, 500.0), t2)

	var c1: Node3D = (p1.get_node(NodePath("VisualCompanion3D")) as Node3D).get_child(0) as Node3D
	var c2: Node3D = (p2.get_node(NodePath("VisualCompanion3D")) as Node3D).get_child(0) as Node3D

	for _frame: int in range(3):
		p1._process(DELTA)
		p2._process(DELTA)
		assert_vector(c1.position).is_equal(VisualMath.map_to_3d(p1.global_position, ProjectileVisual.PROJECTILE_LAYER_HEIGHT))
		assert_vector(c2.position).is_equal(VisualMath.map_to_3d(p2.global_position, ProjectileVisual.PROJECTILE_LAYER_HEIGHT))
		assert_vector(c1.position).is_not_equal(c2.position)

# ---------------------------------------------------------------------------
# "No new callback" clause -- direct source-text scan
# ---------------------------------------------------------------------------

## ADR-0037's "no new callback" constraint, reframed for this file's real
## situation (per the coordinator's redirected-scope instruction): the
## constraint here means "don't add a SECOND _process()/introduce a new
## _physics_process()" -- projectile_visual.gd's single _process() is
## pre-existing (it drove the 2D flight path before this story) and is out
## of this story's control to remove.
func test_projectile_visual_script_declares_exactly_one_process_and_zero_physics_process() -> void:
	var source: String = FileAccess.get_file_as_string(ProjectileVisualScriptPath)

	var process_count: int = 0
	var search_start: int = 0
	while true:
		var idx: int = source.find("func _process(", search_start)
		if idx == -1:
			break
		process_count += 1
		search_start = idx + 1

	assert_int(process_count).is_equal(1)
	assert_bool(source.find("func _physics_process(") != -1).is_false()


## Confirms the sync call site is actually inside _process() (not merely
## present somewhere in the file) -- guards against a future edit moving the
## call into some other, newly-added method while the count assertion above
## stays technically at 1.
func test_process_body_calls_the_visual_companion_sync() -> void:
	var source: String = FileAccess.get_file_as_string(ProjectileVisualScriptPath)
	var process_idx: int = source.find("func _process(")
	assert_int(process_idx).is_greater(-1)

	var next_func_idx: int = source.find("\nfunc ", process_idx + 1)
	var body: String = source.substr(process_idx,
			(next_func_idx - process_idx) if next_func_idx != -1 else -1)
	assert_bool(body.contains("_sync_visual_companion_position()")).is_true()
