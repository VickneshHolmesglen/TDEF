class_name SkillResource
extends Resource

## Data definition for a single Hero active skill. TD-hero-002 (closes the
## missing SkillDatabase/SkillResource pipeline flagged in Story 007).
## ADR-0009: Resource data model — one class_name per file, exported fields only.
##
## Originally minimal (Story 007's stated scope: cooldown data only, no skill
## effect resolution). **Amended 2026-08-26 (TD-hero-001, Skill Power
## implementation)**: gained skill_power_coefficient — Hero.activate_skill()
## now resolves a real damage hit through Damage & Status's Formula D7. The
## rest of a skill's effect shape (target pattern, buff data, non-damage
## fields) remains deferred content-authoring work per
## design/gdd/hero-skill-build.md's own Group 1 Rule 2 — this Resource still
## does not attempt to fill that broader gap, only the one field a downstream
## consumer already fixed the type/existence of.
##
## Loaded by GameDataRegistry from res://assets/data/skills/*.tres, keyed by
## skill_id — same pattern as MonsterResource/TowerData.

@export var skill_id: StringName = &""
@export var base_cooldown: float = 0.0

## TD-hero-001 (Skill Power half — GDScript implementation, 2026-08-26): a
## per-skill scalar applied against the hero's effective_skill_power_final
## before the shared tier/crit pipeline runs (design/gdd/damage-status.md
## Rule IX.1/Formula D7), mirroring Tower's tier_dps_multiplier role in
## Formula 1b. Named directly on SkillResource rather than inside a separate
## effect_data sub-resource — hero-skill-build.md's own Group 1 Rule 2 only
## defers effect_data's target-pattern/buff-data shape, not this one
## already-fixed-by-a-downstream-consumer field (that GDD's Group 1 row for
## effect_data, amended 2026-08-25, says exactly this). Typically 0.5-3.0
## per damage-status.md Formula D7's variable table.
@export var skill_power_coefficient: float = 1.0


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009).
## Returns [] when valid; one string per invalid field otherwise.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if skill_id == &"":
		errors.append("skill_id must not be empty")
	if base_cooldown <= 0.0:
		errors.append("base_cooldown must be > 0.0")
	if skill_power_coefficient <= 0.0:
		errors.append("skill_power_coefficient must be > 0.0")
	return errors
