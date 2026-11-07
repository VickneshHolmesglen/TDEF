extends GdUnitTestSuite

## Hd2dScenery on terrain (spec 2026-11-07-3d-terrain §6.1-6.3): heightfield
## ground, water surface only with water, props standing on the surface; no
## terrain = today's flat PlaneMesh ground.

const PROFILE_PATH := "res://assets/data/hd2d/the_gap_scenery.tres"
const SURFACE_TEST := "res://tests/unit/visual_presentation/terrain_surface_test.gd"
const CELL := 64.0

var _scenery: Hd2dScenery


func _make(with_terrain: bool, with_water: bool = true) -> TerrainSurface:
	var cfg: GridConfig = load(SURFACE_TEST)._config()
	# Raise every placeable cell from row 3 down (keeping the water cell low),
	# so the scattered dressing certainly lands on hills.
	for c: Vector2i in cfg.cells:
		if c.y >= 3 and not cfg.water.has(c):
			cfg.heights[c] = 1
	if not with_water:
		cfg.water = {}
	_scenery = auto_free(Hd2dScenery.new())
	_scenery.profile = load(PROFILE_PATH) as Hd2dSceneryProfile
	add_child(_scenery)
	var surface: TerrainSurface = TerrainSurface.from_config(cfg, TerrainTuning.load_default()) if with_terrain else null
	_scenery.set_terrain(surface)
	_scenery.build(cfg.cols, cfg.rows, cfg.cell_size, cfg.cells)
	return surface


func _p2d(o: Vector3) -> Vector2:
	return Vector2(o.x, o.z / _scenery.get_z_stretch())


func test_flat_scenery_ground_unchanged() -> void:
	_make(false)
	var ground: MeshInstance3D = _scenery.get_node("Ground")
	assert_object(ground.mesh).is_instanceof(PlaneMesh)
	assert_object(_scenery.get_node_or_null("Water")).is_null()
	assert_float(_scenery.ground_height(Vector2(5.5, 5.5) * CELL)).is_equal(0.0)
	assert_float(_scenery.screen_lift(Vector2(5.5, 5.5) * CELL)).is_equal(0.0)
	assert_vector(_scenery.screen_to_ground(Vector2(100, 200))).is_equal(Vector2(100, 200))


func test_terrain_ground_is_arraymesh_following_height() -> void:
	var surface: TerrainSurface = _make(true)
	var ground: MeshInstance3D = _scenery.get_node("Ground")
	assert_object(ground.mesh).is_instanceof(ArrayMesh)
	var verts: PackedVector3Array = (ground.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var top := Vector2(5.5, 5.5) * CELL
	var best: Vector3 = verts[0]
	for v: Vector3 in verts:
		if _p2d(v).distance_to(top) < _p2d(best).distance_to(top):
			best = v
	var gv: Vector3 = ground.global_transform * best
	assert_float(gv.y).is_equal_approx(surface.height_at(_p2d(gv)), 0.5)
	assert_float(gv.y).is_greater(0.4 * CELL)


func test_water_node_exists_only_with_water() -> void:
	var surface: TerrainSurface = _make(true)
	var water: MeshInstance3D = _scenery.get_node_or_null("Water")
	assert_object(water).is_not_null()
	assert_float(water.global_position.y).is_equal_approx(surface.water_level(), 0.01)
	assert_int(water.layers).is_equal(Hd2dScenery.RENDER_LAYER)


func test_no_water_node_on_dry_terrain() -> void:
	_make(true, false)
	assert_object(_scenery.get_node_or_null("Water")).is_null()


## Trees are plain nodes (MultiMesh instance transforms read back as zero
## under the headless renderer, so grass can't be checked here).
func test_props_sit_on_surface() -> void:
	_make(true)
	var checked: int = 0
	var on_hill: int = 0
	for n: Node in _scenery.get_children():
		if not (n is Node3D) or not (String(n.name).begins_with("Pine") or String(n.name).begins_with("Tree")):
			continue
		var o: Vector3 = (n as Node3D).position
		var p: Vector2 = _p2d(o)
		assert_float(o.y).override_failure_message(String(n.name)).is_equal_approx(_scenery.ground_height(p), 1.0)
		checked += 1
		if _scenery.ground_height(p) > 20.0:
			on_hill += 1
	assert_int(checked).is_greater(0)
	assert_int(on_hill).is_greater(0)


func test_no_dressing_in_water() -> void:
	_make(true)
	assert_bool(_scenery._is_open_ground(Vector2(10.5, 5.5) * CELL)).is_false()
	assert_bool(_scenery._is_open_ground(Vector2(5.5, 5.5) * CELL)).is_true()


func test_every_visual_on_scenery_layer_with_terrain() -> void:
	_make(true)
	for n: Node in _scenery.find_children("*", "VisualInstance3D", true, false):
		assert_int((n as VisualInstance3D).layers).is_equal(Hd2dScenery.RENDER_LAYER)
