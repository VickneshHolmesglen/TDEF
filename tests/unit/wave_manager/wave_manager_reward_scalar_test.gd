extends GdUnitTestSuite

## WaveManager wave-reward-scalar formula (F1) and penultimate-wave flag tests.
## Design source: production/epics/epic-04-wave-manager/story-004-reward-scalar-penultimate-flag.md
## ADR-0012: Wave Manager FSM Architecture.
##
## Deviations from the story's Implementation Notes (flagged upfront by the
## requesting agent, not discovered independently):
##   1. The story's pseudocode calls a nonexistent `_total_wave_count()`.
##      Story 001's actual field is `_wave_scripts_count: int` — used directly
##      here and in the implementation.
##   2. The story's pseudocode computes `_wave_reward_scalar` inside
##      _enter_wave_active(), assuming wave_started (also emitted from that
##      function, in the pseudocode's model) reads the freshly-computed value.
##      Story 002 (landed after this story was written) moved wave_started's
##      emission into _transition_to(), strictly before _enter_phase() /
##      _enter_wave_active(). The implementation therefore computes
##      _wave_reward_scalar inside _transition_to() itself, at the same point
##      wave_started is emitted — see wave_manager.gd's own comment at that
##      call site. This suite's payload-consistency tests exist specifically
##      to prove that fix actually satisfies AC-17.
##
## Follows the EventBusSpy + direct-invocation conventions established in
## tests/unit/wave_manager/wave_manager_defeat_victory_test.gd and
## tests/integration/wave_manager/wave_manager_lifecycle_events_test.gd.

var _wm: WaveManager
var _spy: EventBusSpy


func before_test() -> void:
	_wm = WaveManager.new()
	add_child(_wm)  # triggers _ready() — creates timers, subscribes to EventBus

	# Story 007 (round-robin-spawn-cells): _resolve_spawn_cell() now requires a
	# non-empty _spawn_cells (previously this suite relied on the flat, now-dead
	# _spawn_cell placeholder field) — default single-cell fixture here; tests
	# that care about the resolved cell value override it directly.
	_wm._spawn_cells = [Vector2i(0, 0)]

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.wave_started)
	_spy.watch(GEventBus.monster_spawn_requested)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	remove_child(_wm)
	_wm.free()

# ---------------------------------------------------------------------------
# F1 / AC-17: boundary table — wave_reward_scalar = (1 + r)^(w - 1),
# w = wave about to start. ±0.001 tolerance per the story's boundary table.
# ---------------------------------------------------------------------------

func test_wave_reward_scalar_wave_1_r020_equals_one() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._templates_ready = true
	_wm.difficulty_growth_rate = 0.20
	_wm._wave_index = 0  # about to become wave 1

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_float(_wm._wave_reward_scalar).is_equal_approx(1.0, 0.001)


func test_wave_reward_scalar_wave_1_r025_equals_one_regardless_of_r() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._templates_ready = true
	_wm.difficulty_growth_rate = 0.25
	_wm._wave_index = 0

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_float(_wm._wave_reward_scalar).is_equal_approx(1.0, 0.001)


func test_wave_reward_scalar_wave_4_r020_equals_1_728() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._templates_ready = true
	_wm.difficulty_growth_rate = 0.20
	_wm._wave_index = 3  # about to become wave 4

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_float(_wm._wave_reward_scalar).is_equal_approx(1.728, 0.001)


func test_wave_reward_scalar_wave_4_r025_equals_1_953() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._templates_ready = true
	_wm.difficulty_growth_rate = 0.25
	_wm._wave_index = 3

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_float(_wm._wave_reward_scalar).is_equal_approx(1.953, 0.001)


func test_wave_reward_scalar_wave_8_r020_equals_3_583() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._templates_ready = true
	_wm.difficulty_growth_rate = 0.20
	_wm._wave_index = 7  # about to become wave 8

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_float(_wm._wave_reward_scalar).is_equal_approx(3.583, 0.001)


func test_wave_reward_scalar_wave_8_r025_equals_4_768() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._templates_ready = true
	_wm.difficulty_growth_rate = 0.25
	_wm._wave_index = 7

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_float(_wm._wave_reward_scalar).is_equal_approx(4.768, 0.001)

# ---------------------------------------------------------------------------
# AC-17 payload consistency: wave_started.wave_difficulty must match
# monster_spawn_requested.wave_reward_scalar for the SAME wave. These tests
# specifically prove Correction 2's fix (see suite doc comment) actually
# closes the staleness gap the story's original pseudocode would have left.
# ---------------------------------------------------------------------------

func test_wave_started_and_monster_spawn_requested_carry_same_scalar_for_same_wave() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._templates_ready = true
	_wm.difficulty_growth_rate = 0.20
	_wm._wave_index = 3  # about to become wave 4 -> scalar 1.728
	_wm._wave_spawn_entries = [WaveSpawnEntry.new(&"goblin", 0.0)]
	_wm._spawn_cells = [Vector2i(1, 1)]

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_bool(_spy.was_emitted("wave_started")).is_true()
	assert_bool(_spy.was_emitted("monster_spawn_requested")).is_true()

	var wave_started_args: Array = (_spy.emissions["wave_started"] as Array)[0]
	var spawn_args: Array = (_spy.emissions["monster_spawn_requested"] as Array)[0]
	var payload: MonsterSpawnRequest = spawn_args[0]

	var wave_started_scalar: float = wave_started_args[2]
	assert_float(wave_started_scalar).is_equal_approx(1.728, 0.001)
	assert_float(payload.wave_reward_scalar).is_equal_approx(1.728, 0.001)
	assert_float(wave_started_scalar).is_equal(payload.wave_reward_scalar)


## Regression proving Correction 2 actually matters across multiple waves:
## without the fix, wave 2's wave_started would report wave 1's stale scalar
## while monster_spawn_requested (computed at a different point under the
## story's original pseudocode) would report the fresh one. Driving two
## consecutive WAVE_ACTIVE entries and checking both signals stay matched on
## EACH wave closes that gap.
func test_wave_started_and_monster_spawn_requested_stay_consistent_across_consecutive_waves() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._templates_ready = true
	_wm.difficulty_growth_rate = 0.20
	_wm._wave_index = 0
	_wm._wave_spawn_entries = [WaveSpawnEntry.new(&"goblin", 0.0)]

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)  # wave 1 -> scalar 1.0

	var first_wave_started: Array = (_spy.emissions["wave_started"] as Array)[0]
	var first_spawn_payload: MonsterSpawnRequest = (_spy.emissions["monster_spawn_requested"] as Array)[0][0]
	assert_float(first_wave_started[2]).is_equal(first_spawn_payload.wave_reward_scalar)
	assert_float(first_wave_started[2]).is_equal_approx(1.0, 0.001)

	# Drive a second PRE_WAVE -> WAVE_ACTIVE transition directly (test-only
	# direct _phase assignment, matching this suite family's established
	# convention — see wave_manager_lifecycle_events_test.gd).
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)  # wave 2 -> scalar 1.2

	var second_wave_started: Array = (_spy.emissions["wave_started"] as Array)[1]
	var second_spawn_payload: MonsterSpawnRequest = (_spy.emissions["monster_spawn_requested"] as Array)[1][0]
	assert_float(second_wave_started[2]).is_equal_approx(1.2, 0.001)
	assert_float(second_wave_started[2]).is_equal(second_spawn_payload.wave_reward_scalar)

# ---------------------------------------------------------------------------
# Rule 15c / AC-12: _is_penultimate_wave() correctness, including the
# sub-5-wave exemption.
# ---------------------------------------------------------------------------

func test_is_penultimate_wave_true_for_5_wave_mission_at_wave_4() -> void:
	_wm._wave_scripts_count = 5
	_wm._wave_index = 4

	assert_bool(_wm._is_penultimate_wave()).is_true()


func test_is_penultimate_wave_false_for_5_wave_mission_at_wave_3() -> void:
	_wm._wave_scripts_count = 5
	_wm._wave_index = 3

	assert_bool(_wm._is_penultimate_wave()).is_false()


## Sub-5-wave exemption (Rule 15c): wave 3 of a 4-wave mission would
## otherwise satisfy _wave_index == total - 1, but total < 5 exempts it.
func test_is_penultimate_wave_false_for_4_wave_mission_at_would_be_penultimate_wave() -> void:
	_wm._wave_scripts_count = 4
	_wm._wave_index = 3

	assert_bool(_wm._is_penultimate_wave()).is_false()


func test_is_penultimate_wave_false_for_final_wave() -> void:
	_wm._wave_scripts_count = 5
	_wm._wave_index = 5

	assert_bool(_wm._is_penultimate_wave()).is_false()


func test_is_penultimate_wave_flag_forwarded_into_monster_spawn_requested_payload() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._templates_ready = true
	_wm._wave_scripts_count = 5
	_wm._wave_index = 3  # about to become wave 4 -> penultimate
	_wm._wave_spawn_entries = [WaveSpawnEntry.new(&"goblin", 0.0)]

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	var spawn_args: Array = (_spy.emissions["monster_spawn_requested"] as Array)[0]
	var payload: MonsterSpawnRequest = spawn_args[0]
	assert_bool(payload.is_penultimate_wave).is_true()


func test_is_penultimate_wave_flag_false_in_monster_spawn_requested_payload_when_not_penultimate() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._templates_ready = true
	_wm._wave_scripts_count = 5
	_wm._wave_index = 1  # about to become wave 2 -> not penultimate
	_wm._wave_spawn_entries = [WaveSpawnEntry.new(&"goblin", 0.0)]

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	var spawn_args: Array = (_spy.emissions["monster_spawn_requested"] as Array)[0]
	var payload: MonsterSpawnRequest = spawn_args[0]
	assert_bool(payload.is_penultimate_wave).is_false()

# ---------------------------------------------------------------------------
# AC-12: MonsterSpawnRequest payload has exactly 6 fields, no more no fewer.
# ---------------------------------------------------------------------------

func test_monster_spawn_request_payload_has_exactly_six_fields() -> void:
	var p := MonsterSpawnRequest.new()
	var expected_fields: Array = [
		"monster_id", "spawn_cell", "wave_index", "difficulty_tier",
		"wave_reward_scalar", "is_penultimate_wave",
	]
	var actual_fields: Array = []
	for prop: Dictionary in p.get_property_list():
		if (prop["usage"] as int) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			actual_fields.append(prop["name"])

	assert_int(actual_fields.size()).is_equal(6)
	for field_name: String in expected_fields:
		assert_bool(actual_fields.has(field_name)).is_true()

# ---------------------------------------------------------------------------
# Runtime validation: 0.10 <= difficulty_growth_rate <= 0.25 (inclusive both
# ends). Out-of-range values log a content error but are NOT clamped. No
# call site exists yet — Story 006 owns the future mission_launched handler
# that will call _validate_difficulty_growth_rate(); tested here via direct
# invocation, matching this codebase's established pattern for not-yet-wired
# functionality (e.g. _is_final_wave() prior to Story 001's wiring).
# ---------------------------------------------------------------------------

func test_validate_difficulty_growth_rate_logs_error_when_above_max() -> void:
	_wm.difficulty_growth_rate = 0.30

	await assert_error(func() -> void: _wm._validate_difficulty_growth_rate()) \
		.is_push_error("WaveManager: difficulty_growth_rate 0.30 outside valid range [0.10, 0.25]")
	assert_float(_wm.difficulty_growth_rate).is_equal(0.30)  # not clamped


func test_validate_difficulty_growth_rate_logs_error_when_below_min() -> void:
	_wm.difficulty_growth_rate = 0.05

	await assert_error(func() -> void: _wm._validate_difficulty_growth_rate()) \
		.is_push_error("WaveManager: difficulty_growth_rate 0.05 outside valid range [0.10, 0.25]")
	assert_float(_wm.difficulty_growth_rate).is_equal(0.05)  # not clamped


## Boundary-inclusive check: 0.10 is exactly the documented lower bound and
## must NOT log an error (AC's "0.10 <= r <= 0.25" is inclusive). No
## assert_error wrapper is used here — an unexpected push_error would be
## visible as unhandled engine error output, distinct from this test's
## deliberate absence-of-error assertions below.
func test_validate_difficulty_growth_rate_does_not_log_at_lower_boundary_inclusive() -> void:
	_wm.difficulty_growth_rate = 0.10

	_wm._validate_difficulty_growth_rate()

	assert_float(_wm.difficulty_growth_rate).is_equal(0.10)


## Boundary-inclusive check: 0.25 is exactly the documented upper bound and
## must NOT log an error.
func test_validate_difficulty_growth_rate_does_not_log_at_upper_boundary_inclusive() -> void:
	_wm.difficulty_growth_rate = 0.25

	_wm._validate_difficulty_growth_rate()

	assert_float(_wm.difficulty_growth_rate).is_equal(0.25)


func test_validate_difficulty_growth_rate_does_not_log_for_default_value() -> void:
	_wm.difficulty_growth_rate = 0.20

	_wm._validate_difficulty_growth_rate()

	assert_float(_wm.difficulty_growth_rate).is_equal(0.20)

# ---------------------------------------------------------------------------
# Performance / Control Manifest guardrail: the formula and the penultimate
# check are each O(1) — one pow() call and two integer comparisons,
# respectively — evaluated once per wave (at _transition_to(WAVE_ACTIVE)) or
# once per spawn (at _is_penultimate_wave()'s call site in
# _run_spawn_sequence()), never per-frame. Verified here by source inspection,
# mirroring this suite family's existing structural tests (e.g.
# wave_manager_spawn_test.gd's 3-guard-pattern check).
# ---------------------------------------------------------------------------

func test_wave_reward_scalar_computed_once_per_wave_not_per_spawn() -> void:
	var source: String = FileAccess.get_file_as_string("res://src/gameplay/wave_manager.gd")

	# The pow() call for _wave_reward_scalar appears exactly once in the file,
	# inside _transition_to() — not inside _run_spawn_sequence()'s per-entry
	# loop, which would make it O(entries) instead of O(1) per wave.
	var occurrences: int = source.count("_wave_reward_scalar = pow(")
	assert_int(occurrences).is_equal(1)

	var run_spawn_sequence_start: int = source.find("func _run_spawn_sequence")
	var transition_to_start: int = source.find("func _transition_to")
	assert_int(run_spawn_sequence_start).is_greater(-1)
	assert_int(transition_to_start).is_greater(-1)
	# The single pow() call site is textually inside _transition_to(), which
	# is defined before _run_spawn_sequence() in this file.
	var pow_call_index: int = source.find("_wave_reward_scalar = pow(")
	assert_int(pow_call_index).is_greater(transition_to_start)
	assert_int(pow_call_index).is_less(run_spawn_sequence_start)
