class_name WaveManager
extends Node

## Mission phase FSM — Sprint 3 Phase 1 (single-lane spawn coroutine), extended
## by Story 001 (epic-04-wave-manager) with DEFEAT / MISSION_COMPLETE win-loss
## conditions.
##
## Design source: production/stories/core/s3-06-wave-manager-phase1.md
##   + production/epics/epic-04-wave-manager/story-001-defeat-mission-complete.md
## Governing ADR: docs/architecture/adr-0012-wave-manager-fsm.md (Accepted)
## ADR-0002 (revised 2026-05-24) specifies WaveManager as Autoload #7, after
## GameDataRegistry (#5) and SceneManager (#6). `GWaveManager` is correctly
## registered at position 7 in project.godot (TD-wave-001 closed 2026-07-03,
## once S4-01/S4-02 landed both prerequisite Autoloads).
##
## Out of Scope for this story (see s3-06 story file and story-001/002 above):
##   - Multi-lane spawn scripts — single-lane MVP only
##
## Story 003 (boss-fastpaths-wave-clear-robustness) landed: _on_boss_died() /
## _on_monster_breached() / _on_monsters_died_batch() now *consume* the
## _wave_clear_fired latch that Story 002 declares and sets — see those
## handlers below (end of file), and the boss_died / monster_breached /
## monsters_died_batch subscriptions in _ready()/_exit_tree().
##
## Story 002 (wave-lifecycle-events) landed: wave_started / wave_completed /
## wave_preview_available are now emitted for real — see _transition_to(),
## _check_wave_clear_or_start_watchdog(), _on_watchdog_force_timeout(), and
## _enter_intermission() below.
##
## Story 006 (waveconfig-resource-loading) landed: real WaveConfig / WaveScript /
## WaveSpawnEntry Resources (ADR-0009) are now loaded at `mission_launched` —
## see _on_mission_launched(), _load_wave_config(), _reset_all_state(), and
## _validate_wave_time_budgets() below. `_wave_scripts_count` is now set from
## the real `WaveConfig.wave_scripts.size()`, and `_build_composition_preview()`
## reads the real WaveConfig when one is loaded, falling back to the
## `_wave_composition_by_number` test-injection seam otherwise (still used
## directly by unit tests that don't construct a full WaveConfig).
##
## Story 005 (rebuild-gate-waves-2plus) landed: `_rebuild_pending_gate` now
## exists (see field declaration below) and IS part of `_reset_all_state()`'s
## field list, closing the gap this comment used to describe — Story 006's
## `_reset_all_state()` now resets all 8 of ADR-0012's Key Interfaces / AC-20
## fields, not 7. See `_check_rebuild_gate()`, `_on_path_invalidated()`, and
## the waves-2+ gate inside `_run_spawn_sequence()` below for the gate's
## steady-state implementation.
##
## Direct assignment to _phase outside _transition_to() is forbidden — the single
## entry point guarantees timer-stop and mission_phase_changed emission on every
## transition (ADR-0012 Decision).

# =============================================================================
# Phase enum
# =============================================================================

enum Phase {
	IDLE,
	SCOUT,
	PRE_WAVE,
	WAVE_ACTIVE,
	INTERMISSION,
	MISSION_COMPLETE,
	DEFEAT,
}

# =============================================================================
# Data-driven phase/timer durations
# =============================================================================
# NOTE: WaveManager is registered as a script-only Autoload (no .tscn), so
# these @export defaults are not yet Inspector-tunable without converting this
# to a scene. Tracked as a known limitation — full data-driven config load is
# Out of Scope for this story (see WaveConfig note above).

@export var scout_duration_sec: float = 60.0
@export var pre_wave_duration_sec: float = 10.0
@export var intermission_duration_sec: float = 30.0
@export var watchdog_stall_sec: float = 30.0
@export var watchdog_force_sec: float = 60.0

# =============================================================================
# Private state — no public properties; observable via EventBus only.
# =============================================================================

var _phase: Phase = Phase.IDLE
var _phase_locked: bool = false
var _wave_index: int = 0            # 0 = no wave started; 1..N = active wave
var _enemies_alive: int = 0         # clamped >= 0
var _all_spawns_fired: bool = false
var _templates_ready: bool = false
var _spawn_active: bool = false     # set false to cancel spawn coroutine

## Story 005 (rebuild-gate-waves-2plus): Rule 22 secondary gate, analogous to
## `_templates_ready` but for waves 2+. Set `true` by `_check_rebuild_gate()`
## (called once at the INTERMISSION → PRE_WAVE transition) when
## `GPathfindingSystem.is_rebuild_pending()` is `true`; consumed by
## `_run_spawn_sequence()`'s waves-2+ gate, mutually exclusive with wave 1's
## `_templates_ready` gate (`_wave_index == 1` never reaches the waves-2+
## branch, and vice versa — see that function below).
var _rebuild_pending_gate: bool = false

## Sprint 3 MVP placeholder — superseded by Story 007's per-entry
## `_resolve_spawn_cell()` (which reads `_spawn_cells` / `_round_robin_counter`
## instead). No longer read by production code; left declared only because
## some pre-Story-007 tests still assign to it harmlessly. Settable directly
## (tests / future mission-launch wiring).
var _spawn_cell: Vector2i = Vector2i(-1, -1)

## Minimal spawn data for the wave currently in WAVE_ACTIVE. Populated directly
## by tests / future WaveConfig loader (Out of Scope for this story).
var _wave_spawn_entries: Array[WaveSpawnEntry] = []
var _wave_reward_scalar: float = 1.0

## ADR-0036 (Rule 7/F2/F3): Formula F2's unclamped running multiplicative
## product across all equipped tarot_reward_scalar_mult cards. Reset in
## _reset_all_state() (fresh mission or retry). Composed into
## _wave_reward_scalar at every WAVE_ACTIVE entry, per F3.
var _tarot_reward_multiplier_raw: float = 1.0

## ADR-0036 (Rule 7/Rule 8 stacking rule): REPLACE-type first-event-wins
## guards for tarot_difficulty_growth_rate / tarot_wave_config_override.
## Multiple equipped cards targeting the same REPLACE type is a data-error
## case the Tarot Deck UI should already prevent at equip-time; the first
## event received (== lowest deck-slot index, since Tarot emits in
## _active_mission_deck array order) wins, the rest are logged and discarded.
var _tarot_growth_rate_override_applied: bool = false
var _winning_growth_rate_source_card_id: String = ""
var _tarot_wave_config_override_applied: bool = false

## Story 004 (F1 formula, wave-manager.md): difficulty_growth_rate comes from
## the mission's WaveConfig (Story 006) — until that lands, use a settable
## test-injection field, matching this file's established pattern for other
## not-yet-wired config values (_wave_scripts_count, _wave_composition_by_number).
@export var difficulty_growth_rate: float = 0.20

## Story 001 placeholder for the mission's total wave count, feeding
## _is_final_wave(). Settable directly by tests, OR set from the real
## WaveConfig.wave_scripts.size() in _on_mission_launched() (Story 006).
## Defaults large so no mission is mistaken for being on its final wave until
## a real count is set.
var _wave_scripts_count: int = 999999

## Story 002: latched true the instant either wave-clear path (standard clear
## in _check_wave_clear_or_start_watchdog(), or watchdog force-clear in
## _on_watchdog_force_timeout()) commits to emitting wave_completed —
## immediately before that emission. Declared and set here so Story 003's
## BOSS-death / monster-breached guards have a stable field to consume
## without retrofitting this file. Reset is Story 006's job (mission_launched
## reset), out of scope here.
var _wave_clear_fired: bool = false

## Story 002 test-injectable seam for wave_preview_available's composition
## payload (AC-27). Keyed by 1-based wave_number; each value is an
## Array[WaveSpawnEntry] for that wave. Still consumed directly by unit tests
## that don't construct a full WaveConfig; _build_composition_preview() (Story
## 006) only falls back to this seam when _wave_config is unset.
var _wave_composition_by_number: Dictionary = {}  # int -> Array[WaveSpawnEntry]

# =============================================================================
# Story 006 (waveconfig-resource-loading): real per-mission WaveConfig state.
# =============================================================================

## The mission's WaveConfig, loaded fresh at every mission_launched via
## _load_wave_config(). null until the first mission_launched fires (or in
## tests that only exercise functions unrelated to mission_launched).
var _wave_config: WaveConfig = null

## SPAWN cells read once per mission_launched via _grid.get_spawn_cells()
## (ADR-0012's documented direct-Grid-read exception to EventBus-only
## cross-system comms). Round-robin *consumption* of this array (assigning
## _spawn_cells[i % n] to each spawn entry) is Story 007's job — this story
## only reads and stores it, plus guards on it being non-empty (AC-36).
var _spawn_cells: Array[Vector2i] = []

## Rule 8 (Story 006): round-robin spawn-cell index — reset every mission and
## every WAVE_ACTIVE entry per ADR-0012's private-state list. This story only
## declares and resets the counter; Story 007 owns actually consuming it.
var _round_robin_counter: int = 0

## Sourced fresh from mission_launched's 3rd argument on every mission launch
## (see "difficulty_tier sourcing" in story-006-waveconfig-resource-loading.md)
## — deliberately NOT part of _reset_all_state()'s field list, since it is
## assigned anew from real mission data every call, not reset to a default.
var _difficulty_tier: int = 0
var _current_mission_id: String = ""  ## ADR-0036: needed by tarot_wave_config_override's content-error log format

## Test-injection seam mirroring MonsterManager's `_grid` field convention
## (src/core/monster/monster_manager.gd) — production code reads from this
## reference (assigned to the real GGrid Autoload in _ready()); tests may
## override it with a stub after add_child(), avoiding pollution of the real
## GGrid Autoload's shared global state across test runs.
var _grid = null

## Test-injection seam for WaveConfig resolution. Defaults to
## _default_load_wave_config (assigned in _ready()), which resolves via
## ResourceLoader from the ADR-0009 path convention
## (assets/data/waves/{mission_id}_waves.tres). Tests may override this
## Callable to return an in-memory WaveConfig without touching the filesystem
## — no `.tres` content exists yet for any mission, so the default resolver's
## file-not-found fallback (an empty WaveConfig, see _default_load_wave_config)
## is what every real mission_launched hits today; tests exercising specific
## WaveConfig content (wave counts, pre_delay budgets, etc.) should override
## this seam instead of relying on that fallback.
var _wave_config_loader: Callable

# =============================================================================
# Timer nodes — 5x scene-tree Timer, one_shot, timeout-connected (ADR-0012).
# Directly invokable in tests via _on_..._timeout() without Engine.time_scale.
# =============================================================================

var _scout_timer: Timer
var _pre_wave_timer: Timer
var _intermission_timer: Timer
var _watchdog_stall_timer: Timer
var _watchdog_force_timer: Timer

## GDD Formula F2: emits phase_timer_tick once per second during SCOUT and
## INTERMISSION. Extended (beyond F2's own documented SCOUT/INTERMISSION-only
## scope — see wave-manager.md's "Type note") to also tick during PRE_WAVE,
## since that is exactly the "counting down to monster spawn" window players
## see after pressing Ready — wave_countdown_warning alone only fires once at
## PRE_WAVE entry and never updates again, leaving the HUD frozen for the
## full 10s. Repeating (one_shot=false) rather than one of the phase-duration
## timers themselves, since it must keep running across whichever phase is
## active without being torn down/recreated at every transition.
var _phase_tick_timer: Timer

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_scout_timer = _make_timer("_scout_timer", _on_scout_timer_timeout, scout_duration_sec)
	_pre_wave_timer = _make_timer("_pre_wave_timer", _on_pre_wave_timer_timeout, pre_wave_duration_sec)
	_intermission_timer = _make_timer("_intermission_timer", _on_intermission_timer_timeout, intermission_duration_sec)
	_watchdog_stall_timer = _make_timer("_watchdog_stall_timer", _on_watchdog_stall_timeout, watchdog_stall_sec)
	_watchdog_force_timer = _make_timer("_watchdog_force_timer", _on_watchdog_force_timeout, watchdog_force_sec)

	_phase_tick_timer = Timer.new()
	_phase_tick_timer.name = "_phase_tick_timer"
	_phase_tick_timer.one_shot = false
	_phase_tick_timer.wait_time = 1.0
	_phase_tick_timer.timeout.connect(_on_phase_tick_timer_timeout)
	add_child(_phase_tick_timer)

	_grid = GGrid
	_wave_config_loader = _default_load_wave_config

	GEventBus.player_ready.connect(_on_player_ready)
	GEventBus.templates_ready.connect(_on_templates_ready)
	GEventBus.monster_spawned.connect(_on_monster_spawned)
	GEventBus.monster_died.connect(_on_monster_died)
	GEventBus.hero_died.connect(_on_hero_died)
	GEventBus.mission_launched.connect(_on_mission_launched)
	# Story 003 (boss-fastpaths-wave-clear-robustness):
	GEventBus.boss_died.connect(_on_boss_died)
	GEventBus.monster_breached.connect(_on_monster_breached)
	GEventBus.monsters_died_batch.connect(_on_monsters_died_batch)
	GEventBus.mission_modifier_applied.connect(_on_mission_modifier_applied)


func _exit_tree() -> void:
	GEventBus.player_ready.disconnect(_on_player_ready)
	GEventBus.templates_ready.disconnect(_on_templates_ready)
	GEventBus.monster_spawned.disconnect(_on_monster_spawned)
	GEventBus.monster_died.disconnect(_on_monster_died)
	GEventBus.hero_died.disconnect(_on_hero_died)
	GEventBus.mission_launched.disconnect(_on_mission_launched)
	GEventBus.boss_died.disconnect(_on_boss_died)
	GEventBus.monster_breached.disconnect(_on_monster_breached)
	GEventBus.monsters_died_batch.disconnect(_on_monsters_died_batch)
	GEventBus.mission_modifier_applied.disconnect(_on_mission_modifier_applied)


func _make_timer(node_name: String, callback: Callable, wait_time: float) -> Timer:
	var t := Timer.new()
	t.name = node_name
	t.one_shot = true
	t.wait_time = wait_time
	t.timeout.connect(callback)
	add_child(t)
	return t

# =============================================================================
# Single transition entry point (ADR-0012 Key Interfaces)
# =============================================================================

func _transition_to(new_phase: Phase) -> void:
	if _phase_locked:
		return
	_phase_locked = true
	var previous_phase: Phase = _phase
	if previous_phase == Phase.WAVE_ACTIVE and new_phase != Phase.WAVE_ACTIVE:
		_spawn_active = false
	_stop_phase_timers()
	_phase = new_phase
	# Rule 10c / AC-5 (Story 002): wave_started must fire strictly before
	# mission_phase_changed, in the same frame, when entering WAVE_ACTIVE.
	# _wave_index has NOT been incremented for this transition yet — that
	# happens inside _enter_wave_active(), called via _enter_phase() below —
	# so _wave_index + 1 is the number of the wave about to start. Emitting
	# here (in the single transition entry point) rather than inside
	# _enter_wave_active() is what guarantees the ordering relative to
	# mission_phase_changed, emitted immediately after this block.
	if new_phase == Phase.WAVE_ACTIVE:
		# Story 004 F1 formula: correction to that story's pseudocode, which
		# assumed this was computed inside _enter_wave_active() — true when the
		# story was written, but Story 002 later moved wave_started's emission
		# here, into _transition_to(), strictly before _enter_phase() (which is
		# what eventually calls _enter_wave_active()). Computing the scalar at
		# this exact point — immediately before wave_started's own emission —
		# keeps wave_started.wave_difficulty and the later
		# monster_spawn_requested.wave_reward_scalar consistent for the same
		# wave (AC-17 payload consistency). w = _wave_index + 1 is the wave
		# about to start — the same value passed as wave_started's own
		# wave_number argument below; _wave_index itself is not incremented
		# until _enter_wave_active() runs, afterward. _wave_index (still at
		# its pre-increment value here) already equals w - 1, so it's used
		# directly as the formula's exponent without re-deriving it from w.
		# ADR-0036 (tarot.md Formula F3): composes Tarot's reward layer on top
		# of this system's own natural formula. _tarot_reward_multiplier_raw
		# is F2's running product (1.0 when no tarot_reward_scalar_mult card
		# is equipped); compute_rune_bonus() is read fresh here rather than
		# cached at SCOUT entry -- rune discovery only happens at mission end,
		# so it cannot change mid-mission and a fresh read is always correct.
		var wave_reward_scalar_natural: float = pow(1.0 + difficulty_growth_rate, float(_wave_index))
		var rune_reward_bonus: float = GTarot.compute_rune_bonus(&"tarot_reward_scalar_mult")
		_wave_reward_scalar = clamp(
				wave_reward_scalar_natural * _tarot_reward_multiplier_raw + rune_reward_bonus,
				1.00, 4.768)
		GEventBus.wave_started.emit(_wave_index + 1, _wave_scripts_count, _wave_reward_scalar)
	GEventBus.mission_phase_changed.emit(
			_phase_name(previous_phase), _phase_name(new_phase), Time.get_unix_time_from_system())
	_enter_phase(new_phase)
	_phase_locked = false


func _stop_phase_timers() -> void:
	_scout_timer.stop()
	_pre_wave_timer.stop()
	_intermission_timer.stop()
	_watchdog_stall_timer.stop()
	_watchdog_force_timer.stop()
	_phase_tick_timer.stop()


func _phase_name(phase: Phase) -> String:
	return Phase.keys()[phase]

# =============================================================================
# Phase entry methods
# =============================================================================

func _enter_phase(new_phase: Phase) -> void:
	match new_phase:
		Phase.IDLE:
			_enter_idle()
		Phase.SCOUT:
			_enter_scout()
		Phase.PRE_WAVE:
			_enter_pre_wave()
		Phase.WAVE_ACTIVE:
			_enter_wave_active()
		Phase.INTERMISSION:
			_enter_intermission()
		Phase.MISSION_COMPLETE:
			pass  # Transition mechanics only (Story 001) — entry side effects (reward/summary payloads) are a future story's job
		Phase.DEFEAT:
			pass  # Transition mechanics only (Story 001) — entry side effects (loss UI/reward payloads) are a future story's job


func _enter_idle() -> void:
	pass


func _enter_scout() -> void:
	_scout_timer.start()
	_phase_tick_timer.start()


func _enter_pre_wave() -> void:
	_pre_wave_timer.start()
	_phase_tick_timer.start()


func _enter_wave_active() -> void:
	_wave_index += 1
	_enemies_alive = 0
	_all_spawns_fired = false
	_spawn_active = true
	_round_robin_counter = 0  # Rule 10f (Story 007): wave-scoped, not mission-scoped
	# Code review fix (Story 003): _wave_clear_fired was previously only reset
	# per-mission (_reset_all_state(), Story 006) — never per-wave. Since this
	# story's _on_boss_died()/_on_monster_breached() gate on
	# `if _wave_clear_fired: return`, leaving it latched true from wave 1's
	# clear would permanently dead-end BOSS fast-paths for every subsequent
	# wave in the mission (the flag would never go false again until the next
	# mission_launched). Reset it wave-scoped here, mirroring
	# _round_robin_counter's identical wave-scoped reset above.
	_wave_clear_fired = false
	# Bug found and fixed during S4-09 (Assemble The Gap Mission Scene) integration
	# verification: _wave_spawn_entries is declared and read by
	# _run_spawn_sequence() below, but was NEVER populated from the real, loaded
	# WaveConfig anywhere in production code — Story 006/007 wired real WaveConfig
	# loading and _build_composition_preview() correctly, but not this. Every real
	# (non-test-injected) mission has therefore always spawned exactly 0 monsters
	# in actual gameplay. Confirmed via a live headless run of the real
	# mission_launched -> real WaveConfig .tres -> real WAVE_ACTIVE chain — masked
	# until now because this file's entire existing test suite injects
	# _wave_spawn_entries directly, never through a real loaded _wave_config.
	# Guarded so that existing behavior (and the whole existing test suite) is
	# unaffected: only overwrite _wave_spawn_entries when a real WaveConfig with a
	# script for this wave index is actually loaded; otherwise the
	# test-injection seam continues to work exactly as before.
	if _wave_config != null and _wave_index >= 1 and _wave_index <= _wave_config.wave_scripts.size():
		_wave_spawn_entries = (_wave_config.wave_scripts[_wave_index - 1] as WaveScript).entries
	_run_spawn_sequence()


func _enter_intermission() -> void:
	_intermission_timer.start()
	_phase_tick_timer.start()
	# AC-27 (Story 002): fires immediately on INTERMISSION entry, carrying the
	# upcoming wave's composition for Mission HUD's "forewarning" display.
	var next_wave: int = _wave_index + 1
	GEventBus.wave_preview_available.emit(next_wave, _build_composition_preview(next_wave), _preview_boss_spawn_cell(next_wave))


## Aggregates wave_number's WaveSpawnEntry list into one {monster_id, count}
## Dictionary per unique monster_id, in first-seen order. Returns [] if
## wave_number has no available composition.
##
## Story 006: reads the real WaveConfig.wave_scripts when one is loaded
## (production path — set by _on_mission_launched()); falls back to the
## _wave_composition_by_number test-injection seam when _wave_config is unset,
## preserving existing unit tests that inject directly into that seam without
## constructing a full WaveConfig.
##
## O(n) in the wave's own entry count; runs once per INTERMISSION/SCOUT entry
## (not per-frame), so it does not add iteration cost to the per-frame
## EventBus budget the ADR-0012 guardrail is protecting.
func _build_composition_preview(wave_number: int) -> Array[Dictionary]:
	var composition: Array[Dictionary] = []
	var entries: Array = []
	if _wave_config != null and wave_number >= 1 and wave_number <= _wave_config.wave_scripts.size():
		entries = (_wave_config.wave_scripts[wave_number - 1] as WaveScript).entries
	elif _wave_composition_by_number.has(wave_number):
		# NOTE: kept as an untyped Array, not Array[WaveSpawnEntry]. Dictionary
		# values erase static array typing whenever a caller assigns a plain
		# `[...]` literal (as this file's own tests do in more than one place) —
		# a strictly-typed Array[WaveSpawnEntry] local would throw "Trying to
		# assign an array of type Array to a variable of type
		# Array[WaveSpawnEntry]" at runtime for that (common) case. The for-loop
		# below already applies WaveSpawnEntry typing per-element, which is safe
		# regardless of the source array's own static type.
		entries = _wave_composition_by_number[wave_number]
	else:
		return composition
	var index_by_monster: Dictionary = {}
	for entry: WaveSpawnEntry in entries:
		if index_by_monster.has(entry.monster_id):
			var idx: int = index_by_monster[entry.monster_id]
			(composition[idx] as Dictionary)["count"] += 1
		else:
			index_by_monster[entry.monster_id] = composition.size()
			composition.append({"monster_id": entry.monster_id, "count": 1})
	return composition


## Mission HUD ADR-0031 (Story 006, closes tower.md's OQ-11): read-only
## preview of the BOSS-tier entry's spawn cell for wave_number, so it can be
## carried in wave_preview_available BEFORE that wave actually spawns.
## Deliberately does NOT call _resolve_spawn_cell() / touch the real
## _round_robin_counter — that field is wave-scoped mutable state consumed
## during actual spawning (_run_spawn_sequence()), and calling it here would
## desync the real spawn resolution from what was previewed. Instead
## simulates round-robin locally with its own counter, mirroring
## _resolve_spawn_cell()'s exact resolution rules (explicit spawn_cell_index
## >= 0, or round-robin for -1) without any shared mutable state.
## Returns Vector2i(-1,-1) if the wave has no BOSS-tier entry, spawn cells
## are empty, or wave_number has no known composition yet.
func _preview_boss_spawn_cell(wave_number: int) -> Vector2i:
	var entries: Array = []
	if _wave_config != null and wave_number >= 1 and wave_number <= _wave_config.wave_scripts.size():
		entries = (_wave_config.wave_scripts[wave_number - 1] as WaveScript).entries
	elif _wave_composition_by_number.has(wave_number):
		entries = _wave_composition_by_number[wave_number]
	else:
		return Vector2i(-1, -1)
	if _spawn_cells.is_empty():
		return Vector2i(-1, -1)

	var local_round_robin: int = 0
	for entry: WaveSpawnEntry in entries:
		var cell: Vector2i
		if entry.spawn_cell_index >= 0:
			cell = _spawn_cells[entry.spawn_cell_index % _spawn_cells.size()]
		else:
			cell = _spawn_cells[local_round_robin % _spawn_cells.size()]
			local_round_robin += 1
		var resource: MonsterResource = GGameDataRegistry.get_monster_resource(entry.monster_id)
		if resource != null and resource.tier == 2:  # BOSS
			return cell
	return Vector2i(-1, -1)

# =============================================================================
# Story 007 (round-robin-spawn-cells): per-entry spawn cell resolution
# =============================================================================

## Rule 15b: resolves the real spawn_cell for one WaveSpawnEntry. Called once
## per entry from inside _run_spawn_sequence()'s loop, replacing the Sprint 3
## MVP placeholder (the flat, hardcoded _spawn_cell field) entirely.
##
## Deviation from the story's Implementation Notes pseudocode (flagged, not
## silently resolved): the pseudocode's own push_warning text
## ("spawn_cell_index %d out of range — wrapping to %d.") does not contain the
## literal substring the story's own AC-35 / QA Test Cases require
## ("spawn_cell_index [N] out of range" — with literal brackets around the
## number, e.g. "spawn_cell_index [5] out of range" for index 5). The
## pseudocode's unbracketed format is the stale one here; this implementation
## follows AC-35's literal wording instead, since that is the acceptance
## criterion tests actually check.
##
## O(1): one modulo op (positive-index path) or one modulo + one increment
## (round-robin path), no new iteration — matches the story's Performance note.
func _resolve_spawn_cell(entry: WaveSpawnEntry) -> Vector2i:
	if _spawn_cells.is_empty():
		push_error("WaveManager: _resolve_spawn_cell() called with empty _spawn_cells — should have been caught by Story 006's mission_launched guard.")
		return Vector2i(-1, -1)
	if entry.spawn_cell_index >= 0:
		var index: int = entry.spawn_cell_index
		if index >= _spawn_cells.size():
			push_warning("WaveManager: spawn_cell_index [%d] out of range — wrapping to %d." % [index, index % _spawn_cells.size()])
		return _spawn_cells[index % _spawn_cells.size()]
	else:
		# Code review fix (Story 007): Rule 15b only defines behavior for
		# spawn_cell_index >= 0 (positive index) or exactly -1 (round-robin) —
		# any other negative value (e.g. a content-authoring typo like -2) was
		# previously silently treated as round-robin with no signal to the
		# author that something is off. Warn on that undocumented case, but
		# still resolve via round-robin (least-surprising fallback), matching
		# the positive-index path's warn-but-still-resolve pattern above.
		if entry.spawn_cell_index != -1:
			push_warning("WaveManager: spawn_cell_index [%d] is not >= 0 or exactly -1 — treating as round-robin." % entry.spawn_cell_index)
		var cell: Vector2i = _spawn_cells[_round_robin_counter % _spawn_cells.size()]
		_round_robin_counter += 1
		return cell

# =============================================================================
# Story 005 (rebuild-gate-waves-2plus): Rule 22 waves-2+ pathfinding rebuild
# gate, analogous to the wave-1 `_templates_ready` gate above.
# =============================================================================

## Rule 22 secondary gate: called once at the INTERMISSION → PRE_WAVE
## transition (from `_on_intermission_timer_timeout()` and `_on_player_ready()`'s
## INTERMISSION branch, immediately before each of their `_transition_to(
## Phase.PRE_WAVE)` calls). Wave 1 never reaches either of those call sites (it
## starts at SCOUT → PRE_WAVE, which does NOT call this function), so this gate
## is structurally never checked for wave 1 — see the mutual-exclusivity note
## on `_rebuild_pending_gate`'s field declaration above.
##
## Deviation from the story's Implementation Notes pseudocode (flagged, not
## silently applied): the story's own pseudocode only ever sets
## `_rebuild_pending_gate = true` in the positive branch, with no `else`,
## relying entirely on `_on_path_invalidated()` having already reset the flag
## (and disconnected the subscription) from whatever wave last used it. That
## leaves this function without any defensive correction if that cleanup
## somehow didn't happen (a missed signal, an edge case in the disconnect
## logic, etc.) — the exact class of bug Story 003 shipped with this session
## (an unreset latch field silently broke a whole feature from wave 2 onward).
## This implementation instead makes `_check_rebuild_gate()` self-correcting on
## every call: the `else` branch explicitly resets the flag to `false`
## regardless of its prior value, and both branches guard their
## connect()/disconnect() calls with `Signal.is_connected()` so a call to this
## function can never double-connect or double-disconnect
## `GEventBus.path_invalidated` no matter what state the subscription was
## actually left in beforehand. `Signal.is_connected()` is a long-standing
## Godot 3.x/4.x API, unaffected by the 4.4–4.6 changes this project's
## `docs/engine-reference/godot/VERSION.md` flags as knowledge-gap risk — safe
## to use without further verification.
func _check_rebuild_gate() -> void:
	if GPathfindingSystem.is_rebuild_pending():
		_rebuild_pending_gate = true
		if not GEventBus.path_invalidated.is_connected(_on_path_invalidated):
			GEventBus.path_invalidated.connect(_on_path_invalidated)
	else:
		_rebuild_pending_gate = false
		if GEventBus.path_invalidated.is_connected(_on_path_invalidated):
			GEventBus.path_invalidated.disconnect(_on_path_invalidated)


## Disconnects immediately on release — prevents subscription accumulation
## across waves 2-8 (per the GDD's explicit lifecycle note for this signal,
## contrasted with `templates_ready`, which stays connected for the whole
## mission). Guards its own disconnect with `Signal.is_connected()` even
## though, in the current call graph, this handler only ever runs while still
## connected — the guard costs nothing (one boolean check) and keeps this
## function safe under any future change to that call graph, matching the
## same defensive style used in `_check_rebuild_gate()` above.
##
## Verified claim (per this project's standing rule to verify engine-behavior
## claims rather than copy them uncritically): the story's Implementation
## Notes assert that a double-disconnect on an already-disconnected signal
## throws an error in Godot 4.6.2. This is long-standing Godot behavior (not
## something introduced in 4.4–4.6, and not contradicted by anything in
## `docs/engine-reference/godot/`) — `Object.disconnect()` / `Signal.disconnect()`
## push an error ("Disconnecting nonexistent signal") when called on a
## callable that isn't currently connected. The claim holds; the
## `is_connected()` guards above and here are necessary, not just defensive
## decoration.
func _on_path_invalidated(_affected_cells: Array) -> void:
	_rebuild_pending_gate = false
	if GEventBus.path_invalidated.is_connected(_on_path_invalidated):
		GEventBus.path_invalidated.disconnect(_on_path_invalidated)

# =============================================================================
# Spawn coroutine — 3-guard pattern at every await (ADR-0012 Key Interfaces)
# =============================================================================

func _run_spawn_sequence() -> void:
	if _wave_index == 1 and not _templates_ready:
		await GEventBus.templates_ready
		if not is_instance_valid(self): return
		if not _spawn_active: return
		if _phase != Phase.WAVE_ACTIVE: return

	# Story 005: waves-2+ gate, mutually exclusive with the wave-1 gate above —
	# _wave_index == 1 never reaches this branch, and vice versa (wave 1's
	# _rebuild_pending_gate is never set true in the first place, since
	# _check_rebuild_gate() is never called before wave 1's own WAVE_ACTIVE
	# entry — see that function's doc comment).
	if _wave_index > 1 and _rebuild_pending_gate:
		await GEventBus.path_invalidated
		if not is_instance_valid(self): return
		if not _spawn_active: return
		if _phase != Phase.WAVE_ACTIVE: return
		# Early-fire guard (per the GDD's explicit wording): if
		# `path_invalidated` already fired during the PRE_WAVE countdown,
		# before this coroutine started, `_on_path_invalidated()` (a normal,
		# always-connected-first, signal-connected handler) will have already
		# reset `_rebuild_pending_gate` to `false` and disconnected the
		# subscription before this `await` line is even reached — so this
		# `await GEventBus.path_invalidated` line is never actually entered in
		# that case, since the `if _rebuild_pending_gate:` guard above already
		# evaluates `false` by then. This comment exists to make that ordering
		# explicit; no additional code is needed here to satisfy the
		# early-fire guard AC.
		#
		# Double-disconnect subtlety (verified — see `_on_path_invalidated()`'s
		# own doc comment): do NOT disconnect `GEventBus.path_invalidated`
		# here. `_on_path_invalidated()` (connected by `_check_rebuild_gate()`)
		# receives the SAME signal emission this `await` resumes from, and owns
		# the one-and-only disconnect() call for this subscription. A second
		# disconnect() call here, on an already-disconnected callable, would
		# throw an error.

	for entry: WaveSpawnEntry in _wave_spawn_entries:
		if not _spawn_active: return
		if entry.pre_delay > 0.0:
			# process_always: false (ADR-0014) — without this, the timer ignores
			# SceneTree.paused and keeps firing scheduled spawns while "paused".
			await get_tree().create_timer(entry.pre_delay, false).timeout
			if not is_instance_valid(self): return
			if not _spawn_active: return
			if _phase != Phase.WAVE_ACTIVE: return
		var spawn_cell: Vector2i = _resolve_spawn_cell(entry)
		GEventBus.monster_spawn_requested.emit(
				entry.to_payload(_wave_index, _wave_reward_scalar, spawn_cell, _is_penultimate_wave()))

	_all_spawns_fired = true
	_check_wave_clear_or_start_watchdog()

# =============================================================================
# Watchdog / wave-clear
# =============================================================================

## Starts both watchdog timers when all spawns have fired and enemies remain;
## otherwise transitions to INTERMISSION (or MISSION_COMPLETE on the final
## wave — Rule 13/AC-6, Story 001) if the wave is already clear.
##
## Story 001 deviation from the story's Implementation Notes: this function
## now guards on `_phase != Phase.WAVE_ACTIVE` as its first check, matching
## the guard pattern every other EventBus/timer handler in this file already
## uses. This was NOT in the story's pseudo-code, but is required for AC-8:
## `_phase_locked` is a transient reentrancy guard local to a single
## _transition_to() call (reset to false at the end of _transition_to, even
## for DEFEAT) — it is not a permanent terminal-state latch. Without this
## guard, calling this function directly after hero_died has already moved
## _phase to DEFEAT (as AC-8's test does) would silently clobber DEFEAT with
## INTERMISSION/MISSION_COMPLETE, since _transition_to()'s only check
## (`if _phase_locked: return`) would no longer be true by then. Checking
## _phase here closes that gap for every current and future caller
## (_on_monster_died today; _on_boss_died / monster_breached in Stories 002/003).
##
## If the wave clears synchronously inside _transition_to(WAVE_ACTIVE)'s own
## call stack (e.g. empty or all-zero-pre_delay _wave_spawn_entries, so
## _run_spawn_sequence() never suspends on an await), _phase_locked is still
## true here — a direct _transition_to(next_phase) call would be silently
## dropped by _transition_to's own _phase_locked guard, soft-locking the FSM
## in WAVE_ACTIVE forever. Deferring the call lets it run after _phase_locked
## is released at the end of the outer _transition_to.
func _check_wave_clear_or_start_watchdog() -> void:
	if _phase != Phase.WAVE_ACTIVE:
		return
	# Code review fix (Story 003): closes a reentrancy hole found during code
	# review. MonsterManager._on_wave_completed() synchronously re-emits
	# monster_died (and boss_died) for any remaining active_monsters BEFORE
	# clearing its own list and before the original caller's _transition_to()
	# runs — at that point _phase is still WAVE_ACTIVE and _phase_locked is
	# still false, so the guards below alone don't stop a second, nested
	# wave_completed/_transition_to() from firing within the same synchronous
	# call chain. Checking the latch here (which _on_boss_died()/
	# _on_monster_breached() already do) protects every caller of this
	# function at once, including the pre-existing _on_monster_died() path
	# this hole predates. Safe to check here specifically because
	# _wave_clear_fired is now reset wave-scoped in _enter_wave_active() (see
	# that function's own code-review-fix comment) — without that reset, this
	# check would incorrectly block every wave after the first.
	if _wave_clear_fired:
		return
	if not _all_spawns_fired:
		return
	if _enemies_alive > 0:
		_watchdog_stall_timer.start()
		_watchdog_force_timer.start()
		return
	# Code review fix (Story 001): defer the WHOLE function, not just the
	# _transition_to() call. _next_phase must be recomputed fresh once the
	# deferred call actually runs, not captured now and replayed stale — if
	# hero_died lands in the gap between this call being deferred and it
	# actually executing, a captured-at-defer-time next_phase would still
	# clobber DEFEAT with a stale INTERMISSION/MISSION_COMPLETE even though
	# the _phase != Phase.WAVE_ACTIVE guard above would have caught it on
	# re-entry. Re-running this whole function on the deferred call re-checks
	# that guard against whatever _phase actually is by then.
	if _phase_locked:
		_check_wave_clear_or_start_watchdog.call_deferred()
		return
	# Rule 11 / Rule 13 (Story 002): standard clear reports 0 enemies
	# remaining — _enemies_alive is already 0 here (the `_enemies_alive > 0`
	# branch above would have returned early otherwise). Latch
	# _wave_clear_fired immediately before emitting, per this story's
	# cross-story contract with Story 003.
	_wave_clear_fired = true
	GEventBus.wave_completed.emit(_wave_index, 0, false)
	var next_phase: Phase = Phase.MISSION_COMPLETE if _is_final_wave() else Phase.INTERMISSION
	_transition_to(next_phase)


## Rule 13 / AC-6 (Story 001): the mission's final wave clearing ends the
## mission (MISSION_COMPLETE) instead of opening another INTERMISSION.
## _wave_index is 1-based (incremented in _enter_wave_active() before the
## first spawn); _wave_scripts_count is the Story 001 test-injection
## placeholder for the total wave count (see field comment — Story 006
## supersedes it with the real WaveConfig.wave_scripts.size()).
func _is_final_wave() -> bool:
	return _wave_index >= _wave_scripts_count


## Rule 15c / AC-12 (Story 004): penultimate = second-to-last wave, ONLY for
## missions with 5+ waves — sub-5-wave missions never report penultimate
## (the sub-5-wave exemption). O(1) per call; invoked once per spawn entry
## (from _run_spawn_sequence()'s per-entry loop), not per frame.
func _is_penultimate_wave() -> bool:
	return _wave_index == _wave_scripts_count - 1 and _wave_scripts_count >= 5


## Story 004: validates the authored difficulty_growth_rate is within the
## designed [0.10, 0.25] range (inclusive both ends). Logs a content error
## but does NOT clamp — mission continues with the authored value regardless.
## Standalone function with no call site yet: Story 006 owns the future
## mission_launched handler and will invoke this from there. Covered here via
## direct-invocation tests only (wave_manager_reward_scalar_test.gd), matching
## this codebase's established pattern for not-yet-wired functionality.
## Call once per mission from the mission_launched handler, before the first
## _transition_to(PRE_WAVE); idempotent, no state mutation, safe to call at
## any FSM phase.
func _validate_difficulty_growth_rate() -> void:
	if difficulty_growth_rate < 0.10 or difficulty_growth_rate > 0.25:
		push_error("WaveManager: difficulty_growth_rate %.2f outside valid range [0.10, 0.25]" % difficulty_growth_rate)

# =============================================================================
# Story 006: mission_launched — full state reset, WaveConfig load, SCOUT entry
# =============================================================================

## Rule 8 / AC-1 / AC-20: full state reset (if restarting from a terminal
## phase) THEN load WaveConfig THEN transition to SCOUT. Order matters — the
## reset must complete before _transition_to(Phase.SCOUT) runs, so no stale
## state leaks into the new mission (AC-20).
##
## AC-19 / AC-36 guard ordering deviation from the story's own Acceptance
## Criteria wording (flagged, not silently resolved): the story's AC-19/AC-36
## bullets both describe the expected transition as "mission_phase_changed
## (SCOUT → MISSION_COMPLETE)", but the story's own (authoritative,
## "corrected") Implementation Notes pseudocode places both empty-content
## guards BEFORE _transition_to(Phase.SCOUT) — its own inline comment reads
## "AC-36 — bypasses SCOUT entirely". Followed literally here: on either guard,
## `previous_phase` (whatever _phase was before this call — e.g. "IDLE" on a
## mission's first launch) transitions directly to MISSION_COMPLETE; SCOUT is
## never entered. See this story's test file and final report for detail.
func _on_mission_launched(mission_id: String, _modifiers: PackedStringArray, difficulty_tier: int) -> void:
	_reset_all_state()
	_difficulty_tier = difficulty_tier
	_current_mission_id = mission_id  # ADR-0036: needed by tarot_wave_config_override's content-error log format
	_wave_config = _load_wave_config(mission_id)
	# Code review fix (Story 006): _default_load_wave_config() establishes a
	# "never return null" contract, but _wave_config_loader is an injectable
	# Callable seam explicitly designed for override — a future non-conforming
	# override returning null would otherwise crash on the wave_scripts.is_empty()
	# check below. Defensive fallback matches _default_load_wave_config()'s own
	# empty-WaveConfig contract exactly, so AC-19's guard below still handles it.
	if _wave_config == null:
		push_error("WaveManager: _wave_config_loader returned null for mission '%s' — using an empty fallback (0 wave_scripts)." % mission_id)
		_wave_config = WaveConfig.new()
	_spawn_cells = _grid.get_spawn_cells()
	if _spawn_cells.is_empty():
		push_error("WaveManager: 0 spawn cells — cannot spawn any monsters. Triggering MISSION_COMPLETE immediately.")
		_transition_to(Phase.MISSION_COMPLETE)  # AC-36 — bypasses SCOUT entirely
		return
	if _wave_config.wave_scripts.is_empty():
		push_error("WaveManager: WaveConfig has 0 wave_scripts — mission has no waves. Triggering MISSION_COMPLETE immediately.")
		_transition_to(Phase.MISSION_COMPLETE)  # AC-19 — bypasses SCOUT entirely
		return
	_wave_scripts_count = _wave_config.wave_scripts.size()
	_validate_wave_time_budgets()  # AC-41 — logs only, never aborts
	# Do NOT duplicate the [0.10, 0.25] bounds check inline here — Story 004
	# already implemented this exact validation as _validate_difficulty_growth_rate(),
	# reading the WaveManager-level `difficulty_growth_rate` field (idempotent,
	# no state mutation, safe to call at any FSM phase). Assign the loaded
	# WaveConfig's value into that existing field, then call the existing
	# function, so Story 004's 5 validation tests actually cover the real
	# production path instead of exercising a function that never gets called.
	difficulty_growth_rate = _wave_config.difficulty_growth_rate
	_validate_difficulty_growth_rate()
	_transition_to(Phase.SCOUT)
	GEventBus.wave_preview_available.emit(1, _build_composition_preview(1), _preview_boss_spawn_cell(1))  # Rule 8 SCOUT preview


## AC-20's full 8-field reset list per ADR-0012's private-state block —
## Story 005 (rebuild-gate-waves-2plus) closed the previous 7-field gap by
## adding `_rebuild_pending_gate` here. Also cancels any in-flight phase timer
## via _stop_phase_timers() (covers the INTERMISSION-with-15s-remaining
## sub-case: the partial intermission is discarded and its timer stopped
## before a fresh mission can begin).
##
## Known gap (found during Story 005, NOT fixed here — flagged, not silently
## dropped): this function does not disconnect a possibly-still-live
## `GEventBus.path_invalidated` subscription to `_on_path_invalidated()`. If a
## mission is restarted (mission_launched fires again) while
## `_rebuild_pending_gate` was `true` and the subscription still live — e.g.
## the mission was abandoned mid-INTERMISSION-rebuild before `path_invalidated`
## ever fired — this reset clears the flag but leaves the stale subscription
## connected. The story's own Out of Scope section explicitly assigns
## "disconnecting any stale path_invalidated subscription on mission_launched"
## to Story 006 (EC-9's full state-reset list), but Story 006 already landed
## this session, before `_rebuild_pending_gate` (and `_on_path_invalidated()`)
## existed, so it could not have addressed this. No dedicated story currently
## owns this fix — tracked here as a known gap for a follow-up story/ADR
## review, not fixed unilaterally as part of this story's own scope.
func _reset_all_state() -> void:
	_stop_phase_timers()
	_wave_index = 0
	_round_robin_counter = 0
	_enemies_alive = 0
	_all_spawns_fired = false
	_phase_locked = false
	_wave_clear_fired = false
	_templates_ready = false
	_rebuild_pending_gate = false
	# ADR-0036: reset on every mission launch AND retry (retry_current_mission()
	# re-emits mission_launched on this same Autoload instance without
	# recreating it) -- without this, a retried mission would compound the
	# reward multiplier against the failed attempt's stale value.
	_tarot_reward_multiplier_raw = 1.0
	_tarot_growth_rate_override_applied = false
	_winning_growth_rate_source_card_id = ""
	_tarot_wave_config_override_applied = false


## Resolves this mission's WaveConfig via the injectable _wave_config_loader
## seam (defaults to _default_load_wave_config, assigned in _ready()). Tests
## may override _wave_config_loader directly to return an in-memory WaveConfig
## without touching the filesystem.
func _load_wave_config(mission_id: String) -> WaveConfig:
	return _wave_config_loader.call(mission_id)


## Default WaveConfig resolution strategy (ADR-0009 path convention:
## assets/data/waves/{mission_id}_waves.tres). No `.tres` content exists yet
## for any mission — a missing file (or a file that fails to load as a
## WaveConfig) is handled gracefully: logs an error and returns an empty
## WaveConfig (0 wave_scripts), which _on_mission_launched()'s AC-19 guard
## then routes to immediate MISSION_COMPLETE rather than crashing.
func _default_load_wave_config(mission_id: String) -> WaveConfig:
	var path: String = "res://assets/data/waves/%s_waves.tres" % mission_id
	if not ResourceLoader.exists(path):
		push_error("WaveManager: no WaveConfig found at %s — using an empty fallback (0 wave_scripts)." % path)
		return WaveConfig.new()
	var loaded: Resource = ResourceLoader.load(path)
	if not (loaded is WaveConfig):
		push_error("WaveManager: resource at %s did not load as a WaveConfig — using an empty fallback." % path)
		return WaveConfig.new()
	return loaded as WaveConfig


## AC-41: logs a content error identifying the offending wave index (1-based,
## matching _wave_index's convention) for any WaveScript whose entries' total
## pre_delay sum exceeds _wave_config.wave_time_budget. Logs only — never
## clamps, aborts, or mutates _wave_config; the mission continues normally.
## O(total entries across all waves), run once per mission_launched (not
## per-frame).
func _validate_wave_time_budgets() -> void:
	for i: int in range(_wave_config.wave_scripts.size()):
		var script: WaveScript = _wave_config.wave_scripts[i]
		var total_pre_delay: float = 0.0
		for entry: WaveSpawnEntry in script.entries:
			total_pre_delay += entry.pre_delay
		if total_pre_delay > _wave_config.wave_time_budget:
			push_error("WaveManager: wave index %d's pre_delay sum %.2f exceeds wave_time_budget %.2f" % [
					i + 1, total_pre_delay, _wave_config.wave_time_budget])


func _on_watchdog_stall_timeout() -> void:
	if _phase_locked: return
	if _phase != Phase.WAVE_ACTIVE: return
	GEventBus.wave_stalled.emit(_wave_index, _enemies_alive)


func _on_watchdog_force_timeout() -> void:
	if _phase_locked: return
	if _phase != Phase.WAVE_ACTIVE: return
	# Rule 23 (Story 002): force-clear reports the ACTUAL stuck count, not 0.
	_wave_clear_fired = true
	GEventBus.wave_completed.emit(_wave_index, _enemies_alive, false)
	_transition_to(Phase.MISSION_COMPLETE if _is_final_wave() else Phase.INTERMISSION)

# =============================================================================
# Timer timeout handlers
# =============================================================================

func _on_scout_timer_timeout() -> void:
	if _phase_locked: return
	if _phase != Phase.SCOUT: return
	_transition_to(Phase.PRE_WAVE)


func _on_pre_wave_timer_timeout() -> void:
	if _phase_locked: return
	if _phase != Phase.PRE_WAVE: return
	_transition_to(Phase.WAVE_ACTIVE)


## GDD Formula F2 — see _phase_tick_timer's own doc comment for the PRE_WAVE
## scope extension. Reads time_left off whichever phase-duration timer is
## live for the current phase; a no-op for phases with no duration timer
## (WAVE_ACTIVE, MISSION_COMPLETE, DEFEAT, IDLE) — unreachable in practice
## since _phase_tick_timer is only ever started from _enter_scout()/
## _enter_pre_wave()/_enter_intermission() and stopped by _stop_phase_timers()
## on every other transition, but guarded rather than assumed.
func _on_phase_tick_timer_timeout() -> void:
	var duration_timer: Timer
	match _phase:
		Phase.SCOUT:
			duration_timer = _scout_timer
		Phase.PRE_WAVE:
			duration_timer = _pre_wave_timer
		Phase.INTERMISSION:
			duration_timer = _intermission_timer
		_:
			return
	GEventBus.phase_timer_tick.emit(_phase_name(_phase), maxf(0.0, duration_timer.time_left))


## Story 005: `_check_rebuild_gate()` is called here — once, at the
## INTERMISSION → PRE_WAVE transition — immediately before `_transition_to()`,
## per Rule 22. Wave 1 never reaches this handler (it starts at SCOUT →
## PRE_WAVE), so `_check_rebuild_gate()` is structurally never invoked for
## wave 1.
func _on_intermission_timer_timeout() -> void:
	if _phase_locked: return
	if _phase != Phase.INTERMISSION: return
	_check_rebuild_gate()
	_transition_to(Phase.PRE_WAVE)

# =============================================================================
# EventBus handlers (event handler guard pattern — ADR-0012 Key Interfaces)
# =============================================================================

## Reuses the existing EventBus.player_ready signal (see s3-06 collaboration
## notes) instead of adding a new player_ready_pressed signal — player_ready
## already carries the exact SCOUT/INTERMISSION gate semantics this ADR needs.
func _on_player_ready() -> void:
	if _phase_locked: return
	match _phase:
		Phase.SCOUT:
			_transition_to(Phase.PRE_WAVE)
		Phase.INTERMISSION:
			# Story 005: same _check_rebuild_gate() call as
			# _on_intermission_timer_timeout() above — this is the Ready-button
			# path for the same INTERMISSION → PRE_WAVE transition, so Rule 22
			# must gate here too, not just on the timer-driven path.
			_check_rebuild_gate()
			_transition_to(Phase.PRE_WAVE)
		Phase.PRE_WAVE:
			# EC-8 (wave-manager.md): pressing Ready (relabeled "Skip Countdown"
			# by Mission HUD's planning_cluster.gd during PRE_WAVE, same event)
			# cancels the remaining 10s countdown and immediately transitions to
			# WAVE_ACTIVE. _transition_to()'s own _stop_phase_timers() call
			# handles cancelling _pre_wave_timer — no separate stop() needed
			# here. Real gap found live 2026-08-12: this case was missing
			# entirely, silently falling into the `_` no-op branch below, so
			# the Skip Countdown button did nothing.
			_transition_to(Phase.WAVE_ACTIVE)
		_:
			pass  # silently ignored (WAVE_ACTIVE and all other phases)


## ADR-0036 (tarot.md Rule 7's table): consumes the 3 modifier_type values
## this system owns (tarot_speed_scalar_mult is Monster System's own, not
## consumed here). Fires at SCOUT entry, before PRE_WAVE begins -- well
## before _wave_reward_scalar's first computation at wave 1's WAVE_ACTIVE
## entry, and before difficulty_growth_rate is read anywhere.
func _on_mission_modifier_applied(modifier_type: String, modifier_value: float, source_card_id: String) -> void:
	match modifier_type:
		"tarot_reward_scalar_mult":
			_tarot_reward_multiplier_raw *= modifier_value
		"tarot_difficulty_growth_rate":
			if _tarot_growth_rate_override_applied:
				push_warning("WaveManager: Multiple REPLACE-type Tarot modifiers targeting tarot_difficulty_growth_rate — using slot-index-first card '%s', discarding '%s'." % [_winning_growth_rate_source_card_id, source_card_id])
				return
			_tarot_growth_rate_override_applied = true
			_winning_growth_rate_source_card_id = source_card_id
			# tarot.md Rule 7: clamped to this system's own validated range —
			# a mastery-scaled card can exceed [0.10, 0.25] (e.g. Grim Resolve
			# at Tier 4: 0.25 x 1.75 = 0.4375); _validate_difficulty_growth_rate()
			# only push_errors and only runs once at mission launch, before this
			# override applies, so it never re-validates the overridden value.
			difficulty_growth_rate = clamp(modifier_value, 0.10, 0.25)
		"tarot_wave_config_override":
			if _tarot_wave_config_override_applied:
				return
			_tarot_wave_config_override_applied = true
			# Data-model gap (ADR-0036 Constraints): mission_modifier_applied's
			# payload has no field capable of encoding a target WaveConfig
			# variant identifier (modifier_value is a float; TarotModifierEntry
			# has no string/path field). Every event of this type is therefore
			# unresolvable by construction today — always takes EC-6's
			# documented graceful-degradation path. Not a shortcut: this is the
			# only behavior the current Tarot content schema supports, per
			# tarot.md's own "Vertical Slice scope-flagged" note.
			push_warning("WaveManager: tarot_wave_config_override targeting %s has no valid alternate WaveConfig for mission %s — using mission's default WaveConfig." % [source_card_id, _current_mission_id])
		_:
			pass  # not owned by Wave Manager (tarot_speed_scalar_mult is Monster System's)


## Bug found and fixed during S4-09 (Assemble The Gap Mission Scene) integration
## verification — the first time this codebase ever ran the REAL mission_launched
## -> real PathfindingSystem -> real templates_ready chain together in one
## process (every prior unit/integration test stubbed _wave_config_loader/_grid/
## pathfinding rather than exercising the real end-to-end signal chain).
##
## Confirmed via a live headless run: PathfindingSystem also subscribes to
## mission_phase_changed and, on "SCOUT", synchronously builds route templates
## and emits templates_ready — NESTED inside this class's own
## _transition_to(Phase.SCOUT) call, i.e. while _phase_locked is still true
## (cleared only at the very end of _transition_to, after mission_phase_changed's
## entire subscriber chain — including PathfindingSystem's nested emit — has
## already run). The `if _phase_locked: return` guard below previously discarded
## that real templates_ready emission every single time, so _templates_ready
## never became true and wave 1's _run_spawn_sequence() awaited a signal that had
## already fired and would never fire again — permanently stalling EVERY mission
## at 0 spawned monsters in real gameplay (masked until now because no story
## before this one ever ran the real signal chain end-to-end).
##
## Unlike _check_wave_clear_or_start_watchdog() and _on_hero_died() (which defer
## via call_deferred() when _phase_locked is true because they need to call
## _transition_to() again), this handler only ever sets a boolean flag — there is
## no reentrancy hazard to guard against, and no legitimate call path where
## discarding this signal is correct. The guard is removed outright rather than
## deferred.
func _on_templates_ready(_spawn_count: int, _build_duration_ms: float) -> void:
	_templates_ready = true


## NOTE: deliberately does NOT check _phase_locked (unlike the other handlers
## below). A zero-pre_delay WaveSpawnEntry causes _run_spawn_sequence() to
## emit monster_spawn_requested synchronously from inside _enter_wave_active(),
## which MonsterManager answers synchronously with monster_spawned — all still
## nested inside the original _transition_to(WAVE_ACTIVE) call, while
## _phase_locked is still true. _phase is already correctly WAVE_ACTIVE by
## that point (set before _enter_phase() runs), so the phase check alone is
## sufficient; _phase_locked would incorrectly discard this same-stack cascade.
func _on_monster_spawned(_payload: MonsterSpawnedEvent) -> void:
	if _phase != Phase.WAVE_ACTIVE: return
	_enemies_alive += 1


func _on_monster_died(_payload: MonsterDiedEvent) -> void:
	if _phase_locked: return
	if _phase != Phase.WAVE_ACTIVE: return
	_enemies_alive = maxi(0, _enemies_alive - 1)
	_check_wave_clear_or_start_watchdog()


## Rule 14 / AC-7 / AC-8 / AC-21 (Story 001): hero_died has absolute priority
## over any same-frame wave-clear signal, from ANY phase — including when it
## fires while _phase_locked is already true from an outer in-flight
## _transition_to() call (e.g. the reentrant same-call-stack scenario
## _check_wave_clear_or_start_watchdog() already handles via call_deferred).
## Code review fix (Story 001): calling _transition_to(Phase.DEFEAT) directly
## would be silently dropped by _transition_to()'s own `if _phase_locked:
## return` guard in that reentrant case, with no fallback — contradicting
## "unconditional" priority. Mirrors the same defer-if-locked pattern used by
## _check_wave_clear_or_start_watchdog() so DEFEAT still lands as soon as the
## outer transition releases the lock, instead of being lost entirely.
##
## Once this handler's call (deferred or not) completes, _phase is DEFEAT —
## every other handler's `if _phase != Phase.WAVE_ACTIVE: return` (and, as of
## this story, _check_wave_clear_or_start_watchdog()'s own such guard) then
## correctly discards any wave-clear signal that arrives afterward, giving
## DEFEAT structural priority (see _check_wave_clear_or_start_watchdog()'s
## doc comment for the specific gap this closes).
func _on_hero_died() -> void:
	if _phase_locked:
		_transition_to.call_deferred(Phase.DEFEAT)
	else:
		_transition_to(Phase.DEFEAT)

# =============================================================================
# Story 003 (boss-fastpaths-wave-clear-robustness): BOSS death / BOSS breach
# fast-paths, plus the monsters_died_batch consumer.
# =============================================================================

## Rule 20 / EC-5b / AC-32 / AC-34: two sequential guards BEFORE any
## wave-clear logic — phase-equality (AC-32: a stray boss_died received after
## the phase has already advanced to INTERMISSION/elsewhere is a no-op), then
## the _wave_clear_fired latch (AC-34: a same-frame stray boss_died arriving
## after a BOSS breach already committed to clearing the wave, while _phase is
## still nominally WAVE_ACTIVE, is also a no-op).
##
## _phase_locked drop-not-defer (deviation flagged, investigated, and
## confirmed safe — not silently copied from the story's pseudocode without
## checking): unlike _check_wave_clear_or_start_watchdog() and _on_hero_died()
## (both of which DO defer via call_deferred() when _phase_locked is true),
## this handler drops. boss_died is only ever emitted from
## MonsterManager._emit_death(), itself only called from
## MonsterManager._pass1_damage() inside MonsterManager._physics_process() —
## a scene-tree physics callback that is never nested inside this class's
## _transition_to() call stack. _phase_locked is only ever true for the
## duration of a single synchronous _transition_to() call, and the only
## production path that can reenter that same call stack is
## _run_spawn_sequence()'s zero-pre_delay synchronous monster_spawn_requested
## → MonsterManager.spawn_monster() → synchronous monster_spawned cascade
## (see _on_monster_spawned()'s doc comment) — which only reaches as far as
## *spawning* a monster, never as far as damage resolution or goal-arrival,
## both of which require a later _physics_process tick. So boss_died /
## monster_breached can never actually fire while _phase_locked is true in
## production, matching the existing (already-shipped) _on_monster_died()'s
## own drop-not-defer pattern for the exact same structural reason — this is
## NOT the same reentrancy hazard _check_wave_clear_or_start_watchdog() (called
## directly from _run_spawn_sequence()'s own synchronous tail) and
## _on_hero_died() (given unconditional priority "from ANY phase" by design)
## both guard against.
##
## Adjacent hazard (found during code review, now closed — not by this
## handler, but worth noting here since it's easy to assume this handler's
## own analysis covers it): _wave_completed's own emission below can
## synchronously re-enter WaveManager via MonsterManager._on_wave_completed()
## force-flushing remaining active_monsters — including a synchronous
## monster_died → _on_monster_died() → _check_wave_clear_or_start_watchdog()
## call, all before this handler ever reaches its own _transition_to() line.
## That reentrant path is now protected by _check_wave_clear_or_start_watchdog()
## itself checking _wave_clear_fired (see that function's own code-review-fix
## comment) — the _wave_clear_fired = true set on the line below is what makes
## that protection effective.
func _on_boss_died(_entity_id: int, _monster_id: StringName, _wave_index_param: int, _cause: String) -> void:
	if _phase_locked: return
	if _phase != Phase.WAVE_ACTIVE: return
	if _wave_clear_fired: return
	_wave_clear_fired = true
	_spawn_active = false  # EC-3: cancel remaining spawn entries synchronously — do not fire them
	GEventBus.wave_completed.emit(_wave_index, 0, false)
	var next_phase: Phase = Phase.MISSION_COMPLETE if _is_final_wave() else Phase.INTERMISSION
	_transition_to(next_phase)


## Rule 21 / AC-16 / AC-24: tier 2 (BOSS) breach is the wave-clear fast-path —
## was_boss_breached: true, the ONE path where this flag is true. tier 1
## (ELITE) breach, or any other tier value, is a standard -1 decrement that
## falls through to the same handling _on_monster_died() already uses.
##
## _phase_locked drop-not-defer: see _on_boss_died()'s doc comment above — the
## same structural reasoning applies here (monster_breached is only ever
## emitted from MonsterManager._pass3_movement(), also only reachable from
## _physics_process(), never from _transition_to()'s locked window).
func _on_monster_breached(_entity_id: int, _monster_id: StringName, tier: int) -> void:
	if _phase_locked: return
	if _phase != Phase.WAVE_ACTIVE: return
	if tier == 2:
		if _wave_clear_fired: return
		_wave_clear_fired = true
		GEventBus.wave_completed.emit(_wave_index, 0, true)  # was_boss_breached: true
		var next_phase: Phase = Phase.MISSION_COMPLETE if _is_final_wave() else Phase.INTERMISSION
		_transition_to(next_phase)
	else:
		_enemies_alive = maxi(0, _enemies_alive - 1)
		_check_wave_clear_or_start_watchdog()


## AC-28 / AC-37: batch decrement with an invalid-count guard. WaveManager
## does not accumulate anything itself here — payloads.size() is read once
## (already batched upstream by whichever system emits monsters_died_batch),
## so this stays O(1) per event with no iteration added (Control Manifest
## Performance note).
func _on_monsters_died_batch(payloads: Array[MonsterDiedEvent]) -> void:
	if _phase_locked: return
	if _phase != Phase.WAVE_ACTIVE: return
	var count: int = payloads.size()
	if count <= 0:
		push_warning("WaveManager: monsters_died_batch received with invalid count %d — discarded." % count)
		return
	_enemies_alive = maxi(0, _enemies_alive - count)
	_check_wave_clear_or_start_watchdog()
