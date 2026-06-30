## Foundation boot-order integration test — ADR-0002 / TR-gc-002.
## Verifies all 4 Foundation Autoloads are present and can inter-operate correctly.
## Split into two groups:
##   - Singleton access: proves Godot loaded each Autoload in the correct order.
##   - Functional integration: proves cross-Autoload signal chains work end-to-end.
extends GdUnitTestSuite

const SPAWN_CELL := Vector2i(0, 0)
const GOAL_CELL  := Vector2i(2, 0)

var _event_bus: EventBus
var _grid: Grid
var _pathfinding: PathfindingSystem


func _make_minimal_config() -> GridConfig:
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


func before_test() -> void:
	_event_bus = EventBus.new()
	_grid = Grid.new()
	_pathfinding = PathfindingSystem.new()
	_pathfinding._inject(_grid, _event_bus)
	add_child(_event_bus)
	add_child(_grid)
	add_child(_pathfinding)


func after_test() -> void:
	_pathfinding.queue_free()
	_grid.queue_free()
	_event_bus.queue_free()


# ---- AC-1: EventBus global singleton loaded ----

func test_foundation_boot_event_bus_global_singleton_accessible_and_correct_type() -> void:
	var node: Node = get_node_or_null("/root/GEventBus")
	assert_object(node).is_not_null()
	assert_bool(node is EventBus).is_true()


# ---- AC-2: SavePersistence global singleton loaded after EventBus ----

func test_foundation_boot_save_persistence_global_singleton_accessible_and_correct_type() -> void:
	var node: Node = get_node_or_null("/root/GSavePersistence")
	assert_object(node).is_not_null()
	assert_bool(node is SavePersistence).is_true()


# ---- AC-3: Grid global singleton loaded ----

func test_foundation_boot_grid_global_singleton_accessible_and_correct_type() -> void:
	var node: Node = get_node_or_null("/root/GGrid")
	assert_object(node).is_not_null()
	assert_bool(node is Grid).is_true()


# ---- AC-4: PathfindingSystem global singleton loaded after Grid ----

func test_foundation_boot_pathfinding_system_global_singleton_accessible_and_correct_type() -> void:
	var node: Node = get_node_or_null("/root/GPathfindingSystem")
	assert_object(node).is_not_null()
	assert_bool(node is PathfindingSystem).is_true()


# ---- AC-5: Grid -> PathfindingSystem: templates build when Grid is initialized before SCOUT ----

func test_foundation_boot_pathfinding_builds_templates_when_grid_initialized_before_scout() -> void:
	_grid.initialize(_make_minimal_config())
	var state := {"received": false}
	_event_bus.templates_ready.connect(func(_c, _ms): state.received = true)
	_event_bus.mission_phase_changed.emit("", "SCOUT", 0.0)
	assert_bool(state.received).is_true()


# ---- AC-6: EventBus -> PathfindingSystem signal chain fires exactly once ----

func test_foundation_boot_event_bus_signal_chain_reaches_pathfinding_exactly_once() -> void:
	_grid.initialize(_make_minimal_config())
	var state := {"count": 0}
	_event_bus.templates_ready.connect(func(_c, _ms): state.count += 1)
	_event_bus.mission_phase_changed.emit("", "SCOUT", 0.0)
	assert_int(state.count).is_equal(1)


# ---- AC-7: Full integration: get_path() returns valid route after boot sequence ----

func test_foundation_boot_full_sequence_get_path_returns_route_ending_at_goal() -> void:
	_grid.initialize(_make_minimal_config())
	_event_bus.mission_phase_changed.emit("", "SCOUT", 0.0)
	var path: Array[Vector2i] = _pathfinding.find_path(SPAWN_CELL, 0)
	assert_bool(path.is_empty()).is_false()
	assert_object(path.back()).is_equal(GOAL_CELL)
	assert_bool(SPAWN_CELL in path).is_false()
