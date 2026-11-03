# Progression simulation

Expected values (no RNG), from the live game data. Re-run after any data or formula edit.

## Assumptions

- Level curve: `100 x 1.067^(L-1)`, cap 50; skill point every 5 levels
- XP: kill {0: 5, 1: 15, 2: 100} (standard/elite/boss), wave 25, mission 150
- Hero kill share: 35% full XP, 15% half XP, rest none (`--hero-inner/--hero-outer`)
- 6 towers placed, foundation tier 1, archetype `physical` (surplus)
- Difficulty 1; reward multiplier per tier [1.0, 1.3, 1.7] (game values)
- Menagerie quality bonus x1.0, win rate 100%, no tarot
- Plan (cycled): the_ashfields -> the_broodwarrens -> the_duskwood -> the_foothills -> the_gap -> the_hollow -> the_mirefen -> the_narrows

## One run of each mission

| Mission | Waves | Kills S/E/B | XP | Common | Uncommon | Rare | Surplus each | Lures |
|---|---|---|---|---|---|---|---|---|
| The Ashfields | 8 | 41/4/1 | 502 | 129 | 3.6 | 17 | 6.0 | 3.27 |
| The Broodwarrens | 9 | 48/4/1 | 541 | 176 | 10 | 26 | 6.0 | 3.51 |
| The Duskwood | 10 | 51/6/1 | 585 | 194 | 48 | 68 | 6.0 | 3.89 |
| The Foothills | 8 | 38/5/1 | 502 | 111 | 4.5 | 24 | 6.0 | 3.54 |
| The Gap | 8 | 34/8/1 | 513 | 110 | 27 | 41 | 6.0 | 3.40 |
| The Hollow | 9 | 34/17/1 | 594 | 189 | 13 | 61 | 6.0 | 5.14 |
| The Mirefen | 9 | 46/5/1 | 543 | 138 | 25 | 45 | 6.0 | 3.70 |
| The Narrows | 7 | 27/4/1 | 448 | 76 | 0.0 | 11 | 6.0 | 2.60 |

## Campaign timeline (70 missions)

| Missions | Hero level | Skill pts (levels) | Total XP | Purchases owned | Gear owned |
|---|---|---|---|---|---|
| 1 | 5 | 1 | 502 | 21/106 | 1/63 |
| 2 | 9 | 1 | 1,043 | 28/106 | 4/63 |
| 4 | 14 | 2 | 2,130 | 35/106 | 8/63 |
| 8 | 21 | 4 | 4,228 | 45/106 | 11/63 |
| 12 | 26 | 5 | 6,357 | 50/106 | 15/63 |
| 20 | 33 | 6 | 10,585 | 56/106 | 21/63 |
| 30 | 38 | 7 | 15,920 | 66/106 | 27/63 |
| 40 | 42 | 8 | 21,139 | 75/106 | 34/63 |
| 60 | 48 | 9 | 31,725 | 90/106 | 48/63 |
| 70 | 50 | 10 | 37,059 | 94/106 | 52/63 |

## Hero power vs enemy HP

Hero attack = 25 base + 2/level + best owned gear per slot (physical_attack). Enemy HP: Brutal x1.7, each Ascension rank x1.15 (max 15). `Rank to match` = the Ascension rank whose HP has grown as much as the hero has since mission 1 on Normal, i.e. the rank that should feel like the first mission. Towers, skills and tarot are NOT modelled; they push the real number higher.

| Missions | Hero level | Gear attack | Hero attack | Power vs mission 1 | Rank to match |
|---|---|---|---|---|---|
| 1 | 5 | 2.5 | 36 | x1.29 | Brutal or lower |
| 2 | 9 | 3.7 | 45 | x1.63 | Brutal or lower |
| 4 | 14 | 3.7 | 55 | x1.99 | 2 |
| 8 | 21 | 3.7 | 69 | x2.50 | 3 |
| 12 | 26 | 5.2 | 80 | x2.92 | 4 |
| 20 | 33 | 12 | 101 | x3.68 | 6 |
| 30 | 38 | 13 | 112 | x4.09 | 7 |
| 40 | 42 | 14 | 121 | x4.41 | 7 |
| 60 | 48 | 28 | 147 | x5.35 | 9 |
| 70 | 50 | 32 | 155 | x5.64 | 9 |

## Missions to reach each level

| Level | XP to next | Cumulative XP | Missions (avg yield) |
|---|---|---|---|
| 2 | 106 | 100 | 0.2 |
| 5 | 129 | 440 | 0.8 |
| 10 | 179 | 1,179 | 2.2 |
| 15 | 247 | 2,202 | 4.2 |
| 20 | 342 | 3,617 | 6.8 |
| 25 | 474 | 5,574 | 10.5 |
| 30 | 655 | 8,282 | 15.7 |
| 40 | 1,254 | 17,209 | 32.6 |
| 50 | 2,399 | 34,290 | 64.9 |

## Sanctuary purchases

`Affordable` = the first mission whose cumulative income covers this item alone. `Bought` = when a greedy cheapest-first shopper actually gets it, respecting prerequisites. `-` = not within the simulated missions.

| Item | Kind | Cost | Needs | Affordable | Bought |
|---|---|---|---|---|---|
| goblinhide_bandage | crafted good | 5.0 goblin_hide |  | 1 | 1 |
| healing_salve | crafted good | 3.0 Material |  | 1 | 1 |
| healing_salve | crafted good | 6.0 Common |  | 1 | 1 |
| hunters_draught | crafted good | 4.0 Material |  | 1 | 1 |
| ironplate_ration | crafted good | 4.0 iron_plating |  | 1 | 1 |
| spore_poultice | crafted good | 5.0 spore_dust |  | 1 | 1 |
| travelers_bedroll | crafted good | 7.0 troll_hide, 3.0 common_scrap |  | 1 | 1 |
| warlords_field_ration | crafted good | 6.0 warlord_iron, 3.0 iron_plating |  | 1 | 1 |
| iron_greaves | equipment | 120 Common, 11 Uncommon | tech_production_2 | 1 | 10 |
| iron_helm | equipment | 65 Material |  | 1 | 3 |
| iron_sword | equipment | 20 Material |  | 1 | 1 |
| leather_gloves | equipment | 55 Material |  | 1 | 2 |
| leather_jerkin | equipment | 30 Material |  | 1 | 2 |
| leather_leggings | equipment | 75 Material |  | 1 | 3 |
| lucky_charm_trinket | equipment | 95 Material |  | 1 | 3 |
| reinforced_boots | equipment | 100 Common, 9.0 Uncommon | tech_production_2 | 1 | 8 |
| reinforced_gauntlets | equipment | 110 Common, 10 Uncommon | tech_production_2 | 1 | 9 |
| reinforced_helm | equipment | 90 Common, 8.0 Uncommon | tech_production_2 | 1 | 6 |
| traveler_boots | equipment | 45 Material |  | 1 | 2 |
| warding_band | equipment | 100 Common |  | 1 | 7 |
| wooden_buckler | equipment | 85 Material |  | 1 | 3 |
| habitat_expansion_tier_1 | structure | 20 Common |  | 1 | 2 |
| habitat_expansion_tier_2 | structure | 35 Common, 12 Uncommon | habitat_expansion_tier_1 | 1 | 3 |
| habitat_expansion_tier_3 | structure | 55 Common, 25 Uncommon, 8.0 Rare | habitat_expansion_tier_2 | 1 | 4 |
| watchtower_tier_1 | structure | 25 Common | tech_structural_1 | 1 | 7 |
| tech_production_2 | tech | 100 Common |  | 1 | 5 |
| tech_structural_1 | tech | 100 Common |  | 1 | 6 |
| advanced_weapon_component | tower component | 2.0 Material | tech_production_2 | 1 | 6 |
| archer_focus_component | tower component | 3.0 focus_surplus |  | 1 | 1 |
| archer_foundation_component | tower component | 3.0 foundation_surplus |  | 1 | 1 |
| archer_power_component | tower component | 3.0 power_surplus |  | 1 | 1 |
| archer_weapon_component | tower component | 3.0 weapon_surplus |  | 1 | 1 |
| basic_focus_component | tower component | 6.0 Material |  | 1 | 1 |
| basic_shaft_component | tower component | 6.0 Material |  | 1 | 1 |
| basic_top_component | tower component | 8.0 Material |  | 1 | 1 |
| iron_foundation_component | tower component | 5.0 Material |  | 1 | 1 |
| masterwork_power_component | tower component | 19 Common, 10 Uncommon | tech_production_3 | 1 | 22 |
| masterwork_weapon_component | tower component | 19 Common, 10 Uncommon | tech_production_3 | 1 | 22 |
| reinforced_focus_component | tower component | 4.0 Material | tech_production_2 | 1 | 6 |
| reinforced_foundation_component | tower component | 4.0 Material | tech_production_2 | 1 | 6 |
| reinforced_power_component | tower component | 4.0 Material | tech_production_2 | 1 | 6 |
| tier4_power_component | tower component | 32 Common, 16 Uncommon, 8.0 Rare | tech_production_4 | 1 | 39 |
| upgrade_habitat_expansion_boundless | upgrade | 12 Common | creature:emberwing_moth, tarot:apex_predator, equipment:brutes_bulwark_plate | 1 | 1 |
| upgrade_habitat_expansion_bountiful | upgrade | 12 Common | equipment:iron_greaves, creature:mossback_toad | 1 | 1 |
| upgrade_habitat_expansion_flourishing | upgrade | 22 Common | upgrade_habitat_expansion_bountiful creature:aurora_stag, tarot:bountiful_harvest, equipment:warding_band | 1 | 2 |
| upgrade_habitat_expansion_sheltered | upgrade | 12 Common | creature:aurora_stag, equipment:leather_leggings | 1 | 1 |
| upgrade_habitat_expansion_thriving | upgrade | 12 Common | creature:duskfang_fox, tarot:steady_hand | 1 | 1 |
| upgrade_watchtower_reinforced | upgrade | 12 Common | building:habitat_expansion_tier_1, creature:glimmer_hare, tarot:iron_resolve | 1 | 1 |
| upgrade_watchtower_vigilant | upgrade | 22 Common | upgrade_watchtower_reinforced creature:duskfang_fox, tarot:grim_resolve, equipment:iron_helm | 1 | 2 |
| bogwater_tonic | crafted good | 6.0 lurker_ichor |  | 2 | 2 |
| iron_band | equipment | 150 Common, 14 Uncommon | tech_production_2 | 2 | 13 |
| iron_buckler | equipment | 130 Common, 12 Uncommon | tech_production_2 | 2 | 11 |
| reinforced_plate | equipment | 140 Common, 13 Uncommon | tech_production_2 | 2 | 12 |
| silver_pendant | equipment | 160 Common, 15 Uncommon | tech_production_2 | 2 | 14 |
| steel_greatsword | equipment | 175 Common, 16 Uncommon | tech_production_2 | 2 | 15 |
| steelwrought_gauntlets | equipment | 220 Common, 21 Uncommon, 12 iron_ore | tech_production_2 | 2 | 25 |
| steelwrought_helm | equipment | 230 Common, 22 Uncommon, 12 iron_ore | tech_production_2 | 2 | 27 |
| steelwrought_sabatons | equipment | 190 Common, 18 Uncommon, 10 iron_ore | tech_production_2 | 2 | 17 |
| steelwrought_signet | equipment | 200 Common, 19 Uncommon | tech_production_2 | 2 | 18 |
| steelwrought_torc | equipment | 210 Common, 20 Uncommon | tech_production_2 | 2 | 20 |
| habitat_expansion_tier_4 | structure | 80 Common, 45 Uncommon, 15 Rare | habitat_expansion_tier_3 | 2 | 10 |
| tech_production_3 | tech | 220 Common, 30 Uncommon | tech_production_2 | 2 | 21 |
| tech_structural_2 | tech | 220 Common, 30 Uncommon | tech_structural_1 | 2 | 23 |
| riftglass_ward | crafted good | 8.0 rift_shard |  | 3 | 3 |
| steelwrought_cuirass | equipment | 265 Common, 26 Uncommon, 16 iron_ore | tech_production_2 | 3 | 33 |
| steelwrought_kite_shield | equipment | 240 Common, 23 Uncommon, 14 iron_ore | tech_production_2 | 3 | 28 |
| steelwrought_legplates | equipment | 250 Common, 24 Uncommon, 14 iron_ore | tech_production_2 | 3 | 31 |
| steelwrought_longsword | equipment | 280 Common, 28 Uncommon, 18 iron_ore | tech_production_2 | 3 | 35 |
| tech_production_4 | tech | 380 Common, 50 Uncommon, 32 Rare | tech_production_3 | 3 | 38 |
| tech_structural_3 | tech | 380 Common, 50 Uncommon, 32 Rare | tech_structural_2 | 3 | 42 |
| warlords_greaves | equipment | 23 warlord_iron, 18 Uncommon | tech_production_3 | 4 | 28 |
| goblin_raider_leggings | equipment | 170 goblin_hide, 18 Uncommon | tech_production_3 | 5 | 45 |
| goblin_signet | equipment | 170 goblin_hide, 18 Uncommon | tech_production_3 | 5 | 51 |
| brute_gauntlets | equipment | 146 iron_plating, 18 Uncommon | tech_production_3 | 6 | 47 |
| brute_legguards | equipment | 146 iron_plating, 18 Uncommon | tech_production_3 | 6 | 52 |
| ichor_charm | equipment | 39 lurker_ichor, 18 Uncommon | tech_production_3 | 6 | 38 |
| lurker_claw_gauntlets | equipment | 39 lurker_ichor, 18 Uncommon | tech_production_3 | 6 | 43 |
| lurker_fang_blade | equipment | 39 lurker_ichor, 20 iron_ore | tech_production_3 | 6 | 47 |
| troll_hide_mantle | equipment | 84 troll_hide, 18 Uncommon | tech_production_3 | 6 | 30 |
| trollhide_buckler | equipment | 84 troll_hide, 18 Uncommon | tech_production_3 | 6 | 38 |
| sentinel_visor | equipment | 20 rift_shard, 18 Uncommon | tech_production_3 | 7 | 24 |
| sentinel_ward | equipment | 20 rift_shard, 18 Uncommon | tech_production_3 | 7 | 31 |
| warlords_battleplate | equipment | 41 warlord_iron, 26 Uncommon, 8.0 warlord_emblem | tech_production_4 | 9 | 49 |
| warlords_greatblade | equipment | 41 warlord_iron, 26 Uncommon, 8.0 warlord_emblem | tech_production_4 | 9 | 57 |
| warlords_legguards | equipment | 41 warlord_iron, 26 Uncommon, 8.0 warlord_emblem | tech_production_4 | 9 | 66 |
| warlords_standard_amulet | equipment | 41 warlord_iron, 26 Uncommon, 8.0 warlord_emblem | tech_production_4 | 9 | - |
| brute_core_band | equipment | 263 iron_plating, 26 Uncommon, 25 brute_core | tech_production_4 | 10 | 62 |
| brutes_bulwark_plate | equipment | 263 iron_plating, 26 Uncommon, 25 brute_core | tech_production_4 | 10 | 70 |
| brutes_war_helm | equipment | 263 iron_plating, 26 Uncommon, 25 brute_core | tech_production_4 | 10 | - |
| trollhide_striders | equipment | 151 troll_hide, 26 Uncommon, 17 troll_marrow | tech_production_4 | 10 | 49 |
| trollmarrow_band | equipment | 151 troll_hide, 26 Uncommon, 17 troll_marrow | tech_production_4 | 10 | 58 |
| bogpearl_amulet | equipment | 70 lurker_ichor, 26 Uncommon, 11 bog_pearl | tech_production_4 | 11 | 58 |
| goblin_claw_gauntlets | equipment | 306 goblin_hide, 26 Uncommon, 49 goblin_fang | tech_production_4 | 11 | 59 |
| goblin_fang_circlet | equipment | 306 goblin_hide, 26 Uncommon, 49 goblin_fang | tech_production_4 | 11 | 69 |
| sentinels_aegis | equipment | 36 rift_shard, 26 Uncommon, 8.0 sentinel_core | tech_production_4 | 11 | 40 |
| sentinels_lance | equipment | 36 rift_shard, 26 Uncommon, 8.0 sentinel_core | tech_production_4 | 11 | 51 |
| sentinels_striders | equipment | 36 rift_shard, 26 Uncommon, 8.0 sentinel_core | tech_production_4 | 11 | 59 |
| ascendant_aegis | equipment | 200 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_band | equipment | 200 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_blade | equipment | 300 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_crown | equipment | 200 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_cuirass | equipment | 300 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_greaves | equipment | 200 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_grips | equipment | 200 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_pendant | equipment | 200 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_treads | equipment | 200 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
