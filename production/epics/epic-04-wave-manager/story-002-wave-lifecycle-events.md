# Story 002: Wave Lifecycle Events (wave_started / wave_completed / wave_preview_available)

> **Epic**: Wave Manager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-05-16
> **Estimate**: 4h

## Context

**GDD**: `design/gdd/wave-manager.md`
**Requirement**: `TR-wave-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Wave Manager FSM Architecture
**ADR Decision Summary**: All cross-system communication goes through EventBus. Phase transitions and wave lifecycle are observable only via emitted signals — no other system reads WaveManager state directly.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API risk.

**Verified against the actual codebase (2026-07-04) — the key finding driving this story**: `grep -n "wave_completed\|wave_started\|wave_preview_available" src/gameplay/wave_manager.gd` returns **zero matches**. None of these three signals are emitted anywhere in the current implementation, despite the phase machinery (timers, `_transition_to`, wave-clear detection) working correctly. Mission HUD, Resource Economy, and Constellation System currently receive no wave-lifecycle events at all — this is foundational, not an edge case.

**Additional EventBus signal-contract gap found**: `src/foundation/event_bus/event_bus.gd`'s real `wave_completed` signature is `wave_completed(wave_number: int, enemies_remaining: int)` — it is **missing the `was_boss_breached: bool` third field** the GDD requires (Rules 11, 20, 21; AC-30). This story must add that field to the EventBus signal itself before wiring any emission — the same class of prerequisite EventBus change as Story 006 in Epic 02 (Hero) needed for `hero_class_unlocked` earlier this sprint.

**Control Manifest Rules (Feature layer)**:
- Required: All cross-system communication via EventBus signals — no direct references
- Guardrail: signal emission is O(1) per phase transition/wave-clear — no iteration cost beyond what already exists

---

## Acceptance Criteria

*From `design/gdd/wave-manager.md`, scoped to this story:*

- [ ] Rule 10c: `PRE_WAVE → WAVE_ACTIVE`: emits `wave_started(wave_number, total_waves, wave_difficulty)` before the phase transition.
- [ ] Rule 11: Standard (non-final) wave clear emits `wave_completed(wave_number, enemies_remaining: 0, was_boss_breached: false)`, then `mission_phase_changed`, then (on INTERMISSION entry) `wave_preview_available(next_wave_number, composition)`.
- [ ] Rule 13: Final wave clear emits `wave_completed(wave_number, enemies_remaining: 0, was_boss_breached: false)` before `mission_phase_changed(→ MISSION_COMPLETE)`.
- [ ] Rule 23 (force-clear path): the 60s watchdog force-clear emits `wave_completed(wave_number, enemies_remaining: <stuck count>, was_boss_breached: false)` — NOT 0, the actual stuck count.
- [ ] AC-5: `wave_started` fires before `mission_phase_changed` in the same frame (emission order, not just co-tick presence) — verified with a 5-wave fixture, `total_waves: 5` pinned exactly.
- [ ] AC-11: On the final `monster_died` matching all fired spawn entries, `wave_completed` fires in the same frame.
- [ ] AC-27: `wave_preview_available` on INTERMISSION entry carries `next_wave_number = _wave_index + 1` and a `composition: Array[Dictionary]` (`{monster_id, count}` per unique monster, summing to the upcoming wave's total entry count).
- [ ] `wave_completed`'s EventBus signature updated to include `was_boss_breached: bool` as its third field.
- [ ] `_wave_clear_fired` is set `true` at both existing clear paths (standard clear, watchdog force-clear) immediately before their `wave_completed` emission — this satisfies Story 003's guard precondition without requiring Story 003 to modify this story's code.
- [ ] Performance: No performance impact expected — signal emission is O(1) per phase transition/wave-clear, no iteration added by this story.

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines and the GDD Rules above:*

**Step 1 — EventBus signal update** (do this first, it's a prerequisite):

```gdscript
# src/foundation/event_bus/event_bus.gd — BEFORE:
signal wave_completed(wave_number: int, enemies_remaining: int)
# AFTER:
signal wave_completed(wave_number: int, enemies_remaining: int, was_boss_breached: bool)
```

This story emits `was_boss_breached: false` unconditionally at every call site it touches (all clear paths in scope here are non-BOSS). Story 003 (BOSS Death & BOSS Breach) is the only story that ever passes `true`.

**Step 2 — `wave_started` at PRE_WAVE → WAVE_ACTIVE entry:**

```gdscript
func _enter_wave_active() -> void:
    _wave_index += 1
    _enemies_alive = 0
    _all_spawns_fired = false
    _spawn_active = true
    # AC-5: wave_started must fire BEFORE mission_phase_changed in the same
    # frame. _transition_to() emits mission_phase_changed itself (after
    # calling _enter_phase() -> _enter_wave_active()), so emitting here,
    # inside _enter_wave_active(), fires AFTER mission_phase_changed in the
    # current call order (_transition_to sets _phase, emits
    # mission_phase_changed, THEN calls _enter_phase()). This ORDER MUST BE
    # FIXED to satisfy AC-5 — verify the actual _transition_to() call order
    # in the current code and either move the wave_started emission to
    # _transition_to() itself (before the mission_phase_changed emit, gated
    # on new_phase == Phase.WAVE_ACTIVE) or reorder _transition_to()'s emit
    # sequence. Do not assume the existing order is correct without checking.
    GEventBus.wave_started.emit(_wave_index, _total_wave_count(), _wave_reward_scalar)
    _run_spawn_sequence()
```

**Step 3 — `wave_completed` at every clear path.** There are currently 2 call sites in `_check_wave_clear_or_start_watchdog()`/`_on_watchdog_force_timeout()` that transition to INTERMISSION/MISSION_COMPLETE without emitting anything. Add the emission immediately before each `_transition_to()` call:

```gdscript
func _check_wave_clear_or_start_watchdog() -> void:
    if not _all_spawns_fired:
        return
    if _enemies_alive > 0:
        _watchdog_stall_timer.start()
        _watchdog_force_timer.start()
        return
    _wave_clear_fired = true
    GEventBus.wave_completed.emit(_wave_index, 0, false)
    var next_phase: Phase = Phase.MISSION_COMPLETE if _is_final_wave() else Phase.INTERMISSION
    if _phase_locked:
        _transition_to.call_deferred(next_phase)
    else:
        _transition_to(next_phase)

func _on_watchdog_force_timeout() -> void:
    if _phase_locked: return
    if _phase != Phase.WAVE_ACTIVE: return
    # Rule 23: force-clear reports the ACTUAL stuck count, not 0.
    _wave_clear_fired = true
    GEventBus.wave_completed.emit(_wave_index, _enemies_alive, false)
    var next_phase: Phase = Phase.MISSION_COMPLETE if _is_final_wave() else Phase.INTERMISSION
    _transition_to(next_phase)
```

**Cross-story note (owned here, consumed by Story 003)**: both clear paths above set `_wave_clear_fired = true` immediately before their `wave_completed` emission. Story 003 introduces the `_wave_clear_fired` field's *consuming* guard (its `_on_boss_died`/`_on_monster_breached` handlers check it), but this story is the one that must declare the field and set it at these two call sites — do this now so Story 003 doesn't need to retrofit already-implemented code:

```gdscript
var _wave_clear_fired: bool = false  # also reset in mission_launched reset (Story 006)
```

`_is_final_wave()` is introduced by Story 001 — this story depends on it existing.

**Step 4 — `wave_preview_available` on INTERMISSION entry:**

```gdscript
func _enter_intermission() -> void:
    _intermission_timer.start()
    GEventBus.wave_preview_available.emit(_wave_index + 1, _build_composition_preview(_wave_index + 1))

## Aggregates the upcoming wave's WaveSpawnEntry list into {monster_id, count}
## dicts. Depends on Story 006's real WaveConfig loading for the entry
## source — until then, read from whatever test-injectable wave-script
## storage Story 006 introduces, or stub with the currently test-injected
## _wave_spawn_entries equivalent for the NEXT wave (requires a
## wave-indexed collection, not the single flat list current tests inject).
func _build_composition_preview(wave_number: int) -> Array:
    ...
```

**Sequencing note**: `_build_composition_preview()` genuinely needs Story 006's real multi-wave `WaveConfig` storage to do anything meaningful (the current code only has a single flat `_wave_spawn_entries` list for "the wave currently active," not a per-wave-indexed collection). If Story 006 isn't done first, implement this against a test-injectable `Dictionary[int, Array[WaveSpawnEntry]]` seam now and wire it to the real `WaveConfig.wave_scripts` array once Story 006 lands.

---

## Out of Scope

- **Story 001**: `hero_died` → DEFEAT and the `_is_final_wave()` helper this story depends on
- **Story 003**: BOSS-specific `wave_completed(was_boss_breached: true)` emission — this story only ever emits `false`
- **Story 006**: Real `WaveConfig`/`WaveScript` Resource loading that `_build_composition_preview()` and `_total_wave_count()` ultimately need

---

## QA Test Cases

- **AC-5**: `wave_started` before `mission_phase_changed`, same frame
  - Given: A 5-wave WaveConfig fixture (`total_waves` pinned to exactly 5, not asserted as unbound)
  - When: PRE_WAVE countdown expires (or Ready pressed)
  - Then: event log shows `wave_started(1, 5, 1.00)` captured before `mission_phase_changed(from: "PRE_WAVE", to: "WAVE_ACTIVE")`

- **Rule 11 / AC-27**: Non-final wave clear emits `wave_completed` then `wave_preview_available`
  - Given: A 2-wave WaveConfig, Wave Manager in WAVE_ACTIVE for wave 1
  - When: Wave 1 clears (standard — all `monster_died`)
  - Then: `wave_completed(1, 0, false)` emitted, then `mission_phase_changed(→ INTERMISSION)`, then `wave_preview_available(2, [...])` with composition summing to wave 2's entry count

- **Rule 13**: Final wave clear emits `wave_completed` before MISSION_COMPLETE
  - Given: A 2-wave WaveConfig, Wave Manager in WAVE_ACTIVE for wave 2
  - When: Wave 2 clears
  - Then: `wave_completed(2, 0, false)` emitted before `mission_phase_changed(→ MISSION_COMPLETE)`

- **Rule 23**: Watchdog force-clear reports actual stuck count
  - Given: Wave Manager in WAVE_ACTIVE, `_all_spawns_fired = true`, `_enemies_alive = 2`
  - When: 60 simulated seconds elapse (mocked timer)
  - Then: `wave_completed(wave_number, 2, false)` — enemies_remaining is 2, not 0

- **AC-11**: Standard clear fires in the same frame as the final `monster_died`
  - Given: A 2-entry wave; inject `monster_spawned` × 2 then `monster_died` × 2
  - Then: `wave_completed` fires immediately after the second `monster_died`, same frame

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/wave_manager/wave_manager_lifecycle_events_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`_is_final_wave()` helper)
- Sequencing note: `_build_composition_preview()` needs Story 006's real multi-wave `WaveConfig` storage to produce meaningful output. Implement against a test-injectable `Dictionary[int, Array[WaveSpawnEntry]]` seam now; wire to the real `WaveConfig.wave_scripts` once Story 006 lands. This is not a hard blocker on Story 006 — the seam makes this story independently completable and testable.
- Unlocks: Story 003 (BOSS fast-paths extend this story's `wave_completed` emission with `was_boss_breached: true`), Story 008 (mission scene assembly needs real wave-lifecycle events for Mission HUD to consume)

---

## Completion Notes
**Completed**: 2026-07-05
**Criteria**: 10/10 passing (all COVERED, no deferred items)
**Deviations**: ADVISORY (x5) — (1) corrected the story's stale `_total_wave_count()` reference to the real `_wave_scripts_count` field; (2) preserved Story 001's reentrancy fixes instead of reverting to the story's stale pre-code-review pseudocode; (3) the `wave_completed` signature change required unplanned companion fixes to `damage_status.gd`/`monster_manager.gd` (GDScript signal arity must match exactly — confirmed via a real parse error), both now covered by dedicated real-signal regression tests; (4) kept `_build_composition_preview()`'s local `entries` var untyped rather than `Array[WaveSpawnEntry]` as literally suggested in code review, due to a real GDScript typing quirk (documented in-code); (5) `_wave_clear_fired` reset-timing sequencing risk flagged and addressed via a warning added to Story 003's Dependencies section.
**Test Evidence**: `tests/integration/wave_manager/wave_manager_lifecycle_events_test.gd` — 15/15 passing; full regression run across `wave_manager`/`damage_status`/`monster`/`event_bus`: 176/176 passing, 0 errors, 0 failures, independently re-verified
**Code Review**: Complete — APPROVED (after one APPROVED WITH SUGGESTIONS round addressing a regression-coverage gap)
