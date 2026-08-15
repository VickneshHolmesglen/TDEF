## Integration tests for Story 001 (epic-10-sanctuary-ui, ADR-0002): Structural
## Model — Full-Frame Diorama, RoomHost, Persistent Chrome (GDD Core Rule 1,
## AC Group 1).
##
## SanctuaryUI.tscn is loaded and instanced directly rather than hand-built
## (unlike mission_hud's MissionHudTestHelper precedent) — this story
## deliberately builds SanctuaryUI as its own standalone scene (a divergence
## from mission_hud's inline-only convention, since Sanctuary UI is not yet
## wired into any parent scene), so the real .tscn IS the fixture and a
## separate hand-rolled helper would only duplicate its node tree.
extends GdUnitTestSuite

const SanctuaryUiScene: PackedScene = preload("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")

const ROOM_STATES: Array[StringName] = [
	&"ROOM_INVENTORY_CRAFTING",
	&"ROOM_MENAGERIE",
	&"ROOM_DEFENSE_BUILDING",
	&"ROOM_EQUIPMENT_FORGE",
]

var _shell: SanctuaryUI


func before_test() -> void:
	_shell = SanctuaryUiScene.instantiate()
	add_child(_shell)


func after_test() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.queue_free()
	_shell = null


# ---------------------------------------------------------------------------
# AC-1: diorama node persists across room entry (shell-owned, never freed)
# ---------------------------------------------------------------------------

func test_diorama_node_persists_across_room_entry() -> void:
	var diorama_before: Control = _shell.get_diorama()
	var instance_id_before: int = diorama_before.get_instance_id()

	_shell.set_active_state(&"ROOM_INVENTORY_CRAFTING")

	assert_bool(is_instance_valid(diorama_before)).is_true()
	assert_int(_shell.get_diorama().get_instance_id()).is_equal(instance_id_before)


func test_diorama_node_persists_across_all_four_rooms() -> void:
	var instance_id_before: int = _shell.get_diorama().get_instance_id()

	for room_state: StringName in ROOM_STATES:
		_shell.set_active_state(room_state)
		assert_bool(is_instance_valid(_shell.get_diorama())).is_true()
		assert_int(_shell.get_diorama().get_instance_id()).is_equal(instance_id_before)


# ---------------------------------------------------------------------------
# AC-2: room root rect equals RoomHost rect (frame minus tab strip / header)
# ---------------------------------------------------------------------------

func test_room_host_rect_equals_frame_minus_tab_strip_and_header() -> void:
	_shell.size = Vector2(1920.0, 1080.0)
	_shell.set_active_state(&"ROOM_INVENTORY_CRAFTING")

	var room_host: Control = _shell.get_room_host()
	var expected_position := Vector2(SanctuaryUI.TAB_STRIP_WIDTH, SanctuaryUI.HEADER_HEIGHT)
	var expected_size: Vector2 = _shell.size - expected_position

	assert_vector(room_host.position).is_equal(expected_position)
	assert_vector(room_host.size).is_equal(expected_size)


# ---------------------------------------------------------------------------
# AC-3: diorama rect equals the same frame-minus-chrome region while OVERVIEW
# ---------------------------------------------------------------------------

func test_diorama_rect_equals_frame_minus_tab_strip_and_header_when_overview_active() -> void:
	_shell.size = Vector2(1920.0, 1080.0)
	_shell.set_active_state(SanctuaryUI.OVERVIEW_STATE)

	var diorama: Control = _shell.get_diorama()
	var expected_position := Vector2(SanctuaryUI.TAB_STRIP_WIDTH, SanctuaryUI.HEADER_HEIGHT)
	var expected_size: Vector2 = _shell.size - expected_position

	assert_vector(diorama.position).is_equal(expected_position)
	assert_vector(diorama.size).is_equal(expected_size)


# ---------------------------------------------------------------------------
# Player-reported 2026-08-16: "a lot of grey area" -- Diorama/RoomHost's
# content zone had no background fill, rendering on Godot's raw default
# clear color. Fix: ContentBackground, a UI_CHROME-filled ColorRect sized to
# the exact same rect, sitting behind both.
# ---------------------------------------------------------------------------

func test_content_background_uses_ui_chrome_color() -> void:
	assert_bool(_shell._content_background.color.is_equal_approx(ShellChromeStyle.UI_CHROME)).is_true()


func test_content_background_rect_equals_frame_minus_tab_strip_and_header() -> void:
	_shell.size = Vector2(1920.0, 1080.0)

	var background: ColorRect = _shell._content_background
	var expected_position := Vector2(SanctuaryUI.TAB_STRIP_WIDTH, SanctuaryUI.HEADER_HEIGHT)
	var expected_size: Vector2 = _shell.size - expected_position

	assert_vector(background.position).is_equal(expected_position)
	assert_vector(background.size).is_equal(expected_size)


# ---------------------------------------------------------------------------
# AC-4: chrome (tab strip + resource header) always present and rendering
# ---------------------------------------------------------------------------

func test_chrome_present_and_visible_when_overview_active() -> void:
	_shell.set_active_state(SanctuaryUI.OVERVIEW_STATE)

	assert_bool(_shell.get_node("Chrome/TabStrip").visible).is_true()
	assert_bool(_shell.get_node("Chrome/ResourceHeader").visible).is_true()


func test_chrome_present_and_visible_in_every_room_state() -> void:
	for room_state: StringName in ROOM_STATES:
		_shell.set_active_state(room_state)
		assert_bool(_shell.get_node("Chrome/TabStrip").visible).is_true()
		assert_bool(_shell.get_node("Chrome/ResourceHeader").visible).is_true()


# ---------------------------------------------------------------------------
# Structural mutual exclusivity underpinning AC-1/AC-2/AC-3 together
# ---------------------------------------------------------------------------

func test_room_host_hidden_and_diorama_visible_when_overview_active() -> void:
	_shell.set_active_state(SanctuaryUI.OVERVIEW_STATE)

	assert_bool(_shell.get_diorama().visible).is_true()
	assert_bool(_shell.get_room_host().visible).is_false()


func test_diorama_hidden_and_room_host_visible_when_room_state_active() -> void:
	_shell.set_active_state(&"ROOM_MENAGERIE")

	assert_bool(_shell.get_diorama().visible).is_false()
	assert_bool(_shell.get_room_host().visible).is_true()
