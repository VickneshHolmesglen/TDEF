# Quick Spec: Inventory discard

Date: 2026-11-03. Status: implemented.
Implements the first half of the bag-clog fix in
`production/balance/progression-targets.md` ("Bag clog"). Salvage
(turning surplus stacks into something useful) is the planned second half.

## Problem

Nothing removes loot from the bag except spending it. The progression
simulator (`--missions 160 --ascend-after 65`) fills the bag around mission
60 with materials no remaining purchase needs; after that 82% of income is
lost and held Ascendant Shards never arrive, so the Ascendant set is never
bought. With discard modelled (`--discard`) the set completes ~mission 115.

## Rules

1. Right-click, Delete, or gamepad X on a bag slot asks to discard that
   slot's whole stack or item: "Discard N x Name? This can't be undone."
   Cancel has focus by default.
2. Confirming removes the slot (`Inventory.discard_slot`), which goes
   through `remove_item()`, so equipped/installed (locked) slots and the Hero
   equip slots are refused (denial cue for a locked item).
3. `item_removed` is emitted, so screens refresh and held rewards
   (MissionSelect's held shards) move into the freed space at once.
4. Any item can be discarded, Ascendant Shards and unequipped gear included;
   the confirm names the item and amount.
5. The bag header shows the hint "Right-click or Del: discard".

## Edge cases

- A key held down doesn't repeat-discard (echo ignored).
- A confirm arriving after cancel does nothing (the pending slot is cleared).
- Discarding while shards are held: the shards fill the freed slot
  immediately (deferred one frame), so the slot is not left empty.

## Acceptance criteria

- `tests/integration/inventory-screen/discard_test.gd` (5),
  `tests/unit/inventory/equipped_lock_test.gd` (locked discard refused).
- Live-checked on a real full save: discard 99 Goblin Hide, 36 held shards
  arrived in the freed slot.
