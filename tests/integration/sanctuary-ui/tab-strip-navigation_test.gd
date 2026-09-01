## Integration tests for Story 002 (epic-10-sanctuary-ui, ADR-0011): Tab Strip
## Navigation -- 7-entry direct click routing (Skills added 2026-09-01,
## Claude Code -- see tab_strip.gd's own TAB_TARGETS doc comment), global
## hotkeys 1-7, `[`/`]` and gamepad LT/RT prev/next cycling, LB/RB bumper
## absence AT THE TAB-STRIP LEVEL specifically (individual rooms, including
## the new HeroSkillsRoom, may now legitimately use LB/RB for their own
## internal sub-navigation -- see hero_skills_room.gd), and the one-time
## session-local onboarding tooltip (GDD Core Rule 2, AC Group 2).
##
## Hotkeys / `[`/`]` / LT/RT are exercised by constructing an InputEventAction
## for the real InputMap action names added in project.godot and dispatching
## it directly to TabStrip._input() -- NOT via GdUnitSceneRunner's
## simulate_action_press()/simulate_action_pressed(). That runner-mediated path
## was tried first and proved unreliable for a single isolated action dispatch
## in headless mode (this project's own GdUnit4 CLI prints an explicit warning
## that "InputEvents are not transported ... in headless mode" -- it worked
## when chained in a loop within one test but not for the first/only action
## dispatched in a freshly-instantiated scene, a timing race, not a tab_strip.gd
## defect). Direct _input() dispatch against a real InputEventAction still
## verifies the action names are bound and TabStrip's own is_action_pressed()
## routing is correct -- it just skips GdUnit's flaky delivery layer, mirroring
## the pattern the AC-5 test (bumpers) already used successfully in this file.
extends GdUnitTestSuite

const SanctuaryUiScene: PackedScene = preload("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")
const STUB_SCENE_PATH: String = "res://tests/fixtures/scene_manager/StubScene.tscn"

var _runner: GdUnitSceneRunner
var _shell: SanctuaryUI
var _tab_strip: TabStrip

var _original_mission_path: String
var _original_sanctuary_path: String
var _original_tarot_deck_path: String
var _original_current_scene: Node


func before_test() -> void:
	# TD-test-004 fix (2026-07-25): reaching tab index 6 (Loadout) below
	# triggers a real GSceneManager.transition_to_tarot_deck_ui() call,
	# loading the genuine, node-heavy TarotDeckUIScene.tscn with nothing to
	# tear it down afterward -- redirect to a lightweight stub scene via this
	# project's own established test seam, matching loadout-handoff_test.gd's
	# identical pattern.
	_original_mission_path = GSceneManager._mission_scene_path
	_original_sanctuary_path = GSceneManager._sanctuary_scene_path
	_original_tarot_deck_path = GSceneManager._tarot_deck_scene_path
	GSceneManager._inject(STUB_SCENE_PATH, STUB_SCENE_PATH, STUB_SCENE_PATH)
	_original_current_scene = get_tree().current_scene

	TabStrip.reset_onboarding_flag_for_tests()
	_runner = scene_runner("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as SanctuaryUI
	_tab_strip = _shell.get_node("Chrome/TabStrip") as TabStrip
	# A freshly-instantiated scene's viewport needs one settled frame before
	# simulated InputEventAction dispatch reliably reaches _input() on its
	# children -- without this, the first simulated action in an isolated test
	# (as opposed to the Nth in a loop already run in the same test) can race
	# and silently fail to be delivered. Not a tab_strip.gd defect; a Godot/
	# GdUnit4 scene-warm-up timing quirk specific to headless input dispatch.
	await _runner.await_input_processed()


func after_test() -> void:
	TabStrip.reset_onboarding_flag_for_tests()
	if GSceneManager._transition_in_progress:
		await GEventBus.scene_transition_completed
	GSceneManager._inject(_original_mission_path, _original_sanctuary_path, _original_tarot_deck_path)
	GSceneManager._transition_in_progress = false
	if is_instance_valid(_original_current_scene):
		get_tree().current_scene = _original_current_scene


## Constructs and directly dispatches a "pressed" InputEventAction for the
## given real InputMap action name -- see the file-level doc comment for why
## this bypasses GdUnitSceneRunner's own simulate_action_press() path.
func _press_action(action_name: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	_tab_strip._input(event)


# ---------------------------------------------------------------------------
# AC-1: direct click routing (K/M) -- all 6 entries, not just entry 1
# ---------------------------------------------------------------------------

func test_clicking_each_tab_routes_to_its_mapped_state() -> void:
	for index: int in TabStrip.TAB_TARGETS.size():
		_tab_strip.get_tab_button(index).pressed.emit()
		assert_that(_shell.get_active_state()).is_equal(TabStrip.TAB_TARGETS[index])


# ---------------------------------------------------------------------------
# AC-2: numeric hotkeys 1-6 jump directly from any starting state
# ---------------------------------------------------------------------------

func test_hotkeys_jump_directly_from_overview() -> void:
	for index: int in TabStrip.TAB_TARGETS.size():
		_press_action(TabStrip.HOTKEY_ACTIONS[index])
		assert_that(_shell.get_active_state()).is_equal(TabStrip.TAB_TARGETS[index])


func test_hotkey_jumps_directly_from_a_room_state_not_only_overview() -> void:
	_press_action(&"sanctuary_tab_3")
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_MENAGERIE")

	_press_action(&"sanctuary_tab_5")
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_EQUIPMENT_FORGE")


## Renamed 2026-09-01 (Claude Code): Loadout shifted from hotkey 6 to hotkey 7
## when the new Skills entry (ROOM_HERO_SKILLS) was inserted at index 5 --
## see tab_strip.gd's own TAB_TARGETS doc comment.
func test_hotkey_7_reaches_departing_to_loadout_from_a_room_state() -> void:
	_press_action(&"sanctuary_tab_2")
	_press_action(&"sanctuary_tab_7")
	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING_TO_LOADOUT")


func test_hotkey_6_reaches_room_hero_skills() -> void:
	_press_action(&"sanctuary_tab_2")
	_press_action(&"sanctuary_tab_6")
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_HERO_SKILLS")


# ---------------------------------------------------------------------------
# AC-3: `[`/`]` cycling, including wrap-around at both boundaries
# ---------------------------------------------------------------------------

func test_bracket_keys_cycle_forward_then_back() -> void:
	_press_action(&"sanctuary_tab_3")  # index 2 (ROOM_MENAGERIE)

	_press_action(&"sanctuary_tab_next")
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_DEFENSE_BUILDING")  # index 3

	_press_action(&"sanctuary_tab_prev")
	_press_action(&"sanctuary_tab_prev")
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_INVENTORY_CRAFTING")  # index 1


func test_bracket_prev_wraps_from_first_index_to_last() -> void:
	# Default state on mount is OVERVIEW (index 0) -- one `[` from there must
	# wrap to index 6 (Loadout, shifted from index 5 2026-09-01 when the new
	# Skills entry was inserted at index 5 -- see tab_strip.gd's own
	# TAB_TARGETS doc comment).
	_press_action(&"sanctuary_tab_prev")
	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING_TO_LOADOUT")


func test_bracket_next_wraps_from_last_index_to_first() -> void:
	# Updated by Story 010: reaching Loadout (index 6, shifted from index 5
	# 2026-09-01 -- see tab_strip.gd's own TAB_TARGETS doc comment) now
	# triggers a real, one-way terminal-latch hand-off (select_loadout()),
	# not a plain state swap -- cycling past it no longer un-departs, by
	# design (the same guarantee Launch/Depart's own DEPARTING state already
	# has). The tab strip's OWN index still wraps 6->0 at its own level
	# (asserted below); SanctuaryUI's active_state correctly stays latched
	# at DEPARTING_TO_LOADOUT, since select_loadout() intentionally blocks
	# all further navigation once it fires.
	_press_action(&"sanctuary_tab_7")
	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING_TO_LOADOUT")

	_press_action(&"sanctuary_tab_next")

	assert_int(_tab_strip.get_current_index()).is_equal(0)  # tab strip's own cursor still wraps
	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING_TO_LOADOUT")  # but the hand-off is latched


# ---------------------------------------------------------------------------
# AC-4: gamepad LT/RT mirrors `[`/`]` exactly (same bound action in project.godot)
# ---------------------------------------------------------------------------

func test_trigger_actions_mirror_bracket_cycling() -> void:
	_press_action(&"sanctuary_tab_3")

	# sanctuary_tab_next/prev are bound to both `[`/`]` and the LT/RT trigger
	# axes on the same InputMap action (project.godot) -- dispatching the
	# action itself is the correct way to test "the code reacts identically
	# regardless of which physical input fired it," which is the guarantee
	# that binding is designed to provide.
	_press_action(&"sanctuary_tab_next")
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_DEFENSE_BUILDING")

	_press_action(&"sanctuary_tab_prev")
	_press_action(&"sanctuary_tab_prev")
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_INVENTORY_CRAFTING")


# ---------------------------------------------------------------------------
# AC-5: LB/RB never switch tabs AT THE TAB-STRIP LEVEL. Real InputMap actions
# (room_bumper_left/room_bumper_right) now exist (added 2026-09-01 alongside
# hero_skills_room.gd's own internal sub-navigation, Claude Code) -- but
# TabStrip itself still has no code path referencing them at all (this test
# dispatches the raw InputEventJoypadButton directly, not the mapped action,
# matching this suite's own established direct-_input()-dispatch pattern),
# so this AC's guarantee is unaffected by that addition. A hosted room (like
# the new HeroSkillsRoom) consuming these actions for its OWN internal
# sub-screen toggle is a different, legitimate concern this test does not
# cover -- see hero-skills-room_test.gd (new) for that.
# ---------------------------------------------------------------------------

func test_bumpers_never_change_active_state() -> void:
	_shell.set_active_state(&"ROOM_DEFENSE_BUILDING")
	var index_before: int = _tab_strip.get_current_index()

	var lb_event := InputEventJoypadButton.new()
	lb_event.button_index = JOY_BUTTON_LEFT_SHOULDER
	lb_event.pressed = true
	_tab_strip._input(lb_event)

	var rb_event := InputEventJoypadButton.new()
	rb_event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb_event.pressed = true
	_tab_strip._input(rb_event)

	assert_that(_shell.get_active_state()).is_equal(&"ROOM_DEFENSE_BUILDING")
	assert_int(_tab_strip.get_current_index()).is_equal(index_before)


# ---------------------------------------------------------------------------
# AC-6: onboarding tooltip, once per session, dismissible by any input
# ---------------------------------------------------------------------------

func test_onboarding_tooltip_shown_on_first_mount_this_session() -> void:
	assert_bool(_tab_strip.is_onboarding_tooltip_visible()).is_true()


func test_onboarding_tooltip_not_shown_on_second_mount_same_session() -> void:
	# before_test()'s scene_runner mount is this test's "first mount" already.
	assert_bool(_tab_strip.is_onboarding_tooltip_visible()).is_true()

	var second_shell: SanctuaryUI = SanctuaryUiScene.instantiate()
	add_child(second_shell)
	auto_free(second_shell)
	var second_tab_strip: TabStrip = second_shell.get_node("Chrome/TabStrip") as TabStrip

	assert_bool(second_tab_strip.is_onboarding_tooltip_visible()).is_false()


func test_onboarding_tooltip_dismisses_on_key_input() -> void:
	assert_bool(_tab_strip.is_onboarding_tooltip_visible()).is_true()

	await _runner.simulate_key_pressed(KEY_A)
	await _runner.await_input_processed()

	assert_bool(_tab_strip.is_onboarding_tooltip_visible()).is_false()


func test_onboarding_tooltip_dismisses_on_gamepad_button_input() -> void:
	assert_bool(_tab_strip.is_onboarding_tooltip_visible()).is_true()

	var button_event := InputEventJoypadButton.new()
	button_event.button_index = JOY_BUTTON_A
	button_event.pressed = true
	_tab_strip._input(button_event)

	assert_bool(_tab_strip.is_onboarding_tooltip_visible()).is_false()


# ---------------------------------------------------------------------------
# ADR-0011 (Governing Implementation): InputModeTracker + focus-ring gating.
# Not a numbered GDD AC, but a required implementation guideline of this
# story's own governing ADR -- every focusable widget on a tracked screen
# must gate its focus-ring visual on has_focus() AND
# tracker.is_focus_ring_visible(), never on has_focus() alone.
# ---------------------------------------------------------------------------

func test_focus_ring_hidden_by_default_before_any_keyboard_input() -> void:
	# InputModeTracker defaults to KEYBOARD_GAMEPAD (matches inventory.md's own
	# precedent), but no button has been given UI focus yet -- has_focus() is
	# false for every entry on a fresh mount, so every ring must be hidden.
	for index: int in TabStrip.TAB_TARGETS.size():
		assert_bool(_tab_strip.is_focus_ring_visible(index)).is_false()


func test_focus_ring_visible_when_keyboard_focused_entry_has_focus() -> void:
	# Arrange: force InputModeTracker into KEYBOARD_GAMEPAD deterministically
	# rather than relying on it still being untouched at its default. Root-
	# caused via direct has_focus()/tracker inspection (2026-08-05): grab_focus()
	# itself always succeeds (has_focus() true, viewport focus owner correct) --
	# the flake was GdUnitSceneRunner's own scene-mount warm-up occasionally
	# injecting a real mouse-motion event before this test body runs, flipping
	# the tracker to MOUSE ahead of the assertion below. Not a tab_strip.gd or
	# input_mode_tracker.gd defect -- same category of headless SceneRunner
	# timing quirk this file's own header comment already documents for
	# InputEventAction dispatch, just surfacing here for mouse-motion instead.
	# Direct _input() dispatch (not a GdUnit simulate_* call) matches this
	# file's own established workaround, and doubles as this test's real
	# "keyboard" arrange step given its own name.
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_TAB
	key_event.pressed = true
	_tab_strip.get_input_mode_tracker()._input(key_event)

	_tab_strip.get_tab_button(0).grab_focus()
	assert_bool(_tab_strip.is_focus_ring_visible(0)).is_true()


func test_focus_ring_hidden_after_mouse_input_even_if_focused() -> void:
	# Arrange: same explicit KEYBOARD_GAMEPAD-forcing seen in
	# test_focus_ring_visible_when_keyboard_focused_entry_has_focus above --
	# this test's own first assertion below assumes that starting mode too,
	# before it deliberately flips to MOUSE.
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_TAB
	key_event.pressed = true
	_tab_strip.get_input_mode_tracker()._input(key_event)

	_tab_strip.get_tab_button(0).grab_focus()
	assert_bool(_tab_strip.is_focus_ring_visible(0)).is_true()

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(10, 10)
	# The engine normally calls _input() on every node in the tree
	# independently each frame -- since this suite calls TabStrip._input()
	# directly rather than going through engine dispatch, the sibling
	# InputModeTracker node (which has its own separate _input() override)
	# must be given the same event explicitly too.
	_tab_strip.get_input_mode_tracker()._input(motion)
	_tab_strip._input(motion)

	# grab_focus() only ever moves keyboard/gamepad focus in Godot 4.6 (ADR-0011)
	# -- has_focus() is still true here, but the tracker's mode flipped to
	# MOUSE, so the ring must now be hidden despite focus not having moved.
	assert_bool(_tab_strip.is_focus_ring_visible(0)).is_false()


func test_focus_neighbors_wrap_top_to_bottom_and_bottom_to_top() -> void:
	var count: int = TabStrip.TAB_TARGETS.size()
	var first_button: Button = _tab_strip.get_tab_button(0)
	var last_button: Button = _tab_strip.get_tab_button(count - 1)

	assert_str(str(first_button.focus_neighbor_top)).contains(last_button.name)
	assert_str(str(last_button.focus_neighbor_bottom)).contains(first_button.name)
