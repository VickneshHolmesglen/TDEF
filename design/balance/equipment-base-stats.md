# Equipment base_stats Budget

**Authored**: 2026-09-20 (follow-up to `docs/superpowers/specs/2026-09-20-equipment-stats-wiring-design.md`, which wired equipment into Hero but left `base_stats` empty).
**Scope**: the 45 equipment `ItemDefinitionResource`s in `assets/data/items/` (5 per slot × 9 categories; the wiring spec's "36" was stale). Supporting-modifier items (`sup_mod_*`) are not equipment and stay empty.
**Status**: first-pass numbers, unplaytested. All values are flat bonuses (Hero Formula 1 flat bucket); crafted items start with empty `stat_overrides`, so these are what applies.

## Method

`value = unit[stat] × weight × tier_mult[quality_tier]`

`quality_tier` is read from each item's `EquipmentRecipeResource` (T1 starter → T4 endgame). Weights encode the item's slot role and theme (Lurker = crit/lifesteal, Brute = HP/armor, Sentinel = range/resists/CDR, Warlord = all-round, Troll = HP/lifesteal, Goblin = crit/luck/speed).

| Tier | Mult |
|------|------|
| T1 | 1.0 |
| T2 | 1.8 |
| T3 | 2.8 |
| T4 | 4.0 |

| Stat | Unit (T1, weight 1.0) | Hero baseline (PLACEHOLDER_BASE_STATS) | Why |
|------|------|------|------|
| max_hp | 25 | 500 | ~5% of base per unit; full T4 set ≈ +1.5–1.8× base |
| armor | 5 | 0 | Formula 5: `100/(armor+100)`; ~120 armor on a full T4 loadout ≈ 45% reduction |
| physical_attack | 2.5 | 25 | T4 weapon ≈ +40–50% |
| magic_attack | 2.5 | 10 | only on neck slot; T4 ≈ +1.2× base |
| move_speed | 5 | 220 | T4 boots ≈ +10% |
| attack_range | 8 | 220 | T4 lance ≈ +48 |
| crit_chance | 0.02 | 0.10 raw | Formula 7 raw input (half-cap at 0.5); 4 T4 pieces ≈ +0.25 raw |
| crit_multiplier | 0.05 | 0.0 raw | Formula 7 raw input (half-cap at 1.0) |
| luck | 0.02 | 0.0 raw | Formula 7 raw input (half-cap at 0.5) |
| cdr | 0.01 | 0.0 | hard cap 0.75; a T4 stack stays ~10% |
| lifesteal | 0.005 | 0.0 | hard cap 0.40; T4 ring 0.020 |
| elemental_resist_* | 0.03 | 0.0 | hard cap 0.75 |

`tower_affinity` is deliberately never granted by equipment (its base is 1.0 with sqrt scaling; a flat bonus has unclear semantics).

## Tuning

Re-tune by editing the unit/weight tables and regenerating; `tests/unit/inventory/equipment_base_stats_content_test.gd` enforces that every stat key is a real Hero stat (typo guard) and that no single item exceeds a loose per-stat ceiling. Open question for playtest: HP and armor stack across 6+ slots — verify a full T4 set is strong but not unkillable once monsters deal real damage to the Hero.

## Values

| Item | Slot | Tier | base_stats |
|------|------|------|-----------|
| traveler_boots | boots | T1 | `{"move_speed": 6.0}` |
| reinforced_boots | boots | T2 | `{"move_speed": 9.0, "armor": 5.0}` |
| warlords_greaves | boots | T3 | `{"move_speed": 14.0, "armor": 11.0, "max_hp": 35.0}` |
| sentinels_striders | boots | T4 | `{"move_speed": 24.0, "cdr": 0.032}` |
| trollhide_striders | boots | T4 | `{"move_speed": 20.0, "max_hp": 100.0, "lifesteal": 0.010}` |
| leather_jerkin | chest | T1 | `{"max_hp": 38.0, "armor": 3.0}` |
| reinforced_plate | chest | T2 | `{"max_hp": 68.0, "armor": 11.0}` |
| troll_hide_mantle | chest | T3 | `{"max_hp": 140.0, "armor": 8.0, "lifesteal": 0.008}` |
| brutes_bulwark_plate | chest | T4 | `{"max_hp": 180.0, "armor": 32.0}` |
| warlords_battleplate | chest | T4 | `{"max_hp": 160.0, "armor": 24.0, "physical_attack": 5.0}` |
| leather_gloves | gloves | T1 | `{"physical_attack": 1.2, "crit_chance": 0.010}` |
| reinforced_gauntlets | gloves | T2 | `{"physical_attack": 2.7, "armor": 5.0}` |
| brute_gauntlets | gloves | T3 | `{"physical_attack": 5.6, "armor": 8.0}` |
| lurker_claw_gauntlets | gloves | T3 | `{"physical_attack": 3.5, "crit_chance": 0.045}` |
| goblin_claw_gauntlets | gloves | T4 | `{"physical_attack": 6.0, "crit_chance": 0.064, "lifesteal": 0.008}` |
| iron_helm | helmet | T1 | `{"max_hp": 25.0, "armor": 3.0}` |
| reinforced_helm | helmet | T2 | `{"max_hp": 45.0, "armor": 7.0}` |
| sentinel_visor | helmet | T3 | `{"max_hp": 56.0, "attack_range": 22.0, "crit_chance": 0.028}` |
| brutes_war_helm | helmet | T4 | `{"max_hp": 120.0, "armor": 20.0}` |
| goblin_fang_circlet | helmet | T4 | `{"max_hp": 80.0, "crit_chance": 0.064, "luck": 0.064}` |
| lucky_charm_trinket | neck | T1 | `{"luck": 0.030}` |
| silver_pendant | neck | T2 | `{"magic_attack": 4.5, "cdr": 0.011}` |
| ichor_charm | neck | T3 | `{"magic_attack": 7.0, "lifesteal": 0.011}` |
| bogpearl_amulet | neck | T4 | `{"magic_attack": 12.0, "elemental_resist_frost": 0.120, "luck": 0.048}` |
| warlords_standard_amulet | neck | T4 | `{"physical_attack": 8.0, "max_hp": 100.0, "cdr": 0.024}` |
| wooden_buckler | offhand | T1 | `{"armor": 6.0}` |
| iron_buckler | offhand | T2 | `{"armor": 11.0, "max_hp": 23.0}` |
| sentinel_ward | offhand | T3 | `{"armor": 14.0, "elemental_resist_fire": 0.067, "elemental_resist_frost": 0.067}` |
| trollhide_buckler | offhand | T3 | `{"armor": 14.0, "max_hp": 70.0}` |
| sentinels_aegis | offhand | T4 | `{"armor": 28.0, "elemental_resist_fire": 0.096, "elemental_resist_frost": 0.096}` |
| leather_leggings | pants | T1 | `{"max_hp": 25.0, "move_speed": 2.0}` |
| iron_greaves | pants | T2 | `{"max_hp": 45.0, "armor": 7.0}` |
| brute_legguards | pants | T3 | `{"max_hp": 84.0, "armor": 14.0}` |
| goblin_raider_leggings | pants | T3 | `{"max_hp": 56.0, "move_speed": 11.0, "crit_chance": 0.022}` |
| warlords_legguards | pants | T4 | `{"max_hp": 120.0, "armor": 20.0, "elemental_resist_fire": 0.060, "elemental_resist_frost": 0.060}` |
| warding_band | ring | T1 | `{"armor": 5.0, "elemental_resist_fire": 0.018}` |
| iron_band | ring | T2 | `{"physical_attack": 2.7, "crit_chance": 0.022}` |
| goblin_signet | ring | T3 | `{"luck": 0.056, "crit_chance": 0.045}` |
| brute_core_band | ring | T4 | `{"physical_attack": 8.0, "max_hp": 80.0}` |
| trollmarrow_band | ring | T4 | `{"lifesteal": 0.020, "max_hp": 80.0}` |
| iron_sword | weapon | T1 | `{"physical_attack": 2.5}` |
| steel_greatsword | weapon | T2 | `{"physical_attack": 5.4, "crit_multiplier": 0.090}` |
| lurker_fang_blade | weapon | T3 | `{"physical_attack": 7.0, "crit_chance": 0.056, "lifesteal": 0.008}` |
| sentinels_lance | weapon | T4 | `{"physical_attack": 10.0, "attack_range": 48.0}` |
| warlords_greatblade | weapon | T4 | `{"physical_attack": 13.0, "crit_multiplier": 0.240}` |
