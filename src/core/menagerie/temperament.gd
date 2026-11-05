class_name Temperament
extends RefCounted

## Creature temperaments (design/quick-specs/menagerie-rehoming-2026-11-05.md):
## one trait from the species tier's pool plus a 1-5 star grade, rolled when a
## creature is lured, bred or rehomed. HABITAT creatures' temperaments add
## small, capped, economy-only bonuses (Menagerie.trait_bonus()).
##
## Usage:
##   var t: Dictionary = Temperament.roll(species_tier, rng)   # {&"trait": ..., &"grade": ...}
##   var pct: float = Temperament.value(t[&"grade"])

const FORAGER_COMMON: StringName = &"forager_common"
const FORAGER_UNCOMMON: StringName = &"forager_uncommon"
const FORAGER_RARE: StringName = &"forager_rare"
## + hero XP from every source.
const SCHOLAR: StringName = &"scholar"
## + Sanctuary gold banked at mission end.
const HOARDER: StringName = &"hoarder"
## + Ascendant Shards per Ascension win.
const SHARDBOUND: StringName = &"shardbound"

## Pools by species tier (1 Common, 2 Uncommon, 3 Rare), equal weight.
const POOLS: Dictionary[int, Array] = {
	1: [FORAGER_COMMON, SCHOLAR],
	2: [FORAGER_UNCOMMON, SCHOLAR, HOARDER],
	3: [FORAGER_RARE, HOARDER, SHARDBOUND],
}
## Forager trait for a material rarity ("Common"/"Uncommon"/"Rare").
const FORAGER_BY_RARITY: Dictionary[String, StringName] = {
	"Common": FORAGER_COMMON, "Uncommon": FORAGER_UNCOMMON, "Rare": FORAGER_RARE,
}

## Roll weights for 1-5 stars.
const GRADE_WEIGHTS: Array[int] = [40, 30, 18, 9, 3]
## Bonus per creature by grade (1-5 stars).
const GRADE_VALUES: Array[float] = [0.01, 0.02, 0.03, 0.05, 0.08]
## Cap on one trait's summed bonus.
const TRAIT_CAP: float = 0.25
## Grades at or above this end a pity streak.
const HIGH_GRADE: int = 4


## Rolls {&"trait", &"grade"} for a species tier. `min_grade` forces the grade
## roll into [min_grade, 5] (pity); `max_grade` caps it (legacy creatures).
static func roll(species_tier: int, rng: RandomNumberGenerator, min_grade: int = 1, max_grade: int = 5) -> Dictionary:
	var pool: Array = POOLS.get(clampi(species_tier, 1, 3), POOLS[1])
	var trait_id: StringName = pool[rng.randi_range(0, pool.size() - 1)]
	return {&"trait": trait_id, &"grade": roll_grade(rng, min_grade, max_grade)}


## Weighted 1-5 star roll restricted to [min_grade, max_grade].
static func roll_grade(rng: RandomNumberGenerator, min_grade: int = 1, max_grade: int = 5) -> int:
	var lo: int = clampi(min_grade, 1, 5)
	var hi: int = clampi(max_grade, lo, 5)
	var total: int = 0
	for g: int in range(lo, hi + 1):
		total += GRADE_WEIGHTS[g - 1]
	var pick: int = rng.randi_range(1, total)
	for g: int in range(lo, hi + 1):
		pick -= GRADE_WEIGHTS[g - 1]
		if pick <= 0:
			return g
	return hi


static func value(grade: int) -> float:
	return GRADE_VALUES[clampi(grade, 1, 5) - 1]


static func is_valid_trait(trait_id: StringName) -> bool:
	for pool: Array in POOLS.values():
		if pool.has(trait_id):
			return true
	return false
