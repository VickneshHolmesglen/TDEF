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
