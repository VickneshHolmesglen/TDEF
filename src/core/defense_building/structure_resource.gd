class_name StructureResource
extends Resource

## Data definition for a single Sanctuary Structure entry.
##
## GDD source: design/gdd/defense-building.md — Core Rule 4/5/6 (Sanctuary
## Structure Model, Habitat Expansion Content, Watchtower).
## ADR-0009: Resource data model — one class_name per file, exported fields only.
## ADR-0024: Defense Building tech tree data model — this Resource is loaded and
## cached by GameDataRegistry (Autoload #5), never constructed ad hoc elsewhere.
##
## structure_type groups tiers of the same structure family (e.g.
## "habitat_expansion") — matches the sanctuary_structure_built event's
## structure_type field. prerequisite_structure_id == "" marks Tier 1 / an
## untiered structure (Rule 6's sequential-tier enforcement is driven by this
## field at the consumer/resolution layer, not here). tech_gate == "" marks
## an ungated structure.

@export var structure_id: StringName = &""
@export var structure_type: String = ""
@export var tier: int = 1                                # 1-N within structure_type; 1 for untiered
@export var prerequisite_structure_id: StringName = &""  # "" = Tier 1 / untiered
@export var tech_gate: StringName = &""                  # "" = ungated
@export var gold_cost: int = 0
@export var material_costs: Dictionary[StringName, int] = {}


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009).
## Returns [] when valid; one string per invalid field otherwise.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if structure_id == &"":
		errors.append("structure_id must not be empty")
	if structure_type == "":
		errors.append("structure_type must not be empty")
	if tier < 1:
		errors.append("tier must be >= 1 (got %d)" % tier)
	return errors
