# Story 005: Waves 2+ Pathfinding Rebuild Gate

> **Epic**: Wave Manager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-05-16
> **Estimate**: 4h

## Context

**GDD**: `design/gdd/wave-manager.md`
**Requirement**: `TR-wave-008` (previously mis-tracked under `TR-wave-004`) — **registry mismatch RESOLVED (2026-07-07)**: `TR-wave-004`'s text ("templates_ready gate before first spawn") describes only the wave-1 gate; this story's actual requirement (the waves-2+ rebuild-pending gate) is now registered under its own dedicated `TR-wave-008` in `docs/architecture/tr-registry.yaml`.
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Wave Manager FSM Architecture + ADR-0004: Pathfinding Strategy
**ADR Decision Summary**: Wave 1 gates the first spawn on `templates_ready`. Waves 2+ instead check `PathfindingSystem.is_rebuild_pending()` once at the INTERMISSION→PRE_WAVE transition; if `true`, the spawn coroutine awaits `path_invalidated` before its first spawn of that wave. The two gates are mutually exclusive per wave — never both checked in the same wave.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `await EventBus.path_invalidated` and the three-guard pattern (`is_instance_valid`, `_spawn_active`, phase check) after the await — no post-cutoff API risk, matches the pattern already used for the wave-1 `templates_ready` gate in the existing code.

**Verified against the actual codebase (2026-07-04)**: `wave_manager.gd`'s own class doc comment explicitly lists this as Out of Scope: `"Wave 2+ pathfinding rebuild gate (_rebuild_pending_gate) — Sprint 4"`. Confirmed via grep — no `_rebuild_pending_gate` field, no `is_rebuild_pending()` call, no `path_invalidated` subscription anywhere. The wave-1 `templates_ready` gate (`_templates_ready` field, `_on_templates_ready()` handler) IS correctly implemented and should be used as the direct structural template for this story's waves-2+ gate.

**PathfindingSystem's real API** — confirmed: `PathfindingSystem.is_rebuild_pending() -> bool` exists exactly as the GDD/ADR-0004 describe it (`src/foundation/pathfinding/pathfinding_system.gd:196`), registered as Autoload `GPathfindingSystem` (`project.godot`). Call it as `GPathfindingSystem.is_rebuild_pending()`.

**Control Manifest Rules (Feature layer)**:
- Required: `WaveManager must implement a _routes_ready: bool flag that stays false until templates_ready fires` — this rule (already satisfied by `_templates_ready`) is the wave-1 gate; this story adds the analogous waves-2+ gate on top, per the same "must not emit `monster_spawn_requested` before ready" principle
- Guardrail: the `path_invalidated` subscription must disconnect immediately on gate release (not stay connected for the mission's duration, unlike `templates_ready`) — accumulating connections across waves 2-8 would cause the handler to fire once per accumulated connection

---

## Acceptance Criteria

*From `design/gdd/wave-manager.md`, scoped to this story:*

- [ ] Rule 22 (secondary gate): at the INTERMISSION→PRE_WAVE transition, call `PathfindingSystem.is_rebuild_pending()` once. If `true`, set `_rebuild_pending_gate = true` and subscribe to `path_invalidated`; the spawn coroutine holds its first spawn of that wave until `path_invalidated` fires, then disconnects the subscription immediately.
- [ ] AC-33: GIVEN `is_rebuild_pending()` returns `true` at the INTERMISSION→PRE_WAVE transition, WHEN Wave Manager reaches WAVE_ACTIVE, THEN no `monster_spawn_requested` fires for 30 simulated seconds until `path_invalidated` is injected — then the first spawn entry fires within 1 frame (or after `pre_delay`).
- [ ] AC-33 (negative case): GIVEN `is_rebuild_pending()` returns `false`, THEN spawn sequencing begins at WAVE_ACTIVE entry with no additional gate — behaves exactly as it does today.
- [ ] Gate mutual exclusivity: for wave 1, only the `_templates_ready` gate is checked (never `_rebuild_pending_gate`); for waves 2+, only `_rebuild_pending_gate` is checked (`_templates_ready` is already `true` from wave 1 and is not re-checked).
- [ ] `path_invalidated` early-fire guard: if `path_invalidated` fires during the PRE_WAVE countdown (before the spawn coroutine starts), `_rebuild_pending_gate` must already be `false` by the time the coroutine runs — the coroutine checks the flag at its start and does not await a signal that has already fired.
- [ ] Performance: No performance impact expected — one boolean check plus a signal connect/disconnect pair per wave transition; the gate does not poll.

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines and GDD Rule 22:*

```gdscript
var _rebuild_pending_gate: bool = false  # new field — reset on mission_launched (Story 006)

## Rule 22 secondary gate: called once at INTERMISSION -> PRE_WAVE. Wave 1
## never reaches this transition (it starts at SCOUT -> PRE_WAVE, which does
## NOT check is_rebuild_pending() — only INTERMISSION -> PRE_WAVE does, per
## the GDD's explicit wording).
func _on_intermission_timer_timeout() -> void:
    if _phase_locked: return
    if _phase != Phase.INTERMISSION: return
    _check_rebuild_gate()
    _transition_to(Phase.PRE_WAVE)

## Also called from the Ready-button path for INTERMISSION (existing
## _on_player_ready() already transitions INTERMISSION -> PRE_WAVE — add the
## same _check_rebuild_gate() call there, immediately before that
## _transition_to(Phase.PRE_WAVE) call).

func _check_rebuild_gate() -> void:
    if GPathfindingSystem.is_rebuild_pending():
        _rebuild_pending_gate = true
        GEventBus.path_invalidated.connect(_on_path_invalidated)


## Disconnects immediately on release — prevents subscription accumulation
## across waves 2-8 (per the GDD's explicit lifecycle note for this signal,
## contrasted with templates_ready which stays connected for the mission).
func _on_path_invalidated(_affected_cells: Array) -> void:
    _rebuild_pending_gate = false
    GEventBus.path_invalidated.disconnect(_on_path_invalidated)
```

Modify `_run_spawn_sequence()` (currently only checks `_templates_ready` for wave 1) to add the waves-2+ gate, mirroring the existing wave-1 pattern exactly:

```gdscript
func _run_spawn_sequence() -> void:
    if _wave_index == 1 and not _templates_ready:
        await GEventBus.templates_ready
        if not is_instance_valid(self): return
        if not _spawn_active: return
        if _phase != Phase.WAVE_ACTIVE: return

    # NEW: waves 2+ gate (mutually exclusive with the wave-1 gate above —
    # _wave_index == 1 never reaches this branch, and vice versa).
    if _wave_index > 1 and _rebuild_pending_gate:
        await GEventBus.path_invalidated
        if not is_instance_valid(self): return
        if not _spawn_active: return
        if _phase != Phase.WAVE_ACTIVE: return
        # Early-fire guard: if the module-level _on_path_invalidated handler
        # already disconnected and cleared the gate before this await
        # resolves via the SAME signal firing, this block still runs once
        # more here — that's fine, both paths converge on _rebuild_pending_gate
        # already being false and the subscription already disconnected. Do
        # NOT disconnect again here (double-disconnect would error) — only
        # the standalone _on_path_invalidated handler owns the disconnect.

    for entry: WaveSpawnEntry in _wave_spawn_entries:
        # ...existing spawn loop unchanged...
```

**Important subtlety to verify during implementation**: because `_on_path_invalidated` (a normal signal-connected handler) AND the `await GEventBus.path_invalidated` inside the coroutine will BOTH receive the same signal emission, ensure the disconnect only happens once (in the dedicated handler, not duplicated in the coroutine's post-await code) — a double-disconnect on an already-disconnected signal throws an error in Godot 4.6.2. Confirm this exact interaction via a real test before considering the story done — it's a subtle enough race that GDD text alone doesn't resolve it definitively.

---

## Out of Scope

- **Story 001**: The `_is_final_wave()` helper (unrelated to this story, but present in the same `_check_wave_clear_or_start_watchdog` codepath)
- ~~**Story 006**: Resetting `_rebuild_pending_gate = false`...~~ **Resolved during this story's implementation**: Story 006 already shipped `_reset_all_state()` before this field existed, so this story added the reset itself (see `wave_manager.gd`'s `_reset_all_state()`).

**Known gaps found during this story's code review (2026-07-05) — both triaged and closed 2026-07-07, no code changes required:**
- **Stale subscription on mission restart** — CLOSED, accepted as-is. `_reset_all_state()` resets `_rebuild_pending_gate` but doesn't disconnect a possibly-still-live `path_invalidated` subscription if a mission is abandoned mid-rebuild before the signal fires. Confirmed low-severity and self-healing: the next `_check_rebuild_gate()` call (next INTERMISSION→PRE_WAVE transition) re-evaluates via its own `is_connected()` guards regardless of prior state, and `WaveManager` is a persistent Autoload, so there's no dangling-callable crash risk. No fix needed.
- **Second-invalidation-during-wait not re-checked** — CLOSED, confirmed structurally unreachable, not just untested. The scenario requires a *second* independent tower-placement-triggered rebuild to be queued while `_run_spawn_sequence()` is gated and awaiting the first `path_invalidated` inside WAVE_ACTIVE. This can't happen: `TowerSystem.place_tower()`'s own Gate 1 rejects all placement during WAVE_ACTIVE (already covered by `tests/integration/core/combat_loop_test.gd:124`'s "bypasses place_tower() Gate 1" test), independently reinforced by Grid's `ACTIVE_READONLY` write lock during the same phase (`src/foundation/grid/grid.gd`) and Pathfinding's own Rule 20 ("`path_invalidated` is only ever emitted during SCOUT and INTERMISSION — not during active waves"). Three independent layers all prevent a new rebuild from being triggerable during this window — no code fix needed; the existing test coverage already proves the precondition that makes this gap unreachable.

---

## QA Test Cases

- **AC-33**: Rebuild-pending gate blocks first spawn of wave 2+ until `path_invalidated`
  - Given: Wave Manager at the INTERMISSION→PRE_WAVE transition; `PathfindingSystem.is_rebuild_pending()` stubbed to return `true`
  - When: Wave Manager reaches WAVE_ACTIVE for wave 2
  - Then: no `monster_spawn_requested` for 30 simulated seconds; injecting `path_invalidated` causes the first spawn entry to fire within 1 frame (or after `pre_delay`)

- **AC-33 (negative case)**: No gate when rebuild isn't pending
  - Given: `is_rebuild_pending()` stubbed to return `false`
  - When: Wave Manager reaches WAVE_ACTIVE for wave 2
  - Then: spawn sequencing begins immediately, no additional delay

- **Gate mutual exclusivity**: wave 1 never checks `_rebuild_pending_gate`; waves 2+ never re-check `_templates_ready`
  - Given: wave 1, `_rebuild_pending_gate` manually set `true` (contrived, shouldn't matter)
  - When: WAVE_ACTIVE begins
  - Then: wave 1 gates only on `_templates_ready`, ignoring `_rebuild_pending_gate` entirely

- **Subscription lifecycle**: `path_invalidated` disconnects after firing, no accumulation across waves
  - Given: 3 consecutive waves each triggering `is_rebuild_pending() == true`
  - When: each wave's `path_invalidated` fires once
  - Then: the handler fires exactly once per wave, not an accumulating multiple (verifies disconnect actually happened)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/wave_manager/wave_manager_rebuild_gate_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None directly, but is most meaningfully testable alongside Story 006 (needs multiple real waves to reach wave 2+)
- Unlocks: Story 008 (mission scene assembly needs this for any mission with 2+ waves and mid-mission tower changes)

---

## Completion Notes
**Completed**: 2026-07-05
**Criteria**: 6/6 passing (all COVERED, no deferred items)
**Deviations**: ADVISORY (x5) — (1) `TR-wave-004`'s registry mismatch — **RESOLVED 2026-07-07**, see `TR-wave-008` above; (2) two real gaps beyond the story's own pseudocode were found and fixed (`_check_rebuild_gate()`'s self-correcting `else` branch, `_reset_all_state()`'s new reset) — both confirmed correct by code review; (3) two new gaps found during code review, both triaged and closed 2026-07-07 with no code changes needed (stale subscription on mission restart — confirmed self-healing; second-invalidation-during-wait — confirmed structurally unreachable given TowerSystem's WAVE_ACTIVE placement gate) — see Out of Scope section above; (4) an unrelated pre-existing test from Story 007 broke due to a comment-text false positive triggered by this story's own doc comments — fixed by filtering comment lines, closing a fragility flagged in three prior stories' code reviews; (5) a stale, self-contradictory header comment removed.
**Test Evidence**: `tests/integration/wave_manager/wave_manager_rebuild_gate_test.gd` — 17/17 passing; full `wave_manager` suite (unit+integration) 142/142 passing, 0 errors, 0 failures
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (both suggestions applied)
