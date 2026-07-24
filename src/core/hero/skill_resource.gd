class_name SkillResource
extends Resource

## Data definition for a single Hero active skill. TD-hero-002 (closes the
## missing SkillDatabase/SkillResource pipeline flagged in Story 007).
## ADR-0009: Resource data model — one class_name per file, exported fields only.
##
## Intentionally minimal, mirroring Story 007's own stated scope: cooldown data
## only. Skill effect resolution (damage, status application, etc.) remains
## unimplemented anywhere in this codebase — Story 007 explicitly deferred skill
## effect authoring and passive pools, and no system consumes hero_skill_activated
## yet (grep-confirmed at time of writing). This Resource does not attempt to
## fill that gap; it only gives skill cooldown data somewhere real to live,
## replacing hero.gd's hardcoded MVP-empty _skill_cooldowns Dictionary.
##
## Loaded by GameDataRegistry from res://assets/data/skills/*.tres, keyed by
## skill_id — same pattern as MonsterResource/TowerData.

@export var skill_id: StringName = &""
@export var base_cooldown: float = 0.0


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009).
## Returns [] when valid; one string per invalid field otherwise.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if skill_id == &"":
		errors.append("skill_id must not be empty")
	if base_cooldown <= 0.0:
		errors.append("base_cooldown must be > 0.0")
	return errors
