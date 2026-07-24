# Story 003: Deactivation & Overlap Stacking

> **Epic**: Epic 06 — Mission Combat Extensions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/constellation.md`
**Requirement**: `TR-const-001`

**ADR Governing Implementation**: ADR-0022 (Constellation Pattern-Detection Data Structure)
**ADR Decision Summary**: A reverse index `_tower_membership: Dictionary[int, Array[String]]` (tower_id → pattern_ids) makes multi-instance deactivation an O(membership) lookup instead of a full active-instance scan. On `tower_removed`/`tower_destroyed`, every affected `pattern_id` is deactivated and scrubbed from both the active-instance table and every member tower's reverse-index entry.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `Dictionary`/`Array` are reference types in GDScript — the affected-`pattern_id` list must be `.duplicate()`d before iterating, since `_deactivate_instance()` mutates the same array during the loop (ADR-0022 Risks, godot-specialist validation).

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0022 directly.
- Forbidden: Never iterate `_tower_membership.get(tower_id, [])` directly while `_deactivate_instance()` mutates it — causes a mutate-during-iterate skip that silently drops a deactivation (ADR-0022 Risks).
- Guardrail: `_deactivate_instance()` must scrub the departing `pattern_id` from *every* member tower's reverse-index entry, not only the triggering tower's.

---

## Acceptance Criteria

*From GDD `design/gdd/constellation.md`, scoped to this story:*

- [ ] AC-10 — `tower_removed` on an active instance's member fires deactivation with correct reason
- [ ] AC-11 — `tower_destroyed` on an active instance's member fires deactivation with correct reason
- [ ] AC-13 — Destroying a tower shared by two active instances fires one deactivation per instance

---

## Implementation Notes

*Derived from ADR-0022 Implementation Guidelines:*

```gdscript
func _on_tower_removed_or_destroyed(tower_id: int, reason: String) -> void:
    # .duplicate() required: _deactivate_instance() mutates the same array
    # in place (scrubbing pattern_id from every member's entry, including
    # this one), which would cause a mutate-during-iterate skip otherwise.
    var affected: Array[String] = _tower_membership.get(tower_id, []).duplicate()
    for pattern_id in affected:
        _deactivate_instance(pattern_id, reason)
    _tag_cache.erase(tower_id)
```

- `_deactivate_instance(pattern_id, reason)`: look up the instance; if found, scrub `pattern_id` from every member tower's `_tower_membership` entry (erasing the tower's entry entirely if it becomes empty), erase the instance from `_active_instances`, then emit `constellation_deactivated(pattern_id, reason)`.
- `reason` must be exactly `"tower_removed"` or `"tower_destroyed"` depending on the triggering event.
- If a tower belongs to two or more currently-`ACTIVE` instances, one `constellation_deactivated` fires per affected instance — never a single combined event.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: activation-side lifecycle
- Story 006: phase-gating of when formation/breaking can occur (Core Rule 9)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-10**: `tower_removed` deactivation
  - Given: an `ACTIVE` `triad_line@(2,4)` instance (per Story 001's AC-1 setup)
  - When: `tower_removed` fires for the tower at `(3,4)`
  - Then: `constellation_deactivated("triad_line@(2,4)", "tower_removed")` emits exactly once

- **AC-11**: `tower_destroyed` deactivation
  - Given: an `ACTIVE` `triad_line@(2,4)` instance
  - When: `tower_destroyed` fires for the tower at `(4,4)` (simulating a WAVE_ACTIVE mid-wave kill)
  - Then: `constellation_deactivated("triad_line@(2,4)", "tower_destroyed")` emits exactly once

- **AC-13**: Shared-member destruction fires one deactivation per instance
  - Given: `triad_line@A` and `l_corner@B` both `ACTIVE`, sharing one common member tower
  - When: `tower_destroyed` fires for that shared tower
  - Then: exactly two `constellation_deactivated` events emit in the same dispatch — one per `pattern_id`, both `reason = "tower_destroyed"` — not a single combined or batched event
  - Edge cases: verify the reverse index correctly resolves both `pattern_id`s from a single `tower_id` lookup

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/constellation/deactivation-overlap-stacking_test.gd` — must exist and pass

**Status**: [x] Complete — live-verified via gdUnit4 (2026-07-18, Sprint 6 S6-08)

---

## Dependencies

- Depends on: Story 002 (DONE) — deactivation requires an active instance to exist first
- Unlocks: Story 006

**Unblocked**: ADR-0022 accepted 2026-07-18 (Sprint 6, S6-02).
