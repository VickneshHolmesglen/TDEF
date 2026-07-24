class_name DropEntry
extends Resource

## Single material line-item within a DropTableResource (ADR-0017, Epic 03 Story 010).
##
## GDD source: design/gdd/resource-economy.md — Core Rule 4 (schema).
## ADR-0009: Resource data model — one class_name per file, exported fields only.
##
## Deliberately narrow at this story: base_quantity/base_quality_probability are
## authored data only — the math that CONSUMES them (rolling actual awarded
## quantity, quality tier) is Story 008/009's scope, not this file's. This class
## only defines and validates the schema.

@export var material_id: StringName = &""
@export var base_quantity: int = 1
@export_range(0.0, 1.0, 0.01) var base_quality_probability: float = 0.10
@export var is_rare: bool = false


## Load-time validation. Called by DropTableResource.validate() (in turn called by
## GameDataRegistry at boot, ADR-0009). Returns [] when valid; one string per
## invalid field otherwise. Mirrors monster_resource.gd's validate() idiom.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if material_id == &"":
		errors.append("material_id must not be empty")
	if base_quantity <= 0:
		errors.append("base_quantity must be > 0 (got %d)" % base_quantity)
	if base_quality_probability < 0.0 or base_quality_probability > 1.0:
		errors.append("base_quality_probability must be within [0.0, 1.0] (got %.2f)" % base_quality_probability)
	return errors
