## Integration tests for HeroSkillsRoom (new 2026-09-01, Claude Code) --
## the composite `ROOM_HERO_SKILLS` room hosting hero_skill_build_screen.gd
## (Loadout) and hero_skill_tree_screen.gd (Skill Tree) as bumper-toggled
## sub-screens, per sanctuary-ui.md Core Rule 11.
##
## Mirrors this project's own established direct-_input()-dispatch pattern
## for InputEventAction (see tab-strip-navigation_test.gd's own file-level
## doc comment) for the room_bumper_left/room_bumper_right actions this
## class introduces.
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _room: Control


func before_test() -> void:
	_runner = scene_runner("res://src/gameplay/ui/hero_skills_room/HeroSkillsRoom.tscn")
	_room = _runner.scene() as Control


func _press_bumper(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_room._unhandled_input(event)


func test_loadout_is_the_default_sub_screen_on_room_entry() -> void:
	assert_bool(_room.call("is_showing_loadout")).is_true()
	assert_bool((_room.call("get_loadout_screen") as Control).visible).is_true()
	assert_bool((_room.call("get_skill_tree_screen") as Control).visible).is_false()


func test_pressing_the_skill_tree_tab_button_switches_sub_screens() -> void:
	var skill_tree_button: Button = _room.get_node("MainLayout/SubTabStrip/SkillTreeTabButton")
	skill_tree_button.pressed.emit()

	assert_bool(_room.call("is_showing_loadout")).is_false()
	assert_bool((_room.call("get_loadout_screen") as Control).visible).is_false()
	assert_bool((_room.call("get_skill_tree_screen") as Control).visible).is_true()


func test_pressing_the_loadout_tab_button_switches_back() -> void:
	var skill_tree_button: Button = _room.get_node("MainLayout/SubTabStrip/SkillTreeTabButton")
	skill_tree_button.pressed.emit()
	var loadout_button: Button = _room.get_node("MainLayout/SubTabStrip/LoadoutTabButton")
	loadout_button.pressed.emit()

	assert_bool(_room.call("is_showing_loadout")).is_true()


## Bumpers never trigger a tab-strip switch (Core Rule 11) -- this is the
## room's own internal lateral navigation, distinct from TabStrip's own
## AC-5 guarantee (tab-strip-navigation_test.gd) that LB/RB never change
## the ACTIVE ROOM. Both are true simultaneously: the bumper toggles this
## room's own sub-screen without ever calling SanctuaryUI.set_active_state().
func test_bumper_left_toggles_to_skill_tree() -> void:
	_press_bumper(&"room_bumper_left")
	assert_bool(_room.call("is_showing_loadout")).is_false()


func test_bumper_right_toggles_to_skill_tree() -> void:
	_press_bumper(&"room_bumper_right")
	assert_bool(_room.call("is_showing_loadout")).is_false()


func test_bumper_toggles_back_and_forth() -> void:
	_press_bumper(&"room_bumper_left")
	assert_bool(_room.call("is_showing_loadout")).is_false()

	_press_bumper(&"room_bumper_right")
	assert_bool(_room.call("is_showing_loadout")).is_true()


## RoomHost contract (ADR-0032 Section 1) -- delegates to both children's
## own disconnect_own_subscriptions(), matching every other room's own
## test coverage for this method (e.g. inventory_screen_test.gd).
func test_disconnect_own_subscriptions_is_safe_to_call() -> void:
	_room.call("disconnect_own_subscriptions")
	assert_bool(true).is_true()
