# Sanctuary gold (persistent, owned by Resource Economy)

Date: 2026-11-05. Status: **built**. User decisions: Resource Economy owns it; gold is only earned in missions and converts to Sanctuary gold at a lower rate when the run ends; the rate can be improved later; it is spent on equipment forging and upgrading.

Supersedes `sanctuary-header-drop-gold-2026-08-06.md` (that spec removed gold from the Sanctuary header because gold then had no Sanctuary meaning; it now does).

## Rules

1. **Earning.** Unchanged in missions (Rules 8/10/10b, `GMissionEconomy`). When a mission ends (`mission_phase_changed` to `MISSION_COMPLETE` or `DEFEAT`), the mission gold the player still holds is banked: `banked = floor(held_gold x conversion_rate)`. Once per launch (a re-emitted terminal phase cannot bank twice). Retry after a defeat banks that attempt, then the new attempt earns afresh.
2. **Conversion rate.** `0.25 + 0.10 x Treasury techs owned` (0.25 / 0.35 / 0.45 / 0.55).
3. **Improving it.** Defense Building tech tree gains a third column, **Treasury** (`tech_category = "economy_tech"`): Treasury I (Common 80), II (Common 180, Uncommon 20), III (Common 320, Uncommon 40, Rare 20), a chain like Production/Structural. Cards read "Banks N% of mission gold".
4. **Spending (Equipment Forge only).**
   - Craft: `30 x 2^(quality_tier - 1)` (T1 30, T2 60, T3 120, T4 240), on top of materials.
   - Imbue a rune: 40.
   - Add a rune slot: `100 x (slots already added + 1)`, on top of its Ascendant Shards.
   - Every action checks gold with its other costs and spends nothing if any is short.
5. **Display.** Sanctuary resource header: a gold chip first (coin icon). Forge: each recipe shows "N gold" and "Not enough gold" when materials are ready but gold is not; rune buttons show the imbue price and disable when unaffordable; the rune-slot button and confirm dialog list shards and gold. Mission outcome: "+N Sanctuary gold banked" on victory and defeat.

## Ownership

`SanctuaryGold` (`src/core/resource_economy/sanctuary_gold.gd`, autoload `GSanctuaryGold`) is Resource Economy's persistent half: the per-mission `ResourceEconomy` node is rebuilt with each mission scene and cannot hold a balance. Saved via `GSavePersistence` (key `sanctuary_gold`, restore order 38); older saves load with 0. EventBus `sanctuary_gold_changed(balance, delta, source)`, sources `mission_bank`, `forge_craft`, `forge_imbue`, `forge_rune_slot`.

## Tuning notes

A typical mission ends holding most of its ~250-400 gold (towers cost 10-12), so it banks ~75-100 at the base rate and ~165-220 at 55%. T1 gear at 30 is affordable after one mission; T4 at 240 needs a few. Not yet modelled in `tools/balance/progression_sim.py`. Playtest knobs: `BASE_CONVERSION_RATE`, `CONVERSION_RATE_PER_TECH`, `CRAFT_COST_BASE`, `IMBUE_COST`, `RUNE_SLOT_COST_STEP` in `SanctuaryGold`.

## Verification

`tests/unit/resource_economy/sanctuary_gold_test.gd` (rate, bank once on complete/defeat, prices, spend, save round trip, Treasury data). Forge suites fund gold in `before_test`. Live: real save, simulated 300-gold mission end -> 75 banked, header chip, Treasury column, forge prices, crafting an Iron Helm 75 -> 45.
