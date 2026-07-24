# Story 001: DEFEAT & MISSION_COMPLETE Win/Loss Conditions

> **Epic**: Wave Manager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-05-16
> **Estimate**: 3h

## Context

**GDD**: `design/gdd/wave-manager.md`
**Requirement**: `TR-wave-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Wave Manager FSM Architecture
**ADR Decision Summary**: A single `enum Phase` with 7 members; all transitions go through `_transition_to(new_phase)`, which enforces the `_phase_locked` latch, stops timers, assigns `_phase`, and emits `mission_phase_changed`. `_phase_locked = true` on DEFEAT gives it structural priority over any same-frame wave-clear signal.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API risk — `enum`, `match`, `Timer`, signals are all stable since Godot 4.0 (per ADR-0012's Engine Compatibility section).

**Verified against the actual codebase (2026-07-04)**: `src/gameplay/wave_manager.gd`'s `_enter_phase()` match block (lines 149-164) has explicit no-op branches: `Phase.MISSION_COMPLETE: pass # Out of Scope for S3-06 — no win condition yet` and `Phase.DEFEAT: pass # Out of Scope for S3-06 — no loss condition yet`. Neither `hero_died` nor any final-wave-detection logic is subscribed/implemented anywhere in the file (confirmed via grep — zero matches for `hero_died`). The `_phase_locked` latch machinery already exists and is checked correctly by every other handler — but nothing currently ever transitions to DEFEAT or MISSION_COMPLETE, so the latch is presently dead code.

**Control Manifest Rules (Feature layer)**:
- Required: WaveManager is the sole authority on mission phase transitions — no other system may trigger a phase change (Rule 1)
- Required: `_phase_locked = true` must be set as `_on_hero_died()`'s first operation; every other handler must check `_phase_locked` first and return immediately if true (already implemented in `_transition_to` and all existing handlers — this story adds the one handler that's missing)
- Forbidden: WaveManager reading Hero or Monster state directly to determine win/loss — all triggers must arrive via EventBus (`hero_died`, and internal `_wave_index`/`wave_scripts.size()` comparison for MISSION_COMPLETE, which is already-local state)
- **Note on manifest staleness**: `control-manifest.md`'s Feature Layer Rules also contain a now-superseded entry — *"Never implement WaveManager as an Autoload... source: ADR-0002 (Alt C rejected)."* This predates ADR-0012 (Accepted 2026-05-24, after the manifest's 2026-05-16 last-update, and not listed in the manifest's "ADRs Covered"). ADR-0012 revised ADR-0002 to add WaveManager as Autoload #7 — the already-shipped code follows this. Treat ADR-0012 as authoritative; the manifest needs a `/create-control-manifest` regeneration to catch up.

---

## Acceptance Criteria

*From `design/gdd/wave-manager.md`, scoped to this story:*

- [ ] AC-7: GIVEN Wave Manager in each of SCOUT, PRE_WAVE, INTERMISSION, and WAVE_ACTIVE (four separate test cases), WHEN `hero_died` is received, THEN `mission_phase_changed(from: <current_phase>, to: 'DEFEAT')` is emitted with the correct `from` value for each case, and no further wave-lifecycle events fire for the next 60 simulated seconds.
- [ ] AC-8: GIVEN Wave Manager in WAVE_ACTIVE with `_all_spawns_fired == true` and `_enemies_alive == 1`, WHEN `_on_hero_died()` is called immediately followed by a competing wave-clear handler (`_on_monster_died`, `_on_boss_died`, or `monster_breached(tier:2)`) in the same invocation, THEN only `mission_phase_changed(to: 'DEFEAT')` fires — no `wave_completed`.
- [ ] AC-21: If `hero_died` is received during INTERMISSION, Wave Manager immediately transitions to DEFEAT and stops the 30s intermission timer. The partial intermission is discarded; no PRE_WAVE follows.
- [ ] Rule 13: `WAVE_ACTIVE → MISSION_COMPLETE` (final wave cleared): when the wave-clear condition is met on the mission's final wave (`_wave_index == wave_scripts.size()`), transition to MISSION_COMPLETE instead of INTERMISSION. Stops all spawn sequencing and timers.
- [ ] AC-6: GIVEN a 2-wave WaveConfig with Wave Manager in WAVE_ACTIVE for wave 2 (the final wave), WHEN the wave clears, THEN Wave Manager transitions to MISSION_COMPLETE (not INTERMISSION), and for 60 simulated seconds no further wave-lifecycle events fire.
- [ ] Performance: No performance impact expected — phase transition plus one integer/boolean comparison (`_is_final_wave()`), O(1), no new per-frame work.

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines and the GDD Rules above:*

Add a `hero_died` subscription following the exact pattern already used by every other handler in the file:

```gdscript
func _ready() -> void:
    # ...existing subscriptions...
    GEventBus.hero_died.connect(_on_hero_died)

func _exit_tree() -> void:
    # ...existing disconnects...
    GEventBus.hero_died.disconnect(_on_hero_died)

## Rule 14 / AC-7 / AC-8 / AC-21: hero_died has absolute priority over any
## same-frame wave-clear signal. _transition_to() already sets
## _phase_locked = true internally and returns early if already locked — but
## _on_hero_died() must call _transition_to(Phase.DEFEAT) UNCONDITIONALLY,
## even from WAVE_ACTIVE with a competing _check_wave_clear_or_start_watchdog()
## call in flight. Because DEFEAT wins the _phase_locked race by being the
## first handler to call _transition_to() in the same call stack (matching
## AC-8's exact scenario), no special-case guard is needed beyond what
## _transition_to() already enforces — verify this holds via the AC-8 test.
func _on_hero_died() -> void:
    _transition_to(Phase.DEFEAT)
```

For MISSION_COMPLETE (Rule 13), modify `_check_wave_clear_or_start_watchdog()` (currently unconditionally transitions to `Phase.INTERMISSION`) to check whether the current wave is the mission's final wave:

```gdscript
func _check_wave_clear_or_start_watchdog() -> void:
    if not _all_spawns_fired:
        return
    if _enemies_alive > 0:
        _watchdog_stall_timer.start()
        _watchdog_force_timer.start()
        return
    var next_phase: Phase = Phase.MISSION_COMPLETE if _is_final_wave() else Phase.INTERMISSION
    if _phase_locked:
        _transition_to.call_deferred(next_phase)
    else:
        _transition_to(next_phase)

## _wave_index is 1-based (incremented in _enter_wave_active() before the
## first spawn). wave_scripts.size() is the total wave count. This story does
## NOT yet have real WaveConfig loading (see Story 006) — until then, inject
## a wave count directly for testing (mirroring how _wave_spawn_entries is
## currently test-injected).
func _is_final_wave() -> bool:
    return _wave_index >= _wave_scripts_count  # settable test-injection field; superseded by Story 006's real WaveConfig.wave_scripts.size()
```

**Sequencing note**: Story 006 (WaveConfig Resource Loading) will replace whatever placeholder wave-count field this story introduces with the real `WaveConfig.wave_scripts.size()`. Until Story 006 lands, use a settable test-injection field for the total wave count, matching this codebase's established pattern (`_wave_spawn_entries` is already test-injectable the same way).

`_on_watchdog_force_timeout()` (the 60s stuck-wave force-clear) currently unconditionally transitions to `Phase.INTERMISSION` too — apply the same `_is_final_wave()` check there for consistency with Rule 23's "advances to INTERMISSION or MISSION_COMPLETE as normal" wording.

---

## Out of Scope

- **Story 002**: Real `wave_completed`/`wave_started` event emission (this story only needs the phase transition itself, not the lifecycle signals it should accompany — a future story wires those in)
- **Story 003**: BOSS-specific fast-paths — this story's `_is_final_wave()` check applies uniformly regardless of how the wave cleared
- **Story 006**: Real `WaveConfig` loading — this story uses a test-injectable placeholder for total wave count

---

## QA Test Cases

- **AC-7**: `hero_died` → DEFEAT from any phase
  - Given: Wave Manager in SCOUT (repeat for PRE_WAVE, INTERMISSION, WAVE_ACTIVE — 4 total test cases)
  - When: `GEventBus.hero_died.emit()` fires
  - Then: `mission_phase_changed(from: <phase>, to: "DEFEAT")` emitted with the correct `from` value; no `wave_started`/`wave_completed`/`phase_timer_tick`/`wave_countdown_warning`/`monster_spawn_requested` for the next 60 simulated seconds (mocked timers)

- **AC-8**: DEFEAT wins same-frame race against wave-clear
  - Given: Wave Manager in WAVE_ACTIVE, `_all_spawns_fired = true`, `_enemies_alive = 1`
  - When: `_on_hero_died()` called, immediately followed by `_on_monster_died()` (repeat for `_on_boss_died()` and a `monster_breached(tier:2)` equivalent — 3 total test cases)
  - Then: only `mission_phase_changed(to: "DEFEAT")` fires; no `wave_completed`

- **AC-21**: `hero_died` during INTERMISSION stops the timer
  - Given: Wave Manager in INTERMISSION with the 30s timer running
  - When: `hero_died` fires
  - Then: transitions to DEFEAT; `phase_timer_tick(phase: "INTERMISSION", ...)` does not fire again for 30 simulated seconds

- **Rule 13 / AC-6**: Final wave clears to MISSION_COMPLETE, not INTERMISSION
  - Given: A 2-wave mission, Wave Manager in WAVE_ACTIVE for wave 2 (the final wave)
  - When: The wave clears (standard clear — all `monster_died`)
  - Then: `mission_phase_changed(from: "WAVE_ACTIVE", to: "MISSION_COMPLETE")` — NOT INTERMISSION; no further wave-lifecycle events for 60 simulated seconds
  - Edge case: A non-final wave (wave 1 of 2) still transitions to INTERMISSION as before — regression-test this to confirm `_is_final_wave()` doesn't break the existing non-final path

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/wave_manager/wave_manager_defeat_victory_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (builds directly on the already-implemented FSM skeleton)
- Unlocks: Story 008 (mission scene assembly needs a working win/loss condition)

---

## Completion Notes
**Completed**: 2026-07-05
**Criteria**: 6/6 passing (all COVERED, no deferred items)
**Deviations**: ADVISORY — the story's Implementation Notes assumed `_phase_locked` alone made DEFEAT structurally unconditional; code review found this false for reentrant/deferred cases and both `_on_hero_died()` and `_check_wave_clear_or_start_watchdog()` needed a defer-if-locked pattern not in the original spec. Found and fixed within this session, re-reviewed and APPROVED — not left as open debt. ADVISORY — actual effort exceeded the 3h estimate due to the code-review round-trip.
**Test Evidence**: `tests/unit/wave_manager/wave_manager_defeat_victory_test.gd` — 11/11 passing; full `wave_manager` suite 34/34 passing, 0 errors, 0 failures, 0 orphans
**Code Review**: Complete — APPROVED (after one CHANGES REQUIRED round addressing a reentrancy gap)
