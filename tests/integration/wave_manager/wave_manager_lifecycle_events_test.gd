extends GdUnitTestSuite

## WaveManager lifecycle-event tests: wave_started / wave_completed /
## wave_preview_available.
## Design source: production/epics/epic-04-wave-manager/story-002-wave-lifecycle-events.md
## ADR-0012: Wave Manager FSM Architecture.
##
## Deviations from the story's Implementation Notes (see final report — both
## flagged upfront by the requesting agent, not discovered independently):
##   1. The story's pseudocode calls a nonexistent `_total_wave_count()`.
##      Story 001's actual field is `_wave_scripts_count: int` — used directly
##      here and in the implementation.
##   2. The story's Step 3 pseudocode for _check_wave_clear_or_start_watchdog()
##      / _on_watchdog_force_timeout() shows an older, pre-code-review version
##      of those functions. This story's new lines (the _wave_clear_fired
##      assignment and the wave_completed emission) were added into the CURRENT
##      structure (guard-at-top / whole-function call_deferred), not the
##      story's stale version — see wave_manager.gd's own doc comments on
##      those two functions.
##
## Follows the EventBusSpy + direct-invocation conventions established in
## tests/unit/wave_manager/wave_manager_defeat_victory_test.gd. A local
## `_order` recorder is added here (EventBusSpy does not track cross-signal
## emission order) to verify the Rule 11 / Rule 13 / AC-5 ordering guarantees,
## which require checking relative order across DIFFERENT signal types.

const STUB_SCENE_PATH: String = "res://tests/fixtures/scene_manager/StubScene.tscn"

var _wm: WaveManager
var _spy: EventBusSpy
var _order: Array = []

var _cb_wave_started: Callable
var _cb_wave_completed: Callable
var _cb_mission_phase_changed: Callable
var _cb_wave_preview_available: Callable

var _original_mission_path: String
var _original_sanctuary_path: String
var _original_current_scene: Node


## Real leak found and fixed (2026-08-10): mission_phase_changed is a real
## GLOBAL EventBus signal — firing it from this suite's own LOCAL _wm
## instance still reaches the REAL, always-live SceneManager Autoload
## (subscribed in its own _ready()), which reacts to new_phase ==
## "MISSION_COMPLETE" by calling the REAL transition_to_sanctuary(). This
## file's own MISSION_COMPLETE tests were silently swapping current_scene to
## the actual, heavy SanctuaryScene.tscn and never cleaning it up, leaking a
## fully alive, EventBus-subscribed scene into the rest of the test run
## (confirmed live via bisection — the same class of gap as tests/
## integration/foundation/scene_manager_transition_test.gd and tests/
## integration/hero/hero_lifecycle_test.gd, both fixed the same session).
## Matches their same stub-injection + real-cleanup convention.
func before_test() -> void:
	_original_mission_path = GSceneManager._mission_scene_path
	_original_sanctuary_path = GSceneManager._sanctuary_scene_path
	GSceneManager._inject(STUB_SCENE_PATH, STUB_SCENE_PATH)
	_original_current_scene = get_tree().current_scene

	_wm = WaveManager.new()
	add_child(_wm)  # triggers _ready() — creates timers, subscribes to EventBus

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.wave_started)
	_spy.watch(GEventBus.wave_completed)
	_spy.watch(GEventBus.mission_phase_changed)
	_spy.watch(GEventBus.wave_preview_available)

	# Order recorder — independent of EventBusSpy, which only tracks emissions
	# per-signal-name and cannot answer "did A fire before B" across types.
	_order = []
	_cb_wave_started = func(_a: int, _b: int, _c: float) -> void: _order.append("wave_started")
	_cb_wave_completed = func(_a: int, _b: int, _c: bool) -> void: _order.append("wave_completed")
	_cb_mission_phase_changed = func(_a: String, _b: String, _c: float) -> void: _order.append("mission_phase_changed")
	_cb_wave_preview_available = func(_a: int, _b: Array, _c: Vector2i) -> void: _order.append("wave_preview_available")
	GEventBus.wave_started.connect(_cb_wave_started)
	GEventBus.wave_completed.connect(_cb_wave_completed)
	GEventBus.mission_phase_changed.connect(_cb_mission_phase_changed)
	GEventBus.wave_preview_available.connect(_cb_wave_preview_available)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	GEventBus.wave_started.disconnect(_cb_wave_started)
	GEventBus.wave_completed.disconnect(_cb_wave_completed)
	GEventBus.mission_phase_changed.disconnect(_cb_mission_phase_changed)
	GEventBus.wave_preview_available.disconnect(_cb_wave_preview_available)
	remove_child(_wm)
	_wm.free()

	if GSceneManager._transition_in_progress:
		await GEventBus.scene_transition_completed
	var loaded_scene: Node = get_tree().current_scene
	GSceneManager._inject(_original_mission_path, _original_sanctuary_path)
	GSceneManager._transition_in_progress = false
	if is_instance_valid(_original_current_scene):
		get_tree().current_scene = _original_current_scene
	if loaded_scene != null and is_instance_valid(loaded_scene) and loaded_scene != _original_current_scene:
		loaded_scene.free()

# ---------------------------------------------------------------------------
# Rule 10c / AC-5: wave_started fires before mission_phase_changed, same
# frame, on PRE_WAVE -> WAVE_ACTIVE. 5-wave fixture, total_waves pinned to 5.
# ---------------------------------------------------------------------------

func test_wave_started_fires_before_mission_phase_changed_on_pre_wave_to_wave_active() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._wave_scripts_count = 5
	_wm._templates_ready = true  # avoid an unresolved await on wave 1's templates_ready gate
	_wm._wave_reward_scalar = 1.0

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	assert_int(_order.find("wave_started")).is_greater_equal(0)
	assert_int(_order.find("mission_phase_changed")).is_greater(_order.find("wave_started"))

	assert_bool(_spy.was_emitted("wave_started")).is_true()
	var args: Array = (_spy.emissions["wave_started"] as Array)[0]
	assert_int(args[0]).is_equal(1)       # wave_number
	assert_int(args[1]).is_equal(5)       # total_waves — pinned exactly, not unbound
	assert_float(args[2]).is_equal(1.0)   # wave_difficulty (wave_reward_scalar)


## Rule 10c payload correctness across multiple waves — second PRE_WAVE ->
## WAVE_ACTIVE transition reports wave_number 2, not a stale/repeated 1.
func test_wave_started_reports_correct_wave_number_on_second_wave() -> void:
	_wm._phase = WaveManager.Phase.PRE_WAVE
	_wm._wave_scripts_count = 5
	_wm._templates_ready = true
	_wm._wave_index = 1  # wave 1 already cleared

	_wm._transition_to(WaveManager.Phase.WAVE_ACTIVE)

	var args: Array = (_spy.emissions["wave_started"] as Array)[0]
	assert_int(args[0]).is_equal(2)
	assert_int(args[1]).is_equal(5)


## Rule 10c: entering a phase other than WAVE_ACTIVE never emits wave_started.
func test_wave_started_not_emitted_on_non_wave_active_transition() -> void:
	_wm._phase = WaveManager.Phase.SCOUT

	_wm._transition_to(WaveManager.Phase.PRE_WAVE)

	assert_bool(_spy.was_emitted("wave_started")).is_false()

# ---------------------------------------------------------------------------
# Rule 11 / AC-27: non-final wave clear emits wave_completed, then
# mission_phase_changed, then wave_preview_available (INTERMISSION entry).
# ---------------------------------------------------------------------------

func test_standard_clear_emits_wave_completed_then_mission_phase_changed_then_wave_preview_available() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_scripts_count = 2
	_wm._wave_index = 1
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 1
	_wm._wave_composition_by_number[2] = [
		WaveSpawnEntry.new(&"goblin", 0.0),
		WaveSpawnEntry.new(&"goblin", 0.0),
		WaveSpawnEntry.new(&"orc", 0.0),
	]
	_order.clear()

	GEventBus.monster_died.emit(MonsterDiedEvent.new())

	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)
	# Guard before the ordinal comparisons below — if a signal never fired,
	# _order.find() returns -1 and the subsequent is_greater() assertions
	# would produce a confusing off-by-one-looking failure instead of a clear
	# "signal never fired" message.
	assert_bool(_spy.was_emitted("wave_completed")).is_true()
	assert_bool(_spy.was_emitted("mission_phase_changed")).is_true()
	assert_bool(_spy.was_emitted("wave_preview_available")).is_true()
	var i_completed: int = _order.find("wave_completed")
	var i_phase: int = _order.find("mission_phase_changed")
	var i_preview: int = _order.find("wave_preview_available")
	assert_int(i_completed).is_equal(0)
	assert_int(i_phase).is_greater(i_completed)
	assert_int(i_preview).is_greater(i_phase)

	var completed_args: Array = (_spy.emissions["wave_completed"] as Array)[0]
	assert_int(completed_args[0]).is_equal(1)
	assert_int(completed_args[1]).is_equal(0)
	assert_bool(completed_args[2]).is_false()

	var preview_args: Array = (_spy.emissions["wave_preview_available"] as Array)[0]
	assert_int(preview_args[0]).is_equal(2)  # next_wave_number = _wave_index + 1
	var composition: Array = preview_args[1]
	var total_count: int = 0
	for entry: Dictionary in composition:
		total_count += int(entry["count"])
	assert_int(total_count).is_equal(3)  # AC-27: sums to the upcoming wave's total entry count
	assert_int(composition.size()).is_equal(2)  # 2 unique monster ids


## AC-27 edge case: no composition registered for the upcoming wave (Story
## 006's real WaveConfig not wired yet) — wave_preview_available still fires,
## with an empty composition rather than an error.
func test_wave_preview_available_emits_empty_composition_when_seam_unpopulated() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_scripts_count = 2
	_wm._wave_index = 1
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 1

	GEventBus.monster_died.emit(MonsterDiedEvent.new())

	var preview_args: Array = (_spy.emissions["wave_preview_available"] as Array)[0]
	assert_int(preview_args[0]).is_equal(2)
	var composition: Array = preview_args[1]
	assert_int(composition.size()).is_equal(0)

# ---------------------------------------------------------------------------
# Rule 13: final wave clear emits wave_completed before mission_phase_changed
# (-> MISSION_COMPLETE); wave_preview_available must NOT fire.
# ---------------------------------------------------------------------------

func test_final_wave_clear_emits_wave_completed_before_mission_phase_changed() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_scripts_count = 2
	_wm._wave_index = 2
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 1
	_order.clear()

	GEventBus.monster_died.emit(MonsterDiedEvent.new())

	assert_int(_wm._phase).is_equal(WaveManager.Phase.MISSION_COMPLETE)
	# Guard before the ordinal comparison — see the non-final-clear test above
	# for why this precedes the _order.find() comparisons.
	assert_bool(_spy.was_emitted("wave_completed")).is_true()
	assert_bool(_spy.was_emitted("mission_phase_changed")).is_true()
	var i_completed: int = _order.find("wave_completed")
	var i_phase: int = _order.find("mission_phase_changed")
	assert_int(i_completed).is_equal(0)
	assert_int(i_phase).is_greater(i_completed)

	var completed_args: Array = (_spy.emissions["wave_completed"] as Array)[0]
	assert_int(completed_args[0]).is_equal(2)
	assert_int(completed_args[1]).is_equal(0)
	assert_bool(completed_args[2]).is_false()

	assert_bool(_spy.was_emitted("wave_preview_available")).is_false()

# ---------------------------------------------------------------------------
# Rule 23: watchdog force-clear reports the actual stuck enemy count, not 0.
# ---------------------------------------------------------------------------

func test_watchdog_force_clear_reports_actual_stuck_count() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 3
	_wm._enemies_alive = 2

	_wm._on_watchdog_force_timeout()  # direct callback invocation (project convention)

	assert_bool(_spy.was_emitted("wave_completed")).is_true()
	var args: Array = (_spy.emissions["wave_completed"] as Array)[0]
	assert_int(args[0]).is_equal(3)
	assert_int(args[1]).is_equal(2)  # NOT 0 — the actual stuck count
	assert_bool(args[2]).is_false()


func test_watchdog_force_clear_on_final_wave_still_reports_stuck_count() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_scripts_count = 2
	_wm._wave_index = 2
	_wm._enemies_alive = 4

	_wm._on_watchdog_force_timeout()

	var args: Array = (_spy.emissions["wave_completed"] as Array)[0]
	assert_int(args[1]).is_equal(4)
	assert_int(_wm._phase).is_equal(WaveManager.Phase.MISSION_COMPLETE)


## Rule 11's full 3-signal ordering chain (wave_completed -> mission_phase_changed
## -> wave_preview_available), proven on the watchdog force-clear path for a
## NON-final wave. The other watchdog tests above only check wave_completed's
## payload; they don't drive a non-final wave through to INTERMISSION, so they
## never exercise wave_preview_available or the downstream ordering at all.
func test_watchdog_force_clear_on_non_final_wave_follows_full_rule_11_ordering() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_scripts_count = 2
	_wm._wave_index = 1
	_wm._enemies_alive = 3
	_wm._wave_composition_by_number[2] = [WaveSpawnEntry.new(&"goblin", 0.0)]
	_order.clear()

	_wm._on_watchdog_force_timeout()

	assert_int(_wm._phase).is_equal(WaveManager.Phase.INTERMISSION)
	assert_bool(_spy.was_emitted("wave_completed")).is_true()
	assert_bool(_spy.was_emitted("mission_phase_changed")).is_true()
	assert_bool(_spy.was_emitted("wave_preview_available")).is_true()
	var i_completed: int = _order.find("wave_completed")
	var i_phase: int = _order.find("mission_phase_changed")
	var i_preview: int = _order.find("wave_preview_available")
	assert_int(i_completed).is_equal(0)
	assert_int(i_phase).is_greater(i_completed)
	assert_int(i_preview).is_greater(i_phase)

	var completed_args: Array = (_spy.emissions["wave_completed"] as Array)[0]
	assert_int(completed_args[1]).is_equal(3)  # Rule 23: actual stuck count, not 0

# ---------------------------------------------------------------------------
# AC-11: standard clear fires wave_completed in the same frame as the final
# monster_died matching all fired spawn entries.
# ---------------------------------------------------------------------------

func test_wave_completed_fires_same_frame_as_final_monster_died() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._wave_index = 1
	# All spawn entries already fired (simulated directly — this test targets
	# the monster_spawned/monster_died -> wave_completed path, not the spawn
	# coroutine itself, which is covered by wave_manager_spawn_test.gd).
	_wm._all_spawns_fired = true

	GEventBus.monster_spawned.emit(MonsterSpawnedEvent.new())
	GEventBus.monster_spawned.emit(MonsterSpawnedEvent.new())
	assert_int(_wm._enemies_alive).is_equal(2)

	GEventBus.monster_died.emit(MonsterDiedEvent.new())
	assert_bool(_spy.was_emitted("wave_completed")).is_false()  # 1 enemy still alive

	GEventBus.monster_died.emit(MonsterDiedEvent.new())

	# No await anywhere in this test — proves same-frame (synchronous) delivery.
	assert_bool(_spy.was_emitted("wave_completed")).is_true()
	assert_int(_spy.count("wave_completed")).is_equal(1)
	var args: Array = (_spy.emissions["wave_completed"] as Array)[0]
	assert_int(args[1]).is_equal(0)

# ---------------------------------------------------------------------------
# wave_completed signature: was_boss_breached is always false from this
# story's two clear paths (BOSS breach true-emission is Story 003's job).
# ---------------------------------------------------------------------------

func test_wave_completed_third_argument_is_was_boss_breached_bool() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 1

	GEventBus.monster_died.emit(MonsterDiedEvent.new())

	var args: Array = (_spy.emissions["wave_completed"] as Array)[0]
	assert_int(args.size()).is_equal(3)
	assert_bool(args[2] is bool).is_true()
	assert_bool(args[2]).is_false()

# ---------------------------------------------------------------------------
# _wave_clear_fired latch: set true at both clear paths, immediately before
# their wave_completed emission (Story 003's consuming-guard precondition).
# ---------------------------------------------------------------------------

func test_wave_clear_fired_latched_true_at_standard_clear_path() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._all_spawns_fired = true
	_wm._enemies_alive = 1
	assert_bool(_wm._wave_clear_fired).is_false()

	GEventBus.monster_died.emit(MonsterDiedEvent.new())

	assert_bool(_wm._wave_clear_fired).is_true()


func test_wave_clear_fired_latched_true_at_watchdog_force_clear_path() -> void:
	_wm._phase = WaveManager.Phase.WAVE_ACTIVE
	_wm._enemies_alive = 5
	assert_bool(_wm._wave_clear_fired).is_false()

	_wm._on_watchdog_force_timeout()

	assert_bool(_wm._wave_clear_fired).is_true()

# ---------------------------------------------------------------------------
# Performance note: composition aggregation is bounded by the wave's own
# entry count (not per-frame, not proportional to any global state) and
# produces correct results at a representative wave size — structural
# evidence for the "no iteration cost beyond what already exists" guardrail,
# mirroring this suite's source-inspection-style structural tests elsewhere
# in this file's sibling test files (e.g. wave_manager_spawn_test.gd's
# 3-guard-pattern source check).
# ---------------------------------------------------------------------------

func test_build_composition_preview_aggregates_large_wave_correctly_in_one_pass() -> void:
	var entries: Array[WaveSpawnEntry] = []
	for i: int in range(12):
		entries.append(WaveSpawnEntry.new(&"goblin", 0.0))
	for i: int in range(4):
		entries.append(WaveSpawnEntry.new(&"orc", 0.0))
	for i: int in range(1):
		entries.append(WaveSpawnEntry.new(&"boss_troll", 0.0))
	_wm._wave_composition_by_number[7] = entries

	var composition: Array = _wm._build_composition_preview(7)

	assert_int(composition.size()).is_equal(3)  # one dict per unique monster_id
	var total_count: int = 0
	for entry: Dictionary in composition:
		total_count += int(entry["count"])
	assert_int(total_count).is_equal(17)  # matches the wave's total entry count


func test_build_composition_preview_returns_empty_array_for_unregistered_wave() -> void:
	var composition: Array = _wm._build_composition_preview(99)

	assert_int(composition.size()).is_equal(0)
