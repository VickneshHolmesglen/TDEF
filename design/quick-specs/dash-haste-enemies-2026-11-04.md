# Quick spec: Rift Hound (dash) and Goblin Drummer (haste)

Date: 2026-11-04. Extends the 2026-11-02 archetype pass (flying, healing, splitting, stealth).

## Why
The new maps changed what threatens the player. The Shardplain's roads are short and straight, so a burst of speed matters more there than raw HP. On the two-entrance maps, a support enemy at the merge point speeds up both columns.

## Rules
- **Dash** (`MonsterResource.dash_*`): every `dash_interval_seconds` the monster moves at `dash_speed_multiplier` for `dash_duration_seconds`. Slows multiply on top of the burst. A stun cancels it, and the dash clock only runs while the monster is not dashing or stunned. Validation keeps the multiplier in [1, 5].
- **Haste** (`MonsterResource.haste_*`): every `haste_interval_seconds` the drummer hastes every OTHER live monster within `haste_radius_cells` (Chebyshev) for `haste_duration_seconds`. A new pulse refreshes the timer and keeps the larger multiplier; hastes never stack. Validation keeps the multiplier in [1, 3]. A stun pauses the pulse timer, as it does for healers.
- Dash and haste multiply together; a hasted hound mid-dash runs about 3.5× its base speed.
- Hasted monsters show a pink double-chevron status pip (`haste`, bit 64, the 7th entry in `MonsterInstance.STATUS_ORDER`).

## Content
| Monster | HP | Speed | Behaviour | Art |
|---|---|---|---|---|
| Rift Hound | 65 | 1.4 | dash 2.6× for 0.8 s every 3.5 s | spore_skitterling recolour, crimson |
| Goblin Drummer | 95 (armour 5) | 1.0 | haste 1.35× within 2 cells, 3.5 s, every 3 s | goblin_runner recolour, amber |

Waves: Twinpass (drummers waves 4 and 7, hounds wave 8), Coilmarsh (drummers waves 6 and 9), Shardplain (hounds waves 2, 5 and 8, plus a drummer in 8), Rift Gate (hounds waves 3 and 9, drummers waves 6 and 10). The progression sim was re-run and pacing is unchanged (level 50 at about mission 70 in the 70-mission plan).

Art is a placeholder recolour (`tools/asset-pipeline/hd2d/make_archetype_monsters.py rift_hound goblin_drummer`) until bespoke sprites exist.

Tests: `tests/unit/monster/dash_haste_test.gd`.
