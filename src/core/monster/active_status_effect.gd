class_name ActiveStatusEffect
extends RefCounted

## One in-flight burn/poison DoT instance on a MonsterEntity.
## design/gdd/damage-status.md Rule I.3 (amended 2026-08-13): burn and poison
## are now in scope, resolved by Monster System's own status-tick pass (ADR-0006
## 5th pass) rather than D&S — see that Rule's own exception note for why.
##
## Multiple instances of the SAME effect_type may coexist on one monster
## (stacking, not refreshing — a design decision, not an oversight): each hit
## that applies burn/poison creates its own independent instance with its own
## duration and tick timer, so two towers hitting the same target both
## contribute damage rather than the weaker hit being discarded.

## "burn" or "poison" — matches WeaponComponent/PowerComponent.element and
## PowerComponent.effect_type respectively (both String, kept consistent here).
var effect_type: String = ""
var ticks_remaining: int = 0
var tick_interval_remaining: float = 0.0
var tick_damage: float = 0.0

## Bleed only (bleed/haemorrhage spec 2026-10-06): bleed does NOT stack as
## parallel instances like burn/poison. A monster carries at most one bleed
## instance whose `stacks` (1..MonsterManager.BLEED_MAX_STACKS) multiply
## `per_stack_tick` into tick_damage; every new application adds stacks and
## refreshes the duration.
var stacks: int = 1
var per_stack_tick: float = 0.0

## Who gets the kill if a tick finishes the monster (&"tower" or &"hero").
var source: StringName = &"tower"
