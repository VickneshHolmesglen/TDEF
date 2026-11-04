class_name HeroTreeCatalog
extends Resource

## Every non-spine node of the expanded Hero Skill Tree: 4 archetypes x
## (Root + 2 forks x 2 sides x 3 + 2 keystones) + 6 bridges = 66 nodes
## (design/quick-specs/hero-skill-tree-expansion-2026-11-04.md §5.2, §6a).
## Data lives in assets/data/hero_tree/hero_tree_catalog.tres; HeroSkillTree
## owns the loaded instance.
##
## Example: `var keystone := catalog.find("ranged", &"keystone", "A", 0)`

const DEFAULT_PATH: String = "res://assets/data/hero_tree/hero_tree_catalog.tres"

@export var nodes: Array[HeroTreeNodeResource] = []

var _by_id: Dictionary[StringName, HeroTreeNodeResource] = {}


## The node with `node_id`, or null.
func get_node_by_id(node_id: StringName) -> HeroTreeNodeResource:
	_index()
	return _by_id.get(node_id, null)


## The node at a tree position, or null. Root and bridges ignore side/depth.
func find(archetype: String, slot: StringName, side: String = "", depth: int = 0) -> HeroTreeNodeResource:
	for node: HeroTreeNodeResource in nodes:
		if node.archetype == archetype and node.slot == slot and node.side == side and node.depth == depth:
			return node
	return null


## Every bridge node, in catalogue order.
func bridges() -> Array[HeroTreeNodeResource]:
	var out: Array[HeroTreeNodeResource] = []
	for node: HeroTreeNodeResource in nodes:
		if node.slot == &"bridge":
			out.append(node)
	return out


## Per-node errors plus catalogue-level ones (duplicate ids, missing positions).
func validate() -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for node: HeroTreeNodeResource in nodes:
		for error: String in node.validate():
			errors.append("%s: %s" % [node.id, error])
		if seen.has(node.id):
			errors.append("duplicate id '%s'" % node.id)
		seen[node.id] = true
	for archetype: String in HeroSkillTree.ARCHETYPES:
		if find(archetype, &"root") == null:
			errors.append("%s: missing root" % archetype)
		for slot: StringName in [&"fork_1", &"fork_2"]:
			for side: String in HeroTreeNodeResource.FORK_SIDES:
				for depth: int in HeroSkillTree.FORK_DEPTH:
					if find(archetype, slot, side, depth) == null:
						errors.append("%s: missing %s %s%d" % [archetype, slot, side, depth])
		for side: String in HeroTreeNodeResource.KEYSTONE_SIDES:
			if find(archetype, &"keystone", side) == null:
				errors.append("%s: missing keystone %s" % [archetype, side])
	return errors


func _index() -> void:
	if _by_id.size() == nodes.size():
		return
	_by_id.clear()
	for node: HeroTreeNodeResource in nodes:
		_by_id[node.id] = node
