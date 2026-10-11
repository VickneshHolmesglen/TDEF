class_name Hd2dScenery
extends Node3D

## HD-2D scenery layer (ADR-0042; target look docs/images/graphics.PNG).
##
## Pure presentation, under a mission's PresentationRoot3D: a painted 2D ground
## plus 3D grass, flowers, shrubs, trees, fence, ruins and rocks, lit by its own
## sun and seen through its own orthographic Camera3D. Gameplay, picking and
## every 2D overlay keep running on the 2D canvas and Camera2D untouched; this
## layer renders underneath them.
##
## Alignment: the camera is tilted by `camera_pitch_deg`, and the ground's depth
## axis is stretched by 1/sin(pitch) (to_world()). An orthographic camera maps
## ground depth to screen by sin(pitch), so the two cancel and every ground
## point lands on the same screen pixel as the 2D map. Upright props still show
## their sides (foreshortened by cos(pitch)). follow_camera() re-derives the
## ortho camera from the Camera2D every frame, so zoom, framing and screen
## shake stay in lockstep.
##
## Everything this node creates sits on RENDER_LAYER and the camera culls to
## that layer only, so the dormant ADR-0037 3D companions sharing this World3D
## are never drawn by it.

## VisualInstance3D layer bit for every scenery node (layer 12; unused elsewhere).
const RENDER_LAYER: int = 1 << 11
const GROUND_SHADER: Shader = preload("res://src/shaders/hd2d_ground.gdshader")
const CARD_SHADER: Shader = preload("res://src/shaders/hd2d_foliage_card.gdshader")
## Lane-mask resolution, px per cell (linear-filtered, so 4 keeps corners round).
const MASK_RES: int = 4
## Off-grid border, in cells, that still gets ground, lanes and dressing.
const MARGIN_CELLS: int = 3
const CAMERA_DISTANCE: float = 3000.0

@export var profile: Hd2dSceneryProfile

var _camera: Camera3D
var _follow: Camera2D
var _z_stretch: float = 1.0
var _cols: int = 0
var _rows: int = 0
var _cell: float = 64.0
var _lane: Dictionary = {}        # Vector2i -> true: path cells plus off-map run-outs
var _landmarks: Array[Vector2i] = []
var _blocked: Array[Vector2i] = []
var _rng := RandomNumberGenerator.new()
var _material_cache: Dictionary = {}


## Builds the whole layer for a grid. `cells` is GridConfig.cells
## (Vector2i -> Grid.CellType). Call once; calling again rebuilds from scratch.
func build(cols: int, rows: int, cell_size: float, cells: Dictionary) -> void:
	if profile == null:
		push_error("[Hd2dScenery] no profile assigned -- scenery not built")
		return
	for err: String in profile.validate():
		push_error("[Hd2dScenery] profile: " + err)
	for child: Node in get_children():
		child.queue_free()
	_material_cache.clear()
	_cols = cols
	_rows = rows
	_cell = cell_size
	_z_stretch = 1.0 / sin(deg_to_rad(profile.camera_pitch_deg))
	_rng.seed = profile.rng_seed
	_classify(cells)
	_build_camera_and_light()
	_build_ground()
	_build_grass()
	_build_flowers()
	_build_bushes()
	_build_trees()
	if profile.fence_along_top:
		_build_fence()
	if profile.ruins_at_landmarks:
		_build_ruins()
	_build_rocks()


## Keeps the scenery camera locked to `camera` (call once after build()).
func follow_camera(camera: Camera2D) -> void:
	_follow = camera
	_sync_camera()


## 2D map position -> scenery world position (ground stretched, see class doc).
func to_world(p2d: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(p2d.x, height, p2d.y * _z_stretch)


func _process(_delta: float) -> void:
	_sync_camera()


func _sync_camera() -> void:
	if _follow == null or _camera == null or not is_instance_valid(_follow):
		return
	var zoom: float = maxf(_follow.zoom.y, 0.001)
	_camera.size = get_viewport().get_visible_rect().size.y / zoom
	var basis := Basis(Vector3.RIGHT, -deg_to_rad(profile.camera_pitch_deg))
	var target: Vector3 = to_world(_follow.get_screen_center_position())
	_camera.global_transform = Transform3D(basis, target + basis.z * CAMERA_DISTANCE)


# --- Layout ---------------------------------------------------------------

func _classify(cells: Dictionary) -> void:
	_lane.clear()
	_landmarks.clear()
	_blocked.clear()
	for c: Vector2i in cells:
		var t: int = cells[c]
		if t == Grid.CellType.PATH:
			_lane[c] = true
		elif t == Grid.CellType.SPAWN or t == Grid.CellType.GOAL:
			_landmarks.append(c)
		elif t == Grid.CellType.BLOCKED:
			_blocked.append(c)
	# Run the road off the map past each landmark that sits on the grid edge,
	# so monsters visibly arrive from (and leave into) the world beyond.
	for lm: Vector2i in _landmarks:
		var out := Vector2i.ZERO
		if lm.x == 0: out = Vector2i(-1, 0)
		elif lm.x == _cols - 1: out = Vector2i(1, 0)
		elif lm.y == 0: out = Vector2i(0, -1)
		elif lm.y == _rows - 1: out = Vector2i(0, 1)
		if out != Vector2i.ZERO:
			for i in range(1, MARGIN_CELLS + 1):
				_lane[lm + out * i] = true


func _cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * _cell


## True where dressing may stand: off the road (with a lip margin) and off the
## flagstone landmarks.
func _is_open_ground(p: Vector2) -> bool:
	var c := Vector2i(floori(p.x / _cell), floori(p.y / _cell))
	if _lane.has(c):
		return false
	for lm: Vector2i in _landmarks:
		if p.distance_to(_cell_center(lm)) < _cell * (profile.landmark_radius_cells + 0.1):
			return false
	var local: Vector2 = p - Vector2(c) * _cell
	var lip: float = _cell * 0.16
	if (_lane.has(c + Vector2i.RIGHT) and _cell - local.x < lip) or (_lane.has(c + Vector2i.LEFT) and local.x < lip) \
			or (_lane.has(c + Vector2i.DOWN) and _cell - local.y < lip) or (_lane.has(c + Vector2i.UP) and local.y < lip):
		return false
	return true


func _in_grid(p: Vector2) -> bool:
	return p.x >= 0.0 and p.y >= 0.0 and p.x < _cols * _cell and p.y < _rows * _cell


## Low-frequency patchiness so grass gathers in clumps like the reference.
func _patch(p: Vector2) -> float:
	var v: float = sin(p.x * 0.011 + 1.3) * cos(p.y * 0.014 - 0.4) * 0.6 + sin(p.x * 0.004 + p.y * 0.006) * 0.5 + 0.35
	return clampf(v, 0.0, 1.0)


func _random_point(margin_px: float) -> Vector2:
	return Vector2(_rng.randf_range(-margin_px, _cols * _cell + margin_px), _rng.randf_range(-margin_px, _rows * _cell + margin_px))


# --- Camera, light, ground ------------------------------------------------

func _build_camera_and_light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = profile.background_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = profile.ambient_color
	env.ambient_light_energy = profile.ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = profile.exposure
	env.ssao_enabled = true
	env.ssao_radius = 12.0
	env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = profile.saturation
	env.adjustment_contrast = profile.contrast

	_camera = Camera3D.new()
	_camera.name = "SceneryCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 1.0
	_camera.far = CAMERA_DISTANCE * 2.0
	_camera.cull_mask = RENDER_LAYER
	_camera.environment = env
	add_child(_camera)
	_camera.current = true

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = profile.sun_color
	sun.light_energy = profile.sun_energy
	sun.light_cull_mask = RENDER_LAYER
	# A Light3D is itself culled by the camera's cull_mask via its own `layers`
	# (live-found 2026-10-11: left on the default layer 1, the scenery camera
	# dropped its own sun and only ambient light reached the ground).
	sun.layers = RENDER_LAYER
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = CAMERA_DISTANCE * 2.0
	sun.rotation_degrees = profile.sun_rotation_deg
	add_child(sun)


func _build_ground() -> void:
	# Lane mask over the grid plus MARGIN_CELLS of border: R = dirt road,
	# G = round flagstone patch around each landmark.
	var mw: int = (_cols + MARGIN_CELLS * 2) * MASK_RES
	var mh: int = (_rows + MARGIN_CELLS * 2) * MASK_RES
	var img := Image.create(mw, mh, false, Image.FORMAT_RGBA8)
	for y in mh:
		for x in mw:
			var cell := Vector2i(floori(float(x) / MASK_RES) - MARGIN_CELLS, floori(float(y) / MASK_RES) - MARGIN_CELLS)
			var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / MASK_RES - Vector2(MARGIN_CELLS, MARGIN_CELLS)
			var g: float = 0.0
			for lm: Vector2i in _landmarks:
				var d: float = p.distance_to(Vector2(lm) + Vector2(0.5, 0.5))
				g = maxf(g, clampf((profile.landmark_radius_cells - d) * 2.0, 0.0, 1.0))
			img.set_pixel(x, y, Color(1.0 if _lane.has(cell) else 0.0, g, 0.0, 1.0))

	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter(&"grass_tex", profile.ground_grass)
	mat.set_shader_parameter(&"dirt_tex", profile.ground_dirt)
	mat.set_shader_parameter(&"stone_tex", profile.ground_stone)
	mat.set_shader_parameter(&"lane_mask", ImageTexture.create_from_image(img))
	mat.set_shader_parameter(&"mask_origin", -Vector2(MARGIN_CELLS, MARGIN_CELLS) * _cell)
	mat.set_shader_parameter(&"mask_size", Vector2(_cols + MARGIN_CELLS * 2, _rows + MARGIN_CELLS * 2) * _cell)
	mat.set_shader_parameter(&"z_stretch", _z_stretch)
	mat.set_shader_parameter(&"texel_world", profile.ground_texel_px)

	var map := Vector2(_cols, _rows) * _cell
	var plane := PlaneMesh.new()
	# Generous overscan: the ortho view must never show the plane's edge.
	plane.size = Vector2(map.x + _cell * 24.0, (map.y + _cell * 24.0) * _z_stretch)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(mi)
	mi.position = to_world(map * 0.5)


# --- Cards ----------------------------------------------------------------

## Two quads crossed at 90 degrees, pivot at the bottom centre, UV.y = 0 on top.
static func cross_card_mesh(w: float, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var half: Vector3 = axis * w * 0.5
		var up := Vector3.UP * h
		var quad: Array[Vector3] = [-half + up, half + up, half, -half]
		var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[i])
			st.add_vertex(quad[i])
	return st.commit()


func _card_material(tex: Texture2D, sway: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CARD_SHADER
	mat.set_shader_parameter(&"card_texture", tex)
	mat.set_shader_parameter(&"sway_amount", sway)
	return mat


func _scatter(node_name: String, mesh: Mesh, mat: Material, xforms: Array[Transform3D], colors: Array[Color]) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	_own(mmi)


func _build_grass() -> void:
	var cards: Array[Texture2D] = profile.grass_cards
	var per_card: Array = []
	for i in cards.size():
		per_card.append({"x": [] as Array[Transform3D], "c": [] as Array[Color]})
	var margin: float = _cell * MARGIN_CELLS
	var area: float = (_cols * _cell + margin * 2.0) * (_rows * _cell + margin * 2.0)
	var tries: int = int(area / (_cell * _cell) * profile.grass_per_cell)
	for i in tries:
		var p: Vector2 = _random_point(margin)
		var density: float = pow(_patch(p), 1.6)
		if _in_grid(p):
			density *= profile.grass_inner_factor
		if _rng.randf() > density or not _is_open_ground(p):
			continue
		var k: int = _rng.randi() % cards.size()
		var s: float = _rng.randf_range(0.75, 1.3)
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.85, 1.2), s))
		per_card[k]["x"].append(Transform3D(b, to_world(p)))
		var v: float = _rng.randf_range(0.66, 0.95)
		per_card[k]["c"].append(Color(v * 1.04, v, v * 0.82))
	for k in cards.size():
		var tex: Texture2D = cards[k]
		var h: float = profile.grass_height_px * float(tex.get_height()) / 64.0
		var w: float = h * float(tex.get_width()) / float(tex.get_height())
		_scatter("Grass%d" % k, cross_card_mesh(w, h), _card_material(tex, profile.grass_sway_px), per_card[k]["x"], per_card[k]["c"])


func _build_flowers() -> void:
	if profile.flower_card == null:
		return
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var tries: int = int(_cols * _rows * profile.flowers_per_cell)
	for i in tries:
		var p: Vector2 = _random_point(_cell)
		if not _is_open_ground(p):
			continue
		xforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), to_world(p)))
		colors.append(Color.WHITE)
	_scatter("Flowers", cross_card_mesh(16.0, 12.0), _card_material(profile.flower_card, 1.5), xforms, colors)


func _build_bushes() -> void:
	if profile.bush_card == null:
		return
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var placed: int = 0
	var guard: int = 0
	while placed < profile.bush_count and guard < profile.bush_count * 30:
		guard += 1
		var p: Vector2 = _random_point(_cell * 2.0)
		# Shrubs hug the map edge and the blocked border, out of the field.
		var c := Vector2i(floori(p.x / _cell), floori(p.y / _cell))
		if _in_grid(p) and not _blocked.has(c):
			continue
		if not _is_open_ground(p):
			continue
		var s: float = _rng.randf_range(0.8, 1.3)
		xforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), to_world(p)))
		var v: float = _rng.randf_range(0.8, 1.0)
		colors.append(Color(v, v, v))
		placed += 1
	_scatter("Bushes", cross_card_mesh(64.0, 44.0), _card_material(profile.bush_card, 1.0), xforms, colors)


# --- Trees ----------------------------------------------------------------

## Tree spots: the blocked border (not in front of the road's run-outs) and
## the strip just below the map, whose canopies rise into view.
func _tree_spots(count: int) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var guard: int = 0
	while spots.size() < count and guard < count * 40:
		guard += 1
		var p: Vector2
		if _rng.randf() < 0.55 and not _blocked.is_empty():
			var c: Vector2i = _blocked[_rng.randi() % _blocked.size()]
			p = _cell_center(c) + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12))
		else:
			p = Vector2(_rng.randf_range(-_cell, (_cols + 1) * _cell), _rng.randf_range(_rows * _cell + 10.0, (_rows + 1.5) * _cell))
		if not _is_open_ground(p):
			continue
		var crowded := false
		for q: Vector2 in spots:
			if q.distance_to(p) < _cell * 1.4:
				crowded = true
				break
		if not crowded:
			spots.append(p)
	return spots


func _build_trees() -> void:
	var spots: Array[Vector2] = _tree_spots(profile.broadleaf_count + profile.pine_count)
	for i in spots.size():
		var s: float = _rng.randf_range(0.85, 1.25)
		if i < profile.pine_count and profile.pine_card != null:
			_build_pine(spots[i], s)
		else:
			_build_broadleaf(spots[i], s)


func _std_material(tex: Texture2D, triplanar_scale: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s" % [tex.resource_path, triplanar_scale]
	if _material_cache.has(key):
		return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	if triplanar_scale > 0.0:
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * triplanar_scale
	_material_cache[key] = m
	return m


func _billboard_material(tex: Texture2D, shade: float) -> StandardMaterial3D:
	var key := "bb|%s|%.2f" % [tex.resource_path, shade]
	if _material_cache.has(key):
		return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(shade, shade, shade * 0.92)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.roughness = 1.0
	_material_cache[key] = m
	return m


func _build_broadleaf(p2d: Vector2, s: float) -> void:
	var tree := Node3D.new()
	tree.name = "Tree"
	add_child(tree)
	tree.position = to_world(p2d)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 6.0 * s
	trunk.bottom_radius = 10.0 * s
	trunk.height = 64.0 * s
	trunk.radial_segments = 7
	var tm := MeshInstance3D.new()
	tm.mesh = trunk
	tm.material_override = _std_material(profile.bark, 0.04)
	tm.layers = RENDER_LAYER
	tree.add_child(tm)
	tm.position = Vector3(0, trunk.height * 0.5, 0)
	# Canopy: overlapping camera-facing leaf clumps on a rough dome.
	for i in 16:
		var q := QuadMesh.new()
		var size: float = _rng.randf_range(42.0, 62.0) * s
		q.size = Vector2(size, size)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		var tex: Texture2D = profile.leaf_cards[_rng.randi() % profile.leaf_cards.size()]
		mi.material_override = _billboard_material(tex, snappedf(_rng.randf_range(0.62, 0.92), 0.05))
		mi.layers = RENDER_LAYER
		tree.add_child(mi)
		var a: float = _rng.randf() * TAU
		var r: float = _rng.randf_range(0.0, 34.0) * s
		mi.position = Vector3(cos(a) * r, 66.0 * s + _rng.randf_range(-10.0, 38.0) * s - r * 0.4, sin(a) * r)


func _build_pine(p2d: Vector2, s: float) -> void:
	var q := QuadMesh.new()
	var tex: Texture2D = profile.pine_card
	var h: float = 150.0 * s
	q.size = Vector2(h * float(tex.get_width()) / float(tex.get_height()), h)
	q.center_offset = Vector3(0, h * 0.5, 0)
	var mi := MeshInstance3D.new()
	mi.name = "Pine"
	mi.mesh = q
	var m: StandardMaterial3D = _billboard_material(tex, 0.9).duplicate()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mi.material_override = m
	_own(mi)
	mi.position = to_world(p2d)


# --- Fence, ruins, rocks --------------------------------------------------

func _box(size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	_own(mi)
	mi.position = pos
	mi.rotation_degrees = rot_deg


## A weathered rail fence along the top edge of the field (the reference's
## cliff-top fence), broken where the road crosses it.
func _build_fence() -> void:
	var wood: StandardMaterial3D = _std_material(profile.wood, 0.03)
	var y2d: float = _cell * 0.3
	var x: float = _cell * 0.6
	var step: float = 56.0
	while x < _cols * _cell - _cell * 0.6:
		var c := Vector2i(floori(x / _cell), 0)
		if not _lane.has(c) and not _landmarks.has(c):
			var lean: float = _rng.randf_range(-6.0, 6.0)
			_box(Vector3(9, 46, 9), to_world(Vector2(x, y2d), 23.0), wood, Vector3(lean, 0, lean * 0.5))
			if x + step < _cols * _cell - _cell * 0.6:
				_box(Vector3(step, 6, 4), to_world(Vector2(x + step * 0.5, y2d), 34.0), wood, Vector3(0, 0, _rng.randf_range(-3, 3)))
				_box(Vector3(step, 6, 4), to_world(Vector2(x + step * 0.5, y2d), 18.0), wood, Vector3(0, 0, _rng.randf_range(-3, 3)))
		x += step


## Broken brick pillars flanking each landmark, plus fallen blocks.
func _build_ruins() -> void:
	var brick: StandardMaterial3D = _std_material(profile.ruin_bricks, 0.035)
	for lm: Vector2i in _landmarks:
		var centre: Vector2 = _cell_center(lm)
		var inward := Vector2.ZERO
		if lm.x == 0: inward = Vector2.RIGHT
		elif lm.x == _cols - 1: inward = Vector2.LEFT
		elif lm.y == 0: inward = Vector2.DOWN
		else: inward = Vector2.UP
		var side := Vector2(-inward.y, inward.x)
		for sgn: float in [-1.0, 1.0]:
			var at: Vector2 = centre + side * sgn * _cell * 0.95 + inward * _cell * 0.2
			var h: float = _rng.randf_range(60.0, 110.0)
			_box(Vector3(30, h, 30), to_world(at, h * 0.5), brick, Vector3(0, _rng.randf_range(-10, 10), _rng.randf_range(-3, 3)))
			_box(Vector3(42, 8, 42), to_world(at, 4.0), brick)
		for i in 4:
			var at: Vector2 = centre + Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2)) * _cell
			if _lane.has(Vector2i(floori(at.x / _cell), floori(at.y / _cell))):
				continue
			_box(Vector3(20, 12, 16), to_world(at, 5.0), brick, Vector3(_rng.randf_range(-15, 15), _rng.randf() * 90.0, _rng.randf_range(-15, 15)))


func _build_rocks() -> void:
	if profile.rock == null:
		return
	var mat: StandardMaterial3D = _std_material(profile.rock, 0.05)
	var placed: int = 0
	var guard: int = 0
	while placed < profile.rock_count and guard < profile.rock_count * 30:
		guard += 1
		var p: Vector2 = _random_point(_cell)
		var c := Vector2i(floori(p.x / _cell), floori(p.y / _cell))
		if _in_grid(p) and not _blocked.has(c):
			continue
		if not _is_open_ground(p):
			continue
		var sphere := SphereMesh.new()
		var r: float = _rng.randf_range(10.0, 22.0)
		sphere.radius = r
		sphere.height = r * _rng.randf_range(1.1, 1.5)
		sphere.radial_segments = 6
		sphere.rings = 3
		var mi := MeshInstance3D.new()
		mi.name = "Rock"
		mi.mesh = sphere
		mi.material_override = mat
		_own(mi)
		mi.position = to_world(p, r * 0.25)
		mi.rotation_degrees = Vector3(_rng.randf_range(-12, 12), _rng.randf() * 360.0, _rng.randf_range(-12, 12))
		mi.scale = Vector3(_rng.randf_range(1.0, 1.5), 1.0, _rng.randf_range(0.9, 1.3))
		placed += 1


func _own(node: VisualInstance3D) -> void:
	node.layers = RENDER_LAYER
	add_child(node)
