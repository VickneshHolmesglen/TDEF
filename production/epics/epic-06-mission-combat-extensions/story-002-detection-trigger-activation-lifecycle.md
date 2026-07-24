# Story 002: Detection Trigger & Activation Lifecycle

> **Epic**: Epic 06 — Mission Combat Extensions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/constellation.md`
**Requirement**: `TR-const-001`

**ADR Governing Implementation**: ADR-0022 (Constellation Pattern-Detection Data Structure)
**ADR Decision Summary**: Detection recheck runs synchronously within the same dispatch as the triggering `tower_placed`/`tower_removed`/`tower_destroyed` event — never deferred to next frame, never batched across events. An `_active_instances: Dictionary[String, ConstellationInstance]` keyed by `pattern_id` is updated incrementally, never fully rescanned.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: All three per-event updates (tag cache, membership, active-instance table) must occur within one synchronous handler call with no `await` boundary, per ADR-0022's Risks mitigation.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0022 directly.
- Forbidden: No `await` between the three structure updates for a single event (ADR-0022 Risks — desync risk otherwise).
- Guardrail: `constellation_activated` emits exactly once per newly-satisfied instance; a duplicate recheck triggered by an unrelated later placement must not re-fire it while the instance remains `ACTIVE`.

---

## Acceptance Criteria

*From GDD `design/gdd/constellation.md`, scoped to this story:*

- [ ] AC-7 — Recheck resolves synchronously within the same dispatch, not deferred to next frame
- [ ] AC-8 — Two independent placement events each trigger their own recheck (no batching across events)
- [ ] AC-9 — Activation event fires exactly once with correctly-composed `pattern_id`
- [ ] AC-12 — Two overlapping instances activate independently from a single placement event
- [ ] AC-26 — Simultaneous multi-shape satisfaction: no precedence, both bonuses independently correct

---

## Implementation Notes

*Derived from ADR-0022 Implementation Guidelines:*

- `_on_tower_placed(event)`: update `_tag_cache`, call `Grid.get_occupied_cells_in_radius(event.grid_position, PATTERN_SEARCH_RADIUS)`, then `_recheck_patterns_near(...)` — all in one synchronous call stack.
- When a recheck newly satisfies all N cells of a shape+anchor+tag combination, add the `ConstellationInstance` to `_active_instances` and the reverse index `_tower_membership`, then emit `constellation_activated(pattern_id, grid_origin, bonus_type, bonus_value)` exactly once.
- If a single event completes two or more instances simultaneously (e.g. a shared-member `triad_line` and `l_corner`), emit one `constellation_activated` per instance — no summation, no suppression, no precedence between shapes (Constellation never sums; Tower System sums per its own subscription model).
- No test double or handler may introduce an `await`/deferred call between event receipt and emission — this is what AC-7/AC-8 actually assert.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: shape/orientation/eligibility matching itself (this story assumes matching already works and focuses on lifecycle/timing)
- Story 003: deactivation logic and the reverse-index lookup used to fire it

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-7**: Synchronous recheck
  - Given: `(2,4)`,`(3,4)` already occupied by identically-tagged eligible towers, no `_physics_process` tick or `await` between event and assertion
  - When: `tower_placed` emitted directly for a third eligible same-tag tower at `(4,4)`, no frame advance
  - Then: `constellation_activated` has already fired by the time `emit_signal()` returns control to the caller

- **AC-8**: No batching across events
  - Given: empty board
  - When: two `tower_placed` events emitted back-to-back in one test — first completes nothing, second completes `triad_line`
  - Then: exactly one `constellation_activated` emits (after the second event), no coalescing into a single deferred recheck

- **AC-9**: Exactly-once activation with correct `pattern_id`
  - Given: `(3,5)`,`(4,5)`,`(5,5)`,`(6,5)` occupied by identically-tagged eligible towers forming `quad_line`
  - When: the 4th tower's `tower_placed` fires
  - Then: `constellation_activated("quad_line@(3,5)", (3,5), bonus_type, 0.135)` emits exactly once; a later unrelated placement's recheck does not re-fire it while `ACTIVE`

- **AC-12**: Overlapping instances activate independently
  - Given: a single `tower_placed` simultaneously completes both a `triad_line` and an `l_corner` sharing member towers
  - When: the completing event resolves
  - Then: both `constellation_activated` events emit in the same dispatch — two separate events, not one combined — with no summation between them

- **AC-26**: No precedence between simultaneously-satisfied shapes
  - Given: same setup as AC-12
  - When: the event resolves
  - Then: both events carry their own independently-correct `bonus_value` (0.100 and 0.155 respectively) — no suppression, averaging, or picking one shape over the other

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/constellation/detection-trigger-activation-lifecycle_test.gd` — must exist and pass

**Status**: [x] Complete — live-verified via gdUnit4 (2026-07-18, Sprint 6 S6-08)

---

## Dependencies

- Depends on: Story 001 (shape/eligibility matching must exist for activation to have anything to activate)
- Unlocks: Story 003

**Unblocked**: ADR-0022 accepted 2026-07-18 (Sprint 6, S6-02).
