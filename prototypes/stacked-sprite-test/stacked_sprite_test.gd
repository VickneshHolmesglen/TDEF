# PROTOTYPE — NOT FOR PRODUCTION
# Question: Does stacked-sprite technique produce convincing pseudo-3D volume?
#           Does SubViewport 3D hero composite read as a unified diorama?
# Date: 2026-05-18

extends Node2D

# ── Art bible palette (Section 4) ────────────────────────────────────────────
const C_FIELDSTONE  := Color(0.494, 0.522, 0.565)   # #7E8590 — tower Far
const C_AMBER       := Color(0.784, 0.502, 0.102)   # #C8801A — tower Near
const C_GROUND      := Color(0.380, 0.420, 0.340)   # earthy neutral base
const C_SHADOW_FLAT := Color(0.0,   0.0,   0.0, 0.40)  # contact shadow
const C_SHADOW_CAST := Color(0.0,   0.0,   0.0, 0.25)  # inter-layer cast shadow

# ── Stack geometry ────────────────────────────────────────────────────────────
const SLICE_H   := 16   # px — height of each layer slice
const SLICE_GAP := 4    # px — gap between slices (creates depth reading)
const TOWER_W   := 48   # px — tower base width

var _world: Node2D
var _hero_viewport: SubViewport


func _ready() -> void:
	var ground := ColorRect.new()
	ground.name = "Ground"
	ground.color = C_GROUND
	ground.size = Vector2(640, 400)
	ground.position = Vector2(-320, -100)
	add_child(ground)

	# y_sort_enabled: children drawn in order of their world-Y (higher Y = in front)
	_world = Node2D.new()
	_world.name = "World"
	_world.y_sort_enabled = true
	add_child(_world)

	_add_tower(Vector2(-90, -40), C_FIELDSTONE, "TowerFar")
	_add_tower(Vector2(10,   50), C_AMBER,      "TowerNear")
	_setup_hero(Vector2(80, 20))

	var lbl := Label.new()
	lbl.name = "DebugLabel"
	lbl.text = "[Space] fan layers apart   [R] reset scene"
	lbl.position = Vector2(-300, -220)
	add_child(lbl)


# ── Tower stack ───────────────────────────────────────────────────────────────
# y_sort_enabled=false on root: layers use z_index order, not position order.
# The root itself is y-sorted relative to other world objects by _world.
#
# Layer z-order:
#   0  contact shadow (ground)
#   1  Layer 0 base
#   2  cast shadow 1 (L1 → L0)
#   3  Layer 1 mid
#   4  cast shadow 2 (L2 → L1)
#   5  Layer 2 top
func _add_tower(world_pos: Vector2, base_color: Color, tower_id: String) -> void:
	var root := Node2D.new()
	root.name = tower_id
	root.position = world_pos
	root.y_sort_enabled = false
	_world.add_child(root)

	# Contact shadow — flat ellipse anchored to the ground plane
	var contact := ColorRect.new()
	contact.color = C_SHADOW_FLAT
	contact.size = Vector2(TOWER_W, 10)
	contact.position = Vector2(-TOWER_W / 2.0, 2)
	contact.z_index = 0
	root.add_child(contact)

	# Layer 0 — base (widest, darkest)
	var l0 := ColorRect.new()
	l0.color = base_color
	l0.size = Vector2(TOWER_W, SLICE_H)
	l0.position = Vector2(-TOWER_W / 2.0, -SLICE_H)
	l0.z_index = 1
	root.add_child(l0)

	# Cast shadow 1
	var cs1 := ColorRect.new()
	cs1.color = C_SHADOW_CAST
	cs1.size = Vector2(TOWER_W - 4, SLICE_GAP + 2)
	cs1.position = Vector2(-TOWER_W / 2.0 + 2, -SLICE_H - SLICE_GAP)
	cs1.z_index = 2
	root.add_child(cs1)

	# Layer 1 — mid (slightly narrower + lighter)
	var l1 := ColorRect.new()
	l1.color = base_color.lightened(0.10)
	l1.size = Vector2(TOWER_W - 6, SLICE_H)
	l1.position = Vector2(-TOWER_W / 2.0 + 3, -SLICE_H * 2 - SLICE_GAP)
	l1.z_index = 3
	root.add_child(l1)

	# Cast shadow 2
	var cs2 := ColorRect.new()
	cs2.color = C_SHADOW_CAST
	cs2.size = Vector2(TOWER_W - 10, SLICE_GAP + 2)
	cs2.position = Vector2(-TOWER_W / 2.0 + 5, -SLICE_H * 2 - SLICE_GAP * 2)
	cs2.z_index = 4
	root.add_child(cs2)

	# Layer 2 — top (narrowest + lightest — taper implies height)
	var l2 := ColorRect.new()
	l2.color = base_color.lightened(0.22)
	l2.size = Vector2(TOWER_W - 12, SLICE_H - 4)
	l2.position = Vector2(-TOWER_W / 2.0 + 6, -SLICE_H * 3 - SLICE_GAP * 2)
	l2.z_index = 5
	root.add_child(l2)


# ── 3D hero composite ─────────────────────────────────────────────────────────
# SubViewport renders a 3D CapsuleMesh. ViewportTexture is assigned to a
# Sprite2D that participates in y_sort alongside the 2D tower stacks.
func _setup_hero(world_pos: Vector2) -> void:
	# SubViewport must be in the scene tree before get_texture() is valid.
	# Placed as a direct child of root (NOT inside _world) so it is not y-sorted.
	_hero_viewport = SubViewport.new()
	_hero_viewport.name = "HeroViewport"
	_hero_viewport.size = Vector2i(128, 256)
	_hero_viewport.transparent_bg = true
	_hero_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_hero_viewport)

	_build_hero_3d_scene(_hero_viewport)

	# The visual representation lives inside _world so it y-sorts with towers
	var hero_root := Node2D.new()
	hero_root.name = "HeroComposite"
	hero_root.position = world_pos
	hero_root.y_sort_enabled = false
	_world.add_child(hero_root)

	# Contact shadow (mandatory per Art Bible §3.4.4 — anchors hero to ground)
	var shadow := ColorRect.new()
	shadow.color = C_SHADOW_FLAT
	shadow.size = Vector2(34, 10)
	shadow.position = Vector2(-17, 2)
	shadow.z_index = 0
	hero_root.add_child(shadow)

	# Sprite2D displaying the live SubViewport texture
	var hero_sprite := Sprite2D.new()
	hero_sprite.name = "HeroSprite"
	hero_sprite.texture = _hero_viewport.get_texture()
	# SubViewport is 128×256; Sprite2D anchor is at center (64, 128).
	# Offset upward so the capsule base aligns with world_pos (ground level).
	# Tune this value if the hero appears to float or sink into the ground.
	hero_sprite.position = Vector2(0, -100)
	hero_sprite.z_index = 2
	hero_root.add_child(hero_sprite)


func _build_hero_3d_scene(viewport: SubViewport) -> void:
	# Directional light — top-left oblique to match Art Bible §2 lighting direction
	var light := DirectionalLight3D.new()
	light.name = "HeroLight"
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.light_energy = 1.2
	viewport.add_child(light)

	# Capsule placeholder — warm neutral so it reads against the grey/green ground
	var hero_mesh := MeshInstance3D.new()
	hero_mesh.name = "HeroPlaceholder"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	hero_mesh.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.80, 0.55, 0.25)
	mat.roughness = 0.75
	hero_mesh.material_override = mat
	hero_mesh.position = Vector3(0.0, 0.9, 0.0)   # base at Y=0, center at Y=0.9
	viewport.add_child(hero_mesh)

	# Orthographic camera — avoids the perspective distortion mismatch that
	# makes a 3D object look "pasted in" alongside flat 2D art.
	var camera := Camera3D.new()
	camera.name = "HeroCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.2   # world-units visible across viewport height; decrease to zoom in
	camera.position = Vector3(0.0, 2.5, 2.5)
	camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)
	viewport.add_child(camera)
	camera.make_current()


# ── Debug controls ────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_SPACE:
			_fan_tower_layers()
		KEY_R:
			get_tree().reload_current_scene()


# Fan stack layers apart so each slice is individually visible.
# Useful for verifying cast-shadow placement and z-index ordering.
# Press R to reset (reloads scene).
func _fan_tower_layers() -> void:
	for tower_name: String in ["TowerFar", "TowerNear"]:
		var tower: Node2D = _world.get_node_or_null(tower_name)
		if not tower:
			continue
		var layer_idx := 0
		for child: Node in tower.get_children():
			if child is ColorRect:
				child.position.y -= layer_idx * 22
				layer_idx += 1
