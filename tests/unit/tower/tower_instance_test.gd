## Unit tests for TowerInstance -- presentation-only texture lookup by
## Foundation archetype, plus the 2026-08-03 scale fix (mirrors
## MonsterInstance's identical fix, found live via Godot MCP for that class
## and applied here proactively since TowerInstance has no live placement
## call-site yet to have caught it the same way).
extends GdUnitTestSuite

var _instance: TowerInstance


func before_test() -> void:
	var scene: PackedScene = load("res://src/core/tower/TowerInstance.tscn")
	_instance = scene.instantiate() as TowerInstance
	add_child(_instance)


func after_test() -> void:
	remove_child(_instance)
	_instance.free()


func test_configure_known_archetype_sets_sprite_texture() -> void:
	_instance.configure("physical")
	assert_object(_instance._sprite.texture).is_not_null()


func test_configure_unknown_archetype_leaves_sprite_texture_null() -> void:
	_instance.configure("totally_unknown_archetype")
	assert_object(_instance._sprite.texture).is_null()


func test_configure_scales_sprite_to_target_display_height() -> void:
	_instance.configure("physical")
	var texture := _instance._sprite.texture
	var scaled_height: float = float(texture.get_height()) * _instance._sprite.scale.y
	assert_float(scaled_height).is_between(63.9, 64.1)


func test_configure_with_component_ids_builds_three_layer_tower() -> void:
	_instance.configure("physical", "", "found_siege_t4", "weap_siege_t4")
	assert_bool(_instance._layer_root.visible).is_true()
	assert_bool(_instance._sprite.visible).is_false()
	assert_object(_instance._base_sprite.texture).is_equal(TowerInstance.SHAPE_BASE_TEXTURES[&"hexplank"])
	assert_object(_instance._shaft_sprite.texture).is_equal(TowerInstance.SHAPE_SHAFT_TEXTURES[&"hexplank"])
	assert_object(_instance._top_sprite.texture).is_equal(TowerInstance.WEAPON_TOP_TEXTURES[&"siege"])


func test_configure_component_shape_mapping_is_deterministic() -> void:
	var cases: Dictionary[String, StringName] = {
		"found_archer_t1": &"round",
		"found_bulwark_t2": &"square",
		"found_rally_t1": &"stump",
		"found_arcane_t3": &"octagon",
		"found_grandrally_t4": &"tiered",
		"found_frostbolt_t1": &"scalloped",
		"found_longshot_t1": &"triangle",
		"found_siege_t4": &"hexplank",
		"found_venomdart_t1": &"stonemound",
		"found_iron_t1": &"square",
		"found_reinforced_t2": &"square",
	}
	for component_id: String in cases:
		assert_object(_instance.resolve_shape_for_component(component_id, "elemental")).is_equal(cases[component_id])


## Regression guard for a real gap found via live Godot MCP verification
## 2026-08-30: the synthetic ID lists elsewhere in this file (matching every
## keyword the resolver knows about) never actually covered this project's
## REAL shipped foundation data, so found_iron_t1/found_reinforced_t2 silently
## fell through to the modular fallback for weeks without any test noticing.
## Reads the real .tres files directly rather than hardcoding their IDs, so a
## future foundation added to assets/data/tower_components/ is covered
## automatically.
func test_all_real_shipped_foundation_components_resolve_named_shapes() -> void:
	var dir := DirAccess.open("res://assets/data/tower_components")
	assert_object(dir).is_not_null()
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var checked_any: bool = false
	while file_name != "":
		if file_name.begins_with("foundation_") and file_name.ends_with(".tres"):
			var component: FoundationComponent = load("res://assets/data/tower_components/%s" % file_name) as FoundationComponent
			assert_object(component).is_not_null()
			var shape: StringName = _instance.resolve_shape_for_component(component.component_id, component.archetype)
			assert_object(shape).append_failure_message(
				"foundation_component_id '%s' (from %s) resolved to no named shape -- falls through to the modular fallback" % [component.component_id, file_name]
			).is_not_equal(&"")
			checked_any = true
		file_name = dir.get_next()
	dir.list_dir_end()
	assert_bool(checked_any).is_true()


func test_unknown_component_uses_modular_archetype_fallback() -> void:
	_instance.configure("elemental", "fire", "future_foundation", "future_weapon")
	assert_object(_instance._base_sprite.texture).is_equal(TowerInstance.MODULAR_BASE_TEXTURE)
	assert_object(_instance._shaft_sprite.texture).is_equal(TowerInstance.MODULAR_SHAFT_TEXTURES[&"solid"])
	assert_object(_instance._top_sprite.texture).is_equal(TowerInstance.MODULAR_TOP_TEXTURES[&"fire"])


func test_unknown_support_component_uses_open_support_shaft() -> void:
	_instance.configure("support", "", "future_support_foundation", "future_support_weapon")
	assert_object(_instance._shaft_sprite.texture).is_equal(TowerInstance.MODULAR_SHAFT_TEXTURES[&"support"])
	assert_object(_instance._top_sprite.texture).is_equal(TowerInstance.MODULAR_TOP_TEXTURES[&"support"])


func test_each_dedicated_weapon_id_resolves_its_integrated_top() -> void:
	var cases: Dictionary[String, StringName] = {
		"weap_siege_t4": &"siege",
		"weap_railgun_t4": &"railgun",
		"weap_arcane_t3": &"arcane",
		"weap_storm_t2": &"storm",
		"weap_firestorm_t4": &"firestorm",
		"weap_frostbolt_t1": &"frost",
	}
	for weapon_id: String in cases:
		_instance.configure("elemental", "", "found_archer_t1", weapon_id)
		assert_object(_instance._top_sprite.texture).is_equal(TowerInstance.WEAPON_TOP_TEXTURES[cases[weapon_id]])


func test_all_shipped_foundation_component_ids_resolve_named_shapes() -> void:
	var component_ids: PackedStringArray = [
		"found_arcane_t3", "found_archer_t1", "found_barrier_t2", "found_bulwark_t2",
		"found_firebolt_t1", "found_firestorm_t4", "found_frostbolt_t1", "found_grandrally_t4",
		"found_longshot_t1", "found_ballista_t3", "found_railgun_t4", "found_rally_t1",
		"found_standard_t3", "found_siege_t4", "found_storm_t2", "found_venomdart_t1",
		"found_volley_t2", "found_warbreaker_t3",
	]
	for component_id: String in component_ids:
		assert_object(_instance.resolve_shape_for_component(component_id, "")).is_not_equal(&"")


func test_layered_tower_is_scaled_to_target_height_and_bottom_centered() -> void:
	_instance.configure("physical", "", "found_siege_t4", "weap_siege_t4")
	var bounds: Rect2 = _instance.get_layered_visual_bounds()
	assert_float(bounds.size.y * _instance._layer_root.scale.y).is_between(63.9, 64.1)
	assert_float(bounds.end.y * _instance._layer_root.scale.y).is_equal_approx(TowerInstance.TARGET_DISPLAY_HEIGHT * 0.5, 0.1)


func test_stack_layers_seats_each_piece_on_the_seat_line_below_it() -> void:
	for base_shape: StringName in TowerInstance.SHAPE_BASE_TEXTURES:
		for shaft_shape: StringName in TowerInstance.SHAPE_SHAFT_TEXTURES:
			var textures: Array[Texture2D] = [
				TowerInstance.SHAPE_BASE_TEXTURES[base_shape],
				TowerInstance.SHAPE_SHAFT_TEXTURES[shaft_shape],
				TowerInstance.SHAPE_TOP_TEXTURES[&"round"],
			]
			var rects: Array[Rect2] = TowerInstance.stack_layers(textures)
			for i: int in [1, 2]:
				var lower: Rect2 = _painted_part(textures[i - 1], rects[i - 1])
				var upper: Rect2 = _painted_part(textures[i], rects[i])
				var seat_y: float = lower.position.y + TowerInstance.seat_fraction(textures[i - 1]) * lower.size.x
				assert_float(upper.end.y).is_equal_approx(seat_y, 0.0001)
				assert_float(upper.get_center().x).is_equal_approx(0.0, 0.0001)


func test_stack_layers_matches_painted_widths_across_families() -> void:
	var textures: Array[Texture2D] = [
		TowerInstance.SHAPE_BASE_TEXTURES[&"triangle"],
		TowerInstance.SHAPE_SHAFT_TEXTURES[&"hexplank"],
		TowerInstance.SHAPE_TOP_TEXTURES[&"stonemound"],
	]
	var rects: Array[Rect2] = TowerInstance.stack_layers(textures)
	for i: int in textures.size():
		assert_float(_painted_part(textures[i], rects[i]).size.x).is_equal_approx(TowerInstance.LAYER_WIDTH_FRACTIONS[i], 0.0001)


func test_shape_family_reads_family_from_layer_file_names() -> void:
	assert_str(String(TowerInstance.shape_family(TowerInstance.SHAPE_BASE_TEXTURES[&"triangle"]))).is_equal("triangle")
	assert_str(String(TowerInstance.shape_family(TowerInstance.SHAPE_SHAFT_TEXTURES[&"hexplank"]))).is_equal("hexplank")
	assert_str(String(TowerInstance.shape_family(TowerInstance.SHAPE_TOP_TEXTURES[&"round"]))).is_equal("round")
	assert_str(String(TowerInstance.shape_family(TowerInstance.MODULAR_BASE_TEXTURE))).is_equal("")
	for weapon_top: Texture2D in TowerInstance.WEAPON_TOP_TEXTURES.values():
		assert_str(String(TowerInstance.shape_family(weapon_top))).is_equal("")


func test_with_adaptor_caps_inserts_a_cap_only_between_mismatched_families_with_art() -> void:
	var matched: Array[Texture2D] = [
		TowerInstance.SHAPE_BASE_TEXTURES[&"round"],
		TowerInstance.SHAPE_SHAFT_TEXTURES[&"round"],
		TowerInstance.SHAPE_TOP_TEXTURES[&"round"],
	]
	assert_int(TowerInstance.with_adaptor_caps(matched).size()).is_equal(3)
	var mixed: Array[Texture2D] = [
		TowerInstance.SHAPE_BASE_TEXTURES[&"square"],
		TowerInstance.SHAPE_SHAFT_TEXTURES[&"triangle"],
		TowerInstance.SHAPE_TOP_TEXTURES[&"round"],
	]
	var expected: int = 3
	for family: String in ["square", "triangle"]:
		if ResourceLoader.exists(TowerInstance.CAP_TEXTURE_PATH_FORMAT % family):
			expected += 1
	var capped: Array[Texture2D] = TowerInstance.with_adaptor_caps(mixed)
	assert_int(capped.size()).is_equal(expected)
	for texture: Texture2D in capped:
		if TowerInstance.is_adaptor_cap(texture):
			assert_bool(TowerInstance.shape_family(texture) in [&"square", &"triangle"]).is_true()


func _painted_part(texture: Texture2D, rect: Rect2) -> Rect2:
	var tex_scale: float = rect.size.x / float(texture.get_width())
	var painted: Rect2 = TowerInstance.painted_rect(texture)
	return Rect2(rect.position + painted.position * tex_scale, painted.size * tex_scale)


func test_all_shape_profiles_remain_64_units_and_bottom_centered() -> void:
	var foundations: Dictionary[String, StringName] = {
		"found_archer_t1": &"round", "found_bulwark_t2": &"square",
		"found_rally_t1": &"stump", "found_venomdart_t1": &"stonemound",
		"found_arcane_t3": &"octagon", "found_standard_t3": &"tiered",
		"found_frostbolt_t1": &"scalloped", "found_longshot_t1": &"triangle",
		"found_siege_t4": &"hexplank",
	}
	for foundation_id: String in foundations:
		_instance.configure("physical", "", foundation_id, "weap_basic")
		_assert_layered_layout_is_bounded()


func test_all_weapon_top_profiles_remain_64_units_and_bottom_centered() -> void:
	var weapon_ids: PackedStringArray = [
		"weap_siege_t4", "weap_railgun_t4", "weap_arcane_t3",
		"weap_storm_t2", "weap_firestorm_t4", "weap_frostbolt_t1",
	]
	for weapon_id: String in weapon_ids:
		_instance.configure("elemental", "arcane", "found_archer_t1", weapon_id)
		_assert_layered_layout_is_bounded()


func _assert_layered_layout_is_bounded() -> void:
	var bounds: Rect2 = _instance.get_layered_visual_bounds()
	var scaled_height: float = bounds.size.y * _instance._layer_root.scale.y
	var scaled_bottom: float = bounds.end.y * _instance._layer_root.scale.y
	assert_float(scaled_height).is_between(63.9, 64.1)
	assert_float(scaled_bottom).is_equal_approx(TowerInstance.TARGET_DISPLAY_HEIGHT * 0.5, 0.1)


func test_configure_each_known_archetype_resolves_a_distinct_texture() -> void:
	var seen: Dictionary = {}
	for archetype: String in TowerInstance.ARCHETYPE_TEXTURES:
		_instance.configure(archetype)
		var tex := _instance._sprite.texture
		assert_object(tex).is_not_null()
		assert_bool(seen.has(tex)).is_false()
		seen[tex] = true


## Regression test for the 2026-08-17 fix (Art & Animation Pipeline Upgrade
## audit): configure() previously only received archetype, so every
## "elemental" tower rendered as ice art regardless of its real element --
## including the shipped Firebolt Turret (element="fire"). See
## TowerInstance.ELEMENT_TEXTURES's own doc comment.
func test_configure_elemental_archetype_with_element_resolves_element_texture() -> void:
	_instance.configure("elemental", "fire")
	assert_object(_instance._sprite.texture).is_equal(TowerInstance.ELEMENT_TEXTURES["fire"])
	assert_object(_instance._sprite.texture).is_not_equal(TowerInstance.ARCHETYPE_TEXTURES["elemental"])


## element="" (or an element with no entry in ELEMENT_TEXTURES) must still
## fall back to the generic elemental texture, not leave the sprite empty --
## this is the pre-fix behavior for non-elemental archetypes and for any
## element not yet in ELEMENT_TEXTURES.
func test_configure_elemental_archetype_with_unknown_element_falls_back_to_archetype_texture() -> void:
	_instance.configure("elemental", "totally_unknown_element")
	assert_object(_instance._sprite.texture).is_equal(TowerInstance.ARCHETYPE_TEXTURES["elemental"])


## "arcane" has a real ProjectileVisual.ELEMENT_COLORS entry but no
## TowerInstance.ELEMENT_TEXTURES entry -- exactly the real gap this
## feature targets (a defined element with no bespoke tower art yet).
func test_configure_elemental_with_color_but_no_texture_activates_tint_with_its_color() -> void:
	_instance.configure("elemental", "arcane")
	assert_bool(_instance._element_tint_active).is_true()
	assert_object(_instance._element_tint_color).is_equal(ProjectileVisual.ELEMENT_COLORS["arcane"])


func test_configure_elemental_with_known_texture_element_does_not_activate_tint() -> void:
	_instance.configure("elemental", "fire")
	assert_bool(_instance._element_tint_active).is_false()


func test_configure_elemental_with_wholly_unknown_element_activates_tint_with_generic_fallback_color() -> void:
	_instance.configure("elemental", "totally_unknown_element")
	assert_bool(_instance._element_tint_active).is_true()
	assert_object(_instance._element_tint_color).is_equal(ProjectileVisual.ARCHETYPE_COLORS["elemental"])


func test_configure_elemental_with_empty_element_does_not_activate_tint() -> void:
	_instance.configure("elemental", "")
	assert_bool(_instance._element_tint_active).is_false()


func test_configure_non_elemental_archetype_does_not_activate_tint() -> void:
	_instance.configure("physical")
	assert_bool(_instance._element_tint_active).is_false()


## Regression guard: a tower reconfigured from a tint-active element to a
## known-texture element must not carry a stale ring over.
func test_configure_switching_from_tint_element_to_known_texture_element_clears_tint() -> void:
	_instance.configure("elemental", "arcane")
	assert_bool(_instance._element_tint_active).is_true()
	_instance.configure("elemental", "fire")
	assert_bool(_instance._element_tint_active).is_false()


# ---------------------------------------------------------------------------
# Art & Animation Pipeline Upgrade (2026-08-17) — play_hit_flash()
# ---------------------------------------------------------------------------

func test_ready_assigns_a_shader_material_to_the_sprite() -> void:
	assert_object(_instance._sprite.material).is_instanceof(ShaderMaterial)


func test_play_hit_flash_sets_flash_amount_to_full() -> void:
	_instance.play_hit_flash()
	var material := _instance._sprite.material as ShaderMaterial
	assert_float(material.get_shader_parameter("flash_amount")).is_equal_approx(1.0, 0.001)


func test_play_hit_flash_updates_every_layer_material() -> void:
	_instance.configure("physical", "", "found_siege_t4", "weap_siege_t4")
	_instance.play_hit_flash()
	var sprites: Array[Sprite2D] = [_instance._base_sprite, _instance._shaft_sprite, _instance._top_sprite]
	for sprite: Sprite2D in sprites:
		var material: ShaderMaterial = sprite.material as ShaderMaterial
		assert_float(material.get_shader_parameter("flash_amount")).is_equal_approx(1.0, 0.001)


# --- 3D tower path (ADR-0043, spec 2026-11-07-3d-towers-design §5.4) -------
# found_arcane_* resolves to the octagon family and weap_siege_* to the siege
# crown: both modelled in assets/art/towers3d/. An unknown foundation id
# resolves to no family at all, so it can never have a model.

func _add_scenery() -> Hd2dScenery:
	var scenery := Hd2dScenery.new()
	add_child(scenery)
	return scenery


func test_tower_instance_without_scenery_uses_2d_layers() -> void:
	_instance.configure("physical", "", "found_arcane_t3", "weap_siege_t4")
	assert_object(_instance.get_model_3d()).is_null()
	assert_bool(_instance._layer_root.visible).is_true()


func test_tower_instance_with_scenery_and_models_spawns_model_under_scenery() -> void:
	var scenery := _add_scenery()
	_instance.position = Vector2(320, 192)
	_instance.set_scenery(scenery)
	_instance.configure("physical", "", "found_arcane_t3", "weap_siege_t4", 2)
	var model: TowerModel3D = _instance.get_model_3d()
	assert_object(model).is_not_null()
	assert_object(model.get_parent()).is_same(scenery.get_dynamic_root())
	assert_bool(_instance._visual_root.visible).is_false()
	assert_vector(model.position).is_equal_approx(scenery.to_world(_instance.global_position), Vector3(0.01, 0.01, 0.01))
	remove_child(scenery)
	scenery.free()


func test_tower_instance_with_scenery_but_unmodelled_piece_falls_back_to_2d() -> void:
	var scenery := _add_scenery()
	_instance.set_scenery(scenery)
	_instance.configure("ranged", "", "found_unknown_t2", "weap_unknown_t2")
	assert_object(_instance.get_model_3d()).is_null()
	assert_bool(_instance._layer_root.visible).is_true()
	remove_child(scenery)
	scenery.free()


func test_tower_instance_freeing_tower_frees_model() -> void:
	var scenery := _add_scenery()
	_instance.set_scenery(scenery)
	_instance.configure("physical", "", "found_arcane_t3", "weap_siege_t4")
	var model: TowerModel3D = _instance.get_model_3d()
	remove_child(_instance)
	_instance.free()
	_instance = load("res://src/core/tower/TowerInstance.tscn").instantiate() as TowerInstance
	add_child(_instance)  # keeps after_test() valid
	await get_tree().process_frame
	assert_bool(is_instance_valid(model)).is_false()
	remove_child(scenery)
	scenery.free()


func test_tower_instance_targeting_forwards_to_model_aim() -> void:
	var scenery := _add_scenery()
	_instance.position = Vector2(320, 192)
	_instance.set_scenery(scenery)
	_instance.configure("physical", "", "found_arcane_t3", "weap_siege_t4")
	var target := Node2D.new()
	add_child(target)
	target.global_position = _instance.global_position + Vector2(100, 0)
	_instance.play_targeting_orientation(target.global_position, Color.WHITE, 1.0, target)
	for i: int in 12:  # 1.2 s: inside the 1.0 + AIM_HOLD_EXTRA hold, long enough to arrive
		_instance._process(0.1)
		_instance.get_model_3d()._process(0.1)
	var crown: Node3D = _instance.get_model_3d().find_child("Crown", true, false) as Node3D
	assert_float(wrapf(crown.rotation.y, -PI, PI)).is_equal_approx(PI / 2, 0.01)
	remove_child(target)
	target.free()
	remove_child(scenery)
	scenery.free()


func test_tower_instance_freed_target_returns_crown_to_sweep() -> void:
	var scenery := _add_scenery()
	_instance.set_scenery(scenery)
	_instance.configure("physical", "", "found_arcane_t3", "weap_siege_t4")
	var target := Node2D.new()
	add_child(target)
	target.global_position = _instance.global_position + Vector2(100, 0)
	_instance.play_targeting_orientation(target.global_position, Color.WHITE, 5.0, target)
	_instance._process(0.1)
	remove_child(target)
	target.free()
	_instance._process(0.1)
	assert_bool(_instance.get_model_3d().is_tracking()).is_false()
	remove_child(scenery)
	scenery.free()


func test_tower_instance_rank_before_build_applies_after_build() -> void:
	var scenery := _add_scenery()
	_instance.set_rank(2)
	_instance.set_scenery(scenery)
	_instance.configure("physical", "", "found_arcane_t3", "weap_siege_t4")
	var r2: Node3D = _instance.get_model_3d().get_node_or_null("Rank2") as Node3D
	assert_object(r2).is_not_null()
	assert_bool(r2.visible).is_true()
	remove_child(scenery)
	scenery.free()


## Review finding (2026-11-07): a mission retry rebuilds the scenery, which
## used to free every child -- including live tower models -- leaving placed
## towers invisible (2D hidden, 3D gone).
func test_tower_instance_model_survives_scenery_rebuild() -> void:
	var scenery := _add_scenery()
	scenery.profile = load("res://assets/data/hd2d/the_gap_scenery.tres") as Hd2dSceneryProfile
	scenery.build(4, 4, 64.0, {})
	_instance.set_scenery(scenery)
	_instance.configure("physical", "", "found_arcane_t3", "weap_siege_t4")
	var model: TowerModel3D = _instance.get_model_3d()
	scenery.build(4, 4, 64.0, {})
	await get_tree().process_frame
	assert_bool(is_instance_valid(model)).is_true()
	assert_bool(model.is_inside_tree()).is_true()
	remove_child(scenery)
	scenery.free()
