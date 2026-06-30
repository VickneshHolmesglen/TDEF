## Tests for PathfindingSystem template build, get_path slices, fallback A*, and mission restart.
## Covers: GDD AC-1, AC-3, AC-11, AC-14, AC-19, AC-25; ADR-0004 validation criteria.
##
## Setup: Grid + EventBus instances injected before _ready() via _inject().
## Template building is triggered by calling _on_mission_phase_changed("", "SCOUT", 0.0)
## directly — this is the same code path as the EventBus subscription in production.
extends GdUnitTestSuite

# Test map: SPAWN(0,0) → PATH(1,0) → PATH(2,0) → PATH(3,0) → GOAL(4,0)
# Extra row for mid-route slice tests and PLACEABLE cells for block tests.
const SPAWN_CELL := Vector2i(0, 0)
const GOAL_CELL := Vector2i(4, 0)
const MID_CELL := Vector2i(2, 0)   # middle of the route
const PLACEABLE_A := Vector2i(0, 1)
const PLACEABLE_B := Vector2i(1, 1)

var _grid: Grid
var _event_bus: EventBus
var _pathfinding: PathfindingSystem

func _make_config() -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 5
	cfg.rows = 3
	cfg.cell_size = 64.0
	cfg.cells = {
		Vector2i(0, 0): Grid.CellType.SPAWN,
		Vector2i(1, 0): Grid.CellType.PATH,
		Vector2i(2, 0): Grid.CellType.PATH,
		Vector2i(3, 0): Grid.CellType.PATH,
		Vector2i(4, 0): Grid.CellType.GOAL,
		PLACEABLE_A: Grid.CellType.PLACEABLE,
		PLACEABLE_B: Grid.CellType.PLACEABLE,
	}
	return cfg

## Alternate config with a different route — used in mission-restart tests.
func _make_config_g2() -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 3
	cfg.rows = 1
	cfg.cell_size = 64.0
	cfg.cells = {
		Vector2i(0, 0): Grid.CellType.SPAWN,
		Vector2i(1, 0): Grid.CellType.PATH,
		Vector2i(2, 0): Grid.CellType.GOAL,
	}
	return cfg

## Config with no SPAWN cells.
func _make_config_no_spawn() -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 3
	cfg.rows = 1
	cfg.cell_size = 64.0
	cfg.cells = {
		Vector2i(1, 0): Grid.CellType.PATH,
		Vector2i(2, 0): Grid.CellType.GOAL,
	}
	return cfg

func before_test() -> void:
	_grid = Grid.new()
	_event_bus = EventBus.new()
	_pathfinding = PathfindingSystem.new()
	_pathfinding._inject(_grid, _event_bus)
	add_child(_event_bus)
	add_child(_grid)
	add_child(_pathfinding)

func after_test() -> void:
	_pathfinding.queue_free()
	_grid.queue_free()
	_event_bus.queue_free()


# ---- AC-1 / AC-14: templates_ready fires after SCOUT with correct spawn_count ----

func test_pathfinding_templates_ready_emitted_after_scout_with_correct_spawn_count() -> void:
	# Arrange
	_grid.initialize(_make_config())
	var state := {"count": 0, "spawn": -1, "ms": -1.0}
	_event_bus.templates_ready.connect(func(count, ms):
		state.count += 1
		state.spawn = count
		state.ms = ms
	)
	# Act
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	# Assert
	assert_int(state.count).is_equal(1)      # emitted exactly once
	assert_int(state.spawn).is_equal(1)      # 1 SPAWN cell
	assert_bool(state.ms > 0.0).is_true()


func test_pathfinding_templates_ready_not_emitted_before_scout() -> void:
	_grid.initialize(_make_config())
	var emitted: bool = false
	_event_bus.templates_ready.connect(func(_a, _b): emitted = true)
	# templates_ready should not fire on init — only on SCOUT
	assert_bool(emitted).is_false()


# ---- AC-1 / AC-3: get_path from spawn returns path ending at GOAL ----

func test_pathfinding_get_path_from_spawn_returns_nonempty_array_ending_at_goal() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	# Act
	var result: Array[Vector2i] = _pathfinding.find_path(SPAWN_CELL, 0)
	# Assert
	assert_bool(result.is_empty()).is_false()
	assert_object(result.back()).is_equal(GOAL_CELL)


func test_pathfinding_get_path_from_spawn_excludes_spawn_cell_itself() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	var result: Array[Vector2i] = _pathfinding.find_path(SPAWN_CELL, 0)
	# SPAWN cell itself must not appear in the returned slice (F3: slice(idx+1))
	assert_bool(SPAWN_CELL in result).is_false()


# ---- AC-3: get_path from mid-route cell returns correct slice ----

func test_pathfinding_get_path_from_mid_cell_excludes_mid_cell() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	var result: Array[Vector2i] = _pathfinding.find_path(MID_CELL, 0)
	assert_bool(MID_CELL in result).is_false()


func test_pathfinding_get_path_from_mid_cell_ends_at_goal() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	var result: Array[Vector2i] = _pathfinding.find_path(MID_CELL, 0)
	assert_bool(result.is_empty()).is_false()
	assert_object(result.back()).is_equal(GOAL_CELL)


func test_pathfinding_get_path_from_mid_cell_is_contiguous_cardinal_steps() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	var result: Array[Vector2i] = _pathfinding.find_path(MID_CELL, 0)
	for i: int in range(result.size() - 1):
		var dx: int = abs(result[i + 1].x - result[i].x)
		var dy: int = abs(result[i + 1].y - result[i].y)
		# Cardinal adjacency: exactly one step, no diagonal
		assert_int(dx + dy).is_equal(1)


# ---- AC-3: get_path at GOAL cell returns [] ----

func test_pathfinding_get_path_from_goal_cell_returns_empty_array() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	var result: Array[Vector2i] = _pathfinding.find_path(GOAL_CELL, 0)
	assert_bool(result.is_empty()).is_true()


# ---- AC-11: fallback A* fires for off-template cell ----

func test_pathfinding_fallback_fires_for_off_template_cell_sets_warning() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	# PLACEABLE_A is in _spawn_assignment but not in the template's cell_index_map
	# (templates only cache route cells, not PLACEABLE cells)
	var result: Array[Vector2i] = _pathfinding.find_path(PLACEABLE_A, 0)
	# last_fallback_warning should be non-empty (fallback fired)
	assert_str(_pathfinding.last_fallback_warning).is_not_empty()
	# Result must be [] or non-empty Array[Vector2i] (two-value contract, no crash)
	assert_bool(result is Array).is_true()


# ---- Pre-init guard: get_path before templates_ready ----

func test_pathfinding_get_path_before_templates_built_returns_empty() -> void:
	_grid.initialize(_make_config())
	# Do NOT trigger SCOUT — templates not built
	var result: Array[Vector2i] = _pathfinding.find_path(SPAWN_CELL, 0)
	assert_bool(result.is_empty()).is_true()


# ---- AC-19: no SPAWN or GOAL cells → push_error, no templates_ready ----

func test_pathfinding_no_spawn_cells_does_not_emit_templates_ready() -> void:
	_grid.initialize(_make_config_no_spawn())
	var emitted: bool = false
	_event_bus.templates_ready.connect(func(_a, _b): emitted = true)
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	assert_bool(emitted).is_false()


func test_pathfinding_no_spawn_cells_get_path_returns_empty() -> void:
	_grid.initialize(_make_config_no_spawn())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	var result: Array[Vector2i] = _pathfinding.find_path(Vector2i(1, 0), 0)
	assert_bool(result.is_empty()).is_true()


# ---- AC-25: mission restart — old G1 cells return [] after G2 restart ----

func test_pathfinding_restart_g1_route_cell_not_in_g2_templates_returns_empty() -> void:
	# Arrange: build G1 templates
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	# G1 specific cell: MID_CELL = (2,0) exists in G1 but not in G2 config (G2 is 3 cols)
	# Wait — G2 config has cols=3 so (2,0) IS a cell. Let me use (3,0) which is G1-only.
	var g1_only_cell := Vector2i(3, 0)
	# Confirm G1 has a template for this cell
	var g1_path: Array[Vector2i] = _pathfinding.find_path(g1_only_cell, 0)
	assert_bool(g1_path.is_empty()).is_false()  # sanity check
	# Act: restart with G2
	_pathfinding._on_mission_phase_changed("SCOUT", "DEFEAT", 0.0)
	_grid._on_mission_phase_changed("SCOUT", "DEFEAT", 0.0)
	_grid.initialize(_make_config_g2())
	_pathfinding._on_mission_phase_changed("DEFEAT", "SCOUT", 0.0)
	# Assert: G1-only cell is no longer in any template
	var g2_path: Array[Vector2i] = _pathfinding.find_path(g1_only_cell, 0)
	assert_bool(g2_path.is_empty()).is_true()


func test_pathfinding_restart_templates_ready_fires_with_g2_spawn_count() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	_pathfinding._on_mission_phase_changed("SCOUT", "DEFEAT", 0.0)
	_grid._on_mission_phase_changed("SCOUT", "DEFEAT", 0.0)
	_grid.initialize(_make_config_g2())
	var state := {"count": 0, "spawn": -1}
	_event_bus.templates_ready.connect(func(count, _ms): state.count += 1; state.spawn = count)
	_pathfinding._on_mission_phase_changed("DEFEAT", "SCOUT", 0.0)
	assert_int(state.count).is_equal(1)      # emitted exactly once for G2
	assert_int(state.spawn).is_equal(1)      # G2 has 1 SPAWN
