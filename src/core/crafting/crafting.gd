class_name Crafting
extends Node

## Recipe discovery state machine (Story 002, TR-craft-002, ADR-0023).
##
## GDD source: design/gdd/crafting.md — Rule 3/4 (Discovery, two gates:
## tech + materials).
## Scene-instanced, Sanctuary-only (ADR-0023 Architecture Diagram) — NOT an
## Autoload. Flagged in production/epics/index.md as subject to the
## project-wide SavePersistence mid-session-restore gap: this node is
## recreated whenever the Sanctuary scene reloads mid-session, but
## SavePersistence._restore_all_systems() only ever fires from the initial
## load_slot() call — a fresh Crafting instance created after the very first
## boot-load will register with SavePersistence but never have
## restore_save_data() called on it again, so the boot discovery sweep
## (trigger 3 below) will not re-run on every Sanctuary return. This is a
## known, tracked, project-wide gap (not something this story invents or
## silently works around) — see production/epics/index.md's cross-epic
## blocker note.
##
## _discovery_ledger: recipe_id -> true means DISCOVERED, permanent, one-way
## (ADR-0023 Decision). Three trigger paths re-check discovery:
##   1. tech_unlocked — recipes gated on the newly-unlocked tech_id
##   2. item_added — tech-gate-satisfied, not-yet-discovered recipes
##   3. restore_save_data()'s one-time boot sweep — resolves TR-craft-002's
##      originally-flagged gap (a recipe already both-true at session start
##      would otherwise never fire recipe_discovered)
##
## restore_order = 25 (design/gdd/save-persistence.md, added this story —
## that table had no Crafting row at all prior to this pass, despite
## ADR-0023 requiring > 21). Strictly greater than both Inventory (10) and
## Defense Building (21), per ADR-0023's Decision.

const RESTORE_ORDER: int = 25

var _discovery_ledger: Dictionary[StringName, bool] = {}
var _craft_resolving: bool = false  ## Story 004 — single-frame double-confirm guard


func _ready() -> void:
	GEventBus.tech_unlocked.connect(_on_tech_unlocked)
	GEventBus.item_added.connect(_on_item_added)
	GSavePersistence.register(self, RESTORE_ORDER)


func _exit_tree() -> void:
	GEventBus.tech_unlocked.disconnect(_on_tech_unlocked)
	GEventBus.item_added.disconnect(_on_item_added)
	GSavePersistence.unregister(self)


## True if recipe_id is DISCOVERED. O(1) ledger lookup.
func is_discovered(recipe_id: StringName) -> bool:
	return _discovery_ledger.get(recipe_id, false)


## Craftability (Story 003, AC-3): a pure, on-demand read of
## _has_recipe_inputs(recipe.inputs) (item_type via has_items(), rarity via
## has_items_by_rarity() — see _has_recipe_inputs()'s doc comment,
## TD-craft-001 resolution) for an already-DISCOVERED recipe —
## structurally separate from the one-time, permanent Discovery Ledger. A
## DISCOVERED recipe that temporarily lacks materials stays DISCOVERED and
## visible; only this method's result flips. Never writes to
## _discovery_ledger. Returns false (not a crash) for an undiscovered or
## unknown recipe_id — undiscovered recipes are never craftable regardless
## of material stock.
func is_craftable(recipe_id: StringName) -> bool:
	if not is_discovered(recipe_id):
		return false
	var recipe: RecipeResource = GGameDataRegistry.get_recipe(recipe_id)
	if recipe == null:
		return false
	return _has_recipe_inputs(recipe.inputs)


## TD-craft-001 RESOLVED (Sprint 6, S6-06b): `RecipeResource.validate()`
## accepts BOTH item_type keys (Equipment/TowerComponent/Material/
## CraftedGood) and rarity keys (Common/Uncommon/Rare — content-accurate to
## Formula 1-3, e.g. `recipe_tier4_component`) in `inputs`, per
## recipe_resource.gd's VALID_RARITIES doc comment. `has_items()`/
## `consume_by_type()` only understand item_type; a rarity-keyed recipe
## would previously always fail affordability, identical to the bug this
## same Sprint 6 pass fixed for repair's Common-material cost. This split
## routes each key to the matching Inventory query, so a recipe may mix both
## vocabularies in one `inputs` Dictionary.
func _has_recipe_inputs(inputs: Dictionary) -> bool:
	var by_item_type: Dictionary = {}
	var by_rarity: Dictionary = {}
	for key: Variant in inputs:
		if RecipeResource.VALID_RARITIES.has(key):
			by_rarity[key] = inputs[key]
		else:
			by_item_type[key] = inputs[key]
	return GInventory.has_items(by_item_type) and GInventory.has_items_by_rarity(by_rarity)


## Consumes a mixed item_type/rarity-keyed `inputs` Dictionary — see
## _has_recipe_inputs()'s doc comment for the split rationale. Must only be
## called after _has_recipe_inputs() has already confirmed affordability.
func _consume_recipe_inputs(inputs: Dictionary) -> void:
	for key: StringName in inputs:
		if RecipeResource.VALID_RARITIES.has(key):
			GInventory.consume_by_rarity(String(key), inputs[key])
		else:
			GInventory.consume_by_type(String(key), inputs[key])


## Crafting Resolution (Story 004, ADR-0023 Rule 8 / GDD Rule 8): synchronous,
## atomic, guarded by `_craft_resolving` — set at the start, cleared on every
## exit path, no queueing for a second confirmation received while true
## (AC-7). Steps:
##   (a) re-validate has_items(inputs) — stale-UI rejection (AC-12)
##   (b) tower_component only: has_room_for(component_slot, 1) (AC-4)
##   (c) batch-consume inputs (always runs once (a)/(b) pass — crafted_good
##       skips (b) but still consumes here, per AC-13's explicit ordering)
##   (d) construct output: add_unique_item() for tower_component,
##       add_stackable() for crafted_good
##   (e) component_crafted fires ONLY if the output was fully placed —
##       AC-13's crafted_good-genuinely-no-room case consumes materials in
##       (c) but must not fire this event since placement failed
##
## Returns true only on full success (materials consumed AND output fully
## placed). Returns false on any rejection (a/b) with zero side effects, or
## after a partial failure (c succeeded, d failed) where materials WERE
## already spent — callers must not assume false means zero side effects
## occurred; only a/b-rejections guarantee that.
func resolve_craft(recipe_id: StringName) -> bool:
	if _craft_resolving:
		return false
	_craft_resolving = true

	var recipe: RecipeResource = GGameDataRegistry.get_recipe(recipe_id)
	if recipe == null or not is_discovered(recipe_id):
		_craft_resolving = false
		return false

	if not _has_recipe_inputs(recipe.inputs):
		_craft_resolving = false
		return false

	if recipe.recipe_category == "tower_component" and not GInventory.has_room_for(recipe.component_slot, 1):
		_craft_resolving = false
		return false

	_consume_recipe_inputs(recipe.inputs)

	var output_definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(recipe.output_item_id)
	var placed: bool = false
	if output_definition != null:
		if recipe.recipe_category == "tower_component":
			# quality_tier is stored on the instance's stat_overrides (the
			# only per-instance data channel InventorySlot has) so Story
			# 005's repair cost formula can read back the ORIGINALLY-
			# crafted tier later, never re-rolled (Formula 3's explicit
			# requirement). Found and fixed while implementing Story 005 —
			# this call originally passed no stat_overrides at all.
			var crafted_stat_overrides: Dictionary[StringName, float] = {&"quality_tier": float(recipe.quality_tier)}
			placed = GInventory.add_unique_item(output_definition, crafted_stat_overrides) != -1
		else:
			placed = GInventory.add_stackable(output_definition, recipe.output_quantity) == 0

	if placed:
		GEventBus.component_crafted.emit(String(recipe.output_item_id), recipe.recipe_category, recipe.quality_tier)

	_craft_resolving = false
	return placed


## Formula 3 (Story 005/006, ADR-0023/ADR-0021): repair_common_qty(T) =
## round(BASE_REPAIR_COMMON × TIER_DPS_MULTIPLIER[T-1]). Reuses tower.md's
## registered TIER_DPS_MULTIPLIER constant (not a Crafting-owned fork, per
## this story's own Control Manifest Rule).
const BASE_REPAIR_COMMON: int = 4
const TIER_DPS_MULTIPLIER: Array[float] = [1.0, 1.6, 2.4, 4.0]  ## index 0 = Tier 1


static func repair_common_cost(quality_tier: int) -> int:
	return roundi(BASE_REPAIR_COMMON * TIER_DPS_MULTIPLIER[quality_tier - 1])


## Component Repair (Story 005, TR-craft-003 repair half; ADR-0021's
## clear_damaged_flag()). A DISTINCT resolution sequence from
## resolve_craft() (this story's own Control Manifest Rule forbids sharing
## a code path) — not a RecipeResource, no discovery lifecycle, no
## `_craft_resolving` guard (repair has no double-confirm AC of its own).
##
## TD-craft-001/TD-defbuild-002 RESOLVED (Sprint 6, S6-06b): the Common-
## material cost check below uses the rarity vocabulary Formula 1/3 was
## always authored against — now genuinely checkable/payable via
## Inventory.has_items_by_rarity()/consume_by_rarity(), a separate
## aggregation axis from has_items()/consume_by_type()'s item_type-based sum
## (see ItemDefinitionResource.rarity, Inventory's rarity-query methods).
##
## Returns true only on full success: instance found, damaged==true,
## sufficient Common material, damaged flag cleared, component_repaired
## emitted. Returns false on any rejection with zero side effects.
func resolve_repair(instance_id: int) -> bool:
	var contents: Dictionary = GInventory.get_slot_contents_by_instance_id(instance_id)
	if contents.is_empty():
		return false
	if not (contents.get("damaged", false) as bool):
		return false

	var stat_overrides: Dictionary = contents.get("stat_overrides", {})
	if not stat_overrides.has(&"quality_tier"):
		return false
	var quality_tier: int = int(stat_overrides[&"quality_tier"])
	if quality_tier < 1 or quality_tier > 4:
		return false

	var cost: int = repair_common_cost(quality_tier)
	if not GInventory.has_items_by_rarity({&"Common": cost}):
		return false

	GInventory.consume_by_rarity("Common", cost, false)  # AC-6: no item_removed for repair's cost payment
	if not GInventory.clear_damaged_flag(instance_id):
		return false

	var item_id: String = contents.get("item_id", "")
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))
	var component_type: String = definition.item_type if definition != null else ""
	GEventBus.component_repaired.emit(item_id, component_type)
	return true


func _fire_recipe_discovered(recipe_id: StringName, recipe_category: String) -> void:
	_discovery_ledger[recipe_id] = true
	GEventBus.recipe_discovered.emit(String(recipe_id), recipe_category)


# ---------------------------------------------------------------------------
# Trigger 1: tech_unlocked — recipes gated on the newly-unlocked tech
# ---------------------------------------------------------------------------

func _on_tech_unlocked(tech_id: String, _tech_category: String) -> void:
	for recipe: RecipeResource in GGameDataRegistry.get_all_recipes().values():
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
	for recipe: RecipeResource in GGameDataRegistry.get_all_recipes().values():
		if is_discovered(recipe.recipe_id):
			continue
		var tech_gate_ok: bool = recipe.tech_prerequisite == &"" or GDefenseBuilding.is_tech_unlocked(recipe.tech_prerequisite)
		if tech_gate_ok and _has_recipe_inputs(recipe.inputs):
			_fire_recipe_discovered(recipe.recipe_id, recipe.recipe_category)


# ---------------------------------------------------------------------------
# SaveRestorer interface (ADR-0003, ADR-0023)
# ---------------------------------------------------------------------------

func get_save_key() -> String:
	return "crafting"


func get_save_data() -> Dictionary:
	var ledger_data: Dictionary = {}
	for recipe_id: StringName in _discovery_ledger:
		ledger_data[String(recipe_id)] = _discovery_ledger[recipe_id]
	return {"discovery_ledger": ledger_data}


## Per ADR-0023's explicit contract: returns false only if the save payload
## itself is malformed. The boot sweep (trigger 3) itself cannot fail —
## GGameDataRegistry.get_all_recipes() is boot-loaded/validated data.
func restore_save_data(data: Dictionary) -> bool:
	var raw_ledger: Variant = data.get("discovery_ledger", {})
	if typeof(raw_ledger) != TYPE_DICTIONARY:
		return false

	var restored: Dictionary[StringName, bool] = {}
	for key: Variant in (raw_ledger as Dictionary):
		if not (key is String):
			return false
		var value: Variant = (raw_ledger as Dictionary)[key]
		if not (value is bool):
			return false
		restored[StringName(key as String)] = value as bool

	_discovery_ledger = restored
	_run_boot_discovery_sweep()
	return true


## Trigger 3: one-time sweep at restore time — resolves TR-craft-002's
## originally-flagged gap. Runs exactly once, at the end of the save-restore
## sequence, not on every scene load. Safe to call GDefenseBuilding.
## is_tech_unlocked() directly here specifically because Crafting's
## restore_order (25) is constrained to run after Defense Building's (21).
func _run_boot_discovery_sweep() -> void:
	for recipe: RecipeResource in GGameDataRegistry.get_all_recipes().values():
		if is_discovered(recipe.recipe_id):
			continue
		var tech_gate_ok: bool = recipe.tech_prerequisite == &"" or GDefenseBuilding.is_tech_unlocked(recipe.tech_prerequisite)
		if tech_gate_ok and _has_recipe_inputs(recipe.inputs):
			_fire_recipe_discovered(recipe.recipe_id, recipe.recipe_category)


func reset_to_defaults() -> void:
	_discovery_ledger = {}
