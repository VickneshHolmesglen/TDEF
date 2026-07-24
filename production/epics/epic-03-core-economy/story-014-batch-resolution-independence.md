# Story 014: Batch Resolution Independence

> **Epic**: Epic 03 — Core Economy
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/resource-economy.md`
**Requirement**: `TR-econ-002` — "DropTableResource/DropEntry schema + drop quantity/quality Formulas 1-4"

**ADR Governing Implementation**: ADR-0017 (Resource Economy Drop Resolution)
**ADR Decision Summary**: ADR-0017 confirms Resource Economy subscribes to both `monster_died` and `monsters_died_batch`, resolving each identically per-entry. Per godot-specialist validation during authoring: this relies on a pre-existing, project-wide exclusivity guarantee (a kill fires exactly one of the two signals, never both) already confirmed in shipped Wave Manager code — a violation would silently double-award materials/gold, so a dedicated unit test is required (see ADR-0017 Risks/Validation Criteria).

**Engine**: Godot 4.6.2 / GDScript | **Risk**: LOW, consistent with ADR-0001's already-Accepted batching design
**Engine Notes**: See ADR-0001 and `docs/architecture/control-manifest.md`'s Foundation Layer Rules — "Batch events at ≥ 20 firings per frame: switch to a single deferred `{event_name}_batch` event".

**Control Manifest Rules (this layer)**:
- Required (Foundation Layer, ADR-0001): Wave Manager owns the `monster_died` batch accumulator — Resource Economy is a subscriber only, must not implement its own competing batch logic

---

## Acceptance Criteria

*From GDD `design/gdd/resource-economy.md`, scoped to this story:*

- [x] **AC-11**: GIVEN `monsters_died_batch` with 20+ entries, WHEN each resolves, THEN each is rounded independently — no fractional carryover between entries.

---

## Implementation Notes

*Cannot be derived from an ADR — none exists specifically for Resource Economy, though ADR-0001 governs the batching mechanism itself.* Per the GDD's Edge Cases: the batch is purely an EventBus transport optimization from Resource Economy's perspective — each entry must be resolved exactly as if dispatched individually, in array order, with no shared rounding state carried between entries in the same batch.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: the per-kill quantity/rounding formula itself (this story only verifies it holds under batch dispatch)
- Any change to Wave Manager's batch accumulator (owned by Wave Manager per ADR-0001, out of this epic's scope)

---

## QA Test Cases

- **AC-11**: Independent per-entry rounding under batch dispatch
  - Given: `monsters_died_batch` fires with 20+ entries in one frame
  - When: each entry resolves
  - Then: each entry's quantity is rounded independently (per Story 008's formula) — no fractional remainder is carried over or shared between entries
  - Edge cases: construct a test case where naive fractional-accumulation-then-round would produce a *different* total than per-entry rounding, to prove the implementation isn't accidentally batching the math itself; additionally assert no double-award occurs if `monster_died` and `monsters_died_batch` both somehow reference the same `entity_id` (ADR-0017's flagged exclusivity-assumption risk)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/resource_economy/batch_resolution_independence_test.gd` — must exist and pass

**Status**: [x] Created and passing (6/6 test cases, 0 errors, 0 failures — 3 additional tests added during code review: empty-batch, single-entry boundary, mixed-drop-table-id)

---

## Dependencies

- Depends on: Story 008 (quantity/rounding formula)
- Unlocks: None currently identified

---

## Completion Notes

**Completed**: 2026-07-16
**Criteria**: 1/1 passing (AC-11 — verified via naive-accumulation-divergence proof, batch-vs-individual full-payload match, and boundary/mixed-table cases)
**Deviations**: None. This story was verify-only — no changes to `resource_economy.gd` were needed; its existing per-entry batch loop already satisfied AC-11 by construction.
**Test Evidence**: Logic — `tests/unit/resource_economy/batch_resolution_independence_test.gd` (6 tests, all passing). Full project suite: 783/783 passing, 0 errors, 0 failures, 62/62 suites — no regression.
**Code Review**: Complete — APPROVED (godot-gdscript-specialist: MINOR ISSUES → resolved; qa-tester: GAPS → resolved).
**Notes**: Code review surfaced a genuine internal inconsistency in ADR-0017 itself — its Validation Criteria demanded "no double-award" for the `monster_died`/`monsters_died_batch` exclusivity risk, contradicting its own Decision section's stateless-calculator design. ADR-0017 was amended (Validation Criteria, Risk mitigation, Last Verified log) to match the accepted design: Resource Economy documents the failure mode via a tripwire test; the actual exclusivity invariant is an emitter-side (Monster System/Wave Manager) responsibility, tracked as **TD-econ-006** since no test anywhere currently verifies it.
