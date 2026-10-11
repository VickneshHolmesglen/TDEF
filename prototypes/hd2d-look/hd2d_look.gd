extends Node3D
## HD-2D look prototype (2026-10-11, target: docs/images/graphics.PNG).
## Builds The Gap's real 16x12 lane layout as a painted 2D ground plane with
## 3D extras on top: swaying grass tufts, billboard-leaf trees, a fence line,
## ruined pillars, warm sun, depth-of-field. Everything is procedural -- the
## only inputs are the generated textures in assets/art/hd2d/.

const COLS := 16
const ROWS := 12
const CELL := 64.0
const SPAWN := Vector2i(0, 6)
const GOAL := Vector2i(15, 6)
const ART := "res://assets/art/hd2d/"
const MASK_RES := 4
const MARGIN := 3

var _rng := RandomNumberGenerator.new()
var _path: Dictionary = {}


func _ready() -> void:
	_rng.seed = 20261011
	for seg: Array in [[Vector2i(0, 6), Vector2i(4, 6)], [Vector2i(4, 6), Vector2i(4, 2)],
			[Vector2i(4, 2), Vector2i(10, 2)], [Vector2i(10, 2), Vector2i(10, 9)],
			[Vector2i(10, 9), Vector2i(14, 9)], [Vector2i(14, 9), Vector2i(14, 6)],
			[Vector2i(14, 6), Vector2i(15, 6)]]:
		var a: Vector2i = seg[0]
		var b: Vector2i = seg[1]
		var d := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var c := a
		while true:
			_path[c] = true
			if c == b:
				break
			c += d
	_build_environment()
	_build_ground()
	_build_grass()
	_build_flowers()
	_build_trees()
	_build_fence()
	_build_ruins()
	_build_hero()


func _cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0.0, (c.y + 0.5) * CELL)


func _is_border(c: Vector2i) -> bool:
	return c.x == 0 or c.y == 0 or c.x == COLS - 1 or c.y == ROWS - 1


func _tex(name: String) -> Texture2D:
	return load(ART + name) as Texture2D


# --- Environment / camera -------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.16, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.56, 0.68)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.ssao_enabled = true
	env.ssao_radius = 12.0
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.08
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.9
	env.adjustment_contrast = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 2200.0
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	add_child(sun)

	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.far = 4000.0
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 1150.0
	attrs.dof_blur_far_transition = 500.0
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = 700.0
	attrs.dof_blur_near_transition = 260.0
	attrs.dof_blur_amount = 0.12
	cam.attributes = attrs
	add_child(cam)
	cam.look_at_from_position(Vector3(512.0, 700.0, 1040.0), Vector3(512.0, 0.0, 410.0))
	cam.current = true


# --- Ground ---------------------------------------------------------------

func _build_ground() -> void:
	# Lane mask, MASK_RES px per cell over the grid plus a MARGIN-cell border,
	# linear-filtered in the shader: R = dirt (path, extended off-map past the
	# spawn and goal), G = flagstone (round patches at spawn/goal).
	var w := (COLS + MARGIN * 2) * MASK_RES
	var h := (ROWS + MARGIN * 2) * MASK_RES
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	var lane: Dictionary = _path.duplicate()
	for i in range(1, MARGIN + 1):
		lane[SPAWN + Vector2i(-i, 0)] = true
		lane[GOAL + Vector2i(i, 0)] = true
	for y in h:
		for x in w:
			var cell := Vector2i(floori(float(x) / MASK_RES) - MARGIN, floori(float(y) / MASK_RES) - MARGIN)
			var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / MASK_RES - Vector2(MARGIN, MARGIN)
			var r := 1.0 if lane.has(cell) else 0.0
			var g := 0.0
			for lm: Vector2i in [SPAWN, GOAL]:
				var d := p.distance_to(Vector2(lm) + Vector2(0.5, 0.5))
				g = maxf(g, clampf((1.25 - d) * 2.0, 0.0, 1.0))
			img.set_pixel(x, y, Color(r, g, 0, 1))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://prototypes/hd2d-look/hd2d_ground.gdshader")
	mat.set_shader_parameter(&"grass_tex", _tex("ground_grass.png"))
	mat.set_shader_parameter(&"dirt_tex", _tex("ground_dirt.png"))
	mat.set_shader_parameter(&"stone_tex", _tex("ground_stone.png"))
	mat.set_shader_parameter(&"lane_mask", ImageTexture.create_from_image(img))
	mat.set_shader_parameter(&"map_size", Vector2(COLS + MARGIN * 2, ROWS + MARGIN * 2) * CELL)
	mat.set_shader_parameter(&"map_origin", -Vector2(MARGIN, MARGIN) * CELL)
	var plane := PlaneMesh.new()
	plane.size = Vector2(COLS * CELL + 1600.0, ROWS * CELL + 1600.0)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(COLS * CELL * 0.5, 0.0, ROWS * CELL * 0.5)
	add_child(mi)


# --- Card meshes ----------------------------------------------------------

## Two quads crossed at 90 degrees, pivot at the bottom centre.
func _cross_card(w: float, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var half := axis * w * 0.5
		var up := Vector3.UP * h
		var quad: Array[Vector3] = [-half + up, half + up, half, -half]
		var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[i])
			st.set_color(Color.WHITE)
			st.add_vertex(quad[i])
	return st.commit()


func _card_material(tex_name: String, sway: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://prototypes/hd2d-look/hd2d_card.gdshader")
	mat.set_shader_parameter(&"card_texture", _tex(tex_name))
	mat.set_shader_parameter(&"sway_amount", sway)
	return mat


func _scatter(mesh: Mesh, mat: Material, xforms: Array[Transform3D], colors: Array[Color]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)


# --- Grass / flowers ------------------------------------------------------

## Tall-grass density: low-frequency noise so tufts gather in patches like
## the reference instead of an even carpet.
func _patch_density(p: Vector2) -> float:
	return clampf(sin(p.x * 0.011 + 1.3) * cos(p.y * 0.014 - 0.4) * 0.6 + sin(p.x * 0.004 + p.y * 0.006) * 0.5 + 0.35, 0.0, 1.0)


func _off_lane(p: Vector2) -> bool:
	var c := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	if _path.has(c) or c == SPAWN or c == GOAL:
		return false
	if (c.y == SPAWN.y and c.x < 0) or (c.y == GOAL.y and c.x >= COLS):
		return false
	for lm: Vector2i in [SPAWN, GOAL]:
		if p.distance_to((Vector2(lm) + Vector2(0.5, 0.5)) * CELL) < CELL * 1.3:
			return false
	# Keep a soft margin off the dirt so tufts sit on the grass lip, not on the road.
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := c + d
		if _path.has(n):
			var local := p - Vector2(c) * CELL
			var dist := 99.0
			if d.x == 1: dist = CELL - local.x
			elif d.x == -1: dist = local.x
			elif d.y == 1: dist = CELL - local.y
			else: dist = local.y
			if dist < 10.0:
				return false
	return true


func _build_grass() -> void:
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var area := Rect2(-260, -220, COLS * CELL + 520, ROWS * CELL + 440)
	for i in 6500:
		var p := Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
		if _rng.randf() > pow(_patch_density(p), 1.8) or not _off_lane(p):
			continue
		var s := _rng.randf_range(0.7, 1.35)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.85, 1.25), s))
		xforms.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
		var v := _rng.randf_range(0.62, 0.9)
		colors.append(Color(v * 1.04, v, v * 0.82))
	_scatter(_cross_card(30.0, 30.0), _card_material("card_grass.png", 3.5), xforms, colors)


func _build_flowers() -> void:
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in 420:
		var p := Vector2(_rng.randf_range(0, COLS * CELL), _rng.randf_range(0, ROWS * CELL))
		if not _off_lane(p):
			continue
		var basis := Basis(Vector3.UP, _rng.randf() * TAU)
		xforms.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
		colors.append(Color.WHITE)
	_scatter(_cross_card(16.0, 12.0), _card_material("card_flowers.png", 1.5), xforms, colors)


# --- Trees ----------------------------------------------------------------

func _build_trees() -> void:
	var spots: Array[Vector3] = []
	# Back tree line beyond the top edge, plus side clusters -- frames the
	# field the way the reference's canopy does without covering the lanes.
	for i in 9:
		spots.append(Vector3(_rng.randf_range(-120, COLS * CELL + 120), 0, _rng.randf_range(-170, -60)))
	for i in 4:
		spots.append(Vector3(_rng.randf_range(-170, -50), 0, _rng.randf_range(80, ROWS * CELL - 40)))
		spots.append(Vector3(_rng.randf_range(COLS * CELL + 50, COLS * CELL + 170), 0, _rng.randf_range(80, ROWS * CELL - 40)))
	for c: Vector2i in [Vector2i(1, 1), Vector2i(7, 10), Vector2i(13, 1), Vector2i(12, 5)]:
		spots.append(_cell_center(c))
	for s in spots:
		_build_tree(s, _rng.randf_range(0.8, 1.25))


func _build_tree(at: Vector3, s: float) -> void:
	var bark := StandardMaterial3D.new()
	bark.albedo_texture = _tex("mat_bark.png")
	bark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bark.uv1_scale = Vector3(3, 2, 1)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 6.0 * s
	trunk.bottom_radius = 10.0 * s
	trunk.height = 70.0 * s
	trunk.radial_segments = 7
	var tm := MeshInstance3D.new()
	tm.mesh = trunk
	tm.material_override = bark
	tm.position = at + Vector3(0, trunk.height * 0.5, 0)
	add_child(tm)

	# Canopy: overlapping camera-facing leaf clumps on a rough dome.
	for i in 16:
		var leaf := StandardMaterial3D.new()
		leaf.albedo_texture = _tex("card_leaves_%d.png" % (i % 3))
		leaf.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		leaf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		leaf.alpha_scissor_threshold = 0.5
		leaf.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		leaf.billboard_keep_scale = true
		var shade := _rng.randf_range(0.62, 0.9)
		leaf.albedo_color = Color(shade, shade, shade * 0.92)
		var q := QuadMesh.new()
		var size := _rng.randf_range(42.0, 62.0) * s
		q.size = Vector2(size, size)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = leaf
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.0, 34.0) * s
		var h := 72.0 * s + _rng.randf_range(-10.0, 38.0) * s - r * 0.4
		mi.position = at + Vector3(cos(a) * r, h, sin(a) * r)
		add_child(mi)


# --- Fence / ruins --------------------------------------------------------

func _box(size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> void:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)


func _tiled_mat(tex_name: String, scale: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(tex_name)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_scale = scale
	return m


func _build_fence() -> void:
	var wood := _tiled_mat("mat_wood.png", Vector3(0.03, 0.03, 0.03))
	var z := 18.0
	var x := 40.0
	while x < COLS * CELL - 30.0:
		var lean := _rng.randf_range(-6.0, 6.0)
		_box(Vector3(9, 44, 9), Vector3(x, 22, z), wood, Vector3(lean, 0, lean * 0.5))
		if x + 56.0 < COLS * CELL - 30.0:
			_box(Vector3(56, 6, 4), Vector3(x + 28.0, 34, z), wood, Vector3(0, 0, _rng.randf_range(-3, 3)))
			_box(Vector3(56, 6, 4), Vector3(x + 28.0, 18, z), wood, Vector3(0, 0, _rng.randf_range(-3, 3)))
		x += 56.0


func _build_ruins() -> void:
	var brick := _tiled_mat("mat_ruin_bricks.png", Vector3(0.035, 0.035, 0.035))
	# Broken pillars flanking the goal and spawn, a few fallen blocks.
	var pillars: Array = [
		[Vector3(15.0 * CELL - 20, 0, 5.0 * CELL + 10), 70.0],
		[Vector3(15.0 * CELL - 20, 0, 8.0 * CELL - 10), 46.0],
		[Vector3(0.0 * CELL + 84, 0, 5.0 * CELL + 6), 38.0],
		[Vector3(0.0 * CELL + 84, 0, 8.0 * CELL - 6), 58.0],
	]
	for p: Array in pillars:
		var at: Vector3 = p[0]
		var h: float = p[1]
		_box(Vector3(34, h * 1.6, 34), at + Vector3(0, h * 0.8, 0), brick, Vector3(0, _rng.randf_range(-10, 10), _rng.randf_range(-3, 3)))
		_box(Vector3(46, 8, 46), at + Vector3(0, 3, 0), brick)
	for i in 7:
		var at := Vector3(15.0 * CELL + _rng.randf_range(-70, 30), 4, 6.5 * CELL + _rng.randf_range(-90, 90))
		_box(Vector3(20, 12, 16), at, brick, Vector3(_rng.randf_range(-15, 15), _rng.randf() * 90, _rng.randf_range(-15, 15)))


func _build_hero() -> void:
	# Scale reference only: the hero sprite as an upright billboard on the lane.
	var s := Sprite3D.new()
	s.texture = load("res://assets/art/characters/hero_warden_smith.png")
	# Size from the imported texture: the import may downscale the source PNG.
	var tex_h := float(s.texture.get_height())
	s.pixel_size = 120.0 / tex_h
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.offset = Vector2(0, tex_h * 0.5)
	s.position = _cell_center(Vector2i(7, 2))
	add_child(s)
