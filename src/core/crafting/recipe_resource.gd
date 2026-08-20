class_name RecipeResource
extends Resource

## Data definition for a single Crafting recipe.
##
## GDD source: design/gdd/crafting.md — Rule 1 (Recipe Schema).
## ADR-0009: Resource data model — one class_name per file, exported fields only.
## ADR-0023: Crafting recipe data model — this Resource is loaded and cached
## by GameDataRegistry (Autoload #5), never constructed ad hoc elsewhere.
##
## Repair (Rule 2/6) is explicitly NOT modeled as a RecipeResource — it has no
## recipe_id, never fires recipe_discovered, and its own state (an item's
## damaged flag) lives on InventorySlot (ADR-0021). Do not create a
## RecipeResource instance for repair.

@export var recipe_id: StringName = &""
@export var recipe_category: String = ""              # "tower_component" | "crafted_good"
@export var component_slot: String = ""               # foundation|weapon|focus|power; "" unless tower_component
@export var inputs: Dictionary[StringName, int] = {}   # item_type -> quantity, 1-3 entries (TD-craft-001: ADR-0023's own comment calls this "material_id", but Inventory.has_items() actually sums by item_type — this field is keyed to match has_items()'s real, already-shipped contract)
@export var tech_prerequisite: StringName = &""        # "" = ungated
@export var output_item_id: StringName = &""
@export var output_quantity: int = 1
@export var quality_tier: int = 0                      # 0 = N/A (crafted_good); 1-4 for tower_component
## Blueprint-sourced component recipes (2026-08-17): when non-empty, this
## recipe's output_item_id is a standalone copy of one of a specific
## pre-authored basic tower's embedded components (e.g. &"archer" for a
## "Craft Archer Foundation" recipe whose output must match
## blueprint_archer.tres's embedded Foundation_archer values exactly). Empty
## for every other recipe (both existing generic tower_component recipes and
## all crafted_good recipes). Purely descriptive/validating metadata — NOT
## consulted by Crafting.resolve_craft() at craft time (the actual stat
## match is enforced by construction: the recipe author points
## output_item_id at a component .tres whose values were copied from the
## named tower's blueprint, and a dedicated regression test asserts the two
## stay in sync).
@export var source_blueprint_tower_id: StringName = &""

const VALID_CATEGORIES: Array[String] = ["tower_component", "crafted_good"]
const VALID_COMPONENT_SLOTS: Array[String] = ["foundation", "weapon", "focus", "power"]

## TD-craft-001 / TD-defbuild-002 (same open design question, unresolved):
## crafting.md's Formulas 1-3 are explicitly rarity-based (Common/Uncommon/
## Rare), but Inventory.has_items() sums by item_type, and no rarity field
## exists on ItemDefinitionResource. inputs may therefore be keyed by EITHER
## vocabulary — a valid item_type (has_items()-compatible, genuinely
## craftable today) OR a rarity string (content-accurate to Formula 1-3,
## but NOT yet has_items()-compatible — such a recipe is uncraftable in
## practice until the rarity/item_type reconciliation lands). Both are
## accepted here so Story 006's formula-derived content validates correctly
## as DATA, without this Resource silently pretending the gap is closed.
const VALID_RARITIES: Array[StringName] = [&"Common", &"Uncommon", &"Rare"]

## Load-time validation. Called by GameDataRegistry at boot (ADR-0009).
## Returns [] when valid; one string per invalid field otherwise. Cross-
## references GameDataRegistry.get_item_definition() for every inputs/
## output_item_id material reference (AC-3) — GameDataRegistry must have
## already loaded item definitions by the time recipes are validated, since
## _load_item_definitions() runs before _load_recipes() in _ready().
func validate() -> Array[String]:
	var errors: Array[String] = []
	if recipe_id == &"":
		errors.append("recipe_id must not be empty")
	if not VALID_CATEGORIES.has(recipe_category):
		errors.append("recipe_category must be one of %s (got '%s')" % [VALID_CATEGORIES, recipe_category])
	if recipe_category == "tower_component" and not VALID_COMPONENT_SLOTS.has(component_slot):
		errors.append("component_slot must be one of %s when recipe_category is tower_component (got '%s')" % [VALID_COMPONENT_SLOTS, component_slot])
	if recipe_category == "crafted_good" and component_slot != "":
		errors.append("component_slot must be empty when recipe_category is crafted_good (got '%s')" % component_slot)
	if inputs.size() < 1 or inputs.size() > 3:
		errors.append("inputs must have 1-3 entries (got %d)" % inputs.size())
	# TD-craft-001: inputs keys are a valid item_type (has_items()-compatible),
	# a Formula 1-3 rarity string, OR (2026-08-17, blueprint-sourced recipes)
	# a specific item_id (has_items_by_material_id()-compatible) — the third
	# axis needed when a recipe must gate on one exact material (e.g.
	# foundation_surplus) rather than any item sharing its type or rarity.
	for key: StringName in inputs:
		if not (ItemDefinitionResource.VALID_ITEM_TYPES.has(key) or VALID_RARITIES.has(key) or GGameDataRegistry.get_item_definition(key) != null):
			errors.append("inputs key '%s' is not a valid item_type, rarity, or known item_id" % key)
	if output_item_id == &"":
		errors.append("output_item_id must not be empty")
	elif GGameDataRegistry.get_item_definition(output_item_id) == null:
		errors.append("output_item_id references unknown item_id '%s'" % output_item_id)
	if recipe_category == "tower_component":
		if output_quantity != 1:
			errors.append("output_quantity must be exactly 1 for tower_component (got %d)" % output_quantity)
		if quality_tier < 1 or quality_tier > 4:
			errors.append("quality_tier must be 1-4 for tower_component (got %d)" % quality_tier)
	elif recipe_category == "crafted_good":
		if output_quantity < 1 or output_quantity > 5:
			errors.append("output_quantity must be 1-5 for crafted_good (got %d)" % output_quantity)
		if quality_tier != 0:
			errors.append("quality_tier must be 0 for crafted_good (got %d)" % quality_tier)
	if source_blueprint_tower_id != &"":
		if recipe_category != "tower_component":
			errors.append("source_blueprint_tower_id must be empty unless recipe_category is tower_component (got '%s')" % recipe_category)
		if not GGameDataRegistry.get_all_tower_blueprints().has(source_blueprint_tower_id):
			errors.append("source_blueprint_tower_id references unknown tower_id '%s'" % source_blueprint_tower_id)
	return errors
