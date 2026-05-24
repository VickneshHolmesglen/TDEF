# ADR-0012: Wave Manager FSM Architecture

## Status
Proposed

## Date
2026-05-24

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (GDScript FSM, Timer nodes, coroutines) |
| **Knowledge Risk** | LOW — all constructs (enum, match, Timer, await) stable since Godot 4.0; no physics/rendering/navigation APIs used |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm Timer.wait_time assignment and Timer.start() still behave identically in 4.6.2 (no documented changes); confirm `await get_tree().create_timer(N).timeout` still resolves correctly when SceneTree is paused mid-mission. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus — WaveManager subscribes to 10+ signals); ADR-0002 (Autoload structure — WaveManager added at position 7; requires ADR-0002 revision); ADR-0004 (Pathfinding strategy — `templates_ready` event and `PathfindingSystem.is_rebuild_pending()` are external APIs this FSM gates on); ADR-0009 (Resource data model — WaveConfig, WaveScript, WaveSpawnEntry are the data inputs to this FSM) |
| **Enables** | Wave Manager implementation stories; Monster System integration (receives `monster_spawn_requested`); Mission HUD phase-driven display (receives all phase signals) |
| **Blocks** | Wave Manager implementation story cannot begin until this ADR is Accepted |
| **Ordering Note** | ADR-0002 must be revised to add WaveManager at boot position 7 (after SceneManager at 6) before any implementation begins. This is the only new Autoload added by this ADR. |

## Context

### Problem Statement
The Wave Manager GDD specifies a 7-state mission phase lifecycle (IDLE → SCOUT →
PRE_WAVE → WAVE_ACTIVE → INTERMISSION → MISSION_COMPLETE / DEFEAT) with three
independent timer domains, a coroutine-based spawn sequencer with two pathfinding
gates, and a `_phase_locked` latch for DEFEAT priority. An architectural decision is
needed on how to implement this FSM in GDScript — specifically: the state
representation pattern, the timer management approach, and the coroutine
cancellation model.

### Constraints
- GDScript is the sole implementation language (CLAUDE.md)
- The FSM must be unit-testable with mocked timers — timer callbacks must be
  invokable directly without Engine.time_scale manipulation (wave-manager.md AC
  timer mocking note)
- Coroutine await boundaries must guard against stale resumption (ADR-0007
  `is_instance_valid` pattern applies to all await boundaries in this system)
- All cross-system communication must use EventBus (ADR-0001), with two documented
  exceptions: `Grid.get_spawn_cells()` once at `mission_launched`, and
  `PathfindingSystem.is_rebuild_pending()` at INTERMISSION→PRE_WAVE

### Requirements
- Must implement the exact 7-state / 8-transition FSM from wave-manager.md Rule 7
- Must support direct timer callback invocation for unit testing (AC-4, AC-6,
  AC-7, AC-14, AC-15, AC-18, AC-22, AC-25, AC-26, AC-31, AC-32)
- Must implement spawn coroutine with two pathfinding gates:
  wave 1 gates on `_templates_ready`; waves 2+ gate on `_rebuild_pending_gate`
- Must implement `_phase_locked` latch ensuring DEFEAT priority over wave-clear
  when both arrive in the same frame (Rule 14, EC-4)
- WaveManager must be a new Autoload at boot position 7

## Decision

### Chosen Approach: `enum Phase` + `match` + Scene-Tree Timer Nodes + GDScript Spawn Coroutine

**State representation**: A single `enum Phase` with 7 members (IDLE, SCOUT, PRE_WAVE,
WAVE_ACTIVE, INTERMISSION, MISSION_COMPLETE, DEFEAT). All state transitions go through a
single `_transition_to(new_phase: Phase)` method that enforces the `_phase_locked`
check, stops the appropriate timers, assigns `_phase`, emits `mission_phase_changed`,
and calls the phase entry method `_enter_[state]()`. Direct assignment to `_phase` is
forbidden outside `_transition_to` — the single entry point ensures invariants
(timer stop, signal emission) are always enforced.

**Timer management**: Five scene-tree `Timer` nodes added as children of WaveManager in
`_ready()`. Each Timer has `one_shot = true` and its `timeout` signal connected to a
named callback. This makes callbacks directly invokable in tests without Engine.time_scale.

| Timer node | Connected to | Fires when |
|------------|-------------|------------|
| `_scout_timer` | `_on_scout_timer_timeout()` | SCOUT phase expires (60s default) |
| `_pre_wave_timer` | `_on_pre_wave_timer_timeout()` | PRE_WAVE countdown expires (10s default) |
| `_intermission_timer` | `_on_intermission_timer_timeout()` | INTERMISSION expires (30s default) |
| `_watchdog_stall_timer` | `_on_watchdog_stall_timeout()` | 30s stall threshold — emits `wave_stalled` |
| `_watchdog_force_timer` | `_on_watchdog_force_timeout()` | 60s force-clear threshold |

The stall and force timers are independent (stall fires at 30s, force at 60s from the
same start point — both started simultaneously when `_all_spawns_fired = true` and
`_enemies_alive > 0`).

**Spawn coroutine**: A single `_run_spawn_sequence()` async function started at
WAVE_ACTIVE entry. Cancellation is via `_spawn_active: bool` — set `false` to cancel
before the coroutine's next `await` boundary. Every `await` in the coroutine is followed
by the three-guard sequence: `is_instance_valid(self)`, `_spawn_active`, and
`_phase == Phase.WAVE_ACTIVE`. Failing any guard aborts without emitting further spawns.

**Pathfinding gate logic** (per GDD Rule 22):
- Wave 1: coroutine checks `_templates_ready` at start; if `false`, awaits
  `EventBus.templates_ready` before firing first `monster_spawn_requested`.
- Waves 2+: at INTERMISSION→PRE_WAVE transition, calls
  `PathfindingSystem.is_rebuild_pending()` once; if `true`, sets
  `_rebuild_pending_gate = true` and subscribes to `EventBus.path_invalidated`
  (disconnects immediately on gate release). The coroutine checks `_rebuild_pending_gate`
  at its start.

**Ready button interface**: Mission HUD emits `EventBus.player_ready_pressed()` (no-arg
signal; must be added to EventBus GDD signal catalogue and EventBus.gd before
implementation). WaveManager subscribes in `_ready()`. The `_on_player_ready_pressed()`
handler is a match on `_phase` — silently ignored in WAVE_ACTIVE and terminal states.

### Architecture Diagram

```
                ┌───────────────────────────────────────────────────┐
                │                  WaveManager                      │
                │           (Autoload — boot position 7)            │
                │                                                   │
                │  _phase: Phase ◄── _transition_to(new_phase)      │
                │  _phase_locked: bool                              │
                │                                                   │
                │  Timers (5× scene-tree nodes):                    │
                │   _scout_timer        ──► _on_scout_timer_timeout()        │
                │   _pre_wave_timer     ──► _on_pre_wave_timer_timeout()     │
                │   _intermission_timer ──► _on_intermission_timer_timeout() │
                │   _watchdog_stall_timer ► _on_watchdog_stall_timeout()     │
                │   _watchdog_force_timer ► _on_watchdog_force_timeout()     │
                │                                                   │
                │  Spawn coroutine:                                 │
                │   _run_spawn_sequence(entries) ◄── WAVE_ACTIVE entry      │
                │   _spawn_active: bool  (cancellation flag)        │
                └───────────────────────────────────────────────────┘

FSM Transitions:
  IDLE ──[mission_launched]──► SCOUT ──[60s / Ready]──► PRE_WAVE ──[10s / Ready]──► WAVE_ACTIVE
                                                                                          │    │
                                                    INTERMISSION ◄──[wave cleared, non-final]  │
                                                    MISSION_COMPLETE ◄──[wave cleared, final]   │
                                                    DEFEAT ◄──[hero_died, ANY state] ◄──────────┘

Phase-lock: _phase_locked = true on DEFEAT → all handlers discard events
```

### Key Interfaces

```gdscript
# ── State enum ────────────────────────────────────────────────────────────────
enum Phase {
    IDLE, SCOUT, PRE_WAVE, WAVE_ACTIVE,
    INTERMISSION, MISSION_COMPLETE, DEFEAT
}

# ── Private state (no public properties — observable via EventBus only) ───────
var _phase: Phase = Phase.IDLE
var _phase_locked: bool = false
var _wave_index: int = 0           # 0 = no wave started; 1–N = active wave
var _round_robin_counter: int = 0  # resets each WAVE_ACTIVE entry
var _enemies_alive: int = 0        # clamped >= 0
var _all_spawns_fired: bool = false
var _wave_clear_fired: bool = false
var _templates_ready: bool = false
var _rebuild_pending_gate: bool = false
var _spawn_active: bool = false    # set false to cancel spawn coroutine

# ── Single transition entry point ─────────────────────────────────────────────
func _transition_to(new_phase: Phase) -> void:
    # 1. Enforce _phase_locked (only DEFEAT sets it; DEFEAT itself bypasses check)
    # 2. Stop current-phase timers
    # 3. _phase = new_phase
    # 4. EventBus.mission_phase_changed.emit(Phase.keys()[old], Phase.keys()[new])
    # 5. _enter_[new_phase]()

# ── Spawn coroutine — three-guard pattern at every await ──────────────────────
func _run_spawn_sequence(entries: Array[WaveSpawnEntry]) -> void:
    _spawn_active = true
    # wave-index gate (wave 1 only):
    if _wave_index == 1 and not _templates_ready:
        await EventBus.templates_ready
        if not is_instance_valid(self): return
        if not _spawn_active: return
        if _phase != Phase.WAVE_ACTIVE: return
    # wave 2+ gate:
    if _wave_index > 1 and _rebuild_pending_gate:
        await EventBus.path_invalidated
        if not is_instance_valid(self): return
        if not _spawn_active: return
        if _phase != Phase.WAVE_ACTIVE: return
        _rebuild_pending_gate = false
        EventBus.path_invalidated.disconnect(_on_path_invalidated)
    for entry in entries:
        if not _spawn_active: return
        if entry.pre_delay > 0.0:
            await get_tree().create_timer(entry.pre_delay).timeout
            if not is_instance_valid(self): return
            if not _spawn_active: return
            if _phase != Phase.WAVE_ACTIVE: return
        _emit_spawn(entry)
    _all_spawns_fired = true
    _check_wave_clear()

# ── Event handler guard pattern (applies to ALL EventBus handlers) ────────────
func _on_monster_died() -> void:
    if _phase_locked: return          # DEFEAT has fired — discard all events
    if _phase != Phase.WAVE_ACTIVE: return
    _enemies_alive = maxi(0, _enemies_alive - 1)
    _check_wave_clear()
```

## Alternatives Considered

### Alternative 1: State Class Hierarchy (Strategy / State Pattern)
- **Description**: One GDScript class per phase (`ScoutState.gd`, `WaveActiveState.gd`, etc.). WaveManager holds a reference to the active state class and delegates all logic to it.
- **Pros**: Each state class is independently testable; clear separation of per-state logic.
- **Cons**: GDScript coroutines cannot span class boundaries — the spawn coroutine, which sleeps across frame boundaries, would need to live in WaveManager anyway, making WaveActive state class a thin wrapper. 7 × boilerplate class files for 7 states. No GDScript-idiomatic advantage over match.
- **Rejection Reason**: The spawn coroutine is the most complex part of WaveManager; it cannot be cleanly isolated in a state class. The remaining per-state logic (timer start/stop, flag reset) is simple enough that match + private methods is clearer and more direct.

### Alternative 2: `_process(delta)` Timer Accumulation
- **Description**: No Timer nodes. Instead, `_elapsed: float` accumulated in `_process(delta)`. Phase transitions fire when `_elapsed >= phase_duration`.
- **Pros**: No scene-tree node proliferation; single `_process` controls all timing.
- **Cons**: Unit tests cannot inject timer expirations directly — tests must advance `_elapsed` manually or use Engine.time_scale, which is explicitly banned by the wave-manager.md AC timer mocking note. Timer nodes are testable via direct callback invocation.
- **Rejection Reason**: The unit test strategy for ACs 4, 6, 7, 14–16, 18, 22, 25–26, 31–32 requires direct callback invocation (`_on_scout_timer_timeout()`). This is only possible with Timer node + signal approach.

## Consequences

### Positive
- All timer callbacks are directly invokable in GUT tests — no Engine.time_scale required
- Single `_transition_to()` entry point guarantees timer-stop and signal-emit on every transition
- Spawn coroutine is self-contained and cancellable with O(1) flag check
- `_phase_locked` as first check in all handlers provides structural DEFEAT priority
- Clear state enum maps 1:1 to GDD's 7 states — zero translation cost between spec and code

### Negative
- 5 scene-tree Timer nodes add minor scene setup boilerplate in WaveManager's `_ready()`
- Spawn coroutine cancel is non-immediate — it takes effect at the next await boundary
  (up to `pre_delay` seconds, max 30s per WaveSpawnEntry). BOSS-died fast-path (EC-3)
  must set `_spawn_active = false` synchronously before emitting `wave_completed`.
- `create_timer()` timers are not pausable via Timer node `process_mode` — if the game
  is paused mid-wave, `create_timer` timers continue. Mitigation: use Timer nodes
  for all phase timers (their `process_mode` is configurable); reserve `create_timer`
  only for spawn `pre_delay` where pause behaviour is acceptable.

### Risks
- **Stale coroutine resume**: A coroutine that resumes after phase change could emit
  `monster_spawn_requested` in a non-WAVE_ACTIVE phase. Mitigation: phase-check guard
  after every `await` boundary (three-guard pattern documented in Key Interfaces).
- **Double `wave_clear_fired`**: Two clear paths arriving in the same frame (e.g.,
  `boss_died` and `monster_died` at `_enemies_alive == 1`). Mitigation: `_wave_clear_fired`
  latch checked before emitting `wave_completed` on any clear path (GDD Rules 20–21, EC-5b).
- **ADR-0002 revision required before coding**: WaveManager boot position 7 must be
  committed before implementation; if omitted, WaveManager is not in the Autoload list
  and will not be found by dependent systems. This is a build invariant, not a runtime check.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| wave-manager.md Rule 7 | 7-state phase lifecycle FSM (TR-wave-001) | `enum Phase` defines the 7 states; `_transition_to()` enforces the allowed transition graph |
| wave-manager.md Rule 14 + EC-4 | `hero_died` = DEFEAT priority over same-frame wave-clear | `_phase_locked = true` set as first operation in `_on_hero_died()`; all other handlers check `_phase_locked` as their first operation |
| wave-manager.md Rules 20–21 + EC-5b | BOSS breach = wave-clear (TR-wave-003); stray `boss_died` after phase advance is no-op | `_on_boss_died()` applies two sequential guards: phase-equality check, then `_wave_clear_fired` latch |
| wave-manager.md Rule 22 | `templates_ready` gate (wave 1); `is_rebuild_pending()` gate (waves 2+) | Spawn coroutine checks `_templates_ready` (wave 1) or `_rebuild_pending_gate` (waves 2+) before first `monster_spawn_requested`; gates are mutually exclusive per wave |
| wave-manager.md Rule 23 | Wave-stuck watchdog: `wave_stalled` at 30s, force-clear at 60s (TR-wave-005) | `_watchdog_stall_timer` (30s) and `_watchdog_force_timer` (60s) started when `_all_spawns_fired = true` and `_enemies_alive > 0` |
| wave-manager.md F1 | `wave_reward_scalar = 1.0 × (1 + r) ^ (w - 1)` (TR-wave-006) | Computed in `_enter_wave_active()` from `_wave_index` and `WaveConfig.difficulty_growth_rate`; passed in `wave_started.wave_difficulty` and `monster_spawn_requested.wave_reward_scalar`; must not be applied to HP/speed |
| wave-manager.md Rule 15c | `is_penultimate_wave` flag in spawn payload (TR-wave-007) | Computed inline: `_wave_index == wave_scripts.size() - 1 AND wave_scripts.size() >= 5`; always `false` for sub-5-wave missions |

## Performance Implications
- **CPU**: O(1) per phase transition (enum assignment + EventBus emit). O(entries_count) per wave during spawn sequencing (one coroutine resume per entry). EventBus handler overhead for 10+ subscriptions: within ADR-0001's 1.667 ms budget.
- **Memory**: 5 Timer nodes (~200 B each), 8 state variables (int/bool/float), one `Array[Vector2i]` for `_spawn_cells` (loaded per-mission, freed at MISSION_COMPLETE/DEFEAT reset). Total: negligible.
- **Load Time**: No significant impact. WaveManager Autoload initializes with all timers stopped, `_phase = IDLE`.
- **Network**: Not applicable.

## Migration Plan
WaveManager is a new Autoload — no existing code migrates. Three prerequisite changes:

1. **Update ADR-0002** (`adr-0002-scene-autoload-structure.md`): Add `WaveManager` at
   boot position 7. Rationale: WaveManager subscribes to EventBus (position 1) and reads
   from Grid (position 3), Pathfinding (position 4), and GameDataRegistry (position 5).
   Must boot after all upstream Autoloads. Must boot before any mission scene loads.
2. **Update `docs/registry/architecture.yaml`** `autoload_boot_order` entry to reflect
   position 7.
3. **Add `player_ready_pressed` signal** to EventBus GDD signal catalogue and EventBus.gd
   before Wave Manager implementation begins. This is the only new EventBus signal
   introduced by this ADR.

## Validation Criteria
All 41 Acceptance Criteria in wave-manager.md (AC-1 through AC-41). Key groupings:
- Unit tests with directly invoked timer callbacks (no Engine.time_scale):
  AC-4, AC-6, AC-7, AC-14, AC-15, AC-16, AC-18, AC-22, AC-25, AC-26, AC-31, AC-32, AC-37, AC-38
- Integration test (full mission traversal with mocked Monster System): AC-23
- All 8 EC-9 state reset fields verified simultaneously: AC-20
- `_phase_locked` DEFEAT priority across 3 competing-event variants: AC-8
- `_wave_clear_fired` latch same-frame race: AC-34

## Related Decisions
- ADR-0001: EventBus Architecture (WaveManager's primary communication channel)
- ADR-0002: Scene and Autoload Structure (WaveManager added at boot position 7)
- ADR-0004: Pathfinding Strategy (`templates_ready` gate; `is_rebuild_pending()` API)
- ADR-0007: Damage Pipeline (`is_instance_valid()` guard pattern inherited here)
- ADR-0009: Resource Data Model (WaveConfig, WaveScript, WaveSpawnEntry)
