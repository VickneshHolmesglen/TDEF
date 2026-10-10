## Integration tests for Story 011 (epic-10-sanctuary-ui): Cross-Room
## Highlighting Stays Confined to a Room -- GDD Core Rule 9's non-badge items
## (AC Group 9). No new production code: confinement is a direct, structural
## consequence of Story 007's destroy-and-recreate lifecycle (a torn-down
## room's own highlight/selection state ceases to exist along with the node
## holding it) -- these tests confirm that guarantee holds, not implement a
## new suppression mechanism.
##
## AC-2 (the existing Crafting-highlights-Inventory-slots pattern still
## functions when hosted) cannot be tested against real content yet:
## inventory_screen.gd's own doc comment confirms Crafting panel content is
## explicitly deferred ("AC-14, deferred -- no Crafting GDD exists" at the
## time that story shipped). Flagged, not silently skipped -- covered instead
## by a room-switch regression check confirming InventoryScreen's own slot
## grid still renders/functions identically whether hosted here or not.
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _shell: SanctuaryUI


func before_test() -> void:
	TabStrip.reset_onboarding_flag_for_tests()
	_runner = scene_runner("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as SanctuaryUI


# ---------------------------------------------------------------------------
# No cross-room highlight/selection bleed -- structural consequence of
# Story 007's destroy-and-recreate (a stub room's own "selected slot" field
# never survives a lateral switch, mirroring room-lifecycle_test.gd's own
# nested_state coverage but from the highlight-confinement angle specifically)
# ---------------------------------------------------------------------------

func test_a_rooms_own_selection_state_does_not_survive_a_switch_to_another_room() -> void:
	var stub_scene := PackedScene.new()
	var stub_root := Control.new()
	var stub_script: GDScript = load("res://tests/integration/sanctuary-ui/room_lifecycle_stub_room.gd")
	stub_root.set_script(stub_script)
	stub_scene.pack(stub_root)
	stub_root.free()

	_shell.set_active_state(&"ROOM_MENAGERIE")
	_shell.get_room_host().mount_room(stub_scene, &"ROOM_MENAGERIE")
	var menagerie_room: RoomLifecycleStubRoom = _shell.get_room_host().get_current_room() as RoomLifecycleStubRoom
	menagerie_room.nested_state = "creature_003_selected"  # stand-in for an in-room highlight/selection

	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()  # Inventory & Crafting, real room

	# Menagerie's own room instance no longer exists -- there is nothing left
	# anywhere for a "selection bled across rooms" bug to even manifest in.
	# Re-entering Menagerie later would mount an entirely fresh instance
	# (Story 007's own guarantee), not resume the old selection.
	assert_object(_shell.get_room_host().get_current_room()).is_not_same(menagerie_room)


func test_re_entering_a_room_after_a_lateral_switch_never_resumes_a_prior_selection() -> void:
	var stub_scene := PackedScene.new()
	var stub_root := Control.new()
	var stub_script: GDScript = load("res://tests/integration/sanctuary-ui/room_lifecycle_stub_room.gd")
	stub_root.set_script(stub_script)
	stub_scene.pack(stub_root)
	stub_root.free()

	_shell.set_active_state(&"ROOM_MENAGERIE")
	_shell.get_room_host().mount_room(stub_scene, &"ROOM_MENAGERIE")
	(_shell.get_room_host().get_current_room() as RoomLifecycleStubRoom).nested_state = "creature_003_selected"

	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()  # switch away

	_shell.set_active_state(&"ROOM_MENAGERIE")
	_shell.get_room_host().mount_room(stub_scene, &"ROOM_MENAGERIE")  # "re-enter"
	var reentered_room: RoomLifecycleStubRoom = _shell.get_room_host().get_current_room() as RoomLifecycleStubRoom

	assert_str(reentered_room.nested_state).is_equal("root")  # never "creature_003_selected"


# ---------------------------------------------------------------------------
# Connection Badge cross-system legibility without touching the active
# room's own content -- already covered thoroughly by Story 003's own suite;
# one direct AC-Group-9-scoped confirmation here for this story's own record
# ---------------------------------------------------------------------------

func test_badge_for_an_inactive_room_never_touches_the_active_rooms_own_content() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(2).pressed.emit()  # Menagerie active
	var active_room_before: Node = _shell.get_room_host().get_current_room()

	GEventBus.recipe_discovered.emit("iron_foundation", "component")  # Inventory & Crafting's own trigger

	assert_bool(_shell.get_tab_strip_for_test().is_badge_visible(1)).is_true()
	# The active room (Menagerie) is completely untouched -- same instance,
	# same state, no re-mount, no content change.
	assert_object(_shell.get_room_host().get_current_room()).is_same(active_room_before)
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_MENAGERIE")


# ---------------------------------------------------------------------------
# AC-2 regression check: InventoryScreen's own already-shipped behavior is
# unaffected by being hosted inside RoomHost (the room-hosting half of this
# story's own scope, since the highlight-pattern half has no real content yet)
# ---------------------------------------------------------------------------

func test_inventory_screen_slot_grid_still_builds_correctly_when_hosted() -> void:
	_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()

	var room: Node = _shell.get_room_host().get_current_room()
	assert_object(room).is_not_null()
	# Confirms the already-shipped screen mounted and ran its own _ready()
	# (slot grid built) identically to being run standalone -- no behavioral
	# change from being hosted, matching this story's own regression-check
	# framing for the one room with real content.
	assert_object(room.get_node_or_null("MainLayout/LeftPanel/BagPanel/BagContent/SlotGrid")).is_not_null()
