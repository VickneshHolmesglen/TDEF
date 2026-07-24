extends GdUnitTestSuite

## WaveManager spawn coroutine tests — 3-guard pattern and templates_ready gate.
## Covers: AC-8 through AC-12.
## Design source: production/stories/core/s3-06-wave-manager-phase1.md
## ADR-0012: Wave Manager FSM Architecture — Spawn coroutine Key Interfaces.

var _wm: WaveManager
var _spy: EventBusSpy


func before_test() -> void:
	_wm = WaveManager.new()
	add_child(_wm)  # triggers _ready() — needed for get_tree().create_timer()

	# Story 007 (round-robin-spawn-cells): _resolve_spawn_cell() now requires a
	# non-empty _spawn_cells (previously this suite relied on the flat, now-dead
	# _spawn_cell placeholder field) — default single-cell fixture here; tests
	# that care about the resolved cell value override it directly.
	_wm._spawn_cells = [Vector2i(0, 0)]

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.monster_spawn_requested)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	remove_child(_wm)
	_wm.free()

# ---------------------------------------------------------------------------
# AC-8: Every `await` in _run_spawn_sequence is followed immediately by the
# three guards: is_instance_valid(self), _spawn_active, _phase == WAVE_ACTIVE.
# Verified by source inspection since this is a structural requirement.
# ---------------------------------------------------------------------------

func test_run_spawn_sequence_has_three_guard_pattern_after_every_await() -> void:
	var source: String = FileAccess.get_file_as_string("res://src/gameplay/wave_manager.gd")
	var lines: PackedStringArray = source.split("\n")

	var start_idx: int = -1
	var end_idx: int = lines.size()
	for i in range(lines.size()):
		var stripped: String = lines[i].strip_edges()
		if stripped.begins_with("func _run_spawn_sequence"):
			start_idx = i
		elif start_idx != -1 and i > start_idx and stripped.begins_with("func "):
			end_idx = i
			break
	assert_int(start_idx).is_greater(-1)

	var await_line_indices: Array = []
	for i in range(start_idx, end_idx):
		if lines[i].strip_edges().begins_with("await "):
			await_line_indices.append(i)
	assert_int(await_line_indices.size()).is_greater(0)

	for idx: int in await_line_indices:
		var g1: String = lines[idx + 1].strip_edges()
		var g2: String = lines[idx + 2].strip_edges()
		var g3: String = lines[idx + 3].strip_edges()
		assert_str(g1).is_equal("if not is_instance_valid(self): return")
		assert_str(g2).is_equal("if not _spawn_active: return")
		assert_str(g3).is_equal("if _phase != Phase.WAVE_ACTIVE: return")

# ---------------------------------------------------------------------------
# AC-9: _spawn_active = false set externally aborts the coroutine at the next
# await boundary — no further monster_spawn_requested after that point.
# ---------------------------------------------------------------------------

func test_spawn_active_false_aborts_coroutine_before_next_spawn() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 1
	_wm._templates_ready = true
	_wm._spawn_active = true
	_wm._wave_spawn_entries = [
		WaveSpawnEntry.new(&"goblin", 0.0),
		WaveSpawnEntry.new(&"goblin", 0.05),
	]

	_wm._run_spawn_sequence()  # entry 1 (pre_delay 0.0) fires synchronously, suspends on entry 2's await
	assert_int(_spy.count("monster_spawn_requested")).is_equal(1)

	_wm._spawn_active = false  # cancel before entry 2's timer resolves

	await get_tree().create_timer(0.08).timeout  # let entry 2's timer fire and the coroutine resume

	assert_int(_spy.count("monster_spawn_requested")).is_equal(1)  # entry 2 aborted by guard

# ---------------------------------------------------------------------------
# AC-10: Spawn coroutine fires monster_spawn_requested N times per wave
# config, in config order, with each payload's fields matching its entry.
# ---------------------------------------------------------------------------

func test_run_spawn_sequence_emits_n_spawns_matching_config() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 3
	_wm._templates_ready = true
	_wm._spawn_active = true
	_wm._wave_reward_scalar = 1.5
	_wm._spawn_cells = [Vector2i(2, 2)]
	_wm._wave_spawn_entries = [
		WaveSpawnEntry.new(&"goblin", 0.0),
		WaveSpawnEntry.new(&"orc", 0.0),
		WaveSpawnEntry.new(&"orc", 0.0),
	]

	await _wm._run_spawn_sequence()

	assert_int(_spy.count("monster_spawn_requested")).is_equal(3)
	assert_bool(_wm._all_spawns_fired).is_true()
	# _enemies_alive stays 0 in this test (no MonsterManager to emit monster_spawned),
	# so the trailing wave-clear check flips _phase straight to INTERMISSION — assert
	# it explicitly rather than leaving it as an unasserted side effect (see AC-10 note
	# in the s3-06 code review: this masked the reentrancy bug covered below).
	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)

	var emissions: Array = _spy.emissions["monster_spawn_requested"]
	var p1: MonsterSpawnRequest = (emissions[0] as Array)[0]
	var p2: MonsterSpawnRequest = (emissions[1] as Array)[0]
	assert_str(p1.monster_id).is_equal("goblin")
	assert_str(p2.monster_id).is_equal("orc")
	assert_int(p1.wave_index).is_equal(3)
	assert_float(p1.wave_reward_scalar).is_equal(1.5)
	assert_bool(p1.spawn_cell == Vector2i(2, 2)).is_true()

# ---------------------------------------------------------------------------
# Regression: empty (or fully-synchronous, zero-enemy) _wave_spawn_entries
# must not soft-lock the FSM in WAVE_ACTIVE. _run_spawn_sequence() can
# complete with zero `await` suspensions, so _check_wave_clear_or_start_
# watchdog()'s _transition_to(INTERMISSION) call lands INSIDE the still-locked
# outer _transition_to(WAVE_ACTIVE) call stack. A direct call there is
# silently dropped by _phase_locked — this test drives through the real
# _transition_to() entry point (not a direct _run_spawn_sequence() call) so
# it actually exercises the reentrant path and would have caught the bug.
# ---------------------------------------------------------------------------

func test_empty_wave_spawn_entries_does_not_soft_lock_wave_active() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._templates_ready = true
	_wm._wave_spawn_entries = []

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	# The wave-clear transition is deferred (call_deferred) specifically to escape
	# the locked call stack — give it a frame to run before asserting.
	await get_tree().process_frame

	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)
	assert_bool(_wm._all_spawns_fired).is_true()
	assert_int(_wm._enemies_alive).is_equal(0)

# ---------------------------------------------------------------------------
# AC-11: Wave 1 with _templates_ready = false → coroutine awaits
# EventBus.templates_ready before emitting the first spawn.
# ---------------------------------------------------------------------------

func test_wave1_gate_blocks_first_spawn_until_templates_ready_fires() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 1
	_wm._templates_ready = false
	_wm._spawn_active = true
	_wm._wave_spawn_entries = [WaveSpawnEntry.new(&"goblin", 0.0)]

	_wm._run_spawn_sequence()  # suspends on `await EventBus.templates_ready`
	assert_int(_spy.count("monster_spawn_requested")).is_equal(0)

	GEventBus.templates_ready.emit(1, 5.0)

	# AC-12: resumes and fires within the same emit() call — no extra frame delay.
	assert_int(_spy.count("monster_spawn_requested")).is_equal(1)

# ---------------------------------------------------------------------------
# AC-12: If templates_ready is already true when the coroutine starts, the
# first spawn fires immediately — no extra frame delay.
# ---------------------------------------------------------------------------

func test_templates_already_ready_fires_first_spawn_with_no_extra_delay() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 1
	_wm._templates_ready = true
	_wm._spawn_active = true
	_wm._wave_spawn_entries = [WaveSpawnEntry.new(&"goblin", 0.0)]

	_wm._run_spawn_sequence()

	assert_int(_spy.count("monster_spawn_requested")).is_equal(1)
