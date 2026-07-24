## Integration tests for Story 006 (epic-10-sanctuary-ui, ADR-0002): Entry
## Always Defaults to OVERVIEW; Player-Initiated Return -- mount trigger,
## no room-state persistence across visits, player-initiated return via tab
## 1/hotkey 1, and the diorama's always-listening structure feed (GDD Core
## Rule 5, AC Group 5).
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _shell: SanctuaryUI


func before_test() -> void:
	TabStrip.reset_onboarding_flag_for_tests()
	_runner = scene_runner("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as SanctuaryUI


# ---------------------------------------------------------------------------
# Mounts to OVERVIEW before any input is processed
# ---------------------------------------------------------------------------

func test_active_state_is_overview_immediately_on_mount() -> void:
	assert_that(_shell.get_active_state()).is_equal(&"OVERVIEW")


# ---------------------------------------------------------------------------
# scene_transition_completed(SANCTUARY) mounts/resets to OVERVIEW
# ---------------------------------------------------------------------------

func test_scene_transition_completed_sanctuary_mounts_to_overview() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()  # leave OVERVIEW first
	assert_that(_shell.get_active_state()).is_not_equal(&"OVERVIEW")

	GEventBus.scene_transition_completed.emit("SANCTUARY", "")

	assert_that(_shell.get_active_state()).is_equal(&"OVERVIEW")


func test_scene_transition_completed_other_context_does_not_affect_active_state() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()
	var state_before: StringName = _shell.get_active_state()

	GEventBus.scene_transition_completed.emit("MISSION", "the_gap")

	assert_that(_shell.get_active_state()).is_equal(state_before)


# ---------------------------------------------------------------------------
# No room-state persistence across visits -- a fresh instance always starts
# at OVERVIEW regardless of what a PRIOR instance had active
# ---------------------------------------------------------------------------

func test_fresh_instance_starts_overview_regardless_of_a_prior_instances_last_state() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()  # prior instance: Inventory & Crafting
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_INVENTORY_CRAFTING")

	# A "new visit" in this architecture is a fresh SanctuaryUI instance
	# (ADR-0002's scene-instanced classification, SceneManager always calls
	# change_scene_to_packed()) -- simulated here the same way, a brand new
	# instance, not a reset of the existing one.
	var fresh_shell: SanctuaryUI = load("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn").instantiate()
	add_child(fresh_shell)
	auto_free(fresh_shell)

	assert_that(fresh_shell.get_active_state()).is_equal(&"OVERVIEW")


# ---------------------------------------------------------------------------
# Player-initiated return: tab 1 / hotkey 1 reaches OVERVIEW from any
# ROOM_* state, not only on forced mission-return entry
# ---------------------------------------------------------------------------

func test_hotkey_1_returns_to_overview_from_a_real_hosted_room() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()  # Inventory & Crafting, real scene
	assert_object(_shell.get_room_host().get_current_room()).is_not_null()

	_shell.get_tab_strip_for_test().get_tab_button(0).pressed.emit()  # tab 1 / Overview

	assert_that(_shell.get_active_state()).is_equal(&"OVERVIEW")
	assert_object(_shell.get_room_host().get_current_room()).is_null()


# ---------------------------------------------------------------------------
# sanctuary_structure_built always listening, regardless of active state
# ---------------------------------------------------------------------------

func test_structure_built_recorded_while_overview_active() -> void:
	GEventBus.sanctuary_structure_built.emit("watchtower", "defensive")
	assert_array(_shell.get_built_structure_ids()).contains(["watchtower"])


func test_structure_built_recorded_while_a_different_room_is_active() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()  # Inventory & Crafting active

	GEventBus.sanctuary_structure_built.emit("forge_structure", "production")

	assert_array(_shell.get_built_structure_ids()).contains(["forge_structure"])
	# Still active in Inventory & Crafting -- the structure feed update didn't
	# force a state change.
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_INVENTORY_CRAFTING")
