extends GdUnitTestSuite

## WaveManager WaveConfig resource loading & mission_launched wiring tests.
## Design source: production/epics/epic-04-wave-manager/story-006-waveconfig-resource-loading.md
## Governing ADRs: docs/architecture/adr-0012-wave-manager-fsm.md (Accepted)
##                  docs/architecture/adr-0009-resource-data-model.md (Accepted)
##
## Deviations from the story's Implementation Notes / Acceptance Criteria
## wording (flagged upfront, not discovered independently — see the
## requesting agent's report for full detail):
##   1. AC-19 / AC-36's own bullet text describes the expected transition as
##      "mission_phase_changed(SCOUT → MISSION_COMPLETE)", but the story's own
##      "corrected" Implementation Notes pseudocode places both empty-content
##      guards BEFORE _transition_to(Phase.SCOUT) (its own inline comment:
##      "AC-36 — bypasses SCOUT entirely"). Implemented and tested literally
##      per the pseudocode: the "from" phase is whatever _phase was before
##      mission_launched fired (IDLE on a mission's first launch), not SCOUT.
##   2. `phase_timer_tick` is declared on EventBus but is not emitted by any
##      production code in this codebase yet (grep-verified) — a different,
##      not-yet-landed story's responsibility. Where the QA Test Cases call
##      for "at least one phase_timer_tick fires" as proof of no-abort, this
##      suite substitutes the equivalent, already-established assertion
##      pattern used elsewhere in this test family: checking `_phase` and the
##      relevant Timer node's `is_stopped()` state directly.
##   3. AC-20's 8-field reset list (ADR-0012 Key Interfaces / this story's own
##      Implementation Notes) includes `_rebuild_pending_gate`, which does not
##      exist on WaveManager yet (Story 005 has not landed this session — see
##      wave_manager.gd's header note). This suite asserts the 7 fields that
##      actually exist; extending to the 8th is Story 005's/a follow-up's job.
##
## Follows the EventBusSpy + direct-invocation conventions established in
## tests/unit/wave_manager/wave_manager_defeat_victory_test.gd (calling
## _wm._on_mission_launched(...) directly rather than emitting the real
## GEventBus.mission_launched signal, which would also reach the ambient
## GWaveManager/SavePersistence Autoloads live during headless test runs).

# ---------------------------------------------------------------------------
# Stub
# ---------------------------------------------------------------------------

class _StubGrid extends RefCounted:
	var spawn_cells: Array[Vector2i] = [Vector2i(0, 0)]

	func get_spawn_cells() -> Array[Vector2i]:
		return spawn_cells

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Builds a WaveConfig with one WaveScript per entry in wave_entry_counts,
## each script containing that many zero-pre_delay WaveSpawnEntry entries.
func _make_wave_config(wave_entry_counts: Array, wave_time_budget: float = 90.0,
		growth_rate: float = 0.20) -> WaveConfig:
	var cfg := WaveConfig.new()
	cfg.wave_time_budget = wave_time_budget
	cfg.difficulty_growth_rate = growth_rate
	for count: int in wave_entry_counts:
		var script := WaveScript.new()
		for i: int in range(count):
			script.entries.append(WaveSpawnEntry.new(&"goblin", 0.0))
		cfg.wave_scripts.append(script)
	return cfg


func _stub_loader_for(cfg: WaveConfig) -> Callable:
	return func(_mission_id: String) -> WaveConfig: return cfg


var _wm: WaveManager
var _spy: EventBusSpy
var _stub_grid: _StubGrid


func before_test() -> void:
	# Flush any deferred GEventBus emit still in flight from an earlier test
	# (ADR-0001 Rule 2 deferred-dispatch convention, event_bus.gd) BEFORE
	# connecting a fresh WaveManager below -- otherwise a stale queued
	# .emit.call_deferred(...) for e.g. `templates_ready` from a prior
	# suite/instance can resolve against THIS _wm instead of whichever
	# instance was live when it was queued, flipping _templates_ready (or
	# other EventBus-driven fields) back on right before an assertion.
	# CI-only flake (2026-08-05): passes 100% locally on Windows but fails
	# reliably on the Linux GitHub Actions runner, where slower/different
	# frame-timing gives stale deferred calls more opportunity to land in
	# the wrong test's window -- same root cause fixed identically in
	# tests/integration/encyclopedia/discovery-event-ingestion_test.gd and
	# persistence-and-restore-order-safety_test.gd.
	await get_tree().process_frame
	_wm = WaveManager.new()
	add_child(_wm)  # triggers _ready() — creates timers, subscribes to EventBus, sets _grid = GGrid

	_stub_grid = _StubGrid.new()
	_wm._grid = _stub_grid  # test-injection seam (mirrors MonsterManager's _grid pattern)

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.mission_phase_changed)
	_spy.watch(GEventBus.wave_preview_available)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	remove_child(_wm)
	_wm.free()

# ---------------------------------------------------------------------------
# AC-1: mission_launched -> IDLE => SCOUT, 60s timer running, same-frame
# mission_phase_changed.
# ---------------------------------------------------------------------------

func test_mission_launched_from_idle_transitions_to_scout_and_starts_timer() -> void:
	var cfg: WaveConfig = _make_wave_config([1])
	_wm._wave_config_loader = _stub_loader_for(cfg)

	_wm._on_mission_launched("the_gap", PackedStringArray([]), 1)

	assert_int(_wm._phase).is_equal(WaveManager.Phase.SCOUT)
	assert_bool(_wm._scout_timer.is_stopped()).is_false()
	assert_bool(_spy.was_emitted("mission_phase_changed")).is_true()
	var args: Array = (_spy.emissions["mission_phase_changed"] as Array)[0]
	assert_str(args[0]).is_equal("IDLE")
	assert_str(args[1]).is_equal("SCOUT")

# ---------------------------------------------------------------------------
# Rule 8: WaveConfig read, spawn cells read, _wave_index / _round_robin_counter
# reset, SCOUT-entry composition preview emitted for wave 1.
# ---------------------------------------------------------------------------

func test_mission_launched_reads_wave_config_and_spawn_cells() -> void:
	var cfg: WaveConfig = _make_wave_config([2, 3])
	_wm._wave_config_loader = _stub_loader_for(cfg)
	_stub_grid.spawn_cells = [Vector2i(4, 4)]

	_wm._on_mission_launched("the_gap", PackedStringArray([]), 1)

	assert_object(_wm._wave_config).is_equal(cfg)
	assert_int(_wm._wave_scripts_count).is_equal(2)
	assert_array(_wm._spawn_cells).is_equal([Vector2i(4, 4)])
	assert_int(_wm._wave_index).is_equal(0)
	assert_int(_wm._round_robin_counter).is_equal(0)


func test_mission_launched_emits_scout_entry_preview_for_wave_1() -> void:
	var cfg: WaveConfig = _make_wave_config([3])  # wave 1 has 3 entries (all goblin)
	_wm._wave_config_loader = _stub_loader_for(cfg)

	_wm._on_mission_launched("the_gap", PackedStringArray([]), 1)

	assert_bool(_spy.was_emitted("wave_preview_available")).is_true()
	var args: Array = (_spy.emissions["wave_preview_available"] as Array)[0]
	assert_int(args[0]).is_equal(1)  # next_wave_number
	var composition: Array = args[1]
	assert_int(composition.size()).is_equal(1)  # 1 unique monster_id (goblin)
	assert_int(int((composition[0] as Dictionary)["count"])).is_equal(3)
	assert_vector(args[2] as Vector2i).is_equal(Vector2i(-1, -1))  # no BOSS entry in this wave


# ---------------------------------------------------------------------------
# Mission HUD ADR-0031 (Story 006, closes tower.md's OQ-11): boss_spawn_cell
# preview, computed read-only (never mutates _round_robin_counter).
# ---------------------------------------------------------------------------

func test_wave_preview_available_reports_real_boss_spawn_cell_for_boss_wave() -> void:
	var cfg := WaveConfig.new()
	var script := WaveScript.new()
	script.entries.append(WaveSpawnEntry.new(&"goblin", 0.0))
	script.entries.append(WaveSpawnEntry.new(&"goblin_warlord_boss", 0.0))  # real BOSS-tier content
	cfg.wave_scripts.append(script)
	_wm._wave_config_loader = _stub_loader_for(cfg)

	_wm._on_mission_launched("the_gap", PackedStringArray([]), 1)

	var args: Array = (_spy.emissions["wave_preview_available"] as Array)[0]
	assert_vector(args[2] as Vector2i).is_equal(_stub_grid.spawn_cells[0])


func test_boss_spawn_cell_preview_does_not_mutate_round_robin_counter() -> void:
	var cfg := WaveConfig.new()
	var script := WaveScript.new()
	script.entries.append(WaveSpawnEntry.new(&"goblin", 0.0))
	script.entries.append(WaveSpawnEntry.new(&"goblin_warlord_boss", 0.0))
	cfg.wave_scripts.append(script)
	_wm._wave_config_loader = _stub_loader_for(cfg)

	_wm._on_mission_launched("the_gap", PackedStringArray([]), 1)

	assert_int(_wm._round_robin_counter).is_equal(0)  # preview must not consume real spawn state

# ---------------------------------------------------------------------------
# AC-19: empty WaveConfig.wave_scripts -> immediate MISSION_COMPLETE, no
# PRE_WAVE/WAVE_ACTIVE/INTERMISSION.
# ---------------------------------------------------------------------------

func test_empty_wave_scripts_triggers_immediate_mission_complete() -> void:
	var cfg := WaveConfig.new()  # wave_scripts defaults to []
	_wm._wave_config_loader = _stub_loader_for(cfg)

	await assert_error(func() -> void: _wm._on_mission_launched("the_gap", PackedStringArray([]), 1)) \
		.is_push_error("WaveManager: WaveConfig has 0 wave_scripts — mission has no waves. Triggering MISSION_COMPLETE immediately.")

	assert_int(_wm._phase).is_equal(WaveManager.Phase.MISSION_COMPLETE)
	var args: Array = (_spy.emissions["mission_phase_changed"] as Array)[0]
	assert_str(args[1]).is_equal("MISSION_COMPLETE")
	# SCOUT was never entered — its timer was never started.
	assert_bool(_wm._scout_timer.is_stopped()).is_true()
	assert_bool(_spy.was_emitted("wave_preview_available")).is_false()

	# No further wave-lifecycle progression even if a stale timer fires.
	_wm._scout_timer.emit_signal("timeout")
	assert_int(_wm._phase).is_equal(WaveManager.Phase.MISSION_COMPLETE)

# ---------------------------------------------------------------------------
# AC-36: empty spawn cells -> immediate MISSION_COMPLETE, no crash.
# ---------------------------------------------------------------------------

func test_empty_spawn_cells_triggers_immediate_mission_complete() -> void:
	var cfg: WaveConfig = _make_wave_config([1])
	_wm._wave_config_loader = _stub_loader_for(cfg)
	_stub_grid.spawn_cells = []

	await assert_error(func() -> void: _wm._on_mission_launched("the_gap", PackedStringArray([]), 1)) \
		.is_push_error("WaveManager: 0 spawn cells — cannot spawn any monsters. Triggering MISSION_COMPLETE immediately.")

	assert_int(_wm._phase).is_equal(WaveManager.Phase.MISSION_COMPLETE)
	assert_bool(_wm._scout_timer.is_stopped()).is_true()

# ---------------------------------------------------------------------------
# AC-20: full state reset (7 fields — see suite doc comment on the
# _rebuild_pending_gate gap) when restarting from a terminal phase.
# ---------------------------------------------------------------------------

func test_mission_launched_resets_all_seven_state_fields_from_defeat() -> void:
	_wm._phase = WaveManager.Phase.DEFEAT
	_wm._wave_index = 4
	_wm._round_robin_counter = 3
	_wm._enemies_alive = 7
	_wm._all_spawns_fired = true
	_wm._phase_locked = true
	_wm._wave_clear_fired = true
	_wm._templates_ready = true

	var cfg: WaveConfig = _make_wave_config([1])
	_wm._wave_config_loader = _stub_loader_for(cfg)

	_wm._on_mission_launched("the_gap", PackedStringArray([]), 1)

	assert_int(_wm._wave_index).is_equal(0)
	assert_int(_wm._round_robin_counter).is_equal(0)
	assert_int(_wm._enemies_alive).is_equal(0)
	assert_bool(_wm._all_spawns_fired).is_false()
	assert_bool(_wm._phase_locked).is_false()
	assert_bool(_wm._wave_clear_fired).is_false()
	assert_bool(_wm._templates_ready).is_false()
	assert_int(_wm._phase).is_equal(WaveManager.Phase.SCOUT)


## INTERMISSION-with-15s-remaining sub-case: a fresh mission_launched cancels
## the in-flight intermission timer — the partial intermission is discarded,
## and its stale timeout must not fire PRE_WAVE afterward.
func test_mission_launched_from_intermission_cancels_in_flight_timer() -> void:
	_wm._phase = WaveManager.Phase.INTERMISSION
	_wm._intermission_timer.start()
	assert_bool(_wm._intermission_timer.is_stopped()).is_false()

	var cfg: WaveConfig = _make_wave_config([1])
	_wm._wave_config_loader = _stub_loader_for(cfg)

	_wm._on_mission_launched("the_gap", PackedStringArray([]), 1)

	assert_bool(_wm._intermission_timer.is_stopped()).is_true()
	assert_int(_wm._phase).is_equal(WaveManager.Phase.SCOUT)

	# The discarded intermission's stale timeout must not fire PRE_WAVE — the
	# WaveManager is now in SCOUT, so _on_intermission_timer_timeout()'s own
	# `if _phase != Phase.INTERMISSION: return` guard discards it.
	_wm._intermission_timer.emit_signal("timeout")
	assert_int(_wm._phase).is_equal(WaveManager.Phase.SCOUT)

# ---------------------------------------------------------------------------
# AC-41: wave_time_budget overrun logs a content error identifying the
# offending wave index; mission continues without clamping or aborting.
# ---------------------------------------------------------------------------

func test_wave_time_budget_overrun_logs_error_and_continues() -> void:
	var cfg := WaveConfig.new()
	cfg.wave_time_budget = 90.0
	var over_budget_script := WaveScript.new()
	over_budget_script.entries = [
		WaveSpawnEntry.new(&"goblin", 0.0),
		WaveSpawnEntry.new(&"goblin", 50.0),
		WaveSpawnEntry.new(&"goblin", 50.0),  # sum = 100.0 > 90.0
	]
	cfg.wave_scripts = [over_budget_script]
	_wm._wave_config_loader = _stub_loader_for(cfg)

	await assert_error(func() -> void: _wm._on_mission_launched("the_gap", PackedStringArray([]), 1)) \
		.is_push_error("WaveManager: wave index 1's pre_delay sum 100.00 exceeds wave_time_budget 90.00")

	# Mission continues normally — no abort to MISSION_COMPLETE.
	assert_int(_wm._phase).is_equal(WaveManager.Phase.SCOUT)
	assert_bool(_wm._scout_timer.is_stopped()).is_false()


## Negative case: all waves within budget -> no error logged.
func test_wave_time_budget_within_range_logs_no_error() -> void:
	var cfg := WaveConfig.new()
	cfg.wave_time_budget = 90.0
	var within_budget_script := WaveScript.new()
	within_budget_script.entries = [
		WaveSpawnEntry.new(&"goblin", 10.0),
		WaveSpawnEntry.new(&"goblin", 10.0),  # sum = 20.0 <= 90.0
	]
	cfg.wave_scripts = [within_budget_script]
	_wm._wave_config_loader = _stub_loader_for(cfg)

	_wm._on_mission_launched("the_gap", PackedStringArray([]), 1)

	assert_int(_wm._phase).is_equal(WaveManager.Phase.SCOUT)


## Multi-wave case: only the offending wave's index is reported, and it is
## 1-based (matching _wave_index's convention), not 0-based.
func test_wave_time_budget_overrun_identifies_correct_offending_wave_index() -> void:
	var cfg := WaveConfig.new()
	cfg.wave_time_budget = 50.0
	var wave_1_ok := WaveScript.new()
	wave_1_ok.entries = [WaveSpawnEntry.new(&"goblin", 10.0)]
	var wave_2_over := WaveScript.new()
	wave_2_over.entries = [WaveSpawnEntry.new(&"goblin", 60.0)]
	cfg.wave_scripts = [wave_1_ok, wave_2_over]
	_wm._wave_config_loader = _stub_loader_for(cfg)

	await assert_error(func() -> void: _wm._on_mission_launched("the_gap", PackedStringArray([]), 1)) \
		.is_push_error("WaveManager: wave index 2's pre_delay sum 60.00 exceeds wave_time_budget 50.00")

# ---------------------------------------------------------------------------
# difficulty_growth_rate validation reuse (Story 004's
# _validate_difficulty_growth_rate(), called from the real production path).
# ---------------------------------------------------------------------------

func test_mission_launched_assigns_wave_config_growth_rate_and_validates_in_range() -> void:
	var cfg: WaveConfig = _make_wave_config([1], 90.0, 0.20)
	_wm._wave_config_loader = _stub_loader_for(cfg)

	_wm._on_mission_launched("the_gap", PackedStringArray([]), 1)

	assert_float(_wm.difficulty_growth_rate).is_equal(0.20)
	assert_int(_wm._phase).is_equal(WaveManager.Phase.SCOUT)  # not aborted


func test_mission_launched_logs_error_for_out_of_range_growth_rate_but_does_not_abort() -> void:
	var cfg: WaveConfig = _make_wave_config([1], 90.0, 0.30)  # above [0.10, 0.25]
	_wm._wave_config_loader = _stub_loader_for(cfg)

	await assert_error(func() -> void: _wm._on_mission_launched("the_gap", PackedStringArray([]), 1)) \
		.is_push_error("WaveManager: difficulty_growth_rate 0.30 outside valid range [0.10, 0.25]")

	assert_float(_wm.difficulty_growth_rate).is_equal(0.30)  # not clamped
	assert_int(_wm._phase).is_equal(WaveManager.Phase.SCOUT)  # not aborted

# ---------------------------------------------------------------------------
# mission_launched signature: difficulty_tier is the 3rd argument, stored
# fresh every call (not part of _reset_all_state()'s field list).
# ---------------------------------------------------------------------------

func test_mission_launched_stores_difficulty_tier_from_third_argument() -> void:
	var cfg: WaveConfig = _make_wave_config([1])
	_wm._wave_config_loader = _stub_loader_for(cfg)

	_wm._on_mission_launched("the_gap", PackedStringArray([]), 3)

	assert_int(_wm._difficulty_tier).is_equal(3)


func test_mission_launched_real_signal_has_three_parameters() -> void:
	var signal_list: Array = GEventBus.get_signal_list()
	var found: Dictionary = {}
	for sig: Dictionary in signal_list:
		if sig["name"] == "mission_launched":
			found = sig
			break
	assert_bool(found.is_empty()).is_false()
	var sig_args: Array = found["args"]
	assert_int(sig_args.size()).is_equal(3)
	assert_str(sig_args[2]["name"]).is_equal("difficulty_tier")

# ---------------------------------------------------------------------------
# _load_wave_config() / _default_load_wave_config(): missing .tres content is
# handled gracefully (no crash) — no real WaveConfig .tres content exists yet
# for any mission, so this is the path every real mission_launched hits today.
# ---------------------------------------------------------------------------

## NOTE: GDScript lambdas capture outer-scope locals by value at creation
## time, not by reference — assigning to an outer var from inside the
## assert_error() callable would silently leave it null. Call the function
## twice instead: once wrapped for the error assertion, once directly (pure,
## deterministic, no side effects beyond logging) to capture the real return
## value in this function's own scope.
func test_default_load_wave_config_missing_file_returns_empty_fallback_without_crashing() -> void:
	await assert_error(func() -> void: _wm._default_load_wave_config("no_such_mission")) \
		.is_push_error("WaveManager: no WaveConfig found at res://assets/data/waves/no_such_mission_waves.tres — using an empty fallback (0 wave_scripts).")

	var cfg: WaveConfig = _wm._default_load_wave_config("no_such_mission")
	assert_object(cfg).is_not_null()
	assert_bool(cfg.wave_scripts.is_empty()).is_true()


## _load_wave_config() must route through the injectable _wave_config_loader
## seam rather than always calling the default filesystem-backed resolver.
func test_load_wave_config_routes_through_injectable_loader_seam() -> void:
	var cfg: WaveConfig = _make_wave_config([2])
	_wm._wave_config_loader = _stub_loader_for(cfg)

	var result: WaveConfig = _wm._load_wave_config("any_mission_id")

	assert_object(result).is_equal(cfg)

# ---------------------------------------------------------------------------
# WaveSpawnEntry Resource conversion (Story 006): must remain constructible
# and usable exactly as before, now as a Resource instead of a RefCounted, and
# must embed correctly inside WaveScript.entries (Array[WaveSpawnEntry]).
# ---------------------------------------------------------------------------

func test_wave_spawn_entry_is_now_a_resource() -> void:
	var entry := WaveSpawnEntry.new(&"goblin", 1.5, 2)

	assert_bool(entry is Resource).is_true()
	assert_str(entry.monster_id).is_equal("goblin")
	assert_float(entry.pre_delay).is_equal(1.5)
	assert_int(entry.difficulty_tier).is_equal(2)


func test_wave_script_embeds_wave_spawn_entries_as_typed_array() -> void:
	var script := WaveScript.new()
	script.entries.append(WaveSpawnEntry.new(&"orc", 0.0))
	script.entries.append(WaveSpawnEntry.new(&"goblin", 0.0))

	assert_int(script.entries.size()).is_equal(2)
	assert_str(script.entries[0].monster_id).is_equal("orc")


func test_wave_config_embeds_wave_scripts_as_typed_array() -> void:
	var cfg: WaveConfig = _make_wave_config([1, 2, 3])

	assert_int(cfg.wave_scripts.size()).is_equal(3)
	assert_int(cfg.wave_scripts[2].entries.size()).is_equal(3)


## Issue 1 field-schema resolution: both `wave_time_budget` (AC-41, actively
## used) and `reward_base` (ADR-0009 canonical field, unused as of this story)
## must exist on WaveConfig — neither silently dropped.
func test_wave_config_has_both_wave_time_budget_and_reward_base_fields() -> void:
	var cfg := WaveConfig.new()

	assert_float(cfg.wave_time_budget).is_equal(90.0)
	assert_float(cfg.reward_base).is_equal(1.0)

# ---------------------------------------------------------------------------
# Performance / Control Manifest guardrail: WaveConfig loading and the full
# state reset happen once per mission_launched, not per-frame.
#
# Code review fix (Story 006): replaced a textual-source-inspection version of
# this test (flagged as a repeat of Story 004's known brittle pattern — it
# sliced the file between two function-name strings and counted substring
# occurrences, which was vulnerable to "_default_load_wave_config(" containing
# "_load_wave_config(" as a substring, and to source reordering making the
# slice indices invalid). This version uses a call-counting stub Callable via
# the existing _wave_config_loader seam instead — it verifies actual runtime
# behavior, not source text shape, and has no substring-collision risk.
# ---------------------------------------------------------------------------

func test_load_wave_config_called_exactly_once_per_mission_launched() -> void:
	# NOTE: GDScript lambdas capture outer-scope locals by value at creation
	# time — a plain `var call_count: int` incremented inside the closure would
	# only mutate the closure's own snapshot, never this outer variable (same
	# quirk as the missing-file test above). Arrays are reference types, so
	# mutating call_count[0] from inside the closure is visible here.
	var call_count: Array = [0]
	var cfg: WaveConfig = _make_wave_config([1])
	_wm._wave_config_loader = func(_mission_id: String) -> WaveConfig:
		call_count[0] += 1
		return cfg

	_wm._on_mission_launched("the_gap", PackedStringArray([]), 1)

	assert_int(call_count[0]).is_equal(1)

# ---------------------------------------------------------------------------
# Code review fix (Story 006): null-safety regression test for a
# non-conforming _wave_config_loader override. _default_load_wave_config()
# never returns null, but the Callable seam is explicitly injectable — a
# future override that violates that contract must not crash
# _on_mission_launched(), per the defensive fallback added to that function.
# ---------------------------------------------------------------------------

func test_mission_launched_handles_null_wave_config_loader_without_crashing() -> void:
	_wm._wave_config_loader = func(_mission_id: String) -> WaveConfig: return null

	await assert_error(func() -> void: _wm._on_mission_launched("the_gap", PackedStringArray([]), 1)) \
		.is_push_error("WaveManager: _wave_config_loader returned null for mission 'the_gap' — using an empty fallback (0 wave_scripts).")

	# Falls through to AC-19's empty-wave_scripts guard — same as a real
	# missing-file fallback would.
	assert_int(_wm._phase).is_equal(WaveManager.Phase.MISSION_COMPLETE)

# ---------------------------------------------------------------------------
# Code review follow-up (Story 006): WaveManager's own _ready() subscription
# to mission_launched had no direct real-signal proof (every test above calls
# _wm._on_mission_launched() directly, to avoid double-handling by the live
# GWaveManager Autoload during headless runs). Mirrors the disconnect-ambient-
# subscription approach suggested for hero_died in Story 002's code review,
# closing the asymmetry with SavePersistence's equivalent real-signal test.
# ---------------------------------------------------------------------------

func test_wave_manager_own_ready_subscription_wires_real_mission_launched_signal() -> void:
	var ambient_connected: bool = GEventBus.mission_launched.is_connected(GWaveManager._on_mission_launched)
	if ambient_connected:
		GEventBus.mission_launched.disconnect(GWaveManager._on_mission_launched)

	var cfg: WaveConfig = _make_wave_config([1])
	_wm._wave_config_loader = _stub_loader_for(cfg)

	GEventBus.mission_launched.emit("the_gap", PackedStringArray([]), 1)

	assert_int(_wm._phase).is_equal(WaveManager.Phase.SCOUT)

	if ambient_connected:
		GEventBus.mission_launched.connect(GWaveManager._on_mission_launched)

# ---------------------------------------------------------------------------
# Code review follow-up (Story 006): proves _build_composition_preview()'s
# WaveConfig-vs-seam fallback correctly checks the seam when a wave_number is
# out of range for a loaded (non-null) WaveConfig, rather than silently
# returning empty just because _wave_config is set.
# ---------------------------------------------------------------------------

func test_build_composition_preview_falls_back_to_seam_when_wave_number_exceeds_loaded_config() -> void:
	var cfg: WaveConfig = _make_wave_config([1])  # only 1 wave in the loaded config
	_wm._wave_config = cfg
	_wm._wave_composition_by_number[5] = [WaveSpawnEntry.new(&"orc", 0.0)]  # seam has data for wave 5

	var composition: Array = _wm._build_composition_preview(5)

	assert_int(composition.size()).is_equal(1)
	assert_str(composition[0]["monster_id"]).is_equal("orc")
