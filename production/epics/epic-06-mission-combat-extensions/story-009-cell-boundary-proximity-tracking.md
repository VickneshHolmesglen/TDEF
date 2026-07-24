# Story 009: Cell-Boundary Proximity Tracking

> **Epic**: Epic 06 — Mission Combat Extensions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/tower-mastery.md`
**Requirement**: `TR-towermast-001`

**ADR Governing Implementation**: ADR-0029 (Tower Mastery Proximity-Detection Strategy), ADR-0005 (Grid System Data Model), ADR-0020 (Direct-Autoload-call exception pattern)
**ADR Decision Summary**: `_signatures_in_range` is recomputed only on `hero_position_changed` (cell-boundary crossing) or the 4 tower lifecycle events — never every physics frame. This is the GDD's own load-bearing performance claim (Rule 9) and the architectural reason this system's engine risk is MEDIUM rather than HIGH-by-default.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM — architecture confirmed sound by ADR review; live profiling still outstanding (Story 012)
**Engine Notes**: `Grid.get_occupied_cells_in_radius()`/`Grid.get_occupant()` are Criterion A direct calls (ADR-0020), invoked only on cell-boundary crossing or tower lifecycle events, never per-frame.

**Control Manifest Rules (this layer)**:
- Required: Read API is a documented direct-call exception to EventBus-only — source: ADR-0005.
- Forbidden: Never recompute `_signatures_in_range` on an arbitrary `_physics_process` tick — only on `hero_position_changed` or the 4 tower lifecycle events (ADR-0029 Alternatives Considered, Alternative B — rejected).
- Guardrail: `world_to_cell()`/`is_in_bounds()` must be checked before calling `get_occupied_cells_in_radius` — Grid's own GDD requires callers to guard out-of-bounds cells, not Grid itself (EC-1).

---

## Acceptance Criteria

*From GDD `design/gdd/tower-mastery.md`, scoped to this story:*

- [x] AC-24 — SCOUT phase transition halts all accrual same-frame; `hero_position_changed` during SCOUT never changes `mastery_time`
- [x] AC-25 — Out-of-bounds hero cell skips the `signatures_in_range` recompute entirely, retains previous cache, no crash

---

## Implementation Notes

*Derived from ADR-0029 Implementation Guidelines:*

```gdscript
func _on_tower_placed(event: TowerPlacedEvent) -> void:
    var sig := "%s|%s|%s|%s" % [event.foundation_component_id, event.weapon_component_id,
                                  event.focus_component_id, event.power_component_id]
    _active_signature_by_tower[event.tower_id] = sig
    _recompute_signatures_in_range()   # tower lifecycle event, immediate recompute (Rule 11)
```

- Subscribe to `mission_phase_changed` and cache the current phase locally. Accrual is gated to `WAVE_ACTIVE`/`INTERMISSION` only — SCOUT never accrues, mirroring Hero's own phase gate (Rule 15 precedent).
- On `hero_position_changed`, recompute the qualifying-tower set by calling `Grid.get_occupied_cells_in_radius(grid_position, TOWER_MASTERY_PROXIMITY_RADIUS)`, resolving each occupied cell to a `tower_id` via `Grid.get_occupant()`, and grouping by `_active_signature_by_tower[tower_id]` into `_signatures_in_range: Dictionary[String, bool]`.
- Also recompute immediately (using the hero's last-known `grid_position`) on any of the 4 tower lifecycle events (`tower_placed`, `tower_removed`, `tower_destroyed`, `tower_component_equipped`) — a tower vanishing or appearing under a stationary hero must be reflected the same frame, no grace period.
- Grid Boundary guard: if `Grid.is_in_bounds(hero_cell)` is false, skip the recompute entirely and retain the previously cached `_signatures_in_range` — never pass an invalid cell to the Grid API.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: the `build_signature` derivation this story's cache consumes (must land first)
- Story 010: per-frame accrual/progress/unlock logic that consumes `_signatures_in_range`

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-24**: SCOUT phase halts accrual
  - Given: `mission_phase_changed` fires to `SCOUT` while any signature is `TRACKED_ACCRUING`
  - When: the phase transitions
  - Then: all accrual halts that same frame — no partial-frame `mastery_time` increment leaks past the boundary — and `hero_position_changed` events during `SCOUT` never change any `mastery_time` entry

- **AC-25**: Out-of-bounds cell guard
  - Given: hero's world position converts to a cell for which `Grid.is_in_bounds(hero_cell)` returns `false` (e.g. transient edge-of-map position)
  - When: `hero_position_changed` fires with that out-of-bounds cell
  - Then: Tower Mastery skips the `signatures_in_range` recompute entirely, retains its previously cached set, and does not call `Grid.get_occupied_cells_in_radius` with the invalid cell — no crash, no exception, no stale-but-wrong state change

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/tower-mastery/cell-boundary-proximity-tracking_test.gd` — 9 tests covering AC-24, AC-25, and the 4 tower-lifecycle-event immediate-recompute behaviors from the Implementation Notes. All passing.

**Status**: [x] Created and passing (2026-07-19). Full project regression re-run: 1059/1060 (the sole failure is the same pre-existing, unrelated Menagerie `CreatureInstance.CreatureState` enum-value mismatch, `TD-menag-006` — untouched by this story).

---

## Dependencies

- Depends on: Story 007 (radius), Story 008 (`build_signature` via event payload)
- Unlocks: Story 010

**Unblocked**: ADR-0029 accepted 2026-07-18 (Sprint 6, S6-02).

**Implemented (2026-07-19, Sprint 7 S7-06)**: `tower_mastery.gd` now subscribes to `tower_removed`/`tower_destroyed` in addition to `tower_placed`/`tower_component_equipped`; all 4 handlers call a new `_recompute_if_hero_known()` helper that immediately recomputes `_signatures_in_range` against the hero's last-known in-bounds cell (`_last_hero_cell`/`_has_hero_cell`), so a tower appearing/vanishing/swapping under a stationary hero is reflected the same frame. `tower_removed`/`tower_destroyed` also erase the affected `tower_id` from `_active_signature_by_tower`. AC-24/AC-25 were already satisfied by Story 007's existing `tick()` phase-gate and `_on_hero_position_changed()` bounds-guard respectively — both now have explicit regression tests. Unblocks Story 010.
