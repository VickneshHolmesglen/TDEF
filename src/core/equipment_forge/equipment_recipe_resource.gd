class_name EquipmentRecipeResource
extends Resource

## Data definition for a single Equipment Forge crafting recipe.
##
## GDD source: design/gdd/equipment-forge.md — Rule 4 (Recipe Schema).
## ADR-0009: Resource data model — one class_name per file, exported fields only.
## ADR-0025: NOT a subclass of RecipeResource (src/core/crafting/recipe_resource.gd)
## — a separate sibling Resource mirroring its field shape and validation
## convention (same relationship RecipeResource itself has to
## ItemDefinitionResource). Two fields beyond RecipeResource's own set:
## output_slot and rune_slot_count.

@export var recipe_id: StringName = &""
@export var recipe_category: String = "hero_equipment"  ## fixed literal — never anything else
## weapon|offhand|helmet|chest|gloves|pants|boots|neck|ring (expanded
## 2026-08-16, player-requested, from the old 4-category weapon/armor/
## accessory/trinket vocabulary when Hero equipment slots grew 5 -> 10) — a
## DISTINCT vocabulary from Tower's foundation/weapon/focus/power
## component_slot names (Forbidden rule: the shared string "weapon" is a
## content-authoring caution, never a mechanical conflict; these two
## vocabularies are never compared against each other).
@export var output_slot: String = ""
@export var inputs: Dictionary[StringName, int] = {}  ## item_type -> quantity
@export var tech_prerequisite: StringName = &""  ## "" = ungated
@export var output_item_id: StringName = &""
@export var quality_tier: int = 1  ## 1-4, fixed author-set — never rolled or computed at craft time
## Derived at data-authoring time from the fixed output_slot -> rune_slot_count
## table (Rule 11, expanded 2026-08-16: weapon=2, offhand=1, helmet/chest/
## gloves/pants/boots=2, neck=1, ring=1) — never authored freely; validate()
## confirms it matches the table for whatever output_slot is set.
@export var rune_slot_count: int = 1

const VALID_OUTPUT_SLOTS: Array[String] = [
	"weapon", "offhand", "helmet", "chest", "gloves", "pants", "boots", "neck", "ring",
]
## Rule 11's fixed output_slot -> rune_slot_count table (Guardrail — never
## authored per-recipe). Armor-tier slots (helmet/chest/gloves/pants/boots)
## keep the old "armor" category's rune count of 2; neck/ring keep the old
## accessory/trinket categories' rune count of 1; offhand is new and set to
## 1 (lighter than the 2-rune main-hand weapon, matching the old accessory/
## trinket tier rather than the weapon tier).
const RUNE_SLOT_COUNT_FOR_SLOT: Dictionary[String, int] = {
	"weapon": 2, "offhand": 1,
	"helmet": 2, "chest": 2, "gloves": 2, "pants": 2, "boots": 2,
	"neck": 1, "ring": 1,
}


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009 contract).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if recipe_id == &"":
		errors.append("recipe_id must not be empty")
	if recipe_category != "hero_equipment":
		errors.append("recipe_category must be the fixed literal 'hero_equipment' (got '%s')" % recipe_category)
	if not VALID_OUTPUT_SLOTS.has(output_slot):
		errors.append("output_slot must be one of weapon/offhand/helmet/chest/gloves/pants/boots/neck/ring (got '%s')" % output_slot)
	if inputs.is_empty():
		errors.append("inputs must not be empty")
	if output_item_id == &"":
		errors.append("output_item_id must not be empty")
	if quality_tier < 1 or quality_tier > 4:
		errors.append("quality_tier must be in [1,4] (got %d)" % quality_tier)
	if VALID_OUTPUT_SLOTS.has(output_slot):
		var expected: int = RUNE_SLOT_COUNT_FOR_SLOT[output_slot]
		if rune_slot_count != expected:
			errors.append("rune_slot_count must be %d for output_slot '%s' (got %d)" % [expected, output_slot, rune_slot_count])
	return errors
