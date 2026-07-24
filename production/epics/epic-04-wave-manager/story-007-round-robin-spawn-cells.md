# Story 007: Round-Robin Spawn Cell Assignment + Modulo Wrap

> **Epic**: Wave Manager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-05-16
> **Estimate**: 3h

## Context

**GDD**: `design/gdd/wave-manager.md`
**Requirement**: `TR-wave-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Wave Manager FSM Architecture
**ADR Decision Summary**: Each `WaveSpawnEntry.spawn_cell_index` is either a positive index into `Grid.get_spawn_cells()` (modulo-wrapped if out of range) or `-1` for round-robin auto-assignment. The round-robin counter resets to 0 at every WAVE_ACTIVE entry (wave-scoped, not mission-scoped).

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Plain integer modulo (`%`) — no post-cutoff risk.

**Verified against the actual codebase (2026-07-04)**: `wave_manager.gd` currently has a single hardcoded `_spawn_cell: Vector2i` field, used identically for every spawn entry in the wave (no per-entry cell selection at all, no round-robin counter, no modulo wrap). Story 006 introduces the real `_spawn_cells: Array[Vector2i]` from `Grid.get_spawn_cells()` — this story is the first to actually consume it for per-entry cell assignment.

**Control Manifest Rules (Feature layer)**:
- Required: MVP missions must use exactly one SPAWN cell — round-robin/modulo logic must still be implemented (the Voronoi partition is computed regardless per the manifest), but in practice `_spawn_cells.size() == 1` for all MVP missions, meaning every entry resolves to the same single cell until multi-SPAWN ships post-MVP. Implement the general N-cell logic anyway — don't special-case for N=1, since that would silently break when multi-SPAWN lands.

---

## Acceptance Criteria

*From `design/gdd/wave-manager.md`, scoped to this story:*

- [ ] Rule 15b: For each `WaveSpawnEntry`, determine `spawn_cell`: if `spawn_cell_index >= 0` → `spawn_cells[spawn_cell_index % spawn_cells.size()]`; if `-1` → `spawn_cells[_round_robin_counter % spawn_cells.size()]` (increment `_round_robin_counter` after use).
- [ ] Rule 10f: `_round_robin_counter` resets to 0 at every WAVE_ACTIVE entry (wave-scoped).
- [ ] AC-10: GIVEN a WaveScript with 4 entries (`spawn_cell_index: [2, -1, -1, -1]`) on a 3-spawn-cell map `[A, B, C]`, WHEN WAVE_ACTIVE begins, THEN payloads show `spawn_cell`: `[C (2%3), A (counter 0), B (counter 1), C (counter 2)]`. On the next wave's WAVE_ACTIVE, round-robin resets — the first `-1` entry uses cell A again.
- [ ] AC-35: A positive `spawn_cell_index` exceeding `spawn_cells.size() - 1` wraps via modulo, with a warning logged containing `"spawn_cell_index [N] out of range"`. Verify with indices 3, 5, 7 against a 3-cell map (wrapping to 0, 2, 1 respectively).
- [ ] Performance: No performance impact expected — one modulo operation per spawn entry, no new iteration.

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines and GDD Rule 15b:*

```gdscript
var _round_robin_counter: int = 0  # new field, reset in _enter_wave_active() and on mission_launched (Story 006)

func _enter_wave_active() -> void:
    _wave_index += 1
    _enemies_alive = 0
    _all_spawns_fired = false
    _spawn_active = true
    _round_robin_counter = 0  # Rule 10f: wave-scoped, not mission-scoped
    _wave_reward_scalar = pow(1.0 + difficulty_growth_rate, float(_wave_index - 1))  # Story 004
    GEventBus.wave_started.emit(_wave_index, _total_wave_count(), _wave_reward_scalar)
    _run_spawn_sequence()


## Rule 15b: resolves the real spawn_cell for one WaveSpawnEntry. Called once
## per entry from inside _run_spawn_sequence()'s loop, replacing the current
## hardcoded _spawn_cell field entirely.
func _resolve_spawn_cell(entry: WaveSpawnEntry) -> Vector2i:
    if _spawn_cells.is_empty():
        push_error("WaveManager: _resolve_spawn_cell() called with empty _spawn_cells — should have been caught by Story 006's mission_launched guard.")
        return Vector2i(-1, -1)
    if entry.spawn_cell_index >= 0:
        var index: int = entry.spawn_cell_index
        if index >= _spawn_cells.size():
            push_warning("WaveManager: spawn_cell_index %d out of range — wrapping to %d." % [index, index % _spawn_cells.size()])
        return _spawn_cells[index % _spawn_cells.size()]
    else:
        var cell: Vector2i = _spawn_cells[_round_robin_counter % _spawn_cells.size()]
        _round_robin_counter += 1
        return cell
```

Update `_run_spawn_sequence()`'s spawn loop to call `_resolve_spawn_cell(entry)` per entry instead of using the flat `_spawn_cell` field:

```gdscript
for entry: WaveSpawnEntry in _wave_spawn_entries:
    if not _spawn_active: return
    if entry.pre_delay > 0.0:
        await get_tree().create_timer(entry.pre_delay).timeout
        if not is_instance_valid(self): return
        if not _spawn_active: return
        if _phase != Phase.WAVE_ACTIVE: return
    var spawn_cell: Vector2i = _resolve_spawn_cell(entry)
    GEventBus.monster_spawn_requested.emit(
        entry.to_payload(_wave_index, _wave_reward_scalar, spawn_cell, _is_penultimate_wave())
    )
```

**`WaveSpawnEntry.spawn_cell_index` field**: confirm this field exists on the current `WaveSpawnEntry` class (`src/gameplay/wave_spawn_entry.gd`) — it was not present in the version read during epic authoring (only `monster_id`, `pre_delay`, `difficulty_tier` exist today). Add `@export var spawn_cell_index: int = -1` as part of this story (or coordinate with Story 006 if it's authoring the Resource conversion first — avoid duplicate/conflicting edits to the same file).

---

## Out of Scope

- **Story 006**: `_spawn_cells` population from `Grid.get_spawn_cells()`, and the empty-spawn-cells guard (AC-36) — this story assumes `_spawn_cells` is already non-empty by the time `_resolve_spawn_cell()` runs
- **Story 004**: `is_penultimate_wave`/`wave_reward_scalar` — referenced in the call site shown above but implemented by that story

---

## QA Test Cases

- **AC-10**: Round-robin + positive-index mix, wave-scoped reset
  - Given: 3 spawn cells `[A, B, C]`; a WaveScript with 4 entries, `spawn_cell_index: [2, -1, -1, -1]`
  - When: WAVE_ACTIVE begins
  - Then: payloads show `spawn_cell: [C, A, B, C]` in order (entry 1 uses index 2%3=2→C; entries 2-4 round-robin from counter 0,1,2 → A,B,C)
  - Edge case: on the SUBSEQUENT wave's WAVE_ACTIVE (repeat the same WaveScript), the first `-1` entry uses cell A again — confirms `_round_robin_counter` reset to 0, not carried over from the previous wave

- **AC-35**: Modulo wrap for out-of-range positive index
  - Given: 3 spawn cells (indices 0-2)
  - When: an entry has `spawn_cell_index = 5`
  - Then: `spawn_cell == spawn_cells[5 % 3]` (index 2); warning logged containing "spawn_cell_index [5] out of range"
  - Repeat for `spawn_cell_index = 3` (wraps to 0) and `spawn_cell_index = 7` (wraps to 1) — verifies modulo correctness across multiple wrap points, not just one

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/wave_manager/wave_manager_spawn_cell_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 (`_spawn_cells` population **and** the `WaveSpawnEntry` `RefCounted`→`Resource` conversion — Story 006 must land first, since this story adds `spawn_cell_index` to the same `wave_spawn_entry.gd` file and a conflicting edit order would collide), Story 004 (`is_penultimate_wave`/`wave_reward_scalar` used in the same call site)
- Unlocks: Story 008 (mission scene assembly needs real per-entry spawn cell resolution, not a flat hardcoded cell)

---

## Completion Notes
**Completed**: 2026-07-05
**Criteria**: 5/5 passing (all COVERED, no deferred items)
**Deviations**: ADVISORY (x6) — (1) the story's `_enter_wave_active()` pseudocode was a stale full reconstruction reintroducing Story 002/004 logic — corrected to add only the round-robin reset line; (2) `_round_robin_counter` already existed as a Story 006 field, not re-declared; (3) the warning-message format's missing brackets (didn't match AC-35's literal wording) — corrected; (4) a real regression found and fixed — 3 pre-existing tests broke once `_spawn_cells` became load-bearing, fixed with fixture injection; (5) code review found and fixed two gaps — an undocumented-negative-value (`spawn_cell_index < -1`) validation gap now warns, and a test that didn't verify its own "no warning" claim now genuinely does; (6) the recurring source-inspection performance-test pattern (3rd occurrence: Stories 004/006/007) flagged as a process item for a separate follow-up, not fixed here.
**Test Evidence**: `tests/unit/wave_manager/wave_manager_spawn_cell_test.gd` — 12/12 passing; full `wave_manager` suite (unit+integration) 109/109 passing, 0 errors, 0 failures
**Code Review**: Complete — APPROVED (after one APPROVED WITH SUGGESTIONS round; both suggestions applied)
