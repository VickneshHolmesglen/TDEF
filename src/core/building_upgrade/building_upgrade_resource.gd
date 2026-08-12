class_name BuildingUpgradeResource
extends Resource

## Data definition for a single Building Upgrade recipe.
##
## GDD source: design/gdd/building-upgrade.md — Core Rule 1 (Upgrade Recipe
## Model). Loaded and cached by GameDataRegistry, never constructed ad hoc
## elsewhere — same convention as RecipeResource/StructureResource/
## TechNodeResource.
##
## `requirements` is keyed by category (VALID_REQUIREMENT_TYPES below), each
## value the specific identifier required for that category — a
## `structure_id`, an `item_id`, a `card_id`, or a `species_id` respectively.
## ALL named entries must be independently satisfied (Rule 2/4); none are
## consumed by checking or by a successful purchase (Rule 5) — only
## `gold_cost`/`material_cost` are spent.

@export var upgrade_id: StringName = &""
@export var target_structure_id: StringName = &""       # the Defense Building structure_id this upgrades
@export var prerequisite_upgrade_id: StringName = &""    # "" = first upgrade in this structure's own chain
@export var requirements: Dictionary[String, StringName] = {}  # 1-4 entries, keys from VALID_REQUIREMENT_TYPES
@export var gold_cost: int = 0
@export var material_cost: Dictionary[StringName, int] = {}    # rarity-keyed, matches crafting.md Formula 1's vocabulary
@export var effect_description: String = ""              # content-authoring only — mechanical effect owned by whichever system consumes structure_upgraded (Rule 6/7)

const VALID_REQUIREMENT_TYPES: Array[String] = ["building", "equipment", "tarot", "creature"]


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009
## convention). Returns [] when valid; one string per invalid field
## otherwise. Cross-references target_structure_id against
## GameDataRegistry.get_structure() (AC-parity with RecipeResource's own
## output_item_id cross-reference) — GameDataRegistry must have already
## loaded structures by the time upgrades are validated (Defense Building's
## own _load_structures() must run before _load_building_upgrades()).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if upgrade_id == &"":
		errors.append("upgrade_id must not be empty")
	if target_structure_id == &"":
		errors.append("target_structure_id must not be empty")
	elif GGameDataRegistry.get_structure(target_structure_id) == null:
		errors.append("target_structure_id references unknown structure_id '%s'" % target_structure_id)
	if requirements.is_empty() or requirements.size() > 4:
		errors.append("requirements must have 1-4 entries (got %d)" % requirements.size())
	for key: String in requirements:
		if not VALID_REQUIREMENT_TYPES.has(key):
			errors.append("requirements key '%s' is not a valid requirement type (must be one of %s)" % [key, VALID_REQUIREMENT_TYPES])
		elif requirements[key] == &"":
			errors.append("requirements['%s'] must not be an empty identifier" % key)
	return errors


## Cross-Resource content validation (Story 002, TR-buildupgrade-001,
## ADR-0034) — requires the full loaded sibling set, so it cannot live
## inside validate() itself (called once per instance, with no visibility
## into other BuildingUpgradeResources). Called once per resource by
## GameDataRegistry._load_building_upgrades() in a second pass, after every
## upgrade for the current load has already been gathered into
## all_upgrades (keyed by upgrade_id — the same Dictionary shape
## GameDataRegistry itself caches).
##
## Returns [] when valid; one string per invalid field otherwise. Two checks:
## 1. Cross-structure prerequisite rejection (GDD Rule 1b): prerequisite_upgrade_id
##    must reference an upgrade whose own target_structure_id matches this
##    resource's target_structure_id.
## 2. Same-structure chain cycle/length rejection (GDD Rule 1a): walking the
##    prerequisite_upgrade_id chain (this resource + its ancestors, all
##    sharing one target_structure_id) must never revisit an already-visited
##    upgrade_id (cycle, incl. a self-referencing upgrade), and the chain
##    must never exceed 3 upgrades deep — matching Formula 1's
##    upgrade_tier_multiplier lookup table, which is only defined for tiers 1-3.
##    The depth cap (checked before continuing the walk) also guarantees this
##    loop always terminates within 3 iterations, even against a cycle the
##    visited-set check hasn't caught yet. Note: a cycle longer than 3 nodes
##    is reported as a chain-length error, not a cycle error — the depth cap
##    fires first, before the walk ever revisits the starting node. Both are
##    rejected either way; only the specific message text differs.
func validate_chain(all_upgrades: Dictionary[StringName, BuildingUpgradeResource]) -> Array[String]:
	var errors: Array[String] = []
	if prerequisite_upgrade_id == &"":
		return errors  # root of its own chain — nothing to walk
	var prerequisite: BuildingUpgradeResource = all_upgrades.get(prerequisite_upgrade_id)
	if prerequisite == null:
		errors.append("prerequisite_upgrade_id references unknown upgrade_id '%s'" % prerequisite_upgrade_id)
		return errors
	if prerequisite.target_structure_id != target_structure_id:
		errors.append("prerequisite_upgrade_id '%s' targets a different structure ('%s') than this upgrade's own target_structure_id ('%s')" % [prerequisite_upgrade_id, prerequisite.target_structure_id, target_structure_id])
		return errors
	var visited: Dictionary[StringName, bool] = {upgrade_id: true}
	var depth: int = 1  # counts this resource itself
	var current: BuildingUpgradeResource = prerequisite
	while current != null:
		if visited.has(current.upgrade_id):
			errors.append("prerequisite_upgrade_id chain forms a cycle at '%s'" % current.upgrade_id)
			return errors
		visited[current.upgrade_id] = true
		depth += 1
		if depth > 3:
			errors.append("prerequisite_upgrade_id chain exceeds the maximum of 3 upgrades (matches Formula 1's upgrade_tier_multiplier lookup, only defined for tiers 1-3)")
			return errors
		if current.prerequisite_upgrade_id == &"":
			current = null
		else:
			current = all_upgrades.get(current.prerequisite_upgrade_id)
	return errors
