## Regression guard for the mission catalogue gap found and fixed 2026-08-07:
## mission-select.md AC-1 requires "the Alpha mission catalogue (4-6
## MissionEntry resources)", but only 2 existed (the_gap, the_narrows), and
## the_narrows' own GridConfig had an empty cells dictionary (declared
## cols/rows but authored zero cells, so every cell implicitly defaulted to
## BLOCKED per GridConfig's own doc comment -- the mission could never
## actually run). Added the_foothills/the_hollow (commit a6dc10c) and fixed
## the_narrows' grid (commit 1214e40).
##
## Exercises the real GGameDataRegistry Autoload (mission entries are
## static, boot-loaded content) and a scratch Grid instance per mission
## (mirrors game_data_registry_test.gd's own real-Autoload-content
## convention -- no injection needed for read-only content checks).
extends GdUnitTestSuite

const REAL_MISSION_IDS: Array[String] = ["the_gap", "the_foothills", "the_hollow", "the_narrows"]


func test_mission_catalogue_has_between_4_and_6_entries() -> void:
	var entries: Dictionary[String, MissionEntry] = GGameDataRegistry.get_all_mission_entries()
	assert_int(entries.size()).is_between(4, 6)


func test_every_real_mission_id_resolves_to_a_valid_entry() -> void:
	for mission_id: String in REAL_MISSION_IDS:
		var entry: MissionEntry = GGameDataRegistry.get_mission_entry(mission_id)
		assert_object(entry).is_not_null()
		assert_array(entry.validate()).is_empty()


## The real bug this guards against: a MissionEntry can pass validate() (it
## only checks cell_size == 64.0, never that any cells were actually
## authored) while still having a fully non-functional grid. Confirms every
## real mission has exactly one SPAWN and at least one GOAL cell once
## initialized into a real Grid.
func test_every_real_mission_grid_has_a_real_spawn_and_goal_cell() -> void:
	for mission_id: String in REAL_MISSION_IDS:
		var entry: MissionEntry = GGameDataRegistry.get_mission_entry(mission_id)
		assert_object(entry).is_not_null()

		var grid := Grid.new()
		grid.initialize(entry.grid_config)

		var spawn_cells: Array[Vector2i] = grid.get_spawn_cells()
		var goal_cells: Array[Vector2i] = grid.get_goal_cells()
		assert_array(spawn_cells) \
			.override_failure_message("mission '%s' has %d SPAWN cells, expected exactly 1 — grid_config.cells may be empty/misauthored" % [mission_id, spawn_cells.size()]) \
			.has_size(1)
		assert_bool(goal_cells.is_empty()) \
			.override_failure_message("mission '%s' has zero GOAL cells — grid_config.cells may be empty/misauthored" % mission_id) \
			.is_false()

		grid.free()


func test_every_real_mission_wave_config_matches_base_wave_count() -> void:
	for mission_id: String in REAL_MISSION_IDS:
		var entry: MissionEntry = GGameDataRegistry.get_mission_entry(mission_id)
		var wave_config: WaveConfig = load(entry.wave_config_path)
		assert_object(wave_config).is_not_null()
		assert_int(wave_config.wave_scripts.size()).is_equal(entry.base_wave_count)
