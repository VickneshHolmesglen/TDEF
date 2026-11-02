class_name DifficultyRewards
extends RefCounted
## Reward multiplier per difficulty tier (1 Normal, 2 Hard, 3 Brutal).
##
## Decided 2026-10-15 (production/balance/progression-targets.md): harder runs
## must pay noticeably more than Normal so they are the fastest route through
## the campaign. Applied to hero XP (Hero.set_reward_multiplier) and material
## drops + mission-end surplus (ResourceEconomy.set_tier_reward_multiplier).
## In-mission gold is not scaled: it resets every mission and is balanced
## against tower costs, not progression.

const TIER_MULTIPLIERS: Array[float] = [1.0, 1.3, 1.7]


## Returns the multiplier for `tier`, clamped into [1, 3].
static func multiplier_for_tier(tier: int) -> float:
	return TIER_MULTIPLIERS[clampi(tier, 1, TIER_MULTIPLIERS.size()) - 1]
