class_name DropTableResource
extends Resource

## Data definition for a named drop table — a set of DropEntry line-items resolved
## by drop_table_id when a monster with a matching MonsterResource.drop_table_id
## dies (ADR-0017, Epic 03 Story 010).
##
## GDD source: design/gdd/resource-economy.md — Core Rule 4 (schema).
## ADR-0009: Resource data model — one class_name per file, exported fields only.
## ADR-0017: DropTableResource/DropEntry are Resource subclasses loaded via
## GameDataRegistry at boot (Autoload #5), looked up by GameDataRegistry.get_drop_table().
##
## A table with zero entries is valid, structural data (a legitimate "this monster
## drops nothing" authoring choice, GDD Edge Cases) — validate() never rejects an
## empty entries array on that basis alone.

@export var drop_table_id: StringName = &""
@export var entries: Array[DropEntry] = []
@export var guaranteed_min_quantity: int = 1
## Per-table Formula 1 (drop occurrence roll) input — added 2026-07-16 during
## Story 008 (ADR-0017 amendment: the original schema omitted this field). GDD
## source: design/gdd/resource-economy.md Tuning Knobs — "base_drop_rate (per
## table)", default 0.45, safe range 0.3-0.6.
@export var base_drop_rate: float = 0.45


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009). Returns []
## when valid; one string per invalid field otherwise. Mirrors monster_resource.gd's
## validate() idiom, and recurses into each DropEntry's own validate().
func validate() -> Array[String]:
	var errors: Array[String] = []
	if drop_table_id == &"":
		errors.append("drop_table_id must not be empty")
	if guaranteed_min_quantity < 0:
		errors.append("guaranteed_min_quantity must be >= 0 (got %d)" % guaranteed_min_quantity)
	if base_drop_rate < 0.3 or base_drop_rate > 0.6:
		errors.append("base_drop_rate must be within [0.3, 0.6] (got %.2f)" % base_drop_rate)
	for i: int in range(entries.size()):
		var entry: DropEntry = entries[i]
		if entry == null:
			errors.append("entries[%d] must not be null" % i)
			continue
		for err: String in entry.validate():
			errors.append("entries[%d]: %s" % [i, err])
	return errors
