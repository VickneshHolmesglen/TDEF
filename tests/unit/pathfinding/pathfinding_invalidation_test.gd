## Tests for deferred dirty rebuild, deduplication, WAVE_ACTIVE guard, and BOSS auto-rebuild.
## Covers: GDD AC-9a, AC-23, AC-26 (partial), AC-27; ADR-0004 validation criteria.
##
## Note: call_deferred tests require await get_tree().physics_frame to flush the deferred call.
extends GdUnitTestSuite

const SPAWN_CELL := Vector2i(0, 0)
const GOAL_CELL := Vector2i(4, 0)
const PLACEABLE_A := Vector2i(0, 1)
const PLACEABLE_B := Vector2i(1, 1)
const PLACEABLE_C := Vector2i(2, 1)

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
		PLACEABLE_C: Grid.CellType.PLACEABLE,
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


# ---- AC-27: is_rebuild_pending() reflects _rebuild_queued state ----

func test_pathfinding_is_rebuild_pending_false_before_any_tower_event() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	assert_bool(_pathfinding.is_rebuild_pending()).is_false()


func test_pathfinding_is_rebuild_pending_true_after_tower_placed_on_route_cell() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	# Place tower on PATH cell (1,0) which IS in the template — marks template dirty
	_place_tower_on_route_cell()
	assert_bool(_pathfinding.is_rebuild_pending()).is_true()


func test_pathfinding_is_rebuild_pending_false_after_deferred_rebuild_flushes() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	_place_tower_on_route_cell()
	assert_bool(_pathfinding.is_rebuild_pending()).is_true()
	# Flush deferred call
	await get_tree().process_frame
	assert_bool(_pathfinding.is_rebuild_pending()).is_false()


# ---- AC-9a: two tower events in same frame → exactly one path_invalidated with union ----

func test_pathfinding_two_tower_events_same_frame_produce_one_path_invalidated() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	var state := {"count": 0, "cells": []}
	_event_bus.path_invalidated.connect(func(cells):
		state.count += 1
		state.cells.assign(cells)
	)
	# Inject two tower_placed events in the same frame (no await between them).
	# Both footprints intersect the template path.
	_simulate_tower_placed(1, Vector2i(1, 0), Vector2i(1, 1))
	_simulate_tower_placed(2, Vector2i(2, 0), Vector2i(1, 1))
	# Flush deferred rebuild
	await get_tree().process_frame
	# Exactly 1 path_invalidated, affected_cells = union of both footprints
	assert_int(state.count).is_equal(1)
	assert_bool(Vector2i(1, 0) in state.cells).is_true()
	assert_bool(Vector2i(2, 0) in state.cells).is_true()
	assert_int(state.cells.size()).is_equal(2)


func test_pathfinding_affected_cells_has_no_duplicates_for_overlapping_footprints() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	var state := {"cells": []}
	_event_bus.path_invalidated.connect(func(cells): state.cells.assign(cells))
	# Two events covering the same cell
	_simulate_tower_placed(1, Vector2i(1, 0), Vector2i(1, 1))
	_simulate_tower_placed(2, Vector2i(1, 0), Vector2i(1, 1))
	await get_tree().process_frame
	# cell (1,0) should appear exactly once
	var dupe_count: int = 0
	for c: Vector2i in state.cells:
		if c == Vector2i(1, 0):
			dupe_count += 1
	assert_int(dupe_count).is_equal(1)


# ---- AC-23: tower_placed during WAVE_ACTIVE triggers push_error, no path_invalidated ----

func test_pathfinding_tower_placed_during_wave_active_does_not_emit_path_invalidated() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	# Transition to WAVE_ACTIVE
	_pathfinding._on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)
	var invalidated_count: int = 0
	_event_bus.path_invalidated.connect(func(_c): invalidated_count += 1)
	# Inject tower_placed directly on EventBus (bypasses Grid lock — defense-in-depth test)
	_simulate_tower_placed(99, Vector2i(1, 0), Vector2i(1, 1))
	await get_tree().process_frame
	assert_int(invalidated_count).is_equal(0)


# ---- AC-16: tower_destroyed during WAVE_ACTIVE does not queue rebuild immediately ----

func test_pathfinding_tower_destroyed_during_wave_active_does_not_emit_path_invalidated() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	_pathfinding._on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)
	var invalidated_count: int = 0
	_event_bus.path_invalidated.connect(func(_c): invalidated_count += 1)
	_event_bus.tower_destroyed.emit(1, Vector2i(1, 0), "basic", [Vector2i(1, 0)])
	await get_tree().process_frame
	assert_int(invalidated_count).is_equal(0)


# ---- AC-26 (partial): BOSS auto-rebuild fires at INTERMISSION entry ----

func test_pathfinding_boss_destroyed_during_wave_causes_rebuild_at_intermission() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	_pathfinding._on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)
	# BOSS destroys a tower during WAVE_ACTIVE
	_event_bus.tower_destroyed.emit(1, Vector2i(1, 0), "basic", [Vector2i(1, 0)])
	var state := {"count": 0}
	_event_bus.path_invalidated.connect(func(_c): state.count += 1)
	# Transition to INTERMISSION should trigger auto-rebuild.
	# call_deferred() fires at end of current idle frame; process_frame fires before
	# the deferred queue drains, so we need two frame boundaries to be certain.
	_pathfinding._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(state.count).is_equal(1)


# ---- Rebuild does not fire when no templates are dirty ----

func test_pathfinding_tower_placed_on_non_route_cell_does_not_queue_rebuild() -> void:
	_grid.initialize(_make_config())
	_pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	# Place tower on PLACEABLE cell that is NOT in the template's cell_index_map
	# The template only contains SPAWN→PATH→GOAL cells, not PLACEABLE cells
	_simulate_tower_placed(1, PLACEABLE_A, Vector2i(1, 1))
	# No dirty templates → rebuild should NOT be queued
	assert_bool(_pathfinding.is_rebuild_pending()).is_false()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _simulate_tower_placed(tower_id: int, grid_position: Vector2i, footprint_size: Vector2i) -> void:
	_event_bus.tower_placed.emit(tower_id, grid_position, "basic", footprint_size, true)


func _place_tower_on_route_cell() -> void:
	# PATH cell (1,0) is in the template — triggers dirty marking
	_simulate_tower_placed(1, Vector2i(1, 0), Vector2i(1, 1))
