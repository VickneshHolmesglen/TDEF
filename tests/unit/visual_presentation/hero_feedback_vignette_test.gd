extends GdUnitTestSuite

var _hero_parent: Node2D
var _hero: Node2D
var _sprite: Sprite2D
var _camera: Camera2D
var _fb: HeroFeedback
var _rest: Vector2 = Vector2(3.0, 5.0)


func _provider(entity_id: int) -> Vector2:
	return Vector2(100.0, 0.0) if entity_id == 7 else Vector2.INF


func _event(source_entity_id: int) -> HeroIncomingDamageEvent:
	var ev := HeroIncomingDamageEvent.new()
	ev.amount = 10.0
	ev.damage_type = "physical"
	ev.source_type = 0
	ev.source_entity_id = source_entity_id
	return ev


func before_test() -> void:
	_hero_parent = Node2D.new()
	add_child(_hero_parent)
	_hero = Node2D.new()
	_hero_parent.add_child(_hero)
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_sprite.position = _rest
	_hero.add_child(_sprite)
	_camera = Camera2D.new()
	_hero_parent.add_child(_camera)
	_fb = HeroFeedback.new()
	_fb.setup(_hero, _camera, _provider)
	add_child(_fb)


func after_test() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, null)
	if is_instance_valid(_fb):
		_fb.free()
	_hero_parent.free()


func test_is_low_hp_thresholds() -> void:
	assert_bool(HeroFeedback.is_low_hp(19.9, 100.0)).is_true()
	assert_bool(HeroFeedback.is_low_hp(20.0, 100.0)).is_false()
	assert_bool(HeroFeedback.is_low_hp(0.0, 100.0)).is_false()
	assert_bool(HeroFeedback.is_low_hp(5.0, 0.0)).is_false()


func test_low_hp_activates_and_fades_in() -> void:
	_fb._on_health_changed(15.0, 100.0)
	assert_bool(_fb.is_low_hp_active()).is_true()
	_fb.advance(0.3)
	assert_float(_fb.get_vignette_fade()).is_equal_approx(1.0, 0.001)
	assert_float(_fb.get_vignette_strength()).is_greater(0.0)
	assert_bool(_fb._screen_rect.visible).is_true()


func test_healing_fades_out_and_hides_rect() -> void:
	_fb._on_health_changed(15.0, 100.0)
	_fb.advance(0.3)
	_fb._on_health_changed(60.0, 100.0)
	assert_bool(_fb.is_low_hp_active()).is_false()
	_fb.advance(0.3)
	assert_float(_fb.get_vignette_fade()).is_equal_approx(0.0, 0.001)
	assert_bool(_fb._screen_rect.visible).is_false()


func test_vignette_strength_range_and_period() -> void:
	var v: float = HeroFeedback.vignette_strength(0.0, false)
	assert_bool(v >= HeroFeedback.VIGNETTE_MIN - 0.0001 and v <= HeroFeedback.VIGNETTE_MAX + 0.0001).is_true()
	for t: float in [0.0, 0.2, 0.7, 1.1]:
		assert_float(HeroFeedback.vignette_strength(t, false)).is_equal_approx(HeroFeedback.vignette_strength(t + 1.5, false), 0.0001)


func test_reduced_motion_is_steady() -> void:
	for t: float in [0.0, 0.4, 0.9, 3.3]:
		assert_float(HeroFeedback.vignette_strength(t, true)).is_equal_approx(0.55, 0.0001)


func test_sprite_tint_follows_low_hp() -> void:
	_fb._on_health_changed(15.0, 100.0)
	assert_object(_sprite.modulate).is_equal(HeroFeedback.LOW_HP_SPRITE_TINT)
	_fb._on_health_changed(60.0, 100.0)
	assert_object(_sprite.modulate).is_equal(Color.WHITE)


func test_full_health_material_strength_is_zero() -> void:
	_fb._on_health_changed(100.0, 100.0)
	_fb.advance(0.3)
	assert_float(float(_fb.get_screen_fx_material().get_shader_parameter("vignette_strength"))).is_equal(0.0)
