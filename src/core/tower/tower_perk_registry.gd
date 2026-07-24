class_name TowerPerkRegistry
extends Resource

## Maps perk_type (String, e.g. "DAMAGE_BOOST") to its display/validity data.
## Schema: design/gdd/tower.md Rule 12a.
## entries[perk_type] = { "label": String, "description": String,
##                         "archetype_restrictions": Array[String] }
##
## ADR-0009: Resource data model — loaded and validated once by GameDataRegistry
## at boot (res://assets/data/towers/perk_registry.tres). This class only stores
## display/validity data — perk-application effects belong to the Tower System.
##
## Usage:
##   var registry: TowerPerkRegistry = GGameDataRegistry.get_perk_registry()
##   var entry: Dictionary = registry.entries["DAMAGE_BOOST"]
##   print(entry["label"])
const VALID_PERK_TYPES: Array[String] = [
	"DAMAGE_BOOST", "RANGE_BOOST", "SPEED_BOOST", "AURA_EXTEND"
]

@export var entries: Dictionary = {}


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009).
## Returns [] when valid; one string per invalid/missing field otherwise.
## Guards against malformed entries (e.g. a non-Dictionary value authored at
## a perk_type key) — a validator must not itself crash on the exact kind of
## bad data it exists to catch.
func validate() -> Array[String]:
	var errors: Array[String] = []
	for perk_type: String in VALID_PERK_TYPES:
		if not entries.has(perk_type):
			errors.append("Missing required perk_type entry: %s" % perk_type)
			continue
		var raw: Variant = entries[perk_type]
		if typeof(raw) != TYPE_DICTIONARY:
			errors.append("%s: entry is not a Dictionary (got %s)" % [perk_type, type_string(typeof(raw))])
			continue
		var entry: Dictionary = raw
		if not entry.has("label") or String(entry["label"]) == "":
			errors.append("%s: missing or empty label" % perk_type)
		if not entry.has("archetype_restrictions"):
			errors.append("%s: missing archetype_restrictions" % perk_type)
	return errors
