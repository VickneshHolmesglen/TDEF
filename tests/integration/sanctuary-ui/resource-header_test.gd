## Integration tests for Story 004 (epic-10-sanctuary-ui, ADR-0001): Persistent
## Resource Header -- read-only materials display, updates on the real
## EventBus deltas, never focusable (GDD Core Rule 3, AC Group 3).
##
## Gold deliberately NOT covered here (2026-08-06, design/quick-specs/
## sanctuary-header-drop-gold-2026-08-06.md) -- see resource_header.gd's own
## class doc for why a persistent Sanctuary gold display was never correct
## (gold is mission-scoped ephemeral budget, ADR-0018, no carry-over
## mechanic exists). Mission HUD's own gold display is unaffected and still
## covered by tests/integration/mission-hud/combat-cluster-live-data_test.gd.
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _shell: SanctuaryUI
var _header: ResourceHeader


func before_test() -> void:
	_runner = scene_runner("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as SanctuaryUI
	_header = _shell.get_resource_header()


# ---------------------------------------------------------------------------
# Displays identically regardless of active state
# ---------------------------------------------------------------------------

func test_header_value_identical_across_overview_and_room_states() -> void:
	GEventBus.materials_earned.emit("wood", 5, "test_source")

	assert_int(_header.get_material_quantity("wood")).is_equal(5)

	_shell.set_active_state(&"ROOM_MENAGERIE")

	# Header is chrome, held outside the OVERVIEW/RoomHost branch entirely
	# (Story 001's own AC-4 guarantee) -- its own accumulated values are
	# untouched by an active-state switch.
	assert_int(_header.get_material_quantity("wood")).is_equal(5)


# ---------------------------------------------------------------------------
# Sequential event updates apply in order, no stale intermediate value
# ---------------------------------------------------------------------------

func test_sequential_events_apply_in_order() -> void:
	GEventBus.materials_earned.emit("wood", 10, "test_source")
	assert_int(_header.get_material_quantity("wood")).is_equal(10)

	GEventBus.materials_spent.emit("wood", 3, "test_destination")
	assert_int(_header.get_material_quantity("wood")).is_equal(7)


# ---------------------------------------------------------------------------
# Never focusable / not a navigable region
# ---------------------------------------------------------------------------

func test_header_never_receives_focus() -> void:
	assert_int(_header.focus_mode).is_equal(Control.FOCUS_NONE)

	_header.grab_focus()

	assert_bool(_header.has_focus()).is_false()


# ---------------------------------------------------------------------------
# Gold explicitly absent (2026-08-06) -- regression guard against gold
# silently creeping back into this header.
# ---------------------------------------------------------------------------

func test_gold_is_not_displayed_or_tracked() -> void:
	GEventBus.resources_changed.emit(999, &"test_source")

	assert_bool(_header.has_method("get_gold")).is_false()
	assert_bool(_header.get_node_or_null("ResourceRow/GoldIcon") == null).is_true()
	assert_bool(_header.get_node_or_null("ResourceRow/GoldLabel") == null).is_true()


func test_materials_text_updates_and_scale_pop_still_works() -> void:
	GEventBus.materials_earned.emit("wood", 4, &"test_source")

	var materials_label: Label = _header.get_node("MaterialsLabel")
	assert_str(materials_label.text).contains("wood 4")


## 2026-10-07: the readout no longer shares the 320 px plaque with the title
## (only one material fit); it sits in the strip to the plaque's right.
func test_materials_readout_sits_right_of_the_plaque_not_inside_it() -> void:
	var materials_label: Label = _header.get_node("MaterialsLabel")
	assert_object(_header.get_node_or_null("ResourceRow/MaterialsLabel")).is_null()
	assert_float(materials_label.position.x).is_greater_equal(_header.size.x)
