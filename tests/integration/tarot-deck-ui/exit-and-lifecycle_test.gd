## Integration tests for Story 003 (epic-11-tarot-deck-ui, ADR-0032): Exit &
## Lifecycle -- destroy-and-recreate screen mount/unmount (ScreenHost, mirrors
## Sanctuary UI's RoomHost) and Cancel/return-to-Sanctuary (GDD Core Rule 4-5,
## AC Group 3).
##
## Cancel's real hand-off (GSceneManager.transition_to_sanctuary()) is
## exercised safely using this project's own established test seam
## (GSceneManager._inject(), matching tests/integration/foundation/
## scene_manager_transition_test.gd's identical pattern) rather than letting
## it load the real (still placeholder, per every Sanctuary UI story's own
## deferred-integration note) SanctuaryScene.tscn during this suite.
##
## AC-2/AC-3 (committed edits survive a switch; gamepad pick-up silently
## abandoned) cannot be tested against real content -- neither tarot.md's nor
## hero-skill-build.md's own screen exists as a built .tscn anywhere in this
## project yet (OQ-5). The generic ScreenHost mechanism itself (which is what
## WOULD deliver both guarantees once real screens exist, exactly as Story
## 007/010 already proved for Sanctuary UI's own equivalent rooms) is fully
## tested below instead.
extends GdUnitTestSuite

const STUB_SCENE_PATH: String = "res://tests/fixtures/scene_manager/StubScene.tscn"

var _original_mission_path: String
var _original_sanctuary_path: String
var _original_current_scene: Node
var _spy: EventBusSpy

var _runner: GdUnitSceneRunner
var _shell: TarotDeckUI


func before_test() -> void:
	_original_mission_path = GSceneManager._mission_scene_path
	_original_sanctuary_path = GSceneManager._sanctuary_scene_path
	GSceneManager._inject(STUB_SCENE_PATH, STUB_SCENE_PATH)
	_original_current_scene = get_tree().current_scene

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.scene_transition_started)
	_spy.watch(GEventBus.scene_transition_completed)

	_runner = scene_runner("res://src/presentation/tarot_deck_ui/TarotDeckUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as TarotDeckUI


func after_test() -> void:
	if GSceneManager._transition_in_progress:
		await GEventBus.scene_transition_completed
	_spy.disconnect_all()
	_spy = null
	GSceneManager._inject(_original_mission_path, _original_sanctuary_path)
	GSceneManager._transition_in_progress = false
	if is_instance_valid(_original_current_scene):
		get_tree().current_scene = _original_current_scene


# ---------------------------------------------------------------------------
# ScreenHost destroy-and-recreate mechanics (mirrors RoomHost's own Story
# 007 coverage exactly)
# ---------------------------------------------------------------------------

func test_mounting_a_screen_creates_a_fresh_instance() -> void:
	var stub_scene := PackedScene.new()
	var stub_root := Control.new()
	stub_scene.pack(stub_root)
	stub_root.free()

	_shell.get_screen_host().mount_screen(stub_scene, &"TAROT_DECK")
	var first_screen: Node = _shell.get_screen_host().get_current_screen()

	_shell.get_screen_host().mount_screen(stub_scene, &"HERO_SKILL_BUILD")
	var second_screen: Node = _shell.get_screen_host().get_current_screen()

	assert_bool(first_screen == second_screen).is_false()
	assert_object(second_screen).is_not_null()


func test_unmounting_calls_disconnect_own_subscriptions_before_queue_free() -> void:
	var stub_script: GDScript = load("res://tests/integration/sanctuary-ui/room_lifecycle_stub_room.gd")
	var stub_scene := PackedScene.new()
	var stub_root := Control.new()
	stub_root.set_script(stub_script)
	stub_scene.pack(stub_root)
	stub_root.free()

	_shell.get_screen_host().mount_screen(stub_scene, &"TAROT_DECK")
	RoomLifecycleStubRoom.reset_call_log()

	_shell.get_screen_host().unmount_current_screen()

	assert_array(RoomLifecycleStubRoom.call_log).is_equal(["disconnect_own_subscriptions"])


# ---------------------------------------------------------------------------
# Cancel / return-to-Sanctuary: the real SceneManager call, tested safely
# against a stub scene path (this project's own established seam)
# ---------------------------------------------------------------------------

func test_cancel_triggers_a_real_transition_to_sanctuary_call() -> void:
	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	_shell._input(cancel_event)

	await GEventBus.scene_transition_completed

	assert_int(_spy.count("scene_transition_started")).is_equal(1)
	assert_int(_spy.count("scene_transition_completed")).is_equal(1)
	var started_args: Array = (_spy.emissions["scene_transition_started"] as Array)[0] as Array
	assert_str(started_args[0] as String).is_equal("SANCTUARY")
