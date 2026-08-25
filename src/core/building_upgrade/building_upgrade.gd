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

## Story 004 (TR-buildupgrade-004, Rule 6a): per-upgrade_id last-known
## can_purchase() result, used to detect the VISIBLE_LOCKED -> PURCHASABLE
## edge (AC-8/AC-9b). Not persisted (Save & Persistence) -- purely an
## in-memory edge-detection cursor, re-derived fresh (via _seed_
## purchasable_state()) every time this system loads, same "no UI/derived
## state saved" convention Sanctuary UI's own Connection Badge counters use.
var _purchasable_state: Dictionary[StringName, bool] = {}


func _ready() -> void:
	add_to_group(GROUP_NAME)
	GSavePersistence.register(self, RESTORE_ORDER)
	# Baseline pass, no emission: establishes each upgrade_id's current
	# can_purchase() result BEFORE any live subscription below can compare
	# against it, so the first real EventBus event this instance observes
	# only reports a genuine edge, never "was already PURCHASABLE at boot."
	_seed_purchasable_state()
	GEventBus.sanctuary_structure_built.connect(_on_sanctuary_structure_built)
	GEventBus.tech_unlocked.connect(_on_tech_unlocked)
	GEventBus.item_added.connect(_on_item_added)
	GEventBus.item_removed.connect(_on_item_removed)
	GEventBus.creature_acquired.connect(_on_creature_acquired)
	GEventBus.creature_sacrificed.connect(_on_creature_sacrificed)


func _exit_tree() -> void:
	GSavePersistence.unregister(self)
	GEventBus.sanctuary_structure_built.disconnect(_on_sanctuary_structure_built)
	GEventBus.tech_unlocked.disconnect(_on_tech_unlocked)
	GEventBus.item_added.disconnect(_on_item_added)
	GEventBus.item_removed.disconnect(_on_item_removed)
	GEventBus.creature_acquired.disconnect(_on_creature_acquired)
	GEventBus.creature_sacrificed.disconnect(_on_creature_sacrificed)


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
## RESOLVED 2026-08-12 (ADR-0035): Tarot is now a real Autoload (GTarot),
## reachable from any Sanctuary UI context including this system's own
## screen — the previously-documented gap (Tarot only reachable while
## TarotDeckUI.tscn was mounted, failing every "tarot" requirement closed
## from Sanctuary) is closed. This read is now a genuine ADR-0020
## Criterion A direct-Autoload-call instance, matching the building/
## equipment/creature branches below.
func _requirement_satisfied(requirement_type: String, identifier: StringName) -> bool:
	match requirement_type:
		"building":
			return GDefenseBuilding.is_structure_built(identifier)
		"equipment":
			return GInventory.has_specific_item(identifier)
		"tarot":
			return GTarot.is_card_unlocked(identifier)
		"creature":
			return GMenagerie.has_creature_species(identifier)
		_:
			return false


## Read-only per-requirement breakdown (Story 003, TR-buildupgrade-004,
## Rule 2a/AC-6/AC-6b) -- exposes, for VISIBLE_LOCKED per-requirement chip
## rendering, the exact same per-entry satisfied state can_purchase() already
## computes internally via _requirement_satisfied(). Purely additive and
## read-only: does not touch can_purchase()/resolve_upgrade()'s own logic in
## any way. Returns an empty Dictionary for an unknown upgrade_id (mirrors
## is_visible()'s/can_purchase()'s own "unknown id fails closed" convention).
func get_requirement_status(upgrade_id: StringName) -> Dictionary[String, bool]:
	var upgrade: BuildingUpgradeResource = GGameDataRegistry.get_building_upgrade(upgrade_id)
	var status: Dictionary[String, bool] = {}
	if upgrade == null:
		return status
	for requirement_type: String in upgrade.requirements:
		status[requirement_type] = _requirement_satisfied(requirement_type, upgrade.requirements[requirement_type])
	return status


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
## Material CONSUMPTION now runs too (TD-defbuild-002, fully resolved
## 2026-08-25): a loop over material_cost calling Inventory.consume_by_rarity()
## per entry, mirroring DefenseBuilding.resolve_tech_unlock()'s identical fix
## and Crafting's own _consume_recipe_inputs() — the same established
## project-wide pattern for "spend a rarity-keyed cost," not a
## Building-Upgrade-local invention. Gold IS also debited (the existing
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
	for rarity: StringName in upgrade.material_cost:
		GInventory.consume_by_rarity(String(rarity), upgrade.material_cost[rarity])
	_purchased_ledger[upgrade_id] = true
	_purchasable_state[upgrade_id] = false  ## keeps the edge-detection cursor in sync; can_purchase() now always false (PURCHASED)
	GEventBus.structure_upgraded.emit(String(upgrade.target_structure_id), String(upgrade_id))
	# Real gap found during /code-review (godot-specialist): a chained
	# upgrade B whose prerequisite_upgrade_id is THIS upgrade_id (Rule 1/
	# AC-7) can become newly PURCHASABLE the instant this purchase resolves
	# -- without this call, that transition would only ever be detected if
	# some unrelated EventBus trigger happened to fire afterward, silently
	# undermining AC-9b's re-armable notification guarantee for prerequisite
	# chains specifically. No _action_resolving re-entry risk: this call is
	# read-only (can_purchase() checks), never itself calls resolve_upgrade().
	_reevaluate_purchasable_state()
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


# ---------------------------------------------------------------------------
# PURCHASABLE-transition detection (Story 004, TR-buildupgrade-004, Rule 6a)
# ---------------------------------------------------------------------------

## Establishes each loaded upgrade's current can_purchase() result as the
## edge-detection baseline, called once from _ready() BEFORE any live
## subscription connects -- so the first real EventBus event this instance
## observes only reports a genuine VISIBLE_LOCKED -> PURCHASABLE edge, never
## "was already PURCHASABLE at boot."
func _seed_purchasable_state() -> void:
	var all_upgrades: Dictionary[StringName, BuildingUpgradeResource] = GGameDataRegistry.get_all_building_upgrades()
	for upgrade_id: StringName in all_upgrades:
		_purchasable_state[upgrade_id] = can_purchase(upgrade_id)


## Re-evaluates can_purchase() for every loaded upgrade and emits
## building_upgrade_became_purchasable(upgrade_id) exactly on the
## false -> true edge (AC-8) -- never while already PURCHASABLE, and never
## for an already-PURCHASED upgrade (can_purchase() itself already returns
## false for those, so no separate check is needed here). Re-armable: if an
## upgrade later reverts to VISIBLE_LOCKED (Rule 4's live re-evaluation) and
## becomes PURCHASABLE again, this fires again for the same upgrade_id
## (AC-9b) -- _purchasable_state is overwritten every call, never a
## one-shot-forever ledger.
func _reevaluate_purchasable_state() -> void:
	var all_upgrades: Dictionary[StringName, BuildingUpgradeResource] = GGameDataRegistry.get_all_building_upgrades()
	for upgrade_id: StringName in all_upgrades:
		var now_purchasable: bool = can_purchase(upgrade_id)
		var was_purchasable: bool = _purchasable_state.get(upgrade_id, false)
		_purchasable_state[upgrade_id] = now_purchasable
		if now_purchasable and not was_purchasable:
			GEventBus.building_upgrade_became_purchasable.emit(String(upgrade_id))


func _on_sanctuary_structure_built(_structure_id: String, _structure_type: String) -> void:
	_reevaluate_purchasable_state()


## Not a direct requirement trigger today (_requirement_satisfied() has no
## "tech" branch) -- kept because Tarot's own is_card_unlocked() (the
## "tarot" branch's dependency) reads GDefenseBuilding.is_tech_unlocked()
## internally (tarot.md Rule 1's unlock_tech_id field, wired 2026-08-12).
## Currently a no-op in practice since no live Tarot instance is reachable
## from Sanctuary UI (BUG-0001) -- kept rather than dropped so a future
## Tarot-reachability fix doesn't silently reopen this exact "transition
## never detected" gap for tarot-gated upgrades.
func _on_tech_unlocked(_tech_id: String, _tech_category: String) -> void:
	_reevaluate_purchasable_state()


func _on_item_added(_item_id: String, _item_type: String, _quantity: int) -> void:
	_reevaluate_purchasable_state()


func _on_item_removed(_item_id: String, _item_type: String, _quantity: int) -> void:
	_reevaluate_purchasable_state()


func _on_creature_acquired(_creature_id: int, _species: String) -> void:
	_reevaluate_purchasable_state()


func _on_creature_sacrificed(_creature_id: int, _target_item_id: int) -> void:
	_reevaluate_purchasable_state()
