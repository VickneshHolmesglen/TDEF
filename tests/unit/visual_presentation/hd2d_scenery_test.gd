extends GdUnitTestSuite

## ADR-0042 HD-2D scenery layer: the alignment contract (ground maps 1:1 onto
## the 2D map through the tilted ortho camera), render-layer isolation, and
## that dressing never lands on the road.

const PROFILE_PATH := "res://assets/data/hd2d/the_gap_scenery.tres"

var _scenery: Hd2dScenery


func _small_grid() -> Dictionary:
	# 6x4: a straight road along row 2 from spawn (0,2) to goal (5,2).
	var cells: Dictionary = {}
	for y in 4:
		for x in 6:
			var c := Vector2i(x, y)
			if c == Vector2i(0, 2):
				cells[c] = Grid.CellType.SPAWN
			elif c == Vector2i(5, 2):
				cells[c] = Grid.CellType.GOAL
			elif y == 2:
				cells[c] = Grid.CellType.PATH
			elif y == 0 or y == 3:
				cells[c] = Grid.CellType.BLOCKED
			else:
				cells[c] = Grid.CellType.PLACEABLE
	return cells


func before_test() -> void:
	_scenery = auto_free(Hd2dScenery.new())
	_scenery.profile = load(PROFILE_PATH) as Hd2dSceneryProfile
	add_child(_scenery)
	_scenery.build(6, 4, 64.0, _small_grid())


func test_profile_validates_clean() -> void:
	assert_array(_scenery.profile.validate()).is_empty()


func test_to_world_stretches_depth_by_inverse_sin_pitch() -> void:
	var pitch := deg_to_rad(_scenery.profile.camera_pitch_deg)
	var w: Vector3 = _scenery.to_world(Vector2(100.0, 200.0), 5.0)
	assert_float(w.x).is_equal_approx(100.0, 0.001)
	assert_float(w.y).is_equal_approx(5.0, 0.001)
	assert_float(w.z).is_equal_approx(200.0 / sin(pitch), 0.001)


func test_ortho_camera_projects_ground_onto_matching_2d_screen_offsets() -> void:
	# Two ground points 2D-separated by (dx, dy) must land (dx, dy) * zoom
	# apart on screen -- the property that keeps 2D gameplay aligned.
	var cam2d: Camera2D = auto_free(Camera2D.new())
	add_child(cam2d)
	cam2d.position = Vector2(192.0, 128.0)
	cam2d.zoom = Vector2(1.0, 1.0)
	cam2d.make_current()
	_scenery.follow_camera(cam2d)
	var cam3d: Camera3D = _scenery.get_node("SceneryCamera")
	var a: Vector2 = cam3d.unproject_position(_scenery.to_world(Vector2(100.0, 50.0)))
	var b: Vector2 = cam3d.unproject_position(_scenery.to_world(Vector2(160.0, 130.0)))
	var vp_h: float = get_viewport().get_visible_rect().size.y
	var px_per_unit: float = vp_h / cam3d.size
	assert_float((b - a).x / px_per_unit).is_equal_approx(60.0, 0.5)
	assert_float((b - a).y / px_per_unit).is_equal_approx(80.0, 0.5)


func test_camera_sun_and_every_visual_sit_on_the_scenery_layer_only() -> void:
	var cam3d: Camera3D = _scenery.get_node("SceneryCamera")
	assert_int(cam3d.cull_mask).is_equal(Hd2dScenery.RENDER_LAYER)
	for n: Node in _scenery.find_children("*", "VisualInstance3D", true, false):
		assert_int((n as VisualInstance3D).layers).is_equal(Hd2dScenery.RENDER_LAYER)


func test_grass_never_stands_on_the_road() -> void:
	for n: Node in _scenery.find_children("Grass*", "MultiMeshInstance3D", false, false):
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		for i in mm.instance_count:
			var o: Vector3 = mm.get_instance_transform(i).origin
			var p2d := Vector2(o.x, o.z * sin(deg_to_rad(_scenery.profile.camera_pitch_deg)))
			var cell := Vector2i(floori(p2d.x / 64.0), floori(p2d.y / 64.0))
			assert_bool(cell.y == 2 and cell.x >= 0 and cell.x <= 5).override_failure_message("grass on road cell %s" % cell).is_false()
