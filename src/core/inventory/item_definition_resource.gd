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
@export var item_type: StringName = &""  ## Equipment | TowerComponent | Material | CraftedGood | skill_modifier
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
## Epic 08, Story 008 (ADR-0025); expanded 2026-08-16 (player-requested)
## from 4 to 9 categories when Hero equipment slots grew from 5 to 10 named
## slots. Sub-classifies which of Hero's 10 named equipment slots this item
## may occupy. Only meaningful when item_type == &"Equipment"; empty string
## for every other item_type. "ring" is the shared category for both
## ring_1 and ring_2 — no subtype restriction (mirrors the old
## accessory_a/accessory_b precedent this replaces). Every other category
## maps 1:1 to its own named slot.
@export var equipment_category: String = ""  ## "" | weapon | offhand | helmet | chest | gloves | pants | boots | neck | ring
## 2026-10-04 smoke check: true = this item is never counted toward, or
## consumed by, an item_type-keyed cost (has_items()/consume_by_type()). Set on
## menagerie_lure, which shares item_type "Material" but is reserved for the
## Menagerie Lure action (menagerie.md Rule 2: consumed ONLY by that action) --
## without it any "Material: N" recipe silently ate the player's lures.
@export var excluded_from_type_costs: bool = false
## 2026-08-06 (design/quick-specs/inventory-slot-icons-2026-08-06.md): a
## real, data-driven home for slot art. Null = no icon authored yet (the
## slot falls back to its pre-existing text rendering, "mechanism real,
## content placeholder") -- never hardcoded as a UI-side item_id->texture
## lookup table, matching this project's own data-driven-values rule.
@export var icon: Texture2D = null
## Tower Assembly (2026-08-11, player-requested, design/quick-specs/
## tower-assembly-2026-08-11.md): path to a standalone `.tres` whose root
## resource is a real FoundationComponent/WeaponComponent/FocusComponent/
## PowerComponent — the bridge between a crafted TowerComponent item sitting
## inert in Inventory and the real component schema TowerSystem's
## placement/combat code actually reads. Only meaningful when
## item_type == &"TowerComponent"; empty string for every other item_type
## (crafted components had no gameplay effect at all before this — see the
## quick-spec's own Motivation section).
@export var component_resource_path: String = ""
## hero-skill-build.md Rule 13 (revised 2026-09-01 — typed passive slots):
## the single tag this skill-modifier item requires a socketed skill's own
## `effect_data.tags` to contain, or `"any"` to accept every skill
## regardless of tags. Checked by HeroSkillBuild.set_passive_slot() at
## equip time — see that function's own doc comment. Only meaningful when
## item_type == &"skill_modifier"; empty string for every other item_type,
## mirroring component_resource_path's mutual-exclusivity convention above.
## Duplicates HeroSkillEffectResource.VALID_TAGS' 8 values rather than
## referencing that class directly — Inventory is a lower architectural
## layer than Hero Skill Build (Advanced tier) and should not depend
## upward on it; matches this project's own established small-lookup-table
## duplication precedent (e.g. ARCHETYPE_GLYPHS across 3 UI files).
##
## TD-hero-skill-002 (docs/tech-debt-register.md, resolved 2026-09-02):
## Rule 14's own 13-item catalogue has 4 items that gate on `damage_type`
## or `secondary_effect` instead of a tag (e.g. "any non-physical
## damage_type", "damage_type = fire") — `requires_tag` alone can't
## represent that without misrepresenting the design. `requires_damage_type`/
## `requires_secondary_effect` below are the two sibling gating axes this
## added to close that gap. Exactly one of the three gating fields
## (`requires_tag`, `requires_damage_type`, `requires_secondary_effect`)
## must be populated per skill-modifier item — never zero, never more than
## one — matching Rule 14's own table, where each item has exactly one
## stated condition.
@export var requires_tag: String = ""
## See `requires_tag`'s own doc comment for the 3-way mutual-exclusivity
## contract. Array of `HeroSkillEffectResource.VALID_DAMAGE_TYPES` values —
## the item is compatible if the socketed skill's `effect_data.damage_type`
## is IN this array (multi-value, e.g. `sup_mod_arcane_surge`'s
## `["lightning","ice","fire","arcane"]`). Empty = this axis unused.
@export var requires_damage_type: Array[String] = []
## See `requires_tag`'s own doc comment for the 3-way mutual-exclusivity
## contract. Array of `HeroSkillEffectResource.VALID_SECONDARY_EFFECTS`
## values — the item is compatible if the socketed skill's
## `effect_data.secondary_effect` is IN this array. Empty = this axis unused.
@export var requires_secondary_effect: Array[String] = []

const VALID_ITEM_TYPES: Array[StringName] = [&"Equipment", &"TowerComponent", &"Material", &"CraftedGood", &"skill_modifier"]
const VALID_RARITIES: Array[String] = ["", "Common", "Uncommon", "Rare"]
const VALID_EQUIPMENT_CATEGORIES: Array[String] = [
	"", "weapon", "offhand", "helmet", "chest", "gloves", "pants", "boots", "neck", "ring",
]
## Mirrors HeroSkillEffectResource.VALID_TAGS (src/core/hero_skill_effect_resource.gd)
## plus the wildcard "any" (hero-skill-build.md Rule 13).
const VALID_REQUIRES_TAGS: Array[String] = [
	"any", "Area", "Projectile", "Duration", "Channeling", "Totem", "Melee", "Ranged", "Buff",
]
## Mirrors HeroSkillEffectResource.VALID_DAMAGE_TYPES (excluding "" — an
## empty damage_type means "deals no elemental-resistance-checked damage,"
## not a value a skill-modifier would ever gate equipping on).
const VALID_REQUIRES_DAMAGE_TYPES: Array[String] = ["physical", "fire", "ice", "poison", "lightning", "arcane"]
## Mirrors HeroSkillEffectResource.VALID_SECONDARY_EFFECTS (excluding
## "none" for the same reason "" is excluded from damage types above).
const VALID_REQUIRES_SECONDARY_EFFECTS: Array[String] = [
	"slow", "knockback", "armor_shred", "dot_burn", "dot_poison", "dot_bleed", "dot_haemorrhage",
	"chain", "fork", "stun", "lifesteal_bonus",
]


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
		errors.append("item_type must be one of Equipment/TowerComponent/Material/CraftedGood/skill_modifier (got '%s')" % item_type)
	if not VALID_RARITIES.has(rarity):
		errors.append("rarity must be one of \"\"/Common/Uncommon/Rare (got '%s')" % rarity)
	if not VALID_EQUIPMENT_CATEGORIES.has(equipment_category):
		errors.append("equipment_category must be one of \"\"/weapon/offhand/helmet/chest/gloves/pants/boots/neck/ring (got '%s')" % equipment_category)
	if item_type == &"Equipment" and equipment_category == "":
		errors.append("equipment_category must not be empty when item_type is Equipment")
	if item_type == &"TowerComponent" and component_resource_path == "":
		errors.append("component_resource_path must not be empty when item_type is TowerComponent (Tower Assembly cannot resolve this item to a real component)")
	if item_type != &"TowerComponent" and component_resource_path != "":
		errors.append("component_resource_path must be empty when item_type is not TowerComponent (got '%s')" % component_resource_path)
	if requires_tag != "" and not VALID_REQUIRES_TAGS.has(requires_tag):
		errors.append("requires_tag must be one of %s (got '%s')" % [VALID_REQUIRES_TAGS, requires_tag])
	for damage_type: String in requires_damage_type:
		if not VALID_REQUIRES_DAMAGE_TYPES.has(damage_type):
			errors.append("requires_damage_type entry '%s' is not one of %s" % [damage_type, VALID_REQUIRES_DAMAGE_TYPES])
	for secondary_effect: String in requires_secondary_effect:
		if not VALID_REQUIRES_SECONDARY_EFFECTS.has(secondary_effect):
			errors.append("requires_secondary_effect entry '%s' is not one of %s" % [secondary_effect, VALID_REQUIRES_SECONDARY_EFFECTS])
	var gating_axes_set: int = int(requires_tag != "") + int(not requires_damage_type.is_empty()) + int(not requires_secondary_effect.is_empty())
	if item_type == &"skill_modifier" and gating_axes_set != 1:
		errors.append("exactly one of requires_tag/requires_damage_type/requires_secondary_effect must be set when item_type is skill_modifier (found %d set)" % gating_axes_set)
	if item_type != &"skill_modifier" and gating_axes_set != 0:
		errors.append("requires_tag/requires_damage_type/requires_secondary_effect must all be empty when item_type is not skill_modifier")
	return errors
