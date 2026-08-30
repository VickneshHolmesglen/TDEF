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


func test_every_shape_family_has_a_complete_overlap_profile() -> void:
	assert_int(TowerInstance.SHAPE_OVERLAP_PROFILES.size()).is_equal(TowerInstance.SHAPE_BASE_TEXTURES.size())
	for shape: StringName in TowerInstance.SHAPE_BASE_TEXTURES:
		assert_bool(TowerInstance.SHAPE_OVERLAP_PROFILES.has(shape)).is_true()
		var profile: Vector2 = TowerInstance.SHAPE_OVERLAP_PROFILES[shape]
		assert_float(profile.x).is_between(0.0, 0.5)
		assert_float(profile.y).is_between(0.0, 0.5)


func test_every_dedicated_weapon_top_has_an_overlap_profile() -> void:
	assert_int(TowerInstance.WEAPON_TOP_OVERLAP_PROFILES.size()).is_equal(TowerInstance.WEAPON_TOP_TEXTURES.size())
	for weapon_top: StringName in TowerInstance.WEAPON_TOP_TEXTURES:
		assert_bool(TowerInstance.WEAPON_TOP_OVERLAP_PROFILES.has(weapon_top)).is_true()
		assert_float(TowerInstance.WEAPON_TOP_OVERLAP_PROFILES[weapon_top]).is_between(0.0, 0.5)


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
