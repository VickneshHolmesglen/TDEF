## Integration tests for MainMenu (src/scenes/main_menu.gd) — the game's real
## boot scene, added 2026-08-01. Covers Continue/New Game/Load Game, the
## Settings panel's 4 real volume sliders, and Quit. UPGRADES/ACHIEVEMENTS/
## ENCYCLOPEDIA from the source art are deliberately not built at all (see
## main_menu.gd's own doc comment) — nothing to test for buttons that don't
## exist.
##
## Uses GSceneManager's established `_inject()` stub-scene test seam
## (matching exit-mission-select_test.gd/loadout-handoff_test.gd's identical
## pattern) so a real transition_to_sanctuary() call doesn't swap in the
## actual, heavy SanctuaryScene.tscn during a test run.
##
## Volume slider tests restore GAudioSystem's real bus state in after_test()
## — this screen writes through the real Autoload's authoritative percent
## state (GAudioSystem is the single owner, not test-injectable per its own
## design), so a test that changes a slider's value has a real, persistent
## side effect on the live Autoload unless explicitly reverted.
##
## Continue/New Game/Load Game tests are DELIBERATELY adaptive to whatever
## real save state exists on the machine running the tests, rather than
## assuming a fixture state — `main_menu.gd`'s own slot logic is hardcoded
## to the real, production save-slot range (0-2, matching `save-
## persistence.md`), not redirectable to disposable high-numbered test
## slots the way `save_persistence_write_test.gd`'s own convention uses.
## None of this screen's code paths actually WRITE a save file (`load_slot()`
## only reads; `set_active_slot()` is in-memory only), so this is safe — no
## snapshot/restore of real save data is needed.
extends GdUnitTestSuite

const STUB_SCENE_PATH: String = "res://tests/fixtures/scene_manager/StubScene.tscn"
const VOLUME_BUSES: Array[StringName] = [&"Music", &"SFX", &"Voice", &"UI"]
const SAVE_SLOT_COUNT: int = 3

var _original_mission_path: String
var _original_sanctuary_path: String
var _original_tarot_deck_path: String
var _original_current_scene: Node
var _original_bus_volumes: Dictionary[StringName, float] = {}
var _original_active_slot: int

var _runner: GdUnitSceneRunner
var _menu: Control


func before_test() -> void:
	_original_mission_path = GSceneManager._mission_scene_path
	_original_sanctuary_path = GSceneManager._sanctuary_scene_path
	_original_tarot_deck_path = GSceneManager._tarot_deck_scene_path
	GSceneManager._inject(STUB_SCENE_PATH, STUB_SCENE_PATH, STUB_SCENE_PATH)
	_original_current_scene = get_tree().current_scene
	_original_active_slot = GSavePersistence._active_slot

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
	GSavePersistence._active_slot = _original_active_slot

	for bus_name: StringName in VOLUME_BUSES:
		GAudioSystem.set_bus_volume_percent(bus_name, _original_bus_volumes[bus_name])
	GAudioSystem.save_settings_to_disk()


func _slider(bus_name: StringName) -> HSlider:
	var row_name: String = String(bus_name).substr(0, 1) + String(bus_name).substr(1).to_lower() + "Row"
	return _menu.get_node("SettingsPanel/VolumeSliders/%s/Slider" % row_name)


func _value_label(bus_name: StringName) -> Label:
	var row_name: String = String(bus_name).substr(0, 1) + String(bus_name).substr(1).to_lower() + "Row"
	return _menu.get_node("SettingsPanel/VolumeSliders/%s/ValueLabel" % row_name)


func _slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(SavePersistence.SAVE_PATH % slot)


func _any_save_exists() -> bool:
	for slot: int in range(SAVE_SLOT_COUNT):
		if _slot_exists(slot):
			return true
	return false


func _first_empty_slot() -> int:
	for slot: int in range(SAVE_SLOT_COUNT):
		if not _slot_exists(slot):
			return slot
	return -1


func test_all_modal_panels_are_hidden_at_fresh_mount() -> void:
	assert_bool((_menu.get_node("SettingsPanel") as Control).visible).is_false()
	assert_bool((_menu.get_node("LoadGamePanel") as Control).visible).is_false()
	assert_bool((_menu.get_node("OverwriteConfirmPanel") as Control).visible).is_false()


# ---------------------------------------------------------------------------
# Continue / New Game / Load Game (2026-08-01, design/ux/main-menu.md)
# ---------------------------------------------------------------------------

func test_continue_and_load_game_visibility_matches_real_save_state() -> void:
	var has_save: bool = _any_save_exists()
	var continue_button: Button = _menu.get_node("Buttons/ContinueButton")
	var load_game_button: Button = _menu.get_node("Buttons/LoadGameButton")
	assert_bool(continue_button.visible).is_equal(has_save)
	assert_bool(load_game_button.visible).is_equal(has_save)


func test_new_game_button_is_always_visible() -> void:
	var new_game_button: Button = _menu.get_node("Buttons/NewGameButton")
	assert_bool(new_game_button.visible).is_true()


func test_initial_focus_is_continue_if_a_save_exists_else_new_game() -> void:
	var expected: Button = _menu.get_node("Buttons/ContinueButton") if _any_save_exists() \
			else _menu.get_node("Buttons/NewGameButton")
	assert_bool(expected.has_focus()).is_true()


## New Game with an empty slot available transitions silently -- no
## Overwrite Confirmation, per design/ux/main-menu.md's Interaction Map
## ("else -> transitions directly to Sanctuary").
func test_new_game_with_an_empty_slot_transitions_without_confirmation() -> void:
	if _first_empty_slot() == -1:
		# Only meaningful when this test machine actually has an empty slot
		# to target -- adaptive, not a hardcoded fixture (see class comment).
		return

	var received: Array = []
	var handler := func(target: String, mission_id: String) -> void:
		received.append([target, mission_id])
	GEventBus.scene_transition_completed.connect(handler)

	_menu.get_node("Buttons/NewGameButton").pressed.emit()
	await GEventBus.scene_transition_completed

	assert_array(received).contains([["SANCTUARY", ""]])
	assert_bool((_menu.get_node("OverwriteConfirmPanel") as Control).visible).is_false()
	GEventBus.scene_transition_completed.disconnect(handler)


func test_continue_loads_the_most_recently_modified_occupied_slot() -> void:
	if not _any_save_exists():
		return  # adaptive -- Continue is hidden and unfocusable with no save

	var expected_slot: int = -1
	var best_time: int = -1
	for slot: int in range(SAVE_SLOT_COUNT):
		if not _slot_exists(slot):
			continue
		var modified_time: int = FileAccess.get_modified_time(SavePersistence.SAVE_PATH % slot)
		if modified_time > best_time:
			best_time = modified_time
			expected_slot = slot

	var received: Array = []
	var handler := func(target: String, mission_id: String) -> void:
		received.append([target, mission_id])
	GEventBus.scene_transition_completed.connect(handler)

	_menu.get_node("Buttons/ContinueButton").pressed.emit()
	await GEventBus.scene_transition_completed

	assert_int(GSavePersistence._active_slot).is_equal(expected_slot)
	GEventBus.scene_transition_completed.disconnect(handler)


func test_load_game_button_shows_the_panel_with_correct_slot_states() -> void:
	_menu.get_node("Buttons/LoadGameButton").pressed.emit()

	assert_bool((_menu.get_node("LoadGamePanel") as Control).visible).is_true()
	for slot: int in range(SAVE_SLOT_COUNT):
		var slot_button: Button = _menu.get_node("LoadGamePanel/Slots/Slot%dButton" % slot)
		var exists: bool = _slot_exists(slot)
		assert_bool(slot_button.disabled).is_equal(not exists)
		assert_str(slot_button.text).contains("Occupied" if exists else "Empty")


func test_load_game_back_button_hides_the_panel_and_returns_focus() -> void:
	_menu.get_node("Buttons/LoadGameButton").pressed.emit()
	_menu.get_node("LoadGamePanel/BackButton").pressed.emit()

	assert_bool((_menu.get_node("LoadGamePanel") as Control).visible).is_false()
	assert_bool((_menu.get_node("Buttons/LoadGameButton") as Button).has_focus()).is_true()


func test_clicking_an_occupied_slot_loads_it_and_transitions() -> void:
	if not _any_save_exists():
		return

	var occupied_slot: int = -1
	for slot: int in range(SAVE_SLOT_COUNT):
		if _slot_exists(slot):
			occupied_slot = slot
			break

	var received: Array = []
	var handler := func(target: String, mission_id: String) -> void:
		received.append([target, mission_id])
	GEventBus.scene_transition_completed.connect(handler)

	_menu.get_node("Buttons/LoadGameButton").pressed.emit()
	_menu.get_node("LoadGamePanel/Slots/Slot%dButton" % occupied_slot).pressed.emit()
	await GEventBus.scene_transition_completed

	assert_int(GSavePersistence._active_slot).is_equal(occupied_slot)
	GEventBus.scene_transition_completed.disconnect(handler)


## Overwrite Confirmation only triggers when all 3 slots are occupied — not
## reproducible without writing real save data (out of scope; this screen's
## own logic never writes files, see class comment), so this test instead
## verifies the modal's own Yes/Cancel mechanics directly, bypassing the
## New-Game-button entry path.
func test_overwrite_confirm_yes_sets_active_slot_and_transitions() -> void:
	var received: Array = []
	var handler := func(target: String, mission_id: String) -> void:
		received.append([target, mission_id])
	GEventBus.scene_transition_completed.connect(handler)

	_menu.set("_pending_overwrite_slot", 0)
	_menu.get_node("OverwriteConfirmPanel/ConfirmButtons/YesButton").pressed.emit()
	await GEventBus.scene_transition_completed

	assert_int(GSavePersistence._active_slot).is_equal(0)
	GEventBus.scene_transition_completed.disconnect(handler)


func test_overwrite_confirm_cancel_hides_the_panel_and_returns_focus() -> void:
	_menu.get_node("OverwriteConfirmPanel").set("visible", true)
	_menu.call("_set_nav_buttons_focusable", false)

	_menu.get_node("OverwriteConfirmPanel/ConfirmButtons/CancelButton").pressed.emit()

	assert_bool((_menu.get_node("OverwriteConfirmPanel") as Control).visible).is_false()
	assert_bool((_menu.get_node("Buttons/NewGameButton") as Button).has_focus()).is_true()


# ---------------------------------------------------------------------------
# Settings — volume sliders (2026-08-01) — real
# GAudioSystem.set/get_bus_volume_percent() wiring, per audio-system.md
# Core Rule 1 / accessibility-requirements.md's Basic-tier "independent
# volume controls" commitment. No new audio logic here — GAudioSystem
# already implemented the percent<->dB/persistence mechanism; this is pure
# UI wiring.
# ---------------------------------------------------------------------------

func test_settings_button_shows_the_panel() -> void:
	_menu.get_node("Buttons/SettingsButton").pressed.emit()

	var panel: Control = _menu.get_node("SettingsPanel") as Control
	assert_bool(panel.visible).is_true()


func test_settings_back_button_hides_the_panel_again() -> void:
	_menu.get_node("Buttons/SettingsButton").pressed.emit()
	_menu.get_node("SettingsPanel/BackButton").pressed.emit()

	var panel: Control = _menu.get_node("SettingsPanel") as Control
	assert_bool(panel.visible).is_false()


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

func test_focused_button_shows_a_ring_in_keyboard_gamepad_mode() -> void:
	var primary: Button = _menu.get_node("Buttons/ContinueButton") if _any_save_exists() \
			else _menu.get_node("Buttons/NewGameButton")
	var rings: Dictionary = _menu.get("_focus_rings")
	assert_bool((rings[primary] as Panel).visible).is_true()  # default mode is KEYBOARD_GAMEPAD


func test_mouse_motion_hides_the_focus_ring() -> void:
	var input_mode_tracker: InputModeTracker = _menu.get_node("InputModeTracker")
	input_mode_tracker._input(InputEventMouseMotion.new())

	var primary: Button = _menu.get_node("Buttons/ContinueButton") if _any_save_exists() \
			else _menu.get_node("Buttons/NewGameButton")
	var rings: Dictionary = _menu.get("_focus_rings")
	assert_bool((rings[primary] as Panel).visible).is_false()


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
## onto the underlying nav buttons (visually covered, but not
## focus-excluded). Fixed by setting all nav buttons to FOCUS_NONE for the
## duration any modal panel is open.
func test_nav_buttons_are_not_focusable_while_settings_is_open() -> void:
	_menu.get_node("Buttons/SettingsButton").pressed.emit()

	for path in ["ContinueButton", "NewGameButton", "LoadGameButton", "SettingsButton", "QuitButton"]:
		var button: Control = _menu.get_node("Buttons/%s" % path)
		assert_int(button.focus_mode).is_equal(Control.FOCUS_NONE)


func test_nav_buttons_are_focusable_again_after_closing_settings() -> void:
	_menu.get_node("Buttons/SettingsButton").pressed.emit()
	_menu.get_node("SettingsPanel/BackButton").pressed.emit()

	for path in ["ContinueButton", "NewGameButton", "LoadGameButton", "SettingsButton", "QuitButton"]:
		var button: Control = _menu.get_node("Buttons/%s" % path)
		assert_int(button.focus_mode).is_equal(Control.FOCUS_ALL)


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
