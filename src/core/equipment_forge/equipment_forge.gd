class_name EquipmentForge
extends Node

## Equipment Recipe discovery state machine (Story 009, TR-equipforge-001, ADR-0025).
##
## GDD source: design/gdd/equipment-forge.md — Rule 4/6 (Discovery, two gates:
## tech + materials — reuses Crafting's exact model, ADR-0023).
## Scene-instanced, Sanctuary-only (ADR-0025 Architecture Diagram) — NOT an
## Autoload. Nothing calls INTO Equipment Forge directly; every one of its
## outputs is an EventBus event, so it needs no Autoload status of its own
## (ADR-0025's Alternative B, rejected).
##
## Story 009 scope: the recipe data model (EquipmentRecipeResource) and the
## Equipment Recipe Discovery Ledger — mirroring Crafting's discovery
## pattern (src/core/crafting/crafting.gd) verbatim for recipe_category=
## "hero_equipment".
##
## Story 015 (AC-23-25): _forge_resolving is a single shared guard spanning
## all 3 operation types (crafting, imbuing, sacrifice) — see its own field
## doc comment. is_rune_id_known() classifies orphaned rune references found
## on save load (AC-24/AC-25).
##
## _equipment_discovery_ledger: recipe_id -> true means DISCOVERED, permanent,
## one-way. Three trigger paths re-check discovery (matching Crafting's own
## 3-trigger model exactly, added in Story 011 alongside persistence):
##   1. tech_unlocked — recipes gated on the newly-unlocked tech_id
##   2. item_added — tech-gate-satisfied, not-yet-discovered recipes
##   3. restore_save_data()'s one-time boot sweep
##
## Story 010 (TR-equipforge-001, Rule 9/Formula 1): Equipment Crafting
## Resolution & Material Cost. resolve_craft() mirrors Crafting Rule 8
## exactly — steps (a)-(e), synchronous and atomic. _has_recipe_inputs()/
## _consume_recipe_inputs() reuse the identical mixed item_type/rarity-keyed
## input-vocabulary split Crafting itself resolved (TD-craft-001/
## TD-defbuild-002, Sprint 6 S6-06b) — inputs may be keyed by EITHER
## item_type (Material/Equipment/etc.) OR rarity (Common/Uncommon/Rare) in
## the same Dictionary, routed to the matching Inventory query. material_qty()
## replicates design/registry/entities.yaml's crafting_material_qty formula
## (no live GDScript implementation of it exists elsewhere to literally call
## into — Crafting's own recipes author `inputs` directly rather than
## deriving it at runtime) — reuses tower.md's registered
## tier_dps_multiplier table unchanged (Guardrail), identical constant to
## Crafting's own Formula 3 (repair_common_cost()).
##
## Story 012 (TR-equipforge-003, Rule 11-13/AC-13-15): rune slot model and
## the Available Rune Ledger. AC-13's rune_slot_count-per-output_slot table
## is EquipmentRecipeResource.RUNE_SLOT_COUNT_FOR_SLOT — the single source of
## truth (a previously-duplicated copy on this class, keyed by Inventory's
## DIFFERENT 5-name equip-slot vocabulary — accessory_a/accessory_b instead
## of accessory — was removed during the Story 015 batch code review: it was
## unused by any resolve_* method and a test indexed it by
## recipe.output_slot's 4-name vocabulary, which only avoided a runtime
## KeyError because no authored recipe used output_slot="accessory" yet).
## _available_runes is populated EXCLUSIVELY by
## constellation_rune_discovered/tarot_rune_discovered subscriptions, each
## with an Equipment-Forge-authored stat_delta deliberately decoupled from
## whatever internal bonus Constellation/Tarot separately apply for the same
## discovery (Guardrail). Menagerie-sourced runes (creature_sacrificed) are
## excluded by construction, not convention (Forbidden rule) — Equipment
## Forge does not even subscribe to creature_sacrificed; Story 014's
## _resolve_sacrifice() flow (Rule 19) consumes a sacrifice rune directly via
## Menagerie.request_sacrifice()'s own return value, never touching this
## ledger at all, so there is structurally no code path that could write a
## Menagerie-sourced rune here.
##
## Story 011 (TR-equipforge-003, AC-12): Save Payload Ownership Clarification.
## Implemented AFTER Story 012 despite the numbering — Story 011's own
## Dependencies section lists Story 012 as a prerequisite (the Available Rune
## Ledger must exist before its persistence can be specified), a real
## sequencing correction found while working through the epic. get_save_data()
## persists EXACTLY the two ledgers above (Equipment Recipe Discovery Ledger,
## Available Rune Ledger) and nothing else — Equipment Forge never persists
## item-instance data (imbued_runes, rune slot occupancy); that is Inventory's
## data (InventorySlot.rune_slot_count/imbued_runes, Story 010). restore_order
## = 32 (save-persistence.md's authoritative table) — restores after Tarot
## (22), Menagerie (20), Constellation (24), and Hero (30).

const RESTORE_ORDER: int = 32
const TIER_DPS_MULTIPLIER: Array[float] = [1.0, 1.6, 2.4, 4.0]  ## index 0 = Tier 1
## Formula 3 guideline ranges (content-authoring, not a strict formula) —
## additive bonus per rune, feeds Hero's additive_bonus_total.
const RUNE_ADDITIVE_BONUS: float = 0.05  ## midpoint of the 0.02-0.08 guideline range
const BASE_QTY_COMMON: int = 8
const BASE_QTY_UNCOMMON: int = 4
const BASE_QTY_RARE: int = 2

var _equipment_discovery_ledger: Dictionary[StringName, bool] = {}
## Story 015 (AC-23): single shared guard spanning all 3 operation types
## (equipment crafting, rune imbuing, creature sacrifice) — generalizes
## Crafting's `_craft_resolving` (ADR-0023) and Defense Building's
## `_action_resolving` (ADR-0024) precedent, which each guard only one
## operation type. Set at the start of any operation's first validation
## step, cleared only after its final event emission (or on early
## rejection). A second confirmation received while true is rejected
## outright, regardless of which two of the three types are involved — no
## queueing. Replaces Story 010's narrower `_craft_resolving`.
var _forge_resolving: bool = false
var _available_runes: Dictionary[StringName, Dictionary] = {}  ## rune_id -> {rune_source, stat_delta, is_known}


## Group membership added 2026-07-25: EquipmentForge is deliberately
## scene-instanced, not an Autoload (ADR-0025) — its one real instance lives
## as a shell-owned child of SanctuaryUI.tscn (persists across room switches
## within one Sanctuary visit, resets on Sanctuary scene reload, per that
## ADR's own explicit design). The Equipment Forge SCREEN (a RoomHost-hosted,
## destroy-and-recreate room, unlike this node) discovers the shell-owned
## instance via `get_tree().get_first_node_in_group(&"equipment_forge")`
## rather than a direct node-path reference, since RoomHost's generic mount
## mechanism has no room-specific injection seam (and shouldn't gain one just
## for this).
const GROUP_NAME: StringName = &"equipment_forge"


func _ready() -> void:
	add_to_group(GROUP_NAME)
	GEventBus.tech_unlocked.connect(_on_tech_unlocked)
	GEventBus.item_added.connect(_on_item_added)
	GEventBus.constellation_rune_discovered.connect(_on_constellation_rune_discovered)
	GEventBus.tarot_rune_discovered.connect(_on_tarot_rune_discovered)
	GSavePersistence.register(self, RESTORE_ORDER)


func _exit_tree() -> void:
	GEventBus.tech_unlocked.disconnect(_on_tech_unlocked)
	GEventBus.item_added.disconnect(_on_item_added)
	GEventBus.constellation_rune_discovered.disconnect(_on_constellation_rune_discovered)
	GEventBus.tarot_rune_discovered.disconnect(_on_tarot_rune_discovered)
	GSavePersistence.unregister(self)


## AC-14: adds rune_id to the Available Rune Ledger in state AVAILABLE with
## rune_source="constellation" and an Equipment-Forge-authored stat_delta —
## never re-adds if already present (a rune, once discovered, stays
## AVAILABLE regardless of how many times its source event re-fires).
func _on_constellation_rune_discovered(rune_id: String, _pattern_id: String) -> void:
	_add_available_rune(StringName(rune_id), "constellation")


## AC-14 edge case: equivalent to the Constellation path with rune_source="tarot".
func _on_tarot_rune_discovered(rune_id: String, _card_id: String) -> void:
	_add_available_rune(StringName(rune_id), "tarot")


func _add_available_rune(rune_id: StringName, rune_source: String) -> void:
	if _available_runes.has(rune_id):
		return
	_available_runes[rune_id] = {
		"rune_source": rune_source,
		"stat_delta": {"additive_bonus_total": RUNE_ADDITIVE_BONUS},
		"is_known": true,  ## always true when added live via a discovery event
	}


## Story 015 (AC-24/AC-25): single source of truth for "is this rune_id
## still defined in current game data" — used to classify orphaned
## references found on save load. Checks all 3 rune sources:
##   - Constellation: rune_id == "rune_<shape_id>" for one of Constellation's
##     fixed, code-defined SHAPE_N keys (not data-driven catalogue content —
##     there is no removable source to orphan against, so any shape_id
##     currently compiled into Constellation is always known)
##   - Tarot: rune_id matches some currently-loaded TarotCardResource's
##     linked_rune_id
##   - Menagerie: rune_id matches some currently-loaded
##     SacrificeRecipeResource's rune_id
func is_rune_id_known(rune_id: StringName) -> bool:
	if rune_id == &"":
		return false
	var id_str: String = String(rune_id)
	for shape_id: String in Constellation.SHAPE_N:
		if id_str == "rune_%s" % shape_id:
			return true
	for card: TarotCardResource in GGameDataRegistry.get_all_tarot_cards().values():
		if String(card.linked_rune_id) == id_str:
			return true
	for recipe: SacrificeRecipeResource in GGameDataRegistry.get_all_sacrifice_recipes().values():
		if String(recipe.rune_id) == id_str:
			return true
	return false


## Equipment-stats-wiring spec §3.4: resolves rune_id to the stat_delta it
## contributes, on demand — nothing is persisted, since every rune source's
## delta is a pure function of rune_id alone. Mirrors is_rune_id_known()'s
## 3-way source matching (kept as a mirrored pair, not refactored, because
## the return shapes differ). Static because EquipmentForge is not an
## autoload — Hero has no instance to call. Returns {} for an unknown
## (orphaned) rune_id, never an error. Rune-variety spec: values now come
## from data (Constellation/Tarot/Menagerie), with a generic fallback.
static func resolve_rune_stat_delta(rune_id: StringName) -> Dictionary:
	if rune_id == &"":
		return {}
	var id_str: String = String(rune_id)
	for shape_id: String in Constellation.SHAPE_N:
		if id_str == "rune_%s" % shape_id:
			return _rune_delta_or_fallback(Constellation.SHAPE_RUNE_STAT_DELTA.get(shape_id, {}))
	for card: TarotCardResource in GGameDataRegistry.get_all_tarot_cards().values():
		if String(card.linked_rune_id) == id_str:
			return _rune_delta_or_fallback(card.rune_stat_delta)
	for recipe: SacrificeRecipeResource in GGameDataRegistry.get_all_sacrifice_recipes().values():
		if String(recipe.rune_id) == id_str:
			return recipe.stat_delta.duplicate()
	return {}


## A missing/empty authored rune value falls back to the original generic
## +5% all-stats bonus rather than resolving to nothing (rune-variety spec §3.2).
static func _rune_delta_or_fallback(delta: Dictionary) -> Dictionary:
	if delta.is_empty():
		return {"additive_bonus_total": RUNE_ADDITIVE_BONUS}
	return delta.duplicate()


## Returns rune_id's ledger entry, or {} if not AVAILABLE (never discovered,
## or already imbued/consumed — Story 013's own scope removes it from here).
func get_available_rune(rune_id: StringName) -> Dictionary:
	return _available_runes.get(rune_id, {})


## Read-only roster query for the Equipment Forge screen's own Imbue-tab
## rune-pool panel (added 2026-07-25 — no enumeration API existed before,
## only the single-ID get_available_rune() lookup). Returns a shallow copy
## so callers can't mutate the ledger directly.
func get_all_available_runes() -> Dictionary[StringName, Dictionary]:
	return _available_runes.duplicate()


## Rune Imbuing Action (Rule 14, AC-16(a-d)): imbues rune_id (must currently
## be AVAILABLE) into the item identified by instance_id. Calls
## Inventory.apply_rune_to_item() — succeeds on a currently-equipped item
## (AC-16(a), Rule 5 exemption is Inventory's own guarantee), fails cleanly
## with zero mutation if the target has no free rune slot (AC-16(c)). On
## success: the rune is removed from _available_runes (AC-16(b) — permanent,
## one-time consumption, no path can reintroduce it) and
## item_rune_imbued(item_id, rune_id, rune_source) fires exactly once, with
## rune_source carrying whichever exact literal string
## ("constellation"/"tarot"/"menagerie") the ledger entry was created with
## (AC-16(d)). Returns false on any rejection with zero side effects.
##
## Story 015 (AC-23): guarded by the shared _forge_resolving flag — a second
## confirmation of any of the 3 operation types received while this is
## resolving is rejected outright.
## Story 015 (AC-25): an orphaned rune (is_known == false, retained but
## unselectable) is rejected here — orphaning never frees a slot for the
## originally-imbued rune to be re-imbued, and an orphaned still-AVAILABLE
## rune can never be newly selected for imbuing either.
##
## KNOWN GAP, flagged not silently solved: stat_delta is passed through to
## Inventory.apply_rune_to_item() per ADR-0021's signature, but neither
## Inventory nor Equipment Forge currently persists it anywhere retrievable
## after this call — InventorySlot.imbued_runes stores only the rune_id.
## Hero's eventual reading of an already-imbued rune's stat_delta (to
## actually apply the bonus) needs a rune_id -> stat_delta lookup this story
## does not specify; _available_runes is erased on imbue, so it cannot serve
## as that lookup's source of truth after the fact. Out of this story's own
## AC scope (which only tests imbuing mechanics, not stat application) but
## surfaced here explicitly rather than assumed solved.
func resolve_imbue(instance_id: int, rune_id: StringName) -> bool:
	if _forge_resolving:
		return false
	_forge_resolving = true

	if not _available_runes.has(rune_id):
		_forge_resolving = false
		return false
	var entry: Dictionary = _available_runes[rune_id]
	if not (entry.get("is_known", true) as bool):
		_forge_resolving = false
		return false
	var item_contents: Dictionary = GInventory.get_slot_contents_by_instance_id(instance_id)
	if item_contents.is_empty():
		_forge_resolving = false
		return false
	if not GInventory.apply_rune_to_item(instance_id, String(rune_id), entry["stat_delta"] as Dictionary):
		_forge_resolving = false
		return false
	_available_runes.erase(rune_id)
	GEventBus.item_rune_imbued.emit(item_contents["item_id"] as String, String(rune_id), entry["rune_source"] as String)
	_forge_resolving = false
	return true


## Formula 2: quality_tier(species_tier) = clamp(species_tier+1, 1, 4) — a
## sacrifice-born item is never Tier 1, deliberately: surrendering a tended
## creature always produces at least Tier 2.
static func sacrifice_quality_tier(species_tier: int) -> int:
	return clampi(species_tier + 1, 1, 4)


## Creature Sacrifice Resolution (Rule 17-20, AC-17-22): closes menagerie.md's
## explicitly-flagged open question — the item Menagerie's creature_sacrificed
## refers to is a NEW item Equipment Forge creates in this same operation.
## Strict step order (Rule 19), returns false at the first failing step with
## zero side effects up through step (d):
##   (a) species pre-check — sacrifice_recipe.required_species must match the
##       target creature's species, BEFORE any system call (AC-18)
##   (b) has_room_for(output_slot, 1) — checked before the creature is
##       touched at all (AC-20); a full Inventory can never cause a creature
##       to be consumed with no home for the resulting item
##   (c) reserve a prospective target_item_id via Inventory.reserve_instance_id()
##   (d) Menagerie.request_sacrifice(creature_id, target_item_id) — synchronous
##       validation; false (e.g. BREEDING_PEN, AC-19) aborts with zero further
##       side effects, the reserved id is simply left unassigned
##   (f) on success: item constructed with the recipe's rune_slot_count (Rule
##       11 table), added via item_added; hero_equipment_crafted then
##       item_rune_imbued(rune_source="menagerie") fire in that exact order
##       (AC-17) — the item arrives with 1 rune slot already pre-filled by its
##       species-specific rune, any remaining slots open for further Rule 14
##       imbuing
##
## Event item_id convention: hero_equipment_crafted/item_rune_imbued both
## carry the item's BASE definition id (output_base_item_id), not the
## instance_id used internally for target_item_id/reserve_instance_id() — this
## follows Story 010/013's own already-shipped convention for these two
## signals (item_id = definition, item_type = slot) rather than Rule 19(f)'s
## literal "item_id = target_item_id" wording, to keep the event surface
## consistent across the craft/imbue/sacrifice paths. Flagged here explicitly
## as a deliberate consistency decision, not a silent deviation.
func resolve_sacrifice(sacrifice_recipe_id: StringName, creature_id: int) -> bool:
	if _forge_resolving:
		return false  # AC-23: shared guard — a 2nd confirmation of any of the 3 types is rejected outright
	_forge_resolving = true

	var recipe: SacrificeRecipeResource = GGameDataRegistry.get_sacrifice_recipe(sacrifice_recipe_id)
	if recipe == null:
		_forge_resolving = false
		return false

	var creature: CreatureInstance = GMenagerie.get_creature(creature_id)
	if creature == null or creature.species != recipe.required_species:
		_forge_resolving = false
		return false  # AC-18: species mismatch rejected before any system call

	if not GInventory.has_room_for(recipe.output_slot, 1):
		_forge_resolving = false
		return false  # AC-20: room check strictly precedes creature consumption

	var target_item_id: int = GInventory.reserve_instance_id()

	if not GMenagerie.request_sacrifice(creature_id, target_item_id):
		_forge_resolving = false
		return false  # AC-19: e.g. BREEDING_PEN — abort, no item created, no consumption

	var species: SpeciesResource = GGameDataRegistry.get_species(recipe.required_species)
	var species_tier: int = species.species_tier if species != null else 1
	var quality_tier: int = sacrifice_quality_tier(species_tier)

	var output_definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(recipe.output_base_item_id)
	if output_definition == null:
		_forge_resolving = false
		return false

	# recipe.output_slot uses the weapon/armor/accessory/trinket vocabulary,
	# matching EquipmentRecipeResource.RUNE_SLOT_COUNT_FOR_SLOT's own keys.
	var rune_slot_count: int = EquipmentRecipeResource.RUNE_SLOT_COUNT_FOR_SLOT.get(recipe.output_slot, 1)
	var placed_idx: int = GInventory.add_unique_item(output_definition, {}, rune_slot_count, target_item_id)
	if placed_idx == -1:
		_forge_resolving = false
		return false

	GEventBus.hero_equipment_crafted.emit(String(recipe.output_base_item_id), recipe.output_slot, quality_tier)
	GInventory.apply_rune_to_item(target_item_id, String(recipe.rune_id), recipe.stat_delta)
	GEventBus.item_rune_imbued.emit(String(recipe.output_base_item_id), String(recipe.rune_id), "menagerie")
	_forge_resolving = false
	return true


## True if recipe_id is DISCOVERED. O(1) ledger lookup.
func is_discovered(recipe_id: StringName) -> bool:
	return _equipment_discovery_ledger.get(recipe_id, false)


## Craftability (AC-7): a pure, on-demand read of Inventory's current stock
## for an already-DISCOVERED recipe — structurally separate from the
## one-time, permanent Discovery Ledger. A DISCOVERED recipe that temporarily
## lacks materials stays DISCOVERED and visible; only this method's result
## flips. Never writes to _equipment_discovery_ledger. Returns false (not a
## crash) for an undiscovered or unknown recipe_id.
func is_craftable(recipe_id: StringName) -> bool:
	if not is_discovered(recipe_id):
		return false
	var recipe: EquipmentRecipeResource = GGameDataRegistry.get_equipment_recipe(recipe_id)
	if recipe == null:
		return false
	return _has_recipe_inputs(recipe.inputs)


func _fire_recipe_discovered(recipe_id: StringName, recipe_category: String) -> void:
	_equipment_discovery_ledger[recipe_id] = true
	GEventBus.recipe_discovered.emit(String(recipe_id), recipe_category)


## Formula 1: material_qty(rarity, T) = round(base_qty[rarity] x tier_dps_multiplier(T)).
## Worked table (design/registry/entities.yaml): T1=8 Common; T2=13 Common+6
## Uncommon; T3=19 Common+10 Uncommon; T4=32 Common+16 Uncommon+8 Rare.
static func material_qty(rarity: String, quality_tier: int) -> int:
	var base_qty: int
	match rarity:
		"Common":
			base_qty = BASE_QTY_COMMON
		"Uncommon":
			base_qty = BASE_QTY_UNCOMMON
		"Rare":
			base_qty = BASE_QTY_RARE
		_:
			return 0
	return roundi(base_qty * TIER_DPS_MULTIPLIER[quality_tier - 1])


## TD-craft-001/TD-defbuild-002 resolution, reused verbatim (Crafting's own
## src/core/crafting/crafting.gd::_has_recipe_inputs()): inputs may mix
## item_type keys (checked via has_items()) and rarity keys (checked via
## has_items_by_rarity()) in the same Dictionary.
func _has_recipe_inputs(inputs: Dictionary) -> bool:
	var by_item_type: Dictionary = {}
	var by_rarity: Dictionary = {}
	for key: Variant in inputs:
		if ItemDefinitionResource.VALID_RARITIES.has(key) and key != "":
			by_rarity[key] = inputs[key]
		else:
			by_item_type[key] = inputs[key]
	return GInventory.has_items(by_item_type) and GInventory.has_items_by_rarity(by_rarity)


func _consume_recipe_inputs(inputs: Dictionary) -> void:
	for key: Variant in inputs:
		if ItemDefinitionResource.VALID_RARITIES.has(key) and key != "":
			GInventory.consume_by_rarity(String(key), inputs[key])
		else:
			GInventory.consume_by_type(String(key), inputs[key])


## Equipment Crafting Resolution (Rule 9), mirroring Crafting Rule 8 exactly —
## synchronous, atomic, guarded by the shared _forge_resolving flag (Story
## 015, AC-23: single-frame double-confirm rejection across all 3 operation
## types, generalizing this story's own original AC-8/AC-9-style guard).
## Steps:
##   (a) re-validate _has_recipe_inputs(inputs) — stale-UI rejection (AC-8)
##   (b) has_room_for(output_slot, 1) pre-check (AC-9)
##   (c) batch-consume inputs — only after (a)/(b) both pass
##   (d) construct the output item with rune_slot_count free empty rune slots
##   (e) emit hero_equipment_crafted(item_id, item_type=output_slot, quality_tier)
##       — fires ONLY if the output was fully placed
## Returns true only on full success. Returns false on any (a)/(b) rejection
## with zero side effects; a false after (c) succeeded but (d) failed means
## materials WERE already spent (same caveat as Crafting's own resolve_craft()).
func resolve_craft(recipe_id: StringName) -> bool:
	if _forge_resolving:
		return false
	_forge_resolving = true

	var recipe: EquipmentRecipeResource = GGameDataRegistry.get_equipment_recipe(recipe_id)
	if recipe == null or not is_discovered(recipe_id):
		_forge_resolving = false
		return false

	if not _has_recipe_inputs(recipe.inputs):
		_forge_resolving = false
		return false

	if not GInventory.has_room_for(recipe.output_slot, 1):
		_forge_resolving = false
		return false

	_consume_recipe_inputs(recipe.inputs)

	var output_definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(recipe.output_item_id)
	var placed: bool = false
	if output_definition != null:
		placed = GInventory.add_unique_item(output_definition, {}, recipe.rune_slot_count) != -1

	if placed:
		GEventBus.hero_equipment_crafted.emit(String(recipe.output_item_id), recipe.output_slot, recipe.quality_tier)

	_forge_resolving = false
	return placed


# ---------------------------------------------------------------------------
# Trigger 1: tech_unlocked — recipes gated on the newly-unlocked tech
# ---------------------------------------------------------------------------

func _on_tech_unlocked(tech_id: String, _tech_category: String) -> void:
	for recipe: EquipmentRecipeResource in GGameDataRegistry.get_all_equipment_recipes().values():
		if is_discovered(recipe.recipe_id):
			continue
		if String(recipe.tech_prerequisite) != tech_id:
			continue
		if _has_recipe_inputs(recipe.inputs):
			_fire_recipe_discovered(recipe.recipe_id, recipe.recipe_category)


# ---------------------------------------------------------------------------
# Trigger 2: item_added — tech-gate-satisfied, not-yet-discovered recipes
# re-checked against the newly-changed material stock
# ---------------------------------------------------------------------------

func _on_item_added(_item_id: String, _item_type: String, _quantity: int) -> void:
	for recipe: EquipmentRecipeResource in GGameDataRegistry.get_all_equipment_recipes().values():
		if is_discovered(recipe.recipe_id):
			continue
		var tech_gate_ok: bool = recipe.tech_prerequisite == &"" or GDefenseBuilding.is_tech_unlocked(recipe.tech_prerequisite)
		if tech_gate_ok and _has_recipe_inputs(recipe.inputs):
			_fire_recipe_discovered(recipe.recipe_id, recipe.recipe_category)


# ---------------------------------------------------------------------------
# SaveRestorer interface (ADR-0003, ADR-0025) — Story 011
# ---------------------------------------------------------------------------

func get_save_key() -> String:
	return "equipment_forge"


## AC-12: payload contains EXACTLY these two ledgers, no item-instance data —
## actual Equipment item instances (rune_slot_count/imbued_runes) are
## Inventory's data (InventorySlot, Story 010), never duplicated here.
func get_save_data() -> Dictionary:
	var discovery_data: Dictionary = {}
	for recipe_id: StringName in _equipment_discovery_ledger:
		discovery_data[String(recipe_id)] = _equipment_discovery_ledger[recipe_id]

	var runes_data: Dictionary = {}
	for rune_id: StringName in _available_runes:
		var entry: Dictionary = _available_runes[rune_id]
		var stat_delta_data: Dictionary = {}
		for key: String in (entry["stat_delta"] as Dictionary):
			stat_delta_data[key] = (entry["stat_delta"] as Dictionary)[key]
		runes_data[String(rune_id)] = {
			"rune_source": entry["rune_source"],
			"stat_delta": stat_delta_data,
		}

	return {
		"equipment_discovery_ledger": discovery_data,
		"available_runes": runes_data,
	}


## Returns false (not void!) on any malformed/missing data so SavePersistence
## falls back to reset_to_defaults(), matching every other SaveRestorer in
## this project. Type-checks every leaf before mutating any field.
func restore_save_data(data: Dictionary) -> bool:
	if not (data.has("equipment_discovery_ledger") and data.has("available_runes")):
		return false

	var discovery_raw: Variant = data["equipment_discovery_ledger"]
	var runes_raw: Variant = data["available_runes"]
	if not (discovery_raw is Dictionary and runes_raw is Dictionary):
		return false

	var restored_discovery: Dictionary[StringName, bool] = {}
	for key: Variant in (discovery_raw as Dictionary):
		if not (key is String):
			return false
		var value: Variant = (discovery_raw as Dictionary)[key]
		if not (value is bool):
			return false
		restored_discovery[StringName(key as String)] = value as bool

	var restored_runes: Dictionary[StringName, Dictionary] = {}
	for rune_id: Variant in (runes_raw as Dictionary):
		if not (rune_id is String):
			return false
		var entry_raw: Variant = (runes_raw as Dictionary)[rune_id]
		if not (entry_raw is Dictionary):
			return false
		var entry: Dictionary = entry_raw as Dictionary
		if not (entry.has("rune_source") and entry.has("stat_delta")):
			return false
		if not (entry["rune_source"] is String):
			return false
		if not (entry["stat_delta"] is Dictionary):
			return false
		# AC-25: is_known is re-derived against CURRENT game data at restore
		# time, never persisted — a rune valid when saved but removed from
		# the catalogue since (or vice versa, reintroduced) must reflect
		# today's content, not a stale flag from save time.
		restored_runes[StringName(rune_id as String)] = {
			"rune_source": entry["rune_source"],
			"stat_delta": (entry["stat_delta"] as Dictionary).duplicate(),
			"is_known": is_rune_id_known(StringName(rune_id as String)),
		}

	_equipment_discovery_ledger = restored_discovery
	_available_runes = restored_runes
	_run_boot_discovery_sweep()
	return true


## Trigger 3: one-time sweep at restore time, mirroring Crafting's own
## precedent exactly — resolves the equivalent gap TR-craft-002 originally
## flagged (a recipe already both-true at session start would otherwise
## never fire recipe_discovered).
func _run_boot_discovery_sweep() -> void:
	for recipe: EquipmentRecipeResource in GGameDataRegistry.get_all_equipment_recipes().values():
		if is_discovered(recipe.recipe_id):
			continue
		var tech_gate_ok: bool = recipe.tech_prerequisite == &"" or GDefenseBuilding.is_tech_unlocked(recipe.tech_prerequisite)
		if tech_gate_ok and _has_recipe_inputs(recipe.inputs):
			_fire_recipe_discovered(recipe.recipe_id, recipe.recipe_category)


## Clears both persisted ledgers to their starting (brand-new-save) state.
## Never called by mission end — only by SavePersistence when no save data
## exists yet, or when restore_save_data() rejects malformed data.
func reset_to_defaults() -> void:
	_equipment_discovery_ledger.clear()
	_available_runes.clear()
