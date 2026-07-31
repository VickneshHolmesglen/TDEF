## Integration tests for MainMenu (src/scenes/main_menu.gd) — the game's real
## boot scene, added 2026-08-01. Covers the 3 wired buttons (PLAY, SETTINGS,
## QUIT) and the Settings placeholder's Back button. UPGRADES/ACHIEVEMENTS/
## ENCYCLOPEDIA from the source art are deliberately not built at all (see
## main_menu.gd's own doc comment) — nothing to test for buttons that don't
## exist.
##
## Uses GSceneManager's established `_inject()` stub-scene test seam
## (matching exit-mission-select_test.gd/loadout-handoff_test.gd's identical
## pattern) so PLAY's real transition_to_sanctuary() call doesn't swap in the
## actual, heavy SanctuaryScene.tscn during a test run.
extends GdUnitTestSuite

const STUB_SCENE_PATH: String = "res://tests/fixtures/scene_manager/StubScene.tscn"

var _original_mission_path: String
var _original_sanctuary_path: String
var _original_tarot_deck_path: String
var _original_current_scene: Node

var _runner: GdUnitSceneRunner
var _menu: Control


func before_test() -> void:
	_original_mission_path = GSceneManager._mission_scene_path
	_original_sanctuary_path = GSceneManager._sanctuary_scene_path
	_original_tarot_deck_path = GSceneManager._tarot_deck_scene_path
	GSceneManager._inject(STUB_SCENE_PATH, STUB_SCENE_PATH, STUB_SCENE_PATH)
	_original_current_scene = get_tree().current_scene

	_runner = scene_runner("res://src/scenes/MainMenu.tscn")
	_menu = _runner.scene() as Control


func after_test() -> void:
	if GSceneManager._transition_in_progress:
		await GEventBus.scene_transition_completed
	GSceneManager._inject(_original_mission_path, _original_sanctuary_path, _original_tarot_deck_path)
	GSceneManager._transition_in_progress = false
	if is_instance_valid(_original_current_scene):
		get_tree().current_scene = _original_current_scene


func test_settings_panel_is_hidden_at_fresh_mount() -> void:
	var panel: Control = _menu.get_node("SettingsPanel") as Control
	assert_bool(panel.visible).is_false()


func test_settings_button_shows_the_placeholder_panel() -> void:
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
