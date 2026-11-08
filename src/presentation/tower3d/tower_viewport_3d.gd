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
## Frame height as a multiple of the tower's on-screen height (margin).
const FRAME_MARGIN: float = 1.25
const CAMERA_DISTANCE: float = 1000.0

## Parent of the model; turn it to spin the tower (the Inventory turntable).
var turntable: Node3D
var camera: Camera3D
## The tower shown, or null.
var model: TowerModel3D = null


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
	var pitch: float = deg_to_rad(PITCH_DEG)
	camera.size = model.screen_height_px(PITCH_DEG) * FRAME_MARGIN
	camera.position = Vector3(0.0, model.world_height() * 0.5, 0.0) \
			+ Vector3(0.0, sin(pitch), cos(pitch)) * CAMERA_DISTANCE
	return model


## Removes the shown tower.
func clear() -> void:
	if model != null:
		turntable.remove_child(model)
		model.queue_free()
		model = null


## Distance (2D pixels at 1:1 map scale) from the picture's centre down to the
## point under the tower's base, which is where the tower stands on the map.
## The camera looks at half the tower's height above the base, so the base
## sits that far below centre, foreshortened by the pitch.
func ground_offset_px() -> float:
	if model == null:
		return 0.0
	return model.world_height() * 0.5 * cos(deg_to_rad(PITCH_DEG))


## Picture height in 2D pixels at 1:1 map scale (the camera's frame height).
func frame_height_px() -> float:
	return camera.size
