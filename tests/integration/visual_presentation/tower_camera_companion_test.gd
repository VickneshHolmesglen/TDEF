extends GdUnitTestSuite

## Integration test for Epic 15 Story 003 (Tower Visual Companion + Camera3D,
## ADR-0037).
## Story: production/epics/epic-15-3d-visual-presentation/story-003-tower-camera3d.md
##
## Covers AC-1, AC-2, AC-3, AC-4 with real automated assertions:
##   - AC-1: TowerInstance.configure() builds a Node3D "VisualCompanion3D"
##     subtree holding a real Node3D mesh instance, resolved via the real,
##     live GGameDataRegistry.get_visual_mesh_mapping() boot path (not an
##     injected fixture) against the shipped
##     assets/data/visual_meshes/tower_round.tres mapping.
##   - AC-2: the companion mesh's position exactly matches
##     VisualMath.map_to_3d(tower.position, 0.0) — an ABSOLUTE assignment,
##     never relative to TowerInstance's own Node2D transform (ADR-0037's
##     "Important engine clarification") — and this project's real call
##     order (position set once, before configure(), by
##     mission_scene.gd/the_gap.gd's _on_tower_placed) is exercised
##     end-to-end. Also proves NO new _process()/_physics_process() callback
##     was added to tower_instance.gd (a real source-text scan, not just an
##     assertion of the story's intent) — TowerInstance had ZERO such
##     callbacks before this story (verified by grep during implementation;
##     see tower_instance.gd's _build_visual_companion() doc comment for the
##     resulting deviation from ADR-0037's literal "already has one" framing)
##     and must still have zero after it.
##   - AC-3 & AC-4: both MissionScene.tscn and the_gap.tscn have a real
##     Camera3D sibling to the pre-existing Camera2D, and the two coexist in
##     the live scene tree without error under every current/enabled
##     combination (both current, neither current, toggling between them).
##
## AC-5 (combined visual correctness — tower renders at the correct grid
## cell, correct relative scale) and AC-6 (HUD rendering unaffected by which
## camera is active) are NOT automatable — both require a real rendered
## frame and a human comparing what's on screen, per the story's own QA Test
## Cases ("Manual check... Pass condition..."). See
## production/qa/evidence/tower-camera3d-evidence.md for their
## deferred-to-manual-verification status.

const TowerInstanceScenePath: String = "res://src/core/tower/TowerInstance.tscn"
const TheGapScenePath: String = "res://src/gameplay/missions/the_gap/the_gap.tscn"
const TowerInstanceScriptPath: String = "res://src/core/tower/tower_instance.gd"
const TOWER_MESH_ENTITY_ID: StringName = &"tower_round"

var _tower: TowerInstance


func before_test() -> void:
	var packed: PackedScene = load(TowerInstanceScenePath)
	_tower = packed.instantiate() as TowerInstance
	add_child(_tower)


func after_test() -> void:
	if is_instance_valid(_tower):
		remove_child(_tower)
		_tower.free()
	_tower = null


# ---------------------------------------------------------------------------
# AC-1: Node3D visual-companion subtree, resolved via the real registry
# ---------------------------------------------------------------------------

func test_configure_creates_visual_companion_with_a_real_node3d_mesh_child() -> void:
	# Guard: proves this test's positive assertions below actually exercise
	# the real, shipped tower_round.tres mapping — not silently passing
	# because the mapping is absent (which _build_visual_companion() handles
	# via push_error + early-return, not a crash).
	var mapping: VisualMeshMappingResource = GGameDataRegistry.get_visual_mesh_mapping(TOWER_MESH_ENTITY_ID)
	assert_object(mapping).is_not_null()
	assert_array(mapping.validate()).is_empty()

	# Act
	_tower.position = Vector2(120.0, 240.0)
	_tower.configure("physical")

	# Assert
	var companion: Node3D = _tower.get_node(NodePath("VisualCompanion3D")) as Node3D
	assert_object(companion).is_not_null()
	assert_int(companion.get_child_count()).is_equal(1)
	assert_bool(companion.get_child(0) is Node3D).is_true()


# ---------------------------------------------------------------------------
# AC-2: position sync via map_to_3d(), from the existing update method
# ---------------------------------------------------------------------------

func test_configure_places_companion_mesh_at_map_to_3d_of_tower_position() -> void:
	# Arrange: mirrors this project's real call order (mission_scene.gd/
	# the_gap.gd's _on_tower_placed) — position is set BEFORE configure().
	_tower.position = Vector2(320.0, 96.0)

	# Act
	_tower.configure("ranged")

	# Assert
	var companion: Node3D = _tower.get_node(NodePath("VisualCompanion3D")) as Node3D
	var mesh_node: Node3D = companion.get_child(0) as Node3D
	var expected: Vector3 = VisualMath.map_to_3d(_tower.position, 0.0)
	assert_vector(mesh_node.position).is_equal(expected)


## Edge case (story's own QA Test Cases): tower position unchanged across
## repeated syncs must not drift.
func test_configure_called_twice_with_unchanged_position_does_not_drift() -> void:
	_tower.position = Vector2(64.0, 64.0)
	_tower.configure("physical")
	var first_companion: Node3D = _tower.get_node(NodePath("VisualCompanion3D")) as Node3D
	var first_position: Vector3 = (first_companion.get_child(0) as Node3D).position

	_tower.configure("physical")
	var second_companion: Node3D = _tower.get_node(NodePath("VisualCompanion3D")) as Node3D
	var second_position: Vector3 = (second_companion.get_child(0) as Node3D).position

	assert_vector(second_position).is_equal(first_position)


## Edge case: tower at a grid-boundary-style position (large/asymmetric
## coordinates), still maps 1:1 onto the XZ plane with no correction.
func test_configure_at_grid_boundary_position_maps_correctly() -> void:
	_tower.position = Vector2(1024.0 - 32.0, 768.0 - 32.0)  # bottom-right-most cell center, The Gap's 16x12 * 64px grid

	_tower.configure("support")

	var companion: Node3D = _tower.get_node(NodePath("VisualCompanion3D")) as Node3D
	var mesh_node: Node3D = companion.get_child(0) as Node3D
	assert_vector(mesh_node.position).is_equal(VisualMath.map_to_3d(_tower.position, 0.0))


## AC-2's "no new callback" clause: a direct source-text scan of
## tower_instance.gd, not just a behavioral inference. TowerInstance had
## ZERO func _process()/_physics_process() declarations before this story
## (verified via grep during implementation — see this file's own header
## comment and _build_visual_companion()'s doc comment in tower_instance.gd
## for the resulting, explicitly-flagged deviation from ADR-0037's literal
## "TowerInstance already has one" framing). This regression-guards that no
## future edit adds one as a shortcut for this sync step.
func test_tower_instance_script_declares_no_process_or_physics_process_callback() -> void:
	var source: String = FileAccess.get_file_as_string(TowerInstanceScriptPath)
	assert_bool(source.find("func _process(") != -1).is_false()
	assert_bool(source.find("func _physics_process(") != -1).is_false()


# ---------------------------------------------------------------------------
# AC-3 & AC-4: Camera3D added to the real mission scenes, coexisting with
# Camera2D without error
# ---------------------------------------------------------------------------

func test_the_gap_scene_has_camera2d_and_camera3d_siblings() -> void:
	var packed: PackedScene = load(TheGapScenePath)
	var scene: Node2D = packed.instantiate() as Node2D
	add_child(scene)

	var camera_2d: Camera2D = scene.get_node(NodePath("Camera2D")) as Camera2D
	var camera_3d: Camera3D = scene.get_node(NodePath("Camera3D")) as Camera3D
	assert_object(camera_2d).is_not_null()
	assert_object(camera_3d).is_not_null()

	remove_child(scene)
	scene.free()
	GGrid.initialize(GridConfig.new())  # cross-suite isolation, matches mission_scene_the_gap_test.gd's own established fix


func test_the_gap_scene_camera3d_is_fixed_angle_and_not_current_by_default() -> void:
	var packed: PackedScene = load(TheGapScenePath)
	var scene: Node2D = packed.instantiate() as Node2D
	add_child(scene)

	var camera_3d: Camera3D = scene.get_node(NodePath("Camera3D")) as Camera3D
	# "Fixed-angle, non-rotating" per ADR-0037's Decision — no per-frame
	# rotation logic exists (this is a plain scene node, not driven by any
	# script), and Camera2D remains the active view until a later story
	# explicitly cuts over (ADR-0037's Migration Plan: no mass "flip a
	# switch" cutover). is_false() here is also the regression guard for the
	# real bug found live: Godot auto-promotes a lone Camera3D to current on
	# _enter_tree(), overriding the .tscn's stored current=false — fixed by
	# the_gap.gd's _ready() re-asserting it explicitly.
	assert_bool(camera_3d.current).is_false()
	# qa-tester code-review finding: guard against the camera silently being
	# left at the scene's Vector3.ZERO/no-rotation default (e.g. an accidental
	# reset), which the current==false check alone wouldn't catch.
	assert_bool(camera_3d.position != Vector3.ZERO).is_true()
	assert_bool(camera_3d.rotation_degrees != Vector3.ZERO).is_true()

	remove_child(scene)
	scene.free()
	GGrid.initialize(GridConfig.new())


func test_toggling_current_between_camera2d_and_camera3d_does_not_error() -> void:
	var packed: PackedScene = load(TheGapScenePath)
	var scene: Node2D = packed.instantiate() as Node2D
	add_child(scene)

	var camera_2d: Camera2D = scene.get_node(NodePath("Camera2D")) as Camera2D
	var camera_3d: Camera3D = scene.get_node(NodePath("Camera3D")) as Camera3D

	camera_2d.enabled = false
	camera_3d.current = true
	assert_bool(camera_3d.current).is_true()

	camera_3d.current = false
	camera_2d.enabled = true
	assert_bool(camera_2d.enabled).is_true()

	remove_child(scene)
	scene.free()
	GGrid.initialize(GridConfig.new())


## Edge case (story's own QA Test Cases): both cameras enabled/current
## simultaneously must not crash, even if the render doesn't make sense.
func test_both_cameras_current_simultaneously_does_not_crash() -> void:
	var packed: PackedScene = load(TheGapScenePath)
	var scene: Node2D = packed.instantiate() as Node2D
	add_child(scene)

	var camera_2d: Camera2D = scene.get_node(NodePath("Camera2D")) as Camera2D
	var camera_3d: Camera3D = scene.get_node(NodePath("Camera3D")) as Camera3D

	camera_2d.enabled = true
	camera_3d.current = true
	assert_bool(camera_2d.enabled).is_true()
	assert_bool(camera_3d.current).is_true()

	remove_child(scene)
	scene.free()
	GGrid.initialize(GridConfig.new())


## Edge case (story's own QA Test Cases): neither camera current must not
## crash.
func test_neither_camera_current_does_not_crash() -> void:
	var packed: PackedScene = load(TheGapScenePath)
	var scene: Node2D = packed.instantiate() as Node2D
	add_child(scene)

	var camera_2d: Camera2D = scene.get_node(NodePath("Camera2D")) as Camera2D
	var camera_3d: Camera3D = scene.get_node(NodePath("Camera3D")) as Camera3D

	camera_2d.enabled = false
	camera_3d.current = false
	assert_bool(camera_2d.enabled).is_false()
	assert_bool(camera_3d.current).is_false()

	remove_child(scene)
	scene.free()
	GGrid.initialize(GridConfig.new())


func test_mission_scene_has_camera2d_and_camera3d_siblings() -> void:
	GMissionSelect.reset_to_defaults()
	GMissionSelect._restore_completed = true
	var runner: GdUnitSceneRunner = scene_runner("res://src/scenes/MissionScene.tscn")
	@warning_ignore("unsafe_cast")
	var scene: Node2D = runner.scene() as Node2D

	var camera_2d: Camera2D = scene.get_node(NodePath("GameplayRoot/Camera2D")) as Camera2D
	var camera_3d: Camera3D = scene.get_node(NodePath("GameplayRoot/Camera3D")) as Camera3D
	assert_object(camera_2d).is_not_null()
	assert_object(camera_3d).is_not_null()

	# qa-tester code-review finding: the_gap.tscn had a dedicated
	# current=false/fixed-angle assertion (above); MissionScene.tscn — the
	# real gameplay path, not just the secondary/test scene — did not, an
	# asymmetric coverage gap for AC-3/AC-4. Closing it here: this is also
	# the regression guard for mission_scene.gd's own copy of the Camera3D
	# auto-promotion fix (_gameplay_root.get_node("Camera3D").current = false
	# in _ready()).
	assert_bool(camera_3d.current).is_false()
	assert_bool(camera_3d.position != Vector3.ZERO).is_true()
	assert_bool(camera_3d.rotation_degrees != Vector3.ZERO).is_true()

	GMissionSelect.reset_to_defaults()
