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

## Expanded tree (hero-skill-tree-expansion spec §3, §6a): branch slots hang off
## the spine. A slot opens once the spine node in BRANCH_OPENED_BY is bought.
const BRANCH_SLOTS: Array[String] = ["fork_1", "fork_2", "keystone"]
const BRANCH_OPENED_BY: Dictionary[String, int] = {"fork_1": 1, "fork_2": 2, "keystone": 3}
## Nodes per fork side (Minor, Minor, Notable); a keystone slot holds 1.
const FORK_DEPTH: int = 3
## Spine 4 + fork 3 + fork 3 + keystone 1 (spec §3). Bridges never count.
const PURCHASES_PER_ARCHETYPE: int = 11
## A bridge opens once this spine node is bought in both of its archetypes.
const BRIDGE_OPENED_BY: int = 2
## Bridges a hero may own at once (spec §6a decision).
const MAX_BRIDGES: int = 2
## get_save_data() schema; v1 saves (no branches/bridges) still restore.
const SAVE_SCHEMA_VERSION: int = 2

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

## archetype -> slot -> {"side": String, "depth": int}. side "" while depth 0;
## a fork side is "L"/"R" (depth 0-3), the keystone "A"/"B" (depth 0-1).
var _branches: Dictionary[String, Dictionary] = {}

## Owned bridge node ids, at most MAX_BRIDGES.
var _owned_bridges: Array[String] = []

## Node data for roots, branches and bridges. Test seam: assign before use;
## otherwise loaded from HeroTreeCatalog.DEFAULT_PATH on first access.
var catalog: HeroTreeCatalog = null


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
	_reset_branches()


func _reset_branches() -> void:
	_branches.clear()
	for archetype: String in ARCHETYPES:
		var slots: Dictionary = {}
		for slot: String in BRANCH_SLOTS:
			slots[slot] = {"side": "", "depth": 0}
		_branches[archetype] = slots
	_owned_bridges.clear()


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
## - Given is_fully_complete() (all 44 archetype purchases + MAX_BRIDGES
##   bridges, expansion spec §4; was 16 nodes): silent
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


## True once `archetype` has all PURCHASES_PER_ARCHETYPE own purchases (spine,
## both forks to their Notable, a keystone). Bridges never count (spec §4).
func is_archetype_fully_unlocked(archetype: String) -> bool:
	return get_purchase_count(archetype) >= PURCHASES_PER_ARCHETYPE


## Spine nodes bought + fork depths + keystone, for one archetype.
func get_purchase_count(archetype: String) -> int:
	var count: int = 0
	for node: Dictionary in _chain_nodes.get(archetype, []):
		if node.get("unlocked", false) as bool:
			count += 1
	var slots: Dictionary = _branches.get(archetype, {})
	for slot: String in slots:
		count += int((slots[slot] as Dictionary)["depth"])
	return count


## Rule 3c terminal state: every archetype purchase done and MAX_BRIDGES owned.
func is_fully_complete() -> bool:
	for archetype: String in ARCHETYPES:
		if not is_archetype_fully_unlocked(archetype):
			return false
	return _owned_bridges.size() >= MAX_BRIDGES


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

	_spend_point(archetype)

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
# Branches, keystones and bridges (hero-skill-tree-expansion spec §3, §6, §6a)
# ---------------------------------------------------------------------------

## The loaded node catalogue (lazy; see `catalog`).
func get_catalog() -> HeroTreeCatalog:
	if catalog == null:
		catalog = load(HeroTreeCatalog.DEFAULT_PATH) as HeroTreeCatalog
		if catalog == null:
			push_error("[HeroSkillTree] cannot load %s" % HeroTreeCatalog.DEFAULT_PATH)
			catalog = HeroTreeCatalog.new()
	return catalog


## True once the spine node that opens `slot` is bought.
func is_branch_open(archetype: String, slot: String) -> bool:
	if not BRANCH_OPENED_BY.has(slot):
		return false
	return _is_spine_unlocked(archetype, BRANCH_OPENED_BY[slot])


## {"side": String, "depth": int} copy for `slot` ("" / 0 while nothing is bought).
func get_branch_state(archetype: String, slot: String) -> Dictionary:
	var slots: Dictionary = _branches.get(archetype, {})
	if not slots.has(slot):
		return {}
	return (slots[slot] as Dictionary).duplicate()


## Nodes `slot` can hold on one side: FORK_DEPTH for forks, 1 for the keystone.
static func get_slot_depth(slot: String) -> int:
	return 1 if slot == "keystone" else FORK_DEPTH


## Valid sides of `slot`.
static func get_slot_sides(slot: String) -> Array[String]:
	return HeroTreeNodeResource.KEYSTONE_SIDES if slot == "keystone" else HeroTreeNodeResource.FORK_SIDES


## AC-X1/X2: the visit is unspent, the slot is open, `side` is the slot's
## chosen side (or nothing is bought yet), the side is not full, and a point
## (own or overflow) is available.
func is_branch_purchasable(archetype: String, slot: String, side: String) -> bool:
	if visit_spend_count != 0 or not is_branch_open(archetype, slot):
		return false
	if not get_slot_sides(slot).has(side):
		return false
	var state: Dictionary = get_branch_state(archetype, slot)
	if not (state["side"] == "" or state["side"] == side):
		return false
	if int(state["depth"]) >= get_slot_depth(slot):
		return false
	return _has_point(archetype)


## Buys the next node on `side` of `slot`. The first purchase in a slot locks
## the other side. Spends 1 own point (overflow if the pool is empty) and the
## visit. Returns false with no state change when not purchasable.
func purchase_branch_node(archetype: String, slot: String, side: String) -> bool:
	if not is_branch_purchasable(archetype, slot, side):
		return false
	_spend_point(archetype)
	var state: Dictionary = _branches[archetype][slot]
	state["side"] = side
	state["depth"] = int(state["depth"]) + 1
	visit_spend_count += 1
	GEventBus.skill_tree_branch_changed.emit(archetype, slot)
	return true


## True when `slot` has something bought and the visit is unspent.
func can_retrain(archetype: String, slot: String) -> bool:
	if visit_spend_count != 0:
		return false
	var state: Dictionary = get_branch_state(archetype, slot)
	return not state.is_empty() and int(state["depth"]) > 0


## AC-X3: moves the slot's bought nodes to the other side at the same depth
## (keystone A <-> B). Costs the visit; refunds and charges no points.
func retrain(archetype: String, slot: String) -> bool:
	if not can_retrain(archetype, slot):
		return false
	var state: Dictionary = _branches[archetype][slot]
	var sides: Array[String] = get_slot_sides(slot)
	state["side"] = sides[1] if state["side"] == sides[0] else sides[0]
	visit_spend_count += 1
	GEventBus.skill_tree_branch_changed.emit(archetype, slot)
	return true


## Every bridge node, in catalogue order.
func get_bridges() -> Array[HeroTreeNodeResource]:
	return get_catalog().bridges()


## Owned bridge ids (copy).
func get_owned_bridges() -> Array[String]:
	return _owned_bridges.duplicate()


## A bridge is open once both its archetypes own spine node BRIDGE_OPENED_BY (Skill II).
func is_bridge_open(bridge_id: String) -> bool:
	var node: HeroTreeNodeResource = get_catalog().get_node_by_id(StringName(bridge_id))
	if node == null or node.slot != &"bridge":
		return false
	for archetype: String in node.bridge_archetypes:
		if not _is_spine_unlocked(archetype, BRIDGE_OPENED_BY):
			return false
	return true


## AC-X8/X9: visit unspent, open, not owned, under MAX_BRIDGES, and 1 point
## from each archetype's pool (overflow standing in for any missing point).
func is_bridge_purchasable(bridge_id: String) -> bool:
	if visit_spend_count != 0 or _owned_bridges.has(bridge_id) or _owned_bridges.size() >= MAX_BRIDGES:
		return false
	if not is_bridge_open(bridge_id):
		return false
	var node: HeroTreeNodeResource = get_catalog().get_node_by_id(StringName(bridge_id))
	var missing: int = 0
	for archetype: String in node.bridge_archetypes:
		if int(skill_tree_points.get(archetype, 0)) < 1:
			missing += 1
	return missing <= overflow_points


## Buys a bridge atomically: both points (or overflow for either) and the visit.
func purchase_bridge(bridge_id: String) -> bool:
	if not is_bridge_purchasable(bridge_id):
		return false
	var node: HeroTreeNodeResource = get_catalog().get_node_by_id(StringName(bridge_id))
	for archetype: String in node.bridge_archetypes:
		_spend_point(archetype)
	_owned_bridges.append(bridge_id)
	visit_spend_count += 1
	GEventBus.skill_tree_branch_changed.emit("", "bridge")
	return true


## AC-X9: swaps owned `owned_id` for open, unowned `new_id`. Costs the visit;
## the 2 points move with it (no refund, no new cost).
func retrain_bridge(owned_id: String, new_id: String) -> bool:
	if visit_spend_count != 0 or not _owned_bridges.has(owned_id) or _owned_bridges.has(new_id):
		return false
	if not is_bridge_open(new_id):
		return false
	_owned_bridges[_owned_bridges.find(owned_id)] = new_id
	visit_spend_count += 1
	GEventBus.skill_tree_branch_changed.emit("", "bridge")
	return true


## The node at a branch position (null when the catalogue lacks it).
func get_branch_node(archetype: String, slot: String, side: String, depth: int) -> HeroTreeNodeResource:
	return get_catalog().find(archetype, StringName(slot), side, depth)


## The Root node data (spine node 0's effect, GDD Rule 14).
func get_root_node(archetype: String) -> HeroTreeNodeResource:
	return get_catalog().find(archetype, &"root")


## Every owned non-spine node whose effect is live: bought Roots, bought fork
## nodes on the chosen side, the chosen keystone, owned bridges.
func active_tree_nodes() -> Array[HeroTreeNodeResource]:
	var out: Array[HeroTreeNodeResource] = []
	var data: HeroTreeCatalog = get_catalog()
	for archetype: String in ARCHETYPES:
		if _is_spine_unlocked(archetype, 0):
			_append_if(out, data.find(archetype, &"root"))
		for slot: String in BRANCH_SLOTS:
			var state: Dictionary = _branches[archetype][slot]
			for depth: int in int(state["depth"]):
				_append_if(out, data.find(archetype, StringName(slot), state["side"], depth))
	for bridge_id: String in _owned_bridges:
		_append_if(out, data.get_node_by_id(StringName(bridge_id)))
	return out


## Tree effects in SetEffectController's shape ({&"key", &"name", &"type",
## &"params"}), keyed "tree:<node_id>" so they never collide with set keys.
func active_tree_effects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for node: HeroTreeNodeResource in active_tree_nodes():
		if node.effect.is_empty():
			continue
		out.append({
			&"key": StringName("tree:%s" % node.id),
			&"name": node.effect[&"name"],
			&"type": node.effect[&"type"],
			&"params": node.effect[&"params"],
		})
	return out


func _append_if(out: Array[HeroTreeNodeResource], node: HeroTreeNodeResource) -> void:
	if node != null:
		out.append(node)


func _is_spine_unlocked(archetype: String, node_index: int) -> bool:
	var chain: Array = _chain_nodes.get(archetype, [])
	return node_index < chain.size() and ((chain[node_index] as Dictionary).get("unlocked", false) as bool)


func _has_point(archetype: String) -> bool:
	return int(skill_tree_points.get(archetype, 0)) >= 1 or overflow_points >= 1


## Own pool first, overflow otherwise. Callers check _has_point first.
func _spend_point(archetype: String) -> void:
	if int(skill_tree_points.get(archetype, 0)) >= 1:
		skill_tree_points[archetype] -= 1
	else:
		overflow_points -= 1


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
		"schema_version": SAVE_SCHEMA_VERSION,
		"branches": _branches.duplicate(true),
		"bridges": _owned_bridges.duplicate(),
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

	# Schema v2 (expansion spec §7.3). A v1 save has neither key: everything
	# new starts locked and the spine/points restore unchanged (AC-X5).
	var restored_branches: Dictionary = _restore_branches(data.get("branches", {}), restored_chains)
	if restored_branches.is_empty():
		return false
	var restored_bridges: Array[String] = []
	if not _restore_bridges(data.get("bridges", []), restored_chains, restored_bridges):
		return false

	skill_tree_points = restored_points
	overflow_points = int(overflow_raw)
	visit_spend_count = int(visit_raw)
	_chain_nodes = restored_chains
	_branches.clear()
	for archetype: String in restored_branches:
		_branches[archetype] = restored_branches[archetype]
	_owned_bridges = restored_bridges
	return true


## Validated copy of a saved `branches` value, or {} when malformed. A slot is
## only valid when the spine node that opens it is unlocked in `chains`.
func _restore_branches(raw: Variant, chains: Dictionary[String, Array]) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var out: Dictionary = {}
	for archetype: String in ARCHETYPES:
		var slots_raw: Variant = (raw as Dictionary).get(archetype, {})
		if not slots_raw is Dictionary:
			return {}
		var slots: Dictionary = {}
		for slot: String in BRANCH_SLOTS:
			var state_raw: Variant = (slots_raw as Dictionary).get(slot, {"side": "", "depth": 0})
			if not state_raw is Dictionary:
				return {}
			var side: Variant = (state_raw as Dictionary).get("side", null)
			var depth: Variant = (state_raw as Dictionary).get("depth", null)
			if not (side is String and (depth is int or depth is float)):
				return {}
			var depth_i: int = int(depth)
			if depth_i < 0 or depth_i > get_slot_depth(slot):
				return {}
			if depth_i == 0 and side != "":
				return {}
			if depth_i > 0:
				if not get_slot_sides(slot).has(side):
					return {}
				var chain: Array = chains[archetype]
				if not ((chain[BRANCH_OPENED_BY[slot]] as Dictionary)["unlocked"] as bool):
					return {}
			slots[slot] = {"side": side, "depth": depth_i}
		out[archetype] = slots
	return out


## Fills `out` from a saved `bridges` value. False when malformed, over
## MAX_BRIDGES, duplicated, unknown, or not open under `chains`.
func _restore_bridges(raw: Variant, chains: Dictionary[String, Array], out: Array[String]) -> bool:
	if not raw is Array or (raw as Array).size() > MAX_BRIDGES:
		return false
	for entry: Variant in (raw as Array):
		if not entry is String or out.has(entry as String):
			return false
		var node: HeroTreeNodeResource = get_catalog().get_node_by_id(StringName(entry as String))
		if node == null or node.slot != &"bridge":
			return false
		for archetype: String in node.bridge_archetypes:
			if not ((chains[archetype][BRIDGE_OPENED_BY] as Dictionary)["unlocked"] as bool):
				return false
		out.append(entry as String)
	return true


## Clears all persisted state to a brand-new-adventure default: all 4 pools
## and overflow at 0, visit_spend_count at 0, all 16 nodes locked (Choice
## nodes' chosen_skill_id cleared too, per AC-8's revised 2026-09-01 scope —
## a new adventure makes every tier option reachable again).
func reset_to_defaults() -> void:
	overflow_points = 0
	visit_spend_count = 0
	_reset_chain_nodes()
