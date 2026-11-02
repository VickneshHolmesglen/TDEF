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
| 1 | 5 | 1 | 502 | 21/97 | 1/54 |
| 2 | 9 | 1 | 1,043 | 31/97 | 4/54 |
| 4 | 14 | 2 | 2,130 | 44/97 | 6/54 |
| 8 | 21 | 4 | 4,228 | 52/97 | 10/54 |
| 12 | 26 | 5 | 6,357 | 57/97 | 15/54 |
| 20 | 33 | 6 | 10,585 | 65/97 | 23/54 |
| 30 | 38 | 7 | 15,920 | 74/97 | 32/54 |
| 40 | 42 | 8 | 21,139 | 79/97 | 37/54 |
| 60 | 48 | 9 | 31,725 | 92/97 | 50/54 |
| 70 | 50 | 10 | 37,059 | 95/97 | 53/54 |

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
| iron_greaves | equipment | 120 Common, 11 Uncommon | tech_production_2 | 1 | 11 |
| iron_helm | equipment | 65 Material |  | 1 | 3 |
| iron_sword | equipment | 20 Material |  | 1 | 1 |
| leather_gloves | equipment | 55 Material |  | 1 | 2 |
| leather_jerkin | equipment | 30 Material |  | 1 | 2 |
| leather_leggings | equipment | 75 Material |  | 1 | 3 |
| lucky_charm_trinket | equipment | 95 Material |  | 1 | 6 |
| reinforced_boots | equipment | 100 Common, 9.0 Uncommon | tech_production_2 | 1 | 9 |
| reinforced_gauntlets | equipment | 110 Common, 10 Uncommon | tech_production_2 | 1 | 10 |
| reinforced_helm | equipment | 90 Common, 8.0 Uncommon | tech_production_2 | 1 | 7 |
| traveler_boots | equipment | 45 Material |  | 1 | 2 |
| warding_band | equipment | 100 Common |  | 1 | 7 |
| wooden_buckler | equipment | 85 Material |  | 1 | 5 |
| habitat_expansion_tier_1 | structure | 20 Common |  | 1 | 2 |
| habitat_expansion_tier_2 | structure | 35 Common, 12 Uncommon | habitat_expansion_tier_1 | 1 | 3 |
| habitat_expansion_tier_3 | structure | 55 Common, 25 Uncommon, 8.0 Rare | habitat_expansion_tier_2 | 1 | 6 |
| watchtower_tier_1 | structure | 25 Common | tech_structural_1 | 1 | 2 |
| tech_production_2 | tech | 15 Common |  | 1 | 2 |
| tech_production_3 | tech | 27 Common, 14 Uncommon | tech_production_2 | 1 | 3 |
| tech_production_4 | tech | 45 Common, 24 Uncommon, 12 Rare | tech_production_3 | 1 | 4 |
| tech_structural_1 | tech | 15 Common |  | 1 | 2 |
| tech_structural_2 | tech | 27 Common, 14 Uncommon | tech_structural_1 | 1 | 3 |
| tech_structural_3 | tech | 45 Common, 24 Uncommon, 12 Rare | tech_structural_2 | 1 | 5 |
| advanced_weapon_component | tower component | 2.0 Material | tech_production_2 | 1 | 3 |
| archer_focus_component | tower component | 3.0 focus_surplus |  | 1 | 1 |
| archer_foundation_component | tower component | 3.0 foundation_surplus |  | 1 | 1 |
| archer_power_component | tower component | 3.0 power_surplus |  | 1 | 1 |
| archer_weapon_component | tower component | 3.0 weapon_surplus |  | 1 | 1 |
| basic_focus_component | tower component | 6.0 Material |  | 1 | 1 |
| basic_shaft_component | tower component | 6.0 Material |  | 1 | 1 |
| basic_top_component | tower component | 8.0 Material |  | 1 | 1 |
| iron_foundation_component | tower component | 5.0 Material |  | 1 | 1 |
| masterwork_power_component | tower component | 19 Common, 10 Uncommon | tech_production_3 | 1 | 4 |
| masterwork_weapon_component | tower component | 19 Common, 10 Uncommon | tech_production_3 | 1 | 4 |
| reinforced_focus_component | tower component | 4.0 Material | tech_production_2 | 1 | 3 |
| reinforced_foundation_component | tower component | 4.0 Material | tech_production_2 | 1 | 3 |
| reinforced_power_component | tower component | 4.0 Material | tech_production_2 | 1 | 3 |
| tier4_power_component | tower component | 32 Common, 16 Uncommon, 8.0 Rare | tech_production_4 | 1 | 5 |
| upgrade_habitat_expansion_boundless | upgrade | 12 Common | creature:emberwing_moth, tarot:apex_predator, equipment:brutes_bulwark_plate | 1 | 1 |
| upgrade_habitat_expansion_bountiful | upgrade | 12 Common | equipment:iron_greaves, creature:mossback_toad | 1 | 1 |
| upgrade_habitat_expansion_flourishing | upgrade | 22 Common | upgrade_habitat_expansion_bountiful creature:aurora_stag, tarot:bountiful_harvest, equipment:warding_band | 1 | 2 |
| upgrade_habitat_expansion_sheltered | upgrade | 12 Common | creature:aurora_stag, equipment:leather_leggings | 1 | 1 |
| upgrade_habitat_expansion_thriving | upgrade | 12 Common | creature:duskfang_fox, tarot:steady_hand | 1 | 1 |
| upgrade_watchtower_reinforced | upgrade | 12 Common | building:habitat_expansion_tier_1, creature:glimmer_hare, tarot:iron_resolve | 1 | 1 |
| upgrade_watchtower_vigilant | upgrade | 22 Common | upgrade_watchtower_reinforced creature:duskfang_fox, tarot:grim_resolve, equipment:iron_helm | 1 | 2 |
| bogwater_tonic | crafted good | 6.0 lurker_ichor |  | 2 | 2 |
| iron_band | equipment | 150 Common, 14 Uncommon | tech_production_2 | 2 | 14 |
| iron_buckler | equipment | 130 Common, 12 Uncommon | tech_production_2 | 2 | 11 |
| reinforced_plate | equipment | 140 Common, 13 Uncommon | tech_production_2 | 2 | 12 |
| silver_pendant | equipment | 160 Common, 15 Uncommon | tech_production_2 | 2 | 15 |
| steel_greatsword | equipment | 175 Common, 16 Uncommon | tech_production_2 | 2 | 17 |
| steelwrought_gauntlets | equipment | 220 Common, 21 Uncommon, 12 iron_ore | tech_production_2 | 2 | 23 |
| steelwrought_helm | equipment | 230 Common, 22 Uncommon, 12 iron_ore | tech_production_2 | 2 | 25 |
| steelwrought_sabatons | equipment | 190 Common, 18 Uncommon, 10 iron_ore | tech_production_2 | 2 | 18 |
| steelwrought_signet | equipment | 200 Common, 19 Uncommon | tech_production_2 | 2 | 19 |
| steelwrought_torc | equipment | 210 Common, 20 Uncommon | tech_production_2 | 2 | 21 |
| habitat_expansion_tier_4 | structure | 80 Common, 45 Uncommon, 15 Rare | habitat_expansion_tier_3 | 2 | 8 |
| riftglass_ward | crafted good | 8.0 rift_shard |  | 3 | 3 |
| steelwrought_cuirass | equipment | 265 Common, 26 Uncommon, 16 iron_ore | tech_production_2 | 3 | 30 |
| steelwrought_kite_shield | equipment | 240 Common, 23 Uncommon, 14 iron_ore | tech_production_2 | 3 | 27 |
| steelwrought_legplates | equipment | 250 Common, 24 Uncommon, 14 iron_ore | tech_production_2 | 3 | 28 |
| steelwrought_longsword | equipment | 280 Common, 28 Uncommon, 18 iron_ore | tech_production_2 | 3 | 33 |
| warlords_greaves | equipment | 23 warlord_iron, 18 Uncommon | tech_production_3 | 4 | 17 |
| goblin_raider_leggings | equipment | 170 goblin_hide, 18 Uncommon | tech_production_3 | 5 | 37 |
| goblin_signet | equipment | 170 goblin_hide, 18 Uncommon | tech_production_3 | 5 | 43 |
| brute_gauntlets | equipment | 146 iron_plating, 18 Uncommon | tech_production_3 | 6 | 38 |
| brute_legguards | equipment | 146 iron_plating, 18 Uncommon | tech_production_3 | 6 | 44 |
| ichor_charm | equipment | 39 lurker_ichor, 18 Uncommon | tech_production_3 | 6 | 23 |
| lurker_claw_gauntlets | equipment | 39 lurker_ichor, 18 Uncommon | tech_production_3 | 6 | 36 |
| lurker_fang_blade | equipment | 39 lurker_ichor, 20 iron_ore | tech_production_3 | 6 | 42 |
| troll_hide_mantle | equipment | 84 troll_hide, 18 Uncommon | tech_production_3 | 6 | 14 |
| trollhide_buckler | equipment | 84 troll_hide, 18 Uncommon | tech_production_3 | 6 | 30 |
| sentinel_visor | equipment | 20 rift_shard, 18 Uncommon | tech_production_3 | 7 | 16 |
| sentinel_ward | equipment | 20 rift_shard, 18 Uncommon | tech_production_3 | 7 | 22 |
| warlords_battleplate | equipment | 41 warlord_iron, 26 Uncommon, 8.0 warlord_emblem | tech_production_4 | 9 | 41 |
| warlords_greatblade | equipment | 41 warlord_iron, 26 Uncommon, 8.0 warlord_emblem | tech_production_4 | 9 | 49 |
| warlords_legguards | equipment | 41 warlord_iron, 26 Uncommon, 8.0 warlord_emblem | tech_production_4 | 9 | 58 |
| warlords_standard_amulet | equipment | 41 warlord_iron, 26 Uncommon, 8.0 warlord_emblem | tech_production_4 | 9 | 66 |
| brute_core_band | equipment | 263 iron_plating, 26 Uncommon, 25 brute_core | tech_production_4 | 10 | 52 |
| brutes_bulwark_plate | equipment | 263 iron_plating, 26 Uncommon, 25 brute_core | tech_production_4 | 10 | 62 |
| brutes_war_helm | equipment | 263 iron_plating, 26 Uncommon, 25 brute_core | tech_production_4 | 10 | - |
| trollhide_striders | equipment | 151 troll_hide, 26 Uncommon, 17 troll_marrow | tech_production_4 | 10 | 41 |
| trollmarrow_band | equipment | 151 troll_hide, 26 Uncommon, 17 troll_marrow | tech_production_4 | 10 | 51 |
| bogpearl_amulet | equipment | 70 lurker_ichor, 26 Uncommon, 11 bog_pearl | tech_production_4 | 11 | 51 |
| goblin_claw_gauntlets | equipment | 306 goblin_hide, 26 Uncommon, 49 goblin_fang | tech_production_4 | 11 | 51 |
| goblin_fang_circlet | equipment | 306 goblin_hide, 26 Uncommon, 49 goblin_fang | tech_production_4 | 11 | 61 |
| sentinels_aegis | equipment | 36 rift_shard, 26 Uncommon, 8.0 sentinel_core | tech_production_4 | 11 | 39 |
| sentinels_lance | equipment | 36 rift_shard, 26 Uncommon, 8.0 sentinel_core | tech_production_4 | 11 | 48 |
| sentinels_striders | equipment | 36 rift_shard, 26 Uncommon, 8.0 sentinel_core | tech_production_4 | 11 | 59 |

Note: 18 purchases list a gold cost (total 1,846), but gold resets every mission (MissionEconomy) and there is no persistent Sanctuary gold, so gold is ignored here.
