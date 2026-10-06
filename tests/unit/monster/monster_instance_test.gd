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
	# One animation frame, not the whole sprite-sheet strip (walk animation, 2026-10-07).
	var frame_size := Vector2(texture.get_width() / float(_instance._sprite.hframes), texture.get_height() / float(_instance._sprite.vframes))
	var longest_edge := maxf(frame_size.x, frame_size.y)
	var scaled_edge := longest_edge * _instance._sprite.scale.x
	assert_float(scaled_edge).is_between(63.9, 64.1)


func test_configure_scales_boss_tier_sprite_larger_than_standard() -> void:
	_instance.configure(&"rift_sentinel_boss", 2)
	var texture := _instance._sprite.texture
	var frame_size := Vector2(texture.get_width() / float(_instance._sprite.hframes), texture.get_height() / float(_instance._sprite.vframes))
	var longest_edge := maxf(frame_size.x, frame_size.y)
	var scaled_edge := longest_edge * _instance._sprite.scale.x
	assert_float(scaled_edge).is_between(111.9, 112.1)


func test_configure_uniform_scale_preserves_aspect_ratio() -> void:
	_instance.configure(&"goblin_runner", 0)
	assert_float(_instance._sprite.scale.x).is_equal_approx(_instance._sprite.scale.y, 0.0001)


# ---------------------------------------------------------------------------
# design/gdd/monster.md "Tier Badge / Icon" — STANDARD gets no badge/
# nameplate, ELITE gets a badge only, BOSS gets a badge + nameplate.
# ---------------------------------------------------------------------------

func test_configure_standard_tier_records_no_badge_and_no_nameplate() -> void:
	_instance.configure(&"goblin_runner", 0, "Goblin Runner")
	assert_int(_instance._tier).is_equal(0)
	assert_bool(_instance._nameplate.visible).is_false()


func test_configure_elite_tier_records_tier_but_no_nameplate() -> void:
	_instance.configure(&"forest_troll_elite", 1, "Forest Troll")
	assert_int(_instance._tier).is_equal(1)
	# ELITE gets a badge (drawn via _draw(), not independently assertable
	# here) but explicitly no nameplate — that's BOSS-only per the GDD.
	assert_bool(_instance._nameplate.visible).is_false()


func test_configure_boss_tier_shows_nameplate_with_display_name() -> void:
	_instance.configure(&"goblin_warlord_boss", 2, "Goblin Warlord")
	assert_int(_instance._tier).is_equal(2)
	assert_bool(_instance._nameplate.visible).is_true()
	assert_str(_instance._nameplate.text).is_equal("Goblin Warlord")


func test_configure_boss_nameplate_is_positioned_above_the_sprite_top_edge() -> void:
	_instance.configure(&"goblin_warlord_boss", 2, "Goblin Warlord")
	# Nameplate's bottom edge (position.y + its own height) must sit above
	# (a smaller/more-negative Y than) the sprite's own top edge.
	var nameplate_bottom: float = _instance._nameplate.position.y + _instance._nameplate.get_minimum_size().y
	assert_float(nameplate_bottom).is_less(-_instance._sprite_half_size.y)


func test_configure_switching_from_boss_to_standard_hides_the_nameplate() -> void:
	_instance.configure(&"goblin_warlord_boss", 2, "Goblin Warlord")
	assert_bool(_instance._nameplate.visible).is_true()

	_instance.configure(&"goblin_runner", 0)
	assert_bool(_instance._nameplate.visible).is_false()


# ---------------------------------------------------------------------------
# Art & Animation Pipeline Upgrade (2026-08-17) — play_hit_flash()
# ---------------------------------------------------------------------------

func test_ready_assigns_a_shader_material_to_the_sprite() -> void:
	assert_object(_instance._sprite.material).is_instanceof(ShaderMaterial)


func test_play_hit_flash_sets_flash_amount_to_full() -> void:
	_instance.play_hit_flash()
	var material := _instance._sprite.material as ShaderMaterial
	assert_float(material.get_shader_parameter("flash_amount")).is_equal_approx(1.0, 0.001)


func test_play_hit_flash_called_twice_kills_the_prior_tween_without_error() -> void:
	_instance.play_hit_flash()
	_instance.play_hit_flash()
	var material := _instance._sprite.material as ShaderMaterial
	assert_float(material.get_shader_parameter("flash_amount")).is_equal_approx(1.0, 0.001)



# ---------------------------------------------------------------------------
# Walk animation from the sprite sheet (2026-10-07)
# ---------------------------------------------------------------------------

func test_a_monster_with_a_sheet_animates_from_it() -> void:
	_instance.configure(&"goblin_runner", 0)
	assert_bool(_instance.is_sheet_animated()).is_true()
	assert_int(_instance._sprite.hframes).is_equal(5)


func test_moving_plays_the_walk_clip_and_cycles_frames() -> void:
	_instance.configure(&"goblin_runner", 0)
	_instance.advance_animation(0.0)
	var seen: Dictionary = {}
	for i: int in 12:
		_instance.position.x += 2.0
		_instance.advance_animation(1.0 / 30.0)
		seen[_instance._sprite.frame] = true
	assert_str(String(_instance.get_current_clip())).is_equal("walk")
	assert_int(seen.size()).is_greater(1)
	for frame: int in seen:
		assert_int(frame).is_between(1, 4)


func test_standing_still_shows_the_idle_frame() -> void:
	_instance.configure(&"goblin_runner", 0)
	_instance.advance_animation(0.1)
	_instance.advance_animation(0.1)
	assert_str(String(_instance.get_current_clip())).is_equal("idle")
	assert_int(_instance._sprite.frame).is_equal(0)


func test_walking_left_flips_the_sprite() -> void:
	_instance.configure(&"goblin_runner", 0)
	_instance.advance_animation(0.0)
	_instance.position.x -= 3.0
	_instance.advance_animation(0.03)
	assert_bool(_instance._sprite.flip_h).is_true()
	_instance.position.x += 3.0
	_instance.advance_animation(0.03)
	assert_bool(_instance._sprite.flip_h).is_false()


func test_iron_colossus_shows_its_sheet_instead_of_nothing() -> void:
	_instance.configure(&"iron_colossus_elite", 1)
	assert_object(_instance._sprite.texture).is_not_null()
	assert_bool(_instance.is_sheet_animated()).is_true()


func test_a_boss_wind_up_plays_the_attack_prepare_clip() -> void:
	_instance.configure(&"rift_sentinel_boss", 2)
	for i: int in 4:
		_instance.advance_animation(0.1, true)
	assert_str(String(_instance.get_current_clip())).is_equal("attack_prepare")
	assert_int(_instance._sprite.frame).is_between(5, 8)
