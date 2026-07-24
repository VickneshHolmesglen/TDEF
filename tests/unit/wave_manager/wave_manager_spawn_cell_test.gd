extends GdUnitTestSuite

## WaveManager round-robin spawn cell assignment + modulo wrap tests.
## Design source: production/epics/epic-04-wave-manager/story-007-round-robin-spawn-cells.md
## ADR-0012: Wave Manager FSM Architecture.
##
## Deviations from the story's Implementation Notes (flagged upfront by the
## requesting agent, not discovered independently):
##   1. The story's `_enter_wave_active()` pseudocode is a stale full
##      reconstruction — it reintroduces `wave_started` emission and the
##      `_wave_reward_scalar` formula computation, both of which Stories
##      002/004 already relocated into `_transition_to()` itself. Only the
##      `_round_robin_counter = 0` reset line (Rule 10f) was added to the
##      CURRENT `_enter_wave_active()`.
##   2. The pseudocode's `push_warning` text ("spawn_cell_index %d out of
##      range — wrapping to %d.") does not contain the literal substring the
##      story's own AC-35 / QA Test Cases require ("spawn_cell_index [N] out
##      of range" — with literal brackets, e.g. "spawn_cell_index [5] out of
##      range" for index 5). The implementation uses the bracketed format,
##      matching AC-35's literal wording; this suite asserts against that
##      bracketed substring.
##
## Follows the EventBusSpy + direct-invocation / direct-field-injection
## conventions established in wave_manager_reward_scalar_test.gd and
## tests/integration/wave_manager/wave_manager_config_loading_test.gd.

var _wm: WaveManager
var _spy: EventBusSpy


func before_test() -> void:
	_wm = WaveManager.new()
	add_child(_wm)  # triggers _ready() — creates timers, subscribes to EventBus

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.monster_spawn_requested)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	remove_child(_wm)
	_wm.free()

# ---------------------------------------------------------------------------
# Rule 15b: positive spawn_cell_index resolution (in-range, no wrap needed).
# ---------------------------------------------------------------------------

func test_resolve_spawn_cell_positive_index_in_range_returns_correct_cell() -> void:
	_wm._spawn_cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]  # A, B, C
	var entry := WaveSpawnEntry.new(&"goblin", 0.0, 1, 1)  # spawn_cell_index = 1 -> B

	var cell: Vector2i = _wm._resolve_spawn_cell(entry)

	assert_vector(cell).is_equal(Vector2i(1, 0))


## No warning should be logged when the positive index is already in range.
## Code review fix (Story 007): the original version of this test only
## re-asserted the returned cell (identical to the prior test) and never
## actually verified the "no warning" claim in its own name — a regression
## that made every index warn would have passed silently. is_success() (from
## GdUnitGodotErrorAssert) verifies the wrapped callable logged no error or
## warning at all, actually proving the negative case.
func test_resolve_spawn_cell_positive_index_in_range_logs_no_warning() -> void:
	_wm._spawn_cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var entry := WaveSpawnEntry.new(&"goblin", 0.0, 1, 2)  # spawn_cell_index = 2, in range
	var resolved: Array = [Vector2i(-99, -99)]

	await assert_error(func() -> void: resolved[0] = _wm._resolve_spawn_cell(entry)) \
		.is_success()

	assert_vector(resolved[0]).is_equal(Vector2i(2, 0))

# ---------------------------------------------------------------------------
# Rule 15b: round-robin resolution (spawn_cell_index == -1) + counter
# increment.
# ---------------------------------------------------------------------------

func test_resolve_spawn_cell_round_robin_uses_counter_then_increments() -> void:
	_wm._spawn_cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]  # A, B, C
	_wm._round_robin_counter = 0
	var entry := WaveSpawnEntry.new(&"goblin", 0.0)  # spawn_cell_index defaults to -1

	var first: Vector2i = _wm._resolve_spawn_cell(entry)
	assert_vector(first).is_equal(Vector2i(0, 0))  # A
	assert_int(_wm._round_robin_counter).is_equal(1)

	var second: Vector2i = _wm._resolve_spawn_cell(entry)
	assert_vector(second).is_equal(Vector2i(1, 0))  # B
	assert_int(_wm._round_robin_counter).is_equal(2)

	var third: Vector2i = _wm._resolve_spawn_cell(entry)
	assert_vector(third).is_equal(Vector2i(2, 0))  # C
	assert_int(_wm._round_robin_counter).is_equal(3)


## Round-robin wraps back to the first cell once the counter exceeds the
## spawn cell count.
func test_resolve_spawn_cell_round_robin_wraps_after_exhausting_all_cells() -> void:
	_wm._spawn_cells = [Vector2i(0, 0), Vector2i(1, 0)]  # A, B
	_wm._round_robin_counter = 2  # already wrapped once
	var entry := WaveSpawnEntry.new(&"goblin", 0.0)

	var cell: Vector2i = _wm._resolve_spawn_cell(entry)

	assert_vector(cell).is_equal(Vector2i(0, 0))  # A again (2 % 2 == 0)
	assert_int(_wm._round_robin_counter).is_equal(3)


## Code review fix (Story 007): Rule 15b only defines >= 0 (positive index) or
## exactly -1 (round-robin) — an undocumented negative value like -2 (e.g. a
## content-authoring typo) still resolves via round-robin, but now logs a
## warning rather than silently aliasing to -1's behavior with no signal.
func test_resolve_spawn_cell_undocumented_negative_index_warns_but_still_uses_round_robin() -> void:
	_wm._spawn_cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]  # A, B, C
	_wm._round_robin_counter = 0
	var entry := WaveSpawnEntry.new(&"goblin", 0.0, 1, -2)
	var resolved: Array = [Vector2i(-99, -99)]

	await assert_error(func() -> void: resolved[0] = _wm._resolve_spawn_cell(entry)) \
		.is_push_warning("WaveManager: spawn_cell_index [-2] is not >= 0 or exactly -1 — treating as round-robin.")

	assert_vector(resolved[0]).is_equal(Vector2i(0, 0))  # still resolves via round-robin
	assert_int(_wm._round_robin_counter).is_equal(1)  # counter still increments normally

# ---------------------------------------------------------------------------
# Rule 10f: _round_robin_counter resets to 0 at every WAVE_ACTIVE entry
# (wave-scoped, not mission-scoped).
# ---------------------------------------------------------------------------

func test_enter_wave_active_resets_round_robin_counter_to_zero() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._templates_ready = true
	_wm._spawn_cells = [Vector2i(0, 0)]
	_wm._round_robin_counter = 7  # stale value from a previous wave
	_wm._wave_spawn_entries = []

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_int(_wm._round_robin_counter).is_equal(0)

# ---------------------------------------------------------------------------
# AC-10: 4-entry WaveScript (spawn_cell_index: [2, -1, -1, -1]) on a 3-cell
# map [A, B, C] resolves to [C, A, B, C]. Verified across TWO consecutive
# waves, driven via real _transition_to(WAVE_ACTIVE) calls (zero pre_delay so
# _run_spawn_sequence() fires synchronously), proving the counter does NOT
# carry over between waves.
# ---------------------------------------------------------------------------

func test_ac10_mixed_positive_and_round_robin_resolves_correctly_across_two_waves() -> void:
	var cell_a := Vector2i(0, 0)
	var cell_b := Vector2i(1, 0)
	var cell_c := Vector2i(2, 0)
	_wm._spawn_cells = [cell_a, cell_b, cell_c]

	var entries: Array[WaveSpawnEntry] = [
		WaveSpawnEntry.new(&"goblin", 0.0, 1, 2),   # positive index 2 -> C
		WaveSpawnEntry.new(&"goblin", 0.0, 1, -1),  # round-robin -> A (counter 0)
		WaveSpawnEntry.new(&"goblin", 0.0, 1, -1),  # round-robin -> B (counter 1)
		WaveSpawnEntry.new(&"goblin", 0.0, 1, -1),  # round-robin -> C (counter 2)
	]

	# --- Wave 1 ---
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._templates_ready = true
	_wm._wave_spawn_entries = entries

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_int(_spy.count("monster_spawn_requested")).is_equal(4)
	var wave1_emissions: Array = _spy.emissions["monster_spawn_requested"]
	var wave1_cells: Array[Vector2i] = []
	for e: Array in wave1_emissions:
		wave1_cells.append((e[0] as MonsterSpawnRequest).spawn_cell)
	assert_array(wave1_cells).is_equal([cell_c, cell_a, cell_b, cell_c])

	_spy.clear()

	# --- Wave 2: repeat the same WaveScript; the round-robin counter must
	# reset to 0, so the first -1 entry uses cell A again, not a carried-over
	# value from wave 1's counter (which ended at 3).
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._wave_spawn_entries = entries

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_int(_spy.count("monster_spawn_requested")).is_equal(4)
	var wave2_emissions: Array = _spy.emissions["monster_spawn_requested"]
	var wave2_cells: Array[Vector2i] = []
	for e: Array in wave2_emissions:
		wave2_cells.append((e[0] as MonsterSpawnRequest).spawn_cell)
	assert_array(wave2_cells).is_equal([cell_c, cell_a, cell_b, cell_c])

# ---------------------------------------------------------------------------
# AC-35: positive spawn_cell_index exceeding spawn_cells.size() - 1 wraps via
# modulo, with a warning containing "spawn_cell_index [N] out of range".
# Verified for indices 3, 5, 7 against a 3-cell map (wrapping to 0, 2, 1).
# ---------------------------------------------------------------------------

## NOTE (caught during this suite's own test run): GDScript lambdas capture
## outer-scope locals BY VALUE at creation time, not by reference — assigning
## to a plain `var resolved: Vector2i` from inside the assert_error() callable
## silently does not propagate back to this outer scope (the warning text
## itself still logs correctly, but the assertion below would see the
## sentinel forever). Wrapping the captured value in a single-element Array
## (a reference type) fixes it — matching the pattern already established in
## wave_manager_config_loading_test.gd's call-counting stub.
func test_ac35_positive_index_3_wraps_to_0_with_warning() -> void:
	_wm._spawn_cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var entry := WaveSpawnEntry.new(&"goblin", 0.0, 1, 3)
	var resolved: Array = [Vector2i(-99, -99)]

	await assert_error(func() -> void: resolved[0] = _wm._resolve_spawn_cell(entry)) \
		.is_push_warning("WaveManager: spawn_cell_index [3] out of range — wrapping to 0.")

	assert_vector(resolved[0]).is_equal(Vector2i(0, 0))


func test_ac35_positive_index_5_wraps_to_2_with_warning() -> void:
	_wm._spawn_cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var entry := WaveSpawnEntry.new(&"goblin", 0.0, 1, 5)
	var resolved: Array = [Vector2i(-99, -99)]

	await assert_error(func() -> void: resolved[0] = _wm._resolve_spawn_cell(entry)) \
		.is_push_warning("WaveManager: spawn_cell_index [5] out of range — wrapping to 2.")

	assert_vector(resolved[0]).is_equal(Vector2i(2, 0))


func test_ac35_positive_index_7_wraps_to_1_with_warning() -> void:
	_wm._spawn_cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var entry := WaveSpawnEntry.new(&"goblin", 0.0, 1, 7)
	var resolved: Array = [Vector2i(-99, -99)]

	await assert_error(func() -> void: resolved[0] = _wm._resolve_spawn_cell(entry)) \
		.is_push_warning("WaveManager: spawn_cell_index [7] out of range — wrapping to 1.")

	assert_vector(resolved[0]).is_equal(Vector2i(1, 0))

# ---------------------------------------------------------------------------
# Defensive guard (should be unreachable in production per Story 006's
# AC-36): empty _spawn_cells logs a push_error and returns a sentinel
# Vector2i(-1, -1) instead of crashing.
# ---------------------------------------------------------------------------

func test_resolve_spawn_cell_empty_spawn_cells_logs_error_and_returns_sentinel() -> void:
	_wm._spawn_cells = []
	var entry := WaveSpawnEntry.new(&"goblin", 0.0)
	var resolved: Array = [Vector2i(0, 0)]

	await assert_error(func() -> void: resolved[0] = _wm._resolve_spawn_cell(entry)) \
		.is_push_error("WaveManager: _resolve_spawn_cell() called with empty _spawn_cells — should have been caught by Story 006's mission_launched guard.")

	assert_vector(resolved[0]).is_equal(Vector2i(-1, -1))

# ---------------------------------------------------------------------------
# Performance / Control Manifest guardrail: _resolve_spawn_cell() is O(1) —
# one modulo op (positive-index path) or one modulo + one increment
# (round-robin path) — no new iteration added to _run_spawn_sequence()'s
# per-entry loop. Verified by source inspection, mirroring this suite
# family's existing structural tests (e.g. wave_manager_spawn_test.gd's
# 3-guard-pattern check).
# ---------------------------------------------------------------------------

func test_resolve_spawn_cell_is_called_exactly_once_per_entry_not_in_a_nested_loop() -> void:
	var source: String = FileAccess.get_file_as_string("res://src/gameplay/wave_manager.gd")

	var run_spawn_sequence_start: int = source.find("func _run_spawn_sequence")
	var resolve_spawn_cell_start: int = source.find("func _resolve_spawn_cell")
	assert_int(run_spawn_sequence_start).is_greater(-1)
	assert_int(resolve_spawn_cell_start).is_greater(-1)

	# Exactly one call site inside _run_spawn_sequence()'s per-entry loop —
	# not called from within _resolve_spawn_cell() itself (no recursion / no
	# extra iteration), and not called more than once per entry.
	var run_spawn_sequence_body: String = source.substr(run_spawn_sequence_start)
	var next_func_offset: int = run_spawn_sequence_body.find("\nfunc ", 1)
	if next_func_offset != -1:
		run_spawn_sequence_body = run_spawn_sequence_body.substr(0, next_func_offset)
	var call_occurrences: int = run_spawn_sequence_body.count("_resolve_spawn_cell(entry)")
	assert_int(call_occurrences).is_equal(1)

	# _resolve_spawn_cell() itself contains no loop constructs (for/while) —
	# confirms O(1), not O(spawn_cells.size()).
	#
	# Code review fix (Story 005): the original version of this check searched
	# the raw slice (including the doc-comment block trailing the function,
	# up to the next "func ") for the bare substring "for " / "while " — this
	# broke the moment Story 005 added a comment containing ordinary English
	# prose like "checked for wave 1" between this function and the next one.
	# Comment lines are now excluded before checking, so only actual GDScript
	# statements are inspected — closing exactly the fragility flagged (but
	# not yet fixed) during Story 007's code review.
	var resolve_body_end: int = source.find("\nfunc ", resolve_spawn_cell_start + 1)
	var resolve_body: String = source.substr(resolve_spawn_cell_start,
			resolve_body_end - resolve_spawn_cell_start if resolve_body_end != -1 else -1)
	var resolve_code_only: String = ""
	for line: String in resolve_body.split("\n"):
		if not line.strip_edges().begins_with("#"):
			resolve_code_only += line + "\n"
	assert_bool(resolve_code_only.contains("for ")).is_false()
	assert_bool(resolve_code_only.contains("while ")).is_false()
