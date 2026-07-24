# Story 008: Drop Occurrence & Quantity Resolution

> **Epic**: Epic 03 — Core Economy
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/resource-economy.md`
**Requirement**: `TR-econ-???` *(no TR-ID exists yet — `/architecture-review` has not run against this GDD)*

**ADR Governing Implementation**: ADR-0017 (Resource Economy Drop Resolution)
**ADR Decision Summary**: Resource Economy is a scene-instanced node (not an Autoload), mission-scoped like Wave Manager (ADR-0012), holding exactly one mutable field (`_menagerie_quality_bonus`). All quantity/quality math is otherwise a pure function of the incoming `monster_died` payload plus that cached scalar.

**Engine**: Godot 4.6.2 / GDScript | **Risk**: Unassessed
**Engine Notes**: None yet.

**Control Manifest Rules (this layer)**:
- Required (Global Rules): gameplay values must be data-driven — `base_drop_rate`, `base_quantity` must come from `DropEntry` Resource data, never hardcoded
- Required (Global Rules): no direct runtime Node reference — this system reacts to `monster_died` via EventBus only

---

## Acceptance Criteria

*From GDD `design/gdd/resource-economy.md`, scoped to this story:*

- [x] **AC-01**: GIVEN a kill with `base_quantity=1`, `wave_reward_scalar=4.768`, `menagerie_quality_bonus=1.3` and a successful drop roll, WHEN `monster_died` resolves, THEN `materials_earned` reports quantity `6` (`round(1×4.768×1.3) = round(6.198)`).
- [x] **AC-02**: GIVEN inputs that round to less than 1, WHEN a successful drop resolves, THEN reported quantity is floored to `guaranteed_min_quantity=1`, never 0.
- [x] **AC-12 [Statistical]**: GIVEN `base_drop_rate=0.45` over a 10,000-kill sample, WHEN drops are tallied, THEN the observed rate falls within ±2% of 45%.

---

## Implementation Notes

*Derived from ADR-0017:* Formula 1 (drop occurrence) and Formula 2 (quantity) are both fully specified in the GDD with worked examples — transcribe them directly, not reinterpret. Rounding must use `round()` exactly once per kill per drop-table entry (Rule 9) — never accumulate fractional amounts across kills before rounding. `base_quantity` and `base_drop_rate` are read from `DropEntry`/`DropTableResource` (Story 010).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: quality-tier probability roll (separate formula, separate story)
- Story 010: drop table data schema and `GameDataRegistry` lookup mechanics
- Story 011: despawn suppression (BOSS breach / force-clear no-drop rule)

---

## QA Test Cases

- **AC-01**: Quantity formula worked example
  - Given: `base_quantity=1`, `wave_reward_scalar=4.768`, `menagerie_quality_bonus=1.3`, a successful drop roll
  - When: `monster_died` resolves
  - Then: `materials_earned` reports quantity 6
  - Edge cases: verify the same formula at wave 1 (`wave_reward_scalar=1.00`) produces the expected minimum-scale result

- **AC-02**: Quantity floor enforcement
  - Given: input values that round to less than 1 (e.g., very low `base_quantity` combined with wave 1 scalar)
  - When: a successful drop resolves
  - Then: reported quantity is floored to 1, never 0
  - Edge cases: confirm the floor applies only on a *successful* drop roll — a failed roll (per Formula 1) still yields 0 total, which is correct and distinct from this floor

- **AC-12 [Statistical]**: Drop occurrence rate
  - Given: `base_drop_rate=0.45` and a 10,000-kill simulated sample
  - When: drops are tallied
  - Then: observed rate falls within ±2% of 45% (i.e., 43%-47%)
  - Edge cases: this test requires a fixed RNG seed or a statistically significant sample size to avoid flaky failures — QA must define the exact test harness approach

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/resource_economy/drop_occurrence_quantity_test.gd` — must exist and pass

**Status**: [x] Created — 9/9 passing (759/759 full project suite, live-verified, Godot 4.6.2.stable headless)

---

## Dependencies

- Depends on: Story 010 (drop table schema — quantity resolution needs a `DropEntry` to read `base_quantity` from)
- Unlocks: None currently identified

---

## Completion Notes

**Completed**: 2026-07-16
**Criteria**: 3/3 passing (AC-01, AC-02, AC-12)
**Deviations**: Advisory only
- Applied a prerequisite ADR-0017/`DropTableResource` schema fix — Formula 1 requires `base_drop_rate` as per-table data, missing from the original schema Story 010 shipped. Amended ADR-0017 and added the field with validation.
- **Time-sensitive**: `monster_manager.gd` already emits `monster_died` for `wave_end` force-clears; this story doesn't filter it (Story 011's explicit scope) — a temporary GDD Rule 5/AC-06/AC-07 violation until Story 011 lands (next-but-one in the planned sequence). Logged as tech debt.
- `materials_earned`'s `source` field semantics (using `kill_source`) not explicitly GDD-confirmed. Logged as tech debt.
- Two testability gaps (multi-entry-per-table Rule 9, realistic-rate-in-pipeline). Logged as tech debt.
**Test Evidence**: Logic — `tests/unit/resource_economy/drop_occurrence_quantity_test.gd`, 9/9 passing
**Code Review**: Complete — verdict APPROVED WITH SUGGESTIONS (`/code-review`, 2026-07-16)
