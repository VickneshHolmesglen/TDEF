## Hero walk motion (2026-10-07): procedural footstep bob, sway and footfall
## squash while the Hero moves; faces the move direction; idle breathing pauses
## while walking and resumes on stopping; reduce-motion keeps only the facing flip.
extends GdUnitTestSuite

const REST_SCALE: Vector2 = Vector2(0.052083, 0.052083)

var _hero_parent: Node2D
var _hero: CharacterBody2D
var _sprite: Sprite2D
var _camera: Camera2D
var _fb: HeroFeedback


func before_test() -> void:
	_hero_parent = Node2D.new()
	add_child(_hero_parent)
	_hero = CharacterBody2D.new()
	_hero_parent.add_child(_hero)
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_sprite.scale = REST_SCALE
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


func _walk(velocity: Vector2, seconds: float) -> void:
	_hero.velocity = velocity
	_fb.advance(seconds)


func test_moving_starts_the_walk_and_pauses_idle_breathing() -> void:
	_walk(Vector2(120, 0), 0.05)
	assert_bool(_fb.is_walking()).is_true()
	assert_bool(_fb.is_idle_playing()).is_false()


func test_the_walk_bobs_and_sways_within_budget() -> void:
	_walk(Vector2(120, 0), 0.05)
	_walk(Vector2(120, 0), 0.1)  # mid-stride
	var bob_px: float = -_sprite.offset.y * REST_SCALE.y
	assert_float(bob_px).is_greater(0.0)
	assert_float(bob_px).is_less_equal(HeroFeedback.WALK_BOB_PIXELS + 0.001)
	assert_float(absf(_sprite.rotation)).is_less_equal(HeroFeedback.WALK_SWAY_RADIANS + 0.0001)
	assert_vector(_sprite.position).is_equal(Vector2.ZERO)  # flinch's channel is untouched


func test_stopping_restores_the_rest_pose_and_restarts_idle() -> void:
	_walk(Vector2(120, 0), 0.1)
	_walk(Vector2.ZERO, 0.05)
	assert_bool(_fb.is_walking()).is_false()
	assert_vector(_sprite.offset).is_equal(Vector2.ZERO)
	assert_float(_sprite.rotation).is_equal(0.0)
	assert_bool(_fb.is_idle_playing()).is_true()


func test_the_hero_faces_the_direction_of_travel() -> void:
	_walk(Vector2(-120, 0), 0.05)
	assert_bool(_sprite.flip_h).is_true()
	_walk(Vector2(120, 0), 0.05)
	assert_bool(_sprite.flip_h).is_false()
	_walk(Vector2(0, 120), 0.05)  # straight down keeps the last facing
	assert_bool(_sprite.flip_h).is_false()


func test_reduce_motion_keeps_only_the_facing_flip() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, true)
	_walk(Vector2(-120, 0), 0.1)
	assert_bool(_sprite.flip_h).is_true()
	assert_vector(_sprite.offset).is_equal(Vector2.ZERO)
	assert_float(_sprite.rotation).is_equal(0.0)


func test_death_mid_stride_resets_the_walk_pose() -> void:
	_walk(Vector2(120, 0), 0.1)
	_fb._on_hero_died()
	assert_bool(_fb.is_walking()).is_false()
	assert_vector(_sprite.offset).is_equal(Vector2.ZERO)
	assert_float(_sprite.rotation).is_equal(0.0)
