class_name ActiveSlowEffect
extends RefCounted

## One in-flight slow instance on a MonsterEntity. design/gdd/damage-status.md
## Formula D6 (amended 2026-08-13 — slow moves into scope alongside burn/poison,
## see Rule I.3). Unlike ActiveStatusEffect (burn/poison), this has no ticks —
## it is a continuous speed multiplier that decays by wall-clock duration and
## is read fresh every frame by Monster System's movement pass, never applied
## by mutating MonsterEntity.scaled_speed (which stays immutable after spawn
## per ADR-0006's own Key Interfaces contract).
##
## Multiple instances stack multiplicatively (a design decision, not an
## oversight — see the GDD): two 15% slows combine to 0.85 x 0.85 = 72.25% of
## original speed, not a summed 30% reduction. This structurally guarantees
## effective speed can never reach zero or go negative regardless of how many
## instances are active, with no separate clamp needed at the combination site.

var remaining_duration: float = 0.0
## 1.0 - effect_value, clamped to [SPEED_MULTIPLIER_FLOOR, 1.0] — see
## MonsterManager.SPEED_MULTIPLIER_FLOOR's own doc comment for the floor's purpose.
var speed_multiplier: float = 1.0
