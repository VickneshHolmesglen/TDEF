## Integration tests for Picking3D.pick_tower() (ADR-0039): a real raycast
## against an Area3D on PICKING_LAYER_TOWER, resolving its "owner_tower"
## metadata. The no-metadata case guards the has_meta() check — get_meta()
## with a null default logs an engine error for a missing key (VERSION.md).
extends GdUnitTestSuite

var _world: Node3D
var _camera: Camera3D
var _area: Area3D


func before_test() -> void:
	_world = Node3D.new()
	add_child(_world)
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 10.0, 0.0)
	_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_world.add_child(_camera)
	_area = Area3D.new()
	_area.collision_layer = Picking3D.PICKING_LAYER_TOWER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.0, 2.0)
	shape.shape = box
	_area.add_child(shape)
	_world.add_child(_area)
	# The Area3D only enters the physics space's broadphase on a physics step.
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_test() -> void:
	if _world != null and is_instance_valid(_world):
		_world.queue_free()
	_world = null


func _pick() -> Node2D:
	var mouse_pos: Vector2 = _camera.unproject_position(Vector3.ZERO)
	return Picking3D.pick_tower(_camera, mouse_pos, _world.get_world_3d().direct_space_state)


func test_pick_tower_hit_with_owner_metadata_returns_the_tower() -> void:
	var tower: Node2D = auto_free(Node2D.new())
	_area.set_meta(&"owner_tower", tower)

	var picked: Node2D = _pick()

	assert_object(picked).is_same(tower)


func test_pick_tower_hit_without_owner_metadata_returns_null() -> void:
	var picked: Node2D = _pick()

	assert_object(picked).is_null()


func test_pick_tower_ignores_a_collider_on_another_layer() -> void:
	_area.collision_layer = Picking3D.PICKING_LAYER_GROUND
	_area.set_meta(&"owner_tower", auto_free(Node2D.new()))
	await get_tree().physics_frame

	var picked: Node2D = _pick()

	assert_object(picked).is_null()
