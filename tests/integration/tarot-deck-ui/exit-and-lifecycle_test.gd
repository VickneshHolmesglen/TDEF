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
## AC-2 (committed edits survive a switch) is now tested against real content
## (2026-07-25) -- both tarot_screen.gd and hero_skill_build_screen.gd exist
## as real, mounted screens as of this session's earlier work.
##
## AC-3 (gamepad pick-up silently abandoned) is confirmed N/A, not merely
## untested (2026-07-25): hero_skill_build_screen.gd's own class doc comment
## documents an honestly-scoped deviation from the GDD's literal pick-up-
## then-place gamepad model -- the real screen assigns a library skill to the
## first empty active slot in one direct action (mirrors tarot_screen.gd's
## identical simplification), so there is no "picked up, not yet placed"
## transient state anywhere in the real implementation for a screen switch
## to abandon. AC-3 describes a mechanic this project's real screen
## deliberately does not implement, not a gap in this shell's own coverage.
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
	GHeroSkillBuild.reset_to_defaults()
	GHeroSkillBuild._is_sanctuary = false


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

# ---------------------------------------------------------------------------
# AC-2: committed edits survive a screen switch (real content, 2026-07-25)
# ---------------------------------------------------------------------------

func test_hero_skill_build_slot_assignment_survives_a_switch_to_tarot_and_back() -> void:
	GHeroSkillBuild._is_sanctuary = true
	var skill_id: String = "phys_cleave"
	GHeroSkillBuild._equippable_skills[skill_id] = true

	_shell.set_active_state(&"HERO_SKILL_BUILD")
	var hsb_screen: Control = _shell.get_screen_host().get_current_screen() as Control
	@warning_ignore("unsafe_method_access")
	hsb_screen.call("_on_library_skill_pressed", skill_id)
	assert_array(GHeroSkillBuild.get_active_slots()).contains(skill_id)

	_shell.set_active_state(&"TAROT_DECK")
	_shell.set_active_state(&"HERO_SKILL_BUILD")

	# Re-query via Hero Skill Build's own already-existing state, not a new
	# shell-level assertion about internal data (matches the GDD's own
	# framing of this AC).
	assert_array(GHeroSkillBuild.get_active_slots()).contains(skill_id)


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
