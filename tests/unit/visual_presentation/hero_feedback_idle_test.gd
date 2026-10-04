## Hero idle breathing (hero-visual-profile.md §5; 2026-10-04 smoke check found the
## spec unimplemented and the Hero sprite fully static). Covers the lifecycle:
## starts on mount, stops on death restoring the exact rest pose, restarts on a
## relaunch, and is skipped entirely when reduce-motion is on.
extends GdUnitTestSuite

const REST_SCALE: Vector2 = Vector2(0.052083, 0.052083)

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
	_sprite.scale = REST_SCALE
	_hero.add_child(_sprite)
	_camera = Camera2D.new()
	_hero_parent.add_child(_camera)
	_fb = HeroFeedback.new()
	_fb.setup(_hero, _camera, func(_id: int) -> Vector2: return Vector2.INF)


func after_test() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, null)
	if is_instance_valid(_fb):
		_fb.free()
	_hero_parent.free()


func test_idle_starts_when_mounted() -> void:
	add_child(_fb)
	assert_bool(_fb.is_idle_playing()).is_true()


func test_idle_cycle_stays_within_the_movement_budget() -> void:
	# A 1.2% breath on scale.y plus a small skew -- never a position change.
	assert_float(HeroFeedback.IDLE_BREATH_FRACTION).is_less_equal(0.02)
	var cycle: float = HeroFeedback.IDLE_INHALE_SECONDS + HeroFeedback.IDLE_EXHALE_SECONDS \
		+ HeroFeedback.IDLE_SHIFT_SECONDS + HeroFeedback.IDLE_HOLD_SECONDS
	assert_float(cycle).is_between(3.0, 4.0)


func test_death_stops_idle_and_restores_rest_pose() -> void:
	add_child(_fb)
	_sprite.scale = REST_SCALE * 1.01
	_sprite.skew = 0.02
	_fb._on_hero_died()
	assert_bool(_fb.is_idle_playing()).is_false()
	assert_vector(_sprite.scale).is_equal_approx(REST_SCALE, Vector2(0.00001, 0.00001))
	assert_float(_sprite.skew).is_equal(0.0)


func test_relaunch_restarts_idle_after_death() -> void:
	add_child(_fb)
	_fb._on_hero_died()
	_fb._on_mission_launched("the_gap", PackedStringArray(), 1)
	assert_bool(_fb.is_idle_playing()).is_true()


func test_reduce_motion_disables_idle() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, true)
	add_child(_fb)
	assert_bool(_fb.is_idle_playing()).is_false()
	assert_vector(_sprite.scale).is_equal(REST_SCALE)
