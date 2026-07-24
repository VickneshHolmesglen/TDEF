class_name ItemDefinitionResource
extends Resource

## Static, data-driven definition for a single inventory item (Epic 03, ADR-0016).
##
## GDD source: design/gdd/inventory.md
## ADR: docs/architecture/adr-0016-inventory-storage-model.md — "Two-tier data model"
## Story: production/epics/epic-03-core-economy/story-001-slot-stack-model.md
##
## One `.tres` file per distinct item definition, intended to live under
## assets/data/items/ and be loaded by GameDataRegistry at boot (ADR-0009's
## existing convention) — that loader wiring is deliberately NOT added by
## Story 001 (see that story's Context section); this Resource class exists
## so later stories/tests can construct definitions directly.
##
## is_unique_instance drives stack-cap behavior in Inventory: true = cap 1,
## stat-rolled (Equipment / stat-rolled Tower Components — base_stats is the
## template a roll is generated from); false = cap 99, stackable (Material /
## CraftedGood — base_stats is unused).

@export var item_id: StringName = &""
@export var item_type: StringName = &""  ## Equipment | TowerComponent | Material | CraftedGood
@export var display_name: String = ""
@export var is_unique_instance: bool = false  ## true = cap 1, stat-rolled; false = cap 99, stackable
@export var base_stats: Dictionary[StringName, float] = {}  ## only meaningful when is_unique_instance == true
## TD-craft-001/TD-defbuild-002 resolution (Sprint 6, S6-06b): rarity tier for
## Material-tab items, independent of item_type. Recipe/tech/structure cost
## tables (RecipeResource.inputs when rarity-keyed, TechNodeResource/
## StructureResource.material_costs) are authored per Formula 1/3 as
## "N of rarity tier X", not "N of a specific item_type" — item_type has no
## rarity vocabulary of its own. Empty string = not rarity-gated (Equipment/
## TowerComponent/CraftedGood, or any Material not currently used in a
## rarity-keyed cost table). Queried via Inventory.has_items_by_rarity()/
## consume_by_rarity(), a separate aggregation axis from item_type's
## has_items()/consume_by_type().
@export var rarity: String = ""  ## "" | Common | Uncommon | Rare — Material-tab items only
## Epic 08, Story 008 (ADR-0025): sub-classifies which of Hero's 5 named
## equipment slots this item may occupy. Only meaningful when
## item_type == &"Equipment"; empty string for every other item_type.
## "accessory" is the shared category for both accessory_a and accessory_b —
## no subtype restriction at Alpha (Story 008's own Implementation Notes).
@export var equipment_category: String = ""  ## "" | weapon | armor | accessory | trinket

const VALID_ITEM_TYPES: Array[StringName] = [&"Equipment", &"TowerComponent", &"Material", &"CraftedGood"]
const VALID_RARITIES: Array[String] = ["", "Common", "Uncommon", "Rare"]
const VALID_EQUIPMENT_CATEGORIES: Array[String] = ["", "weapon", "armor", "accessory", "trinket"]


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009 contract) —
## modeled exactly on MonsterResource.validate() (src/core/monster/monster_resource.gd):
## pushes nothing itself, returns [] when valid, one string per invalid field otherwise.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if item_id == &"":
		errors.append("item_id must not be empty")
	if display_name == "":
		errors.append("display_name must not be empty")
	if not VALID_ITEM_TYPES.has(item_type):
		errors.append("item_type must be one of Equipment/TowerComponent/Material/CraftedGood (got '%s')" % item_type)
	if not VALID_RARITIES.has(rarity):
		errors.append("rarity must be one of \"\"/Common/Uncommon/Rare (got '%s')" % rarity)
	if not VALID_EQUIPMENT_CATEGORIES.has(equipment_category):
		errors.append("equipment_category must be one of \"\"/weapon/armor/accessory/trinket (got '%s')" % equipment_category)
	if item_type == &"Equipment" and equipment_category == "":
		errors.append("equipment_category must not be empty when item_type is Equipment")
	return errors
