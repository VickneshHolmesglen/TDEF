# S3-06 — Wave Manager Phase 1

**Story ID**: S3-06
**Epic**: Core
**Layer**: Core
**Type**: Integration
**Owner**: godot-gdscript-specialist
**Sprint**: 3
**Estimate**: 2.0 days
**Status**: Complete
**Manifest Version**: 2026-05-16

## TR Coverage

Corrected against `docs/architecture/tr-registry.yaml` — the original table below
mislabeled several rows against the wrong section. See note below the table.

| TR-ID | Requirement |
|-------|-------------|
| TR-wave-001 | 7-state phase lifecycle FSM — covers Phase FSM Transitions (AC-1–4) |
| TR-wave-004 | `templates_ready` gate before first spawn — covers `templates_ready` Gate (AC-11–12) |
| TR-wave-005 | Wave-stuck watchdog (30s stalled / 60s force-clear) — covers Watchdog Timers (AC-13–15) |

**Out of scope for this story** (deferred to a later story): `TR-wave-002`
(`WaveConfig`/`WaveScript`/`WaveSpawnEntry` Resources — ADR-0009 territory),
`TR-wave-003` (BOSS breach = wave-clear), `TR-wave-006` (`wave_reward_scalar`
semantic contract), `TR-wave-007` (Penultimate-wave rule). These were previously
listed incorrectly against the Timer Nodes / Watchdog / `player_ready_pressed`
rows above and have been removed from this story's coverage table.

## ADR Governing Implementation

`docs/architecture/adr-0012-wave-manager-fsm.md` (Accepted)

**ADR Decision Summary**: WaveManager uses a single `enum Phase` with 7 members. All
transitions go through `_transition_to(new_phase)` which enforces `_phase_locked`,
stops timers, assigns `_phase`, emits `mission_phase_changed`, and calls the phase
entry method. Direct `_phase` assignment outside `_transition_to` is forbidden.
5 scene-tree `Timer` nodes (one-shot, timeout-connected). Spawn coroutine uses
3-guard sequence after every `await`.

**Engine**: Godot 4.6.2 | **Risk**: LOW — enum, match, Timer, await all stable since Godot 4.0

## Dependencies

- S2-01 EventBus Autoload — Complete
- S3-02 Monster System — **Must be Complete** (WaveManager emits `monster_spawn_requested`)

## Files to Create

- `src/core/wave_manager/wave_manager.gd` — WaveManager autoload
- `tests/unit/wave_manager/wave_manager_fsm_test.gd`
- `tests/unit/wave_manager/wave_manager_spawn_test.gd`
- `tests/integration/wave_manager/wave_manager_spawn_integration_test.gd`

## Acceptance Criteria

### Phase FSM Transitions
- [ ] AC-1: `_transition_to(WAVE_ACTIVE)` from SCOUT → `mission_phase_changed("SCOUT", "WAVE_ACTIVE", delta)` fires on EventBus
- [ ] AC-2: `_transition_to(INTERMISSION)` from WAVE_ACTIVE → correct signal fires; `_scout_timer` and spawn coroutine cancelled
- [ ] AC-3: Direct assignment to `_phase` outside `_transition_to` is NOT possible (private; verified by code inspection)
- [ ] AC-4: `_phase_locked = true` during transition → second call to `_transition_to` is silently ignored

### Timer Nodes
- [ ] AC-5: 5 Timer child nodes created in `_ready()`: `_scout_timer`, `_pre_wave_timer`, `_intermission_timer`, `_watchdog_stall_timer`, `_watchdog_force_timer`
- [ ] AC-6: Each Timer has `one_shot = true`; timeout signals connected to named callbacks
- [ ] AC-7: Timers can be triggered by calling `timer.emit_signal("timeout")` in tests (no Engine.time_scale manipulation needed)

### Spawn Coroutine — 3-Guard Pattern
- [ ] AC-8: Each `await` in `_run_spawn_sequence` is followed immediately by 3 guards:
  `is_instance_valid(self)`, `_spawn_active`, `_phase == Phase.WAVE_ACTIVE`
- [ ] AC-9: If `_spawn_active = false` is set externally, coroutine aborts at next `await` boundary without emitting further `monster_spawn_requested` events
- [ ] AC-10: Spawn coroutine fires `monster_spawn_requested` N times per wave config; interval between spawns matches config value

### `templates_ready` Gate (Wave 1)
- [ ] AC-11: On Wave 1 start, if `_templates_ready = false`, coroutine awaits `EventBus.templates_ready` before emitting first spawn
- [ ] AC-12: If `templates_ready` fires after coroutine is already waiting, first spawn fires immediately (no extra frame delay)

### Watchdog Timers
- [ ] AC-13: When `_all_spawns_fired = true` and `_enemies_alive > 0`: `_watchdog_stall_timer` starts (30s)
- [ ] AC-14: `_watchdog_stall_timer` fires → `wave_stalled` emitted on EventBus
- [ ] AC-15: `_watchdog_force_timer` fires at 60s → force transition to INTERMISSION regardless of `_enemies_alive`

### Player Ready Interface
- [ ] AC-16: `EventBus.player_ready_pressed` subscribed in `_ready()`
- [ ] AC-17: Received during SCOUT → begins transition to PRE_WAVE
- [ ] AC-18: Received during WAVE_ACTIVE → silently ignored (no crash, no state change)

### EventBus Signal Wiring
- [ ] AC-19: `mission_phase_changed` payload includes: previous phase name, new phase name, wave_index
- [ ] AC-20: `monster_died` subscription decrements `_enemies_alive`; when count reaches 0 → transition to INTERMISSION

## Implementation Notes (from ADR-0012)

### 7-Phase Enum

```gdscript
enum Phase {
    IDLE,
    SCOUT,
    PRE_WAVE,
    WAVE_ACTIVE,
    INTERMISSION,
    MISSION_COMPLETE,
    DEFEAT
}
```

### Transition Method

```gdscript
func _transition_to(new_phase: Phase) -> void:
    if _phase_locked:
        return
    _phase_locked = true
    _stop_phase_timers()
    _phase = new_phase
    EventBus.mission_phase_changed.emit(_phase_name(_phase), _phase_name(new_phase), _wave_index)
    _enter_phase(new_phase)
    _phase_locked = false
```

### Spawn Coroutine — 3-Guard Pattern

```gdscript
func _run_spawn_sequence() -> void:
    if not _templates_ready:
        await EventBus.templates_ready
        if not is_instance_valid(self): return
        if not _spawn_active: return
        if _phase != Phase.WAVE_ACTIVE: return

    for entry in _wave_config.spawn_entries:
        await get_tree().create_timer(entry.delay_sec).timeout
        if not is_instance_valid(self): return
        if not _spawn_active: return
        if _phase != Phase.WAVE_ACTIVE: return
        EventBus.monster_spawn_requested.emit(entry.to_payload(_wave_index))
    _all_spawns_fired = true
    _start_watchdog_timers()
```

### Timer Setup in `_ready()`

```gdscript
func _ready() -> void:
    _scout_timer = _make_timer("_scout_timer", _on_scout_timer_timeout)
    _pre_wave_timer = _make_timer("_pre_wave_timer", _on_pre_wave_timer_timeout)
    _intermission_timer = _make_timer("_intermission_timer", _on_intermission_timer_timeout)
    _watchdog_stall_timer = _make_timer("_watchdog_stall_timer", _on_watchdog_stall_timeout)
    _watchdog_force_timer = _make_timer("_watchdog_force_timer", _on_watchdog_force_timeout)

func _make_timer(node_name: String, callback: Callable) -> Timer:
    var t := Timer.new()
    t.name = node_name
    t.one_shot = true
    t.timeout.connect(callback)
    add_child(t)
    return t
```

### Note on `player_ready_pressed`

`EventBus.player_ready_pressed` is a no-arg signal. It must be added to
`EventBus.gd` signal catalogue before implementation. Check `src/foundation/event_bus/`
for the signal list and add if missing.

## Out of Scope

- Wave 2+ Pathfinding rebuild gate (`_rebuild_pending_gate` logic — Sprint 4)
- Multi-lane spawn scripts (MVP is single-lane; extend in Sprint 4)
- Phase: MISSION_COMPLETE and DEFEAT transitions (no win/lose condition yet in Sprint 3)
- WaveConfig resource design (author a minimal struct sufficient for single-lane spawn)

## QA Test Cases

- **AC-1**: SCOUT → WAVE_ACTIVE transition
  - Given: WaveManager in SCOUT phase
  - When: `_transition_to(Phase.WAVE_ACTIVE)` called
  - Then: `mission_phase_changed` fires with previous="SCOUT", new="WAVE_ACTIVE"
  - Edge cases: called twice rapidly → second call blocked by `_phase_locked`

- **AC-8**: 3-guard pattern in spawn coroutine
  - Given: WaveManager in WAVE_ACTIVE with active spawn coroutine
  - When: `_spawn_active = false` set between two awaits
  - Then: no further `monster_spawn_requested` emitted after the next await completes
  - Edge cases: node freed during coroutine → `is_instance_valid` guard fires first

- **AC-11**: `templates_ready` gate
  - Given: WaveManager starts Wave 1 with `_templates_ready = false`
  - When: coroutine begins
  - Then: no `monster_spawn_requested` emitted until `EventBus.templates_ready` fires
  - Edge cases: `templates_ready` fires before coroutine starts → no wait needed

- **AC-15**: Watchdog force-clear
  - Given: all spawns fired, `_enemies_alive = 1`, 60 seconds pass
  - When: `_watchdog_force_timer` fires
  - Then: transition to INTERMISSION regardless of `_enemies_alive` count

- **AC-18**: `player_ready_pressed` during WAVE_ACTIVE
  - Given: WaveManager in WAVE_ACTIVE
  - When: `EventBus.player_ready_pressed` fires
  - Then: no state change; no crash; `_phase` remains WAVE_ACTIVE

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/wave_manager/wave_manager_fsm_test.gd` — AC-1 through AC-7, AC-13 through AC-20
- `tests/unit/wave_manager/wave_manager_spawn_test.gd` — AC-8 through AC-12
- `tests/integration/wave_manager/wave_manager_spawn_integration_test.gd` — full spawn cycle with MonsterManager

**Status**: [ ] Not yet created

## Dependencies

- Depends on: S3-02 (Monster System — Complete)
- Unlocks: Sprint 4 Hero + Wave Manager integration ("The Gap" VS scene)

## Completion Notes
**Completed**: 2026-07-03
**Criteria**: 20/20 passing (AC-1 through AC-20), plus one bonus regression test for a reentrancy bug found during code review
**Deviations**: Advisory only (no blocking) — file path governed by ADR-0002 revision (`src/gameplay/wave_manager.gd`, not the story's stated `src/core/wave_manager/`); `player_ready` signal reused instead of adding a new `player_ready_pressed`; AC-19's `mission_phase_changed` payload wording was imprecise (implementation matches the real EventBus signal: previous_phase, new_phase, timestamp — no wave_index); `control-manifest.md` content is stale re: WaveManager-as-Autoload (ADR-0012 supersedes it); `@export` timer durations are hardcoded defaults pending the deferred WaveConfig Resource model; WaveManager registered as the 5th Autoload, not 7th, tracked as TD-wave-001 (GameDataRegistry/SceneManager don't exist yet)
**Test Evidence**: Integration — `tests/unit/wave_manager/wave_manager_fsm_test.gd` (17 tests), `tests/unit/wave_manager/wave_manager_spawn_test.gd` (6 tests), `tests/integration/wave_manager/wave_manager_spawn_integration_test.gd` (3 tests) — 26/26 passing, 0 errors, 0 failures
**Code Review**: Complete — one BLOCKING reentrancy deadlock found and fixed (`_check_wave_clear_or_start_watchdog()` could silently drop a nested `_transition_to` call while `_phase_locked` was held); re-verified after fix
**Tech debt logged**: TD-monster-003 (pre-existing MonsterManager orphan-node gap, unrelated to this story), TD-wave-001 (Autoload boot-order placeholder)
