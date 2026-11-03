# Quick Spec: Ascension Rewards (2026-11-03)

Extends `design/gdd/mission-select.md` (Amendment 2026-11-03: Ascension) and
`DifficultyRewards`. User picked all four reward layers on 2026-11-03.

## Overview

Ascension ranks (tiers 4-18) only scaled enemy HP (x1.15/rank) and rewards
(x1.12/rank). Rewards grow slower than HP on purpose, so the best farm is the
highest rank you clear reliably and pushing past it paid nothing. This adds
four things only Ascension gives: a new material (Ascendant Shards) with two
sinks (an extra rune slot on owned gear, and a tier-5 gear set), three Tarot
cards, and a medallion rim on Mission Select.

## Player Fantasy

"I conquered The Gap at Ascension 10 and everyone can see it": a silver rim on
the card, a card in the deck nobody else has, and gear forged from shards only
the hardest runs give.

## Detailed Rules

1. **Ascendant Shard** (`ascendant_shard`, Material, rarity `""` so no
   rarity-keyed cost such as "32 Rare" can ever consume it). Granted only on a
   victory at an Ascension rank R >= 1, through `materials_earned` (source
   `ascension_reward`), by `MissionSelect` when it records the clear:
   - **First-clear bounty**: the first clear of rank R on a map pays
     `FIRST_CLEAR_SHARDS_PER_RANK x R`.
   - **Run reward**: every Ascension victory pays `RUN_SHARDS_PER_RANK x R`.
   - Not scaled by the tier reward multiplier or Tarot reward cards (fixed and
     readable). Defeat pays nothing. The outcome screen lists the shards.
2. **Extra rune slot (Forge, Imbue tab).** With an owned equipment item
   selected, "Add rune slot" spends shards and raises that item's
   `rune_slot_count` by 1. At most `MAX_EXTRA_RUNE_SLOTS` above the slot's base
   count (`EquipmentRecipeResource.RUNE_SLOT_COUNT_FOR_SLOT`). Cost of the
   n-th extra slot: `EXTRA_RUNE_SLOT_COST[n-1]`. Rejected in full (nothing
   spent) when at the cap, short of shards, or the item is not equipment.
3. **Ascension Tarot cards.** `TarotCardResource.unlock_ascension_rank`: a card
   with a value > 0 unlocks once the highest Ascension rank cleared on ANY map
   reaches it (pull-based, like `unlock_tech_id`; nothing extra is saved).
   The Tarot screen's locked tag names the rank. The dev unlock-all switch does
   not unlock them (it opens maps, it does not record clears).
4. **Medallion rim.** A map's best Ascension rank >= 5 / 10 / 15 draws a
   bronze / silver / gold rim on its Mission Select medallion.
5. **Ascendant gear (tier 5).** Nine pieces, one per equipment slot,
   `quality_tier = 5`, gated by `tech_production_4`, inputs: shards + Rare +
   Uncommon. Discovered like every recipe (gate open + inputs owned), so the
   Forge's "Next recipes" shows them as goals once Production IV is done.

## Formulas

- `first_clear_shards(R) = 10 x R` (R in 1..15): A1 10, A5 50, A15 150.
- `run_shards(R) = 2 x R`: A1 2, A5 10, A15 30.
- All first clears, 8 maps to A15: `8 x 10 x (1+...+15) = 9,600` shards.
- To A6 on every map: `8 x 10 x 21 = 1,680` first-clear shards plus runs.
- Extra rune slot costs: 1st `40`, 2nd `120` shards (cap 2 per item).
- Ascendant set: weapon and chest 300 shards, other 7 pieces 200 shards each
  = 2,000 shards, each piece also 20 Rare + 30 Uncommon. About A6 on every map.
- Ascendant stats = about 1.3 x the best tier-4 item in the same slot.
- `EquipmentForge.TIER_DPS_MULTIPLIER` gains tier 5 = 6.0 (Formula 1 scaling
  continues 1.0 / 1.6 / 2.4 / 4.0 / 6.0).

## Edge Cases

- Re-clearing a rank already cleared: run reward only, no bounty.
- Clearing a rank whose lower ranks were never cleared (dev switch on): the
  bounty is still paid for that rank only; lower ranks pay when cleared.
- Bag full of other stacks (amended 2026-11-03 after the live check: the real
  save had 18/18 slots used and the first-clear bounty was silently rejected):
  only what fits (`Inventory.stackable_room`) goes in; the rest is held by
  MissionSelect (`held_shards`, saved, absent in older saves = 0) and
  delivered as soon as the bag frees space (item removed, slot expansion,
  load). No "bag full" toast/sound. The outcome screen adds "Bag full: N
  shards are held and will arrive when you free space".
- Shards stack to 99 per bag slot like every material, so the 300-shard
  Ascendant Blade needs 4 slots of shards at once. Open tuning question.
- Extra-slot purchase on an item with imbued runes: allowed; runes kept.
- Item un-equipped / equipped: slot count is per instance and travels with it.
- Old saves: no shards, no rims, Ascension cards locked until earned.

## Dependencies

- MissionSelect (completion ledger, highest rank), Inventory (stacks, rune
  slots), EquipmentForge (purchase + recipes), Tarot (unlock check),
  Mission Select screen (rim), Mission outcome screen (shard line),
  GameDataRegistry (new item, recipes, cards).

## Tuning Knobs

| Knob | Value | Safe range | Affects |
|---|---|---|---|
| `AscensionRewards.FIRST_CLEAR_SHARDS_PER_RANK` | 10 | 5-20 | push incentive per map |
| `AscensionRewards.RUN_SHARDS_PER_RANK` | 2 | 1-5 | farm income at a rank |
| `AscensionRewards.EXTRA_RUNE_SLOT_COST` | [40, 120] | 20-300 | first shard sink |
| `AscensionRewards.MAX_EXTRA_RUNE_SLOTS` | 2 | 1-3 | rune power ceiling |
| `AscensionRewards.RIM_RANKS` | [5, 10, 15] | within 1..15 | cosmetic milestones |
| Ascendant recipe shard costs | 300 / 200 | 100-500 | set completion pace |
| Tarot `unlock_ascension_rank` | 3 / 6 / 10 | 1..15 | card availability |

## Acceptance Criteria

- First Ascension 2 clear on a map grants 20 + 4 = 24 shards; a second A2
  clear grants 4. A Brutal clear grants 0.
- "Add rune slot" on a 2-slot item with 40 shards: 3 slots, 0 shards left;
  third purchase on the same item is refused with nothing spent.
- Dawnbreaker is locked until any map's best rank >= 3, then equippable.
- The Gap with best rank 10 shows a silver rim; best rank 4 shows none.
- Each Ascendant recipe validates at load (quality_tier 5 accepted) and is
  discovered once Production IV is researched and its inputs are owned.
