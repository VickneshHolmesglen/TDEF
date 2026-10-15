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
## 2D-map rects that in-field debris must avoid (set before build()). The
## Sanctuary town passes its buildings' art rects: the 2D buttons hide
## anything behind them, and a prop peeking out reads as clutter.
var keep_out: Array[Rect2] = []

var _camera: Camera3D
var _follow: Camera2D
## Fixed 2D rect to frame instead of following a Camera2D (frame_rect()).
var _frame: Rect2 = Rect2()
var _z_stretch: float = 1.0
var _cols: int = 0
var _rows: int = 0
var _cell: float = 64.0
var _lane: Dictionary = {}        # Vector2i -> true: path cells plus off-map run-outs
var _landmarks: Array[Vector2i] = []
var _blocked: Array[Vector2i] = []
var _rng := RandomNumberGenerator.new()
## Kit-model choices (variant, yaw) and the debris pass draw from their own
## stream so enabling kit meshes never shifts the main layout.
var _kit_rng := RandomNumberGenerator.new()
var _material_cache: Dictionary = {}
var _kit_mesh_cache: Dictionary = {}  # PackedScene path -> Mesh


## Builds the whole layer for a grid. `cells` is GridConfig.cells
## (Vector2i -> Grid.CellType). Call once; calling again rebuilds from scratch.
func build(cols: int, rows: int, cell_size: float, cells: Dictionary) -> void:
	if profile == null:
		push_error("[Hd2dScenery] no profile assigned -- scenery not built")
		return
	for err: String in profile.validate():
		push_error("[Hd2dScenery] profile: " + err)
	for child: Node in get_children():
		# Detach now so the rebuilt nodes keep their plain names ("Ground", ...).
		remove_child(child)
		child.queue_free()
	_material_cache.clear()
	_cols = cols
	_rows = rows
	_cell = cell_size
	_z_stretch = 1.0 / sin(deg_to_rad(profile.camera_pitch_deg))
	_rng.seed = profile.rng_seed
	_kit_rng.seed = profile.rng_seed + 7919
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
	# Mission-specific dressing (2026-10-11). Built last so the shared scatter
	# above keeps its RNG sequence, and with it The Gap's exact layout.
	_build_lane_edges()
	_build_spires()
	_build_crystals()
	_build_debris()


## The 2D gameplay layer's light for this mission (ADR-0042 unit pass): a
## CanvasModulate named "UnitLight" under `canvas_host`, created on first use.
## It tints every CanvasItem on that canvas (units, towers, VFX) but not
## CanvasLayers such as the HUD.
static func apply_unit_light(canvas_host: Node, tint: Color) -> void:
	var light: CanvasModulate = canvas_host.get_node_or_null(^"UnitLight") as CanvasModulate
	if light == null:
		light = CanvasModulate.new()
		light.name = "UnitLight"
		canvas_host.add_child(light)
	light.color = tint


## Keeps the scenery camera locked to `camera` (call once after build()).
func follow_camera(camera: Camera2D) -> void:
	_follow = camera
	_sync_camera()


## Shows/hides the layer and hands the viewport camera to it (or releases it).
## MissionScene keeps the scenery inactive behind the mission-select screen.
func set_active(active: bool) -> void:
	visible = active
	if _camera != null:
		_camera.current = active


## 2D map position -> scenery world position (ground stretched, see class doc).
func to_world(p2d: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(p2d.x, height, p2d.y * _z_stretch)


func _process(_delta: float) -> void:
	_sync_camera()


func _sync_camera() -> void:
	if _camera == null:
		return
	var centre: Vector2
	if _frame.size.y > 0.0:
		_camera.size = _frame.size.y
		centre = _frame.get_center()
	elif _follow != null and is_instance_valid(_follow):
		var zoom: float = maxf(_follow.zoom.y, 0.001)
		_camera.size = get_viewport().get_visible_rect().size.y / zoom
		centre = _follow.get_screen_center_position()
	else:
		return
	var basis := Basis(Vector3.RIGHT, -deg_to_rad(profile.camera_pitch_deg))
	_camera.global_transform = Transform3D(basis, to_world(centre) + basis.z * CAMERA_DISTANCE)


## Frames a fixed 2D map rect instead of following a Camera2D -- for a
## scenery rendered into its own SubViewport behind a UI (the Sanctuary
## diorama). The viewport's aspect must match `rect`'s.
func frame_rect(rect: Rect2) -> void:
	_follow = null
	_frame = rect
	_sync_camera()


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
	mat.set_shader_parameter(&"lane_shimmer", profile.lane_shimmer)
	mat.set_shader_parameter(&"lane_scale", profile.lane_scale)

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


## One upright quad facing the scenery camera (which never yaws), pivot at
## the bottom centre. For wide cards a crossed pair would show as an X.
static func facing_card_mesh(w: float, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad: Array[Vector3] = [Vector3(-w * 0.5, h, 0), Vector3(w * 0.5, h, 0), Vector3(w * 0.5, 0, 0), Vector3(-w * 0.5, 0, 0)]
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
		per_card[k]["c"].append(Color(v * profile.grass_tint.r, v * profile.grass_tint.g, v * profile.grass_tint.b))
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
		_rng.randf()  # was the card's yaw; still drawn so later scatter keeps its RNG sequence
		xforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), to_world(p)))
		var v: float = _rng.randf_range(0.8, 1.0)
		colors.append(Color(v, v, v))
		placed += 1
	_scatter("Bushes", facing_card_mesh(64.0, 44.0), _card_material(profile.bush_card, 1.0), xforms, colors)


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
		if not _is_open_ground(p) or not _clear_above(p, 150.0, _cell * 0.5):
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
	m.albedo_color = Color(shade, shade, shade * 0.92) * profile.foliage_tint
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
	var h: float = 150.0 * s
	if not profile.kit_pines.is_empty():
		var kit: MeshInstance3D = _kit_instance(_kit_pick(profile.kit_pines), null)
		kit.name = "Pine"
		var size: Vector3 = kit.mesh.get_aabb().size
		var k: float = h / size.y
		# Kenney pines are slender; widen a little to match the reference's
		# full-bodied conifers.
		kit.scale = Vector3(k * 1.25, k, k * 1.25)
		kit.position = to_world(p2d)
		kit.rotation.y = _kit_rng.randf() * TAU
		return
	var q := QuadMesh.new()
	var tex: Texture2D = profile.pine_card
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
	var brick: StandardMaterial3D = _std_material(profile.ruin_bricks, 0.035).duplicate()
	brick.albedo_color = profile.ruin_tint
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
			var rot := Vector3(0, _rng.randf_range(-10, 10), _rng.randf_range(-3, 3))
			if profile.kit_columns.is_empty():
				_box(Vector3(30, h, 30), to_world(at, h * 0.5), brick, rot)
			else:
				var col: MeshInstance3D = _kit_instance(_kit_pick(profile.kit_columns), profile.ruin_bricks, profile.ruin_tint)
				col.name = "Column"
				var size: Vector3 = col.mesh.get_aabb().size
				col.scale = Vector3(30.0 / size.x, h / size.y, 30.0 / size.z)
				col.position = to_world(at)
				col.rotation_degrees = rot
			_box(Vector3(42, 8, 42), to_world(at, 4.0), brick)
		for i in 4:
			var at: Vector2 = centre + Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2)) * _cell
			if _lane.has(Vector2i(floori(at.x / _cell), floori(at.y / _cell))):
				continue
			var rot := Vector3(_rng.randf_range(-15, 15), _rng.randf() * 90.0, _rng.randf_range(-15, 15))
			if profile.kit_rubble.is_empty():
				_box(Vector3(20, 12, 16), to_world(at, 5.0), brick, rot)
			else:
				var tex: Texture2D = profile.kit_rubble_texture if profile.kit_rubble_texture != null else profile.ruin_bricks
				var block: MeshInstance3D = _kit_instance(_kit_pick(profile.kit_rubble), tex, profile.ruin_tint)
				block.name = "Rubble"
				block.scale = Vector3.ONE * 20.0 / block.mesh.get_aabb().size.x
				block.position = to_world(at, -2.0)
				block.rotation_degrees = rot


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
		var r: float = _rng.randf_range(10.0, 22.0)
		var height_mul: float = _rng.randf_range(1.1, 1.5)
		var rot := Vector3(_rng.randf_range(-12, 12), _rng.randf() * 360.0, _rng.randf_range(-12, 12))
		var stretch := Vector3(_rng.randf_range(1.0, 1.5), 1.0, _rng.randf_range(0.9, 1.3))
		placed += 1
		if not profile.kit_rocks.is_empty():
			var kit: MeshInstance3D = _kit_instance(_kit_pick(profile.kit_rocks), _kit_rock_texture(), profile.kit_rock_tint)
			kit.name = "Rock"
			var size: Vector3 = kit.mesh.get_aabb().size
			# Footprint ~2.4 r wide; Kenney's flat boulders get the sphere's
			# height multiplier so taller variety survives.
			var k: float = r * 2.4 / maxf(size.x, size.z)
			kit.scale = Vector3(k * stretch.x, k * height_mul, k * stretch.z)
			kit.position = to_world(p)
			kit.rotation_degrees = rot
			continue
		var sphere := SphereMesh.new()
		sphere.radius = r
		sphere.height = r * height_mul
		sphere.radial_segments = 6
		sphere.rings = 3
		var mi := MeshInstance3D.new()
		mi.name = "Rock"
		mi.mesh = sphere
		mi.material_override = mat
		_own(mi)
		mi.position = to_world(p, r * 0.25)
		mi.rotation_degrees = rot
		mi.scale = stretch


# --- Mission-specific dressing ---------------------------------------------

## Distance from `p` to the nearest lane cell's rectangle (0 inside one).
func _lane_distance(p: Vector2) -> float:
	var c := Vector2i(floori(p.x / _cell), floori(p.y / _cell))
	var best: float = INF
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if not _lane.has(n):
				continue
			var r := Rect2(Vector2(n) * _cell, Vector2(_cell, _cell))
			var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
			best = minf(best, p.distance_to(q))
	return best


## Reeds / dry tufts hugging the lane banks (Narrows river, Foothills road).
func _build_lane_edges() -> void:
	if profile.lane_edge_cards.is_empty() or profile.lane_edge_per_cell <= 0.0:
		return
	var cards: Array[Texture2D] = profile.lane_edge_cards
	var per_card: Array = []
	for i in cards.size():
		per_card.append({"x": [] as Array[Transform3D], "c": [] as Array[Color]})
	var tries: int = int(_lane.size() * profile.lane_edge_per_cell * 3.0)
	for i in tries:
		var lane_cells: Array = _lane.keys()
		var lc: Vector2i = lane_cells[_rng.randi() % lane_cells.size()]
		var p: Vector2 = _cell_center(lc) + Vector2(_rng.randf_range(-0.85, 0.85), _rng.randf_range(-0.85, 0.85)) * _cell
		var d: float = _lane_distance(p)
		if d < 2.0 or d > _cell * 0.32:
			continue
		var on_landmark := false
		for lm: Vector2i in _landmarks:
			if p.distance_to(_cell_center(lm)) < _cell * (profile.landmark_radius_cells + 0.1):
				on_landmark = true
		if on_landmark:
			continue
		var k: int = _rng.randi() % cards.size()
		var s: float = _rng.randf_range(0.8, 1.25)
		per_card[k]["x"].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), to_world(p)))
		var v: float = _rng.randf_range(0.75, 1.0)
		per_card[k]["c"].append(Color(v, v, v))
	for k in cards.size():
		var tex: Texture2D = cards[k]
		var h: float = profile.lane_edge_height_px
		var w: float = h * float(tex.get_width()) / float(tex.get_height())
		_scatter("LaneEdge%d" % k, cross_card_mesh(w, h), _card_material(tex, profile.grass_sway_px), per_card[k]["x"], per_card[k]["c"])


## True when an upright prop `height` tall at `p` would not cover any lane or
## landmark cell on screen. The camera foreshortens height by cos(pitch) and
## draws it straight up the screen, i.e. toward smaller 2D y.
func _clear_above(p: Vector2, height: float, half_width: float) -> bool:
	var screen_h: float = height * cos(deg_to_rad(profile.camera_pitch_deg))
	var y: float = p.y
	while y >= p.y - screen_h:
		for x: float in [p.x - half_width, p.x, p.x + half_width]:
			var c := Vector2i(floori(x / _cell), floori(y / _cell))
			if _lane.has(c) or _landmarks.has(c):
				return false
		y -= _cell * 0.25
	return true


## A spot on the blocked border or just off the map (never the field);
## Vector2(INF, INF) when none is found.
func _border_spot(margin_px: float) -> Vector2:
	# Mission maps fill the screen exactly, so off-map dressing is mostly out
	# of view: try the in-grid blocked cells first, then the margin.
	for attempt in 20:
		if _blocked.is_empty():
			break
		var c0: Vector2i = _blocked[_rng.randi() % _blocked.size()]
		var q: Vector2 = _cell_center(c0) + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-20, 20))
		if _is_open_ground(q):
			return q
	for attempt in 40:
		var p: Vector2 = _random_point(margin_px)
		var c := Vector2i(floori(p.x / _cell), floori(p.y / _cell))
		if _in_grid(p) and not _blocked.has(c):
			continue
		if _is_open_ground(p):
			return p
	return Vector2(INF, INF)


## Tall eroded rock spires (Narrows canyon walls, Foothills crags).
func _build_spires() -> void:
	if profile.spire_count <= 0 or profile.rock == null:
		return
	var mat: StandardMaterial3D = _std_material(profile.rock, 0.05)
	for i in profile.spire_count:
		var p: Vector2 = _border_spot(_cell * 1.5)
		if p.x == INF:
			continue
		var h: float = _rng.randf_range(profile.spire_height_px.x, profile.spire_height_px.y)
		var r: float = _rng.randf_range(16.0, 28.0)
		if not _clear_above(p, h, r):
			continue
		var taper: float = _rng.randf_range(0.45, 0.75)
		var rot := Vector3(_rng.randf_range(-5, 5), _rng.randf() * 360.0, _rng.randf_range(-5, 5))
		var shelf_yaw: float = _rng.randf() * 90.0
		if not profile.kit_spires.is_empty():
			# Kenney's tall rocks carry their own grassy foot, so no shelf.
			var kit: MeshInstance3D = _kit_instance(_kit_pick(profile.kit_spires), _kit_rock_texture(), profile.kit_rock_tint)
			kit.name = "Spire"
			var size: Vector3 = kit.mesh.get_aabb().size
			var w: float = r * 2.6 / maxf(size.x, size.z)
			kit.scale = Vector3(w, h / size.y, w)
			kit.position = to_world(p)
			kit.rotation_degrees = rot
			continue
		var cyl := CylinderMesh.new()
		cyl.bottom_radius = r
		cyl.top_radius = r * taper
		cyl.height = h
		cyl.radial_segments = 6
		cyl.rings = 2
		var mi := MeshInstance3D.new()
		mi.name = "Spire"
		mi.mesh = cyl
		mi.material_override = mat
		_own(mi)
		mi.position = to_world(p, h * 0.5)
		mi.rotation_degrees = rot
		# Rubble shelf at the foot so a spire never stands on a hard edge.
		_box(Vector3(r * 1.6, 8, r * 1.4), to_world(p, 4.0), mat, Vector3(0, shelf_yaw, 0))


## Glowing crystal clusters (The Hollow): emissive prisms plus one small light
## per cluster, so the dark floor around them picks up their colour.
func _build_crystals() -> void:
	if profile.crystal_clusters <= 0:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = profile.crystal_color
	mat.emission_enabled = true
	mat.emission = profile.crystal_color
	mat.emission_energy_multiplier = 1.6
	mat.roughness = 0.25
	for i in profile.crystal_clusters:
		var centre: Vector2 = _border_spot(_cell)
		if centre.x == INF:
			continue
		for j in _rng.randi_range(3, 6):
			var p: Vector2 = centre + Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-12, 12))
			var prism := CylinderMesh.new()
			prism.bottom_radius = _rng.randf_range(4.0, 8.0)
			prism.top_radius = 0.0
			prism.height = _rng.randf_range(18.0, 46.0)
			prism.radial_segments = 5
			prism.rings = 1
			var mi := MeshInstance3D.new()
			mi.name = "Crystal"
			mi.mesh = prism
			mi.material_override = mat
			_own(mi)
			mi.position = to_world(p, prism.height * 0.4)
			mi.rotation_degrees = Vector3(_rng.randf_range(-22, 22), _rng.randf() * 360.0, _rng.randf_range(-22, 22))
		var glow := OmniLight3D.new()
		glow.name = "CrystalGlow"
		glow.light_color = profile.crystal_color
		glow.light_energy = 1.4
		glow.omni_range = 110.0
		glow.light_cull_mask = RENDER_LAYER
		glow.layers = RENDER_LAYER  # see the sun's comment: lights are camera-culled by layers
		add_child(glow)
		glow.position = to_world(centre, 30.0)


## Stumps, logs and mushrooms on the blocked border / off-map (the
## reference's fallen trunk and forest-floor clutter). Built last; the kit
## stream picks the model, size and yaw.
func _build_debris() -> void:
	if profile.debris_count <= 0 or profile.kit_debris.is_empty():
		return
	for i in profile.debris_count:
		# Only draw the coin when a share is set, so share-0 profiles keep
		# their existing debris picks.
		var in_field: bool = profile.debris_field_share > 0.0 and _kit_rng.randf() < profile.debris_field_share
		var p: Vector2 = _field_spot() if in_field else _border_spot(_cell * 0.5)
		if p.x == INF:
			continue
		var scene: PackedScene = _kit_pick(profile.kit_debris)
		var size: Vector3 = _kit_mesh(scene).get_aabb().size
		# Kenney props are ~1 unit per tile; 70 px/unit keeps a stump under
		# half a cell and a big log just over one.
		var k: float = 70.0 * _kit_rng.randf_range(0.85, 1.15)
		var yaw: float = _kit_rng.randf() * TAU
		if not _clear_above(p, size.y * k, maxf(size.x, size.z) * k * 0.5):
			continue
		var kit: MeshInstance3D = _kit_instance(scene, null)
		kit.name = "Debris"
		kit.scale = Vector3.ONE * k
		kit.position = to_world(p)
		kit.rotation.y = yaw


## An open in-grid spot at least half a cell from any lane (roads, and the
## town's building pads) and landmark; Vector2(INF, INF) when none is found.
## Draws from the kit stream only.
func _field_spot() -> Vector2:
	for attempt in 30:
		var p := Vector2(_kit_rng.randf_range(0.0, _cols * _cell), _kit_rng.randf_range(0.0, _rows * _cell))
		var c := Vector2i(floori(p.x / _cell), floori(p.y / _cell))
		if _blocked.has(c) or not _is_open_ground(p):
			continue
		if _lane_distance(p) < _cell * 0.5:
			continue
		var hidden := false
		for r: Rect2 in keep_out:
			if r.has_point(p):
				hidden = true
				break
		if hidden:
			continue
		return p
	return Vector2(INF, INF)


# --- Kenney kit meshes -----------------------------------------------------

func _kit_pick(scenes: Array[PackedScene]) -> PackedScene:
	return scenes[_kit_rng.randi() % scenes.size()]


func _kit_rock_texture() -> Texture2D:
	return profile.kit_rock_texture if profile.kit_rock_texture != null else profile.rock


## The first mesh in a kit scene (Kenney .glb: a root plus one mesh node,
## modelled base-at-origin). Cached per scene.
func _kit_mesh(scene: PackedScene) -> Mesh:
	var key: String = scene.resource_path
	if _kit_mesh_cache.has(key):
		return _kit_mesh_cache[key]
	var root: Node = scene.instantiate()
	var mesh: Mesh = null
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		mesh = (n as MeshInstance3D).mesh
		break
	root.free()
	_kit_mesh_cache[key] = mesh
	return mesh


## A scenery-owned MeshInstance3D of a kit scene with every surface reskinned
## by its Kenney material name (_kit_surface_material()). `stone` is the
## texture for rock/stone surfaces; null leaves those flat-coloured.
func _kit_instance(scene: PackedScene, stone: Texture2D, stone_tint: Color = Color.WHITE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _kit_mesh(scene)
	for i in mi.mesh.get_surface_count():
		mi.set_surface_override_material(i, _kit_surface_material(mi.mesh.surface_get_material(i), stone, stone_tint))
	_own(mi)
	return mi


## Maps a Kenney Nature Kit material onto the project's pixel textures so the
## kit shares the HD-2D look (Kenney ships flat, untextured colours):
##   leafs*      -> kit_foliage (tinted by foliage_tint)
##   woodInner   -> wood          wood*/bark -> bark
##   grass       -> ground_grass  (the mossy caps on Kenney rocks)
##   dirt/stone*/rock, _defaultMat with a stone texture -> `stone`
##   anything else (mushroom caps and stems) -> its own colour, toned down.
## Textures are world-space triplanar, so a stretched mesh never stretches
## its pixels. The key includes the texel scale via the texture path only, as
## ground_texel_px is fixed per profile and the cache is cleared per build().
func _kit_surface_material(src: Material, stone: Texture2D, stone_tint: Color) -> Material:
	var src_name: String = src.resource_name.to_lower() if src != null else ""
	var tex: Texture2D = null
	var shade := Color.WHITE
	if src_name.begins_with("leaf"):
		tex = profile.kit_foliage
		shade = profile.foliage_tint
	elif src_name == "woodinner":
		tex = profile.wood
	elif src_name.begins_with("wood") or src_name.contains("bark"):
		tex = profile.bark
	elif src_name == "grass":
		tex = profile.ground_grass
		shade = profile.grass_tint
	elif stone != null and (src_name == "dirt" or src_name.begins_with("stone") or src_name.begins_with("rock") or src_name == "_defaultmat"):
		tex = stone
		shade = stone_tint
		if src_name == "stonedark":
			shade = shade.darkened(0.22)
		elif src_name == "_defaultmat":
			shade = shade.lightened(0.08)
	var key := "kit|%s|%s" % [tex.resource_path if tex != null else src_name, shade.to_html()]
	if _material_cache.has(key):
		return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	if tex != null:
		m.albedo_texture = tex
		m.albedo_color = shade
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		# One texture repeat per (width x ground_texel_px) world px: prop
		# pixels come out the same size as the ground's.
		m.uv1_scale = Vector3.ONE / (float(tex.get_width()) * profile.ground_texel_px)
	else:
		var base: Color = (src as BaseMaterial3D).albedo_color if src is BaseMaterial3D else Color(0.8, 0.8, 0.8)
		m.albedo_color = base.darkened(0.18)
	_material_cache[key] = m
	return m


func _own(node: VisualInstance3D) -> void:
	node.layers = RENDER_LAYER
	add_child(node)
