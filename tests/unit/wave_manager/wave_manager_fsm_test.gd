extends GdUnitTestSuite

## WaveManager Phase FSM, Timer node, Watchdog, and EventBus wiring tests.
## Covers: AC-1 through AC-7, AC-13 through AC-20.
## Design source: production/stories/core/s3-06-wave-manager-phase1.md
## ADR-0012: Wave Manager FSM Architecture.

var _wm: WaveManager
var _spy: EventBusSpy


func before_test() -> void:
	_wm = WaveManager.new()
	add_child(_wm)  # triggers _ready() — creates timers, subscribes to EventBus

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.mission_phase_changed)
	_spy.watch(GEventBus.wave_stalled)
	_spy.watch(GEventBus.monster_spawn_requested)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	remove_child(_wm)
	_wm.free()

# ---------------------------------------------------------------------------
# AC-1: SCOUT → WAVE_ACTIVE transition emits mission_phase_changed
# ---------------------------------------------------------------------------

func test_transition_scout_to_wave_active_emits_mission_phase_changed() -> void:
	_wm._phase = WaveManager.Phase.SCOUT

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_bool(_spy.was_emitted("mission_phase_changed")).is_true()
	var args: Array = (_spy.emissions["mission_phase_changed"] as Array)[0]
	assert_str(args[0]).is_equal("SCOUT")
	assert_str(args[1]).is_equal("WAVE_ACTIVE")
	assert_int(_wm._phase).is_equal(WaveManager.Phase.WAVE_ACTIVE)

# ---------------------------------------------------------------------------
# AC-2: WAVE_ACTIVE → INTERMISSION cancels _scout_timer and spawn coroutine
# ---------------------------------------------------------------------------

func test_transition_wave_active_to_intermission_cancels_scout_timer_and_spawn() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._spawn_active = true
	_wm._scout_timer.start()

	_wm._transition_to(WaveManager.Phase.INTERMISSION)

	assert_bool(_wm._spawn_active).is_false()
	assert_bool(_wm._scout_timer.is_stopped()).is_true()
	assert_bool(_spy.was_emitted("mission_phase_changed")).is_true()
	var args: Array = (_spy.emissions["mission_phase_changed"] as Array)[0]
	assert_str(args[0]).is_equal("WAVE_ACTIVE")
	assert_str(args[1]).is_equal("INTERMISSION")

# ---------------------------------------------------------------------------
# AC-3: Direct assignment to _phase is only permitted inside _transition_to
# (Verified by code inspection — GDScript has no access modifiers, so this
# is enforced by convention and checked here via source-text inspection.)
# ---------------------------------------------------------------------------

func test_phase_assignment_only_occurs_inside_transition_to() -> void:
	var source: String = FileAccess.get_file_as_string("res://src/gameplay/wave_manager.gd")
	var lines: PackedStringArray = source.split("\n")
	var assignment_lines: Array = []
	for line: String in lines:
		var stripped: String = line.strip_edges()
		if stripped.begins_with("_phase = "):
			assignment_lines.append(stripped)

	assert_int(assignment_lines.size()).is_equal(1)
	assert_str(assignment_lines[0]).is_equal("_phase = new_phase")

# ---------------------------------------------------------------------------
# AC-4: _phase_locked = true → second _transition_to() call is silently ignored
# ---------------------------------------------------------------------------

func test_transition_to_ignored_when_phase_locked() -> void:
	_wm._phase = WaveManager.Phase.SCOUT
	_wm._phase_locked = true

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_int(_wm._phase).is_equal(WaveManager.Phase.SCOUT)
	assert_bool(_spy.was_emitted("mission_phase_changed")).is_false()

# ---------------------------------------------------------------------------
# AC-5: 5 Timer child nodes created in _ready() with the documented names.
# A 6th, _phase_tick_timer (repeating, phase_timer_tick's own driver — see
# below), was added 2026-08-13; this test's count was updated alongside it.
# ---------------------------------------------------------------------------

func test_ready_creates_five_named_timer_nodes() -> void:
	assert_int(_wm.get_child_count()).is_equal(6)
	assert_str(_wm._scout_timer.name).is_equal("_scout_timer")
	assert_str(_wm._pre_wave_timer.name).is_equal("_pre_wave_timer")
	assert_str(_wm._intermission_timer.name).is_equal("_intermission_timer")
	assert_str(_wm._watchdog_stall_timer.name).is_equal("_watchdog_stall_timer")
	assert_str(_wm._watchdog_force_timer.name).is_equal("_watchdog_force_timer")
	assert_str(_wm._phase_tick_timer.name).is_equal("_phase_tick_timer")

# ---------------------------------------------------------------------------
# AC-6: Each Timer is one_shot and has its timeout signal connected
# ---------------------------------------------------------------------------

func test_all_timers_are_one_shot_and_have_timeout_connected() -> void:
	var timers: Array[Timer] = [
		_wm._scout_timer, _wm._pre_wave_timer, _wm._intermission_timer,
		_wm._watchdog_stall_timer, _wm._watchdog_force_timer,
	]
	for t: Timer in timers:
		assert_bool(t.one_shot).is_true()
		assert_int(t.timeout.get_connections().size()).is_greater(0)

# ---------------------------------------------------------------------------
# AC-7: Timer callbacks are directly invokable via emit_signal("timeout")
# (no Engine.time_scale manipulation needed)
# ---------------------------------------------------------------------------

func test_scout_timer_timeout_can_be_triggered_directly() -> void:
	_wm._phase = WaveManager.Phase.SCOUT

	_wm._scout_timer.emit_signal("timeout")

	assert_int(_wm._phase).is_equal(WaveManager.Phase.PRE_WAVE)

# ---------------------------------------------------------------------------
# AC-13: _all_spawns_fired && _enemies_alive > 0 → both watchdog timers start
# ---------------------------------------------------------------------------

func test_check_wave_clear_starts_watchdog_timers_when_enemies_remain() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 3

	_wm._check_wave_clear_or_start_watchdog()

	assert_bool(_wm._watchdog_stall_timer.is_stopped()).is_false()
	assert_bool(_wm._watchdog_force_timer.is_stopped()).is_false()
	assert_float(_wm._watchdog_stall_timer.wait_time).is_equal(30.0)
	assert_float(_wm._watchdog_force_timer.wait_time).is_equal(60.0)

# ---------------------------------------------------------------------------
# AC-14: _watchdog_stall_timer fires → wave_stalled emitted
# ---------------------------------------------------------------------------

func test_watchdog_stall_timeout_emits_wave_stalled() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 2
	_wm._enemies_alive = 4

	_wm._watchdog_stall_timer.emit_signal("timeout")

	assert_bool(_spy.was_emitted("wave_stalled")).is_true()
	var args: Array = (_spy.emissions["wave_stalled"] as Array)[0]
	assert_int(args[0]).is_equal(2)
	assert_int(args[1]).is_equal(4)

# ---------------------------------------------------------------------------
# AC-15: _watchdog_force_timer fires → force transition to INTERMISSION
# regardless of _enemies_alive count
# ---------------------------------------------------------------------------

func test_watchdog_force_timeout_forces_intermission_regardless_of_enemies_alive() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._enemies_alive = 10

	_wm._watchdog_force_timer.emit_signal("timeout")

	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)

# ---------------------------------------------------------------------------
# AC-16: EventBus.player_ready is subscribed in _ready()
# (Reuses the existing player_ready signal — see s3-06 collaboration notes;
# no new player_ready_pressed signal was added.)
# ---------------------------------------------------------------------------

func test_player_ready_subscribed_in_ready() -> void:
	assert_bool(GEventBus.player_ready.is_connected(_wm._on_player_ready)).is_true()

# ---------------------------------------------------------------------------
# AC-17: player_ready during SCOUT → begins transition to PRE_WAVE
# ---------------------------------------------------------------------------

func test_player_ready_during_scout_transitions_to_pre_wave() -> void:
	_wm._phase = WaveManager.Phase.SCOUT

	GEventBus.player_ready.emit()

	assert_int(_wm._phase).is_equal(WaveManager.Phase.PRE_WAVE)

# ---------------------------------------------------------------------------
# AC-18: player_ready during WAVE_ACTIVE → silently ignored, no crash
# ---------------------------------------------------------------------------

func test_player_ready_during_wave_active_is_silently_ignored() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE

	GEventBus.player_ready.emit()

	assert_int(_wm._phase).is_equal(WaveManager.Phase.WAVE_ACTIVE)

# ---------------------------------------------------------------------------
# EC-8 (wave-manager.md): player_ready during PRE_WAVE ("Skip Countdown")
# cancels the remaining countdown and immediately transitions to WAVE_ACTIVE.
# Real bug found live 2026-08-12: _on_player_ready()'s match statement had no
# Phase.PRE_WAVE case at all, silently falling into the ignored-phases branch
# — the Skip Countdown button did nothing.
# ---------------------------------------------------------------------------

func test_player_ready_during_pre_wave_skips_countdown_to_wave_active() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._pre_wave_timer.start()

	GEventBus.player_ready.emit()

	assert_int(_wm._phase).is_equal(WaveManager.Phase.WAVE_ACTIVE)
	assert_bool(_wm._pre_wave_timer.is_stopped()).is_true()
	assert_bool(_spy.was_emitted("mission_phase_changed")).is_true()
	var args: Array = (_spy.emissions["mission_phase_changed"] as Array)[0]
	assert_str(args[0]).is_equal("PRE_WAVE")
	assert_str(args[1]).is_equal("WAVE_ACTIVE")

# ---------------------------------------------------------------------------
# AC-19: mission_phase_changed payload — previous phase name, new phase name,
# timestamp. NOTE: the real EventBus signature is
# mission_phase_changed(previous_phase: String, new_phase: String, timestamp: float)
# — it does not carry wave_index (verified against event_bus.gd); this test
# matches the actual signal shape rather than the story text's looser wording.
# ---------------------------------------------------------------------------

func test_mission_phase_changed_payload_has_previous_new_and_timestamp() -> void:
	_wm._phase = WaveManager.Phase.SCOUT

	_wm._transition_to(WaveManager.Phase.PRE_WAVE)

	assert_bool(_spy.was_emitted("mission_phase_changed")).is_true()
	var args: Array = (_spy.emissions["mission_phase_changed"] as Array)[0]
	assert_str(args[0]).is_equal("SCOUT")
	assert_str(args[1]).is_equal("PRE_WAVE")
	assert_float(args[2] as float).is_greater(0.0)

# ---------------------------------------------------------------------------
# AC-20: monster_died decrements _enemies_alive; reaching 0 (with all spawns
# fired) transitions to INTERMISSION.
# ---------------------------------------------------------------------------

func test_monster_died_decrements_enemies_alive_and_transitions_at_zero() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 1

	GEventBus.monster_died.emit(MonsterDiedEvent.new())

	assert_int(_wm._enemies_alive).is_equal(0)
	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)


func test_monster_died_does_not_transition_before_all_spawns_fired() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._all_spawns_fired = false
	_wm._enemies_alive = 1

	GEventBus.monster_died.emit(MonsterDiedEvent.new())

	assert_int(_wm._enemies_alive).is_equal(0)
	assert_int(_wm._phase).is_equal(WaveManager.Phase.WAVE_ACTIVE)


func test_monster_died_ignored_outside_wave_active() -> void:
	_wm._phase = WaveManager.Phase.INTERMISSION
	_wm._enemies_alive = 1

	GEventBus.monster_died.emit(MonsterDiedEvent.new())

	# Guard pattern: handler discards events received outside WAVE_ACTIVE.
	assert_int(_wm._enemies_alive).is_equal(1)

# ---------------------------------------------------------------------------
# phase_timer_tick (Formula F2, 2026-08-13): real bug found live — the signal
# was declared on EventBus but never emitted by any production code, so the
# Mission HUD's phase timer stayed frozen on "Timer: --" the whole session.
# _phase_tick_timer is repeating (one_shot=false) and separate from the 5
# one-shot phase-duration timers above.
# ---------------------------------------------------------------------------

func test_phase_tick_timer_is_repeating_with_one_second_interval() -> void:
	assert_bool(_wm._phase_tick_timer.one_shot).is_false()
	assert_float(_wm._phase_tick_timer.wait_time).is_equal(1.0)
	assert_int(_wm._phase_tick_timer.timeout.get_connections().size()).is_greater(0)


func test_phase_tick_timer_starts_on_scout_entry_and_emits_phase_timer_tick() -> void:
	_spy.watch(GEventBus.phase_timer_tick)
	_wm._phase = WaveManager.Phase.SCOUT
	_wm._scout_timer.start()

	_wm._phase_tick_timer.emit_signal("timeout")

	assert_bool(_spy.was_emitted("phase_timer_tick")).is_true()
	var args: Array = (_spy.emissions["phase_timer_tick"] as Array)[0]
	assert_str(args[0]).is_equal("SCOUT")
	assert_float(args[1] as float).is_greater(0.0)


## The PRE_WAVE extension this story adds — see wave-manager.md Formula F2's
## Type note. wave_countdown_warning alone (fired once at PRE_WAVE entry)
## left the HUD frozen for the full 10s; phase_timer_tick now also ticks here.
func test_phase_tick_timer_emits_during_pre_wave() -> void:
	_spy.watch(GEventBus.phase_timer_tick)
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._pre_wave_timer.start()

	_wm._phase_tick_timer.emit_signal("timeout")

	assert_bool(_spy.was_emitted("phase_timer_tick")).is_true()
	var args: Array = (_spy.emissions["phase_timer_tick"] as Array)[0]
	assert_str(args[0]).is_equal("PRE_WAVE")


func test_phase_tick_timer_emits_during_intermission() -> void:
	_spy.watch(GEventBus.phase_timer_tick)
	_wm._phase = WaveManager.Phase.INTERMISSION
	_wm._intermission_timer.start()

	_wm._phase_tick_timer.emit_signal("timeout")

	assert_bool(_spy.was_emitted("phase_timer_tick")).is_true()
	var args: Array = (_spy.emissions["phase_timer_tick"] as Array)[0]
	assert_str(args[0]).is_equal("INTERMISSION")


func test_phase_tick_timer_does_not_emit_during_wave_active() -> void:
	_spy.watch(GEventBus.phase_timer_tick)
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE

	_wm._phase_tick_timer.emit_signal("timeout")

	assert_bool(_spy.was_emitted("phase_timer_tick")).is_false()


func test_transition_to_wave_active_stops_phase_tick_timer() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._phase_tick_timer.start()

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_bool(_wm._phase_tick_timer.is_stopped()).is_true()
