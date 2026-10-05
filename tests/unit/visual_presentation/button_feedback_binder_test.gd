## Unit tests for ButtonFeedbackBinder (2026-10-05 UI polish pass): every Button gets a hover/focus
## scale-up and a press punch, with an opt-out meta and ReduceMotion respected.
extends GdUnitTestSuite

var _binder: ButtonFeedbackBinder
var _host: Control
var _had_setting: bool
var _original: Variant


func before_test() -> void:
	_had_setting = ProjectSettings.has_setting(ReduceMotion.SETTING_KEY)
	_original = ProjectSettings.get_setting(ReduceMotion.SETTING_KEY) if _had_setting else null
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, false)
	_host = Control.new()
	add_child(_host)
	_binder = ButtonFeedbackBinder.new()
	add_child(_binder)
	_binder.setup(get_tree())


func after_test() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, _original if _had_setting else null)
	_binder.free()
	_host.free()


func _button() -> Button:
	var button := Button.new()
	button.size = Vector2(100, 40)
	_host.add_child(button)
	return button


func test_button_feedback_new_button_is_hooked_on_entering_the_tree() -> void:
	var button: Button = _button()
	assert_bool(button.has_meta(&"_ui_feedback_hooked")).is_true()


func test_button_feedback_focus_scales_the_button_up_around_its_center() -> void:
	var button: Button = _button()
	button.focus_mode = Control.FOCUS_ALL

	button.grab_focus()
	await await_millis(200)

	assert_vector(button.scale).is_equal_approx(Vector2.ONE * ButtonFeedbackBinder.HOVER_SCALE, Vector2(0.001, 0.001))
	assert_vector(button.pivot_offset).is_equal(Vector2(50, 20))


func test_button_feedback_press_punches_below_rest_scale() -> void:
	var button: Button = _button()

	button.button_down.emit()
	await await_millis(120)

	assert_float(button.scale.x).is_less(1.0)


func test_button_feedback_opted_out_button_never_scales() -> void:
	var button: Button = _button()
	button.set_meta(ButtonFeedbackBinder.META_KEY, ButtonFeedbackBinder.KIND_NONE)

	button.button_down.emit()
	await await_millis(120)

	assert_vector(button.scale).is_equal(Vector2.ONE)


func test_button_feedback_reduce_motion_disables_scaling() -> void:
	ProjectSettings.set_setting(ReduceMotion.SETTING_KEY, true)
	var button: Button = _button()

	button.button_down.emit()
	await await_millis(120)

	assert_vector(button.scale).is_equal(Vector2.ONE)


func test_button_feedback_disabled_button_never_scales() -> void:
	var button: Button = _button()
	button.disabled = true

	button.button_down.emit()
	await await_millis(120)

	assert_vector(button.scale).is_equal(Vector2.ONE)


func test_button_feedback_wide_button_growth_is_capped_in_pixels() -> void:
	var wide: Vector2 = ButtonFeedbackBinder.rest_scale(true, Vector2(1900, 40))
	var small: Vector2 = ButtonFeedbackBinder.rest_scale(true, Vector2(100, 40))

	assert_float(wide.x * 1900.0 - 1900.0).is_less_equal(ButtonFeedbackBinder.MAX_HOVER_GROWTH_PX + 0.01)
	assert_float(small.x).is_equal_approx(ButtonFeedbackBinder.HOVER_SCALE, 0.0001)


func test_button_feedback_wide_button_press_shrink_is_capped_in_pixels() -> void:
	var wide: Vector2 = ButtonFeedbackBinder.press_scale(Vector2(1900, 40))

	assert_float(1900.0 - wide.x * 1900.0).is_less_equal(ButtonFeedbackBinder.MAX_PRESS_SHRINK_PX + 0.01)
