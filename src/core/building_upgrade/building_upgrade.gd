class_name BuildingUpgrade
extends Node

## Building Upgrade's purchased-ledger container (player-requested, 2026-08-11).
##
## GDD source: design/gdd/building-upgrade.md.
## Deliberately scene-instanced, NOT an Autoload — mirrors Crafting's/
## EquipmentForge's own ADR-0023/ADR-0025 precedent (this system, like them,
## is Sanctuary-only). Its one real instance lives as a shell-owned child of
## SanctuaryUI.tscn, discovered via the "building_upgrade" group — the same
## reason those two systems use group discovery instead of a direct node-path
## reference: RoomHost's generic mount mechanism has no room-specific
## injection seam.
##
## _purchased_ledger: upgrade_id -> true means PURCHASED (permanent, one-way,
## mirrors DefenseBuilding's own ledger convention exactly).

const RESTORE_ORDER: int = 33  ## matches save-persistence.md's table (the gap between Equipment Forge=32 and Tower Mastery=34)
const GROUP_NAME: StringName = &"building_upgrade"

var _purchased_ledger: Dictionary[StringName, bool] = {}
var _action_resolving: bool = false  ## single-frame double-confirm guard, mirrors DefenseBuilding's _action_resolving


func _ready() -> void:
	add_to_group(GROUP_NAME)
	GSavePersistence.register(self, RESTORE_ORDER)


func _exit_tree() -> void:
	GSavePersistence.unregister(self)


## True if upgrade_id is PURCHASED. O(1) ledger lookup, mirrors
## DefenseBuilding.is_structure_built() exactly.
func is_purchased(upgrade_id: StringName) -> bool:
	return _purchased_ledger.get(upgrade_id, false)


## Rule 3: an upgrade is visible at all only once its target_structure_id is
## BUILT. Returns false (not a crash) for an unknown upgrade_id.
func is_visible(upgrade_id: StringName) -> bool:
	var upgrade: BuildingUpgradeResource = GGameDataRegistry.get_building_upgrade(upgrade_id)
	if upgrade == null:
		return false
	return GDefenseBuilding.is_structure_built(upgrade.target_structure_id)


## Rule 2: resolves a single requirements entry against whichever upstream
## system owns that category. Returns false for an unrecognized key (should
## never happen post-validate(), but never errors here either way).
##
## Real gap found 2026-08-11 (not this system's to fix): unlike Inventory/
## DefenseBuilding/Menagerie (all real Autoloads), Tarot is NOT an Autoload
## and is only ever instanced inside TarotDeckUI.tscn — a scene reached via
## a full SceneManager transition AWAY from Sanctuary. No live Tarot
## instance exists in the tree while the player is anywhere in Sanctuary UI
## (where this system's own screen lives), so the "tarot" group lookup
## below will find nothing there today. Failing closed (false, not a crash)
## on a missing instance is the correct, honest behavior — matches
## equipment_forge_screen.gd's own established `if equipment_forge == null:
## return` null-guard convention — rather than silently pretending the
## requirement passed. See design/gdd/building-upgrade.md's Open Questions
## for the full account; fixing Tarot's own scene-lifecycle reachability is
## out of this system's scope.
func _requirement_satisfied(requirement_type: String, identifier: StringName) -> bool:
	match requirement_type:
		"building":
			return GDefenseBuilding.is_structure_built(identifier)
		"equipment":
			return GInventory.has_specific_item(identifier)
		"tarot":
			var tarot: Tarot = get_tree().get_first_node_in_group(&"tarot") as Tarot
			return tarot != null and tarot.is_card_unlocked(identifier)
		"creature":
			return GMenagerie.has_creature_species(identifier)
		_:
			return false


## Read-only eligibility check (Rule 4): visible, not already purchased,
## prerequisite chain satisfied, and every requirements entry independently
## true. Does NOT check gold/material affordability — mirrors DefenseBuilding's
## can_unlock_tech()/can_build_structure() split exactly (a true result here
## only means "eligible to proceed to the cost check"). Returns false for an
## unknown upgrade_id.
func can_purchase(upgrade_id: StringName) -> bool:
	if is_purchased(upgrade_id):
		return false
	if not is_visible(upgrade_id):
		return false
	var upgrade: BuildingUpgradeResource = GGameDataRegistry.get_building_upgrade(upgrade_id)
	if upgrade == null:
		return false
	if upgrade.prerequisite_upgrade_id != &"" and not is_purchased(upgrade.prerequisite_upgrade_id):
		return false
	for requirement_type: String in upgrade.requirements:
		if not _requirement_satisfied(requirement_type, upgrade.requirements[requirement_type]):
			return false
	return true


## Resolves an upgrade purchase (Rule 4/5/6). Dual-gated: both can_purchase()
## AND materials sufficiency (Inventory.has_items_by_rarity(material_cost))
## must pass, or the action is rejected in full — zero ledger mutation, zero
## gold-debit emission, zero structure_upgraded emission.
##
## Material CONSUMPTION is deliberately NOT performed here — mirrors
## DefenseBuilding.resolve_tech_unlock()'s own identical, already-documented
## deferral (TD-defbuild-002) rather than inventing a Building-Upgrade-local
## resolution to a project-wide open question. Gold IS debited (the existing
## self-debit convention every gold-spending system in this project uses).
##
## Guarded by `_action_resolving` (mirrors DefenseBuilding's shared-flag
## pattern) so a stale double-confirm can never double-spend.
##
## Returns true on a successful resolve (gold debit + structure_upgraded
## emitted, ledger written). Returns false on any rejection, zero side effects.
func resolve_upgrade(upgrade_id: StringName) -> bool:
	if _action_resolving:
		return false
	_action_resolving = true
	if not can_purchase(upgrade_id):
		_action_resolving = false
		return false
	var upgrade: BuildingUpgradeResource = GGameDataRegistry.get_building_upgrade(upgrade_id)
	if upgrade == null:
		_action_resolving = false
		return false
	if not GInventory.has_items_by_rarity(upgrade.material_cost):
		_action_resolving = false
		return false
	GEventBus.resources_changed.emit(-upgrade.gold_cost, &"structure_upgrade")
	_purchased_ledger[upgrade_id] = true
	GEventBus.structure_upgraded.emit(String(upgrade.target_structure_id), String(upgrade_id))
	_action_resolving = false
	return true


# ---------------------------------------------------------------------------
# SaveRestorer interface (ADR-0003)
# ---------------------------------------------------------------------------

func get_save_key() -> String:
	return "building_upgrade"


func get_save_data() -> Dictionary:
	var ledger_data: Dictionary = {}
	for upgrade_id: StringName in _purchased_ledger:
		ledger_data[String(upgrade_id)] = _purchased_ledger[upgrade_id]
	return {"purchased_ledger": ledger_data}


## Returns false (not void!) on any malformed/missing data so
## SavePersistence's _restore_all_systems() falls back to reset_to_defaults()
## for this system — matches defense_building.gd's/crafting.gd's identical
## restore_save_data() idiom.
func restore_save_data(data: Dictionary) -> bool:
	var raw_ledger: Variant = data.get("purchased_ledger", null)
	if not (raw_ledger is Dictionary):
		return false

	var restored: Dictionary[StringName, bool] = {}
	for key: Variant in (raw_ledger as Dictionary):
		if not (key is String):
			return false
		var value: Variant = (raw_ledger as Dictionary)[key]
		if not (value is bool):
			return false
		restored[StringName(key as String)] = value as bool

	_purchased_ledger = restored
	return true


func reset_to_defaults() -> void:
	_purchased_ledger = {}
