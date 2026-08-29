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
## separate subdirectory from res://assets/data/skills/'s existing
## SkillResource content (cooldown-only, a different concept, TD-hero-002) to
## avoid a directory-scan collision between the two skill_id-keyed Resource
## subclasses (same pattern as Story 008's MissionEntry/MissionResource split).

## Unique skill identifier.
@export var skill_id: StringName = &""
## Player-facing name. Real gap found 2026-07-20 (Epic 06 Story 013): this
## field didn't exist, so Mission HUD's skill_unlocked toast showed the raw
## skill_id (e.g. "Skill Learned: phys_cleave") instead of a real name.
@export var display_name: String = ""
## Must match tower.md's Foundation archetype enum exactly: physical|ranged|elemental|support.
@export var category: String = ""
## Number of passive sub-slots this skill provides. Valid range: 1-3.
@export var passive_slot_count: int = 1
## Tower Mastery's build_signature this skill unlocks via mastery, or empty
## if unreachable via mastery (AC-2's explicit allowance).
@export var source_build_signature: StringName = &""
## Seconds of proximity time required to unlock via Tower Mastery.
@export var mastery_threshold_seconds: float = 45.0
## Opaque; format owned by Hero Skill Build's future content pass. Tower
## Mastery never interprets this field's contents (tower-mastery.md Rule 7).
@export var effect_data: Resource = null
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
	return errors
