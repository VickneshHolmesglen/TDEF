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

## damage/fire/frost/poison/lightning/arcane — reuses tower.md's
## WeaponComponent.element vocabulary and monster.md's
## monster_elemental_resistances verbatim, not a new taxonomy. "" for
## non-damage support/buff skills (physical is represented as "physical",
## distinct from "" which means "this skill deals no elemental-resistance-
## checked damage at all").
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

## Any of Area/Projectile/Duration/Channeling/Totem/Melee/Ranged/Buff — the
## axis hero-skill-build.md Rule 13's typed passive slots check
## skill-modifier item compatibility against (`requires_tag`).
@export var tags: Array[String] = []

const VALID_DAMAGE_TYPES: Array[String] = ["", "physical", "fire", "frost", "poison", "lightning", "arcane"]
const VALID_DELIVERIES: Array[String] = [
	"melee_arc", "projectile_pierce", "projectile_spread", "beam", "aoe_zone", "self_buff", "totem", "channel",
]
const VALID_SECONDARY_EFFECTS: Array[String] = [
	"slow", "knockback", "armor_shred", "dot_burn", "dot_poison", "chain", "fork", "stun", "lifesteal_bonus", "none",
]
const VALID_TAGS: Array[String] = [
	"Area", "Projectile", "Duration", "Channeling", "Totem", "Melee", "Ranged", "Buff",
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
