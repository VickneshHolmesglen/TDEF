## Unit tests for TowerModel3D: assembly of 3D tower pieces on Seat markers,
## tier detail groups, render layer and idle crown motion (ADR-0043,
## docs/superpowers/specs/2026-11-07-3d-towers-design.md §5.1-5.3, §5.8).
## Uses the real octagon/siege pieces in assets/art/towers3d/.
extends GdUnitTestSuite

var _model: TowerModel3D


func before_test() -> void:
	_model = TowerModel3D.new()
	add_child(_model)


func after_test() -> void:
	remove_child(_model)
	_model.free()


func _named(node: Node, name: String) -> Array[Node]:
	var out: Array[Node] = []
	for n: Node in node.find_children(name, "", true, false):
		out.append(n)
	return out


func test_tower_model_has_models_true_for_octagon_siege() -> void:
	assert_bool(TowerModel3D.has_models(&"octagon", &"siege")).is_true()


func test_tower_model_has_models_false_for_unmodelled_family() -> void:
	assert_bool(TowerModel3D.has_models(&"triangle", &"top_triangle")).is_false()


func test_tower_model_has_models_true_for_family_top_crown() -> void:
	assert_bool(TowerModel3D.has_models(&"octagon", &"top_octagon")).is_true()


func test_tower_model_build_stacks_crown_on_shaft_seat() -> void:
	_model.build(&"octagon", &"siege", 1, 1.0, 7)
	var seats: Array[Node] = _named(_model, "Seat")
	assert_int(seats.size()).is_equal(2)
	var top_seat_y: float = maxf((seats[0] as Node3D).global_position.y, (seats[1] as Node3D).global_position.y)
	var crown: Node3D = _named(_model, "Crown")[0] as Node3D
	assert_float(crown.global_position.y).is_equal_approx(top_seat_y, 0.001)


func test_tower_model_set_tier_shows_groups_up_to_tier() -> void:
	_model.build(&"octagon", &"siege", 3, 1.0, 7)
	for t: int in [2, 3, 4]:
		var groups: Array[Node] = _named(_model, "Tier%d" % t)
		assert_int(groups.size()).is_equal(3)  # base, shaft, crown
		for g: Node in groups:
			assert_bool((g as Node3D).visible).is_equal(t <= 3)


func test_tower_model_all_visual_instances_on_render_layer() -> void:
	_model.build(&"octagon", &"siege", 4, 1.0, 7)
	var visuals: Array[Node] = _model.find_children("*", "VisualInstance3D", true, false)
	assert_int(visuals.size()).is_greater(0)
	for v: Node in visuals:
		assert_int((v as VisualInstance3D).layers).is_equal(Hd2dScenery.RENDER_LAYER)


func test_tower_model_process_turns_crown_while_idle() -> void:
	_model.build(&"octagon", &"siege", 1, 1.0, 7)
	var crown: Node3D = _named(_model, "Crown")[0] as Node3D
	var before: float = crown.rotation.y
	_model._process(1.0)
	assert_float(absf(wrapf(crown.rotation.y - before, -PI, PI))).is_greater(0.5)


func test_tower_model_different_seeds_start_at_different_yaws() -> void:
	_model.build(&"octagon", &"siege", 1, 1.0, 7)
	var other := TowerModel3D.new()
	add_child(other)
	other.build(&"octagon", &"siege", 1, 1.0, 8)
	var a: float = (_named(_model, "Crown")[0] as Node3D).rotation.y
	var b: float = (_named(other, "Crown")[0] as Node3D).rotation.y
	remove_child(other)
	other.free()
	assert_float(absf(a - b)).is_greater(0.01)


func test_tower_model_aim_at_turns_crown_toward_target() -> void:
	_model.build(&"octagon", &"siege", 1, 1.0, 7)
	_model.aim_at(Vector2(1, 0), 5.0)
	for i: int in 20:
		_model._process(0.1)
	var crown: Node3D = _named(_model, "Crown")[0] as Node3D
	assert_float(wrapf(crown.rotation.y, -PI, PI)).is_equal_approx(PI / 2, 0.001)
