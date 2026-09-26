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


func test_is_big_hit_is_strictly_greater_than_25_percent() -> void:
	assert_bool(HeroFeedback.is_big_hit(25, 100.0)).is_false()
	assert_bool(HeroFeedback.is_big_hit(26, 100.0)).is_true()
	assert_bool(HeroFeedback.is_big_hit(50, 0.0)).is_false()  # max unknown: never a big hit


func test_flash_frames_are_two_normally_four_for_a_big_hit() -> void:
	assert_int(HeroFeedback.flash_frames(false)).is_equal(2)
	assert_int(HeroFeedback.flash_frames(true)).is_equal(4)


func test_flash_restarts_are_gated_to_one_per_334ms() -> void:
	var fb := HeroFeedback.new()
	auto_free(fb)
	assert_bool(fb.can_restart_flash(1000)).is_true()
	assert_bool(fb.can_restart_flash(1100)).is_false()
	assert_bool(fb.can_restart_flash(1300)).is_false()
	assert_bool(fb.can_restart_flash(1334)).is_true()


func test_a_hit_flashes_the_sprite_and_spawns_particles_toward_the_source() -> void:
	_fb._on_health_changed(200.0, 200.0)
	_fb._on_incoming_damage(_event(7))
	_fb._on_damage_taken(10, 0)
	var mat: ShaderMaterial = _sprite.material as ShaderMaterial
	assert_object(mat).is_not_null()
	assert_float(float(mat.get_shader_parameter("flash_amount"))).is_greater(0.0)
	var bursts: Array = _hero_parent.get_children().filter(func(n: Node) -> bool: return n is CPUParticles2D)
	assert_int(bursts.size()).is_equal(1)
	var p: CPUParticles2D = bursts[0] as CPUParticles2D
	assert_bool(p.emitting).is_true()
	assert_bool(p.one_shot).is_true()
	assert_vector(p.direction).is_equal_approx(Vector2.RIGHT, Vector2(0.01, 0.01))  # source is at +x


func test_a_hit_with_an_unknown_source_still_flashes_and_bursts_without_direction() -> void:
	_fb._on_health_changed(200.0, 200.0)
	_fb._on_incoming_damage(_event(999))  # provider returns Vector2.INF for this id
	_fb._on_damage_taken(10, 0)
	var bursts: Array = _hero_parent.get_children().filter(func(n: Node) -> bool: return n is CPUParticles2D)
	assert_int(bursts.size()).is_equal(1)
	assert_float((bursts[0] as CPUParticles2D).spread).is_equal(180.0)
	assert_float(float((_sprite.material as ShaderMaterial).get_shader_parameter("flash_amount"))).is_greater(0.0)


func test_flinch_moves_the_sprite_away_from_the_source_then_returns_it() -> void:
	_fb._on_incoming_damage(_event(7))
	_fb._on_damage_taken(10, 0)
	# Deterministic stepping: headless frame deltas can exceed the whole 3-frame flinch, so a
	# frame/timer sample could miss the peak. Pause the real tween and step it manually.
	var tween: Tween = _fb._flinch_tween
	assert_object(tween).is_not_null()
	tween.pause()
	tween.custom_step(HeroFeedback.FRAME_SECONDS * float(HeroFeedback.FLINCH_FRAMES) * 0.5)
	assert_float(_sprite.position.x).is_less(_rest.x)  # source at +x, so recoil is toward -x
	tween.custom_step(HeroFeedback.FRAME_SECONDS * float(HeroFeedback.FLINCH_FRAMES))
	assert_vector(_sprite.position).is_equal_approx(_rest, Vector2(0.01, 0.01))


func test_a_big_hit_shakes_the_camera_offset_and_it_settles_to_zero() -> void:
	_fb._on_health_changed(200.0, 200.0)
	_fb._on_damage_taken(60, 0)  # 30% of max
	# Deterministic stepping (headless frame deltas can swallow the whole 7-frame shake): pause the
	# real tween and step it manually, sampling after each of the first three frames.
	var tween: Tween = _fb._shake_tween
	assert_object(tween).is_not_null()
	tween.pause()
	var moved: bool = false
	for i in range(3):
		tween.custom_step(HeroFeedback.FRAME_SECONDS)
		if _camera.offset != Vector2.ZERO:
			moved = true
	assert_bool(moved).is_true()
	tween.custom_step(1.0)
	assert_vector(_camera.offset).is_equal(Vector2.ZERO)


func test_a_big_hit_does_not_shake_under_reduced_motion() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, true)
	_fb._on_health_changed(200.0, 200.0)
	_fb._on_damage_taken(60, 0)
	assert_object(_fb._shake_tween).is_null()
	for i in range(5):
		await get_tree().process_frame
		assert_vector(_camera.offset).is_equal(Vector2.ZERO)


func test_a_normal_hit_does_not_shake() -> void:
	_fb._on_health_changed(200.0, 200.0)
	_fb._on_damage_taken(50, 0)  # exactly 25%: not a big hit
	assert_object(_fb._shake_tween).is_null()
	for i in range(5):
		await get_tree().process_frame
		assert_vector(_camera.offset).is_equal(Vector2.ZERO)


func test_signals_are_disconnected_on_exit() -> void:
	remove_child(_fb)
	assert_bool(GEventBus.hero_damage_taken.is_connected(_fb._on_damage_taken)).is_false()
	assert_bool(GEventBus.hero_incoming_damage.is_connected(_fb._on_incoming_damage)).is_false()
	assert_bool(GEventBus.hero_health_changed.is_connected(_fb._on_health_changed)).is_false()
	add_child(_fb)  # after_test frees it through the normal path
