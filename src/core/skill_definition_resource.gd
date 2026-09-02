class_name SkillDefinitionResource
extends Resource

## Shared skill catalogue entry — one Resource, two consumers (Tower Mastery
## and Hero Skill Build), per ADR-0030's amendment of ADR-0029's original
## definition. Neither system owns a second, competing copy: Tower Mastery
## reads source_build_signature/mastery_threshold_seconds for its own unlock
## logic; Hero Skill Build reads category/passive_slot_count/effect_data for
## its own slot/Ultimate logic.
##
## GDD sources: design/gdd/hero-skill-build.md Rule 2, design/gdd/tower-mastery.md Rule 7
## Governing ADRs: docs/architecture/adr-0030-hero-skill-build-ultimate-lookup.md (authoritative field list)
##                  docs/architecture/adr-0029-tower-mastery-proximity-detection.md (amended in place)
##
## Loaded by GameDataRegistry from res://assets/data/skills/definitions/ — a
## separate subdirectory from res://assets/data/skills/'s legacy SkillResource
## content, to avoid a directory-scan collision between the two skill_id-keyed
## Resource subclasses (same pattern as Story 008's MissionEntry/MissionResource
## split).
##
## TD-hero-006 (docs/tech-debt-register.md, fixed 2026-09-02): SkillResource's
## catalogue (assets/data/skills/*.tres — fireball/earth_slam/frost_nova/
## chain_lightning, 4 skills) has zero skill_id overlap with this catalogue's
## real, player-equippable 32-skill roster (assets/data/skills/definitions/).
## Hero.gd originally read cooldown/skill_power_coefficient from SkillResource
## regardless, so every one of the 32 real skills dealt zero damage and used a
## wrong, always-floored 0.5s cooldown in shipped combat. Fixed by adding
## base_cooldown here (this catalogue is the correct, single source of truth
## for an equippable skill's full activation contract) and repointing Hero.gd
## at get_skill_definition()/effect_data instead of the legacy pipeline.
## SkillResource itself is left in place, now fully unreferenced by production
## code — a candidate for a future deletion pass, not removed here.

## Unique skill identifier.
@export var skill_id: StringName = &""
## Player-facing name. Real gap found 2026-07-20 (Epic 06 Story 013): this
## field didn't exist, so Mission HUD's skill_unlocked toast showed the raw
## skill_id (e.g. "Skill Learned: phys_cleave") instead of a real name.
@export var display_name: String = ""
## Must match tower.md's Foundation archetype enum exactly: physical|ranged|elemental|support.
@export var category: String = ""
## Added 2026-09-01 for Hero Skill Tree's Choice-node redesign
## (hero-skill-tree.md Rule 9/Formula 2) — which of an archetype's 8
## catalogued skills (hero-skill-build.md Rule 3) appear as candidates on
## Choice_1/Choice_2/Choice_3 respectively. Must be one of opener|core|capstone.
@export var tier: String = "opener"
## Number of passive sub-slots this skill provides. Valid range: 1-3.
@export var passive_slot_count: int = 1
## Tower Mastery's build_signature this skill unlocks via mastery, or empty
## if unreachable via mastery (AC-2's explicit allowance).
@export var source_build_signature: StringName = &""
## Seconds of proximity time required to unlock via Tower Mastery.
@export var mastery_threshold_seconds: float = 45.0
## TD-hero-006: this skill's active-slot cooldown, seconds — Hero.activate_skill()
## reads this via Rule 12's formula (effective_cooldown = base_cooldown x
## (1 - cdr), floored at 0.5s). Per-tier structural placeholder, not yet
## through a dedicated balance pass (same "real values, not yet tuned"
## precedent as skill_power_coefficient): opener 4.0s, core 6.0s, capstone
## 10.0s — lower-commitment openers stay spammable, capstones are the bigger
## cooldown payoff. Range matches the legacy SkillResource catalogue's own
## historical 3.0-8.0s spread.
@export var base_cooldown: float = 4.0
## Formalized 2026-09-01 (hero-skill-build.md Rule 2's PoE-scale content
## pass — "no longer deferred") — typed as HeroSkillEffectResource. Tower
## Mastery still never interprets this field's contents (tower-mastery.md
## Rule 7); it exists purely for Hero Skill Build/Hero Skill Tree's own
## category-profile/Choice-node consumption. Still nullable: a skill whose
## content-authoring pass hasn't landed yet (rare, should not ship) fails
## validate() below rather than crashing a consumer that assumes non-null.
@export var effect_data: HeroSkillEffectResource = null
## Skill-slot icon, matching ItemDefinitionResource.icon's established
## data-driven home for slot art (design/quick-specs/inventory-slot-icons-
## 2026-08-06.md). Null = no icon authored yet (missing-assets-audit-2026-
## 08-29.md #5 — zero of the 13 skills had one until this field existed).
## Mission HUD's skill-slot tiles don't render this yet (Story 007's own
## Open Question #4 doc comment) — wiring a real "which skill occupies which
## slot" readout into mission_hud.gd is separate, unscoped follow-up work,
## not implied by this field landing.
@export var icon: Texture2D = null


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009 pattern).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if skill_id == &"":
		errors.append("skill_id must not be empty")
	if display_name == "":
		errors.append("display_name must not be empty")
	const VALID_CATEGORIES: Array[String] = ["physical", "ranged", "elemental", "support"]
	if not VALID_CATEGORIES.has(category):
		errors.append("category must be one of %s (got '%s')" % [VALID_CATEGORIES, category])
	if passive_slot_count < 1 or passive_slot_count > 3:
		errors.append("passive_slot_count must be in [1,3] (got %d)" % passive_slot_count)
	const VALID_TIERS: Array[String] = ["opener", "core", "capstone"]
	if not VALID_TIERS.has(tier):
		errors.append("tier must be one of %s (got '%s')" % [VALID_TIERS, tier])
	if base_cooldown <= 0.0:
		errors.append("base_cooldown must be > 0.0 (got %.2f)" % base_cooldown)
	if effect_data == null:
		errors.append("effect_data must not be null (hero-skill-build.md Rule 2 — no longer deferred)")
	else:
		for effect_error: String in effect_data.validate():
			errors.append("effect_data: %s" % effect_error)
	return errors
