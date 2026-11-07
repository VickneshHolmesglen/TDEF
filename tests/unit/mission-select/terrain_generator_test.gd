## TerrainGenerator (spec 2026-11-07-3d-terrain §5): every shipped map's
## terrain profile, over many seeds, keeps the map playable.
extends GdUnitTestSuite

const ENTRY_DIR: String = "res://assets/data/missions/entries/"
const SEEDS: int = 200


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _entries() -> Array[MissionEntry]:
	var result: Array[MissionEntry] = []
	for file: String in DirAccess.get_files_at(ENTRY_DIR):
		if file.ends_with("_entry.tres"):
			result.append(load(ENTRY_DIR + file) as MissionEntry)
	return result


func _gen(entry: MissionEntry, seed_value: int) -> GridConfig:
	var g: GridConfig = entry.grid_config
	return MapGenerator.generate(g.cols, g.rows, g.cell_size, _rng(seed_value),
			entry.spawn_count, entry.path_winding, entry.terrain_profile)


func _each_generated(check: Callable) -> void:
	for entry: MissionEntry in _entries():
		for s: int in SEEDS:
			check.call(entry, _gen(entry, 7000 + s))


func test_every_entry_has_a_valid_profile() -> void:
	var entries: Array[MissionEntry] = _entries()
	assert_int(entries.size()).is_equal(12)
	for entry: MissionEntry in entries:
		assert_object(entry.terrain_profile).override_failure_message(entry.mission_id).is_not_null()
		assert_array(entry.terrain_profile.validate()).override_failure_message(entry.mission_id).is_empty()


func test_no_hills_on_path_spawn_goal() -> void:
	_each_generated(func(entry: MissionEntry, cfg: GridConfig) -> void:
		assert_array(cfg.validate()).override_failure_message(entry.mission_id).is_empty()
		for cell: Vector2i in cfg.heights:
			var ct: int = cfg.cells.get(cell, Grid.CellType.BLOCKED)
			assert_int(ct).override_failure_message("%s %s" % [entry.mission_id, cell]).is_equal(Grid.CellType.PLACEABLE))


func test_river_crosses_lane_as_ford() -> void:
	_each_generated(func(entry: MissionEntry, cfg: GridConfig) -> void:
		if entry.terrain_profile.river_count == 0:
			assert_bool(cfg.water.is_empty()).is_true()
			return
		var fords: int = 0
		for cell: Vector2i in cfg.water:
			if cfg.cells.get(cell, -1) == Grid.CellType.PATH:
				fords += 1
		assert_int(fords).override_failure_message(entry.mission_id).is_greater(0))


func test_spawn_reaches_goal() -> void:
	var grid := Grid.new()
	_each_generated(func(entry: MissionEntry, cfg: GridConfig) -> void:
		grid.initialize(cfg)
		var walk: Dictionary[Vector2i, bool] = grid.get_walkable_cell_map()
		var goal: Vector2i = grid.get_goal_cells()[0]
		for spawn: Vector2i in grid.get_spawn_cells():
			var seen: Dictionary[Vector2i, bool] = {spawn: true}
			var queue: Array[Vector2i] = [spawn]
			while not queue.is_empty():
				var c: Vector2i = queue.pop_back()
				for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					if walk.has(c + d) and not seen.has(c + d):
						seen[c + d] = true
						queue.append(c + d)
			assert_bool(seen.has(goal)).override_failure_message(entry.mission_id).is_true())
	grid.free()


func test_min_buildable_share_holds() -> void:
	var floor_share: float = TerrainTuning.load_default().min_buildable_share
	_each_generated(func(entry: MissionEntry, cfg: GridConfig) -> void:
		var interior: int = (cfg.cols - 2) * (cfg.rows - 2)
		var buildable: int = 0
		for cell: Vector2i in cfg.cells:
			if cfg.cells[cell] == Grid.CellType.PLACEABLE and not cfg.water.get(cell, false):
				buildable += 1
		assert_float(float(buildable) / interior).override_failure_message(entry.mission_id) \
				.is_greater_equal(floor_share))


func test_level_two_inside_level_one() -> void:
	_each_generated(func(entry: MissionEntry, cfg: GridConfig) -> void:
		for cell: Vector2i in cfg.heights:
			if cfg.heights[cell] < 2:
				continue
			for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				assert_int(cfg.heights.get(cell + d, 0)).is_greater_equal(1))


func test_hilly_profiles_produce_hills() -> void:
	var foothills: MissionEntry = load(ENTRY_DIR + "the_foothills_entry.tres")
	var cfg: GridConfig = _gen(foothills, 99)
	assert_int(cfg.heights.size()).is_greater(10)
	assert_bool(cfg.heights.values().has(2)).is_true()


func test_same_seed_same_terrain_two_spawns() -> void:
	var profile: TerrainProfile = (load(ENTRY_DIR + "the_twinpass_entry.tres") as MissionEntry).terrain_profile
	var a: GridConfig = MapGenerator.generate(16, 12, 64, _rng(42), 2, 0.5, profile)
	var b: GridConfig = MapGenerator.generate(16, 12, 64, _rng(42), 2, 0.5, profile)
	assert_dict(a.heights).is_equal(b.heights)
	assert_dict(a.water).is_equal(b.water)
	assert_dict(a.cells).is_equal(b.cells)
	assert_bool(a.heights.is_empty() and a.water.is_empty()).is_false()


func test_null_profile_leaves_terrain_empty() -> void:
	var cfg: GridConfig = MapGenerator.generate(16, 12, 64, _rng(3))
	assert_bool(cfg.heights.is_empty()).is_true()
	assert_bool(cfg.water.is_empty()).is_true()
