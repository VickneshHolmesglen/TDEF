# Progression simulation

Expected values (no RNG), from the live game data. Re-run after any data or formula edit.

## Assumptions

- Level curve: `100 x 1.15^(L-1)`, cap 50; skill point every 5 levels
- XP: kill {0: 5, 1: 15, 2: 100} (standard/elite/boss), wave 25, mission 150
- Hero kill share: 35% full XP, 15% half XP, rest none (`--hero-inner/--hero-outer`)
- 6 towers placed, foundation tier 1, archetype `physical` (surplus)
- Difficulty 1; reward multiplier per tier [1.0, 1.0, 1.0] (game has none)
- Menagerie quality bonus x1.0, win rate 100%, no tarot
- Plan (cycled): the_foothills -> the_gap -> the_hollow -> the_narrows

## One run of each mission

| Mission | Waves | Kills S/E/B | XP | Common | Uncommon | Rare | Surplus each | Lures |
|---|---|---|---|---|---|---|---|---|
| The Foothills | 5 | 18/3/1 | 373 | 46 | 1.8 | 9.0 | 6.0 | 2.03 |
| The Gap | 6 | 22/7/1 | 432 | 68 | 13 | 21 | 6.0 | 2.65 |
| The Hollow | 7 | 21/13/1 | 492 | 97 | 4.0 | 31 | 6.0 | 3.74 |
| The Narrows | 4 | 12/3/1 | 336 | 35 | 0.0 | 4.3 | 6.0 | 1.52 |

## Campaign timeline (40 missions)

| Missions | Hero level | Skill pts (levels) | Total XP | Purchases owned |
|---|---|---|---|---|
| 1 | 4 | 0 | 373 | 19/88 |
| 2 | 6 | 1 | 805 | 25/88 |
| 4 | 9 | 1 | 1,633 | 47/88 |
| 8 | 13 | 2 | 3,267 | 56/88 |
| 12 | 16 | 3 | 4,900 | 64/88 |
| 20 | 19 | 3 | 8,167 | 75/88 |
| 30 | 22 | 4 | 12,239 | 79/88 |
| 40 | 24 | 4 | 16,335 | 81/88 |

## Missions to reach each level

| Level | XP to next | Cumulative XP | Missions (avg yield) |
|---|---|---|---|
| 2 | 114 | 100 | 0.2 |
| 5 | 174 | 498 | 1.2 |
| 10 | 351 | 1,675 | 4.1 |
| 15 | 707 | 4,045 | 9.9 |
| 20 | 1,423 | 8,813 | 21.6 |
| 25 | 2,862 | 18,407 | 45.1 |
| 30 | 5,757 | 37,704 | 92.3 |
| 40 | 23,292 | 154,599 | 378.6 |
| 50 | 94,231 | 627,518 | 1536.7 |

## Sanctuary purchases

`Affordable` = the first mission whose cumulative income covers this item alone. `Bought` = when a greedy cheapest-first shopper actually gets it, respecting prerequisites. `-` = not within the simulated missions.

| Item | Kind | Cost | Needs | Affordable | Bought |
|---|---|---|---|---|---|
| healing_salve | crafted good | 3.0 Material |  | 1 | 1 |
| healing_salve | crafted good | 6.0 Common |  | 1 | 1 |
| hunters_draught | crafted good | 4.0 Material |  | 1 | 1 |
| ironplate_ration | crafted good | 4.0 iron_plating |  | 1 | 1 |
| spore_poultice | crafted good | 5.0 spore_dust |  | 1 | 3 |
| brute_gauntlets | equipment | 19 iron_plating, 10 Uncommon | tech_production_3 | 1 | 9 |
| brute_legguards | equipment | 19 iron_plating, 10 Uncommon | tech_production_3 | 1 | 11 |
| iron_band | equipment | 6.0 Material | tech_production_2 | 1 | 4 |
| iron_buckler | equipment | 6.0 Material | tech_production_2 | 1 | 4 |
| iron_greaves | equipment | 6.0 Material | tech_production_2 | 1 | 4 |
| iron_helm | equipment | 5.0 Material |  | 1 | 1 |
| iron_sword | equipment | 4.0 Material |  | 1 | 1 |
| leather_gloves | equipment | 3.0 Material |  | 1 | 1 |
| leather_jerkin | equipment | 5.0 Material |  | 1 | 1 |
| leather_leggings | equipment | 4.0 Material |  | 1 | 1 |
| lucky_charm_trinket | equipment | 3.0 Material |  | 1 | 1 |
| reinforced_boots | equipment | 6.0 Material | tech_production_2 | 1 | 4 |
| reinforced_gauntlets | equipment | 6.0 Material | tech_production_2 | 1 | 4 |
| reinforced_helm | equipment | 6.0 Material | tech_production_2 | 1 | 4 |
| reinforced_plate | equipment | 6.0 Material | tech_production_2 | 1 | 4 |
| silver_pendant | equipment | 6.0 Material | tech_production_2 | 1 | 4 |
| steel_greatsword | equipment | 13 Common, 6.0 Uncommon | tech_production_2 | 1 | 3 |
| traveler_boots | equipment | 3.0 Material |  | 1 | 1 |
| warding_band | equipment | 8.0 Common |  | 1 | 2 |
| wooden_buckler | equipment | 4.0 Material |  | 1 | 1 |
| habitat_expansion_tier_1 | structure | 20 Common |  | 1 | 3 |
| habitat_expansion_tier_2 | structure | 35 Common, 12 Uncommon | habitat_expansion_tier_1 | 1 | 7 |
| watchtower_tier_1 | structure | 25 Common | tech_structural_1 | 1 | 5 |
| tech_production_2 | tech | 15 Common |  | 1 | 3 |
| tech_production_3 | tech | 27 Common, 14 Uncommon | tech_production_2 | 1 | 6 |
| tech_structural_1 | tech | 15 Common |  | 1 | 3 |
| tech_structural_2 | tech | 27 Common, 14 Uncommon | tech_structural_1 | 1 | 6 |
| advanced_weapon_component | tower component | 2.0 Material | tech_production_2 | 1 | 4 |
| archer_focus_component | tower component | 3.0 focus_surplus |  | 1 | 1 |
| archer_foundation_component | tower component | 3.0 foundation_surplus |  | 1 | 1 |
| archer_power_component | tower component | 3.0 power_surplus |  | 1 | 1 |
| archer_weapon_component | tower component | 3.0 weapon_surplus |  | 1 | 1 |
| basic_focus_component | tower component | 6.0 Material |  | 1 | 1 |
| basic_shaft_component | tower component | 6.0 Material |  | 1 | 1 |
| basic_top_component | tower component | 8.0 Material |  | 1 | 1 |
| iron_foundation_component | tower component | 5.0 Material |  | 1 | 1 |
| masterwork_power_component | tower component | 19 Common, 10 Uncommon | tech_production_3 | 1 | 7 |
| masterwork_weapon_component | tower component | 19 Common, 10 Uncommon | tech_production_3 | 1 | 7 |
| reinforced_focus_component | tower component | 4.0 Material | tech_production_2 | 1 | 4 |
| reinforced_foundation_component | tower component | 4.0 Material | tech_production_2 | 1 | 4 |
| reinforced_power_component | tower component | 4.0 Material | tech_production_2 | 1 | 4 |
| tier4_power_component | tower component | 32 Common, 16 Uncommon, 8.0 Rare | tech_production_4 | 1 | 9 |
| upgrade_habitat_expansion_boundless | upgrade | 12 Common | creature:emberwing_moth, tarot:apex_predator, equipment:brutes_bulwark_plate | 1 | 2 |
| upgrade_habitat_expansion_bountiful | upgrade | 12 Common | equipment:iron_greaves, creature:mossback_toad | 1 | 2 |
| upgrade_habitat_expansion_flourishing | upgrade | 22 Common | upgrade_habitat_expansion_bountiful creature:aurora_stag, tarot:bountiful_harvest, equipment:warding_band | 1 | 4 |
| upgrade_habitat_expansion_sheltered | upgrade | 12 Common | creature:aurora_stag, equipment:leather_leggings | 1 | 2 |
| upgrade_habitat_expansion_thriving | upgrade | 12 Common | creature:duskfang_fox, tarot:steady_hand | 1 | 3 |
| upgrade_watchtower_reinforced | upgrade | 12 Common | building:habitat_expansion_tier_1, creature:glimmer_hare, tarot:iron_resolve | 1 | 3 |
| upgrade_watchtower_vigilant | upgrade | 22 Common | upgrade_watchtower_reinforced creature:duskfang_fox, tarot:grim_resolve, equipment:iron_helm | 1 | 5 |
| goblinhide_bandage | crafted good | 5.0 goblin_hide |  | 2 | 2 |
| travelers_bedroll | crafted good | 7.0 troll_hide, 3.0 common_scrap |  | 2 | 3 |
| warlords_field_ration | crafted good | 6.0 warlord_iron, 3.0 iron_plating |  | 2 | 2 |
| goblin_raider_leggings | equipment | 19 goblin_hide, 10 Uncommon | tech_production_3 | 2 | 10 |
| goblin_signet | equipment | 19 goblin_hide, 10 Uncommon | tech_production_3 | 2 | 14 |
| troll_hide_mantle | equipment | 19 troll_hide, 10 Uncommon | tech_production_3 | 2 | 10 |
| trollhide_buckler | equipment | 19 troll_hide, 10 Uncommon | tech_production_3 | 2 | 11 |
| habitat_expansion_tier_3 | structure | 55 Common, 25 Uncommon, 8.0 Rare | habitat_expansion_tier_2 | 2 | 11 |
| habitat_expansion_tier_4 | structure | 80 Common, 45 Uncommon, 15 Rare | habitat_expansion_tier_3 | 2 | 14 |
| tech_production_4 | tech | 45 Common, 24 Uncommon, 12 Rare | tech_production_3 | 2 | 8 |
| tech_structural_3 | tech | 45 Common, 24 Uncommon, 12 Rare | tech_structural_2 | 2 | 10 |
| bogwater_tonic | crafted good | 6.0 lurker_ichor |  | 3 | 3 |
| brute_core_band | equipment | 32 iron_plating, 16 Uncommon, 8.0 brute_core | tech_production_4 | 3 | 13 |
| brutes_bulwark_plate | equipment | 32 iron_plating, 16 Uncommon, 8.0 brute_core | tech_production_4 | 3 | 16 |
| brutes_war_helm | equipment | 32 iron_plating, 16 Uncommon, 8.0 brute_core | tech_production_4 | 3 | 17 |
| goblin_claw_gauntlets | equipment | 32 goblin_hide, 16 Uncommon, 8.0 goblin_fang | tech_production_4 | 3 | 18 |
| goblin_fang_circlet | equipment | 32 goblin_hide, 16 Uncommon, 8.0 goblin_fang | tech_production_4 | 3 | 22 |
| trollhide_striders | equipment | 32 troll_hide, 16 Uncommon, 8.0 troll_marrow | tech_production_4 | 3 | 18 |
| trollmarrow_band | equipment | 32 troll_hide, 16 Uncommon, 8.0 troll_marrow | tech_production_4 | 3 | 19 |
| riftglass_ward | crafted good | 8.0 rift_shard |  | 4 | 7 |
| ichor_charm | equipment | 19 lurker_ichor, 10 Uncommon | tech_production_3 | 5 | 16 |
| lurker_claw_gauntlets | equipment | 19 lurker_ichor, 10 Uncommon | tech_production_3 | 5 | 21 |
| lurker_fang_blade | equipment | 19 lurker_ichor, 10 iron_ore | tech_production_3 | 5 | 27 |
| warlords_greaves | equipment | 19 warlord_iron, 10 Uncommon | tech_production_3 | 6 | 18 |
| bogpearl_amulet | equipment | 32 lurker_ichor, 16 Uncommon, 8.0 bog_pearl | tech_production_4 | 8 | 35 |
| sentinel_visor | equipment | 19 rift_shard, 10 Uncommon | tech_production_3 | 11 | 20 |
| sentinel_ward | equipment | 19 rift_shard, 10 Uncommon | tech_production_3 | 11 | 31 |
| warlords_battleplate | equipment | 32 warlord_iron, 16 Uncommon, 8.0 warlord_emblem | tech_production_4 | 13 | 30 |
| warlords_greatblade | equipment | 32 warlord_iron, 16 Uncommon, 8.0 warlord_emblem | tech_production_4 | 13 | - |
| warlords_legguards | equipment | 32 warlord_iron, 16 Uncommon, 8.0 warlord_emblem | tech_production_4 | 13 | - |
| warlords_standard_amulet | equipment | 32 warlord_iron, 16 Uncommon, 8.0 warlord_emblem | tech_production_4 | 13 | - |
| sentinels_aegis | equipment | 32 rift_shard, 16 Uncommon, 8.0 sentinel_core | tech_production_4 | 15 | - |
| sentinels_lance | equipment | 32 rift_shard, 16 Uncommon, 8.0 sentinel_core | tech_production_4 | 15 | - |
| sentinels_striders | equipment | 32 rift_shard, 16 Uncommon, 8.0 sentinel_core | tech_production_4 | 15 | - |

Note: 18 purchases list a gold cost (total 1,846), but gold resets every mission (MissionEconomy) and there is no persistent Sanctuary gold, so gold is ignored here.
