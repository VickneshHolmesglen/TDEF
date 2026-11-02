class_name DifficultyRewards
extends RefCounted
## Reward multiplier per difficulty tier (1 Normal, 2 Hard, 3 Brutal, 4+ Ascension).
##
## Decided 2026-10-15 (production/balance/progression-targets.md): harder runs
## must pay noticeably more than Normal so they are the fastest route through
## the campaign. Applied to hero XP (Hero.set_reward_multiplier) and material
## drops + mission-end surplus (ResourceEconomy.set_tier_reward_multiplier).
## In-mission gold is not scaled: it resets every mission and is balanced
## against tower costs, not progression.
##
## Ascension (2026-11-03, endgame): tiers above Brutal. Clearing a map's
## highest tier opens the next one on that map (MissionSelect), up to
## MAX_ASCENSION ranks. Each rank multiplies monster HP by ASCENSION_HP_GROWTH
## and rewards by ASCENSION_REWARD_GROWTH on top of Brutal, so late-game hero
## power keeps meeting resistance (tower-defense pitfall: enemy HP must keep
## pace with player power). Rewards grow slower than HP on purpose: each rank
## is a real step up, and the best farm is the highest rank you can clear
## reliably, not the highest one at all.

const TIER_MULTIPLIERS: Array[float] = [1.0, 1.3, 1.7]
const BRUTAL_TIER: int = 3
const MAX_ASCENSION: int = 15
const MAX_TIER: int = BRUTAL_TIER + MAX_ASCENSION
const ASCENSION_HP_GROWTH: float = 1.15
const ASCENSION_REWARD_GROWTH: float = 1.12


## Returns the reward multiplier for `tier`, clamped into [1, MAX_TIER].
## Example: multiplier_for_tier(2) == 1.3; multiplier_for_tier(5) == 1.7 * 1.12^2.
static func multiplier_for_tier(tier: int) -> float:
	var t: int = clampi(tier, 1, MAX_TIER)
	var base: float = TIER_MULTIPLIERS[mini(t, BRUTAL_TIER) - 1]
	return base * pow(ASCENSION_REWARD_GROWTH, ascension_rank(t))


## Extra monster HP factor from Ascension alone (1.0 for Normal/Hard/Brutal);
## MonsterManager applies it on top of its own per-tier growth.
## Example: ascension_hp_multiplier(4) == 1.15.
static func ascension_hp_multiplier(tier: int) -> float:
	return pow(ASCENSION_HP_GROWTH, ascension_rank(clampi(tier, 1, MAX_TIER)))


## 0 for tiers 1-3, then 1, 2, ... for Ascension ranks.
static func ascension_rank(tier: int) -> int:
	return maxi(0, tier - BRUTAL_TIER)
