## Integration tests for Story 001 (epic-11-tarot-deck-ui, ADR-0011):
## Structural Model -- Sibling Shell, 2-Screen Tab Strip Navigation (GDD Core
## Rule 1-2, AC Group 1).
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _shell: TarotDeckUI
var _tab_strip: DeckTabStrip


func before_test() -> void:
	_runner = scene_runner("res://src/presentation/tarot_deck_ui/TarotDeckUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as TarotDeckUI
	_tab_strip = _shell.get_tab_strip_for_test()


func _press_action(action_name: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	_tab_strip._input(event)


# ---------------------------------------------------------------------------
# AC-1: exactly 2 states exist on mount, tab strip present/rendering in both
# ---------------------------------------------------------------------------

func test_mount_state_is_hero_skill_build_and_tab_strip_present() -> void:
	assert_that(_shell.get_active_state()).is_equal(&"HERO_SKILL_BUILD")
	assert_object(_tab_strip).is_not_null()
	assert_int(DeckTabStrip.TAB_TARGETS.size()).is_equal(2)


# ---------------------------------------------------------------------------
# AC-2: click / [/]/LT-RT switch between the 2 screens
# ---------------------------------------------------------------------------

func test_clicking_the_other_tab_switches_state() -> void:
	_tab_strip.get_tab_button(1).pressed.emit()
	assert_that(_shell.get_active_state()).is_equal(&"TAROT_DECK")

	_tab_strip.get_tab_button(0).pressed.emit()
	assert_that(_shell.get_active_state()).is_equal(&"HERO_SKILL_BUILD")


func test_bracket_and_trigger_actions_toggle_between_the_2_screens() -> void:
	_press_action(&"tarot_tab_next")
	assert_that(_shell.get_active_state()).is_equal(&"TAROT_DECK")

	_press_action(&"tarot_tab_prev")
	assert_that(_shell.get_active_state()).is_equal(&"HERO_SKILL_BUILD")

	# LT/RT bound to the same actions -- confirms both physical inputs drive
	# identical behavior via the shared action name, matching the GDD's own
	# "same trigger/bumper split as Sanctuary UI" requirement.
	_press_action(&"tarot_tab_next")
	assert_that(_shell.get_active_state()).is_equal(&"TAROT_DECK")


# ---------------------------------------------------------------------------
# AC-3: bumpers never switch screens (no InputMap action exists to target,
# matching AC-5's own reasoning in Sanctuary UI's identical test)
# ---------------------------------------------------------------------------

func test_bumpers_never_change_active_state() -> void:
	_tab_strip.get_tab_button(1).pressed.emit()  # TAROT_DECK active
	var index_before: int = _tab_strip.get_current_index()

	var lb_event := InputEventJoypadButton.new()
	lb_event.button_index = JOY_BUTTON_LEFT_SHOULDER
	lb_event.pressed = true
	_tab_strip._input(lb_event)

	var rb_event := InputEventJoypadButton.new()
	rb_event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb_event.pressed = true
	_tab_strip._input(rb_event)

	assert_that(_shell.get_active_state()).is_equal(&"TAROT_DECK")
	assert_int(_tab_strip.get_current_index()).is_equal(index_before)


# ---------------------------------------------------------------------------
# ADR-0011 focus-ring contract, mirroring Sanctuary UI's own equivalent tests
# ---------------------------------------------------------------------------

func test_focus_ring_visible_only_when_keyboard_focused() -> void:
	assert_bool(_tab_strip.is_focus_ring_visible(0)).is_false()

	_tab_strip.get_tab_button(0).grab_focus()

	assert_bool(_tab_strip.is_focus_ring_visible(0)).is_true()
