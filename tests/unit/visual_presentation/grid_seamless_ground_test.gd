## Unit tests for grid_visual.gd's seamless ground layer (2026-10-06): PLACEABLE cells are cut from
## one tileable layer so the tile art's dark rim and mismatched edges never form a grid.
extends GdUnitTestSuite

const GridVisualScript: GDScript = preload("res://src/gameplay/missions/the_gap/grid_visual.gd")


## A source whose rim is black and whose interior is a left-to-right gradient, so a visible seam
## or a leftover rim would both show up as a pixel mismatch.
func _source() -> Image:
	var img := Image.create(100, 80, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	for y: int in range(8, 72):
		for x: int in range(8, 92):
			img.set_pixel(x, y, Color(x / 100.0, y / 80.0, 0.5))
	return img


func test_seamless_ground_has_the_requested_size() -> void:
	var ground: Image = GridVisualScript.build_seamless_ground(_source(), 250, 130, 40)

	assert_vector(Vector2(ground.get_size())).is_equal(Vector2(250, 130))


func test_seamless_ground_trims_the_dark_rim() -> void:
	var ground: Image = GridVisualScript.build_seamless_ground(_source(), 120, 120, 40)

	assert_float(ground.get_pixel(0, 0).r + ground.get_pixel(0, 0).g).is_greater(0.1)


func test_seamless_ground_repeats_join_without_a_seam() -> void:
	var ground: Image = GridVisualScript.build_seamless_ground(_source(), 160, 160, 40)

	for y: int in range(0, 160, 7):
		var left: Color = ground.get_pixel(39, y)
		var right: Color = ground.get_pixel(40, y)
		assert_float(absf(left.r - right.r) + absf(left.g - right.g)).is_less(0.02)
	for x: int in range(0, 160, 7):
		var top: Color = ground.get_pixel(x, 39)
		var bottom: Color = ground.get_pixel(x, 40)
		assert_float(absf(top.r - bottom.r) + absf(top.g - bottom.g)).is_less(0.02)


## A horizontal lane tile: red kerb on the top 20%, blue kerb on the bottom 20%, green lane between.
func _lane_tile() -> Image:
	var img := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	img.fill(Color.GREEN)
	img.fill_rect(Rect2i(0, 0, 100, 20), Color.RED)
	img.fill_rect(Rect2i(0, 80, 100, 20), Color.BLUE)
	return img


func test_lane_parts_surface_has_no_edging_in_it() -> void:
	var parts: Dictionary = GridVisualScript.build_lane_parts(_lane_tile(), "horizontal", 0.2, 200, 200, 40, 60)

	var surface: Image = parts["surface"]
	for p: Vector2i in [Vector2i(0, 0), Vector2i(59, 59), Vector2i(100, 120), Vector2i(199, 199)]:
		assert_float(surface.get_pixel(p.x, p.y).g).is_greater(0.8)


func test_lane_parts_strips_are_cell_long_and_band_thick() -> void:
	var parts: Dictionary = GridVisualScript.build_lane_parts(_lane_tile(), "horizontal", 0.2, 200, 200, 40, 60)

	assert_vector(Vector2((parts[Vector2i.UP] as Image).get_size())).is_equal(Vector2(40, 8))
	assert_vector(Vector2((parts[Vector2i.LEFT] as Image).get_size())).is_equal(Vector2(8, 40))


func test_lane_parts_side_strips_reuse_the_tile_edging_turned_outward() -> void:
	var parts: Dictionary = GridVisualScript.build_lane_parts(_lane_tile(), "horizontal", 0.2, 200, 200, 40, 60)

	assert_float((parts[Vector2i.UP] as Image).get_pixel(20, 4).r).is_greater(0.8)
	assert_float((parts[Vector2i.LEFT] as Image).get_pixel(4, 20).r).is_greater(0.8)
	assert_float((parts[Vector2i.DOWN] as Image).get_pixel(20, 4).b).is_greater(0.8)
	assert_float((parts[Vector2i.RIGHT] as Image).get_pixel(4, 20).b).is_greater(0.8)
