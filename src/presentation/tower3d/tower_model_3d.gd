class_name TowerModel3D
extends Node3D

## One assembled 3D tower (ADR-0043, spec 2026-11-07-3d-towers-design §5.1-5.3,
## §5.6, §5.8). Lives under Hd2dScenery; TowerInstance owns and positions it.
##
## Pieces are .gltf files from tools/asset-pipeline/blender/tower_kit.py:
## base -> shaft on the base's `Seat` -> crown on the shaft's `Seat`. Only the
## crown's `Crown` pivot turns. `Tier2`..`Tier4` groups add detail up to the
## tower's Foundation tier. All units here are kit units (1 = about one cell
## across); the node is scaled by PX_PER_UNIT into Hd2dScenery's pixel world.

const PIECE_DIR: String = "res://assets/art/towers3d/"
const PIECE_EXT: String = ".gltf"
## Kit units -> 2D gameplay pixels (pilot looked right between 38 and 45).
const PX_PER_UNIT: float = 40.0
## Idle sweep speed variation per tower, so neighbours never turn in step.
const IDLE_SPEED_VARIATION: float = 0.2
const PUNCH_SCALE: float = 1.12
const PUNCH_DURATION: float = 0.15
const HIT_FLASH_DURATION: float = 0.18
const REMOVE_DURATION: float = 0.4
const RANK_POP_DURATION: float = 0.3
## Pennant pole stands on the base's top ring, left of the shaft: the right
## side is where TowerInstance draws the 2D perk badge.
const RANK_1_SIDE_OFFSET: float = -0.47

var _crown: Node3D = null
var _spin: Node3D = null
var _motion: TowerCrownMotion = null
var _aim: TowerAim = null
var _flash_overlay: StandardMaterial3D = null
var _punch_tween: Tween = null
var _flash_tween: Tween = null
## Anchor points (kit units, this node's space) found at build time.
var _base_seat: Vector3 = Vector3.ZERO
var _shaft_front: Vector3 = Vector3.ZERO
var _crown_foot: Vector3 = Vector3.ZERO


## True when the base, shaft and crown files for this combination exist.
## crown_key is a weapon key (&"siege") or a family top (&"top_octagon").
static func has_models(shape: StringName, crown_key: StringName) -> bool:
	for path: String in [_base_path(shape), _shaft_path(shape), _crown_path(crown_key)]:
		if not ResourceLoader.exists(path):
			return false
	return true


static func _base_path(shape: StringName) -> String:
	return PIECE_DIR + "base_" + String(shape) + PIECE_EXT


static func _shaft_path(shape: StringName) -> String:
	return PIECE_DIR + "shaft_" + String(shape) + PIECE_EXT


static func _crown_path(crown_key: StringName) -> String:
	var key: String = String(crown_key)
	return PIECE_DIR + (key if key.begins_with("top_") else "weapon_" + key) + PIECE_EXT


## Builds the tower. z_stretch: Hd2dScenery's ground depth stretch, so aim
## directions match what the player sees. rng_seed: per-tower seed for the
## start yaw and idle speed variation.
func build(shape: StringName, crown_key: StringName, tier: int, z_stretch: float, rng_seed: int) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	scale = Vector3.ONE * PX_PER_UNIT
	var base: Node3D = _add_piece(_base_path(shape), Vector3.ZERO)
	var shaft: Node3D = _add_piece(_shaft_path(shape), _seat_offset(base))
	var crown_root: Node3D = _add_piece(_crown_path(crown_key), shaft.position + _seat_offset(shaft))
	_base_seat = _seat_offset(base)
	_crown_foot = crown_root.position
	var shaft_box: AABB = _local_aabb(shaft)
	_shaft_front = Vector3(0.0, shaft_box.get_center().y, shaft_box.end.z)
	_crown = crown_root.find_child("Crown", true, false) as Node3D
	if _crown == null:
		_crown = crown_root
	_motion = TowerCrownMotion.for_crown(crown_key)
	_spin = _crown.find_child(String(_motion.spin_node), true, false) as Node3D if _motion.spin_node != &"" else null
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var idle_speed: float = _motion.idle_speed_deg * (1.0 + rng.randf_range(-IDLE_SPEED_VARIATION, IDLE_SPEED_VARIATION))
	if _motion.idle_mode == TowerCrownMotion.IdleMode.NONE:
		idle_speed = 0.0
	_aim = TowerAim.new(rng.randf_range(-PI, PI), idle_speed, _motion.track_speed_deg, _motion.aims)
	_aim.z_stretch = z_stretch
	_apply_layers(self)
	set_tier(tier)
	_apply_yaw(0.0)


func _add_piece(path: String, offset: Vector3) -> Node3D:
	var scene: PackedScene = load(path) as PackedScene
	var piece: Node3D = scene.instantiate() as Node3D
	add_child(piece)
	piece.position = offset
	return piece


func _seat_offset(piece: Node3D) -> Vector3:
	var seat: Node3D = piece.find_child("Seat", true, false) as Node3D
	return seat.position if seat != null else Vector3.ZERO


func _apply_layers(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = Hd2dScenery.RENDER_LAYER
	for child: Node in node.get_children():
		_apply_layers(child)


## Shows every TierN detail group with N <= tier.
func set_tier(tier: int) -> void:
	for t: int in [2, 3, 4]:
		for group: Node in find_children("Tier%d" % t, "", true, false):
			(group as Node3D).visible = t <= tier


## Turns toward a 2D gameplay direction; tracking lapses after hold_seconds.
func aim_at(direction_2d: Vector2, hold_seconds: float) -> void:
	if _aim != null:
		_aim.set_target(direction_2d, hold_seconds)


## Drops the target; the crown resumes its idle sweep from where it points.
func clear_aim() -> void:
	if _aim != null:
		_aim.clear_target()


func is_tracking() -> bool:
	return _aim != null and _aim.is_tracking()


func _process(delta: float) -> void:
	if _aim == null:
		return
	_apply_yaw(delta)


func _apply_yaw(delta: float) -> void:
	var tracking: bool = _aim.is_tracking()
	var yaw: float = _aim.step(delta)
	if _spin != null and not tracking:
		# SPIN crowns turn only their spinning part while idle.
		_spin.rotation.y = yaw
	else:
		_crown.rotation.y = yaw


## Short scale pulse on the crown when the tower fires.
func play_punch() -> void:
	if _crown == null:
		return
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	_crown.scale = Vector3.ONE
	_punch_tween = create_tween()
	_punch_tween.tween_property(_crown, "scale", Vector3.ONE * PUNCH_SCALE, PUNCH_DURATION * 0.4)
	_punch_tween.tween_property(_crown, "scale", Vector3.ONE, PUNCH_DURATION * 0.6)


## Brief white flash over the whole tower when it takes damage.
func play_hit_flash() -> void:
	if _flash_overlay == null:
		_flash_overlay = StandardMaterial3D.new()
		_flash_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for mesh: Node in find_children("*", "GeometryInstance3D", true, false):
			(mesh as GeometryInstance3D).material_overlay = _flash_overlay
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_overlay.albedo_color = Color(1, 1, 1, 0.8)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_overlay, "albedo_color:a", 0.0, HIT_FLASH_DURATION)


## Sinks and shrinks the tower, then calls on_done (the owner frees itself).
func play_remove(on_done: Callable) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * PX_PER_UNIT * 0.05, REMOVE_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y - PX_PER_UNIT * 0.3, REMOVE_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(on_done)


## Veterancy flourishes (spec §5.8): Rank1 pennant, Rank2 crest, Rank3
## laurel, shown for every N <= rank. animate pops the newly shown ones.
func set_rank(rank: int, animate: bool) -> void:
	for r: int in [1, 2, 3]:
		var node: Node3D = get_node_or_null("Rank%d" % r) as Node3D
		if r > rank:
			if node != null:
				node.visible = false
			continue
		var newly_shown: bool = node == null or not node.visible
		if node == null:
			node = _add_flourish(r)
		node.visible = true
		if animate and newly_shown:
			node.scale = Vector3.ONE * 0.01
			var tween: Tween = node.create_tween()
			tween.tween_property(node, "scale", Vector3.ONE * 1.15, RANK_POP_DURATION * 0.6) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(node, "scale", Vector3.ONE, RANK_POP_DURATION * 0.4)


func _add_flourish(rank: int) -> Node3D:
	var node: Node3D = _add_piece(PIECE_DIR + "rank_%d" % rank + PIECE_EXT, Vector3.ZERO)
	node.name = "Rank%d" % rank
	match rank:
		1:
			node.position = _base_seat + Vector3(RANK_1_SIDE_OFFSET, 0.0, 0.0)
			node.rotation.y = PI  # flag flies outward (authored pointing +X)
		2:
			node.position = _shaft_front
		3:
			node.position = _crown_foot
	_apply_layers(node)
	return node


## AABB of every visual under `node`, in this node's local space.
func _local_aabb(node: Node) -> AABB:
	var box := AABB()
	var first: bool = true
	var inv: Transform3D = global_transform.affine_inverse()
	for child: Node in node.find_children("*", "VisualInstance3D", true, false):
		var vis := child as VisualInstance3D
		var local: AABB = (inv * vis.global_transform) * vis.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box


## On-screen height in 2D pixels under an orthographic camera at pitch_deg.
func screen_height_px(pitch_deg: float) -> float:
	var box: AABB = _local_aabb(self)
	var pitch: float = deg_to_rad(pitch_deg)
	return (box.size.y * cos(pitch) + box.size.z * sin(pitch)) * PX_PER_UNIT
