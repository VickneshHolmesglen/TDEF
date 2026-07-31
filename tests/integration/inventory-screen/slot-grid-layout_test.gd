## Integration test for InventoryScreen's slot-grid layout across viewport
## sizes (TD-ui-002 item 2). Live-verified via Godot MCP before this fix:
## GridContainer's default size_flags_horizontal (SIZE_FILL) stretched
## SlotGrid's own bounding rect to fill LeftPanel's full width, but did NOT
## stretch its columns to match, leaving up to ~675px of dead space between
## the slot grid and RightPanel at the default viewport while all 10
## fixed-size 64x64 slot buttons stayed clustered in the top-left corner.
## inventory_screen.gd now sets SIZE_SHRINK_BEGIN on SlotGrid — this test
## proves the grid stays at its own natural content size (not the parent's
## full width) at more than one resolution, closing the "not yet performed"
## gap this entry originally flagged.
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	GInventory.reset_to_defaults()
	_runner = scene_runner("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn")
	_screen = _runner.scene() as Control


func after_test() -> void:
	GInventory.reset_to_defaults()


func _slot_grid() -> Control:
	return _screen.get_node("MainLayout/LeftPanel/SlotGrid") as Control


func _left_panel() -> Control:
	return _screen.get_node("MainLayout/LeftPanel") as Control


func test_slot_grid_stays_at_its_natural_content_width_not_the_left_panels_full_width() -> void:
	# Container sizes are only valid after at least one layout/sort_children
	# pass -- a freshly-mounted scene_runner() scene reports .size == 0 for
	# every Container until the tree processes one frame.
	await _screen.get_tree().process_frame

	var grid: Control = _slot_grid()
	var left_panel: Control = _left_panel()

	# LeftPanel is genuinely wider than the grid's natural content -- if this
	# fails, the two are equal-width, meaning the fixture no longer exercises
	# the dead-space scenario this test exists to guard against.
	assert_float(left_panel.size.x).is_greater(grid.get_combined_minimum_size().x)
	assert_vector(grid.size).is_equal_approx(grid.get_combined_minimum_size(), Vector2(1.0, 1.0))


func test_slot_grid_natural_width_is_unaffected_by_viewport_resize() -> void:
	var grid: Control = _slot_grid()
	var natural_width: float = grid.get_combined_minimum_size().x

	_screen.get_viewport().size = Vector2i(1920, 1080)
	await _screen.get_tree().process_frame
	await _screen.get_tree().process_frame

	assert_float(grid.size.x).is_equal_approx(natural_width, 1.0)

	_screen.get_viewport().size = Vector2i(1024, 600)
	await _screen.get_tree().process_frame
	await _screen.get_tree().process_frame

	assert_float(grid.size.x).is_equal_approx(natural_width, 1.0)
