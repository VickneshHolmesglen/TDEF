class_name HeroSkillEffectResource
extends Resource

## Formalized `effect_data` schema for SkillDefinitionResource, per
## design/gdd/hero-skill-build.md Rule 2 (amended 2026-09-01, PoE-scale
## content pass — "No longer deferred"). Distinct from SkillResource's own
## skill_power_coefficient (src/core/hero/skill_resource.gd) — that field is
## the one already fixed and consumed by Damage & Status's live combat
## pipeline (Formula D7); this Resource's own copy of the same-named field
## is catalogue/identity metadata (SkillDefinitionResource's consumers —
## Hero Skill Build's category-profile derivation, Hero Skill Tree's
## Choice-node candidate resolution — never read it for combat math).
##
## Named `HeroSkillEffectResource` (not the GDD's bare "SkillEffectResource")
## to avoid a project-wide naming collision risk with any future non-hero
## skill/ability system — matches this project's existing disambiguation
## precedent (e.g. `TowerMissionState` vs. a bare `MissionState`).

## physical | fire | ice | poison | lightning | arcane, or "" for non-damage
## support/buff skills ("" is distinct from "physical" — see VALID_DAMAGE_TYPES).
## Renamed 2026-09-04 (player decision): "frost" -> "ice", the canonical name
## for this project's damage-classification taxonomy (see VALID_TAGS below) —
## same underlying type, only the name changed; no gameplay change.
## Open, growing list, not a fixed enum closed for all time (player's own
## framing: "we can add more tags/classification as necessary later") — adding
## a new value here is expected as real content needs it, same as any other
## VALID_* const in this codebase.
@export var damage_type: String = ""

## melee_arc | projectile_pierce | projectile_spread | beam | aoe_zone |
## self_buff | totem | channel
@export var delivery: String = ""

## Per-skill scalar, [0.5, 3.0]. Catalogue/identity copy — see class doc
## comment for why this duplicates SkillResource's own field of the same name.
@export var skill_power_coefficient: float = 1.0

## slow | knockback | armor_shred | dot_burn | dot_poison | chain | fork |
## stun | lifesteal_bonus | none
@export var secondary_effect: String = "none"

## Two independent tag families share this one array (both consumed by
## hero-skill-build.md Rule 13's typed passive-slot skill-modifier
## compatibility check, `requires_tag`):
##   (a) delivery-shape tags (pre-existing): Area/Projectile/Duration/
##       Channeling/Totem/Melee/Ranged/Buff.
##   (b) damage-classification tags (added 2026-09-04, player-directed
##       reclassification pass — see this const's own doc comment below).
## A skill's `tags` array is the union of whichever of both families apply —
## e.g. a fire melee skill carries both `Melee` and `Fire`/`Basic`/
## `Elemental`/`DifferentDamage`.
@export var tags: Array[String] = []

const VALID_DAMAGE_TYPES: Array[String] = ["", "physical", "fire", "ice", "poison", "lightning", "arcane"]
const VALID_DELIVERIES: Array[String] = [
	"melee_arc", "projectile_pierce", "projectile_spread", "beam", "aoe_zone", "self_buff", "totem", "channel",
]
const VALID_SECONDARY_EFFECTS: Array[String] = [
	"slow", "knockback", "armor_shred", "dot_burn", "dot_poison", "chain", "fork", "stun", "lifesteal_bonus", "none",
]
## Damage-classification tags (2026-09-04, player-directed reclassification
## pass — `docs/tech-debt-register.md` TD-hero-skill-003 has the full history).
## Authored directly onto each damage-dealing skill's own `tags` array (not a
## separate central lookup table — same authoring convention as the
## pre-existing delivery-shape tags), per damage_type:
##   fire/water/earth/wind/poison ("Basic Elemental") -> own name + Basic + Elemental + DifferentDamage
##   ice/lightning/light/dark/solar/steam/spark ("Advanced Elemental") -> Advanced + Elemental + DifferentDamage (no own-name tag)
##   arcane ("Magic")                            -> Basic + Magic + DifferentDamage (no own-name tag)
##   physical, "" (no damage_type)                -> no classification tags at all
##   bleed/haemorrhage (future, not-yet-authored physical-lineage DoT family) ->
##     Physical + DoT (player decision, 2026-09-08: "Bleed gets 'physical'" plus
##     a dedicated DoT tag, not Physical alone) — no `damage_type` value exists
##     for either yet, so no skill carries this combination today; the DoT tag
##     is added to VALID_TAGS in advance of that content, not speculatively used.
## poison classified 2026-09-08 (player decision): Basic Elemental, same
## treatment as fire — see `elem_poison_nova.tres`.
## Player's own framing: "we can add more tags/classification as necessary
## later" — this list grows as real content needs new values, same pattern
## as VALID_DAMAGE_TYPES above.
##
## ItemDefinitionResource.VALID_REQUIRES_TAGS (src/core/inventory/
## item_definition_resource.gd) intentionally duplicates only the pre-
## existing delivery-shape half of VALID_TAGS, not this new classification
## half — no skill-modifier currently needs to gate on a damage
## classification, so extending that duplicate now would be speculative.
## Flagged here so the two lists' "mirrors X" doc comments don't silently
## drift further out of sync without a reader knowing why.
const VALID_TAGS: Array[String] = [
	"Area", "Projectile", "Duration", "Channeling", "Totem", "Melee", "Ranged", "Buff",
	"Fire", "Water", "Earth", "Wind", "Poison", "Basic", "Advanced", "Elemental", "Magic", "DifferentDamage", "Physical", "DoT",
]


func validate() -> Array[String]:
	var errors: Array[String] = []
	if not VALID_DAMAGE_TYPES.has(damage_type):
		errors.append("damage_type must be one of %s (got '%s')" % [VALID_DAMAGE_TYPES, damage_type])
	if not VALID_DELIVERIES.has(delivery):
		errors.append("delivery must be one of %s (got '%s')" % [VALID_DELIVERIES, delivery])
	if skill_power_coefficient < 0.5 or skill_power_coefficient > 3.0:
		errors.append("skill_power_coefficient must be in [0.5, 3.0] (got %.2f)" % skill_power_coefficient)
	if not VALID_SECONDARY_EFFECTS.has(secondary_effect):
		errors.append("secondary_effect must be one of %s (got '%s')" % [VALID_SECONDARY_EFFECTS, secondary_effect])
	for tag: String in tags:
		if not VALID_TAGS.has(tag):
			errors.append("tags entry '%s' is not one of %s" % [tag, VALID_TAGS])
	return errors
