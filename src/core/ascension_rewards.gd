class_name AscensionRewards
extends RefCounted
## What Ascension ranks pay beyond DifficultyRewards' multipliers
## (design/quick-specs/ascension-rewards-2026-11-03.md).
##
## Ascension raised enemy HP faster than rewards, so pushing past the rank you
## farm paid nothing. Ascendant Shards fix that: a one-time bounty for the
## first clear of each rank on each map, plus a small reward per Ascension
## victory. Shards are spent on extra rune slots (EquipmentForge) and the
## tier-5 Ascendant gear set. The rank milestones also unlock Tarot cards
## (TarotCardResource.unlock_ascension_rank) and draw a medallion rim on
## Mission Select.

## The shard material. Rarity "" on purpose: rarity-keyed costs ("32 Rare")
## can never consume it, only recipes that name it.
const SHARD_ITEM_ID: StringName = &"ascendant_shard"
## materials_earned source tag.
const SHARD_SOURCE: String = "ascension_reward"

const FIRST_CLEAR_SHARDS_PER_RANK: int = 10
const RUN_SHARDS_PER_RANK: int = 2

## Extra rune slots one item can buy above its slot's base count, and the
## shard cost of the 1st and 2nd.
const MAX_EXTRA_RUNE_SLOTS: int = 2
const EXTRA_RUNE_SLOT_COST: Array[int] = [40, 120]

## Best Ascension rank on a map that earns a bronze / silver / gold rim.
const RIM_RANKS: Array[int] = [5, 10, 15]


## Shards for one victory at `tier`. 0 below Ascension.
## Example: shards_for_victory(5, true) == 24 (Ascension 2: 20 bounty + 4 run);
## shards_for_victory(5, false) == 4; shards_for_victory(3, true) == 0.
static func shards_for_victory(tier: int, first_clear: bool) -> int:
	var rank: int = DifficultyRewards.ascension_rank(tier)
	if rank <= 0:
		return 0
	var shards: int = RUN_SHARDS_PER_RANK * rank
	if first_clear:
		shards += FIRST_CLEAR_SHARDS_PER_RANK * rank
	return shards


## Shard cost of the next extra rune slot when `extra_slots_owned` are
## already bought; -1 at the cap.
## Example: extra_rune_slot_cost(0) == 40, extra_rune_slot_cost(2) == -1.
static func extra_rune_slot_cost(extra_slots_owned: int) -> int:
	if extra_slots_owned < 0 or extra_slots_owned >= MAX_EXTRA_RUNE_SLOTS:
		return -1
	return EXTRA_RUNE_SLOT_COST[extra_slots_owned]


## 0 = no rim, 1 bronze, 2 silver, 3 gold, from a map's best Ascension rank.
## Example: rim_level(4) == 0, rim_level(10) == 2, rim_level(15) == 3.
static func rim_level(best_rank: int) -> int:
	var level: int = 0
	for threshold: int in RIM_RANKS:
		if best_rank >= threshold:
			level += 1
	return level
