# Equipment Set Bonuses

**Authored**: 2026-09-20 (spec: `docs/superpowers/specs/2026-09-20-equipment-set-bonuses-design.md`; item stats: `equipment-base-stats.md`).
**Status**: first-pass numbers, unplaytested. Stat bonuses only (special effects are out of scope).

## Rules

- A set's piece count is the number of DISTINCT equipped `item_id`s in that set (two identical rings count once).
- Thresholds are cumulative: at 4 pieces both the 2-piece and 4-piece bonuses apply.
- An item belongs to at most one set (enforced by `tests/unit/equipment/equipment_set_content_test.gd`).
- Set bonuses fold into the same flat/additive buckets as gear and runes via `EquipmentBonuses.compute()`; `additive_bonus_total` is the all-stats wildcard (Warlord's 5-piece).
- Values are on the T1-unit scale of `equipment-base-stats.md` (max_hp 25, armor 5, physical_attack 2.5, magic_attack 2.5, move_speed 5, attack_range 8, crit_chance 0.02, luck 0.02, cdr 0.01, lifesteal 0.005, elemental_resist_* 0.03): a 2-piece bonus is about 3-4 units, higher thresholds about 6-10 units.

## Values

| set_id | Name | Members | Bonuses (pieces: delta) |
|---|---|---|---|
| set_iron | Iron | iron_sword, iron_helm, iron_greaves, iron_buckler, iron_band | 2: armor +8; 4: max_hp +50, physical_attack +3 |
| set_leather | Leather | leather_gloves, leather_jerkin, leather_leggings | 2: move_speed +8; 3: luck +0.03 |
| set_reinforced | Reinforced | reinforced_helm, reinforced_plate, reinforced_boots, reinforced_gauntlets | 2: max_hp +40; 4: armor +12, physical_attack +4 |
| set_goblin | Goblin | goblin_fang_circlet, goblin_claw_gauntlets, goblin_raider_leggings, goblin_signet | 2: luck +0.04; 4: crit_chance +0.06, move_speed +15 |
| set_brute | Brute | brutes_war_helm, brutes_bulwark_plate, brute_gauntlets, brute_legguards, brute_core_band | 2: max_hp +60; 4: armor +25; 5: max_hp +100 |
| set_sentinel | Sentinel | sentinel_visor, sentinel_ward, sentinels_aegis, sentinels_lance, sentinels_striders | 2: attack_range +16; 4: cdr +0.05, elemental_resist_fire +0.06, elemental_resist_frost +0.06 |
| set_troll | Troll | troll_hide_mantle, trollhide_buckler, trollhide_striders, trollmarrow_band | 2: max_hp +60; 4: lifesteal +0.02, max_hp +80 |
| set_warlord | Warlord | warlords_battleplate, warlords_greatblade, warlords_greaves, warlords_legguards, warlords_standard_amulet | 2: physical_attack +5; 4: max_hp +80, armor +15; 5: all stats +5% |
| set_lurker | Lurker | lurker_claw_gauntlets, lurker_fang_blade | 2: crit_chance +0.05, lifesteal +0.015 |

`sentinel_ward` and `sentinels_aegis` share the single offhand slot, so at most 4 Sentinel pieces can be worn at once; 4 is Sentinel's top threshold. `crit_chance` and `luck` are raw inputs to Hero's diminishing-returns curve (Formula 7).

## Open questions

- **Cross-set stacking:** several 2-piece bonuses from different sets stack freely; combined with gear and rune stats this may outpace committing to one set. Revisit with playtest data.
- ~~**Sentinel's dual offhands**~~ **Resolved 2026-09-25 (user decision): intentional.** `sentinel_ward` and `sentinels_aegis` are a deliberate flavour choice for the single offhand slot (ward vs. aegis), so Sentinel is a 5-member set with 4 wearable pieces and 4 as its top threshold. This is not an authoring slip and should not be "fixed" by re-slotting a piece or adding a 5-piece threshold.
