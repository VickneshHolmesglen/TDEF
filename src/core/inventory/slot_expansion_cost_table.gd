class_name SlotExpansionCostTable
extends RefCounted

## Static, data-driven slot-expansion capacity/cost table (Epic 03, Story 003).
##
## GDD source: design/gdd/inventory.md, Formulas section (2026-07-10 correction).
## Story: production/epics/epic-03-core-economy/story-003-slot-expansion-cost-table.md
## (AC-8, AC-9, AC-10, AC-16)
##
## Deliberately NOT a Resource subclass, unlike ItemDefinitionResource/MonsterResource
## (ADR-0016's established convention). That convention exists for designer-authored
## CONTENT — many .tres instances loaded and validated by GameDataRegistry at boot.
## This table is the opposite case: exactly 5 fixed, code-owned rows that will never
## be authored as separate .tres assets or registered with GameDataRegistry. Wrapping
## it in Resource would add serialization/inspector machinery for zero benefit. A
## plain RefCounted holding one named const table satisfies the control manifest's
## "gameplay values must be data-driven, never inline literals in a function body"
## rule just as well — the table is the single named source of truth, queried
## through one pure function, never re-typed at call sites.
##
## Hand-tuned, NOT formula-derived (GDD Formulas section, 2026-07-10 correction): an
## earlier draft's `round(10 x 1.35^(tier-1))` was found wrong (produces 10/14/18/25/33,
## not the table below) and removed. Do not attempt to "clean up" this table into a
## closed-form expression — the GDD is explicit that none reproduces these values.
##
## Player-requested 2026-08-16 (twice, same day): every slots_after value shifted
## +4 (16/22/28/34/40 -> 20/26/32/38/44) when Inventory.STARTING_SLOT_COUNT first
## rose from 10 to 14 (Hero equipment slots expanded 5 -> 10), then shifted +4
## again (20/26/32/38/44 -> 24/30/36/42/48) when STARTING_SLOT_COUNT rose again
## from 14 to 18 (a live playthrough found only 4 discretionary slots wasn't
## enough — see that constant's own doc comment for the full history). Both are
## re-basings, not re-derivations: the same +6-per-tier cadence and the exact same
## material costs (common/uncommon/rare columns, untouched below) are preserved:
## only the resulting total-capacity numbers move to keep pace with the larger
## starting point.
##
## Tier indexing: 1-5, where tier N is the expansion that grows capacity FROM the
## tier-(N-1) capacity TO the tier-N capacity (tier 1: 18->24, ..., tier 5: 42->48,
## max). Tier 0 (the un-expanded starting state, 18 slots) is intentionally NOT a row
## in this table — it is Inventory.STARTING_SLOT_COUNT's concern, not a "cost to
## reach," since no expansion is required to have it.

const MIN_TIER: int = 1
const MAX_TIER: int = 5

## Rarity-quantity keys used in table rows. Inventory.attempt_expand_slots()
## maps these to ItemDefinitionResource.rarity's capitalized vocabulary
## ("Common"/"Uncommon"/"Rare") via its own _RARITY_KEY_TO_NAME table.
const KEY_SLOTS_AFTER: StringName = &"slots_after"
const KEY_COMMON: StringName = &"common"
const KEY_UNCOMMON: StringName = &"uncommon"
const KEY_RARE: StringName = &"rare"

## Row shape: {slots_after: int, common: int, uncommon: int, rare: int}. A rarity not
## yet required at a given tier (GDD's "—" cells) is explicitly 0, not absent — every
## valid row always has all 4 keys, so callers never need an `has()` check to read a
## not-yet-gated rarity's cost (it's simply 0, correctly meaning "nothing required").
const _TABLE: Dictionary[int, Dictionary] = {
	1: {KEY_SLOTS_AFTER: 24, KEY_COMMON: 10, KEY_UNCOMMON: 0, KEY_RARE: 0},
	2: {KEY_SLOTS_AFTER: 30, KEY_COMMON: 18, KEY_UNCOMMON: 4, KEY_RARE: 0},
	3: {KEY_SLOTS_AFTER: 36, KEY_COMMON: 28, KEY_UNCOMMON: 10, KEY_RARE: 0},
	4: {KEY_SLOTS_AFTER: 42, KEY_COMMON: 36, KEY_UNCOMMON: 18, KEY_RARE: 5},
	5: {KEY_SLOTS_AFTER: 48, KEY_COMMON: 45, KEY_UNCOMMON: 28, KEY_RARE: 12},
}


## Returns the cost/capacity row for `tier` (1-5), or {} for any out-of-range tier
## (AC-9 edge case: 0 or 6+ must fail EXPLICITLY, not resolve to a default/zero-cost
## row — {} is unambiguous here because every valid row always has all 4 keys
## populated, so a caller can distinguish "out of range" from "a valid row where a
## rarity's cost happens to be 0" by checking is_empty(), never by checking any
## individual value against 0).
##
## Usage:
##   var cost := SlotExpansionCostTable.get_cost_for_tier(4)
##   # cost == {"slots_after": 42, "common": 36, "uncommon": 18, "rare": 5}
##   var invalid := SlotExpansionCostTable.get_cost_for_tier(6)
##   # invalid == {} (push_error logged)
static func get_cost_for_tier(tier: int) -> Dictionary:
	if tier < MIN_TIER or tier > MAX_TIER:
		push_error("[SlotExpansionCostTable] get_cost_for_tier: tier %d out of range [%d, %d]." % [tier, MIN_TIER, MAX_TIER])
		return {}
	return _TABLE[tier].duplicate()
