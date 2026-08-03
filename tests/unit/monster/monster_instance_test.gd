## Unit tests for MonsterInstance — presentation-only texture lookup by monster_id.
## Mirrors the absence of a dedicated TowerInstance test file only in that
## TowerInstance has none yet; this class gets direct coverage since it's
## also exercised indirectly via monster_spawn_test.gd's wiring tests.
extends GdUnitTestSuite

var _instance: MonsterInstance


func before_test() -> void:
	_instance = MonsterManager.MONSTER_INSTANCE_SCENE.instantiate() as MonsterInstance
	add_child(_instance)


func after_test() -> void:
	remove_child(_instance)
	_instance.free()


func test_configure_known_monster_id_sets_sprite_texture() -> void:
	_instance.configure(&"goblin_runner")
	assert_object(_instance._sprite.texture).is_not_null()


func test_configure_each_known_monster_id_resolves_a_distinct_texture() -> void:
	var seen: Dictionary = {}
	for id: StringName in MonsterInstance.MONSTER_TEXTURES:
		_instance.configure(id)
		var tex := _instance._sprite.texture
		assert_object(tex).is_not_null()
		assert_bool(seen.has(tex)).is_false()
		seen[tex] = true


func test_configure_unknown_monster_id_leaves_sprite_texture_null() -> void:
	_instance.configure(&"totally_unknown_monster")
	assert_object(_instance._sprite.texture).is_null()


func test_configure_scales_standard_tier_sprite_to_fit_one_cell() -> void:
	_instance.configure(&"goblin_runner", 0)
	var texture := _instance._sprite.texture
	var longest_edge := maxf(texture.get_width(), texture.get_height())
	var scaled_edge := longest_edge * _instance._sprite.scale.x
	assert_float(scaled_edge).is_between(63.9, 64.1)


func test_configure_scales_boss_tier_sprite_larger_than_standard() -> void:
	_instance.configure(&"rift_sentinel_boss", 2)
	var texture := _instance._sprite.texture
	var longest_edge := maxf(texture.get_width(), texture.get_height())
	var scaled_edge := longest_edge * _instance._sprite.scale.x
	assert_float(scaled_edge).is_between(111.9, 112.1)


func test_configure_uniform_scale_preserves_aspect_ratio() -> void:
	_instance.configure(&"goblin_runner", 0)
	assert_float(_instance._sprite.scale.x).is_equal_approx(_instance._sprite.scale.y, 0.0001)
