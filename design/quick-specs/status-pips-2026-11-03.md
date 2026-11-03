# Quick Spec: Monster status pips and hero status cue

Date: 2026-11-03. Status: implemented, live-checked (pips).
Closes "hero skill side-effects aren't shown on screen or heard".

## Rules

1. Every 2D monster shows one pip per active status along its sprite's
   top-left edge, in this order: burn, poison, bleed, slow, stun, armour shred.
   Source doesn't matter (hero skill or tower).
2. Each pip has its own shape AND colour, on a dark backing, so it reads
   without colour vision: burn = orange flame triangle, poison = green drop,
   bleed = red diamond, slow = blue down-chevron, stun = yellow star,
   armour shred = purple cross. Haemorrhage shows as bleed (same status).
3. MonsterManager's visual-sync pass computes a status bitmask per monster
   (`status_bits_for`, allocation-free) and only rebuilds the pip list when
   the mask changes (`MonsterEntity.status_bits`).
4. A hero skill hit whose secondary effect leaves a status (slow, knockback,
   armor_shred, dot_burn, dot_poison, dot_bleed, dot_haemorrhage, stun) plays
   `hero_status_<effect>` if authored, else `hero_status_applied`; at most one
   per 150 ms (`AudioCueDispatcher.HERO_STATUS_MIN_GAP_MSEC`) so an area cast
   is one sound. chain / fork / lifesteal_bonus are silent here.

## Content (placeholders)

| Cue | Sound |
|---|---|
| hero_status_dot_burn | tower_attacked_burn.wav |
| hero_status_dot_poison | tower_attacked_poison.wav |
| hero_status_slow | tower_attacked_slow.wav |
| hero_status_applied (all others) | tower_attacked_v2.wav |

## Not covered

- The batched 3D swarm path still has only its placeholder "any status"
  magenta tint (`creature_swarm_body.gdshader`); pips are 2D-only.
- Knockback is instant, so it has a sound but no pip.

## Acceptance criteria

`tests/unit/monster/status_pips_test.gd` (3),
`tests/unit/audio/audio_cue_dispatcher_hero_status_test.gd` (5).
