# Progression simulation

Expected values (no RNG), from the live game data. Re-run after any data or formula edit.

## Assumptions

- Level curve: `100 x 1.067^(L-1)`, cap 50; skill point every 5 levels
- XP: kill {0: 5, 1: 15, 2: 100} (standard/elite/boss), wave 25, mission 150
- Hero kill share: 35% full XP, 15% half XP, rest none (`--hero-inner/--hero-outer`)
- 6 towers placed, foundation tier 1, archetype `physical` (surplus)
- Difficulty 1; reward multiplier per tier [1.0, 1.3, 1.7] (game values)
- Menagerie quality bonus x1.0, win rate 100%, no tarot
- Plan (cycled): the_ashfields -> the_broodwarrens -> the_coilmarsh -> the_duskwood -> the_foothills -> the_gap -> the_hollow -> the_mirefen -> the_narrows -> the_riftgate -> the_shardplain -> the_twinpass
- No Ascension climb (`--ascend-after N` to model the endgame)
- Bag: 8 slots (Inventory slots minus the hero's equip slots), stacks of 99 (ascendant_shard 999); overflow lost, shards held; equipment assumed worn, crafted goods used; no discard

## One run of each mission

| Mission | Waves | Kills S/E/B | XP | Common | Uncommon | Rare | Surplus each | Lures |
|---|---|---|---|---|---|---|---|---|
| The Ashfields | 8 | 41/4/1 | 502 | 129 | 3.6 | 17 | 6.0 | 3.27 |
| The Broodwarrens | 9 | 48/4/1 | 541 | 176 | 10 | 26 | 6.0 | 3.51 |
| The Coilmarsh | 10 | 69/7/1 | 628 | 281 | 48 | 82 | 6.0 | 4.97 |
| The Duskwood | 10 | 51/6/1 | 585 | 194 | 48 | 68 | 6.0 | 3.89 |
| The Foothills | 8 | 38/5/1 | 502 | 111 | 4.5 | 24 | 6.0 | 3.54 |
| The Gap | 8 | 34/8/1 | 513 | 110 | 27 | 41 | 6.0 | 3.40 |
| The Hollow | 9 | 34/17/1 | 594 | 189 | 13 | 61 | 6.0 | 5.14 |
| The Mirefen | 9 | 46/5/1 | 543 | 138 | 25 | 45 | 6.0 | 3.70 |
| The Narrows | 7 | 27/4/1 | 448 | 76 | 0.0 | 11 | 6.0 | 2.60 |
| The Rift Gate | 11 | 89/9/2 | 749 | 444 | 99 | 143 | 6.0 | 6.54 |
| The Shardplain | 9 | 53/7/1 | 570 | 208 | 20 | 66 | 6.0 | 4.56 |
| The Twinpass | 9 | 58/6/1 | 574 | 188 | 29 | 61 | 6.0 | 4.58 |

## Campaign timeline (70 missions)

| Missions | Hero level | Skill pts (levels) | Total XP | Purchases owned | Gear owned |
|---|---|---|---|---|---|
| 1 | 5 | 1 | 502 | 17/111 | 0/63 |
| 2 | 9 | 1 | 1,043 | 29/111 | 2/63 |
| 4 | 15 | 3 | 2,256 | 40/111 | 8/63 |
| 8 | 22 | 4 | 4,408 | 50/111 | 11/63 |
| 12 | 27 | 5 | 6,750 | 57/111 | 17/63 |
| 20 | 33 | 6 | 11,157 | 67/111 | 23/63 |
| 30 | 39 | 7 | 16,769 | 78/111 | 34/63 |
| 40 | 43 | 8 | 22,504 | 86/111 | 39/63 |
| 60 | 49 | 9 | 33,748 | 93/111 | 46/63 |
| 70 | 50 | 10 | 39,353 | 93/111 | 46/63 |

## Hero power vs enemy HP

Hero attack = 25 base + 2/level + best owned gear per slot (physical_attack). Enemy HP: Brutal x1.7, each Ascension rank x1.15 (max 15). `Rank to match` = the Ascension rank whose HP has grown as much as the hero has since mission 1 on Normal, i.e. the rank that should feel like the first mission. Towers, skills and tarot are NOT modelled; they push the real number higher.

| Missions | Hero level | Gear attack | Hero attack | Power vs mission 1 | Rank to match |
|---|---|---|---|---|---|
| 1 | 5 | 0.0 | 33 | x1.32 | Brutal or lower |
| 2 | 9 | 2.5 | 44 | x1.74 | 1 |
| 4 | 15 | 3.7 | 57 | x2.27 | 3 |
| 8 | 22 | 3.7 | 71 | x2.83 | 4 |
| 12 | 27 | 7.9 | 85 | x3.40 | 5 |
| 20 | 33 | 12 | 101 | x4.04 | 7 |
| 30 | 39 | 15 | 116 | x4.64 | 8 |
| 40 | 43 | 22 | 131 | x5.22 | 9 |
| 60 | 49 | 36 | 157 | x6.26 | 10 |
| 70 | 50 | 36 | 159 | x6.34 | 10 |

## Bag

Slots used at the end of each shopping trip, and income lost because the bag was full during that mission.

| Missions | Slots used | Lost that mission |
|---|---|---|
| 1 | 5/14 | 35 |
| 2 | 9/26 | 12 |
| 4 | 12/38 | 0.0 |
| 8 | 17/38 | 0.0 |
| 12 | 20/38 | 0.0 |
| 20 | 26/38 | 0.0 |
| 30 | 36/38 | 0.0 |
| 40 | 38/38 | 223 |
| 60 | 38/38 | 292 |
| 70 | 38/38 | 690 |

Lost to a full bag over 70 missions: 8,588 of 20,700 (41%): goblin_hide 1,956, spore_dust 1,205, iron_plating 1,135, goblin_fang 1,028, iron_ore 914, common_scrap 509, troll_hide 416, brute_core 350

## Missions to reach each level

| Level | XP to next | Cumulative XP | Missions (avg yield) |
|---|---|---|---|
| 2 | 106 | 100 | 0.2 |
| 5 | 129 | 440 | 0.8 |
| 10 | 179 | 1,179 | 2.1 |
| 15 | 247 | 2,202 | 3.9 |
| 20 | 342 | 3,617 | 6.4 |
| 25 | 474 | 5,574 | 9.9 |
| 30 | 655 | 8,282 | 14.7 |
| 40 | 1,254 | 17,209 | 30.6 |
| 50 | 2,399 | 34,290 | 61.0 |

## Sanctuary purchases

`Affordable` = the first mission whose cumulative income covers this item alone. `Bought` = when a greedy cheapest-first shopper actually gets it, respecting prerequisites. `-` = not within the simulated missions.

| Item | Kind | Cost | Needs | Affordable | Bought |
|---|---|---|---|---|---|
| bag_expansion_1 | bag | 10 Common | -> 14 slots | 1 | 1 |
| bag_expansion_2 | bag | 18 Common, 4.0 Uncommon | bag_expansion_1 -> 20 slots | 1 | 2 |
| bag_expansion_3 | bag | 28 Common, 10 Uncommon | bag_expansion_2 -> 26 slots | 1 | 2 |
| bag_expansion_4 | bag | 36 Common, 18 Uncommon, 5.0 Rare | bag_expansion_3 -> 32 slots | 1 | 3 |
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
| iron_sword | equipment | 20 Material |  | 1 | 2 |
| leather_gloves | equipment | 55 Material |  | 1 | 3 |
| leather_jerkin | equipment | 30 Material |  | 1 | 2 |
| leather_leggings | equipment | 75 Material |  | 1 | 3 |
| lucky_charm_trinket | equipment | 95 Material |  | 1 | 4 |
| reinforced_boots | equipment | 100 Common, 9.0 Uncommon | tech_production_2 | 1 | 8 |
| reinforced_gauntlets | equipment | 110 Common, 10 Uncommon | tech_production_2 | 1 | 9 |
| reinforced_helm | equipment | 90 Common, 8.0 Uncommon | tech_production_2 | 1 | 6 |
| traveler_boots | equipment | 45 Material |  | 1 | 3 |
| warding_band | equipment | 100 Common |  | 1 | 7 |
| wooden_buckler | equipment | 85 Material |  | 1 | 3 |
| habitat_expansion_tier_1 | structure | 20 Common |  | 1 | 2 |
| habitat_expansion_tier_2 | structure | 35 Common, 12 Uncommon | habitat_expansion_tier_1 | 1 | 3 |
| habitat_expansion_tier_3 | structure | 55 Common, 25 Uncommon, 8.0 Rare | habitat_expansion_tier_2 | 1 | 4 |
| watchtower_tier_1 | structure | 25 Common | tech_structural_1 | 1 | 8 |
| tech_production_2 | tech | 100 Common |  | 1 | 5 |
| tech_structural_1 | tech | 100 Common |  | 1 | 7 |
| advanced_weapon_component | tower component | 2.0 Material | tech_production_2 | 1 | 6 |
| archer_focus_component | tower component | 3.0 focus_surplus |  | 1 | 2 |
| archer_foundation_component | tower component | 3.0 foundation_surplus |  | 1 | 1 |
| archer_power_component | tower component | 3.0 power_surplus |  | 1 | 2 |
| archer_weapon_component | tower component | 3.0 weapon_surplus |  | 1 | 2 |
| basic_focus_component | tower component | 6.0 Material |  | 1 | 1 |
| basic_shaft_component | tower component | 6.0 Material |  | 1 | 1 |
| basic_top_component | tower component | 8.0 Material |  | 1 | 1 |
| iron_foundation_component | tower component | 5.0 Material |  | 1 | 1 |
| masterwork_power_component | tower component | 19 Common, 10 Uncommon | tech_production_3 | 1 | 19 |
| masterwork_weapon_component | tower component | 19 Common, 10 Uncommon | tech_production_3 | 1 | 19 |
| reinforced_focus_component | tower component | 4.0 Material | tech_production_2 | 1 | 6 |
| reinforced_foundation_component | tower component | 4.0 Material | tech_production_2 | 1 | 6 |
| reinforced_power_component | tower component | 4.0 Material | tech_production_2 | 1 | 6 |
| tier4_power_component | tower component | 32 Common, 16 Uncommon, 8.0 Rare | tech_production_4 | 1 | 35 |
| upgrade_habitat_expansion_boundless | upgrade | 12 Common | creature:emberwing_moth, tarot:apex_predator, equipment:brutes_bulwark_plate | 1 | 1 |
| upgrade_habitat_expansion_bountiful | upgrade | 12 Common | equipment:iron_greaves, creature:mossback_toad | 1 | 1 |
| upgrade_habitat_expansion_flourishing | upgrade | 22 Common | upgrade_habitat_expansion_bountiful creature:aurora_stag, tarot:bountiful_harvest, equipment:warding_band | 1 | 2 |
| upgrade_habitat_expansion_sheltered | upgrade | 12 Common | creature:aurora_stag, equipment:leather_leggings | 1 | 1 |
| upgrade_habitat_expansion_thriving | upgrade | 12 Common | creature:duskfang_fox, tarot:steady_hand | 1 | 1 |
| upgrade_watchtower_reinforced | upgrade | 12 Common | building:habitat_expansion_tier_1, creature:glimmer_hare, tarot:iron_resolve | 1 | 2 |
| upgrade_watchtower_vigilant | upgrade | 22 Common | upgrade_watchtower_reinforced creature:duskfang_fox, tarot:grim_resolve, equipment:iron_helm | 1 | 2 |
| bag_expansion_5 | bag | 45 Common, 28 Uncommon, 12 Rare | bag_expansion_4 -> 38 slots | 2 | 4 |
| bogwater_tonic | crafted good | 6.0 lurker_ichor |  | 2 | 2 |
| iron_band | equipment | 150 Common, 14 Uncommon | tech_production_2 | 2 | 11 |
| iron_buckler | equipment | 130 Common, 12 Uncommon | tech_production_2 | 2 | 10 |
| reinforced_plate | equipment | 140 Common, 13 Uncommon | tech_production_2 | 2 | 11 |
| silver_pendant | equipment | 160 Common, 15 Uncommon | tech_production_2 | 2 | 12 |
| steel_greatsword | equipment | 175 Common, 16 Uncommon | tech_production_2 | 2 | 13 |
| steelwrought_gauntlets | equipment | 220 Common, 21 Uncommon, 12 iron_ore | tech_production_2 | 2 | 22 |
| steelwrought_helm | equipment | 230 Common, 22 Uncommon, 12 iron_ore | tech_production_2 | 2 | 23 |
| steelwrought_sabatons | equipment | 190 Common, 18 Uncommon, 10 iron_ore | tech_production_2 | 2 | 14 |
| steelwrought_signet | equipment | 200 Common, 19 Uncommon | tech_production_2 | 2 | 15 |
| steelwrought_torc | equipment | 210 Common, 20 Uncommon | tech_production_2 | 2 | 16 |
| habitat_expansion_tier_4 | structure | 80 Common, 45 Uncommon, 15 Rare | habitat_expansion_tier_3 | 2 | 10 |
| tech_production_3 | tech | 220 Common, 30 Uncommon | tech_production_2 | 2 | 18 |
| tech_structural_2 | tech | 220 Common, 30 Uncommon | tech_structural_1 | 2 | 20 |
| riftglass_ward | crafted good | 8.0 rift_shard |  | 3 | 3 |
| steelwrought_cuirass | equipment | 265 Common, 26 Uncommon, 16 iron_ore | tech_production_2 | 3 | 27 |
| steelwrought_kite_shield | equipment | 240 Common, 23 Uncommon, 14 iron_ore | tech_production_2 | 3 | 24 |
| steelwrought_legplates | equipment | 250 Common, 24 Uncommon, 14 iron_ore | tech_production_2 | 3 | 26 |
| steelwrought_longsword | equipment | 280 Common, 28 Uncommon, 18 iron_ore | tech_production_2 | 3 | 28 |
| tech_production_4 | tech | 380 Common, 50 Uncommon, 32 Rare | tech_production_3 | 3 | 34 |
| tech_structural_3 | tech | 380 Common, 50 Uncommon, 32 Rare | tech_structural_2 | 3 | 37 |
| goblin_raider_leggings | equipment | 170 goblin_hide, 18 Uncommon | tech_production_3 | 4 | 22 |
| goblin_signet | equipment | 170 goblin_hide, 18 Uncommon | tech_production_3 | 4 | 34 |
| sentinel_visor | equipment | 20 rift_shard, 18 Uncommon | tech_production_3 | 4 | 19 |
| sentinel_ward | equipment | 20 rift_shard, 18 Uncommon | tech_production_3 | 4 | 21 |
| brute_gauntlets | equipment | 146 iron_plating, 18 Uncommon | tech_production_3 | 5 | 32 |
| brute_legguards | equipment | 146 iron_plating, 18 Uncommon | tech_production_3 | 5 | - |
| ichor_charm | equipment | 39 lurker_ichor, 18 Uncommon | tech_production_3 | 5 | 20 |
| lurker_claw_gauntlets | equipment | 39 lurker_ichor, 18 Uncommon | tech_production_3 | 5 | 26 |
| lurker_fang_blade | equipment | 39 lurker_ichor, 20 iron_ore | tech_production_3 | 5 | 29 |
| warlords_greaves | equipment | 23 warlord_iron, 18 Uncommon | tech_production_3 | 5 | 22 |
| troll_hide_mantle | equipment | 84 troll_hide, 18 Uncommon | tech_production_3 | 6 | 31 |
| trollhide_buckler | equipment | 84 troll_hide, 18 Uncommon | tech_production_3 | 6 | 42 |
| goblin_claw_gauntlets | equipment | 306 goblin_hide, 26 Uncommon, 49 goblin_fang | tech_production_4 | 7 | - |
| goblin_fang_circlet | equipment | 306 goblin_hide, 26 Uncommon, 49 goblin_fang | tech_production_4 | 7 | - |
| bogpearl_amulet | equipment | 70 lurker_ichor, 26 Uncommon, 11 bog_pearl | tech_production_4 | 8 | 43 |
| sentinels_aegis | equipment | 36 rift_shard, 26 Uncommon, 8.0 sentinel_core | tech_production_4 | 8 | 35 |
| sentinels_lance | equipment | 36 rift_shard, 26 Uncommon, 8.0 sentinel_core | tech_production_4 | 8 | 44 |
| sentinels_striders | equipment | 36 rift_shard, 26 Uncommon, 8.0 sentinel_core | tech_production_4 | 8 | 52 |
| trollhide_striders | equipment | 151 troll_hide, 26 Uncommon, 17 troll_marrow | tech_production_4 | 8 | - |
| trollmarrow_band | equipment | 151 troll_hide, 26 Uncommon, 17 troll_marrow | tech_production_4 | 8 | - |
| brute_core_band | equipment | 263 iron_plating, 26 Uncommon, 25 brute_core | tech_production_4 | 9 | - |
| brutes_bulwark_plate | equipment | 263 iron_plating, 26 Uncommon, 25 brute_core | tech_production_4 | 9 | - |
| brutes_war_helm | equipment | 263 iron_plating, 26 Uncommon, 25 brute_core | tech_production_4 | 9 | - |
| warlords_battleplate | equipment | 41 warlord_iron, 26 Uncommon, 8.0 warlord_emblem | tech_production_4 | 10 | 36 |
| warlords_greatblade | equipment | 41 warlord_iron, 26 Uncommon, 8.0 warlord_emblem | tech_production_4 | 10 | 42 |
| warlords_legguards | equipment | 41 warlord_iron, 26 Uncommon, 8.0 warlord_emblem | tech_production_4 | 10 | 48 |
| warlords_standard_amulet | equipment | 41 warlord_iron, 26 Uncommon, 8.0 warlord_emblem | tech_production_4 | 10 | 54 |
| ascendant_aegis | equipment | 200 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_band | equipment | 200 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_blade | equipment | 300 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_crown | equipment | 200 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_cuirass | equipment | 300 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_greaves | equipment | 200 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_grips | equipment | 200 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_pendant | equipment | 200 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
| ascendant_treads | equipment | 200 ascendant_shard, 20 Rare, 30 Uncommon | tech_production_4 | - | - |
