# Quick Design Spec: Habitat Expansion Tier 4

**Type**: Addition
**System**: Defense Building / Menagerie (cross-GDD contract) / Sanctuary UI (Diorama)
**GDD Reference**: `design/gdd/defense-building.md`, `design/gdd/menagerie.md`
**Date**: 2026-08-03

## Change Summary

Habitat Expansion gains a real 4th tier. The source reference art
(`assets/source/habitat/habitat_building_set.png`) always depicted 4
buildings, but only 3 tiers were ever authored as real `StructureResource`
content — the 4th (grandest) building sat unused with no design slot,
flagged across multiple prior session logs. This closes that gap for real:
new `StructureResource`/`TechNodeResource` content, a new diorama texture,
and both GDDs' tier-count claims extended from 3 to 4 in lockstep.

## Motivation

Leaving real, already-generated art permanently orphaned because "no design
slot exists" is a worse outcome than extending an already-designed,
already-formulaic system by one more step of its own established curve.
Both the tech-node cost formula (Formula 1, `defense-building.md`) and the
habitat capacity formula (`menagerie.md` Rule 4, `+2 slots/tier`) already
generalize cleanly to a 4th tier — this is not a new mechanic, just one more
row in two tables that were never hard-capped by anything except unused
content.

## Design Delta

- **New tech node**: `tech_structural_3` (`structural_tech`, prerequisite
  `tech_structural_2`, `branch_tier=3`) — sits inside Formula 1's existing
  1–3 `branch_tier` domain, so it costs exactly what `tech_production_4`
  costs (45 Common / 24 Uncommon / 12 Rare / 150 gold), per that formula's
  own "both categories share one cost curve" rule. No formula change.
- **New structure**: `habitat_expansion_tier_4` (`tier=4`, prerequisite
  `habitat_expansion_tier_3`, gated by `tech_structural_3`) — continues
  Formula 2's hand-tuned, diminishing-severity cost curve: 80 Common / 45
  Uncommon / 15 Rare / 300 gold.
- **New Menagerie capacity step**: `HABITAT_MAX_TIERS` 3 → 4,
  `HABITAT_MAX_CAPACITY` 10 → 12 (`menagerie.gd`), continuing the existing
  `+2 slots/tier` formula unchanged.
- **New diorama art**: `assets/art/sanctuary/habitat_tier_4.png`, cropped
  from the same source sheet as tiers 1–3 and processed with the same
  connected-component flood-fill alpha-cut technique
  (`design/art/asset-generation-prompts.md`'s documented method). Added to
  `diorama.gd`'s `HABITAT_TEXTURES` dictionary — no other diorama code
  changed, since `_render_habitat()` already looks up tier generically.

## Cost Table (Formula 2 continuation)

| `structure_id` | `tier` | Common | Uncommon | Rare | Gold |
|---|---|---|---|---|---|
| `habitat_expansion_tier_4` | 4 | 80 | 45 | 15 | 300 |

Ratios vs. Tier 3 (Common 1.45×, Uncommon 1.8×, Rare 1.875×, Gold 1.50×) sit
close together deliberately, continuing the diminishing-severity trend
without letting any single material spike disproportionately.

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| `design/gdd/defense-building.md` | Core Rule 3/5, Formula 2, AC-3/7/8/15/23, new AC-42/43/44 | Updated |
| `design/gdd/menagerie.md` | Core Rule 4, Tuning Knobs, AC-7, Open Questions | Updated |
| `assets/data/defense_building/tech_nodes/tech_structural_3.tres` | New content | Authored |
| `assets/data/defense_building/structures/habitat_expansion_tier_4.tres` | New content | Authored |
| `src/core/menagerie/menagerie.gd` | `HABITAT_MAX_TIERS`/`HABITAT_MAX_CAPACITY` constants | Updated |
| `src/presentation/sanctuary_ui/diorama.gd` | `HABITAT_TEXTURES` dictionary | Updated |
| `assets/art/sanctuary/habitat_tier_4.png` | New art | Generated from existing source sheet |
| Tests across `tests/unit/defense_building/`, `tests/integration/defense_building/`, `tests/integration/defense-building-screen/`, `tests/integration/menagerie/` | New/updated assertions for the 4th tier/6th node | Updated |

## Acceptance Criteria

- [x] `tech_structural_3` loads with `branch_tier=3`, correct prerequisite, correct cost (matches `tech_production_4`)
- [x] `habitat_expansion_tier_4` loads with `tier=4`, correct prerequisite, correct tech_gate, correct cost
- [x] `GameDataRegistry` loads 6 tech nodes / 5 structures (was 5/4)
- [x] `Menagerie._on_sanctuary_structure_built` raises capacity to 12 across all 4 tier events; a 5th event is a no-op
- [x] `DefenseBuilding.can_build_structure` enforces both tier-sequence and tech-gate for Tier 4, mirroring Tier 2/3's existing checks
- [x] Diorama renders `habitat_tier_4.png` when Tier 4 is built, same texture-swap-in-place path as tiers 1–3
- [x] Defense Building screen's tech/structure lists surface the new node/structure (already fully data-driven, no UI code change needed)
- [x] Full project regression clean, no unrelated regressions

## GDD Update Required?

Yes — both `defense-building.md` and `menagerie.md` updated in this pass (see Affected Systems above).
