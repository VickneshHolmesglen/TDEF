## Integration tests for Story 010 (epic-10-sanctuary-ui, ADR-0032/ADR-0020):
## Loadout -- Tab Strip's 6th Entry, Hand-off to Tarot Deck UI. The 4-step
## ordered sequence, reachable-from-any-state semantics, shared terminal
## latch with Launch/Depart, and double-selection guard (GDD Core Rule 10,
## AC Group 10).
##
## Gap closed 2026-07-25: select_loadout()'s Step 4 now calls the real
## GSceneManager.transition_to_tarot_deck_ui(), landing on the real,
## fully-built TarotDeckUIScene.tscn. Exercised safely using this project's
## own established test seam (GSceneManager._inject(), matching
## tests/integration/tarot-deck-ui/exit-and-lifecycle_test.gd's identical
## pattern for the equivalent Cancel/return-to-Sanctuary call) rather than
## letting each test actually swap the running SceneTree's current_scene.
extends GdUnitTestSuite

const STUB_SCENE_PATH: String = "res://tests/fixtures/scene_manager/StubScene.tscn"

var _original_mission_path: String
var _original_sanctuary_path: String
var _original_tarot_deck_path: String
var _original_current_scene: Node

var _runner: GdUnitSceneRunner
var _shell: SanctuaryUI


func before_test() -> void:
	_original_mission_path = GSceneManager._mission_scene_path
	_original_sanctuary_path = GSceneManager._sanctuary_scene_path
	_original_tarot_deck_path = GSceneManager._tarot_deck_scene_path
	GSceneManager._inject(STUB_SCENE_PATH, STUB_SCENE_PATH, STUB_SCENE_PATH)
	_original_current_scene = get_tree().current_scene

	TabStrip.reset_onboarding_flag_for_tests()
	_runner = scene_runner("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as SanctuaryUI


func after_test() -> void:
	if GSceneManager._transition_in_progress:
		await GEventBus.scene_transition_completed
	GSceneManager._inject(_original_mission_path, _original_sanctuary_path, _original_tarot_deck_path)
	GSceneManager._transition_in_progress = false
	if is_instance_valid(_original_current_scene):
		get_tree().current_scene = _original_current_scene


# ---------------------------------------------------------------------------
# Reachable from any state -- enumerated individually per the story's own
# rewrite rationale (not a generic "any ROOM_* state" assertion)
# ---------------------------------------------------------------------------

func test_loadout_reachable_from_overview() -> void:
	assert_that(_shell.get_active_state()).is_equal(&"OVERVIEW")
	_shell.select_loadout()
	assert_bool(_shell.is_departing_to_loadout()).is_true()


func test_loadout_reachable_from_inventory_crafting() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()
	_shell.select_loadout()
	assert_bool(_shell.is_departing_to_loadout()).is_true()


func test_loadout_reachable_from_menagerie() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(2).pressed.emit()
	_shell.select_loadout()
	assert_bool(_shell.is_departing_to_loadout()).is_true()


func test_loadout_reachable_from_defense_building() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(3).pressed.emit()
	_shell.select_loadout()
	assert_bool(_shell.is_departing_to_loadout()).is_true()


func test_loadout_reachable_from_equipment_forge() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(4).pressed.emit()
	_shell.select_loadout()
	assert_bool(_shell.is_departing_to_loadout()).is_true()


# ---------------------------------------------------------------------------
# Full ordered sequence: active room torn down first, distinct destination
# from Launch/Depart's DEPARTING state
# ---------------------------------------------------------------------------

func test_selecting_loadout_tears_down_active_room_and_enters_distinct_state() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()  # Inventory & Crafting
	assert_object(_shell.get_room_host().get_current_room()).is_not_null()

	_shell.select_loadout()

	assert_object(_shell.get_room_host().get_current_room()).is_null()
	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING_TO_LOADOUT")
	# Distinct from Launch/Depart's own DEPARTING state -- not a reuse.
	assert_that(_shell.get_active_state()).is_not_equal(&"DEPARTING")


## Renamed 2026-09-01 (Claude Code): Loadout shifted from hotkey 6 to hotkey 7
## when the new Skills entry (ROOM_HERO_SKILLS) was inserted at index 5,
## between Equipment Forge and Loadout, per sanctuary-ui.md Core Rule 11 --
## see tab_strip.gd's own TAB_TARGETS doc comment.
func test_selecting_loadout_via_tab_strip_hotkey_7_routes_correctly() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(2).pressed.emit()  # Menagerie

	_shell.get_tab_strip_for_test().get_tab_button(6).pressed.emit()  # Loadout, index 6 (was 5 before the Skills entry)

	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING_TO_LOADOUT")
	assert_object(_shell.get_room_host().get_current_room()).is_null()


# ---------------------------------------------------------------------------
# Call-order: room teardown completes before DEPARTING_TO_LOADOUT is entered
# ---------------------------------------------------------------------------

func test_room_teardown_completes_via_call_order_before_departing_to_loadout() -> void:
	var stub_scene := PackedScene.new()
	var stub_root := Control.new()
	var stub_script: GDScript = load("res://tests/integration/sanctuary-ui/room_lifecycle_stub_room.gd")
	stub_root.set_script(stub_script)
	stub_scene.pack(stub_root)
	stub_root.free()

	RoomLifecycleStubRoom.reset_call_log()
	_shell.set_active_state(&"ROOM_EQUIPMENT_FORGE")
	_shell.get_room_host().mount_room(stub_scene, &"ROOM_EQUIPMENT_FORGE")
	RoomLifecycleStubRoom.reset_call_log()  # clear the "ready" entry from mount

	_shell.select_loadout()

	# disconnect_own_subscriptions() must have run (Story 007's own teardown
	# sequence) BEFORE this method returns with DEPARTING_TO_LOADOUT active --
	# call-order inspection, mirroring Story 007's own AC-2 test pattern.
	assert_array(RoomLifecycleStubRoom.call_log).is_equal(["disconnect_own_subscriptions"])
	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING_TO_LOADOUT")


# ---------------------------------------------------------------------------
# Double-selection guard -- only one DEPARTING_TO_LOADOUT entry
# ---------------------------------------------------------------------------

func test_double_selection_produces_only_one_departing_to_loadout_entry() -> void:
	_shell.select_loadout()
	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING_TO_LOADOUT")

	_shell.select_loadout()

	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING_TO_LOADOUT")
	assert_bool(_shell.is_departing()).is_true()


func test_loadout_selected_while_departing_from_launch_depart_is_discarded() -> void:
	_shell.confirm_launch_depart()  # Launch/Depart's own DEPARTING first
	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING")

	_shell.select_loadout()  # shared _departing flag -- must be a no-op

	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING")


# ---------------------------------------------------------------------------
# Loadout tears down a room with an unconfirmed staged action the same way
# any other lateral switch does -- a direct consequence of Story 007's
# destroy-and-recreate lifecycle, not a separately-implemented discard
# ---------------------------------------------------------------------------

func test_loadout_discards_staged_room_state_via_the_same_teardown_as_any_switch() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()  # Inventory & Crafting
	var room_before: Node = _shell.get_room_host().get_current_room()
	assert_object(room_before).is_not_null()

	_shell.select_loadout()

	# The node holding any staged state no longer exists -- same guarantee
	# Story 007's own nested-state test already covers, exercised here via
	# Loadout specifically rather than a lateral tab switch.
	assert_object(_shell.get_room_host().get_current_room()).is_null()


# ---------------------------------------------------------------------------
# The real Tarot Deck UI hand-off call (gap closed 2026-07-25)
# ---------------------------------------------------------------------------

func test_loadout_triggers_a_real_transition_to_tarot_deck_ui_call() -> void:
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.scene_transition_started)
	spy.watch(GEventBus.scene_transition_completed)

	_shell.select_loadout()

	await GEventBus.scene_transition_completed

	assert_int(spy.count("scene_transition_started")).is_equal(1)
	var started_args: Array = (spy.emissions["scene_transition_started"] as Array)[0] as Array
	assert_str(started_args[0] as String).is_equal("TAROT_DECK")
	spy.disconnect_all()
