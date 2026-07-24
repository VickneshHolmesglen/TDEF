## Regression test for a real bug found 2026-07-20: `GridConfig.cells` was
## missing `@export`, so no GridConfig authored as a .tres could ever
## actually persist its cell layout — ResourceSaver.save() silently dropped
## it. Discovered via `the_gap_entry.tres` (Mission Select's real mission
## entry) shipping with 0 cells for this exact reason, causing the real
## Mission Select launch/retry pipeline to hand WaveManager a 0-spawn-cell
## grid and hard-fail every real (non-debug-direct-boot) mission launch.
extends GdUnitTestSuite

const TEST_TRES_PATH: String = "res://tests/unit/grid/.grid_config_persistence_test_tmp.tres"


func after_test() -> void:
	if ResourceLoader.exists(TEST_TRES_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_TRES_PATH))


func test_cells_survives_a_save_and_fresh_disk_load() -> void:
	var config := GridConfig.new()
	config.cols = 3
	config.rows = 2
	config.cell_size = 64.0
	config.cells[Vector2i(0, 0)] = Grid.CellType.SPAWN
	config.cells[Vector2i(2, 1)] = Grid.CellType.GOAL

	var save_err: Error = ResourceSaver.save(config, TEST_TRES_PATH)
	assert_int(save_err).is_equal(OK)

	# CACHE_MODE_IGNORE forces a genuine read from disk, not the in-memory
	# instance already cached from the save() call above — this is what
	# actually caught the original bug (in-memory reads looked fine).
	var reloaded: GridConfig = ResourceLoader.load(TEST_TRES_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)

	assert_int(reloaded.cells.size()).is_equal(2)
	assert_int(reloaded.cells[Vector2i(0, 0)]).is_equal(Grid.CellType.SPAWN)
	assert_int(reloaded.cells[Vector2i(2, 1)]).is_equal(Grid.CellType.GOAL)
