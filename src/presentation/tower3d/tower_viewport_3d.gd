class_name TowerViewport3D
extends SubViewport

## Off-screen view of one TowerModel3D under the mission camera's pitch, lit
## like the scenery (ADR-0043). Its texture is the tower picture shown in UI:
## the Inventory's rotating preview and the Mission HUD's build tiles and
## placement ghost, so every screen shows the model a mission places.
##
## Example (a still icon, rendered once):
##     var view := TowerViewport3D.new()
##     add_child(view)
##     view.render_target_update_mode = SubViewport.UPDATE_ONCE
##     view.show_tower(&"octagon", &"octagon", &"arcane", 2, true)
##     button.icon = view.get_texture()

## The mission camera's default pitch (Hd2dSceneryProfile.camera_pitch_deg).
const PITCH_DEG: float = 50.0
const CAMERA_DISTANCE: float = 1000.0

## Parent of the model; turn it to spin the tower (the Inventory turntable).
var turntable: Node3D
var camera: Camera3D
## The tower shown, or null.
var model: TowerModel3D = null
## Frame size as a multiple of the tower's on-screen outline. Room to spare
## for a turntable (the Inventory); a still icon can sit tight.
var frame_margin: float = 1.25
## Where the point under the tower's base lands, relative to the picture's
## centre, in 2D pixels at 1:1 map scale (y down). Set by show_tower().
var _ground_offset: Vector2 = Vector2.ZERO


func _init() -> void:
	own_world_3d = true
	transparent_bg = true
	turntable = Node3D.new()
	turntable.name = "Turntable"
	add_child(turntable)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.55
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.cull_mask = Hd2dScenery.RENDER_LAYER
	camera.environment = env
	camera.rotation_degrees = Vector3(-PITCH_DEG, 0.0, 0.0)
	camera.far = CAMERA_DISTANCE * 4.0
	add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.layers = Hd2dScenery.RENDER_LAYER  # VERSION.md: a light off the camera's layers is ignored
	sun.light_cull_mask = Hd2dScenery.RENDER_LAYER
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	add_child(sun)


## Replaces the shown tower and frames the camera on it. painted: re-shade
## for the painted-vector scenery (ADR-0045), as missions do.
## Example: view.show_tower(&"round", &"round", &"top_round", 1, false)
func show_tower(base_shape: StringName, shaft_shape: StringName, crown_key: StringName, tier: int,
		painted: bool) -> TowerModel3D:
	clear()
	model = TowerModel3D.new()
	turntable.add_child(model)
	model.build_parts(base_shape, shaft_shape, crown_key, tier, 1.0, 1)
	model.set_painted_style(painted)
	_frame_on_model()
	return model


## Removes the shown tower.
func clear() -> void:
	if model != null:
		turntable.remove_child(model)
		model.queue_free()
		model = null


## Where the point under the tower's base sits relative to the picture's
## centre, in 2D pixels at 1:1 map scale (y down). The placement ghost
## shifts the picture by this so the tower stands where it will be placed.
func ground_offset_px() -> Vector2:
	return _ground_offset


## Fits the camera to the tower's projected outline (all 8 corners of its
## bounds seen from the camera), centred, so a still picture wastes no space.
func _frame_on_model() -> void:
	var pitch: float = deg_to_rad(PITCH_DEG)
	var up := Vector3(0.0, cos(pitch), -sin(pitch))  # camera up, tilted by the pitch
	var back := Vector3(0.0, sin(pitch), cos(pitch))  # toward the camera
	var box: AABB = model.bounds_px()
	var u_min: float = INF
	var u_max: float = -INF
	var r_min: float = INF
	var r_max: float = -INF
	for i: int in 8:
		var corner: Vector3 = box.get_endpoint(i)
		u_min = minf(u_min, corner.dot(up))
		u_max = maxf(u_max, corner.dot(up))
		r_min = minf(r_min, corner.x)
		r_max = maxf(r_max, corner.x)
	var u_mid: float = (u_min + u_max) * 0.5
	var r_mid: float = (r_min + r_max) * 0.5
	camera.size = maxf(u_max - u_min, r_max - r_min) * frame_margin
	camera.position = up * u_mid + Vector3(r_mid, 0.0, 0.0) + back * CAMERA_DISTANCE
	_ground_offset = Vector2(-r_mid, u_mid)


## Picture height in 2D pixels at 1:1 map scale (the camera's frame height).
func frame_height_px() -> float:
	return camera.size
