# Quick spec: Riftrunner set

Date: 2026-11-04. The tenth equipment set and the first crafted from the 2026-11-04 enemies (`dash-haste-enemies-2026-11-04.md`).

## Identity
A fast, cooldown-and-crit set for a hero who runs the lanes on the two-entrance maps. Its effects reward moving and killing, not standing behind towers.

## Chain
| Enemy | Drop table | Material | Rarity |
|---|---|---|---|
| Rift Hound | `hound_drops` (rate 0.55): rift_fang ×2, goblin_hide ×1 | Rift Fang | Rare |
| Goblin Drummer | `drummer_drops` (rate 0.6, the registry maximum): drum_hide ×4, goblin_fang ×1 | Drum Hide | Uncommon |

Both enemies appear only on maps 9–12, so the set is tied to the late campaign.

## Pieces (quality tier 4, `tech_production_4`)
| Piece | Slot | Stats | Recipe | Runes |
|---|---|---|---|---|
| Riftrunner Hood | helmet | 60 HP, 10 move, 3% crit | 34 rift_fang, 22 drum_hide, 18 Uncommon | 2 |
| Riftrunner Coat | chest | 110 HP, 6 armour, 10 move | 48 rift_fang, 30 drum_hide, 24 Uncommon | 2 |
| Riftrunner Striders | boots | 25 move, 70 HP | 40 rift_fang, 20 drum_hide, 18 Uncommon | 2 |
| Drumskin Talisman | neck | 4% CDR, 4 phys attack | 44 drum_hide, 24 rift_fang, 8 Rare | 1 |

## Set bonuses and effects
- 2 pieces: +15 move speed. Effect **Drumbeat** (`on_wave_start_buff`): +25% move speed for 8 s at each wave start.
- 4 pieces: +5% CDR, +4% crit. Capstone **Pack Hunt** (`on_kill_stack_buff`): +3% move speed and +3% physical attack per kill, up to 8 stacks, 5 s.

Uses only existing effect types; no code change. Follows the one-capstone-plus-one-lower-tier rule.

## Pacing
Progression sim: all four pieces bought by about mission 33 (`production/balance/progression-baseline.md`). Pacing to hero level 50 is unchanged.

## Art
Placeholder recolours (rift crimson-violet; the talisman in drum-hide amber) of Goblin Fang Circlet, Leather Jerkin, Trollhide Striders and Ichor Charm, plus worn overlays for the three visible pieces. Materials are recolours of Goblin Fang and Goblin Hide. Generator: a one-off authoring script, not kept; to remake the art, run `tools/asset-pipeline/hd2d/recolor_variant.py` per piece.

Tests: `tests/unit/equipment/riftrunner_content_test.gd`, `equipment_set_content_test.gd`, base-stat and worn-overlay counts.
