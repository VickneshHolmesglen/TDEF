extends GdUnitTestSuite

## TerrainSurface (spec 2026-11-07-3d-terrain §6.1/§6.4): smooth height field
## from cell levels, flat lane, sunken water, screen lift and height-aware picking.

const CELL := 64.0
const PITCH := 50.0


## 12x10 board, PATH row y=1 (with a ford at (8,1)), a 5x5 level-1 blob on
## cells (3..7, 3..7), water at (10,5).
static func _config() -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 12
	cfg.rows = 10
	cfg.cell_size = CELL
	var cells: Dictionary[Vector2i, int] = {}
	for x: int in 12:
		for y: int in 10:
			cells[Vector2i(x, y)] = Grid.CellType.PATH if y == 1 else Grid.CellType.PLACEABLE
	cfg.cells = cells
	var heights: Dictionary[Vector2i, int] = {}
	for x: int in range(3, 8):
		for y: int in range(3, 8):
			heights[Vector2i(x, y)] = 1
	cfg.heights = heights
	cfg.water = {Vector2i(10, 5): true, Vector2i(8, 1): true}
	return cfg


func _surface() -> TerrainSurface:
	return TerrainSurface.from_config(_config(), TerrainTuning.load_default())


func test_flat_config_returns_null() -> void:
	var cfg: GridConfig = _config()
	cfg.heights = {}
	cfg.water = {}
	assert_object(TerrainSurface.from_config(cfg, TerrainTuning.load_default())).is_null()


func test_hilltop_height_equals_level_height() -> void:
	var h: float = _surface().height_at(Vector2(5.5, 5.5) * CELL)
	assert_float(h).is_equal_approx(0.5 * CELL, 0.05 * 0.5 * CELL)


func test_slopes_are_smooth_between_levels() -> void:
	var s: TerrainSurface = _surface()
	var edge: float = s.height_at(Vector2(5.5, 3.0) * CELL)  # the blob's top edge
	assert_float(edge).is_between(0.2 * CELL, 0.3 * CELL)


func test_path_cells_flat_zero() -> void:
	var s: TerrainSurface = _surface()
	assert_float(s.height_at(Vector2(5.5, 1.5) * CELL)).is_equal_approx(0.0, 0.5)
	assert_float(s.height_at(Vector2(0.5, 1.5) * CELL)).is_equal_approx(0.0, 0.5)


func test_water_below_zero() -> void:
	var s: TerrainSurface = _surface()
	assert_float(s.height_at(Vector2(10.5, 5.5) * CELL)).is_less(s.water_level())
	var ford: float = s.height_at(Vector2(8.5, 1.5) * CELL)
	assert_float(ford).is_equal_approx(-0.09 * CELL, 0.5)
	assert_float(ford).is_less(s.water_level())
	assert_float(s.water_level()).is_equal_approx(-0.07 * CELL, 0.001)


func test_screen_lift_cos_pitch() -> void:
	var s: TerrainSurface = _surface()
	var p := Vector2(5.5, 5.5) * CELL
	assert_float(s.screen_lift(p, PITCH)).is_equal_approx(s.height_at(p) * cos(deg_to_rad(PITCH)), 0.001)


func test_screen_to_ground_flat_identity() -> void:
	var s: TerrainSurface = _surface()
	var p := Vector2(10.5, 8.5) * CELL
	var g: Vector2 = s.screen_to_ground(p, PITCH)
	assert_float(g.x).is_equal(p.x)
	assert_float(g.y).is_equal_approx(p.y, 1.0)


func test_screen_to_ground_front_face_hits_hilltop() -> void:
	var s: TerrainSurface = _surface()
	var top := Vector2(5.5, 7.2) * CELL  # near the blob's front (camera-side) edge
	var screen := Vector2(top.x, top.y - s.screen_lift(top, PITCH))
	assert_int(int(floor(screen.y / CELL))).is_equal(6)  # flat maths would pick row 6
	var g: Vector2 = s.screen_to_ground(screen, PITCH)
	assert_int(int(floor(g.y / CELL))).is_equal(7)
	assert_float(g.y).is_equal_approx(top.y, 1.0)


## With the shipped tuning (0.5 cell per level, sigma 0.45 cell) the steepest
## slope is about 0.9 px/px, gentler than the 1/cos(50°) ≈ 1.56 a slope needs to
## hide anything behind it: rolling hills never occlude at this camera.
func test_shipped_hills_never_occlude() -> void:
	var s: TerrainSurface = _surface()
	for y: float in [2.0, 2.4, 2.6, 2.8, 3.0, 3.2]:
		assert_bool(s.occludes(Vector2(5.5, y) * CELL, PITCH)).is_false()


func test_occludes_spot_behind_tall_hill() -> void:
	var tall := TerrainTuning.new()
	tall.height_per_level_cells = 2.5
	var s: TerrainSurface = TerrainSurface.from_config(_config(), tall)
	# Just behind (north of) the blob's top edge: the steep hill is drawn over it.
	assert_bool(s.occludes(Vector2(5.5, 2.6) * CELL, PITCH)).is_true()
	# Open ground far from any hill, and the hilltop itself.
	assert_bool(s.occludes(Vector2(10.5, 8.5) * CELL, PITCH)).is_false()
	assert_bool(s.occludes(Vector2(5.5, 5.5) * CELL, PITCH)).is_false()


## Guard for spec §6.4 "hidden spots": the x-ray / fade for things behind hills
## is not built because the shipped hills can't hide anything at the 50°
## camera. If a tuning or profile change makes them steep enough to, this fails
## and the readability work (a stencil-masked tower silhouette) is needed.
func test_shipped_maps_hide_nothing() -> void:
	var dir := "res://assets/data/missions/entries/"
	for file: String in DirAccess.get_files_at(dir):
		if not file.ends_with("_entry.tres"):
			continue
		var entry: MissionEntry = load(dir + file)
		for s: int in 5:
			var rng := RandomNumberGenerator.new()
			rng.seed = 900 + s
			var g: GridConfig = entry.grid_config
			var cfg: GridConfig = MapGenerator.generate(g.cols, g.rows, g.cell_size, rng, entry.spawn_count,
					entry.path_winding, entry.terrain_profile)
			var surface: TerrainSurface = TerrainSurface.from_config(cfg, TerrainTuning.load_default())
			if surface == null:
				continue
			for cell: Vector2i in cfg.cells:
				var p: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * cfg.cell_size
				assert_bool(surface.occludes(p, PITCH)).override_failure_message("%s %s" % [entry.mission_id, cell]).is_false()
