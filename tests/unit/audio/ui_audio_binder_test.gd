extends GdUnitTestSuite

## UiAudioBinder unit tests (UI audio cues spec §3-§5).

var played: Array[StringName] = []
var _binder: UiAudioBinder


func before_test() -> void:
	played.clear()


func after_test() -> void:
	if _binder != null and is_instance_valid(_binder):
		_binder.free()
	_binder = null


func _record(cue: StringName) -> void:
	played.append(cue)


func _make_binder() -> UiAudioBinder:
	_binder = UiAudioBinder.new()
	add_child(_binder)
	_binder.setup(_record, get_tree())
	return _binder


func _button(kind: Variant = null) -> Button:
	var b: Button = Button.new()
	if kind != null:
		b.set_meta(UiAudioBinder.META_KEY, kind)
	return b


func _mouse(button_index: MouseButton, pressed: bool) -> InputEventMouseButton:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = button_index
	e.pressed = pressed
	return e


func test_cue_for_mapping() -> void:
	assert_str(String(UiAudioBinder.cue_for(&"confirm"))).is_equal("ui_confirm")
	assert_str(String(UiAudioBinder.cue_for(&"cancel"))).is_equal("ui_cancel")
	assert_str(String(UiAudioBinder.cue_for(&"none"))).is_equal("")
	assert_str(String(UiAudioBinder.cue_for(null))).is_equal("ui_click")
	assert_str(String(UiAudioBinder.cue_for(&"bogus"))).is_equal("ui_click")


func test_button_added_after_setup_is_hooked() -> void:
	_make_binder()
	var b: Button = auto_free(_button())
	add_child(b)
	assert_int(_binder.hooked_count()).is_equal(1)
	b.pressed.emit()
	assert_array(played).is_equal([&"ui_click"])


func test_button_existing_before_setup_is_hooked() -> void:
	var b: Button = auto_free(_button())
	add_child(b)
	_make_binder()
	assert_bool(b.has_meta(&"_ui_audio_hooked")).is_true()
	b.pressed.emit()
	assert_array(played).is_equal([&"ui_click"])


func test_meta_kinds() -> void:
	_make_binder()
	var c: Button = auto_free(_button(&"confirm"))
	var x: Button = auto_free(_button(&"cancel"))
	var n: Button = auto_free(_button(&"none"))
	add_child(c)
	add_child(x)
	add_child(n)
	c.pressed.emit()
	x.pressed.emit()
	n.pressed.emit()
	assert_array(played).is_equal([&"ui_confirm", &"ui_cancel"])


func test_disabled_left_press_denies_once() -> void:
	_make_binder()
	var b: Button = auto_free(_button())
	add_child(b)
	b.disabled = true
	_binder._on_gui_input(_mouse(MOUSE_BUTTON_LEFT, true), b)
	assert_array(played).is_equal([&"ui_denied"])


func test_enabled_no_denial() -> void:
	_make_binder()
	var b: Button = auto_free(_button())
	add_child(b)
	_binder._on_gui_input(_mouse(MOUSE_BUTTON_LEFT, true), b)
	assert_array(played).is_empty()


func test_disabled_right_click_and_release_no_denial() -> void:
	_make_binder()
	var b: Button = auto_free(_button())
	add_child(b)
	b.disabled = true
	_binder._on_gui_input(_mouse(MOUSE_BUTTON_RIGHT, true), b)
	_binder._on_gui_input(_mouse(MOUSE_BUTTON_LEFT, false), b)
	assert_array(played).is_empty()


func test_double_hook_is_idempotent() -> void:
	_make_binder()
	var b: Button = auto_free(_button())
	add_child(b)
	var before: int = _binder.hooked_count()
	_binder._hook(b)
	assert_int(_binder.hooked_count()).is_equal(before)
	b.pressed.emit()
	assert_int(played.size()).is_equal(1)


func test_freed_binder_stops_playing_without_errors() -> void:
	_make_binder()
	var b: Button = auto_free(_button())
	add_child(b)
	_binder.free()
	b.pressed.emit()
	b.gui_input.emit(_mouse(MOUSE_BUTTON_LEFT, true))
	assert_array(played).is_empty()
	assert_bool(b.has_meta(&"_ui_audio_hooked")).is_false()


func test_readd_after_exit_rehooks() -> void:
	_make_binder()
	var b: Button = auto_free(_button())
	add_child(b)
	remove_child(_binder)
	b.pressed.emit()
	assert_array(played).is_empty()
	# Re-adding and re-setup rehooks (hooked flag cleared on exit).
	add_child(_binder)
	_binder.setup(_record, get_tree())
	b.pressed.emit()
	assert_array(played).is_equal([&"ui_click"])


func test_freed_button_then_new_buttons_is_safe() -> void:
	_make_binder()
	var b: Button = _button()
	add_child(b)
	b.free()
	var b2: Button = auto_free(_button())
	add_child(b2)
	b2.pressed.emit()
	assert_array(played).is_equal([&"ui_click"])


func test_checkbox_and_texturebutton_hooked() -> void:
	_make_binder()
	var cb: CheckBox = auto_free(CheckBox.new())
	var tb: TextureButton = auto_free(TextureButton.new())
	add_child(cb)
	add_child(tb)
	cb.pressed.emit()
	tb.pressed.emit()
	assert_array(played).is_equal([&"ui_click", &"ui_click"])


func test_real_gui_input_connection_denies_once() -> void:
	_make_binder()
	var b: Button = auto_free(_button())
	add_child(b)
	b.disabled = true
	b.gui_input.emit(_mouse(MOUSE_BUTTON_LEFT, true))
	assert_array(played).is_equal([&"ui_denied"])
	played.clear()
	_binder._hook(b)
	b.gui_input.emit(_mouse(MOUSE_BUTTON_LEFT, true))
	assert_array(played).is_equal([&"ui_denied"])


func test_prune_drops_freed_buttons() -> void:
	_make_binder()
	var live: Button = auto_free(_button())
	add_child(live)
	var doomed: Array[Button] = []
	for i in 100:
		var b: Button = _button()
		add_child(b)
		doomed.append(b)
	for b: Button in doomed:
		b.free()
	_binder._prune()
	assert_int(_binder.hooked_count()).is_equal(1)


func test_hook_growth_is_bounded_automatically() -> void:
	_make_binder()
	for i in 300:
		var b: Button = _button()
		add_child(b)
		b.free()
	assert_int(_binder.hooked_count()).is_less_equal(UiAudioBinder.PRUNE_INTERVAL + 1)


func test_binder_freed_outside_tree_cleans_up() -> void:
	var b: Button = auto_free(_button())
	add_child(b)
	_binder = UiAudioBinder.new()
	_binder.setup(_record, get_tree())
	assert_bool(b.has_meta(&"_ui_audio_hooked")).is_true()
	_binder.free()
	assert_bool(b.has_meta(&"_ui_audio_hooked")).is_false()
	b.pressed.emit()
	assert_array(played).is_empty()
