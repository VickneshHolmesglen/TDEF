## Integration tests for Story 012 (epic-10-sanctuary-ui, ADR-0001/ADR-0011):
## Load-Bearing Edge Cases -- rapid input mashing, staged-discard toast,
## Watchtower/no-room click, mount-time resource poll under a boot-order race
## (GDD's own Load-Bearing Edge Cases section).
##
## 3 of this story's 4 items hit gaps already flagged by earlier stories, not
## newly discovered here -- confirmed directly rather than silently assumed:
## - Staged-discard TOAST half: no toast UI exists yet (Story 013's own
##   Visual/Feel scope). The DATA-gone half is fully real and tested below
##   (identical mechanism Story 010 already proved for its own Loadout case).
## - Watchtower/no-room click: the Sanctuary-overview diorama has no structure
##   representation or click interaction anywhere in this project yet (Story
##   001's Diorama is still an empty placeholder Control, and no later story
##   in this epic added structure rendering) -- there is no "click a
##   structure" mechanism to test at all, not a bug, a not-yet-built feature.
## - Mount-time resource poll: already confirmed not implementable in Story
##   004 (no system owns a queryable Sanctuary-context gold/materials
##   balance) -- not re-litigated here, cross-referenced only.
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _shell: SanctuaryUI


func before_test() -> void:
	TabStrip.reset_onboarding_flag_for_tests()
	_runner = scene_runner("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as SanctuaryUI


func _press_hotkey(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_shell.get_tab_strip_for_test()._input(event)


# ---------------------------------------------------------------------------
# Rapid input mashing: only the last-targeted room ends up mounted, no
# errors, no stale connections from torn-down intermediate rooms
# ---------------------------------------------------------------------------

func test_rapid_hotkey_mashing_through_5_targets_leaves_only_the_last_mounted() -> void:
	# Faster than any single room's own mount-complete callback could fire --
	# no awaits between presses, exactly the adversarial-timing case this AC
	# targets. Sequence: Inventory & Crafting (real room) -> Menagerie ->
	# Defense Building -> Equipment Forge -> Overview.
	_press_hotkey(&"sanctuary_tab_2")
	_press_hotkey(&"sanctuary_tab_3")
	_press_hotkey(&"sanctuary_tab_4")
	_press_hotkey(&"sanctuary_tab_5")
	_press_hotkey(&"sanctuary_tab_1")

	assert_that(_shell.get_active_state()).is_equal(&"OVERVIEW")
	assert_object(_shell.get_room_host().get_current_room()).is_null()
	# GdUnit's own orphan-node detection (checked at suite teardown, visible
	# in the run's own "orphans" count) is the direct verification that every
	# intermediate room+tracker pair (Inventory & Crafting's real screen
	# among them) was actually freed, not merely unmounted from RoomHost's
	# own reference -- a stale/leaked node would show up there.


func test_rapid_mashing_through_all_6_tab_strip_entries_produces_no_errors() -> void:
	# Includes Loadout (index 6) -- since select_loadout() latches _departing
	# permanently, this is deliberately the LAST press in the sequence (a
	# press after it would be a no-op by design, not part of what this AC
	# tests: the mashing itself must not error, not that departing can be
	# un-departed).
	_press_hotkey(&"sanctuary_tab_3")
	_press_hotkey(&"sanctuary_tab_4")
	_press_hotkey(&"sanctuary_tab_5")
	_press_hotkey(&"sanctuary_tab_2")
	_press_hotkey(&"sanctuary_tab_6")

	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING_TO_LOADOUT")
	assert_object(_shell.get_room_host().get_current_room()).is_null()


# ---------------------------------------------------------------------------
# Staged-discard: DATA half only (real, tested) -- the TOAST half is Story
# 013's own Visual/Feel scope, flagged not fabricated
# ---------------------------------------------------------------------------

func test_staged_room_state_is_gone_after_switching_away_via_hotkey() -> void:
	var stub_scene := PackedScene.new()
	var stub_root := Control.new()
	var stub_script: GDScript = load("res://tests/integration/sanctuary-ui/room_lifecycle_stub_room.gd")
	stub_root.set_script(stub_script)
	stub_scene.pack(stub_root)
	stub_root.free()

	_shell.set_active_state(&"ROOM_EQUIPMENT_FORGE")
	_shell.get_room_host().mount_room(stub_scene, &"ROOM_EQUIPMENT_FORGE")
	var room: RoomLifecycleStubRoom = _shell.get_room_host().get_current_room() as RoomLifecycleStubRoom
	room.nested_state = "unconfirmed_imbue_staged"

	_press_hotkey(&"sanctuary_tab_1")  # switch away via hotkey, matching this AC's own trigger

	assert_object(_shell.get_room_host().get_current_room()).is_not_same(room)
	# The staged data's own node no longer exists anywhere -- same guarantee
	# already proven structurally by Story 007/010's own equivalent tests.


# ---------------------------------------------------------------------------
# Watchtower / no-room click: no diorama structure-click mechanism exists to
# test -- confirmed directly, not assumed
# ---------------------------------------------------------------------------

func test_diorama_has_no_structure_click_mechanism_yet_confirmed_not_assumed() -> void:
	# Updated 2026-07-25 (Story 013): the Diorama gained a real `World`
	# container + placeholder structure rendering (diorama.gd) -- it is no
	# longer Story 001's empty placeholder, so a bare `get_child_count() == 0`
	# check would now be testing a stale assumption instead of the real gap.
	# The real gap this test verifies is unchanged and still real: no
	# structure/habitat is a *clickable secondary entry path* into a room
	# (GDD Core Rule 1's "click a structure -> enter its room" mechanism) --
	# diorama.gd's own structure rendering has no click/input handling of any
	# kind, confirmed directly against the real node it now instantiates.
	GEventBus.sanctuary_structure_built.emit("watchtower_tier_1", "watchtower")
	var world: Node2D = _shell.get_diorama().call("get_world")
	var structure: Node = world.get_child(0)
	assert_bool(structure is ColorRect).is_true()  # a plain placeholder rect
	# No click/room-entry handler is wired to it at all -- confirmed by its
	# gui_input signal having zero connections, not merely "it's a rect."
	assert_array((structure as ColorRect).gui_input.get_connections()).is_empty()
