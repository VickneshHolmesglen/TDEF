## Content-integrity regression test for `assets/data/missions/entries/the_gap_entry.tres`.
##
## Real bug found 2026-07-20: this shipped mission entry's `grid_config` had
## 0 cells (GridConfig.cells was missing @export — fixed in grid_config.gd),
## so launching "the_gap" through the real Mission Select pipeline
## (confirm_launch()/retry_current_mission()) handed WaveManager a 0-spawn-
## cell grid, triggering an immediate MISSION_COMPLETE bypass instead of a
## real playable mission. the_gap.tscn's own direct-boot debug path was
## unaffected (it builds its GridConfig programmatically, never touching
## this .tres) — only the real launch pipeline was broken. This test loads
## the actual shipped file, not a synthetic fixture.
extends GdUnitTestSuite


func test_the_gap_entry_grid_config_has_a_real_layout() -> void:
	var entry: MissionEntry = ResourceLoader.load(
		"res://assets/data/missions/entries/the_gap_entry.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	)

	assert_object(entry.grid_config).is_not_null()
	assert_int(entry.grid_config.cells.size()).is_equal(entry.grid_config.cols * entry.grid_config.rows)
	assert_int(entry.grid_config.cells.get(Vector2i(0, 6), -1)).is_equal(Grid.CellType.SPAWN)
	assert_int(entry.grid_config.cells.get(Vector2i(15, 6), -1)).is_equal(Grid.CellType.GOAL)


func test_the_gap_entry_grid_config_matches_the_real_scenes_own_layout() -> void:
	var entry: MissionEntry = ResourceLoader.load(
		"res://assets/data/missions/entries/the_gap_entry.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	)
	var the_gap_script: Script = load("res://src/gameplay/missions/the_gap/the_gap.gd")
	var probe: Node = the_gap_script.new()
	var real_config: GridConfig = probe.call("_build_grid_config")
	probe.free()

	assert_int(entry.grid_config.cells.size()).is_equal(real_config.cells.size())
	for cell: Vector2i in real_config.cells:
		assert_int(entry.grid_config.cells.get(cell, -1)).is_equal(real_config.cells[cell])
