## Integration tests for MainMenu (src/scenes/main_menu.gd) — the game's real
## boot scene, added 2026-08-01. Covers the 3 wired buttons (PLAY, SETTINGS,
## QUIT), the Settings panel's 4 real volume sliders, and its Back button.
## UPGRADES/ACHIEVEMENTS/ENCYCLOPEDIA from the source art are deliberately
## not built at all (see main_menu.gd's own doc comment) — nothing to test
## for buttons that don't exist.
##
## Uses GSceneManager's established `_inject()` stub-scene test seam
## (matching exit-mission-select_test.gd/loadout-handoff_test.gd's identical
## pattern) so PLAY's real transition_to_sanctuary() call doesn't swap in the
## actual, heavy SanctuaryScene.tscn during a test run.
##
## Volume slider tests restore GAudioSystem's real bus state in after_test()
## — this screen writes through the real Autoload's authoritative percent
## state (GAudioSystem is the single owner, not test-injectable per its own
## design), so a test that changes a slider's value has a real, persistent
## side effect on the live Autoload unless explicitly reverted.
extends GdUnitTestSuite

const STUB_SCENE_PATH: String = "res://tests/fixtures/scene_manager/StubScene.tscn"
const VOLUME_BUSES: Array[StringName] = [&"Music", &"SFX", &"Voice", &"UI"]

var _original_mission_path: String
var _original_sanctuary_path: String
var _original_tarot_deck_path: String
var _original_current_scene: Node
var _original_bus_volumes: Dictionary[StringName, float] = {}

var _runner: GdUnitSceneRunner
var _menu: Control


func before_test() -> void:
	_original_mission_path = GSceneManager._mission_scene_path
	_original_sanctuary_path = GSceneManager._sanctuary_scene_path
	_original_tarot_deck_path = GSceneManager._tarot_deck_scene_path
	GSceneManager._inject(STUB_SCENE_PATH, STUB_SCENE_PATH, STUB_SCENE_PATH)
	_original_current_scene = get_tree().current_scene

	for bus_name: StringName in VOLUME_BUSES:
		_original_bus_volumes[bus_name] = GAudioSystem.get_bus_volume_percent(bus_name)

	_runner = scene_runner("res://src/scenes/MainMenu.tscn")
	_menu = _runner.scene() as Control


func after_test() -> void:
	if GSceneManager._transition_in_progress:
		await GEventBus.scene_transition_completed
	GSceneManager._inject(_original_mission_path, _original_sanctuary_path, _original_tarot_deck_path)
	GSceneManager._transition_in_progress = false
	if is_instance_valid(_original_current_scene):
		get_tree().current_scene = _original_current_scene

	for bus_name: StringName in VOLUME_BUSES:
		GAudioSystem.set_bus_volume_percent(bus_name, _original_bus_volumes[bus_name])
	GAudioSystem.save_settings_to_disk()


func _slider(bus_name: StringName) -> HSlider:
	var row_name: String = String(bus_name).substr(0, 1) + String(bus_name).substr(1).to_lower() + "Row"
	return _menu.get_node("SettingsPanel/VolumeSliders/%s/Slider" % row_name)


func _value_label(bus_name: StringName) -> Label:
	var row_name: String = String(bus_name).substr(0, 1) + String(bus_name).substr(1).to_lower() + "Row"
	return _menu.get_node("SettingsPanel/VolumeSliders/%s/ValueLabel" % row_name)


func test_settings_panel_is_hidden_at_fresh_mount() -> void:
	var panel: Control = _menu.get_node("SettingsPanel") as Control
	assert_bool(panel.visible).is_false()


func test_settings_button_shows_the_panel() -> void:
	_menu.get_node("Buttons/SettingsButton").pressed.emit()

	var panel: Control = _menu.get_node("SettingsPanel") as Control
	assert_bool(panel.visible).is_true()


func test_settings_back_button_hides_the_panel_again() -> void:
	_menu.get_node("Buttons/SettingsButton").pressed.emit()
	_menu.get_node("SettingsPanel/BackButton").pressed.emit()

	var panel: Control = _menu.get_node("SettingsPanel") as Control
	assert_bool(panel.visible).is_false()


func test_play_button_transitions_to_sanctuary() -> void:
	var received: Array = []
	var handler := func(target: String, mission_id: String) -> void:
		received.append([target, mission_id])
	GEventBus.scene_transition_completed.connect(handler)

	_menu.get_node("Buttons/PlayButton").pressed.emit()
	await GEventBus.scene_transition_completed

	assert_array(received).contains([["SANCTUARY", ""]])
	GEventBus.scene_transition_completed.disconnect(handler)


# ---------------------------------------------------------------------------
# Volume sliders (2026-08-01) — real GAudioSystem.set/get_bus_volume_percent()
# wiring, per audio-system.md Core Rule 1 / accessibility-requirements.md's
# Basic-tier "independent volume controls" commitment. No new audio logic
# here — GAudioSystem already implemented the percent<->dB/persistence
# mechanism; this is pure UI wiring.
# ---------------------------------------------------------------------------

## _ready() reads GAudioSystem's state once, at mount time -- so this test
## sets the state and mounts a fresh scene instance afterward, rather than
## reusing before_test()'s _menu (which already mounted, and therefore
## already read the pre-test value, before this test body could run).
func test_sliders_are_initialized_from_real_audio_system_state() -> void:
	GAudioSystem.set_bus_volume_percent(&"SFX", 37.0)
	var fresh_runner: GdUnitSceneRunner = scene_runner("res://src/scenes/MainMenu.tscn")
	var fresh_menu: Control = fresh_runner.scene() as Control
	fresh_menu.get_node("Buttons/SettingsButton").pressed.emit()

	var row_name: String = "SfxRow"
	var slider: HSlider = fresh_menu.get_node("SettingsPanel/VolumeSliders/%s/Slider" % row_name)
	var value_label: Label = fresh_menu.get_node("SettingsPanel/VolumeSliders/%s/ValueLabel" % row_name)
	assert_float(slider.value).is_equal(37.0)
	assert_str(value_label.text).is_equal("37%")


func test_dragging_a_slider_writes_through_to_audio_system() -> void:
	_menu.get_node("Buttons/SettingsButton").pressed.emit()

	_slider(&"Music").value = 62.0

	assert_float(GAudioSystem.get_bus_volume_percent(&"Music")).is_equal(62.0)
	assert_str(_value_label(&"Music").text).is_equal("62%")


func test_dragging_a_slider_persists_to_disk() -> void:
	_menu.get_node("Buttons/SettingsButton").pressed.emit()

	_slider(&"UI").value = 15.0

	var config := ConfigFile.new()
	var err: Error = config.load(GAudioSystem.AUDIO_SETTINGS_PATH)
	assert_int(err).is_equal(OK)
	assert_float(config.get_value(GAudioSystem.AUDIO_SETTINGS_SECTION, &"UI", -1.0)).is_equal(15.0)


# ---------------------------------------------------------------------------
# Gamepad focus rings (ADR-0011 — UI Dual-Focus Handling), added 2026-08-01
# ---------------------------------------------------------------------------

func test_play_button_has_initial_focus_on_mount() -> void:
	var play_button: TextureButton = _menu.get_node("Buttons/PlayButton")
	assert_bool(play_button.has_focus()).is_true()


func test_focused_button_shows_a_ring_in_keyboard_gamepad_mode() -> void:
	var play_button: TextureButton = _menu.get_node("Buttons/PlayButton")
	var rings: Dictionary = _menu.get("_focus_rings")
	assert_bool((rings[play_button] as Panel).visible).is_true()  # default mode is KEYBOARD_GAMEPAD


func test_mouse_motion_hides_the_focus_ring() -> void:
	var input_mode_tracker: InputModeTracker = _menu.get_node("InputModeTracker")
	input_mode_tracker._input(InputEventMouseMotion.new())

	var play_button: TextureButton = _menu.get_node("Buttons/PlayButton")
	var rings: Dictionary = _menu.get("_focus_rings")
	assert_bool((rings[play_button] as Panel).visible).is_false()


func test_settings_button_pressed_moves_focus_and_ring_to_the_first_slider() -> void:
	_menu.get_node("Buttons/SettingsButton").pressed.emit()

	var music_slider: HSlider = _slider(&"Music")
	var rings: Dictionary = _menu.get("_focus_rings")
	assert_bool(music_slider.has_focus()).is_true()
	assert_bool((rings[music_slider] as Panel).visible).is_true()


func test_back_button_pressed_returns_focus_and_ring_to_the_settings_button() -> void:
	_menu.get_node("Buttons/SettingsButton").pressed.emit()
	_menu.get_node("SettingsPanel/BackButton").pressed.emit()

	var settings_button: TextureButton = _menu.get_node("Buttons/SettingsButton")
	var rings: Dictionary = _menu.get("_focus_rings")
	assert_bool(settings_button.has_focus()).is_true()
	assert_bool((rings[settings_button] as Panel).visible).is_true()


## Real bug found and fixed 2026-08-01: the Settings panel previously didn't
## trap Tab-focus -- Godot's automatic Tab traversal has no concept of
## "modal," so pressing Tab while the panel was open could cycle focus back
## onto the underlying PLAY/SETTINGS/QUIT buttons (visually covered, but not
## focus-excluded). Fixed by setting those 3 to FOCUS_NONE for the duration
## the panel is open.
func test_underlying_buttons_are_not_focusable_while_settings_is_open() -> void:
	_menu.get_node("Buttons/SettingsButton").pressed.emit()

	var play_button: TextureButton = _menu.get_node("Buttons/PlayButton")
	var settings_button: TextureButton = _menu.get_node("Buttons/SettingsButton")
	var quit_button: TextureButton = _menu.get_node("Buttons/QuitButton")
	assert_int(play_button.focus_mode).is_equal(Control.FOCUS_NONE)
	assert_int(settings_button.focus_mode).is_equal(Control.FOCUS_NONE)
	assert_int(quit_button.focus_mode).is_equal(Control.FOCUS_NONE)


func test_underlying_buttons_are_focusable_again_after_closing_settings() -> void:
	_menu.get_node("Buttons/SettingsButton").pressed.emit()
	_menu.get_node("SettingsPanel/BackButton").pressed.emit()

	var play_button: TextureButton = _menu.get_node("Buttons/PlayButton")
	var settings_button: TextureButton = _menu.get_node("Buttons/SettingsButton")
	var quit_button: TextureButton = _menu.get_node("Buttons/QuitButton")
	assert_int(play_button.focus_mode).is_equal(Control.FOCUS_ALL)
	assert_int(settings_button.focus_mode).is_equal(Control.FOCUS_ALL)
	assert_int(quit_button.focus_mode).is_equal(Control.FOCUS_ALL)


## The direct behavioral proof, not just the focus_mode implementation
## detail above -- simulates real Tab presses while the panel is open and
## confirms focus stays within the panel's own 5 Controls (4 sliders +
## Back), never escaping to a covered button underneath.
func test_tab_presses_while_settings_open_stay_within_the_panel() -> void:
	_menu.get_node("Buttons/SettingsButton").pressed.emit()

	var panel_controls: Array = [
		_slider(&"Music"), _slider(&"SFX"), _slider(&"Voice"), _slider(&"UI"),
		_menu.get_node("SettingsPanel/BackButton"),
	]

	for i in range(5):
		await _runner.simulate_key_pressed(KEY_TAB)
		var focus_owner: Control = _menu.get_viewport().gui_get_focus_owner()
		assert_array(panel_controls).contains([focus_owner])
