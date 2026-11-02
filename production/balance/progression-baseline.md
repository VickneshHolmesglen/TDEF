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

| Missions | Hero level | Skill pts (levels) | Total XP | Purchases owned |
|---|---|---|---|---|
| 1 | 5 | 1 | 502 | 25/97 |
| 2 | 9 | 1 | 1,043 | 37/97 |
| 4 | 14 | 2 | 2,130 | 60/97 |
| 8 | 21 | 4 | 4,228 | 74/97 |
| 12 | 26 | 5 | 6,357 | 84/97 |
| 20 | 33 | 6 | 10,585 | 90/97 |
| 30 | 38 | 7 | 15,920 | 94/97 |
| 40 | 42 | 8 | 21,139 | 96/97 |
| 60 | 48 | 9 | 31,725 | 96/97 |
| 70 | 50 | 10 | 37,059 | 96/97 |

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
| travelers_bedroll | crafted good | 7.0 troll_hide, 3.0 common_scrap |  | 1 | 2 |
| warlords_field_ration | crafted good | 6.0 warlord_iron, 3.0 iron_plating |  | 1 | 1 |
| brute_gauntlets | equipment | 19 iron_plating, 10 Uncommon | tech_production_3 | 1 | 4 |
| brute_legguards | equipment | 19 iron_plating, 10 Uncommon | tech_production_3 | 1 | 6 |
| iron_band | equipment | 6.0 Material | tech_production_2 | 1 | 3 |
| iron_buckler | equipment | 6.0 Material | tech_production_2 | 1 | 3 |
| iron_greaves | equipment | 6.0 Material | tech_production_2 | 1 | 3 |
| iron_helm | equipment | 5.0 Material |  | 1 | 1 |
| iron_sword | equipment | 4.0 Material |  | 1 | 1 |
| leather_gloves | equipment | 3.0 Material |  | 1 | 1 |
| leather_jerkin | equipment | 5.0 Material |  | 1 | 1 |
| leather_leggings | equipment | 4.0 Material |  | 1 | 1 |
| lucky_charm_trinket | equipment | 3.0 Material |  | 1 | 1 |
| reinforced_boots | equipment | 6.0 Material | tech_production_2 | 1 | 3 |
| reinforced_gauntlets | equipment | 6.0 Material | tech_production_2 | 1 | 3 |
| reinforced_helm | equipment | 6.0 Material | tech_production_2 | 1 | 3 |
| reinforced_plate | equipment | 6.0 Material | tech_production_2 | 1 | 3 |
| silver_pendant | equipment | 6.0 Material | tech_production_2 | 1 | 3 |
| steel_greatsword | equipment | 13 Common, 6.0 Uncommon | tech_production_2 | 1 | 2 |
| steelwrought_signet | equipment | 30 Common, 9.0 Uncommon | tech_production_2 | 1 | 3 |
| steelwrought_torc | equipment | 30 Common, 9.0 Uncommon | tech_production_2 | 1 | 3 |
| traveler_boots | equipment | 3.0 Material |  | 1 | 1 |
| warding_band | equipment | 8.0 Common |  | 1 | 1 |
| wooden_buckler | equipment | 4.0 Material |  | 1 | 1 |
| habitat_expansion_tier_1 | structure | 20 Common |  | 1 | 2 |
| habitat_expansion_tier_2 | structure | 35 Common, 12 Uncommon | habitat_expansion_tier_1 | 1 | 4 |
| habitat_expansion_tier_3 | structure | 55 Common, 25 Uncommon, 8.0 Rare | habitat_expansion_tier_2 | 1 | 12 |
| watchtower_tier_1 | structure | 25 Common | tech_structural_1 | 1 | 2 |
| tech_production_2 | tech | 15 Common |  | 1 | 2 |
| tech_production_3 | tech | 27 Common, 14 Uncommon | tech_production_2 | 1 | 3 |
| tech_production_4 | tech | 45 Common, 24 Uncommon, 12 Rare | tech_production_3 | 1 | 6 |
| tech_structural_1 | tech | 15 Common |  | 1 | 2 |
| tech_structural_2 | tech | 27 Common, 14 Uncommon | tech_structural_1 | 1 | 3 |
| tech_structural_3 | tech | 45 Common, 24 Uncommon, 12 Rare | tech_structural_2 | 1 | 11 |
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
| tier4_power_component | tower component | 32 Common, 16 Uncommon, 8.0 Rare | tech_production_4 | 1 | 7 |
| upgrade_habitat_expansion_boundless | upgrade | 12 Common | creature:emberwing_moth, tarot:apex_predator, equipment:brutes_bulwark_plate | 1 | 1 |
| upgrade_habitat_expansion_bountiful | upgrade | 12 Common | equipment:iron_greaves, creature:mossback_toad | 1 | 1 |
| upgrade_habitat_expansion_flourishing | upgrade | 22 Common | upgrade_habitat_expansion_bountiful creature:aurora_stag, tarot:bountiful_harvest, equipment:warding_band | 1 | 2 |
| upgrade_habitat_expansion_sheltered | upgrade | 12 Common | creature:aurora_stag, equipment:leather_leggings | 1 | 2 |
| upgrade_habitat_expansion_thriving | upgrade | 12 Common | creature:duskfang_fox, tarot:steady_hand | 1 | 2 |
| upgrade_watchtower_reinforced | upgrade | 12 Common | building:habitat_expansion_tier_1, creature:glimmer_hare, tarot:iron_resolve | 1 | 2 |
| upgrade_watchtower_vigilant | upgrade | 22 Common | upgrade_watchtower_reinforced creature:duskfang_fox, tarot:grim_resolve, equipment:iron_helm | 1 | 2 |
| bogwater_tonic | crafted good | 6.0 lurker_ichor |  | 2 | 2 |
| brute_core_band | equipment | 32 iron_plating, 16 Uncommon, 8.0 brute_core | tech_production_4 | 2 | 8 |
| brutes_bulwark_plate | equipment | 32 iron_plating, 16 Uncommon, 8.0 brute_core | tech_production_4 | 2 | 10 |
| brutes_war_helm | equipment | 32 iron_plating, 16 Uncommon, 8.0 brute_core | tech_production_4 | 2 | 11 |
| goblin_raider_leggings | equipment | 19 goblin_hide, 10 Uncommon | tech_production_3 | 2 | 5 |
| goblin_signet | equipment | 19 goblin_hide, 10 Uncommon | tech_production_3 | 2 | 5 |
| steelwrought_cuirass | equipment | 44 Common, 10 Uncommon, 8.0 iron_ore | tech_production_2 | 2 | 12 |
| steelwrought_gauntlets | equipment | 32 Common, 8.0 Uncommon, 5.0 iron_ore | tech_production_2 | 2 | 5 |
| steelwrought_helm | equipment | 34 Common, 8.0 Uncommon, 6.0 iron_ore | tech_production_2 | 2 | 6 |
| steelwrought_kite_shield | equipment | 36 Common, 8.0 Uncommon, 6.0 iron_ore | tech_production_2 | 2 | 7 |
| steelwrought_legplates | equipment | 38 Common, 8.0 Uncommon, 6.0 iron_ore | tech_production_2 | 2 | 7 |
| steelwrought_longsword | equipment | 48 Common, 12 Uncommon, 8.0 iron_ore | tech_production_2 | 2 | 13 |
| steelwrought_sabatons | equipment | 30 Common, 7.0 Uncommon, 5.0 iron_ore | tech_production_2 | 2 | 4 |
| troll_hide_mantle | equipment | 19 troll_hide, 10 Uncommon | tech_production_3 | 2 | 5 |
| trollhide_buckler | equipment | 19 troll_hide, 10 Uncommon | tech_production_3 | 2 | 6 |
| warlords_greaves | equipment | 19 warlord_iron, 10 Uncommon | tech_production_3 | 2 | 10 |
| habitat_expansion_tier_4 | structure | 80 Common, 45 Uncommon, 15 Rare | habitat_expansion_tier_3 | 2 | 15 |
| riftglass_ward | crafted good | 8.0 rift_shard |  | 3 | 3 |
| goblin_claw_gauntlets | equipment | 32 goblin_hide, 16 Uncommon, 8.0 goblin_fang | tech_production_4 | 3 | 9 |
| goblin_fang_circlet | equipment | 32 goblin_hide, 16 Uncommon, 8.0 goblin_fang | tech_production_4 | 3 | 11 |
| trollhide_striders | equipment | 32 troll_hide, 16 Uncommon, 8.0 troll_marrow | tech_production_4 | 3 | 11 |
| trollmarrow_band | equipment | 32 troll_hide, 16 Uncommon, 8.0 troll_marrow | tech_production_4 | 3 | 13 |
| ichor_charm | equipment | 19 lurker_ichor, 10 Uncommon | tech_production_3 | 4 | 4 |
| lurker_claw_gauntlets | equipment | 19 lurker_ichor, 10 Uncommon | tech_production_3 | 4 | 6 |
| lurker_fang_blade | equipment | 19 lurker_ichor, 10 iron_ore | tech_production_3 | 4 | 10 |
| warlords_battleplate | equipment | 32 warlord_iron, 16 Uncommon, 8.0 warlord_emblem | tech_production_4 | 5 | 17 |
| warlords_greatblade | equipment | 32 warlord_iron, 16 Uncommon, 8.0 warlord_emblem | tech_production_4 | 5 | 25 |
| warlords_legguards | equipment | 32 warlord_iron, 16 Uncommon, 8.0 warlord_emblem | tech_production_4 | 5 | 29 |
| warlords_standard_amulet | equipment | 32 warlord_iron, 16 Uncommon, 8.0 warlord_emblem | tech_production_4 | 5 | 36 |
| bogpearl_amulet | equipment | 32 lurker_ichor, 16 Uncommon, 8.0 bog_pearl | tech_production_4 | 6 | 14 |
| sentinel_visor | equipment | 19 rift_shard, 10 Uncommon | tech_production_3 | 6 | 8 |
| sentinel_ward | equipment | 19 rift_shard, 10 Uncommon | tech_production_3 | 6 | 14 |
| sentinels_aegis | equipment | 32 rift_shard, 16 Uncommon, 8.0 sentinel_core | tech_production_4 | 11 | 22 |
| sentinels_lance | equipment | 32 rift_shard, 16 Uncommon, 8.0 sentinel_core | tech_production_4 | 11 | 30 |
| sentinels_striders | equipment | 32 rift_shard, 16 Uncommon, 8.0 sentinel_core | tech_production_4 | 11 | 38 |

Note: 18 purchases list a gold cost (total 1,846), but gold resets every mission (MissionEconomy) and there is no persistent Sanctuary gold, so gold is ignored here.
