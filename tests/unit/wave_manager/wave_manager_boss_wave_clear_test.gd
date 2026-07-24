extends GdUnitTestSuite

## WaveManager BOSS death / BOSS breach fast-paths + wave-clear robustness tests.
## Covers: AC-15, AC-16, AC-24, AC-28, AC-29, AC-30, AC-32, AC-34, AC-37, plus
## the Performance / Control Manifest guardrail (O(1) guard checks).
## Design source: production/epics/epic-04-wave-manager/story-003-boss-fastpaths-wave-clear-robustness.md
## ADR-0012: Wave Manager FSM Architecture.
##
## Follows the EventBusSpy + direct-field-injection + direct-handler-invocation
## conventions established in wave_manager_defeat_victory_test.gd and
## wave_manager_spawn_cell_test.gd. Handlers are invoked directly on this
## test's own _wm instance (not via GEventBus.boss_died.emit(...) etc.)
## wherever the real ambient GWaveManager Autoload would otherwise also react
## and pollute the spy — see wave_manager_defeat_victory_test.gd's note on
## _on_hero_died() for the same rationale. Where a test needs multiple
## independent EventBus subscribers on the same signal (none do here — every
## assertion only needs this suite's own _wm instance's reaction), direct
## emission would be preferred instead; not needed in this file.

var _wm: WaveManager
var _spy: EventBusSpy


func before_test() -> void:
	_wm = WaveManager.new()
	add_child(_wm)  # triggers _ready() — creates timers, subscribes to EventBus

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.wave_completed)
	_spy.watch(GEventBus.mission_phase_changed)
	_spy.watch(GEventBus.wave_preview_available)
	_spy.watch(GEventBus.monster_spawn_requested)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	remove_child(_wm)
	_wm.free()

# ---------------------------------------------------------------------------
# AC-15: boss_died clears the wave immediately regardless of
# _enemies_alive/_all_spawns_fired, and discards remaining spawn entries
# (EC-3: _spawn_active set false, so the coroutine's own guard stops it).
# ---------------------------------------------------------------------------

func test_boss_died_clears_wave_immediately_and_discards_remaining_spawns() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 1
	_wm._wave_scripts_count = 2
	_wm._all_spawns_fired = false  # 3 unfired WaveScript entries, simulated by this flag alone
	_wm._enemies_alive = 2
	_wm._spawn_active = true

	_wm._on_boss_died(1, &"dragon", 1, "killed")

	assert_int(_spy.count("wave_completed")).is_equal(1)
	var args: Array = (_spy.emissions["wave_completed"] as Array)[0]
	assert_int(args[0]).is_equal(1)      # wave_number
	assert_int(args[1]).is_equal(0)      # enemies_remaining reported as 0
	assert_bool(args[2]).is_false()      # was_boss_breached
	assert_bool(_wm._spawn_active).is_false()  # EC-3: remaining spawns discarded
	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)

# ---------------------------------------------------------------------------
# AC-16 / AC-30: BOSS breach (tier 2) clears the wave with
# was_boss_breached: true — the one path where this flag is true.
# ---------------------------------------------------------------------------

func test_boss_breach_clears_wave_with_was_boss_breached_true() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 1
	_wm._wave_scripts_count = 2

	_wm._on_monster_breached(1, &"dragon", 2)

	assert_int(_spy.count("wave_completed")).is_equal(1)
	var args: Array = (_spy.emissions["wave_completed"] as Array)[0]
	assert_bool(args[2]).is_true()  # was_boss_breached: true
	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)

# ---------------------------------------------------------------------------
# AC-24: ELITE breach (tier 1) does NOT trigger the BOSS fast-path — treated
# as a standard -1 decrement, wave does not clear while enemies remain.
# ---------------------------------------------------------------------------

func test_elite_breach_is_standard_decrement_not_fast_path() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 3

	_wm._on_monster_breached(2, &"elite_orc", 1)

	assert_int(_wm._enemies_alive).is_equal(2)
	assert_int(_wm._phase).is_equal(WaveManager.Phase.WAVE_ACTIVE)  # wave does NOT clear
	assert_bool(_spy.was_emitted("wave_completed")).is_false()


## Regression: an unrecognized tier value (neither 2 nor 1) is also treated as
## a standard decrement, not the BOSS fast-path.
func test_unrecognized_tier_breach_is_also_standard_decrement() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 3

	_wm._on_monster_breached(3, &"mystery_monster", 0)

	assert_int(_wm._enemies_alive).is_equal(2)
	assert_bool(_spy.was_emitted("wave_completed")).is_false()

# ---------------------------------------------------------------------------
# AC-29: boss_died received before all spawns have fired still emits the full
# 3-event sequence (wave_completed -> mission_phase_changed ->
# wave_preview_available) via the same INTERMISSION entry path as a standard
# clear. 2-wave mission, wave 1 (non-final), so INTERMISSION — not
# MISSION_COMPLETE — is entered, which is what emits wave_preview_available.
# ---------------------------------------------------------------------------

## Code review fix (Story 003): the original version of this test only
## checked each signal's emission COUNT, not their relative order — its own
## comment claimed order was "proven by index position," which was not true
## (EventBusSpy records each signal in its own separate per-name list; nothing
## compared positions ACROSS lists). A shared ordered-log array (same pattern
## as wave_manager_lifecycle_events_test.gd's `_order` recorder) actually
## proves cross-signal order, so a future regression that reorders these
## emissions would be caught here instead of passing silently.
func test_boss_died_before_all_spawns_fired_emits_full_3_event_sequence_in_order() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 1
	_wm._wave_scripts_count = 2
	_wm._all_spawns_fired = false  # not all spawns have fired yet

	var order: Array = []
	var cb_wave_completed := func(_a: int, _b: int, _c: bool) -> void: order.append("wave_completed")
	var cb_phase_changed := func(_a: String, _b: String, _c: float) -> void: order.append("mission_phase_changed")
	var cb_preview := func(_a: int, _b: Array, _c: Vector2i) -> void: order.append("wave_preview_available")
	GEventBus.wave_completed.connect(cb_wave_completed)
	GEventBus.mission_phase_changed.connect(cb_phase_changed)
	GEventBus.wave_preview_available.connect(cb_preview)

	_wm._on_boss_died(1, &"dragon", 1, "killed")

	GEventBus.wave_completed.disconnect(cb_wave_completed)
	GEventBus.mission_phase_changed.disconnect(cb_phase_changed)
	GEventBus.wave_preview_available.disconnect(cb_preview)

	assert_array(order).is_equal(["wave_completed", "mission_phase_changed", "wave_preview_available"])

	var phase_changed_args: Array = (_spy.emissions["mission_phase_changed"] as Array)[0]
	assert_str(phase_changed_args[0]).is_equal("WAVE_ACTIVE")
	assert_str(phase_changed_args[1]).is_equal("INTERMISSION")

	var preview_args: Array = (_spy.emissions["wave_preview_available"] as Array)[0]
	assert_int(preview_args[0]).is_equal(2)  # upcoming wave number

# ---------------------------------------------------------------------------
# AC-30: was_boss_breached correct across all 3 clear paths (standard,
# boss_died fast-path, BOSS breach).
# ---------------------------------------------------------------------------

func test_ac30_standard_clear_reports_was_boss_breached_false() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 1

	GEventBus.monster_died.emit(MonsterDiedEvent.new())

	assert_int(_spy.count("wave_completed")).is_equal(1)
	var args: Array = (_spy.emissions["wave_completed"] as Array)[0]
	assert_bool(args[2]).is_false()


func test_ac30_boss_died_fast_path_reports_was_boss_breached_false() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE

	_wm._on_boss_died(1, &"dragon", 1, "killed")

	var args: Array = (_spy.emissions["wave_completed"] as Array)[0]
	assert_bool(args[2]).is_false()


func test_ac30_boss_breach_reports_was_boss_breached_true() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE

	_wm._on_monster_breached(1, &"dragon", 2)

	var args: Array = (_spy.emissions["wave_completed"] as Array)[0]
	assert_bool(args[2]).is_true()

# ---------------------------------------------------------------------------
# AC-32: a stray boss_died received after the phase has already advanced to
# INTERMISSION (from a prior standard clear) is a no-op.
# ---------------------------------------------------------------------------

func test_stray_boss_died_after_phase_already_advanced_is_a_noop() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 1
	GEventBus.monster_died.emit(MonsterDiedEvent.new())  # standard clear -> INTERMISSION

	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)
	assert_int(_spy.count("wave_completed")).is_equal(1)

	_wm._on_boss_died(1, &"dragon", 1, "force_removed")  # stray, phase no longer WAVE_ACTIVE

	assert_int(_spy.count("wave_completed")).is_equal(1)  # no second wave_completed
	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)

# ---------------------------------------------------------------------------
# AC-34: a same-frame stray boss_died immediately following a BOSS breach
# (before phase state updates, i.e. still within the same synchronous
# handling) is also a no-op — the _wave_clear_fired latch (not the phase
# check, which would also still read WAVE_ACTIVE at the instant of the
# in-flight _transition_to()) catches this within-WAVE_ACTIVE race.
# ---------------------------------------------------------------------------

func test_same_frame_stray_boss_died_after_breach_is_a_noop_via_latch() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE

	_wm._on_monster_breached(1, &"dragon", 2)  # breach fires first, sets the latch
	assert_int(_spy.count("wave_completed")).is_equal(1)
	assert_bool(_wm._wave_clear_fired).is_true()  # proves the latch itself is what will catch the race

	_wm._on_boss_died(1, &"dragon", 1, "force_removed")  # same-frame stray immediately after

	# Exactly one wave_completed (was_boss_breached: true) — not two.
	assert_int(_spy.count("wave_completed")).is_equal(1)
	var args: Array = (_spy.emissions["wave_completed"] as Array)[0]
	assert_bool(args[2]).is_true()

# ---------------------------------------------------------------------------
# AC-28: monsters_died_batch(payloads) with payloads.size() == N decrements
# _enemies_alive by N and triggers wave-clear identically to N sequential
# monster_died events.
# ---------------------------------------------------------------------------

func test_monsters_died_batch_decrements_by_payload_count_and_clears_wave() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 5

	var payloads: Array[MonsterDiedEvent] = [
		MonsterDiedEvent.new(), MonsterDiedEvent.new(), MonsterDiedEvent.new(),
		MonsterDiedEvent.new(), MonsterDiedEvent.new(),
	]
	_wm._on_monsters_died_batch(payloads)

	assert_int(_wm._enemies_alive).is_equal(0)
	assert_int(_spy.count("wave_completed")).is_equal(1)
	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)


## Regression: a partial batch (some enemies remain) does not clear the wave,
## matching N sequential monster_died events leaving _enemies_alive > 0.
func test_monsters_died_batch_partial_decrement_does_not_clear_wave() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 5

	var payloads: Array[MonsterDiedEvent] = [
		MonsterDiedEvent.new(), MonsterDiedEvent.new(),
	]
	_wm._on_monsters_died_batch(payloads)

	assert_int(_wm._enemies_alive).is_equal(3)
	assert_bool(_spy.was_emitted("wave_completed")).is_false()
	assert_int(_wm._phase).is_equal(WaveManager.Phase.WAVE_ACTIVE)

# ---------------------------------------------------------------------------
# AC-37: monsters_died_batch with an empty (invalid) payload array is
# discarded — _enemies_alive unchanged, a warning logged, no wave_completed.
# ---------------------------------------------------------------------------

func test_monsters_died_batch_empty_payload_is_discarded_with_warning() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 3
	var empty_payloads: Array[MonsterDiedEvent] = []

	await assert_error(func() -> void: _wm._on_monsters_died_batch(empty_payloads)) \
		.is_push_warning("WaveManager: monsters_died_batch received with invalid count 0 — discarded.")

	assert_int(_wm._enemies_alive).is_equal(3)
	assert_bool(_spy.was_emitted("wave_completed")).is_false()

# ---------------------------------------------------------------------------
# Performance / Control Manifest guardrail: O(1) guard checks per event;
# monsters_died_batch reads payloads.size() once, no iteration added by this
# story. Verified by source inspection, mirroring this suite family's
# existing structural tests (e.g. wave_manager_spawn_cell_test.gd's O(1)
# check for _resolve_spawn_cell()).
# ---------------------------------------------------------------------------

func test_on_monsters_died_batch_is_o1_no_iteration_over_payloads() -> void:
	var source: String = FileAccess.get_file_as_string("res://src/gameplay/wave_manager.gd")

	var start_idx: int = source.find("func _on_monsters_died_batch")
	assert_int(start_idx).is_greater(-1)
	var end_idx: int = source.find("\nfunc ", start_idx + 1)
	var body: String = source.substr(start_idx, end_idx - start_idx if end_idx != -1 else -1)

	assert_bool(body.contains("for ")).is_false()
	assert_bool(body.contains("while ")).is_false()
	assert_bool(body.contains("payloads.size()")).is_true()

# ---------------------------------------------------------------------------
# Guardrail regression: none of the three new handlers act while
# _phase != Phase.WAVE_ACTIVE, independent of the _wave_clear_fired latch —
# confirms the phase-equality guard is genuinely the first operation, not
# accidentally bypassed for any of the three handlers.
# ---------------------------------------------------------------------------

func test_all_three_handlers_are_noop_outside_wave_active() -> void:
	_wm._phase = WaveManager.Phase.INTERMISSION

	_wm._on_boss_died(1, &"dragon", 1, "killed")
	_wm._on_monster_breached(1, &"dragon", 2)
	var payloads: Array[MonsterDiedEvent] = [MonsterDiedEvent.new()]
	_wm._on_monsters_died_batch(payloads)

	assert_bool(_spy.was_emitted("wave_completed")).is_false()
	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)

# ---------------------------------------------------------------------------
# Code review fix (Story 003): real bug found while implementing the
# reentrancy-guard suggestion. _wave_clear_fired was previously reset ONLY
# per-mission (_reset_all_state(), Story 006) — never per-wave. Since this
# story's _on_boss_died()/_on_monster_breached() gate on
# `if _wave_clear_fired: return`, leaving the flag latched true from wave 1's
# clear would permanently dead-end BOSS fast-paths for every subsequent wave
# in the mission (most real missions put the BOSS on the FINAL wave, not
# wave 1 — this would have made BOSS handling non-functional in practice).
# Fixed by resetting _wave_clear_fired in _enter_wave_active() (wave-scoped),
# mirroring _round_robin_counter's identical reset. This test proves a
# SECOND wave's boss_died fast-path still fires after the FIRST wave cleared
# via the standard path (not a BOSS fast-path) and set the latch.
# ---------------------------------------------------------------------------

func test_boss_died_fast_path_still_works_on_wave_2_after_wave_1_standard_clear() -> void:
	_wm._wave_scripts_count = 2

	# Wave 1: standard clear (not a BOSS fast-path) sets _wave_clear_fired.
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 1
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 1
	GEventBus.monster_died.emit(MonsterDiedEvent.new())

	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)
	assert_bool(_wm._wave_clear_fired).is_true()

	# Wave 2 begins — _enter_wave_active() must reset the latch wave-scoped,
	# not leave it latched from wave 1's clear.
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)
	assert_bool(_wm._wave_clear_fired).is_false()

	_spy.clear()

	# Wave 2's BOSS fast-path must actually fire — this would silently no-op
	# (via the `if _wave_clear_fired: return` guard) without the fix above.
	_wm._on_boss_died(2, &"dragon", 2, "killed")

	assert_int(_spy.count("wave_completed")).is_equal(1)
	var args: Array = (_spy.emissions["wave_completed"] as Array)[0]
	assert_int(args[0]).is_equal(2)  # wave_number
	assert_int(_wm._phase).is_equal(WaveManager.Phase.MISSION_COMPLETE)  # wave 2 is final
