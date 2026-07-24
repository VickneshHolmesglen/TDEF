# Story 003: BOSS Death, BOSS Breach & Wave-Clear Robustness

> **Epic**: Wave Manager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-05-16
> **Estimate**: 5h

## Context

**GDD**: `design/gdd/wave-manager.md`
**Requirement**: `TR-wave-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Wave Manager FSM Architecture
**ADR Decision Summary**: `_wave_clear_fired` latch prevents double-clear when two wave-clear paths race in the same frame (e.g. `boss_died` and `monster_died` at `_enemies_alive == 1`). `_on_boss_died()` applies two sequential guards (phase-equality, then the latch) before executing any wave-clear logic.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API risk.

**Verified against the actual codebase (2026-07-04)**: grep for `boss_died|monster_breached|monsters_died_batch` in `src/gameplay/wave_manager.gd` returns zero matches — none of these three subscriptions exist. No `_wave_clear_fired` field exists either (only `_all_spawns_fired`/`_enemies_alive` drive the standard clear path from Story 002). This story adds all of it fresh.

**Real EventBus signatures** (verified against `src/foundation/event_bus/event_bus.gd`):
- `boss_died(entity_id: int, monster_id: StringName, wave_index: int, cause: String)`
- `monster_breached(entity_id: int, monster_id: StringName, tier: int)`
- `monsters_died_batch(payloads: Array[MonsterDiedEvent])` — carries an **array of event payloads**, not a raw `count: int` as the GDD's narrative text implies. Use `payloads.size()` as the decrement count.

**Control Manifest Rules (Feature layer)**:
- Required: WaveManager owns the `monster_died` batch accumulator logic on its receiving side — it does not accumulate anything itself, it just reads `payloads.size()` from the already-batched signal
- Guardrail: BOSS-fast-path guards (phase-equality + `_wave_clear_fired` latch) must be the first two operations in `_on_boss_died()`, before any wave-clear logic executes

---

## Acceptance Criteria

*From `design/gdd/wave-manager.md`, scoped to this story:*

- [ ] AC-15: On `boss_died`, wave-clear triggers immediately regardless of `_enemies_alive`/`_all_spawns_fired`. Remaining spawn entries are discarded, not fired.
- [ ] AC-16: On `monster_breached(tier == 2)` (BOSS breach), wave-clear triggers with `was_boss_breached: true` — the one path where this flag is true.
- [ ] AC-24: `monster_breached(tier == 1)` (ELITE breach) does NOT trigger the BOSS fast-path — treated as a standard `-1` decrement.
- [ ] AC-29: `boss_died` received before all spawns have fired still emits the full 3-event sequence (`wave_completed` → `mission_phase_changed` → `wave_preview_available`) via the same INTERMISSION entry path as a standard clear.
- [ ] AC-30: `wave_completed`'s `was_boss_breached` flag is correct in all 3 clear paths: standard (false), `boss_died` fast-path (false), BOSS breach (true).
- [ ] AC-32: Stray `boss_died(cause: "force_removed")` received after the phase has already advanced to INTERMISSION is a no-op — no second `wave_completed`.
- [ ] AC-34: Stray `boss_died` in the SAME frame as a BOSS breach (before phase state updates) is also a no-op — the `_wave_clear_fired` latch catches this within-WAVE_ACTIVE race.
- [ ] AC-28: `monsters_died_batch(payloads)` with `payloads.size() == N` decrements `_enemies_alive` by `N` and triggers wave-clear identically to `N` sequential `monster_died` events.
- [ ] AC-37: `monsters_died_batch` with an empty or otherwise invalid payload (size 0) is discarded — `_enemies_alive` unchanged, a warning logged, no `wave_completed`.
- [ ] Performance: No performance impact expected — O(1) guard checks per event; `monsters_died_batch` reads `payloads.size()` once (already batched upstream), no iteration added by this story.

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines and the GDD Rules above:*

```gdscript
var _wave_clear_fired: bool = false  # new field — reset in mission_launched reset (Story 006)

func _ready() -> void:
    # ...existing...
    GEventBus.boss_died.connect(_on_boss_died)
    GEventBus.monster_breached.connect(_on_monster_breached)
    GEventBus.monsters_died_batch.connect(_on_monsters_died_batch)

func _exit_tree() -> void:
    # ...existing...
    GEventBus.boss_died.disconnect(_on_boss_died)
    GEventBus.monster_breached.disconnect(_on_monster_breached)
    GEventBus.monsters_died_batch.disconnect(_on_monsters_died_batch)


## Rules 20, EC-5b, AC-32/34: two sequential guards BEFORE any wave-clear
## logic. Guard 1 (phase-equality) catches stray boss_died after phase has
## already advanced (AC-32). Guard 2 (_wave_clear_fired latch) catches a
## same-frame race where phase is still nominally WAVE_ACTIVE but wave-clear
## already fired (AC-34).
func _on_boss_died(_entity_id: int, _monster_id: StringName, _wave_index_param: int, _cause: String) -> void:
    if _phase_locked: return
    if _phase != Phase.WAVE_ACTIVE: return
    if _wave_clear_fired: return
    _wave_clear_fired = true
    _spawn_active = false  # EC-3: cancel remaining spawn entries synchronously
    GEventBus.wave_completed.emit(_wave_index, 0, false)
    var next_phase: Phase = Phase.MISSION_COMPLETE if _is_final_wave() else Phase.INTERMISSION
    _transition_to(next_phase)


## Rule 21 / AC-16 / AC-24: tier 2 = BOSS breach fast-path (was_boss_breached
## = true, the ONE path where this is true). tier 1 = ELITE breach, standard
## decrement only — falls through to the same handling as monster_died.
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


## AC-28 / AC-37: batch decrement with an invalid-count guard.
func _on_monsters_died_batch(payloads: Array) -> void:
    if _phase_locked: return
    if _phase != Phase.WAVE_ACTIVE: return
    var count: int = payloads.size()
    if count <= 0:
        push_warning("WaveManager: monsters_died_batch received with invalid count %d — discarded." % count)
        return
    _enemies_alive = maxi(0, _enemies_alive - count)
    _check_wave_clear_or_start_watchdog()
```

**`_wave_clear_fired` precondition**: Story 002 declares `_wave_clear_fired` and sets it `true` at both its clear paths (standard clear, watchdog force-clear) as part of its own implementation — see Story 002's Implementation Notes. This story only needs to *consume* the field via Guard 2 in `_on_boss_died()`/`_on_monster_breached()`; it does not need to retrofit Story 002's code.

---

## Out of Scope

- **Story 001**: `_is_final_wave()` this story depends on
- **Story 002**: The base `wave_completed`/`wave_started` emission machinery and the `was_boss_breached` EventBus field this story extends
- **Story 006**: `_wave_clear_fired` reset on `mission_launched` (added as part of that story's full state-reset work, per AC-20's 8-field list)

---

## QA Test Cases

- **AC-15**: `boss_died` clears wave immediately, discards remaining entries
  - Given: WAVE_ACTIVE with 3 unfired WaveScript entries, `_enemies_alive = 2`
  - When: `boss_died` fires
  - Then: `wave_completed(wave_number, 0, false)` emitted; no `monster_spawn_requested` for 30 simulated seconds after

- **AC-16**: BOSS breach clears wave with `was_boss_breached: true`
  - Given: WAVE_ACTIVE
  - When: `monster_breached(tier: 2)` fires
  - Then: `wave_completed(wave_number, 0, true)`; no DEFEAT triggered

- **AC-24**: ELITE breach (tier 1) is a standard decrement
  - Given: WAVE_ACTIVE with 3 enemies remaining
  - When: `monster_breached(tier: 1)` fires
  - Then: wave does NOT clear; `_enemies_alive` decrements by 1 only

- **AC-29**: `boss_died` before all spawns fired still emits the full 3-event sequence
  - Given: A 2-wave WaveConfig, WAVE_ACTIVE wave 1, `_all_spawns_fired = false`
  - When: `boss_died` fires
  - Then: `wave_completed(was_boss_breached: false)` → `mission_phase_changed(→ INTERMISSION)` → `wave_preview_available(2, [...])`, in that order

- **AC-30**: `was_boss_breached` correct across all 3 paths (3 separate tests: standard, `boss_died`, breach)

- **AC-32**: Stray `boss_died` after phase already advanced is a no-op
  - Given: Wave Manager already in INTERMISSION after a standard clear
  - When: `boss_died(cause: "force_removed")` fires
  - Then: no second `wave_completed`/`mission_phase_changed`/`wave_started` for 30 simulated seconds

- **AC-34**: Same-frame stray `boss_died` after a breach is a no-op
  - Given: WAVE_ACTIVE
  - When: `monster_breached(tier:2)` fires, immediately followed (same invocation) by `boss_died(cause: "force_removed")`
  - Then: exactly one `wave_completed` (`was_boss_breached: true`) — not two

- **AC-28**: `monsters_died_batch` clears wave identically to sequential `monster_died`
  - Given: 5 alive monsters, all spawned, 0 died
  - When: `monsters_died_batch` with 5 payloads fires
  - Then: wave clears identically to 5 sequential `monster_died`

- **AC-37**: Invalid batch count is discarded
  - Given: `_enemies_alive = 3`
  - When: `monsters_died_batch` fires with an empty payload array
  - Then: `_enemies_alive` remains 3; warning logged; no `wave_completed`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/wave_manager/wave_manager_boss_wave_clear_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`_is_final_wave()`), Story 002 (base `wave_completed` emission and `was_boss_breached` field)
- **Sequencing risk flagged during Story 002's code review (2026-07-05) — resolved with a correction, not just by Story 006 landing**: this note originally said confirming Story 006 was Complete would resolve the risk, but that undersold the actual problem — Story 006's `_reset_all_state()` reset is **mission-scoped** (fires once per `mission_launched`), not **wave-scoped**. Even with Story 006 Complete, `_wave_clear_fired` was still never reset between waves *within* the same mission, meaning it would have stayed latched `true` from wave 1's clear onward, permanently dead-ending this story's `_on_boss_died()`/`_on_monster_breached()` fast-paths from wave 2 onward for the rest of every mission (most missions put the BOSS on the *final* wave, not wave 1). Caught during this story's own code-review-fix pass, before writing any BOSS-fast-path test that would have exposed it in production; fixed by adding a wave-scoped `_wave_clear_fired = false` reset to `_enter_wave_active()`, mirroring `_round_robin_counter`'s identical wave-scoped reset from Story 007.
- Unlocks: Story 008 (mission scene assembly needs BOSS handling for a complete mission)

---

## Completion Notes
**Completed**: 2026-07-05
**Criteria**: 10/10 passing (all COVERED, no deferred items)
**Deviations**: ADVISORY (x5) — (1) the Story 002 sequencing risk resolved with a correction (see updated Dependencies note above — it needed a wave-scoped fix, not just Story 006 landing); (2) the drop-vs-defer design question investigated via actual call-graph tracing, confirmed safe; (3) a real, serious bug found and fixed this session — `_wave_clear_fired` never reset per-wave would have made BOSS fast-paths permanently non-functional from wave 2 onward in real missions; (4) a related, pre-existing reentrancy hole in `_check_wave_clear_or_start_watchdog()` found and fixed (only safe once the wave-scoped reset above landed); (5) a static-typing violation and a test that didn't prove its own claimed assertion (AC-29 ordering) both found and fixed during code review.
**Test Evidence**: `tests/unit/wave_manager/wave_manager_boss_wave_clear_test.gd` — 16/16 passing; full `wave_manager` suite (unit+integration) 125/125 passing, 0 errors, 0 failures
**Code Review**: Complete — APPROVED (after one APPROVED WITH SUGGESTIONS round; all 4 requested fixes applied, one additional critical bug found and fixed during that work)
