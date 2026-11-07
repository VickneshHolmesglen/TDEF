extends GdUnitTestSuite

## Painted-vector art style (spec 2026-11-08-painted-vector-style-design):
## a profile's art_style switches the ground, water and dressing builders;
## "hd2d" stays exactly as before.

const PROFILE_PATH := "res://assets/data/hd2d/the_gap_scenery.tres"
const SURFACE_TEST := "res://tests/unit/visual_presentation/terrain_surface_test.gd"

var _scenery: Hd2dScenery


func _make(style: String, with_terrain: bool) -> void:
	var cfg: GridConfig = load(SURFACE_TEST)._config()
	_scenery = auto_free(Hd2dScenery.new())
	var profile: Hd2dSceneryProfile = (load(PROFILE_PATH) as Hd2dSceneryProfile).duplicate()
	profile.art_style = style
	_scenery.profile = profile
	add_child(_scenery)
	_scenery.set_terrain(TerrainSurface.from_config(cfg, TerrainTuning.load_default()) if with_terrain else null)
	_scenery.build(cfg.cols, cfg.rows, cfg.cell_size, cfg.cells)


func _ground_shader() -> Shader:
	return ((_scenery.get_node("Ground") as MeshInstance3D).material_override as ShaderMaterial).shader


func test_painted_ground_shader_flat_and_terrain() -> void:
	_make("painted", false)
	assert_object(_ground_shader()).is_same(Hd2dScenery.PAINTED_GROUND_SHADER)
	_make("painted", true)
	assert_object(_ground_shader()).is_same(Hd2dScenery.PAINTED_GROUND_SHADER)
	var water: MeshInstance3D = _scenery.get_node("Water")
	assert_object((water.material_override as ShaderMaterial).shader).is_same(Hd2dScenery.PAINTED_WATER_SHADER)


func test_hd2d_style_unchanged() -> void:
	_make("hd2d", true)
	assert_object(_ground_shader()).is_same(Hd2dScenery.GROUND_SHADER)
	assert_object((_scenery.get_node("Water").material_override as ShaderMaterial).shader).is_same(Hd2dScenery.WATER_SHADER)


func test_painted_trees_are_painted_blobs() -> void:
	_make("painted", true)
	var trees: int = 0
	for n: Node in _scenery.get_children():
		if String(n.name).begins_with("Tree") or String(n.name).begins_with("Pine"):
			trees += 1
			for c: Node in n.get_children():
				var mi := c as MeshInstance3D
				assert_object(mi).is_not_null()
				assert_object((mi.material_override as ShaderMaterial).shader).is_same(Hd2dScenery.PAINTED_PROP_SHADER)
	assert_int(trees).is_greater(0)


func test_painted_grass_is_tufts() -> void:
	_make("painted", true)
	var grass: Array[Node] = _scenery.find_children("Grass*", "MultiMeshInstance3D", false, false)
	assert_int(grass.size()).is_greater(0)
	for n: Node in grass:
		var mmi := n as MultiMeshInstance3D
		assert_object((mmi.material_override as ShaderMaterial).shader).is_same(Hd2dScenery.PAINTED_PROP_SHADER)


func test_painted_profile_validates() -> void:
	var p: Hd2dSceneryProfile = (load(PROFILE_PATH) as Hd2dSceneryProfile).duplicate()
	p.art_style = "painted"
	assert_array(p.validate()).is_empty()
	p.art_style = "oil"
	assert_array(p.validate()).is_not_empty()
