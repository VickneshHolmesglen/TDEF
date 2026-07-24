extends GdUnitTestSuite

## WaveManager DEFEAT / MISSION_COMPLETE win-loss condition tests.
## Covers: AC-7, AC-8, AC-21, Rule 13 / AC-6 (final wave clear), plus a
## non-final-wave regression check.
## Design source: production/epics/epic-04-wave-manager/story-001-defeat-mission-complete.md
## ADR-0012: Wave Manager FSM Architecture.

var _wm: WaveManager
var _spy: EventBusSpy


func before_test() -> void:
	_wm = WaveManager.new()
	add_child(_wm)  # triggers _ready() — creates timers, subscribes to EventBus

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.mission_phase_changed)
	_spy.watch(GEventBus.wave_completed)
	_spy.watch(GEventBus.wave_started)
	_spy.watch(GEventBus.phase_timer_tick)
	_spy.watch(GEventBus.wave_countdown_warning)
	_spy.watch(GEventBus.monster_spawn_requested)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	remove_child(_wm)
	_wm.free()

# ---------------------------------------------------------------------------
# AC-7: hero_died -> DEFEAT from any of SCOUT / PRE_WAVE / INTERMISSION /
# WAVE_ACTIVE, with the correct `from` phase name, and no further
# wave-lifecycle events fire afterward (mocked timers — direct callback
# invocation is used elsewhere in this suite to prove timers are inert once
# _phase_locked no longer matches SCOUT/PRE_WAVE/INTERMISSION/WAVE_ACTIVE).
# ---------------------------------------------------------------------------

func test_hero_died_from_scout_transitions_to_defeat() -> void:
	_wm._phase = WaveManager.Phase.SCOUT

	# NOTE: calls _wm._on_hero_died() directly rather than emitting the real
	# GEventBus.hero_died signal. GWaveManager is a real registered Autoload
	# (project.godot) and stays alive during headless test runs; emitting the
	# actual bus signal also fires that ambient singleton's own (deliberately
	# unconditional) _on_hero_died() handler — and SceneManager's — polluting
	# this spy with an unrelated mission_phase_changed("IDLE","DEFEAT",...)
	# emission and scene-load error noise. Direct invocation on this test's
	# own _wm instance avoids touching shared ambient Autoload state.
	_wm._on_hero_died()

	assert_int(_wm._phase).is_equal(WaveManager.Phase.DEFEAT)
	assert_bool(_spy.was_emitted("mission_phase_changed")).is_true()
	var args: Array = (_spy.emissions["mission_phase_changed"] as Array)[0]
	assert_str(args[0]).is_equal("SCOUT")
	assert_str(args[1]).is_equal("DEFEAT")

	# No further wave-lifecycle events fire even if a stale timer callback
	# is invoked directly afterward (60s watchdog / scout timer surrogate).
	# NOTE: wave_completed/wave_started are not yet emitted anywhere in this
	# file (real emission is Story 002's job) — these two assertions are
	# forward-looking placeholders proving absence, not evidence that this
	# story wired up real emission. Do not mistake them for coverage of
	# Story 002's signals.
	_wm._scout_timer.emit_signal("timeout")
	assert_int(_wm._phase).is_equal(WaveManager.Phase.DEFEAT)
	assert_bool(_spy.was_emitted("wave_completed")).is_false()
	assert_bool(_spy.was_emitted("wave_started")).is_false()


func test_hero_died_from_pre_wave_transitions_to_defeat() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE

	_wm._on_hero_died()  # see note in test_hero_died_from_scout_transitions_to_defeat

	assert_int(_wm._phase).is_equal(WaveManager.Phase.DEFEAT)
	var args: Array = (_spy.emissions["mission_phase_changed"] as Array)[0]
	assert_str(args[0]).is_equal("PRE_WAVE")
	assert_str(args[1]).is_equal("DEFEAT")

	_wm._pre_wave_timer.emit_signal("timeout")
	assert_int(_wm._phase).is_equal(WaveManager.Phase.DEFEAT)


func test_hero_died_from_wave_active_transitions_to_defeat() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE

	_wm._on_hero_died()  # see note in test_hero_died_from_scout_transitions_to_defeat

	assert_int(_wm._phase).is_equal(WaveManager.Phase.DEFEAT)
	var args: Array = (_spy.emissions["mission_phase_changed"] as Array)[0]
	assert_str(args[0]).is_equal("WAVE_ACTIVE")
	assert_str(args[1]).is_equal("DEFEAT")

	# A stray monster_died arriving after DEFEAT must not resurrect wave logic.
	GEventBus.monster_died.emit(MonsterDiedEvent.new())
	assert_int(_wm._phase).is_equal(WaveManager.Phase.DEFEAT)
	assert_bool(_spy.was_emitted("wave_completed")).is_false()

# ---------------------------------------------------------------------------
# AC-21: hero_died during INTERMISSION stops the 30s intermission timer;
# the partial intermission is discarded and no PRE_WAVE follows.
# ---------------------------------------------------------------------------

func test_hero_died_from_intermission_transitions_to_defeat_and_stops_timer() -> void:
	_wm._phase = WaveManager.Phase.INTERMISSION
	_wm._intermission_timer.start()

	_wm._on_hero_died()  # see note in test_hero_died_from_scout_transitions_to_defeat

	assert_int(_wm._phase).is_equal(WaveManager.Phase.DEFEAT)
	var args: Array = (_spy.emissions["mission_phase_changed"] as Array)[0]
	assert_str(args[0]).is_equal("INTERMISSION")
	assert_str(args[1]).is_equal("DEFEAT")
	assert_bool(_wm._intermission_timer.is_stopped()).is_true()

	# The partial intermission is discarded — a stale timeout must not fire PRE_WAVE.
	_wm._intermission_timer.emit_signal("timeout")
	assert_int(_wm._phase).is_equal(WaveManager.Phase.DEFEAT)

# ---------------------------------------------------------------------------
# AC-8: DEFEAT wins a same-frame race against a competing wave-clear check.
# _on_monster_died / _on_boss_died / the monster_breached(tier:2) handler do
# not exist yet in this file (Stories 002/003 territory) — per this story's
# Implementation Notes, the race is simulated by calling _on_hero_died()
# immediately followed by a direct call to _check_wave_clear_or_start_watchdog()
# in the same test function. Only the DEFEAT transition's signal must fire.
# ---------------------------------------------------------------------------

func test_hero_died_wins_race_against_wave_clear_check() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 0  # post-decrement state a competing monster_died would leave behind

	_wm._on_hero_died()
	_wm._check_wave_clear_or_start_watchdog()

	assert_int(_wm._phase).is_equal(WaveManager.Phase.DEFEAT)
	assert_int(_spy.count("mission_phase_changed")).is_equal(1)
	var args: Array = (_spy.emissions["mission_phase_changed"] as Array)[0]
	assert_str(args[1]).is_equal("DEFEAT")
	assert_bool(_spy.was_emitted("wave_completed")).is_false()

# ---------------------------------------------------------------------------
# Rule 13 / AC-6: final wave clearing transitions to MISSION_COMPLETE instead
# of INTERMISSION. 2-wave mission, WAVE_ACTIVE on wave 2 (the final wave).
# ---------------------------------------------------------------------------

func test_final_wave_clear_transitions_to_mission_complete() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_scripts_count = 2
	_wm._wave_index = 2
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 1

	GEventBus.monster_died.emit(MonsterDiedEvent.new())

	assert_int(_wm._enemies_alive).is_equal(0)
	assert_int(_wm._phase).is_equal(WaveManager.Phase.MISSION_COMPLETE)
	var args: Array = (_spy.emissions["mission_phase_changed"] as Array)[0]
	assert_str(args[0]).is_equal("WAVE_ACTIVE")
	assert_str(args[1]).is_equal("MISSION_COMPLETE")

	# No further wave-lifecycle events fire — stale watchdog timeouts are inert.
	_wm._watchdog_force_timer.emit_signal("timeout")
	assert_int(_wm._phase).is_equal(WaveManager.Phase.MISSION_COMPLETE)


## Regression: a non-final wave (wave 1 of 2) must still transition to
## INTERMISSION — _is_final_wave() must not break the existing clear path.
func test_non_final_wave_clear_still_transitions_to_intermission() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_scripts_count = 2
	_wm._wave_index = 1
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 1

	GEventBus.monster_died.emit(MonsterDiedEvent.new())

	assert_int(_wm._enemies_alive).is_equal(0)
	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)

# ---------------------------------------------------------------------------
# Implementation Notes item 5: the 60s watchdog force-clear path applies the
# same _is_final_wave() check for consistency.
# ---------------------------------------------------------------------------

func test_watchdog_force_timeout_on_final_wave_transitions_to_mission_complete() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_scripts_count = 2
	_wm._wave_index = 2
	_wm._enemies_alive = 10

	_wm._watchdog_force_timer.emit_signal("timeout")

	assert_int(_wm._phase).is_equal(WaveManager.Phase.MISSION_COMPLETE)


## Regression (symmetry with the existing _on_monster_died non-final-wave
## regression test above): the 60s watchdog force-clear path must also still
## route to INTERMISSION, not MISSION_COMPLETE, on a non-final wave.
func test_watchdog_force_timeout_on_non_final_wave_still_transitions_to_intermission() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_scripts_count = 2
	_wm._wave_index = 1
	_wm._enemies_alive = 10

	_wm._watchdog_force_timer.emit_signal("timeout")

	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)

# ---------------------------------------------------------------------------
# Code review fix (Story 001): _on_hero_died() must defer to
# _transition_to(Phase.DEFEAT) rather than dropping it, if hero_died fires
# while _phase_locked is already true from an outer in-flight _transition_to()
# call. Simulated here by setting _phase_locked = true directly (standing in
# for an outer transition in progress), calling _on_hero_died(), confirming
# nothing happens synchronously, then releasing the lock (simulating the
# outer transition completing) and awaiting a frame for the deferred call to
# actually run — mirrors this suite's existing call_deferred test pattern
# (see wave_manager_spawn_test.gd's empty-wave-spawn-entries regression test).
# ---------------------------------------------------------------------------

func test_hero_died_while_phase_locked_defers_and_still_reaches_defeat() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._phase_locked = true  # simulate an outer in-flight _transition_to() call

	_wm._on_hero_died()

	# Not dropped, but not applied yet either — deferred, not synchronous.
	assert_int(_wm._phase).is_equal(WaveManager.Phase.WAVE_ACTIVE)
	assert_bool(_spy.was_emitted("mission_phase_changed")).is_false()

	_wm._phase_locked = false  # the outer transition releases the lock

	await get_tree().process_frame

	assert_int(_wm._phase).is_equal(WaveManager.Phase.DEFEAT)
	assert_bool(_spy.was_emitted("mission_phase_changed")).is_true()
	var args: Array = (_spy.emissions["mission_phase_changed"] as Array)[0]
	assert_str(args[0]).is_equal("WAVE_ACTIVE")
	assert_str(args[1]).is_equal("DEFEAT")

# ---------------------------------------------------------------------------
# Spawn-coroutine interrupt: hero_died arriving while _run_spawn_sequence()
# is suspended mid-await (a nonzero pre_delay entry) must stop the coroutine
# from resuming with further spawns. Exercises the existing 3-guard pattern
# (ADR-0012) — DEFEAT sets _spawn_active = false as a side effect of leaving
# WAVE_ACTIVE inside _transition_to(), which the coroutine's `if not
# _spawn_active: return` guard picks up on resume.
# ---------------------------------------------------------------------------

func test_hero_died_mid_spawn_coroutine_await_stops_further_spawns() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._templates_ready = true
	_wm._wave_spawn_entries = [
		WaveSpawnEntry.new(&"goblin", 0.05),
	]

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)  # suspends on the entry's pre_delay await
	assert_int(_spy.count("monster_spawn_requested")).is_equal(0)
	assert_int(_wm._phase).is_equal(WaveManager.Phase.WAVE_ACTIVE)

	_wm._on_hero_died()
	assert_int(_wm._phase).is_equal(WaveManager.Phase.DEFEAT)
	assert_bool(_wm._spawn_active).is_false()

	await get_tree().create_timer(0.08).timeout  # let the pending pre_delay timer fire and the coroutine try to resume

	assert_int(_spy.count("monster_spawn_requested")).is_equal(0)
	assert_int(_wm._phase).is_equal(WaveManager.Phase.DEFEAT)
