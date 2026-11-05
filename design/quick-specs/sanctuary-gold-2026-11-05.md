# Sanctuary gold (persistent, owned by Resource Economy)

Date: 2026-11-05. Status: **built**. User decisions: Resource Economy owns it; gold is only earned in missions and converts to Sanctuary gold at a lower rate when the run ends; the rate can be improved later; it is spent on equipment forging and upgrading.

Supersedes `sanctuary-header-drop-gold-2026-08-06.md` (that spec removed gold from the Sanctuary header because gold then had no Sanctuary meaning; it now does).

## Rules

1. **Earning.** Unchanged in missions (Rules 8/10/10b, `GMissionEconomy`). When a mission ends (`mission_phase_changed` to `MISSION_COMPLETE` or `DEFEAT`), the mission gold the player still holds is banked: `banked = floor(held_gold x conversion_rate)`. Once per launch (a re-emitted terminal phase cannot bank twice). Retry after a defeat banks that attempt, then the new attempt earns afresh.
2. **Conversion rate.** `0.25 + 0.10 x Treasury techs owned` (0.25 / 0.35 / 0.45 / 0.55).
3. **Improving it.** Defense Building tech tree gains a third column, **Treasury** (`tech_category = "economy_tech"`): Treasury I (Common 80), II (Common 180, Uncommon 20), III (Common 320, Uncommon 40, Rare 20), a chain like Production/Structural. Cards read "Banks N% of mission gold".
4. **Spending (Equipment Forge only).**
   - Craft: `80 x quality_tier` (80 / 160 / 240 / 320; tier 5 pays 320), on top of materials.
   - Imbue a rune: 100.
   - Add a rune slot: `250 x (slots already added + 1)` (250 then 500), on top of its Ascendant Shards. The endgame sink.
   - Every action checks gold with its other costs and spends nothing if any is short.
5. **Display.** Sanctuary resource header: a gold chip first (coin icon). Forge: each recipe shows "N gold" and "Not enough gold" when materials are ready but gold is not; rune buttons show the imbue price and disable when unaffordable; the rune-slot button and confirm dialog list shards and gold. Mission outcome: "+N Sanctuary gold banked" on victory and defeat.

## Ownership

`SanctuaryGold` (`src/core/resource_economy/sanctuary_gold.gd`, autoload `GSanctuaryGold`) is Resource Economy's persistent half: the per-mission `ResourceEconomy` node is rebuilt with each mission scene and cannot hold a balance. Saved via `GSavePersistence` (key `sanctuary_gold`, restore order 38); older saves load with 0. EventBus `sanctuary_gold_changed(balance, delta, source)`, sources `mission_bank`, `forge_craft`, `forge_imbue`, `forge_rune_slot`.

## Tuning notes

Modelled in `tools/balance/progression_sim.py` (2026-11-05): mission income = scout + wave grants (+ `--early-call`), minus `--towers` x the average blueprint placement cost (~21), banked at the Treasury-adjusted rate; Forge crafts need gold too (imbues and rune slots not modelled). Knobs: `--craft-gold`, `--gold-rate`, `--tower-gold`, `--no-sanctuary-gold`.

Findings (120 missions, ascend after 65, 6 towers, no early calls): a mission banks ~60-120 at 25% and ~190-260 at 55%. **At the shipped prices gold never delays a purchase** — materials are the bottleneck and 22,362 is banked vs 3,510 spent. What-ifs on the tier-1 price (doubling per tier):

| T1 price | Gear @12 / @30 / @60 | Peak visits waiting on gold | Unspent at 120 |
|---|---|---|---|
| 30 (shipped) | 17 / 32 / 41 | 0 | 18,852 |
| 100 | 12 / 25 / 37 | 10 | 13,244 |
| 150 | 9 / 21 / 32 | 25 | 5,412 |
| 200 | 8 / 17 / 30 | 32 | 999 |

So at launch prices (T1 30, doubling) gold was decoration.

**Retuned 2026-11-05 (user: "perform whatever cost balancing you think necessary").** Goal: gold is a real but gentle constraint through the campaign (planned around, never a wall) and has an endgame sink. Curves compared in the simulator:

| Craft curve | Gear @12 / @30 / @60 | Longest wait (visits) |
|---|---|---|
| 80 x 2^(t-1) (80...640) | 13 / 28 / 40 | 23 |
| **80 x t (80/160/240/320)** | **13 / 30 / 45** | **17** |
| 100 x t | 11 / 24 / 46 | 38 |
| 60 x (t+1) | 12 / 28 / 47 | 28 |

Chosen: craft `80 x tier`, imbue 100 (runes are rare one-off finds; 40 was trivial), rune slot `250 x (added+1)`. Result: the balance stays under ~150 through mission 40 (gold is spent as it arrives, a few purchases wait each visit), gear by mission 60 is 45/67 (41 at launch prices, because gold-gated visits let materials pool for bigger pieces), and after the gear catalogue saturates (~mission 60) about 200 a mission banks. Rune slots on ~10 worn items absorb ~7,500 of that, but they are also shard-gated, so a late surplus (~14,800 unspent at 120 in the model) remains: the place for a future endgame sink. Knobs: `BASE_CONVERSION_RATE`, `CONVERSION_RATE_PER_TECH`, `CRAFT_COST_BASE`, `IMBUE_COST`, `RUNE_SLOT_COST_STEP` in `SanctuaryGold`.

## Verification

`tests/unit/resource_economy/sanctuary_gold_test.gd` (rate, bank once on complete/defeat, prices, spend, save round trip, Treasury data). Forge suites fund gold in `before_test`. Live: real save, simulated 300-gold mission end -> 75 banked, header chip, Treasury column, forge prices, crafting an Iron Helm 75 -> 45.
