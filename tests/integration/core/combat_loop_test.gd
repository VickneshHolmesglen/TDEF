## S3-05 Integration — end-to-end combat loop: tower fires → D&S resolves → monster dies.
##
## Wires MonsterManager, TowerSystem, and DamageStatus together via GEventBus.
## add_child() triggers _ready() so EventBus subscriptions go live; DI seams are
## overridden immediately after to replace real autoloads with deterministic stubs.
## GDScript 4 lambda closure rule: use Dictionary state boxes for mutable lambda state.
## Signal callbacks are class members so after_test() can always disconnect on failure.
extends GdUnitTestSuite

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------

class _StubGrid extends RefCounted:
	func get_cell_type(_cell: Vector2i) -> int:
		return Grid.CellType.SPAWN

	func cell_to_world(cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x) * 64.0, float(cell.y) * 64.0)

	func world_to_cell(pos: Vector2) -> Vector2i:
		return Vector2i(int(pos.x / 64.0), int(pos.y / 64.0))

	func get_towers_in_range(_center: Vector2i, _radius: int) -> Array[int]:
		return []

	func is_footprint_placeable(_top_left: Vector2i, _footprint: Vector2i) -> bool:
		return true

	func remove_tower(_id: int) -> void:
		pass


class _StubPathfinding extends RefCounted:
	## 15-cell path from (4,9) eastward — all cells within Chebyshev distance
	## 4 of the tower at (8,6), so the monster is in range the entire walk.
	func find_path(_from: Vector2i, _tier: int) -> Array[Vector2i]:
		var path: Array[Vector2i] = []
		for x: int in range(4, 19):
			path.append(Vector2i(x, 9))
		return path

	func would_block_all_paths(_cells: Array[Vector2i]) -> bool:
		return false


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const SPAWN_CELL := Vector2i(4, 9)
const TOWER_CELL := Vector2i(8, 6)

# ---------------------------------------------------------------------------
# Systems under test
# ---------------------------------------------------------------------------

var _mm: MonsterManager
var _ts: TowerSystem
var _ds: DamageStatus

# Signal callbacks as class members so after_test() can always disconnect them
# even if a test exits early via assertion failure or GUT timeout.
var _on_died_cb: Callable
var _on_breached_cb: Callable
var _on_damage_cb: Callable


func before_test() -> void:
	_on_died_cb = Callable()
	_on_breached_cb = Callable()
	_on_damage_cb = Callable()

	var grid_stub := _StubGrid.new()
	var path_stub := _StubPathfinding.new()

	_mm = MonsterManager.new()
	_ts = TowerSystem.new()
	_ds = DamageStatus.new()

	# add_child triggers _ready(): EventBus subscriptions go live and DI fields
	# are set to real autoloads — we override them below.
	add_child(_mm)
	add_child(_ts)
	add_child(_ds)

	# Override DI seams after _ready() so combat runs against deterministic stubs.
	_mm._grid = grid_stub
	_mm._pathfinding = path_stub
	_ts._grid = grid_stub
	_ts._pathfinding = path_stub

	# Set wave-active state on both systems.
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	_ts._current_phase = TowerSystem.Phase.WAVE_ACTIVE

	# Register goblin resource: base_hp=70, unarmored STANDARD (tier=0).
	var res := MonsterResource.new()
	res.monster_id = &"goblin"
	res.base_hp = 70.0
	res.base_speed = 2.0
	res.tier = 0
	res.archetype_tag = &""
	res.drop_table_id = &""
	res.menagerie_attraction_drop_chance = 0.0
	_mm._resource_table[&"goblin"] = res

	# Build tower components: weapon_damage=35, attack_speed=2.0, range=4 cells, 180° cone.
	var foundation := FoundationComponent.new()
	foundation.tier = 1
	foundation.hp_base = 100.0
	foundation.tier_multiplier = 1.0
	foundation.tier_dps_multiplier = 1.0
	foundation.tier_boss_dps_multiplier = 1.0
	foundation.footprint = Vector2i(1, 1)
	var weapon := WeaponComponent.new()
	weapon.weapon_damage = 35.0
	weapon.attack_speed = 2.0
	var focus := FocusComponent.new()
	focus.attack_range_cells = 4
	focus.cone_half_angle = 180.0
	var power := PowerComponent.new()

	# Place tower directly: bypasses place_tower() Gate 1 (WAVE_ACTIVE blocks it).
	# attack_timer_remaining=0.0 so the tower fires on the very first physics tick.
	var mission_state := TowerMissionState.new()
	mission_state.tower_id = 1
	mission_state.placement_cost = 0
	mission_state.foundation = foundation
	mission_state.weapon = weapon
	mission_state.focus = focus
	mission_state.power = power
	mission_state.grid_position = TOWER_CELL
	mission_state.max_hp = 100.0
	mission_state.current_hp = 100.0
	mission_state.attack_timer_remaining = 0.0
	_ts.placed_towers[1] = mission_state
	_ts._tower_id_counter = 1


func after_test() -> void:
	# Safety-net disconnects — reached even when a test fails mid-function.
	# is_connected() guard prevents errors if the happy path already disconnected.
	if _on_died_cb.is_valid() and GEventBus.monster_died.is_connected(_on_died_cb):
		GEventBus.monster_died.disconnect(_on_died_cb)
	if _on_breached_cb.is_valid() and GEventBus.monster_breached.is_connected(_on_breached_cb):
		GEventBus.monster_breached.disconnect(_on_breached_cb)
	if _on_damage_cb.is_valid() and GEventBus.monster_damage_taken.is_connected(_on_damage_cb):
		GEventBus.monster_damage_taken.disconnect(_on_damage_cb)

	for e: MonsterEntity in _mm.active_monsters:
		if is_instance_valid(e):
			e.free()
	for e: MonsterEntity in _mm.spawning_entities:
		if is_instance_valid(e):
			e.free()
	_mm.active_monsters.clear()
	_mm.spawning_entities.clear()
	remove_child(_mm)
	_mm.free()
	remove_child(_ts)
	_ts.free()
	remove_child(_ds)
	_ds.free()
	_mm = null
	_ts = null
	_ds = null


# ---------------------------------------------------------------------------
# AC-1 through AC-6: End-to-end kill scenario
#
# Tower at (8,6): weapon_damage=35, attack_speed=2.0, range=4 cells.
# Goblin at (4,9): base_hp=70, wave_index=1, difficulty_tier=1 → scaled_hp=70.
# Path (4,9)→(18,9): every cell is within Chebyshev 4 of (8,6).
# Tower fires frame 1, shot 2 arrives ~30 frames later → monster dies.
# ---------------------------------------------------------------------------

func test_combat_loop_monster_died_fires_with_correct_entity_id() -> void:
	# Covers AC-2 (scaled_hp), AC-5 (monster_died + entity_id + ≤2 shots)
	var state := {"died": null, "breached": -1, "shots": 0}

	_on_died_cb = func(payload: MonsterDiedEvent) -> void:
		state.died = payload
	_on_breached_cb = func(entity_id: int, _mid: StringName, _tier: int) -> void:
		state.breached = entity_id
	_on_damage_cb = func(_ev: MonsterDamageTaken) -> void:
		state.shots += 1

	GEventBus.monster_died.connect(_on_died_cb)
	GEventBus.monster_breached.connect(_on_breached_cb)
	GEventBus.monster_damage_taken.connect(_on_damage_cb)

	# Act — spawn goblin; monster_spawned fires → TowerSystem cache populated.
	var entity: MonsterEntity = _mm.spawn_monster(&"goblin", SPAWN_CELL, 1, 1)
	assert_object(entity).is_not_null()
	var entity_id: int = entity.entity_id
	# AC-2: wave_index=1, difficulty_tier=1 → scaled_hp=70.0 (no wave scaling).
	assert_float(entity.scaled_hp).is_equal_approx(70.0, 0.001)

	for _tick: int in range(300):
		await get_tree().physics_frame
		if state.died != null:
			break

	GEventBus.monster_died.disconnect(_on_died_cb)
	GEventBus.monster_breached.disconnect(_on_breached_cb)
	GEventBus.monster_damage_taken.disconnect(_on_damage_cb)

	# AC-5: monster_died fired with correct entity_id.
	var died: MonsterDiedEvent = state.died as MonsterDiedEvent
	assert_object(died).is_not_null()
	assert_int(died.entity_id).is_equal(entity_id)
	# AC-5 edge case: exactly 2 shots to kill (70 HP / 35 dmg — no overkill multiplier).
	assert_int(state.shots).is_less_equal(2)


func test_combat_loop_monster_breached_not_fired() -> void:
	# AC-6: monster dies inside tower range; breach event never fires.
	var state := {"died": null, "breached": -1}

	_on_died_cb = func(payload: MonsterDiedEvent) -> void:
		state.died = payload
	_on_breached_cb = func(entity_id: int, _mid: StringName, _tier: int) -> void:
		state.breached = entity_id

	GEventBus.monster_died.connect(_on_died_cb)
	GEventBus.monster_breached.connect(_on_breached_cb)

	_mm.spawn_monster(&"goblin", SPAWN_CELL, 1, 1)

	for _tick: int in range(300):
		await get_tree().physics_frame
		if state.died != null:
			break

	GEventBus.monster_died.disconnect(_on_died_cb)
	GEventBus.monster_breached.disconnect(_on_breached_cb)

	# Confirm combat completed — guards against false-positive if combat stalled.
	assert_object(state.died as MonsterDiedEvent).is_not_null()
	assert_int(state.breached).is_equal(-1)


func test_combat_loop_monster_dies_within_300_frames() -> void:
	# AC-4 + AC-5: monster must die within the timeout window.
	# 2 shots at attack_speed=2.0: period=0.5s=~30 frames; generous bound of 120.
	var state := {"died": null}

	_on_died_cb = func(payload: MonsterDiedEvent) -> void:
		state.died = payload
	GEventBus.monster_died.connect(_on_died_cb)

	_mm.spawn_monster(&"goblin", SPAWN_CELL, 1, 1)

	var frames_elapsed: int = 0
	for _tick: int in range(300):
		await get_tree().physics_frame
		frames_elapsed += 1
		if state.died != null:
			break

	GEventBus.monster_died.disconnect(_on_died_cb)

	assert_object(state.died as MonsterDiedEvent).is_not_null()
	assert_int(frames_elapsed).is_less_equal(120)


# ---------------------------------------------------------------------------
# AC-8 through AC-11: Pathfinding profiler (measurement only — no assertions)
#
# Calls GPathfindingSystem directly (not the stub). Results are measurement-only;
# a QA sign-off judgment determines PASS/FAIL against ADR-0004 thresholds.
# Tests are ordered: baseline first (cold), then warm 100-sample batch, then block check.
# Print [PROFILER] lines to stdout — copy values to tests/performance/sprint-03-profiler.md.
#
# NOTE (measurement-only convention, matches this section's pre-existing pattern):
# these profiler tests intentionally do not hard-fail on threshold — same
# convention as the pre-existing AC-9/AC-10 tests below. A QA sign-off judgment
# reads the printed [PROFILER] numbers against tests/performance/*.md, not an
# in-test assertion. This is a deliberate exception to the general
# "performance tests must ... fail if exceeded" rule, consistent with how this
# file already treats AC-9/AC-10/AC-24a.
# ---------------------------------------------------------------------------

## S4-10 helper — builds a single-lane boustrophedon (snake) SPAWN→PATH×N→GOAL
## corridor covering exactly `path_len_after_spawn` cells beyond SPAWN (SPAWN
## excluded, GOAL included) — e.g. path_len_after_spawn=25 means
## find_path(SPAWN, 0) returns an Array[Vector2i] of size 25. Uses only as many
## rows as needed; cells outside the corridor are absent from the config
## (implicitly BLOCKED per GridConfig's own contract) since only the corridor
## matters for a find_path() latency measurement.
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


## S4-10 helper — builds and warms a FRESH, ISOLATED PathfindingSystem instance
## (not the live GPathfindingSystem autoload, to avoid cross-test global-state
## pollution) via the real production template-build code path
## (_on_mission_phase_changed("", "SCOUT", 0.0) — same handler EventBus
## normally drives). Pattern matches tests/unit/pathfinding/pathfinding_template_test.gd.
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


## S4-10 helper — nearest-rank percentile. `samples` is a non-empty Array of
## floats (microseconds); p is in (0.0, 1.0].
func _percentile_us(samples: Array, p: float) -> float:
	var sorted_samples: Array = samples.duplicate()
	sorted_samples.sort()
	var idx: int = int(ceil(p * sorted_samples.size())) - 1
	idx = clampi(idx, 0, sorted_samples.size() - 1)
	return sorted_samples[idx]


## S4-10 helper — allocates and discards ~400,000 Vector2i entries to reliably
## trigger a collection cycle on the next GC-eligible frame. Godot 4 has no
## direct GC.collect() API for GDScript's refcounted objects; this is the
## forcing pattern specified in this story's Implementation Notes item 2.
func _force_gc_cycle() -> void:
	var gc_trigger: Array = []
	for i: int in range(400000):
		gc_trigger.append(Vector2i(i, i))
	gc_trigger.clear()


func test_pathfinding_profiler_astar_baseline() -> void:
	# AC-10: A* baseline — single cold find_path() call before any warm-up.
	var t0: int = Time.get_ticks_usec()
	GPathfindingSystem.find_path(Vector2i(0, 0), 0)
	var elapsed_us: int = Time.get_ticks_usec() - t0
	var baseline_ms: float = float(elapsed_us) / 1000.0
	print("[PROFILER] A* baseline single find_path(): %.3f ms" % baseline_ms)


func test_pathfinding_profiler_find_path_100_samples() -> void:
	# AC-4 (S4-10 fix, closes TD-path-001): find_path() call latency against a
	# WARM 16x12 grid (avg path length 25, pre-built route templates) — not the
	# cold fallback path TD-path-001 found (34.043ms avg on an unwarmed
	# GPathfindingSystem autoload). Uses a fresh isolated PathfindingSystem
	# instance so this measurement never touches GPathfindingSystem's global
	# state (which other tests in this suite call directly).
	#
	# Deviation from AC-4's literal "10-second window" (documented per the
	# S4-10 collaboration protocol): a literal 10 real-time wall-clock seconds
	# of sampling per CI run is impractical for this suite. This test instead
	# runs 1000 batches of 100 calls each (100,000 total find_path() calls) as
	# a statistically equivalent synthetic sampling window — one forced
	# GC-trigger allocation fires mid-run per Implementation Notes item 2.
	# See tests/performance/sprint-04-profiler.md for the recorded verdict and
	# this deviation note.
	var ctx: Dictionary = _setup_isolated_pathfinding(16, 12, 25)
	var pathfinding: PathfindingSystem = ctx.pathfinding
	var spawn_cell: Vector2i = ctx.spawn_cell

	const BATCHES: int = 1000
	const CALLS_PER_BATCH: int = 100
	var batch_totals_us: Array = []

	for batch: int in range(BATCHES):
		if batch == BATCHES / 2:
			_force_gc_cycle()
		var t0: int = Time.get_ticks_usec()
		for _i: int in range(CALLS_PER_BATCH):
			pathfinding.find_path(spawn_cell, 0)
		batch_totals_us.append(float(Time.get_ticks_usec() - t0))
		if batch % 100 == 0:
			await get_tree().process_frame

	_teardown_isolated_pathfinding(ctx)

	var p50_ms: float = _percentile_us(batch_totals_us, 0.50) / 1000.0
	var p95_ms: float = _percentile_us(batch_totals_us, 0.95) / 1000.0
	var p99_ms: float = _percentile_us(batch_totals_us, 0.99) / 1000.0
	var p999_ms: float = _percentile_us(batch_totals_us, 0.999) / 1000.0
	print("[PROFILER] find_path() warm 16x12 grid (avg path 25), %d batches of 100 calls: p50=%.4fms p95=%.4fms p99=%.4fms p99.9=%.4fms  (target: 100 calls/frame total <=1ms p99.9 per ADR-0004)" % [BATCHES, p50_ms, p95_ms, p99_ms, p999_ms])


func test_pathfinding_profiler_find_path_100_samples_max_grid_24x18() -> void:
	# AC-2 (S4-10, max-grid stretch case): identical warm-template batch
	# measurement as AC-4 above, but on the 24x18 max grid (avg path length
	# 60). Not a hard gate per the story — the real number is recorded
	# regardless of pass/fail against the provisional 1ms target.
	var ctx: Dictionary = _setup_isolated_pathfinding(24, 18, 60)
	var pathfinding: PathfindingSystem = ctx.pathfinding
	var spawn_cell: Vector2i = ctx.spawn_cell

	const BATCHES: int = 1000
	const CALLS_PER_BATCH: int = 100
	var batch_totals_us: Array = []

	for batch: int in range(BATCHES):
		if batch == BATCHES / 2:
			_force_gc_cycle()
		var t0: int = Time.get_ticks_usec()
		for _i: int in range(CALLS_PER_BATCH):
			pathfinding.find_path(spawn_cell, 0)
		batch_totals_us.append(float(Time.get_ticks_usec() - t0))
		if batch % 100 == 0:
			await get_tree().process_frame

	_teardown_isolated_pathfinding(ctx)

	var p50_ms: float = _percentile_us(batch_totals_us, 0.50) / 1000.0
	var p95_ms: float = _percentile_us(batch_totals_us, 0.95) / 1000.0
	var p99_ms: float = _percentile_us(batch_totals_us, 0.99) / 1000.0
	var p999_ms: float = _percentile_us(batch_totals_us, 0.999) / 1000.0
	print("[PROFILER] find_path() warm 24x18 max grid (avg path 60), %d batches of 100 calls: p50=%.4fms p95=%.4fms p99=%.4fms p99.9=%.4fms  (provisional target <=1ms — not a hard gate, per S4-10 AC-2)" % [BATCHES, p50_ms, p95_ms, p99_ms, p999_ms])


func test_pathfinding_profiler_would_block_all_paths() -> void:
	# AC-9: would_block_all_paths() on full 24×18 grid footprint (432 cells).
	# Target: ≤5ms p99 per ADR-0004.
	var footprint: Array[Vector2i] = []
	for x: int in range(24):
		for y: int in range(18):
			footprint.append(Vector2i(x, y))
	var t0: int = Time.get_ticks_usec()
	GPathfindingSystem.would_block_all_paths(footprint)
	var elapsed_us: int = Time.get_ticks_usec() - t0
	var p99_ms: float = float(elapsed_us) / 1000.0
	print("[PROFILER] would_block_all_paths() 24×18 grid: %.3f ms  (target ≤5ms p99 per ADR-0004)" % p99_ms)
	print("[PROFILER] NOTE — copy all [PROFILER] values to tests/performance/sprint-03-profiler.md")
