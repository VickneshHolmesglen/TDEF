extends GdUnitTestSuite

## The flat 2D grid view (no scenery profile) still shows terrain (spec
## 2026-11-07-3d-terrain §6.4): hills tinted per level, water blue.

const GRID_VISUAL := preload("res://src/gameplay/missions/the_gap/grid_visual.gd")


func before_test() -> void:
	var cfg: GridConfig = load("res://tests/unit/grid/grid_terrain_test.gd").make_config()
	cfg.heights[Vector2i(0, 3)] = 2
	GGrid.initialize(cfg)


func after_test() -> void:
	GGrid.initialize(GridConfig.new())


func test_grid_visual_tints_hill_and_water() -> void:
	var plain: Color = GRID_VISUAL.cell_color(Vector2i(0, 0))
	var hill1: Color = GRID_VISUAL.cell_color(Vector2i(3, 2))
	var hill2: Color = GRID_VISUAL.cell_color(Vector2i(0, 3))
	var water: Color = GRID_VISUAL.cell_color(Vector2i(4, 2))
	assert_float(plain.a).is_equal(0.0)
	for c: Color in [hill1, hill2, water]:
		assert_bool(c != plain).is_true()
	assert_bool(hill1 != hill2 and hill1 != water and hill2 != water).is_true()
	assert_float(hill2.a).is_greater(hill1.a)
	assert_float(water.b).is_greater(water.r)
