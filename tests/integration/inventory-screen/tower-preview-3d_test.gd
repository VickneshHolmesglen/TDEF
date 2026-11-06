## Integration tests for the Inventory's 3D tower gallery icons and rotating
## 3D assembly preview (ADR-0043, spec 2026-11-07-3d-towers-design §5.7).
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	GInventory.reset_to_defaults()
	_runner = scene_runner("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn")
	_screen = _runner.scene() as Control


func after_test() -> void:
	GInventory.reset_to_defaults()


func _pick(entry_name: String) -> void:
	(_screen.find_child(entry_name, true, false) as Button).button_pressed = true


func _models_in_preview() -> Array[Node]:
	var viewport: SubViewport = _screen.get("_preview_viewport") as SubViewport
	var out: Array[Node] = []
	for n: Node in viewport.find_children("*", "TowerModel3D", true, false):
		out.append(n)
	return out


func test_tower_preview_3d_octagon_picks_build_model_with_crown_on_shaft_seat() -> void:
	_pick("Base_octagon")
	_pick("Shaft_octagon")
	_pick("Top_octagon")
	var model: TowerModel3D = _screen.get("_preview_model") as TowerModel3D
	assert_object(model).is_not_null()
	var seats: Array[Node] = model.find_children("Seat", "", true, false)
	var top_seat_y: float = maxf((seats[0] as Node3D).global_position.y, (seats[1] as Node3D).global_position.y)
	var crown: Node3D = model.find_child("Crown", true, false) as Node3D
	assert_float(crown.global_position.y).is_equal_approx(top_seat_y, 0.01)


func test_tower_preview_3d_mixed_families_build_one_model() -> void:
	_pick("Base_square")
	_pick("Shaft_round")
	_pick("Top_stump")
	assert_int(_models_in_preview().size()).is_equal(1)


func test_tower_preview_3d_repicking_base_rebuilds_single_model() -> void:
	_pick("Base_octagon")
	_pick("Base_triangle")
	await _runner.simulate_frames(2)
	assert_int(_models_in_preview().size()).is_equal(1)


func test_tower_preview_3d_viewport_has_own_world() -> void:
	var viewport: SubViewport = _screen.get("_preview_viewport") as SubViewport
	assert_bool(viewport.own_world_3d).is_true()


func test_tower_preview_3d_gallery_uses_3d_icon() -> void:
	var entry: Button = _screen.find_child("Base_octagon", true, false) as Button
	var icon: TextureRect = entry.find_child("*", true, false) as TextureRect
	if icon == null:
		icon = entry.get_node("Center").get_child(0) as TextureRect
	assert_str(icon.texture.resource_path).is_equal("res://assets/art/towers3d/icons/base_octagon.png")


func test_tower_preview_3d_turntable_turns() -> void:
	var turntable: Node3D = _screen.get("_preview_turntable") as Node3D
	var before: float = turntable.rotation.y
	await _runner.simulate_frames(30, 16)
	assert_float(absf(turntable.rotation.y - before)).is_greater(0.05)
