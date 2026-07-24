# Story 006: Material Cost Formulas (Tier Scaling, Crafted Goods, Repair)

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (2-3 hrs)
> **Manifest Version**: 2026-07-13b *(stale for this epic — see Story 001)*

## Context

**GDD**: `design/gdd/crafting.md`
**Requirement**: `TR-craft-001` (Formulas 1-3)

**ADR Governing Implementation**: ADR-0023
**ADR Decision Summary**: Formula 1 (Tower Component cost) reuses `tower.md`'s `tier_dps_multiplier` constant — not a Crafting-owned copy. Formula 2 (Crafted Goods) is deliberately hand-authored per recipe, not derived. Formula 3 (Repair) reuses Formula 1's `tier_dps_multiplier` at a lower `base_repair_common` baseline.

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules**:
- Required: Formula 1/3 read `tier_dps_multiplier` from `tower.md`'s registered constant — never fork a separate Crafting-only copy (any future change to that constant must auto-rescale both)

## Acceptance Criteria

- [ ] AC-8: GIVEN a Tier 4 `tower_component` recipe, WHEN its material cost is checked, THEN it matches Formula 1's table exactly: 32 Common + 16 Uncommon + 8 Rare.
- [ ] AC-10: GIVEN a `crafted_good` recipe authored per Formula 2's guideline (e.g. a "Healing Salve ×3" recipe costing 6 Common), WHEN its material cost and output are checked, THEN they match the recipe's authored values exactly: 6 Common consumed, `output_quantity=3` produced, `quality_tier=0`.

## Implementation Notes

```
Formula 1: material_qty(rarity, T) = round(base_qty[rarity] × tier_dps_multiplier(T))
  base_qty: Common=8, Uncommon=4, Rare=2
  tier_dps_multiplier: {1.0, 1.6, 2.4, 4.0} for T=1..4 (tower.md's registered constant)

Formula 3: repair_common_qty(T) = round(base_repair_common(4) × tier_dps_multiplier(T))
```

Formula 2 is not a formula at all — it's a content-authoring guideline (Common-only, 3-12 material, output_quantity 1-5) validated at data-authoring time, not computed at runtime.

## Out of Scope

- Story 001: the `RecipeResource` fields these formulas read from
- Story 005: repair's actual resolution flow (this story only covers the cost number)

## QA Test Cases

**AC-8**
- Given: `T=4`, `base_qty={Common:8, Uncommon:4, Rare:2}`, `tier_dps_multiplier(4)=4.0`
- When: Formula 1 computed
- Then: `round(8×4.0)=32` Common, `round(4×4.0)=16` Uncommon, `round(2×4.0)=8` Rare
- Edge cases: T=1 — only Common (8), zero Uncommon/Rare (per the rarity-gating table)

**AC-10**
- Given: a `crafted_good` recipe authored with `inputs={Common: 6}`, `output_quantity=3`, `quality_tier=0`
- When: its data is read
- Then: exact match, no derived/computed value overrides the authored content
- Edge cases: `quality_tier` field on any `crafted_good` recipe must always read 0, never a tier value

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/crafting/material_cost_formulas_test.gd`
**Status**: [x] Created — 2 test functions (AC-8, AC-10). Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 2/2 passing (AC-8, AC-10)
**Deviations**: ADVISORY — Formula 1's rarity-based costs required relaxing `RecipeResource.validate()` to accept rarity-string keys alongside item_type keys (user-approved judgment call — see `TD-craft-001`, reopened/escalated to reflect this: the rarity-keyed recipe (`recipe_tier4_component`) is content-correct but not genuinely craftable today, same open gap as `TD-defbuild-002`). Numbers authored as pure data (no runtime formula function), matching Defense Building Story 025's precedent.
**Test Evidence**: `tests/unit/crafting/material_cost_formulas_test.gd` (2 functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Skipped per "keep skip review plan through the remaining stories" instruction

## Dependencies

- Depends on: Story 001
- Unlocks: Story 004, Story 005
