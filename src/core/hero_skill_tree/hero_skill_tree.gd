class_name HeroSkillTree
extends Node

## Autoload (ADR-0041) — Sanctuary spend-progression layer between Tower
## Mastery's mid-combat mastery accrual and Hero Skill Build's equippable-
## skill library. Must stay alive and correctly-stated across the entire
## SANCTUARY<->MISSION boundary: `skill_tree_point_earned` fires mid-mission
## (Tower Mastery), while node purchases only ever happen at Sanctuary — a
## scene-instanced node would lose both the earned-but-unspent points and the
## purchased node state on every scene transition.
##
## GDD source: design/gdd/hero-skill-tree.md
## Governing ADR: docs/architecture/adr-0041-hero-skill-tree-event-ownership.md
##
## Emission-only ownership split (ADR-0041): Tower Mastery emits
## skill_tree_point_earned unconditionally, forever, with zero cross-system
## reads of this Autoload's state — this file is the SOLE owner of all
## skill_tree_points/overflow_points/node mutation, and the sole emitter of
## skill_unlocked (Choice node purchase) and skill_tree_node_unlocked (Minor
## node purchase).
##
## Node chain shape (Rule 6, revised 2026-09-01 for the PoE-scale skill
## roster): each of the 4 archetype chains is `[Minor_1, Choice_1, Choice_2,
## Choice_3]` — node_index 0 is the fixed-effect Minor node, node_index 1-3
## are Choice nodes whose 2-3 candidate skill_ids are resolved live from
## hero-skill-build.md's catalogue (opener/core/capstone tiers respectively),
## never persisted as their own field (Dependencies section: locked_out_skill_ids
## is intentionally derived, not stored, to avoid a second source of truth).

const ARCHETYPES: Array[String] = ["physical", "ranged", "elemental", "support"]
const NODES_PER_CHAIN: int = 4
const RESTORE_ORDER: int = 37

## node_index -> tier queried from GameDataRegistry's SkillDefinitionResource.tier
## for Choice nodes (1, 2, 3). node_index 0 (Minor) has no tier — never queried.
const TIER_FOR_CHOICE_NODE: Dictionary[int, String] = {1: "opener", 2: "core", 3: "capstone"}

## archetype -> 4-int point pool. Never fungible with each other (Rule 7) —
## overflow_points below is the sole substitution mechanism.
var skill_tree_points: Dictionary[String, int] = {}

## Shared, archetype-agnostic pool credited when an already-fully-unlocked
## archetype earns a further point (Rule 3b) — may substitute for any
## archetype's own point at purchase time, but archetype pools never convert
## into it or into each other directly.
var overflow_points: int = 0

## Per-visit spend cap (Rule 13): 1 purchase per Sanctuary visit, across all
## 4 archetypes combined. Persisted (not ephemeral) and reset only on
## mission_launched — closes a Save & Quit -> relaunch free-purchase exploit
## a `/review-all-gdds` pass found.
var visit_spend_count: int = 0

## archetype -> Array[Dictionary] of NODES_PER_CHAIN node states. Node 0:
## {"unlocked": bool}. Nodes 1-3: {"unlocked": bool, "chosen_skill_id": String}
## (empty until purchased).
var _chain_nodes: Dictionary[String, Array] = {}


func _ready() -> void:
	_reset_chain_nodes()
	GEventBus.skill_tree_point_earned.connect(_on_skill_tree_point_earned)
	GEventBus.mission_launched.connect(_on_mission_launched)
	GSavePersistence.register(self, RESTORE_ORDER)


func _exit_tree() -> void:
	GEventBus.skill_tree_point_earned.disconnect(_on_skill_tree_point_earned)
	GEventBus.mission_launched.disconnect(_on_mission_launched)
	GSavePersistence.unregister(self)


func _reset_chain_nodes() -> void:
	_chain_nodes.clear()
	for archetype: String in ARCHETYPES:
		var chain: Array = []
		chain.append({"unlocked": false})
		for _choice_index: int in 3:
			chain.append({"unlocked": false, "chosen_skill_id": ""})
		_chain_nodes[archetype] = chain
	for archetype: String in ARCHETYPES:
		skill_tree_points[archetype] = 0


## Rule 13: visit_spend_count resets only on mission_launched, not on generic
## Sanctuary (re-)entry — a player who never leaves Sanctuary keeps the same
## visit's single-purchase allowance until they actually depart.
func _on_mission_launched(_mission_id: String, _modifiers: PackedStringArray, _difficulty_tier: int) -> void:
	visit_spend_count = 0


## Formula 3's crediting rule, revised 2026-08-31/09-01: Tower Mastery emits
## unconditionally and never checks this system's state — all of the
## fully-unlocked/overflow/terminal-no-op branching lives here instead.
## - Given the crediting archetype's own chain still has a locked node:
##   credit its own pool (the common case).
## - Given that archetype's chain is fully unlocked but at least one other
##   archetype still has a locked node: credit the shared overflow pool
##   instead (Rule 3b) and emit skill_tree_overflow_point_earned.
## - Given ALL 16 nodes across all 4 archetypes are already unlocked: silent
##   no-op — no currency of any kind, no event (Rule 3c, revised 2026-08-31
##   third pass after the terminal gold-conversion design was reverted).
func _on_skill_tree_point_earned(archetype: String, source_tower_id: int) -> void:
	if not ARCHETYPES.has(archetype):
		return
	if not is_archetype_fully_unlocked(archetype):
		skill_tree_points[archetype] = skill_tree_points.get(archetype, 0) + 1
		return
	if is_fully_complete():
		return
	overflow_points += 1
	GEventBus.skill_tree_overflow_point_earned.emit(source_tower_id)


## True once all NODES_PER_CHAIN nodes in `archetype`'s own chain are unlocked.
func is_archetype_fully_unlocked(archetype: String) -> bool:
	var chain: Array = _chain_nodes.get(archetype, [])
	for node: Dictionary in chain:
		if not (node.get("unlocked", false) as bool):
			return false
	return chain.size() == NODES_PER_CHAIN


## True once all 4 archetypes' chains are fully unlocked (all 16 nodes).
func is_fully_complete() -> bool:
	for archetype: String in ARCHETYPES:
		if not is_archetype_fully_unlocked(archetype):
			return false
	return true


## Index of the first locked node in `archetype`'s chain, or -1 if the chain
## is already fully unlocked. Purchases are only ever legal against this index
## (Rule 7 — strictly in order within a chain).
func get_first_locked_node_index(archetype: String) -> int:
	var chain: Array = _chain_nodes.get(archetype, [])
	for i: int in chain.size():
		if not ((chain[i] as Dictionary).get("unlocked", false) as bool):
			return i
	return -1


## Formula 2's purchasability precondition (AC-2): visit_spend_count == 0 for
## the current Sanctuary visit, node_index is the chain's first locked node,
## AND its own pool or overflow has >=1 point.
func is_node_purchasable(archetype: String, node_index: int) -> bool:
	if visit_spend_count != 0:
		return false
	if not ARCHETYPES.has(archetype):
		return false
	if node_index != get_first_locked_node_index(archetype):
		return false
	if skill_tree_points.get(archetype, 0) < 1 and overflow_points < 1:
		return false
	return true


## The 2-3 candidate skill_ids for a Choice node, resolved live from
## GameDataRegistry (never persisted — Dependencies section's deliberate
## choice, avoiding a second source of truth against the catalogue itself).
## Empty for node_index 0 (Minor — has no tier/candidates).
func get_tier_skill_ids(archetype: String, node_index: int) -> Array[String]:
	var result: Array[String] = []
	if not TIER_FOR_CHOICE_NODE.has(node_index):
		return result
	var tier: String = TIER_FOR_CHOICE_NODE[node_index]
	var definitions: Dictionary[StringName, SkillDefinitionResource] = GGameDataRegistry.get_all_skill_definitions()
	var skill_ids: Array[String] = []
	for skill_id: StringName in definitions:
		var definition: SkillDefinitionResource = definitions[skill_id]
		if definition.category == archetype and definition.tier == tier:
			skill_ids.append(String(skill_id))
	skill_ids.sort()
	return skill_ids


## Edge Cases (LOCKED_OUT): the sibling skill_ids of an already-purchased
## Choice node that are now permanently unreachable this playthrough. Empty
## for a not-yet-purchased node or for the Minor node (node_index 0).
func get_locked_out_skill_ids(archetype: String, node_index: int) -> Array[String]:
	var result: Array[String] = []
	if not TIER_FOR_CHOICE_NODE.has(node_index):
		return result
	var chain: Array = _chain_nodes.get(archetype, [])
	if node_index >= chain.size():
		return result
	var node: Dictionary = chain[node_index]
	if not (node.get("unlocked", false) as bool):
		return result
	var chosen: String = node.get("chosen_skill_id", "") as String
	for skill_id: String in get_tier_skill_ids(archetype, node_index):
		if skill_id != chosen:
			result.append(skill_id)
	return result


## Formula 2: attempts to purchase `node_index` in `archetype`'s chain.
## `player_selected_skill_id` is required for Choice nodes (node_index 1-3)
## and must be a member of that node's current tier_skill_ids — ignored for
## the Minor node (node_index 0). Rejected without any state mutation
## (own pool, overflow, visit_spend_count, or the node itself) if
## is_node_purchasable() fails, or (Choice nodes only) if
## player_selected_skill_id isn't a valid candidate. Returns true on success.
func purchase_node(archetype: String, node_index: int, player_selected_skill_id: String = "") -> bool:
	if not is_node_purchasable(archetype, node_index):
		return false

	var is_choice: bool = TIER_FOR_CHOICE_NODE.has(node_index)
	if is_choice:
		var candidates: Array[String] = get_tier_skill_ids(archetype, node_index)
		if not candidates.has(player_selected_skill_id):
			return false

	if skill_tree_points.get(archetype, 0) >= 1:
		skill_tree_points[archetype] -= 1
	else:
		overflow_points -= 1

	var chain: Array = _chain_nodes[archetype]
	var node: Dictionary = chain[node_index]
	node["unlocked"] = true
	visit_spend_count += 1

	if is_choice:
		node["chosen_skill_id"] = player_selected_skill_id
		GEventBus.skill_unlocked.emit(player_selected_skill_id, -1)
	else:
		GEventBus.skill_tree_node_unlocked.emit(archetype, node_index)

	return true


## Read-only snapshot of one node's current state, for UI consumption.
func get_node_state(archetype: String, node_index: int) -> Dictionary:
	var chain: Array = _chain_nodes.get(archetype, [])
	if node_index < 0 or node_index >= chain.size():
		return {}
	return (chain[node_index] as Dictionary).duplicate()


# ---------------------------------------------------------------------------
# SaveRestorer interface (ADR-0003, ADR-0041)
# ---------------------------------------------------------------------------

func get_save_key() -> String:
	return "hero_skill_tree"


func get_save_data() -> Dictionary:
	return {
		"skill_tree_points": skill_tree_points.duplicate(),
		"overflow_points": overflow_points,
		"visit_spend_count": visit_spend_count,
		"chain_nodes": _chain_nodes.duplicate(true),
	}


## Returns false (not void!) on any malformed/missing data so SavePersistence
## falls back to reset_to_defaults(), matching every other SaveRestorer in
## this project. Type-checks every leaf before mutating any field — no
## partial-restore side effects on a rejected payload.
func restore_save_data(data: Dictionary) -> bool:
	if not (data.has("skill_tree_points") and data.has("overflow_points")
			and data.has("visit_spend_count") and data.has("chain_nodes")):
		return false

	var points_raw: Variant = data["skill_tree_points"]
	var overflow_raw: Variant = data["overflow_points"]
	var visit_raw: Variant = data["visit_spend_count"]
	var chains_raw: Variant = data["chain_nodes"]
	if not (points_raw is Dictionary and (overflow_raw is int or overflow_raw is float)
			and (visit_raw is int or visit_raw is float) and chains_raw is Dictionary):
		return false

	var restored_points: Dictionary[String, int] = {}
	for archetype: Variant in (points_raw as Dictionary):
		if not (archetype is String and ARCHETYPES.has(archetype as String)):
			return false
		var value: Variant = (points_raw as Dictionary)[archetype]
		if not (value is int or value is float):
			return false
		restored_points[archetype as String] = int(value)
	for archetype: String in ARCHETYPES:
		if not restored_points.has(archetype):
			restored_points[archetype] = 0

	var restored_chains: Dictionary[String, Array] = {}
	for archetype: Variant in (chains_raw as Dictionary):
		if not (archetype is String and ARCHETYPES.has(archetype as String)):
			return false
		var chain_raw: Variant = (chains_raw as Dictionary)[archetype]
		if not (chain_raw is Array) or (chain_raw as Array).size() != NODES_PER_CHAIN:
			return false
		var restored_chain: Array = []
		for i: int in NODES_PER_CHAIN:
			var node_raw: Variant = (chain_raw as Array)[i]
			if not (node_raw is Dictionary):
				return false
			var node_dict: Dictionary = node_raw as Dictionary
			var unlocked_raw: Variant = node_dict.get("unlocked", null)
			if not (unlocked_raw is bool):
				return false
			if TIER_FOR_CHOICE_NODE.has(i):
				var chosen_raw: Variant = node_dict.get("chosen_skill_id", "")
				if not (chosen_raw is String):
					return false
				restored_chain.append({"unlocked": unlocked_raw, "chosen_skill_id": chosen_raw})
			else:
				restored_chain.append({"unlocked": unlocked_raw})
		restored_chains[archetype as String] = restored_chain
	for archetype: String in ARCHETYPES:
		if not restored_chains.has(archetype):
			return false

	skill_tree_points = restored_points
	overflow_points = int(overflow_raw)
	visit_spend_count = int(visit_raw)
	_chain_nodes = restored_chains
	return true


## Clears all persisted state to a brand-new-adventure default: all 4 pools
## and overflow at 0, visit_spend_count at 0, all 16 nodes locked (Choice
## nodes' chosen_skill_id cleared too, per AC-8's revised 2026-09-01 scope —
## a new adventure makes every tier option reachable again).
func reset_to_defaults() -> void:
	overflow_points = 0
	visit_spend_count = 0
	_reset_chain_nodes()
