# Story 012: Menagerie Attraction Material (Lure)

> **Epic**: Epic 03 — Core Economy
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/resource-economy.md`
**Requirement**: `TR-econ-???` *(no TR-ID exists yet)*

**ADR Governing Implementation**: ADR-0017 (Resource Economy Drop Resolution)
**ADR Decision Summary**: The lure roll is resolved by the same mission-scoped node as all other drop math, but per GDD Rule 6 uses `monster_died.menagerie_attraction_drop_chance` directly, unscaled — no Resource-subclass schema needed for this specific mechanic. The GDD's own Open Questions still flag that `menagerie_lure`'s naming/consumption model may need co-design with the (not yet authored) Menagerie GDD — this story implements only the drop-chance mechanic, provisional pending that future coordination.

**Engine**: Godot 4.6.2 / GDScript | **Risk**: Unassessed
**Engine Notes**: None yet.

**Control Manifest Rules (this layer)**:
- Required (Global Rules): gameplay values must be data-driven — `menagerie_attraction_drop_chance` is per-monster-type data, not hardcoded

---

## Acceptance Criteria

*From GDD `design/gdd/resource-economy.md`, scoped to this story:*

- [x] **AC-08**: GIVEN `menagerie_attraction_drop_chance=0.5` and `wave_reward_scalar=4.768`, WHEN the lure roll resolves, THEN it uses `0.5` unscaled.

---

## Implementation Notes

*Derived from ADR-0017 + GDD Rule 6:* this is a deliberately simple, isolated rule: the lure roll is a flat chance that must NOT be multiplied by `wave_reward_scalar` under any circumstance — it's a rare-find mechanic, not part of the wave-escalating economy. The most likely implementation bug here is accidentally routing this through the same code path as Formula 2/3's wave-scaled math; keep it structurally separate.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008/009: the wave-scaled quantity/quality math (explicitly NOT applicable to the lure roll)
- Menagerie System's actual consumption of `menagerie_lure` (Menagerie has no GDD yet — out of this epic entirely)

---

## QA Test Cases

- **AC-08**: Lure roll uses unscaled chance
  - Given: `menagerie_attraction_drop_chance=0.5`, `wave_reward_scalar=4.768` (a late-wave value)
  - When: the lure roll resolves
  - Then: the roll uses exactly 0.5, with no multiplication by `wave_reward_scalar`
  - Edge cases: run the same test at wave 1 (`wave_reward_scalar=1.00`) and confirm the roll chance is identical (0.5) at both wave extremes — this is the core regression this test guards against

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/resource_economy/menagerie_attraction_material_test.gd` — must exist and pass

**Status**: [x] Created and passing — `tests/unit/resource_economy/menagerie_attraction_material_test.gd` (7 tests)

---

## Dependencies

- Depends on: Story 010 (drop table schema, since `menagerie_attraction_drop_chance` arrives via the same `monster_died` payload path)
- Unlocks: None currently identified

---

## Completion Notes

**Completed**: 2026-07-16
**Criteria**: 1/1 passing (AC-08, verified via structural signature exclusion + statistical proof + deterministic e2e test at both wave extremes)
**Deviations**: None
**Test Evidence**: Logic — `tests/unit/resource_economy/menagerie_attraction_material_test.gd` (7 tests, all passing). Full project suite: 777/777 passing, 0 errors, 0 failures, 61/61 suites — no regression.
**Code Review**: Complete — APPROVED (godot-gdscript-specialist: MINOR ISSUES, non-blocking test redundancy noted; qa-tester: GAPS found and closed same-session by adding `test_resource_economy_guaranteed_lure_and_guaranteed_drop_entry_emit_two_independent_materials_earned`, proving the lure roll and a normal drop-table entry emit two independent, correctly-attributed `materials_earned` events on the same kill).
**Notes**: `quantity=1` for the lure is an implementation interpretation, not an explicit GDD formula — the GDD only specifies a drop chance, and its own Open Questions table already flags `menagerie_lure`'s naming/consumption model as provisional pending future Menagerie System co-design. No `Inventory` consumer wiring exists for `menagerie_lure` (or any `materials_earned` material_id) yet — this is a pre-existing, epic-wide gap correctly out of scope for this story.
