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


func test_tower_model_has_models_false_for_unmodelled_crown() -> void:
	assert_bool(TowerModel3D.has_models(&"triangle", &"no_such_crown")).is_false()


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


# --- veterancy flourishes (spec §5.8) --------------------------------------

func _visible_ranks(model: TowerModel3D) -> Array[int]:
	var out: Array[int] = []
	for r: int in [1, 2, 3]:
		var node: Node3D = model.get_node_or_null("Rank%d" % r) as Node3D
		if node != null and node.visible:
			out.append(r)
	return out


func test_tower_model_set_rank_shows_flourishes_up_to_rank() -> void:
	_model.build(&"octagon", &"siege", 1, 1.0, 7)
	_model.set_rank(2, false)
	assert_array(_visible_ranks(_model)).contains_exactly([1, 2])


func test_tower_model_set_rank_lowering_hides_extra_flourishes() -> void:
	_model.build(&"octagon", &"siege", 1, 1.0, 7)
	_model.set_rank(3, false)
	_model.set_rank(0, false)
	assert_array(_visible_ranks(_model)).is_empty()


func test_tower_model_set_rank_twice_does_not_duplicate() -> void:
	_model.build(&"octagon", &"siege", 1, 1.0, 7)
	_model.set_rank(2, false)
	_model.set_rank(2, true)
	var count: int = 0
	for child: Node in _model.get_children():
		if String(child.name).begins_with("Rank2"):
			count += 1
	assert_int(count).is_equal(1)


func test_tower_model_flourishes_on_render_layer() -> void:
	_model.build(&"octagon", &"siege", 1, 1.0, 7)
	_model.set_rank(3, false)
	for v: Node in _model.get_node("Rank3").find_children("*", "VisualInstance3D", true, false):
		assert_int((v as VisualInstance3D).layers).is_equal(Hd2dScenery.RENDER_LAYER)


## Review finding (2026-11-07): the hit-flash overlay stayed on every mesh
## after the first hit (an extra transparent pass per mesh for the rest of
## the mission).
func test_tower_model_hit_flash_overlay_removed_after_flash() -> void:
	_model.build(&"octagon", &"siege", 1, 1.0, 7)
	_model.play_hit_flash()
	await get_tree().create_timer(TowerModel3D.HIT_FLASH_DURATION + 0.15).timeout
	for mesh: Node in _model.find_children("*", "GeometryInstance3D", true, false):
		assert_object((mesh as GeometryInstance3D).material_overlay).is_null()


# --- Painted-vector style (ADR-0045) -------------------------------------------

func _surface_materials() -> Array[Material]:
	var out: Array[Material] = []
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			out.append(mi.get_active_material(i))
	return out


func test_painted_style_repaints_every_surface_keeping_textures() -> void:
	_model.build(&"octagon", &"siege", 1, 1.0, 7)
	_model.set_painted_style(true)
	_model.set_rank(3, false)  # flourishes added after the switch are painted too
	var mats: Array[Material] = _surface_materials()
	assert_int(mats.size()).is_greater(0)
	for m: Material in mats:
		assert_object(m).is_instanceof(ShaderMaterial)
		assert_object((m as ShaderMaterial).shader).is_same(TowerModel3D.PAINTED_TOWER_SHADER)


func test_unpainted_model_keeps_imported_materials() -> void:
	_model.build(&"octagon", &"siege", 1, 1.0, 7)
	for m: Material in _surface_materials():
		assert_bool(m is ShaderMaterial and (m as ShaderMaterial).shader == TowerModel3D.PAINTED_TOWER_SHADER).is_false()


func test_painted_style_keeps_glow() -> void:
	_model.build(&"octagon", &"siege", 1, 1.0, 7)
	var src := StandardMaterial3D.new()
	src.emission_enabled = true
	src.emission = Color(1, 0.5, 0)
	src.emission_energy_multiplier = 2.0
	var m: ShaderMaterial = TowerModel3D._painted_for(src)
	assert_float(m.get_shader_parameter(&"emission_energy")).is_equal(2.0)
	assert_object(m.get_shader_parameter(&"emission_color")).is_equal(Color(1, 0.5, 0))
