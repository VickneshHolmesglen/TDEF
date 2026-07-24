extends GdUnitTestSuite

## WaveManager Rule 22 waves-2+ pathfinding rebuild gate tests.
## Covers: Rule 22, AC-33 (positive/negative), gate mutual exclusivity, the
## path_invalidated early-fire guard, and the subscription-lifecycle
## (no-accumulation) case from this story's QA Test Cases.
## Design source: production/epics/epic-04-wave-manager/story-005-rebuild-gate-waves-2plus.md
## Governing ADRs: docs/architecture/adr-0012-wave-manager-fsm.md (Accepted)
##                  docs/architecture/adr-0004-pathfinding-strategy.md (Accepted)
##
## Two real gaps closed by this story's implementation, beyond the story's own
## Implementation Notes pseudocode (see wave_manager.gd's _check_rebuild_gate()
## / _on_path_invalidated() doc comments for full detail — summarized here):
##   1. `_reset_all_state()` now also resets `_rebuild_pending_gate` (the field
##      did not exist when Story 006 wrote that function).
##   2. `_check_rebuild_gate()` is self-correcting: it explicitly resets the
##      flag to `false` in its `else` branch (not just relying on
##      `_on_path_invalidated()` having already done so), and both branches
##      guard connect()/disconnect() with `Signal.is_connected()` so this
##      function can never double-connect or double-disconnect
##      `GEventBus.path_invalidated` regardless of prior state.
##
## Follows the EventBusSpy + direct-field-injection + direct-handler-invocation
## conventions established in wave_manager_boss_wave_clear_test.gd and
## wave_manager_config_loading_test.gd. `GPathfindingSystem.is_rebuild_pending()`
## has no test-injection seam on WaveManager (the story's own pseudocode calls
## the real Autoload directly, matching the wave-1 `templates_ready` gate's
## precedent of calling `GEventBus`/`GPathfindingSystem` directly rather than
## through an injected reference) — this suite instead manipulates the real,
## ambient `GPathfindingSystem` Autoload's `_rebuild_queued` field directly
## (save/restore around each test), the same class of ambient-Autoload
## interaction already exercised directly in tests/integration/core/combat_loop_test.gd
## and tests/integration/foundation/scene_manager_transition_test.gd.

var _wm: WaveManager
var _spy: EventBusSpy
var _saved_rebuild_queued: bool


func before_test() -> void:
	_wm = WaveManager.new()
	add_child(_wm)  # triggers _ready() — creates timers, subscribes to EventBus

	_wm._spawn_cells = [Vector2i(0, 0)]

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.monster_spawn_requested)
	_spy.watch(GEventBus.mission_phase_changed)

	# Save/restore the real ambient GPathfindingSystem Autoload's rebuild-queued
	# state — WaveManager's _check_rebuild_gate() calls it directly (no
	# test-injection seam), so this suite manipulates the real Autoload's field
	# instead, restoring it in after_test() to avoid leaking state into other
	# suites sharing the same headless test-run process.
	_saved_rebuild_queued = GPathfindingSystem._rebuild_queued
	GPathfindingSystem._rebuild_queued = false


func after_test() -> void:
	GPathfindingSystem._rebuild_queued = _saved_rebuild_queued
	# Defensive cleanup: if a test failed partway through and left this
	# suite's _wm still connected to the real GEventBus.path_invalidated
	# signal, disconnect it here so it can't leak into a later suite.
	if GEventBus.path_invalidated.is_connected(_wm._on_path_invalidated):
		GEventBus.path_invalidated.disconnect(_wm._on_path_invalidated)
	_spy.disconnect_all()
	_spy = null
	remove_child(_wm)
	_wm.free()


## Counts how many entries in sig's current connection list target callable —
## used to prove no duplicate connections accumulate (Gap 2 / subscription-
## lifecycle guard) without relying on is_connected() alone, which only
## reports true/false, not a count.
func _count_connections(sig: Signal, callable: Callable) -> int:
	var count: int = 0
	for conn: Dictionary in sig.get_connections():
		if conn["callable"] == callable:
			count += 1
	return count

# ---------------------------------------------------------------------------
# Rule 22 / _check_rebuild_gate(): positive case — sets the flag and subscribes.
# ---------------------------------------------------------------------------

func test_check_rebuild_gate_sets_flag_true_and_subscribes_when_rebuild_pending() -> void:
	GPathfindingSystem._rebuild_queued = true

	_wm._check_rebuild_gate()

	assert_bool(_wm._rebuild_pending_gate).is_true()
	assert_bool(GEventBus.path_invalidated.is_connected(_wm._on_path_invalidated)).is_true()
	assert_int(_count_connections(GEventBus.path_invalidated, _wm._on_path_invalidated)).is_equal(1)

# ---------------------------------------------------------------------------
# AC-33 (negative case) / _check_rebuild_gate(): no gate when rebuild isn't
# pending — flag stays false, no subscription.
# ---------------------------------------------------------------------------

func test_check_rebuild_gate_leaves_flag_false_and_does_not_subscribe_when_not_pending() -> void:
	GPathfindingSystem._rebuild_queued = false

	_wm._check_rebuild_gate()

	assert_bool(_wm._rebuild_pending_gate).is_false()
	assert_bool(GEventBus.path_invalidated.is_connected(_wm._on_path_invalidated)).is_false()

# ---------------------------------------------------------------------------
# Gap 2: _check_rebuild_gate() is self-correcting — a stale `true` flag left
# over from a previous wave (that somehow wasn't cleaned up) is defensively
# reset to `false` when the current call finds rebuild is no longer pending.
# ---------------------------------------------------------------------------

func test_check_rebuild_gate_defensively_resets_stale_true_flag_when_no_longer_pending() -> void:
	_wm._rebuild_pending_gate = true  # contrived stale state from a prior wave
	GPathfindingSystem._rebuild_queued = false

	_wm._check_rebuild_gate()

	assert_bool(_wm._rebuild_pending_gate).is_false()


## Gap 2 (defensive disconnect): a stale subscription left connected (e.g. by
## a hypothetical missed _on_path_invalidated() firing) is also disconnected
## by _check_rebuild_gate()'s negative branch, not just the flag reset.
func test_check_rebuild_gate_defensively_disconnects_stale_subscription_when_no_longer_pending() -> void:
	GEventBus.path_invalidated.connect(_wm._on_path_invalidated)  # simulate a stale, still-live subscription
	GPathfindingSystem._rebuild_queued = false

	_wm._check_rebuild_gate()

	assert_bool(GEventBus.path_invalidated.is_connected(_wm._on_path_invalidated)).is_false()


## Double-connect guard: calling _check_rebuild_gate() twice in a row while
## rebuild is still pending (simulating a hypothetical double-call before
## release) must not throw a "signal already connected" error, and must leave
## exactly one connection — not two.
func test_check_rebuild_gate_called_twice_while_pending_does_not_double_connect() -> void:
	GPathfindingSystem._rebuild_queued = true

	_wm._check_rebuild_gate()
	_wm._check_rebuild_gate()

	assert_int(_count_connections(GEventBus.path_invalidated, _wm._on_path_invalidated)).is_equal(1)

# ---------------------------------------------------------------------------
# _on_path_invalidated(): resets the flag and disconnects immediately.
# ---------------------------------------------------------------------------

func test_on_path_invalidated_resets_flag_and_disconnects() -> void:
	GPathfindingSystem._rebuild_queued = true
	_wm._check_rebuild_gate()
	assert_bool(GEventBus.path_invalidated.is_connected(_wm._on_path_invalidated)).is_true()

	GEventBus.path_invalidated.emit([Vector2i(1, 1)])

	assert_bool(_wm._rebuild_pending_gate).is_false()
	assert_bool(GEventBus.path_invalidated.is_connected(_wm._on_path_invalidated)).is_false()

# ---------------------------------------------------------------------------
# AC-33 (positive case): rebuild-pending gate blocks the first spawn of a
# waves-2+ wave until path_invalidated fires, then fires within the same
# emit() call (no extra frame delay) — mirrors the wave-1 templates_ready
# gate's own AC-11/AC-12 pattern (wave_manager_spawn_test.gd).
# ---------------------------------------------------------------------------

func test_wave2_gate_blocks_first_spawn_until_path_invalidated_then_fires_immediately() -> void:
	GPathfindingSystem._rebuild_queued = true
	_wm._phase = WaveManager.Phase.INTERMISSION
	_wm._check_rebuild_gate()
	assert_bool(_wm._rebuild_pending_gate).is_true()

	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 2
	_wm._spawn_active = true
	_wm._wave_spawn_entries = [WaveSpawnEntry.new(&"goblin", 0.0)]

	_wm._run_spawn_sequence()  # suspends on `await GEventBus.path_invalidated`
	assert_int(_spy.count("monster_spawn_requested")).is_equal(0)

	GEventBus.path_invalidated.emit([])

	assert_int(_spy.count("monster_spawn_requested")).is_equal(1)
	# Early-fire guard / handler-ownership proof: the dedicated handler (not
	# the coroutine) owns the reset + disconnect, and both have already run by
	# the time this line executes (same synchronous emit() call).
	assert_bool(_wm._rebuild_pending_gate).is_false()
	assert_bool(GEventBus.path_invalidated.is_connected(_wm._on_path_invalidated)).is_false()

# ---------------------------------------------------------------------------
# AC-33 (negative case): no gate when rebuild isn't pending — spawn sequencing
# begins immediately, no additional delay.
# ---------------------------------------------------------------------------

func test_wave2_no_gate_when_rebuild_not_pending_spawns_immediately() -> void:
	GPathfindingSystem._rebuild_queued = false
	_wm._phase = WaveManager.Phase.INTERMISSION
	_wm._check_rebuild_gate()
	assert_bool(_wm._rebuild_pending_gate).is_false()

	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 2
	_wm._spawn_active = true
	_wm._wave_spawn_entries = [WaveSpawnEntry.new(&"goblin", 0.0)]

	_wm._run_spawn_sequence()

	assert_int(_spy.count("monster_spawn_requested")).is_equal(1)

# ---------------------------------------------------------------------------
# Gate mutual exclusivity: wave 1 only ever checks _templates_ready, ignoring
# _rebuild_pending_gate entirely, even when the latter is (contrivedly) true.
# ---------------------------------------------------------------------------

func test_wave1_gate_ignores_rebuild_pending_gate_and_waits_only_on_templates_ready() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 1
	_wm._templates_ready = false
	_wm._rebuild_pending_gate = true  # contrived — should have zero effect on wave 1
	_wm._spawn_active = true
	_wm._wave_spawn_entries = [WaveSpawnEntry.new(&"goblin", 0.0)]

	_wm._run_spawn_sequence()  # suspends on `await GEventBus.templates_ready`
	assert_int(_spy.count("monster_spawn_requested")).is_equal(0)

	GEventBus.path_invalidated.emit([])  # must NOT resume wave 1's coroutine
	assert_int(_spy.count("monster_spawn_requested")).is_equal(0)

	GEventBus.templates_ready.emit(1, 5.0)  # this is what wave 1 actually waits on
	assert_int(_spy.count("monster_spawn_requested")).is_equal(1)


## Gate mutual exclusivity: waves 2+ never re-check _templates_ready — a
## (contrived) false _templates_ready has zero effect once _wave_index > 1.
func test_wave2_gate_ignores_templates_ready_and_spawns_immediately_when_rebuild_not_pending() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 2
	_wm._templates_ready = false  # contrived — should have zero effect on waves 2+
	_wm._rebuild_pending_gate = false
	_wm._spawn_active = true
	_wm._wave_spawn_entries = [WaveSpawnEntry.new(&"goblin", 0.0)]

	_wm._run_spawn_sequence()

	assert_int(_spy.count("monster_spawn_requested")).is_equal(1)

# ---------------------------------------------------------------------------
# path_invalidated early-fire guard: if path_invalidated fires during the
# PRE_WAVE countdown, before the spawn coroutine starts, _rebuild_pending_gate
# must already be false by the time the coroutine runs — it must not await a
# signal that has already fired.
# ---------------------------------------------------------------------------

func test_path_invalidated_early_fire_before_coroutine_starts_leaves_gate_already_released() -> void:
	GPathfindingSystem._rebuild_queued = true
	_wm._phase = WaveManager.Phase.INTERMISSION
	_wm._check_rebuild_gate()
	assert_bool(_wm._rebuild_pending_gate).is_true()

	# Simulate path_invalidated firing during the PRE_WAVE countdown, before
	# _run_spawn_sequence() (the spawn coroutine) has started.
	GEventBus.path_invalidated.emit([])
	assert_bool(_wm._rebuild_pending_gate).is_false()

	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 2
	_wm._spawn_active = true
	_wm._wave_spawn_entries = [WaveSpawnEntry.new(&"goblin", 0.0)]

	_wm._run_spawn_sequence()  # must NOT await — _rebuild_pending_gate is already false

	assert_int(_spy.count("monster_spawn_requested")).is_equal(1)

# ---------------------------------------------------------------------------
# Subscription lifecycle: path_invalidated disconnects after firing, no
# accumulation across 3 consecutive waves each triggering
# is_rebuild_pending() == true — the QA Test Case most likely to reveal a real
# disconnect-logic bug.
# ---------------------------------------------------------------------------

func test_subscription_lifecycle_across_three_consecutive_waves_no_accumulation() -> void:
	for wave: int in range(1, 4):
		GPathfindingSystem._rebuild_queued = true
		_wm._phase = WaveManager.Phase.INTERMISSION
		_wm._check_rebuild_gate()

		assert_bool(_wm._rebuild_pending_gate).is_true()
		assert_int(_count_connections(GEventBus.path_invalidated, _wm._on_path_invalidated)) \
			.override_failure_message("Wave %d: expected exactly 1 connection before release" % wave) \
			.is_equal(1)

		GEventBus.path_invalidated.emit([])

		assert_bool(_wm._rebuild_pending_gate).is_false()
		assert_int(_count_connections(GEventBus.path_invalidated, _wm._on_path_invalidated)) \
			.override_failure_message("Wave %d: expected 0 connections after release — accumulation detected" % wave) \
			.is_equal(0)

# ---------------------------------------------------------------------------
# Gap 1: _reset_all_state() resets _rebuild_pending_gate to false.
# ---------------------------------------------------------------------------

func test_reset_all_state_resets_rebuild_pending_gate() -> void:
	_wm._rebuild_pending_gate = true

	_wm._reset_all_state()

	assert_bool(_wm._rebuild_pending_gate).is_false()

# ---------------------------------------------------------------------------
# Rule 22 call sites: both INTERMISSION -> PRE_WAVE paths call
# _check_rebuild_gate() before transitioning.
# ---------------------------------------------------------------------------

func test_intermission_timer_timeout_calls_check_rebuild_gate_before_transition() -> void:
	GPathfindingSystem._rebuild_queued = true
	_wm._phase = WaveManager.Phase.INTERMISSION

	_wm._on_intermission_timer_timeout()

	assert_bool(_wm._rebuild_pending_gate).is_true()
	assert_int(_wm._phase).is_equal(WaveManager.Phase.PRE_WAVE)


func test_player_ready_from_intermission_calls_check_rebuild_gate_before_transition() -> void:
	GPathfindingSystem._rebuild_queued = true
	_wm._phase = WaveManager.Phase.INTERMISSION

	_wm._on_player_ready()

	assert_bool(_wm._rebuild_pending_gate).is_true()
	assert_int(_wm._phase).is_equal(WaveManager.Phase.PRE_WAVE)


## Negative companion: neither call site sets the gate when rebuild isn't
## pending — the FSM transition still happens exactly as it does today.
func test_intermission_timer_timeout_does_not_set_gate_when_rebuild_not_pending() -> void:
	GPathfindingSystem._rebuild_queued = false
	_wm._phase = WaveManager.Phase.INTERMISSION

	_wm._on_intermission_timer_timeout()

	assert_bool(_wm._rebuild_pending_gate).is_false()
	assert_int(_wm._phase).is_equal(WaveManager.Phase.PRE_WAVE)

# ---------------------------------------------------------------------------
# Performance / Control Manifest guardrail: one boolean check plus a single
# connect/disconnect pair per wave transition — no polling. Verified via
# call-counting: is_rebuild_pending() (indirectly, via _rebuild_queued reads)
# and the connect/disconnect pair each happen exactly once per
# _check_rebuild_gate() call, not per-frame.
# ---------------------------------------------------------------------------

func test_check_rebuild_gate_is_o1_no_polling_across_multiple_frames() -> void:
	GPathfindingSystem._rebuild_queued = true
	_wm._check_rebuild_gate()

	assert_int(_count_connections(GEventBus.path_invalidated, _wm._on_path_invalidated)).is_equal(1)

	# Simulate several frames passing with no further _check_rebuild_gate()
	# calls — the connection count must not change (no per-frame polling
	# re-subscribing or re-checking).
	await get_tree().process_frame
	await get_tree().process_frame

	assert_int(_count_connections(GEventBus.path_invalidated, _wm._on_path_invalidated)).is_equal(1)
