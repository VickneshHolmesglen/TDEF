class_name SacrificeRecipeResource
extends Resource

## Data definition for a single Equipment Forge Creature Sacrifice recipe.
##
## GDD source: design/gdd/equipment-forge.md — Rule 18 (Sacrifice Recipe Schema).
## ADR-0009: Resource data model — one class_name per file, exported fields only.
## ADR-0025: sibling to EquipmentRecipeResource (same relationship
## EquipmentRecipeResource itself has to RecipeResource) — consumes a
## creature_id instead of `inputs`. One recipe per species (5 total at Alpha,
## matching Menagerie's fixed 5-species roster).
##
## quality_tier is deliberately NOT an authored field here (Rule 18: "Derived,
## not authored") — computed at resolve time from the target creature's
## species_tier via Formula 2 (EquipmentForge.resolve_sacrifice()), never
## stored on the recipe itself.

@export var sacrifice_recipe_id: StringName = &""
@export var required_species: StringName = &""
@export var output_slot: String = ""  ## weapon|offhand|helmet|chest|gloves|pants|boots|neck|ring
@export var output_base_item_id: StringName = &""  ## item's base definition, before its pre-imbued rune
@export var rune_id: StringName = &""  ## fixed per species — e.g. "menagerie_aurora_stag"
@export var stat_delta: Dictionary[StringName, float] = {}  ## authored per species (Formula 3 guideline)

## Expanded 2026-08-16 (player-requested) from the old 4-category weapon/
## armor/accessory/trinket vocabulary — mirrors EquipmentRecipeResource's
## own identical VALID_OUTPUT_SLOTS expansion.
const VALID_OUTPUT_SLOTS: Array[String] = [
	"weapon", "offhand", "helmet", "chest", "gloves", "pants", "boots", "neck", "ring",
]


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009 contract).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if sacrifice_recipe_id == &"":
		errors.append("sacrifice_recipe_id must not be empty")
	if required_species == &"":
		errors.append("required_species must not be empty")
	if not VALID_OUTPUT_SLOTS.has(output_slot):
		errors.append("output_slot must be one of weapon/offhand/helmet/chest/gloves/pants/boots/neck/ring (got '%s')" % output_slot)
	if output_base_item_id == &"":
		errors.append("output_base_item_id must not be empty")
	if rune_id == &"":
		errors.append("rune_id must not be empty")
	return errors
