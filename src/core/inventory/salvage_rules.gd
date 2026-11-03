class_name SalvageRules
extends RefCounted
## Salvage (design/quick-specs/inventory-salvage-2026-11-03.md): refines a
## stack of surplus materials one rarity up, so a clogged bag turns into
## something the rarity-keyed costs ("N Uncommon", "N Rare") can spend.
## The outputs are generic: no named recipe uses them.
##
## Usage:
##   var out: StringName = SalvageRules.output_for("Common")  # &"refined_alloy"
##   var n: int = SalvageRules.outputs_for(45)                 # 2 (40 consumed)

## Input items per output item.
const RATIO: int = 20

## Input rarity -> output item. Rare (and rarity "", e.g. lures and
## Ascendant Shards) has no entry: not salvageable.
const OUTPUT_BY_RARITY: Dictionary[String, StringName] = {
	"Common": &"refined_alloy",
	"Uncommon": &"refined_essence",
}


## Output item for an input `rarity`, or &"" when it can't be salvaged.
static func output_for(rarity: String) -> StringName:
	return OUTPUT_BY_RARITY.get(rarity, &"")


## Whole output items `quantity` inputs make (the remainder stays put).
static func outputs_for(quantity: int) -> int:
	return maxi(0, quantity) / RATIO
