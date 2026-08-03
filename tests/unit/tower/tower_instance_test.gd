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
