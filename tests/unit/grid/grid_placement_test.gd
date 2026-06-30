## Tests for Grid placement, occupancy, and write-gate (AC-1 through AC-6, AC-10, AC-12).
## Grid.new() bypasses _ready() — no EventBus Autoload needed.
## State is driven directly via _on_mission_phase_changed().
extends GdUnitTestSuite

const PLACEABLE_CELL := Vector2i(3, 4)
const PATH_CELL := Vector2i(5, 5)
const BLOCKED_CELL := Vector2i(9, 9)  # not in config — implicitly BLOCKED

var _grid: Grid

## Minimal GridConfig: one PLACEABLE cell and one PATH cell.
func _make_config() -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 16
	cfg.rows = 12
	cfg.cell_size = 64.0
	cfg.cells = {
		PLACEABLE_CELL: Grid.CellType.PLACEABLE,
		PATH_CELL: Grid.CellType.PATH,
		Vector2i(2, 2): Grid.CellType.PLACEABLE,
		Vector2i(3, 2): Grid.CellType.PLACEABLE,
		Vector2i(2, 3): Grid.CellType.PLACEABLE,
		Vector2i(3, 3): Grid.CellType.PLACEABLE,
	}
	return cfg

func before_test() -> void:
	_grid = Grid.new()

func after_test() -> void:
	_grid.free()


# ---- AC-10: Safe defaults when UNINITIALIZED ----

func test_grid_uninitialized_get_cell_type_returns_blocked() -> void:
	assert_int(_grid.get_cell_type(PLACEABLE_CELL)).is_equal(Grid.CellType.BLOCKED)

func test_grid_uninitialized_is_placeable_returns_false() -> void:
	assert_bool(_grid.is_placeable(PLACEABLE_CELL)).is_false()

func test_grid_uninitialized_get_all_occupied_cells_returns_empty() -> void:
	assert_int(_grid.get_all_occupied_cells().size()).is_equal(0)

func test_grid_uninitialized_get_spawn_cells_returns_empty() -> void:
	assert_int(_grid.get_spawn_cells().size()).is_equal(0)


# ---- AC-1: Cell type integrity after initialize ----

func test_grid_cell_type_matches_config_after_initialize() -> void:
	_grid.initialize(_make_config())
	assert_int(_grid.get_cell_type(PLACEABLE_CELL)).is_equal(Grid.CellType.PLACEABLE)
	assert_int(_grid.get_cell_type(PATH_CELL)).is_equal(Grid.CellType.PATH)

func test_grid_unconfigured_cell_returns_blocked() -> void:
	_grid.initialize(_make_config())
	assert_int(_grid.get_cell_type(BLOCKED_CELL)).is_equal(Grid.CellType.BLOCKED)


# ---- AC-2: 1×1 placement on PLACEABLE unoccupied cell ----

func test_grid_place_1x1_on_placeable_cell_returns_ok() -> void:
	_grid.initialize(_make_config())
	var result: Error = _grid.place_tower(42, PLACEABLE_CELL, Vector2i(1, 1))
	assert_int(result).is_equal(OK)

func test_grid_place_1x1_sets_occupant() -> void:
	_grid.initialize(_make_config())
	_grid.place_tower(42, PLACEABLE_CELL, Vector2i(1, 1))
	assert_int(_grid.get_occupant(PLACEABLE_CELL)).is_equal(42)

func test_grid_place_1x1_makes_cell_non_placeable() -> void:
	_grid.initialize(_make_config())
	_grid.place_tower(42, PLACEABLE_CELL, Vector2i(1, 1))
	assert_bool(_grid.is_placeable(PLACEABLE_CELL)).is_false()

func test_grid_place_on_occupied_cell_returns_write_rejected() -> void:
	# Arrange
	_grid.initialize(_make_config())
	_grid.place_tower(1, PLACEABLE_CELL, Vector2i(1, 1))
	# Act
	var result: Error = _grid.place_tower(2, PLACEABLE_CELL, Vector2i(1, 1))
	# Assert
	assert_int(result).is_equal(Grid.GRID_WRITE_REJECTED)

func test_grid_place_2x2_with_one_occupied_cell_rejects_atomically() -> void:
	# Arrange: occupy only the top-left cell of the intended 2×2 footprint
	_grid.initialize(_make_config())
	_grid.place_tower(1, Vector2i(2, 2), Vector2i(1, 1))
	# Act: attempt 2×2 placement overlapping the occupied cell
	var result: Error = _grid.place_tower(2, Vector2i(2, 2), Vector2i(2, 2))
	# Assert: rejected, and the three unoccupied cells were not written
	assert_int(result).is_equal(Grid.GRID_WRITE_REJECTED)
	assert_int(_grid.get_occupant(Vector2i(3, 2))).is_equal(-1)
	assert_int(_grid.get_occupant(Vector2i(2, 3))).is_equal(-1)
	assert_int(_grid.get_occupant(Vector2i(3, 3))).is_equal(-1)


# ---- AC-3: 2×2 placement occupies all 4 cells ----

func test_grid_place_2x2_occupies_all_four_cells() -> void:
	_grid.initialize(_make_config())
	_grid.place_tower(7, Vector2i(2, 2), Vector2i(2, 2))
	assert_int(_grid.get_occupant(Vector2i(2, 2))).is_equal(7)
	assert_int(_grid.get_occupant(Vector2i(3, 2))).is_equal(7)
	assert_int(_grid.get_occupant(Vector2i(2, 3))).is_equal(7)
	assert_int(_grid.get_occupant(Vector2i(3, 3))).is_equal(7)


# ---- AC-4: Placement rejected on non-PLACEABLE cell ----

func test_grid_place_on_path_cell_returns_write_rejected() -> void:
	_grid.initialize(_make_config())
	var result: Error = _grid.place_tower(1, PATH_CELL, Vector2i(1, 1))
	assert_int(result).is_equal(Grid.GRID_WRITE_REJECTED)

func test_grid_place_on_path_cell_does_not_change_occupancy() -> void:
	_grid.initialize(_make_config())
	_grid.place_tower(1, PATH_CELL, Vector2i(1, 1))
	assert_int(_grid.get_occupant(PATH_CELL)).is_equal(-1)


# ---- AC-5: Placement rejected during ACTIVE_READONLY ----

func test_grid_place_during_wave_active_returns_write_rejected() -> void:
	_grid.initialize(_make_config())
	_grid._on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)
	var result: Error = _grid.place_tower(1, PLACEABLE_CELL, Vector2i(1, 1))
	assert_int(result).is_equal(Grid.GRID_WRITE_REJECTED)

func test_grid_place_during_wave_active_does_not_change_state() -> void:
	_grid.initialize(_make_config())
	_grid._on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)
	_grid.place_tower(1, PLACEABLE_CELL, Vector2i(1, 1))
	assert_int(_grid.get_occupant(PLACEABLE_CELL)).is_equal(-1)


# ---- AC-6: Tower removal frees all occupied cells ----

func test_grid_remove_tower_2x2_all_cells_cleared() -> void:
	_grid.initialize(_make_config())
	_grid.place_tower(7, Vector2i(2, 2), Vector2i(2, 2))
	_grid.remove_tower(7)
	assert_int(_grid.get_occupant(Vector2i(2, 2))).is_equal(-1)
	assert_int(_grid.get_occupant(Vector2i(3, 2))).is_equal(-1)
	assert_int(_grid.get_occupant(Vector2i(2, 3))).is_equal(-1)
	assert_int(_grid.get_occupant(Vector2i(3, 3))).is_equal(-1)

func test_grid_remove_tower_makes_cells_placeable_again() -> void:
	_grid.initialize(_make_config())
	_grid.place_tower(7, Vector2i(2, 2), Vector2i(2, 2))
	_grid.remove_tower(7)
	assert_bool(_grid.is_placeable(Vector2i(2, 2))).is_true()
	assert_bool(_grid.is_placeable(Vector2i(3, 3))).is_true()

func test_grid_remove_tower_a_leaves_tower_b_intact() -> void:
	# Arrange: place two distinct towers
	_grid.initialize(_make_config())
	_grid.place_tower(1, PLACEABLE_CELL, Vector2i(1, 1))
	_grid.place_tower(2, Vector2i(2, 2), Vector2i(1, 1))
	# Act: remove only tower 1
	_grid.remove_tower(1)
	# Assert: tower 1 gone, tower 2 unaffected
	assert_int(_grid.get_occupant(PLACEABLE_CELL)).is_equal(-1)
	assert_int(_grid.get_occupant(Vector2i(2, 2))).is_equal(2)


# ---- AC-12: Mission restart clears occupancy ----

func test_grid_defeat_phase_clears_all_occupancy() -> void:
	_grid.initialize(_make_config())
	_grid.place_tower(99, PLACEABLE_CELL, Vector2i(1, 1))
	_grid._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)
	assert_int(_grid.get_occupant(PLACEABLE_CELL)).is_equal(-1)

func test_grid_scout_after_defeat_reenables_writes() -> void:
	# Arrange: full cycle through to DEFEAT
	_grid.initialize(_make_config())
	_grid._on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)
	_grid._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)
	# Act: SCOUT fires (mission restart — _cell_types still populated from prior initialize)
	_grid._on_mission_phase_changed("DEFEAT", "SCOUT", 0.0)
	var result: Error = _grid.place_tower(1, PLACEABLE_CELL, Vector2i(1, 1))
	# Assert: writes are re-enabled
	assert_int(result).is_equal(OK)
