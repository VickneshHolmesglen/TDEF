# Quick Spec: Inventory salvage

Date: 2026-11-03. Status: implemented.
Second half of the bag-clog fix (`production/balance/progression-targets.md`);
first half: `inventory-discard-2026-11-03.md`.

## Rules

1. The discard dialog (right-click / Del / pad X on a bag slot) shows a
   Salvage button when the stack can be salvaged.
2. Salvage refines a stack one rarity up at `SalvageRules.RATIO` (20) inputs
   per output; the remainder stays in the slot:
   - Common material -> Refined Alloy (Uncommon)
   - Uncommon material -> Refined Essence (Rare)
3. Rare materials, rarity "" items (Menagerie Lure, Ascendant Shard),
   unique items and stacks under one batch can't be salvaged (no button).
4. The outputs are generic: no named recipe uses them, so they only pay
   rarity-keyed costs ("N Uncommon", "N Rare") and never shortcut a
   boss-material recipe.
5. Nothing is consumed unless the output fits. A whole-batch stack frees its
   own slot, which counts as room. When it can't fit, the button is greyed
   out and the dialog adds "(Free a bag slot first.)" (found in the live
   check on a full 8/8 bag).

## Tuning

| Knob | Value | Where |
|---|---|---|
| Inputs per output | 20 | `SalvageRules.RATIO` |
| Rarity chain | Common -> Uncommon -> Rare | `SalvageRules.OUTPUT_BY_RARITY` |

Simulator (`--missions 160 --ascend-after 65`, real 8-slot bag): neither
feature 84% of loot lost, Ascendant set never; discard 29% lost, set by 135;
salvage only 76%, 6/9; both 14% lost, set by 135. Campaign pacing unchanged
(top research still bought at mission 39): salvage only matters once the bag
is full.

## Acceptance criteria

`tests/integration/inventory-screen/salvage_test.gd` (7). Live-checked on a
real full save: the greyed-out state and its reason.

Art: Refined Alloy / Refined Essence icons are recolours of Iron Ore / Sentinel
Core (placeholders; candidates for Amuse).
