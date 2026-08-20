extends GdUnitTestSuite

## Integration test for Epic 15 Story 005 (Hero Visual Companion, ADR-0037).
## Story: production/epics/epic-15-3d-visual-presentation/story-005-hero-visual-companion.md
##
## Covers AC-1, AC-2, AC-3 with real automated assertions:
##   - AC-1: Hero's _ready() builds a Node3D "VisualCompanion3D" subtree
##     holding a real Node3D mesh instance, resolved via the real, live
##     GGameDataRegistry.get_visual_mesh_mapping() boot path (not an injected
##     fixture) against the shipped assets/data/visual_meshes/hero.tres
##     mapping.
##   - AC-2: the companion mesh's position tracks
##     VisualMath.map_to_3d(hero.global_position, 0.0) across MULTIPLE real
##     Hero._physics_process() frames of actual movement (not just a single
##     static check), and a direct source-text scan confirms Hero's script
##     still declares exactly ONE _physics_process() and exactly ONE
##     _process() -- i.e. this story added a line to the existing
##     _physics_process(), not a new callback (ADR-0037's "no new callback"
##     constraint, verified the same way Stories 003/004 verified it for
##     TowerInstance/MonsterInstance).
##   - AC-3 (no regression): this suite does not re-implement
##     hero_movement_test.gd's/hero_lifecycle_test.gd's/etc. own coverage --
##     see this file's own header note in the evidence doc for how AC-3 was
##     verified (re-running the existing Hero suites after this story's
##     change), matching monster_visual_companion_test.gd's identical
##     precedent for AC-3.
##
## AC-4 (live visual tracking) and AC-5 (CharacterBody2D-specific live
## observation) are NOT covered by this automated suite -- both require a
## human/live-rendered session per the story's own QA Test Cases ("Manual
## check: live gameplay observation"). See
## production/qa/evidence/hero-visual-companion-evidence.md for their honest
## deferred-to-manual-verification status (no fabricated numbers/screenshots).

const HeroScriptPath: String = "res://src/core/hero/hero.gd"
const HERO_MESH_ENTITY_ID: StringName = &"hero"
const DELTA := 1.0 / 60.0

var _hero: Hero


func after_test() -> void:
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


## Mirrors tests/integration/hero/hero_movement_test.gd's own _make_hero()
## fixture exactly -- add_child() triggers the real _ready() (collision
## shape, timers, and -- as of this story -- the visual-companion build).
func _make_hero() -> Hero:
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[&"move_speed"] = 200.0
	# Rule 27 fixture note (same as hero_movement_test.gd): disable _process()
	# so the real headless Input singleton doesn't overwrite _input_direction
	# between our direct sets.
	_hero.set_process(false)
	return _hero

# ---------------------------------------------------------------------------
# AC-1: Node3D visual-companion subtree, resolved via the real registry
# ---------------------------------------------------------------------------

func test_ready_creates_visual_companion_with_a_real_node3d_mesh_child() -> void:
	# Guard: proves this test's positive assertions below actually exercise
	# the real, shipped hero.tres mapping -- not silently passing because the
	# mapping is absent (which _build_visual_companion() handles via
	# push_error + early-return, not a crash).
	var mapping: VisualMeshMappingResource = GGameDataRegistry.get_visual_mesh_mapping(HERO_MESH_ENTITY_ID)
	assert_object(mapping).is_not_null()
	assert_array(mapping.validate()).is_empty()

	var hero := _make_hero()

	var companion: Node3D = hero.get_node(NodePath("VisualCompanion3D")) as Node3D
	assert_object(companion).is_not_null()
	assert_int(companion.get_child_count()).is_equal(1)
	assert_bool(companion.get_child(0) is Node3D).is_true()


## Edge case (story's own Acceptance Criteria: "Hero at mission start (companion
## must exist and be correctly positioned from the first visible frame)").
func test_ready_seeds_companion_at_correct_position_before_any_sync_call() -> void:
	var hero := _make_hero()
	hero.global_position = Vector2(120.0, -40.0)
	# Rebuild so the seeded position reflects the position set above (mirrors
	# _build_visual_companion() seeding from global_position at build time --
	# real production Hero.tscn placement happens before _ready() runs, this
	# just exercises the same code path deterministically).
	hero._build_visual_companion()

	var companion: Node3D = hero.get_node(NodePath("VisualCompanion3D")) as Node3D
	var mesh_node: Node3D = companion.get_child(0) as Node3D
	var expected: Vector3 = VisualMath.map_to_3d(hero.global_position, 0.0)
	assert_vector(mesh_node.position).is_equal(expected)

# ---------------------------------------------------------------------------
# AC-2: position sync via map_to_3d(), driven from Hero's own EXISTING
# _physics_process(), tracked across multiple frames of real movement
# ---------------------------------------------------------------------------

func test_position_sync_tracks_map_to_3d_across_multiple_physics_process_frames() -> void:
	var hero := _make_hero()
	hero._input_direction = Vector2(1.0, 0.0)  # steady rightward movement

	var companion: Node3D = hero.get_node(NodePath("VisualCompanion3D")) as Node3D
	var mesh_node: Node3D = companion.get_child(0) as Node3D

	# Drive the REAL _physics_process() -- not _sync_visual_companion_position()
	# in isolation -- so this test exercises the actual wiring (the one line
	# added to Hero's existing _physics_process()) rather than just the sync
	# method called directly.
	for _frame: int in range(10):
		hero._physics_process(DELTA)
		var expected: Vector3 = VisualMath.map_to_3d(hero.global_position, 0.0)
		assert_vector(mesh_node.position).is_equal(expected)

	# Sanity: the hero actually moved over these 10 frames (otherwise the
	# per-frame assertions above would trivially pass at a fixed position).
	assert_bool(hero.global_position != Vector2.ZERO).is_true()


## Edge case: direction change mid-movement -- the companion must not lag or
## desync when velocity changes frame-to-frame, not just under constant
## velocity.
func test_position_sync_tracks_correctly_through_a_direction_change() -> void:
	var hero := _make_hero()
	hero._input_direction = Vector2(1.0, 0.0)

	var companion: Node3D = hero.get_node(NodePath("VisualCompanion3D")) as Node3D
	var mesh_node: Node3D = companion.get_child(0) as Node3D

	for _frame: int in range(5):
		hero._physics_process(DELTA)

	hero._input_direction = Vector2(0.0, 1.0)  # direction change
	for _frame: int in range(5):
		hero._physics_process(DELTA)
		var expected: Vector3 = VisualMath.map_to_3d(hero.global_position, 0.0)
		assert_vector(mesh_node.position).is_equal(expected)


## AC-2's "no new callback" clause: a direct source-text scan of hero.gd, not
## just a behavioral inference. hero.gd declared exactly one _process() and
## exactly one _physics_process() BEFORE this story (both pre-existing --
## input polling and movement/tracking/proximity, respectively, per the
## class doc comment's control-manifest note) and must still declare exactly
## one of each AFTER it -- this regression-guards that the sync step was
## added as a line inside the existing _physics_process(), never as a second,
## competing callback (ADR-0037's Decision: "not a *new* per-node override,
## since these two [TowerInstance/Hero] already have one; it gains one line,
## not a new callback").
func test_hero_script_declares_exactly_one_process_and_one_physics_process() -> void:
	var source: String = FileAccess.get_file_as_string(HeroScriptPath)

	var process_count: int = 0
	var physics_process_count: int = 0
	var search_start: int = 0
	while true:
		var idx: int = source.find("func _process(", search_start)
		if idx == -1:
			break
		process_count += 1
		search_start = idx + 1

	search_start = 0
	while true:
		var idx: int = source.find("func _physics_process(", search_start)
		if idx == -1:
			break
		physics_process_count += 1
		search_start = idx + 1

	assert_int(process_count).is_equal(1)
	assert_int(physics_process_count).is_equal(1)


## Confirms the sync call site is actually inside _physics_process() (not
## merely present somewhere in the file) -- guards against a future edit
## moving the call into some other, newly-added method while this file's
## _physics_process()/_process() counts above stay technically at 1/1.
func test_physics_process_body_calls_the_visual_companion_sync() -> void:
	var source: String = FileAccess.get_file_as_string(HeroScriptPath)
	var physics_process_idx: int = source.find("func _physics_process(")
	assert_int(physics_process_idx).is_greater(-1)

	var next_func_idx: int = source.find("\nfunc ", physics_process_idx + 1)
	var body: String = source.substr(physics_process_idx,
			(next_func_idx - physics_process_idx) if next_func_idx != -1 else -1)
	assert_bool(body.contains("_sync_visual_companion_position()")).is_true()

# ---------------------------------------------------------------------------
# CharacterBody2D-specific verification (story's own explicitly-called-out
# target -- ADR-0037/AC-5: "confirm the mixed-root pattern holds for a
# CharacterBody2D root specifically").
# ---------------------------------------------------------------------------

## Rule 27 collision (move_and_slide() being stopped by an obstacle) must not
## desync the companion -- the companion should track whatever
## global_position move_and_slide() actually settles at, including a
## collision-truncated movement, not the pre-collision intended position.
func test_position_sync_remains_correct_after_move_and_slide_collision_stop() -> void:
	var hero := _make_hero()
	hero.global_position = Vector2(0.0, 0.0)
	hero._input_direction = Vector2(1.0, 0.0)

	var obstacle := StaticBody2D.new()
	obstacle.collision_layer = Hero.COLLISION_LAYER_ENVIRONMENT
	obstacle.collision_mask = 0
	obstacle.global_position = Vector2(100.0, 0.0)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64.0, 64.0)
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = shape
	obstacle.add_child(collision_shape)
	add_child(obstacle)

	var companion: Node3D = hero.get_node(NodePath("VisualCompanion3D")) as Node3D
	var mesh_node: Node3D = companion.get_child(0) as Node3D

	for _frame: int in range(120):
		hero._physics_process(DELTA)

	# Hero must have been stopped by the obstacle (real Rule 27 collision, not
	# a fixture artifact -- same assertion style as hero_movement_test.gd's
	# own Rule 27 tests).
	assert_float(hero.global_position.x).is_less(100.0 - 32.0)
	assert_float(hero.global_position.x).is_greater(50.0)
	# The companion tracks the ACTUAL (collision-truncated) settled position,
	# not the pre-collision intended position -- no anomaly correlated with
	# the CharacterBody2D collision-resolution event.
	var expected: Vector3 = VisualMath.map_to_3d(hero.global_position, 0.0)
	assert_vector(mesh_node.position).is_equal(expected)

	obstacle.get_parent().remove_child(obstacle)
	obstacle.free()
