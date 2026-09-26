## Wind-up presentation Task 7: the Hero death sequence. Calls `_fb._on_hero_died()` directly
## (not GEventBus.hero_died.emit()) so the live GSceneManager's death hold is never armed.
extends GdUnitTestSuite

var _hero_parent: Node2D
var _hero: Node2D
var _sprite: Sprite2D
var _camera: Camera2D
var _fb: HeroFeedback


func before_test() -> void:
	_hero_parent = Node2D.new()
	add_child(_hero_parent)
	_hero = Node2D.new()
	_hero_parent.add_child(_hero)
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_hero.add_child(_sprite)
	_camera = Camera2D.new()
	_hero_parent.add_child(_camera)
	_fb = HeroFeedback.new()
	_fb.setup(_hero, _camera, func(_id: int) -> Vector2: return Vector2.INF)
	add_child(_fb)


func after_test() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, null)
	if is_instance_valid(_fb):
		_fb.free()
	_hero_parent.free()


## The ring is the only bare Node2D sibling of the Hero (the inner class _DeathRing reports "Node2D").
func _rings() -> Array:
	return _hero_parent.get_children().filter(func(n: Node) -> bool: return n.get_class() == "Node2D" and n != _hero)


func test_hero_died_marks_dead_and_fades_the_sprite_to_30_percent() -> void:
	_fb._on_hero_died()
	assert_bool(_fb.is_dead()).is_true()
	_settle_death_tweens()
	assert_float(_sprite.modulate.a).is_equal_approx(0.3, 0.02)


func test_death_desaturates_the_screen_and_freezes_the_vignette_at_maximum() -> void:
	_fb._on_hero_died()
	_settle_death_tweens()
	var mat: ShaderMaterial = _fb.get_screen_fx_material()
	assert_float(float(mat.get_shader_parameter("desaturate"))).is_equal_approx(HeroFeedback.DEATH_DESATURATE, 0.01)
	assert_float(_fb.get_vignette_strength()).is_equal_approx(HeroFeedback.VIGNETTE_MAX, 0.001)
	_fb.advance(1.0)  # frozen: time passing changes nothing
	assert_float(_fb.get_vignette_strength()).is_equal_approx(HeroFeedback.VIGNETTE_MAX, 0.001)


## Steps the stored death tweens to completion deterministically (headless frame deltas are coarse).
func _settle_death_tweens() -> void:
	for tween: Tween in [_fb._death_tween, _fb._flash_tween]:
		if tween != null and tween.is_valid():
			tween.pause()
			tween.custom_step(1.0)


func test_death_spawns_one_shockwave_ring_that_frees_itself() -> void:
	_fb._on_hero_died()
	_fb._on_hero_died()  # idempotent
	assert_int(_rings().size()).is_equal(1)
	await get_tree().create_timer(0.4).timeout
	assert_int(_rings().size()).is_equal(0)


func test_death_skips_the_ring_under_reduced_motion() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, true)
	_fb._on_hero_died()
	assert_int(_rings().size()).is_equal(0)


func test_a_new_wave_clears_the_death_state() -> void:
	_fb._on_hero_died()
	_settle_death_tweens()
	GEventBus.wave_started.emit(1, 5, 1.0)
	assert_bool(_fb.is_dead()).is_false()
	assert_float(_sprite.modulate.a).is_equal(1.0)
	assert_float(float(_fb.get_screen_fx_material().get_shader_parameter("desaturate"))).is_equal(0.0)


func test_a_later_wave_keeps_low_hp_feedback_on_a_live_hero() -> void:
	_fb._on_health_changed(15.0, 100.0)
	_fb.advance(0.3)
	GEventBus.wave_started.emit(2, 5, 1.0)
	assert_bool(_fb.is_low_hp_active()).is_true()
	assert_float(_fb.get_vignette_fade()).is_equal_approx(1.0, 0.001)
	assert_object(_sprite.modulate).is_equal(HeroFeedback.LOW_HP_SPRITE_TINT)


func test_wave_one_clears_low_hp_state_on_a_live_hero() -> void:
	_fb._on_health_changed(15.0, 100.0)
	_fb.advance(0.3)
	GEventBus.wave_started.emit(1, 5, 1.0)
	assert_bool(_fb.is_low_hp_active()).is_false()
	assert_float(_fb.get_vignette_fade()).is_equal(0.0)


func test_death_with_no_prior_hit_still_white_flashes() -> void:
	_fb._on_hero_died()
	assert_float(float(_fb._flash_material.get_shader_parameter("flash_amount"))).is_greater(0.0)


func test_a_killing_blow_damage_handler_does_not_cancel_the_death_sequence() -> void:
	_fb._on_health_changed(100.0, 100.0)
	_fb._on_hero_died()
	_fb._on_damage_taken(10, 0)  # Hero emits died before HeroFeedback's own damage handler runs
	_settle_death_tweens()
	assert_float(_sprite.modulate.a).is_equal_approx(0.3, 0.02)
	assert_object(_fb._flinch_tween).is_null()
	assert_int(_hero_parent.get_children().filter(func(n: Node) -> bool: return n is CPUParticles2D).size()).is_equal(0)


func test_wave_one_after_death_resets_a_flinched_sprite_position() -> void:
	_sprite.position = Vector2(5.0, 5.0)
	_fb.setup(_hero, _camera, func(_id: int) -> Vector2: return Vector2.INF)  # rest = (5, 5)
	_fb._on_damage_taken(10, 0)
	_fb._on_hero_died()
	_sprite.position = Vector2(9.0, 9.0)  # mid-flinch displacement
	GEventBus.wave_started.emit(1, 5, 1.0)
	assert_vector(_sprite.position).is_equal(Vector2(5.0, 5.0))
	assert_bool(_fb._flinch_tween == null or not _fb._flinch_tween.is_valid()).is_true()
