## Integration tests for MissionSelectScreen (src/gameplay/ui/
## mission_select_screen), the browsing/configuring content of MissionScene's
## shell. Exercises the screen against mission-select.md's UI Requirements:
## mission list, difficulty/modifiers panel (progressive disclosure), and
## the persistent launch bar's lightweight arm/confirm two-step.
##
## Uses the real GMissionSelect Autoload (screen's own @export defaults to
## it) and the real GGameDataRegistry-loaded mission catalogue
## (assets/data/missions/entries/ — "the_gap" and "the_narrows").
extends GdUnitTestSuite

const MISSION_THE_GAP: String = "the_gap"

var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	GMissionSelect.reset_to_defaults()
	GMissionSelect._restore_completed = true
	# Most tests here are not about campaign unlocks; the lock tests below
	# turn locks back on and rebuild the screen.
	GMissionSelect.campaign_locks_enabled = false
	_runner = scene_runner("res://src/gameplay/ui/mission_select_screen/MissionSelectScreen.tscn")
	_screen = _runner.scene() as Control


func after_test() -> void:
	GMissionSelect.campaign_locks_enabled = true
	GMissionSelect.reset_to_defaults()


func _rebuild_with_locks(completions: Array) -> void:
	GMissionSelect.campaign_locks_enabled = true
	for completion: Array in completions:
		GMissionSelect.record_completion(completion[0], completion[1], 100.0)
	_runner = scene_runner("res://src/gameplay/ui/mission_select_screen/MissionSelectScreen.tscn")
	_screen = _runner.scene() as Control


func test_campaign_locked_map_card_is_disabled_and_names_its_prerequisite() -> void:
	_rebuild_with_locks([])

	var foothills: Button = _screen.call("get_mission_button", "the_foothills")
	assert_bool(foothills.disabled).is_true()
	assert_str(foothills.text).contains(tr("MISSION_SELECT_LOCKED") % "The Gap")
	assert_bool((_screen.call("get_mission_button", "the_gap") as Button).disabled).is_false()


func test_campaign_locked_tiers_are_disabled_and_ignore_presses() -> void:
	_rebuild_with_locks([])
	_screen.call("_on_mission_pressed", MISSION_THE_GAP)

	var hard: Button = _screen.call("get_tier_button", 2)
	assert_bool(hard.disabled).is_true()
	_screen.call("_on_tier_pressed", 2)
	assert_int(GMissionSelect.difficulty_tier).is_equal(1)
	assert_bool((_screen.call("get_ascension_button") as Button).visible).is_false()


func test_campaign_ascension_button_appears_after_brutal_and_cycles_ranks() -> void:
	_rebuild_with_locks([[MISSION_THE_GAP, 4]])  # Brutal + Ascension 1 cleared -> ranks 1-2 open
	_screen.call("_on_mission_pressed", MISSION_THE_GAP)
	var ascension: Button = _screen.call("get_ascension_button")
	assert_bool(ascension.visible).is_true()

	_screen.call("_on_ascension_pressed")
	assert_int(GMissionSelect.difficulty_tier).is_equal(5)  # first press: highest open rank
	assert_str(ascension.text).is_equal(tr("MISSION_SELECT_TIER_ASCENSION") % 2)
	_screen.call("_on_ascension_pressed")
	assert_int(GMissionSelect.difficulty_tier).is_equal(4)  # wraps to rank 1


## 2026-11-03 tidy: a fully cleared card used to wrap to five lines of raw
## per-tier seconds under the medallion. Now: name + one status line.
func test_mission_select_dev_unlock_tag_follows_dev_switch() -> void:
	assert_bool((_screen.call("get_dev_unlock_tag") as Label).visible).is_false()

	GMissionSelect.dev_unlock_active = true
	_runner = scene_runner("res://src/gameplay/ui/mission_select_screen/MissionSelectScreen.tscn")
	_screen = _runner.scene() as Control
	GMissionSelect.dev_unlock_active = false

	var tag: Label = _screen.call("get_dev_unlock_tag")
	assert_bool(tag.visible).is_true()
	assert_str(tag.text).is_equal(tr("MISSION_SELECT_DEV_UNLOCK"))


func test_mission_card_cleared_card_shows_highest_tier_on_two_lines() -> void:
	_rebuild_with_locks([[MISSION_THE_GAP, 1], [MISSION_THE_GAP, 2], [MISSION_THE_GAP, 3], [MISSION_THE_GAP, 5]])

	var gap: Button = _screen.call("get_mission_button", MISSION_THE_GAP)
	var lines: PackedStringArray = gap.text.split("\n")
	assert_int(lines.size()).is_equal(2)
	# Non-breaking space keeps the rank number with its word on the narrow card.
	assert_str(lines[1]).is_equal(tr("MISSION_SELECT_CLEARED") % (tr("MISSION_SELECT_TIER_ASCENSION") % 2).replace(" ", " "))
	var foothills: Button = _screen.call("get_mission_button", "the_foothills")
	assert_str(foothills.text.split("\n")[1]).is_equal(tr("MISSION_SELECT_NOT_CLEARED"))


func test_mission_select_best_time_label_follows_selected_tier() -> void:
	GMissionSelect.record_completion(MISSION_THE_GAP, 1, 200.0)
	_screen.call("_on_mission_pressed", MISSION_THE_GAP)
	var label: Label = _screen.call("get_best_time_label")
	assert_str(label.text).is_equal(tr("MISSION_SELECT_BEST_TIME") % [tr("MISSION_SELECT_TIER_NORMAL"), "3:20"])

	_screen.call("_on_tier_pressed", 2)
	assert_str(label.text).is_equal(tr("MISSION_SELECT_BEST_TIME_NONE") % tr("MISSION_SELECT_TIER_HARD"))


func test_mission_select_format_best_time_is_minutes_and_seconds() -> void:
	var screen_script: GDScript = load("res://src/gameplay/ui/mission_select_screen/mission_select_screen.gd")
	assert_str(screen_script.call("format_best_time", 200.0)).is_equal("3:20")
	assert_str(screen_script.call("format_best_time", 59.6)).is_equal("1:00")
	assert_str(screen_script.call("format_best_time", 0.0)).is_equal("0:00")
	assert_str(screen_script.call("format_best_time", 3725.0)).is_equal("62:05")


# ---------------------------------------------------------------------------
# Mission list
# ---------------------------------------------------------------------------

## Player-reported 2026-08-16: "a lot of grey area" -- this screen had no
## background fill at all, rendering on Godot's raw default clear color.
## Fix: a UI_CHROME-filled Background ColorRect (same token every other
## screen-space chrome in this project uses).
func test_background_uses_ui_chrome_color() -> void:
	var color: Color = _screen.call("get_background_color")
	assert_bool(color.is_equal_approx(ShellChromeStyle.UI_CHROME)).is_true()


func test_mission_list_contains_both_authored_missions() -> void:
	assert_object(_screen.call("get_mission_button", "the_gap")).is_not_null()
	assert_object(_screen.call("get_mission_button", "the_narrows")).is_not_null()


func test_pressing_a_mission_selects_it_and_enters_configuring() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_mission_pressed", MISSION_THE_GAP)

	assert_int(GMissionSelect.state).is_equal(MissionSelect.State.CONFIGURING)
	assert_str(GMissionSelect.get_current_mission_id()).is_equal(MISSION_THE_GAP)


# ---------------------------------------------------------------------------
# Config panel — progressive disclosure (empty until a mission is selected)
# ---------------------------------------------------------------------------

func test_config_panel_hidden_before_any_mission_is_selected() -> void:
	var config_panel: Control = _screen.get_node("MainLayout/TopRow/RightPanel/ConfigPanel") as Control
	assert_bool(config_panel.visible).is_false()


func test_config_panel_visible_after_selecting_a_mission() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_mission_pressed", MISSION_THE_GAP)

	var config_panel: Control = _screen.get_node("MainLayout/TopRow/RightPanel/ConfigPanel") as Control
	assert_bool(config_panel.visible).is_true()


func test_pressing_a_tier_sets_difficulty_tier() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_mission_pressed", MISSION_THE_GAP)

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_tier_pressed", 3)

	assert_int(GMissionSelect.difficulty_tier).is_equal(3)


func test_pressing_a_modifier_cycles_through_its_3_steps() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_mission_pressed", MISSION_THE_GAP)

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_modifier_pressed", &"extend_waves")
	assert_float(GMissionSelect.get_run_modifier_value(&"extend_waves")).is_equal(1.0)

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_modifier_pressed", &"extend_waves")
	assert_float(GMissionSelect.get_run_modifier_value(&"extend_waves")).is_equal(2.0)

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_modifier_pressed", &"extend_waves")
	assert_float(GMissionSelect.get_run_modifier_value(&"extend_waves")).is_equal(0.0)  # wraps back to OFF


func test_back_button_returns_to_browsing() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_mission_pressed", MISSION_THE_GAP)

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_back_pressed")

	assert_int(GMissionSelect.state).is_equal(MissionSelect.State.BROWSING)


# ---------------------------------------------------------------------------
# Launch bar — lightweight arm/confirm two-step (never a modal)
# ---------------------------------------------------------------------------

func test_first_launch_press_arms_without_confirming() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_mission_pressed", MISSION_THE_GAP)

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_launch_pressed")

	assert_bool(_screen.call("is_launch_armed")).is_true()
	assert_int(GMissionSelect.state).is_equal(MissionSelect.State.CONFIGURING)  # not yet LAUNCHED


func test_second_launch_press_actually_confirms() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_mission_pressed", MISSION_THE_GAP)
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_launch_pressed")  # arm

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_launch_pressed")  # confirm

	assert_int(GMissionSelect.state).is_equal(MissionSelect.State.LAUNCHED)


func test_pressing_any_other_control_while_armed_silently_disarms() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_mission_pressed", MISSION_THE_GAP)
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_launch_pressed")  # arm
	assert_bool(_screen.call("is_launch_armed")).is_true()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_tier_pressed", 2)  # any other control

	assert_bool(_screen.call("is_launch_armed")).is_false()


func test_launch_press_with_no_mission_selected_is_a_no_op() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_launch_pressed")

	assert_bool(_screen.call("is_launch_armed")).is_false()
	assert_int(GMissionSelect.state).is_equal(MissionSelect.State.BROWSING)


# ---------------------------------------------------------------------------
# Room-hosting-style contract (this screen's shell, mission_scene.gd, calls
# this the same way RoomHost/ScreenHost do for their own hosted content)
# ---------------------------------------------------------------------------

func test_disconnect_own_subscriptions_is_safe_to_call() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("disconnect_own_subscriptions")
	assert_bool(true).is_true()
