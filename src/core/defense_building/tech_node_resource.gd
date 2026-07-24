class_name TechNodeResource
extends Resource

## Data definition for a single Defense Building tech tree node.
##
## GDD source: design/gdd/defense-building.md — Core Rule 2/3 (Tech Node Model,
## Tech Tree Content).
## ADR-0009: Resource data model — one class_name per file, exported fields only.
## ADR-0024: Defense Building tech tree data model — this Resource is loaded and
## cached by GameDataRegistry (Autoload #5), never constructed ad hoc elsewhere.
##
## tech_category is one of "production_tech" / "structural_tech" (Rule 3).
## prerequisite_tech_id == "" marks a root node (branch_tier 1). gates is
## content-authoring documentation only — NEVER read at runtime (ADR-0024
## Decision; actual gating is enforced entirely on the *consumer* side, e.g.
## Crafting checking a recipe's own tech prerequisite against tech_unlocked
## history, not by Defense Building pushing gate logic outward).

@export var tech_id: StringName = &""
@export var tech_category: String = ""              # "production_tech" | "structural_tech"
@export var prerequisite_tech_id: StringName = &""   # "" = root node
@export var branch_tier: int = 1                     # 1-3
@export var gold_cost: int = 0
@export var material_costs: Dictionary[StringName, int] = {}
@export var gates: String = ""                       # content-authoring documentation only, NEVER read at runtime

const VALID_CATEGORIES: Array[String] = ["production_tech", "structural_tech"]


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009).
## Returns [] when valid; one string per invalid field otherwise. Note:
## VALID_CATEGORIES also constrains the editor UI via the @export type hint
## only if an enum were used — tech_category is a free String field, so this
## check is the only runtime guarantee of the two valid literal values.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if tech_id == &"":
		errors.append("tech_id must not be empty")
	if not VALID_CATEGORIES.has(tech_category):
		errors.append("tech_category must be one of %s (got '%s')" % [VALID_CATEGORIES, tech_category])
	if branch_tier < 1 or branch_tier > 3:
		errors.append("branch_tier must be 1-3 (got %d)" % branch_tier)
	return errors
