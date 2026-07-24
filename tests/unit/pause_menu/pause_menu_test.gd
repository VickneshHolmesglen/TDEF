## Unit tests for PauseMenu (ADR-0014). Covers the mechanism's core contract:
## SceneTree.paused as source of truth, game_paused/game_unpaused emission,
## Resume/Quit-to-Sanctuary button wiring, and PROCESS_MODE_ALWAYS.
##
## Injects the real GSceneManager with stub scene paths before exercising the
## Quit button, same pattern as tests/unit/scene_manager/scene_manager_test.gd —
## GSceneManager is a singleton Autoload and SanctuaryScene.tscn does not exist
## yet (confirmed Not Started), so an uninjected call would push_error.
extends GdUnitTestSuite

const PAUSE_MENU_SCENE: PackedScene = preload("res://src/gameplay/ui/pause_menu/pause_menu.tscn")
const STUB_SCENE_PATH: String = "res://tests/fixtures/scene_manager/StubScene.tscn"

var _pause_menu: CanvasLayer
var _spy: EventBusSpy
var _original_mission_path: String
var _original_sanctuary_path: String


func before_test() -> void:
	_original_mission_path = GSceneManager._mission_scene_path
	_original_sanctuary_path = GSceneManager._sanctuary_scene_path
	GSceneManager._inject(STUB_SCENE_PATH, STUB_SCENE_PATH)

	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	add_child(_pause_menu)

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.game_paused)
	_spy.watch(GEventBus.game_unpaused)


func after_test() -> void:
	get_tree().paused = false
	_spy.disconnect_all()
	_spy = null
	_pause_menu.queue_free()
	_pause_menu = null
	GSceneManager._inject(_original_mission_path, _original_sanctuary_path)
	GSceneManager._transition_in_progress = false

# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_pause_menu_starts_hidden_and_tree_unpaused() -> void:
	assert_bool(_pause_menu.visible).is_false()
	assert_bool(get_tree().paused).is_false()


func test_pause_menu_process_mode_is_always() -> void:
	assert_int(_pause_menu.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)

# ---------------------------------------------------------------------------
# Toggle contract — SceneTree.paused is the source of truth
# ---------------------------------------------------------------------------

func test_toggle_pause_pauses_tree_and_shows_menu() -> void:
	_pause_menu._toggle_pause()
	assert_bool(get_tree().paused).is_true()
	assert_bool(_pause_menu.visible).is_true()


func test_toggle_pause_twice_resumes_tree_and_hides_menu() -> void:
	_pause_menu._toggle_pause()
	_pause_menu._toggle_pause()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_pause_menu.visible).is_false()


func test_toggle_pause_emits_game_paused_exactly_once() -> void:
	_pause_menu._toggle_pause()
	assert_int(_spy.count("game_paused")).is_equal(1)
	assert_int(_spy.count("game_unpaused")).is_equal(0)


func test_toggle_pause_twice_emits_game_unpaused_exactly_once() -> void:
	_pause_menu._toggle_pause()
	_pause_menu._toggle_pause()
	assert_int(_spy.count("game_paused")).is_equal(1)
	assert_int(_spy.count("game_unpaused")).is_equal(1)

# ---------------------------------------------------------------------------
# Resume button
# ---------------------------------------------------------------------------

func test_resume_button_pressed_unpauses_when_currently_paused() -> void:
	_pause_menu._toggle_pause()
	_pause_menu._on_resume_pressed()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_pause_menu.visible).is_false()
	assert_int(_spy.count("game_unpaused")).is_equal(1)

# ---------------------------------------------------------------------------
# Quit to Sanctuary
# ---------------------------------------------------------------------------

func test_quit_to_sanctuary_unpauses_tree_and_hides_menu_before_transition() -> void:
	_pause_menu._toggle_pause()
	_pause_menu._on_quit_to_sanctuary_pressed()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_pause_menu.visible).is_false()


func test_quit_to_sanctuary_triggers_exactly_one_scene_transition() -> void:
	var transition_spy := EventBusSpy.new()
	transition_spy.watch(GEventBus.scene_transition_started)

	_pause_menu._toggle_pause()
	_pause_menu._on_quit_to_sanctuary_pressed()

	assert_int(transition_spy.count("scene_transition_started")).is_equal(1)
	transition_spy.disconnect_all()

# ---------------------------------------------------------------------------
# Input action wiring (static/structural check — no instance needed)
# ---------------------------------------------------------------------------

func test_pause_input_action_defined_in_project_settings() -> void:
	assert_bool(InputMap.has_action("pause")).is_true()
