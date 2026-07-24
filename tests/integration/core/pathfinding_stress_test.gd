## S4-10 — AC-3 (corrected spawn-burst scenario): wave-start monster spawn
## burst pathfinding cost measurement.
##
## GDD OQ-6's original framing ("when path_invalidated fires, up to 150
## monsters simultaneously call get_path() to refresh") describes a mechanism
## that does NOT exist in shipped code:
## src/core/monster/monster_manager.gd::_on_path_invalidated() is an explicit
## no-op ("Dead code at MVP (Grid locks tower writes during WAVE_ACTIVE).
## Kept for post-MVP."). The only real find_path() call site is
## src/core/monster/monster_manager.gd:286, once per monster AT SPAWN.
## See docs/tech-debt-register.md's new stale-GDD-text entry for the tracked
## documentation-accuracy debt this discrepancy leaves behind.
##
## Real spawn cadence found in assets/data/waves/the_gap_waves.tres: every
## WaveSpawnEntry has pre_delay in [2.0, 5.0] seconds, and
## src/gameplay/wave_manager.gd::_run_spawn_sequence() awaits
## get_tree().create_timer(entry.pre_delay).timeout between spawn entries
## whenever pre_delay > 0.0. So in shipped wave data, 150 monsters do NOT
## spawn within the same or adjacent physics frames — spawns are staggered
## several seconds apart.
##
## This test still measures the "150 find_path() calls in one frame" scenario
## as a SYNTHETIC WORST-CASE UPPER BOUND, per the story's approved
## approximation (a loop of N find_path() calls in one frame, each
## independently sourced, approximates what a true same-frame burst would
## cost if it ever occurred) — it is NOT an observed real spawn pattern in
## shipped content. Looping find_path() from the same SPAWN cell is itself a
## realistic sub-case: multiple monsters spawning from the same SPAWN cell in
## the same frame each call find_path(spawn_cell, tier) independently, so this
## is not purely synthetic in its per-call shape — only the "all 150 in one
## frame" timing assumption is a stress upper bound rather than an observed
## real-world frame.
extends GdUnitTestSuite

const BURST_SIZE: int = 150
const MONSTER_PHYSICS_BUDGET_MS: float = 2.0          # Monster System AC-28
const PATHFINDING_RESIDUAL_BUDGET_MS: float = 10.67   # pathfinding.md frame-budget accounting


## Same snake-corridor grid builder as combat_loop_test.gd's S4-10 helper.
## Duplicated locally — this codebase's test files do not share a common
## test-utility module, so each file keeps its own fixture helpers (matches
## the pre-existing convention of per-file `_make_config()` helpers seen in
## tests/unit/pathfinding/pathfinding_template_test.gd).
func _make_snake_grid_config(cols: int, rows: int, path_len_after_spawn: int) -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = cols
	cfg.rows = rows
	cfg.cell_size = 64.0
	var total_cells: int = path_len_after_spawn + 1  # +1 for the SPAWN cell itself
	var visited: Array[Vector2i] = []
	var row: int = 0
	while visited.size() < total_cells and row < rows:
		var left_to_right: bool = (row % 2 == 0)
		for col_i: int in range(cols):
			if visited.size() >= total_cells:
				break
			var col: int = col_i if left_to_right else (cols - 1 - col_i)
			visited.append(Vector2i(col, row))
		row += 1
	assert(visited.size() == total_cells, "Grid too small for requested snake path length — increase rows or cols.")
	var cells: Dictionary[Vector2i, int] = {}
	for i: int in range(visited.size()):
		var ct: int = Grid.CellType.PATH
		if i == 0:
			ct = Grid.CellType.SPAWN
		elif i == visited.size() - 1:
			ct = Grid.CellType.GOAL
		cells[visited[i]] = ct
	cfg.cells = cells
	return cfg


func _setup_isolated_pathfinding(cols: int, rows: int, path_len_after_spawn: int) -> Dictionary:
	var grid := Grid.new()
	var event_bus := EventBus.new()
	var pathfinding := PathfindingSystem.new()
	pathfinding._inject(grid, event_bus)
	add_child(event_bus)
	add_child(grid)
	add_child(pathfinding)
	grid.initialize(_make_snake_grid_config(cols, rows, path_len_after_spawn))
	pathfinding._on_mission_phase_changed("", "SCOUT", 0.0)
	return {
		"grid": grid,
		"event_bus": event_bus,
		"pathfinding": pathfinding,
		"spawn_cell": grid.get_spawn_cells()[0],
	}


func _teardown_isolated_pathfinding(ctx: Dictionary) -> void:
	(ctx.pathfinding as PathfindingSystem).queue_free()
	(ctx.grid as Grid).queue_free()
	(ctx.event_bus as EventBus).queue_free()


func test_pathfinding_stress_150_monster_spawn_burst_single_frame_cost() -> void:
	# Arrange: warm 16x12 grid (avg path 25) — same shape as AC-4's grid, since
	# a spawn burst hits the SAME O(1) warm-template find_path() call site any
	# ordinary spawn does; there is no separate "burst" code path to measure.
	var ctx: Dictionary = _setup_isolated_pathfinding(16, 12, 25)
	var pathfinding: PathfindingSystem = ctx.pathfinding
	var spawn_cell: Vector2i = ctx.spawn_cell

	# Act: simulate BURST_SIZE independent monsters spawning from the same
	# SPAWN cell within a single physics frame (worst-case approximation —
	# see file header for why this over-states the real, staggered cadence).
	var t0: int = Time.get_ticks_usec()
	for _i: int in range(BURST_SIZE):
		pathfinding.find_path(spawn_cell, 0)
	var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0

	_teardown_isolated_pathfinding(ctx)

	# Report (measurement-only per story scope — AC-3 is not a hard pass/fail
	# gate; PASS/WARNING/FAIL below is an informational note, not an assertion,
	# matching this suite's established profiler-test convention).
	var monster_budget_verdict: String = "PASS"
	if elapsed_ms > MONSTER_PHYSICS_BUDGET_MS:
		monster_budget_verdict = "FAIL"
	elif elapsed_ms > MONSTER_PHYSICS_BUDGET_MS * 0.5:
		monster_budget_verdict = "WARNING"
	var residual_budget_verdict: String = "PASS" if elapsed_ms <= PATHFINDING_RESIDUAL_BUDGET_MS else "FAIL"

	print("[PROFILER] pathfinding-only cost of %d find_path() calls in one frame (warm 16x12 grid, avg path 25): %.4fms" % [BURST_SIZE, elapsed_ms])
	print("[PROFILER] vs Monster System AC-28 2ms physics budget: %s (pathfinding-only cost; does not include real MonsterManager._physics_process() work)" % monster_budget_verdict)
	print("[PROFILER] vs pathfinding.md 10.67ms residual frame budget: %s" % residual_budget_verdict)
	print("[PROFILER] NOTE — real wave data (assets/data/waves/the_gap_waves.tres) stages spawns via pre_delay in [2.0, 5.0]s per WaveSpawnEntry; a true same-frame 150-monster burst is not observed in shipped content. This measurement is a synthetic worst-case upper bound.")

	# Sanity assertion only — confirms the measurement actually ran and
	# produced a real, non-negative number. No hard perf gate per story scope.
	assert_bool(elapsed_ms >= 0.0).is_true()
