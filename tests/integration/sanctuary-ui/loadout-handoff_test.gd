## Integration tests for Story 010 (epic-10-sanctuary-ui, ADR-0032/ADR-0020):
## Loadout -- Tab Strip's 6th Entry, Hand-off to Tarot Deck UI. The 4-step
## ordered sequence, reachable-from-any-state semantics, shared terminal
## latch with Launch/Depart, and double-selection guard (GDD Core Rule 10,
## AC Group 10).
##
## See sanctuary_ui.gd's own select_loadout() doc comment for a real, flagged
## gap: Tarot Deck UI (epic-11-tarot-deck-ui) has no built scene yet, mirroring
## Story 009's identical Mission Select gap. These tests cover the ordered
## sequence and state machine, which ARE fully real, not the unresolved
## cross-shell hand-off call itself.
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _shell: SanctuaryUI


func before_test() -> void:
	TabStrip.reset_onboarding_flag_for_tests()
	_runner = scene_runner("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as SanctuaryUI


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


func test_selecting_loadout_via_tab_strip_hotkey_6_routes_correctly() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(2).pressed.emit()  # Menagerie

	_shell.get_tab_strip_for_test().get_tab_button(5).pressed.emit()  # Loadout, index 5

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
