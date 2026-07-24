class_name Inventory
extends Node

## Player item storage: fixed-size slot array of InventorySlot stacks (Epic 03, ADR-0016).
##
## GDD source: design/gdd/inventory.md
## ADR: docs/architecture/adr-0016-inventory-storage-model.md — "Two-tier data model"
## Story: production/epics/epic-03-core-economy/story-001-slot-stack-model.md (AC-1, AC-2,
## AC-3, AC-4, AC-18 — slot count, one-stack-per-slot invariant, unique-instance cap
## enforcement, stackable overflow, stat-rolled non-merge)
## Story: production/epics/epic-03-core-economy/story-002-tab-categorization.md (AC-7 —
## item_type -> fixed tab mapping)
## Story: production/epics/epic-03-core-economy/story-003-slot-expansion-cost-table.md
## (AC-8, AC-9, AC-10, AC-16 — tier-driven capacity growth, data-driven cost table,
## rarity gating, max-tier eligibility block)
##
## Registered as Autoload #9 in project.godot (GInventory), appended after
## MissionEconomy (#8) — resolved 2026-07-17 per ADR-0016's "Last Verified"
## amendment, which closed the original "Autoload or scene-persistent node,
## TBD at implementation time" open question: ADR-0021's cross-system
## direct-call surface (has_items()/has_room_for()/clear_damaged_flag()/
## apply_rune_to_item()) must be callable as a bare global from Crafting,
## Equipment Forge, Menagerie, and Defense Building, per ADR-0020 Criterion A.
## Also registers with SavePersistence like Hero does (src/core/hero/hero.gd),
## at restore_order=10 (Core layer, strictly below Hero's 30 — ADR-0016
## Decision, corrected 2026-07-13 per save-persistence.md's Formula 4 table).
##
## Two-tier model: this file owns only the runtime Array[InventorySlot]; static item
## data (ItemDefinitionResource — item_type, is_unique_instance, base_stats) is
## resolved by the caller and passed IN to add_unique_item()/add_stackable() as a
## parameter — Inventory itself never loads ItemDefinitionResource by path. The one
## exception is has_items() (Story 022, ADR-0021), which resolves a slot's item_id to
## its item_type via GGameDataRegistry.get_item_definition() (landed Story 022) —
## a read-only lookup through the established Autoload, not a path load, so most of
## this file remains dependency-injectable/unit-testable without any Autoload (control
## manifest, Global Rules), but has_items() specifically requires GGameDataRegistry to
## be live (see tests/unit/inventory/has_items_test.gd, which exercises it as such).
##
## Query API is deliberately narrow (get_slot_count(), get_slot_contents(),
## is_slot_empty()) rather than exposing the internal Array[InventorySlot] directly —
## this is ADR-0016's own stated Risk mitigation intent (Consequences > Risks: "a
## future system... might be tempted to read InventorySlot.stat_overrides directly").
##
## Unique-instance identity (instance_id) is the SOLE key for cap/merge logic (AC-18) —
## add_unique_item() always allocates a brand-new slot with a fresh instance_id; it
## never attempts to stack onto an existing occupied slot, so non-merging is
## structurally guaranteed rather than enforced by item_id/stat comparison (forbidden
## pattern, control manifest: "never key Inventory stacking... on item_id or
## stat-value equality").

const STARTING_SLOT_COUNT: int = 10  ## GDD Core Rule 1 — Inventory's own tuning constant
const STACK_CAP_STACKABLE: int = 99  ## GDD Core Rule 2 — Material / CraftedGood cap
const STACK_CAP_UNIQUE: int = 1      ## GDD Core Rule 2 — Equipment / stat-rolled Tower Component cap

## Fixed tab display order (GDD Core Rule 3, AC-5) — Equipment, Tower Components,
## Materials, Crafted Goods. Values are ItemDefinitionResource.item_type identifiers
## directly (1:1 mapping — "Tower Components" is a presentation-layer label for
## &"TowerComponent", not a distinct identifier; display labels are Story 007's
## concern). Not player-customizable at MVP (AC-6) — this list is intentionally
## the only place tab order is defined; no UI-side reordering API exists.
const TAB_ORDER: Array[StringName] = [&"Equipment", &"TowerComponent", &"Material", &"CraftedGood"]

## restore_order is NOT a readable const/property inspected by SavePersistence — it is
## a call-site argument to GSavePersistence.register(). Declared as a const here purely
## so the value used at the _ready() call site is documented and named, matching
## hero.gd's existing const-for-tuning-value style (see that file's RESTORE_ORDER).
const RESTORE_ORDER: int = 10

## Epic 08, Story 008 (ADR-0025): 5 fixed Hero equipment slots — a flagged
## origination (hero.md never fixes this number). Reserved at the LAST 5
## indices of the base 10-slot array (5-9), permanently locked, so
## _find_first_empty_slot() (generic pickups) naturally never lands there —
## no changes needed to that method. Slot-expansion (Story 003) only ever
## appends new slots after the current end, so these indices stay stable
## across expansion. At STARTING_SLOT_COUNT=10, this leaves exactly 5
## discretionary slots (indices 0-4) — satisfies inventory.md Rule 5a's
## ≥4-free floor with one slot of headroom (Guardrail).
const EQUIPMENT_SLOT_NAMES: Array[String] = ["weapon", "armor", "accessory_a", "accessory_b", "trinket"]
const EQUIPMENT_SLOT_INDEX: Dictionary[String, int] = {
	"weapon": 5, "armor": 6, "accessory_a": 7, "accessory_b": 8, "trinket": 9,
}
## accessory_a/accessory_b both accept the generic "accessory" category, no
## subtype restriction at Alpha (Story 008's own Implementation Notes).
const EQUIPMENT_SLOT_CATEGORY: Dictionary[String, String] = {
	"weapon": "weapon", "armor": "armor",
	"accessory_a": "accessory", "accessory_b": "accessory",
	"trinket": "trinket",
}

## `reason` payload value for GEventBus.item_pickup_rejected when a pickup
## cannot be stored because no slot/stack has room (Story 005, AC-15). The
## sole rejection reason this class currently produces — a caller-error
## rejection (null/wrong-type definition) is a programming error, not a
## fullness condition, and does NOT emit this signal at all (see
## add_unique_item()/add_stackable()'s own doc comments).
const REASON_INVENTORY_FULL: StringName = &"inventory_full"

## Fixed-size slot array. null = empty slot (well-defined empty result, not an error —
## see get_slot_contents()). Index-stable: consumption/removal only ever mutates a
## slot in place or nulls it out, never re-indexes the array (GDD AC-17, out of this
## story's scope but the invariant starts here).
var _slots: Array[InventorySlot] = []

## Monotonic unique-instance identity counter, persisted in get_save_data() so IDs
## remain stable and non-colliding across save/load (ADR-0016 Consequences > Negative).
var _next_instance_id: int = 0

## Number of slot-expansion tiers COMPLETED so far (Story 003). 0 = still at
## STARTING_SLOT_COUNT (10 slots), no expansion completed yet — tiers 1-5 map
## directly to SlotExpansionCostTable's row indices once completed (tier 1 complete
## = 16 slots, ..., tier 5 complete = 40 slots, max). Deliberately 0-based rather
## than starting at 1, so "current tier" and "next tier to buy" (_slot_tier + 1)
## never need an off-by-one correction at call sites.
var _slot_tier: int = 0


func _ready() -> void:
	reset_to_defaults()
	GSavePersistence.register(self, RESTORE_ORDER)


func _exit_tree() -> void:
	GSavePersistence.unregister(self)


# ---------------------------------------------------------------------------
# Query API (read-only accessors — narrow public surface, ADR-0016 Risk mitigation)
# ---------------------------------------------------------------------------

## Total slot count. 10 at fresh init (AC-1). Slot-expansion (Story 003) will grow
## this; this story never changes it after reset_to_defaults().
func get_slot_count() -> int:
	return _slots.size()


## ADR-0021 prerequisite fix (Story 004, Crafting Resolution Flow): a pure,
## read-only capacity check — does NOT mutate any state. Scoped to this
## project's actual call site (Crafting's tower_component pre-check,
## has_room_for(component_slot, 1)): tower components are always
## unique-instance items (STACK_CAP_UNIQUE=1), so each unit needs a fresh
## empty slot — existing stacks never absorb them, regardless of item_type.
## This method therefore checks "at least `quantity` empty slots exist,"
## which is exactly correct for the unique-instance case. It does NOT model
## the more complex stackable-overflow case (an existing partial stack
## absorbing part of `quantity`) — `item_type` alone cannot resolve to a
## specific item_id to check an existing stack against, and no current
## caller needs that path. Returns true trivially for quantity <= 0.
func has_room_for(_item_type: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return true
	var empty_count: int = 0
	for slot: InventorySlot in _slots:
		if slot == null:
			empty_count += 1
			if empty_count >= quantity:
				return true
	return false


## true if slot_index is empty (or out of range). Never errors on an out-of-range
## or empty index — see get_slot_contents()'s matching contract.
func is_slot_empty(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _slots.size():
		return true
	return _slots[slot_index] == null


## Returns exactly one item_id and one quantity per occupied slot (AC-2 — never a
## list, never multiple stacks in one slot, by construction: one InventorySlot per
## array index). Empty slot or out-of-range index returns {} — a well-defined empty
## result, not an error (QA Test Cases, AC-2 edge case).
##
## Usage:
##   var contents := inventory.get_slot_contents(0)
##   if not contents.is_empty():
##       print(contents["item_id"], contents["quantity"])
func get_slot_contents(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= _slots.size():
		return {}
	var slot: InventorySlot = _slots[slot_index]
	if slot == null:
		return {}
	var imbued_runes_strings: Array[String] = []
	for rune_id: StringName in slot.imbued_runes:
		imbued_runes_strings.append(String(rune_id))
	return {
		"item_id": String(slot.item_id),
		"quantity": slot.quantity,
		"instance_id": slot.instance_id,
		"stat_overrides": slot.stat_overrides.duplicate(true),
		"locked": slot.locked,
		"damaged": slot.damaged,
		"rune_slot_count": slot.rune_slot_count,
		"imbued_runes": imbued_runes_strings,
	}


## Story 005 prerequisite fix: Crafting's repair flow needs to read a
## specific unique instance's state (damaged, stat_overrides) without
## already knowing its slot_index — instance_id is this project's sole
## identity key (ADR-0016), so lookups by it must be possible. Returns the
## same shape as get_slot_contents(), or {} if instance_id is not found.
func get_slot_contents_by_instance_id(instance_id: int) -> Dictionary:
	for i: int in range(_slots.size()):
		var slot: InventorySlot = _slots[i]
		if slot != null and slot.instance_id == instance_id:
			return get_slot_contents(i)
	return {}


## Returns slot_name's current occupant, or {} if the slot is empty (no item
## equipped) or slot_name is unknown. Same shape as get_slot_contents().
func get_equipped_item(slot_name: String) -> Dictionary:
	if not EQUIPMENT_SLOT_INDEX.has(slot_name):
		return {}
	var idx: int = EQUIPMENT_SLOT_INDEX[slot_name]
	var slot: InventorySlot = _slots[idx]
	if slot.item_id == &"":
		return {}
	return get_slot_contents(idx)


## Equips definition into the named Hero equipment slot (weapon/armor/
## accessory_a/accessory_b/trinket) — AC-1/AC-2. Rejected (false, no state
## change) if slot_name is unknown, definition is null, definition's
## equipment_category doesn't match the slot's required category (accessory_a/
## accessory_b both accept "accessory"; weapon/armor/trinket require an exact
## match), or the slot already holds an item (unequip_item() first — no
## implicit swap). On success, emits equipment_slot_changed(slot, new_item_id,
## previous_item_id) — Inventory-owned (ADR-0025); this is the ONLY entry
## point that ever emits it. Equipment Forge never calls Hero directly (AC-3);
## Hero reads this passively via its own equipment_slot_changed subscription.
func equip_item(slot_name: String, definition: ItemDefinitionResource, stat_overrides: Dictionary[StringName, float] = {}) -> bool:
	if not EQUIPMENT_SLOT_INDEX.has(slot_name):
		return false
	if definition == null:
		return false
	if definition.equipment_category != EQUIPMENT_SLOT_CATEGORY[slot_name]:
		return false
	var idx: int = EQUIPMENT_SLOT_INDEX[slot_name]
	var slot: InventorySlot = _slots[idx]
	if slot.item_id != &"":
		return false
	slot.item_id = definition.item_id
	slot.instance_id = _next_instance_id
	_next_instance_id += 1
	slot.stat_overrides = stat_overrides.duplicate()
	slot.locked = true
	GEventBus.equipment_slot_changed.emit(slot_name, String(slot.item_id), "")
	return true


## Unequips whatever occupies slot_name, returning it to a bare locked
## placeholder (the slot itself is never removable — only its occupant).
## Rejected (false, no state change) if slot_name is unknown or already
## empty. Emits equipment_slot_changed(slot, "", previous_item_id) on
## success — the caller is responsible for placing the removed item back
## into a discretionary slot if desired (this method only clears the
## equipment slot; it does not itself return the item to general storage).
func unequip_item(slot_name: String) -> bool:
	if not EQUIPMENT_SLOT_INDEX.has(slot_name):
		return false
	var idx: int = EQUIPMENT_SLOT_INDEX[slot_name]
	var slot: InventorySlot = _slots[idx]
	if slot.item_id == &"":
		return false
	var previous_item_id: String = String(slot.item_id)
	slot.item_id = &""
	slot.instance_id = -1
	slot.stat_overrides = {}
	slot.locked = true
	GEventBus.equipment_slot_changed.emit(slot_name, "", previous_item_id)
	return true


## Resolves an item's tab membership from its item_type (AC-7, Story 002). Pure
## function — no Inventory instance state involved, computed at read time per
## ADR-0016 ("compute tab membership at read time... rather than caching a
## redundant copy on InventorySlot"). item_type is 1:1 with TAB_ORDER's
## identifiers, so this is an identity/membership check, not a translation
## table — kept as an explicit named function (not inlined at call sites) so a
## future UI story (Story 007) has one discoverable, testable entry point
## rather than re-deriving tab logic ad hoc.
##
## A malformed item_type (not one of the 4 known categories) is rejected here
## via push_error() and returns &"" — this is a defense-in-depth backstop only;
## the primary guarantee is ItemDefinitionResource.validate() failing loudly at
## load time (Story 001), which this function does not re-implement.
##
## Usage:
##   var tab := Inventory.get_tab_for_item_type(&"Equipment")  # -> &"Equipment"
static func get_tab_for_item_type(item_type: StringName) -> StringName:
	if not TAB_ORDER.has(item_type):
		push_error("[Inventory] get_tab_for_item_type: unknown item_type '%s' — not one of the 4 fixed tabs." % item_type)
		return &""
	return item_type


## Number of expansion tiers completed so far (Story 003). 0 = still at
## STARTING_SLOT_COUNT (10 slots); 5 = max tier (40 slots). get_slot_count() reflects
## the capacity this implies — this accessor exists separately because "which tier"
## and "how many slots" are both independently useful to callers (e.g. UI progress
## display vs. capacity checks).
##
## Usage:
##   var tier := inventory.get_current_slot_tier()  # -> 0 on a fresh Inventory
func get_current_slot_tier() -> int:
	return _slot_tier


## AC-16's standalone eligibility query: true if another expansion is possible AT
## ALL, independent of whether the player can currently afford it. This is what a
## UI should check to decide whether the expand button is even reachable/enabled —
## checkable before ever calling attempt_expand_slots() or resolving real Inventory
## material contents (QA Test Cases, AC-16 edge case: "must be a UI-disableable
## state... not merely a runtime rejection after the fact").
##
## Usage:
##   if inventory.can_expand_slots():
##       var cost := inventory.get_next_expansion_cost()
func can_expand_slots() -> bool:
	return _slot_tier < SlotExpansionCostTable.MAX_TIER


## The material cost of the NEXT expansion (tier _slot_tier + 1), or {} if already
## at max tier (AC-16) — same explicit-failure contract as
## SlotExpansionCostTable.get_cost_for_tier() itself (this simply delegates to it
## for _slot_tier + 1, which is naturally out of range at max tier, so no separate
## max-tier branch is needed here).
##
## Usage:
##   var cost := inventory.get_next_expansion_cost()
##   # cost == {"slots_after": 16, "common": 10, "uncommon": 0, "rare": 0} at tier 0
func get_next_expansion_cost() -> Dictionary:
	return SlotExpansionCostTable.get_cost_for_tier(_slot_tier + 1)


## Returns true iff every `item_type` key in `cost` has a matching total
## quantity at least the required amount, summed across ALL matching slots
## (inventory.md, Cross-System Query & Mutation APIs — "promoted from an
## '(anticipated)' placeholder to a fully specified method on 2026-07-17").
## Empty `cost` returns true trivially. Pure read-only check — never mutates
## `_slots`, never emits anything.
##
## Story 022 prerequisite fix: this method did not previously exist despite
## ADR-0021/ADR-0024 both describing it as "already a direct call" — see
## those ADRs' own text. Implementing it required a second prerequisite fix
## (GameDataRegistry.get_item_definition(), Story 022) because `_slots` only
## stores `item_id`/`quantity` (never `item_type` — that lives on
## ItemDefinitionResource, which Inventory itself never loads by path, per
## this file's header comment). Each occupied slot's `item_id` is resolved
## to its `ItemDefinitionResource.item_type` via `GGameDataRegistry` — a
## read-only lookup, not a load-by-path, so this does not violate that
## invariant. A slot whose `item_id` has no registered
## ItemDefinitionResource (unauthored content, or test-only data) is simply
## skipped, not treated as an error — same non-crashing-null convention
## every other GameDataRegistry consumer already follows.
##
## Known content gap this method does NOT resolve (see defense-building.md's
## own Open Questions table): `TechNodeResource`/`StructureResource`'s
## `material_costs` are documented as keyed by material RARITY
## ("Common"/"Uncommon"/"Rare"), which is a different vocabulary from
## `ItemDefinitionResource.item_type`'s fixed 4-category tab vocabulary
## (Equipment/TowerComponent/Material/CraftedGood) — no rarity field exists
## anywhere on `ItemDefinitionResource` today. This method implements
## `has_items()`'s own literal, generic contract (sum by `item_type`)
## correctly; reconciling the rarity-vs-item_type naming mismatch for
## Defense Building's real content is a separate, already-flagged,
## Inventory-owner gap this story does not invent a resolution for.
##
## Usage:
##   var cost: Dictionary = {&"Material": 40}
##   if inventory.has_items(cost):
##       ...
## Story 007 (Menagerie Lure) prerequisite fix: checks a SPECIFIC item_id's
## total stackable quantity — NOT item_type. has_items() sums by item_type,
## which would be wrong here: menagerie_lure shares item_type="Material"
## with other materials (common_scrap, iron_ore), so a has_items()-style
## check would incorrectly count them all together. Pure read-only.
func has_item_quantity(item_id: StringName, quantity: int) -> bool:
	if quantity <= 0:
		return true
	var total: int = 0
	for slot: InventorySlot in _slots:
		if slot != null and slot.instance_id == -1 and slot.item_id == item_id:
			total += slot.quantity
			if total >= quantity:
				return true
	return false


## Real inconsistency found and fixed during the epic-wide code review
## (Crafting/Menagerie/Defense Building epic, 2026-07-18): this method
## previously counted ALL matching slots toward availability, including
## locked (equipped/installed) and unique-instance slots — but
## consume_by_type() (the method that actually SPENDS what this method
## checks for) only ever draws from unlocked, stackable (instance_id == -1)
## slots. A recipe could therefore report craftable via has_items() yet
## under-consume via consume_by_type(), still producing output — a real
## quantity-conservation bug (low-probability today since recipe inputs are
## Material-type and only Equipment/TowerComponent ever get locked, but nothing
## in the type system prevented it). Fixed by filtering identically to
## consume_by_type(): only unlocked, stackable slots count.
func has_items(cost: Dictionary) -> bool:
	if cost.is_empty():
		return true

	var totals_by_item_type: Dictionary[StringName, int] = {}
	for slot: InventorySlot in _slots:
		if slot == null or slot.instance_id != -1 or slot.locked:
			continue
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(slot.item_id)
		if definition == null:
			continue
		totals_by_item_type[definition.item_type] = totals_by_item_type.get(definition.item_type, 0) + slot.quantity

	for item_type: Variant in cost:
		var required: int = cost[item_type] as int
		if totals_by_item_type.get(StringName(item_type), 0) < required:
			return false
	return true


## TD-craft-001/TD-defbuild-002 resolution (Sprint 6, S6-06b): rarity-keyed
## counterpart to has_items(), for recipe/tech/structure cost tables authored
## as "N of rarity tier X" (Formula 1/3) rather than "N of a specific
## item_type". Sums by ItemDefinitionResource.rarity instead of item_type —
## a genuinely separate aggregation axis, not a re-keying of the same data
## (a single rarity tier spans multiple item_types across Material-tab
## content). Same unlocked+stackable filtering as has_items().
##
## Usage:
##   var cost: Dictionary = {&"Common": 8, &"Uncommon": 4}
##   if inventory.has_items_by_rarity(cost):
##       ...
func has_items_by_rarity(cost: Dictionary) -> bool:
	if cost.is_empty():
		return true

	var totals_by_rarity: Dictionary[String, int] = {}
	for slot: InventorySlot in _slots:
		if slot == null or slot.instance_id != -1 or slot.locked:
			continue
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(slot.item_id)
		if definition == null or definition.rarity == "":
			continue
		totals_by_rarity[definition.rarity] = totals_by_rarity.get(definition.rarity, 0) + slot.quantity

	for rarity: Variant in cost:
		var required: int = cost[rarity] as int
		if totals_by_rarity.get(String(rarity), 0) < required:
			return false
	return true


# ---------------------------------------------------------------------------
# Mutation API
# ---------------------------------------------------------------------------

## Adds ONE freshly stat-rolled unique-instance item (Equipment / stat-rolled Tower
## Component, definition.is_unique_instance == true) to the next open slot. Always
## allocates a brand-new instance_id and a brand-new slot — never attempts to stack
## onto an existing occupied slot of the same item_id, so two stat-rolled instances
## of the same definition structurally never merge (AC-18), even with byte-identical
## stat_overrides.
##
## Returns the slot index the item was placed in, or -1 on rejection.
## Rejection has two distinct causes, only one of which is a real
## pickup-rejection event (Story 005, AC-15):
##   - definition is null, or not a unique-instance definition: a caller
##     error, not "inventory full" — logged via push_error(), no
##     GEventBus.item_pickup_rejected emission.
##   - no empty slot exists (_find_first_empty_slot() == -1): the genuine
##     mid-mission-pickup-full case — emits
##     GEventBus.item_pickup_rejected.emit(item_id, item_type, quantity,
##     REASON_INVENTORY_FULL) instead of item_added, no retry/queueing
##     (nothing here remembers the rejected pickup).
##
## On success, emits GEventBus.item_added.emit(item_id, item_type, quantity)
## synchronously (matches consume_stackable()'s existing direct-.emit()
## precedent, not call_deferred — no cascade concern here).
##
## Usage:
##   var def := ItemDefinitionResource.new()
##   def.item_id = &"iron_sword"
##   def.is_unique_instance = true
##   var slot_index := inventory.add_unique_item(def, {&"damage": 12.0})
##
## rune_slot_count (Epic 08, Story 010, ADR-0025): total rune slots to create
## the item with, all empty — 0 (default) for any non-Equipment-Forge caller.
## Backward-compatible additive parameter; every pre-existing call site is
## unaffected.
##
## reserved_instance_id (Epic 08, Story 014, ADR-0025): if != -1, the slot is
## assigned this exact instance_id instead of auto-generating one from
## _next_instance_id — used by EquipmentForge's Creature Sacrifice flow
## (Rule 19c/d), which must reserve the id via reserve_instance_id() BEFORE
## calling Menagerie.request_sacrifice() so creature_sacrificed's
## target_item_id matches the item this call subsequently creates. Default -1
## (auto-generate) leaves every pre-existing call site unaffected.
func add_unique_item(definition: ItemDefinitionResource, stat_overrides: Dictionary[StringName, float] = {}, rune_slot_count: int = 0, reserved_instance_id: int = -1) -> int:
	if definition == null:
		push_error("[Inventory] add_unique_item: definition must not be null.")
		return -1
	if not definition.is_unique_instance:
		push_error("[Inventory] add_unique_item: '%s' is not a unique-instance item — use add_stackable()." % definition.item_id)
		return -1

	var idx: int = _find_first_empty_slot()
	if idx == -1:
		GEventBus.item_pickup_rejected.emit(String(definition.item_id), String(definition.item_type), STACK_CAP_UNIQUE, REASON_INVENTORY_FULL)
		return -1

	var slot := InventorySlot.new()
	slot.item_id = definition.item_id
	if reserved_instance_id != -1:
		slot.instance_id = reserved_instance_id
	else:
		slot.instance_id = _next_instance_id
		_next_instance_id += 1
	slot.quantity = STACK_CAP_UNIQUE
	slot.stat_overrides = stat_overrides.duplicate(true)
	slot.rune_slot_count = rune_slot_count
	_slots[idx] = slot
	GEventBus.item_added.emit(String(slot.item_id), String(definition.item_type), STACK_CAP_UNIQUE)
	return idx


## Reserves and returns the next monotonic instance_id without creating a
## slot (Epic 08, Story 014, ADR-0025) — used by EquipmentForge's Creature
## Sacrifice flow (Rule 19c) to generate a prospective target_item_id BEFORE
## calling Menagerie.request_sacrifice(), so creature_sacrificed's
## target_item_id can be passed to add_unique_item()'s reserved_instance_id
## on success. If the Menagerie call is rejected, the reserved id is simply
## never assigned to a slot — a harmless gap in the id sequence, matching
## resolve_craft()'s own established caveat that partial-failure paths in
## this project trade a bookkeeping gap for correctness elsewhere.
func reserve_instance_id() -> int:
	var id: int = _next_instance_id
	_next_instance_id += 1
	return id


## Adds `quantity` units of a stackable item (Material / CraftedGood,
## definition.is_unique_instance == false) — first filling any existing,
## not-locked, same-item_id stack up to STACK_CAP_STACKABLE, then opening new
## slots (each capped at STACK_CAP_STACKABLE) for any remainder (AC-4: pickup is
## never blocked by a full stack — it overflows to the next open slot instead).
##
## Returns the leftover quantity that could NOT be placed (0 = fully placed).
##
## EventBus emission (Story 005, AC-15) is keyed off how much of `quantity`
## actually got placed vs. left over, not a simple all-or-nothing check —
## a nonzero leftover after a partial fill is still a real pickup-rejection
## event for the UNPLACED portion, so both signals can fire from a single
## call:
##   - placed > 0 (quantity - leftover): emits GEventBus.item_added.emit
##     (item_id, item_type, placed) for the portion that WAS stored.
##   - leftover > 0 (no open slot left for the remainder): emits
##     GEventBus.item_pickup_rejected.emit(item_id, item_type, leftover,
##     REASON_INVENTORY_FULL) for the portion that could NOT be stored.
##   - Both can fire together (a partial placement — some stacks filled,
##     inventory then ran out of room) — this is the natural generalization
##     of AC-15's literal "completely full" wording rather than a narrower
##     all-or-nothing check, since the same overflow logic already computes
##     both numbers in one pass. No queueing/retry of the leftover: the
##     caller must re-call add_stackable() itself if it wants to try again
##     later (e.g. after the player frees up space).
##
## definition null/wrong-type rejection (caller error, not "inventory full")
## is unchanged: push_error(), full `quantity` returned as leftover, NO
## EventBus emission of either signal.
func add_stackable(definition: ItemDefinitionResource, quantity: int) -> int:
	if definition == null:
		push_error("[Inventory] add_stackable: definition must not be null.")
		return quantity
	if definition.is_unique_instance:
		push_error("[Inventory] add_stackable: '%s' is a unique-instance item — use add_unique_item()." % definition.item_id)
		return quantity

	var remaining: int = quantity

	# Fill existing open stacks of the same item_id first.
	for slot: InventorySlot in _slots:
		if remaining <= 0:
			break
		if slot != null and slot.item_id == definition.item_id and slot.instance_id == -1 and not slot.locked:
			remaining -= _try_add_to_slot(slot, STACK_CAP_STACKABLE, remaining)

	# Overflow into new slots.
	while remaining > 0:
		var idx: int = _find_first_empty_slot()
		if idx == -1:
			break
		var new_slot := InventorySlot.new()
		new_slot.item_id = definition.item_id
		new_slot.instance_id = -1
		_slots[idx] = new_slot
		remaining -= _try_add_to_slot(new_slot, STACK_CAP_STACKABLE, remaining)

	var placed: int = quantity - remaining
	if placed > 0:
		GEventBus.item_added.emit(String(definition.item_id), String(definition.item_type), placed)
	if remaining > 0:
		GEventBus.item_pickup_rejected.emit(String(definition.item_id), String(definition.item_type), remaining, REASON_INVENTORY_FULL)

	return remaining


## Attempts to complete the NEXT slot-expansion tier (Story 003, AC-8/AC-9/AC-10/
## AC-16). `rarity_quantities_available` is an explicit, caller-supplied
## Dictionary[StringName, int] keyed by SlotExpansionCostTable's rarity keys
## (KEY_COMMON/KEY_UNCOMMON/KEY_RARE) — e.g. {&"common": 40, &"uncommon": 5}. This
## story deliberately does NOT resolve real Materials-tab contents by rarity
## internally: ItemDefinitionResource has no `rarity` field yet (no
## material-rarity vocabulary exists anywhere in the project — GDD
## design/gdd/inventory.md, Formulas section), so "how much Common/Uncommon/Rare
## material does the player actually own" is unanswerable from real Inventory
## slots today. The caller resolves and owns that real-spend accounting; this
## method only checks the supplied quantities and, on success, deducts NOTHING
## from `rarity_quantities_available` itself (it is a read-only affordability
## input, not a ledger this method mutates).
##
## Order of checks (AC-16 — the max-tier block happens BEFORE any affordability
## check, with zero side effects either way):
##   1. Not eligible (already at max tier) -> return false, no side effects.
##   2. Eligible but unaffordable (any required rarity's available qty is short)
##      -> return false, no side effects.
##   3. Eligible and affordable -> grow _slots (append-only, never disturbs
##      existing indices/contents — Story 001's index-stability invariant),
##      advance _slot_tier by exactly one, return true.
##
## No EventBus signal is emitted here. The GDD's Visual/Audio Requirements
## section implies slot-expansion completion should eventually be player-visible
## (a "Herald Gold flash" milestone moment), but Inventory does not emit any
## signals yet (Story 001's deliberate scope) and no such signal exists in
## event-bus.md's catalogue today — flagged as a gap for a future story, not
## silently added here.
##
## Usage:
##   if inventory.can_expand_slots():
##       var cost := inventory.get_next_expansion_cost()
##       var available: Dictionary[StringName, int] = {&"common": 50, &"uncommon": 10}
##       var expanded := inventory.attempt_expand_slots(available)
func attempt_expand_slots(rarity_quantities_available: Dictionary[StringName, int]) -> bool:
	if not can_expand_slots():
		return false

	var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(_slot_tier + 1)
	if not _can_afford_expansion(cost, rarity_quantities_available):
		return false

	var new_slot_count: int = cost[SlotExpansionCostTable.KEY_SLOTS_AFTER] as int
	while _slots.size() < new_slot_count:
		_slots.append(null)
	_slot_tier += 1
	return true


## Removes the item occupying `slot_index` entirely (Story 004, AC-11). Rejected
## — returns false, slot completely unchanged — if the index is out of range,
## the slot is already empty, or the slot is locked (equipped/installed —
## InventorySlot.locked, set via set_slot_locked()). This is the ONLY removal
## entry point Inventory exposes; there is no second path that could bypass the
## lock check (AC-11 edge case: "no path should bypass the lock").
##
## Matches Story 001's index-stability invariant (AC-17, see _slots' own doc
## comment): removal always nulls the slot in place, never re-indexes/compacts
## _slots.
##
## Usage:
##   if not inventory.remove_item(3):
##       print("could not remove — locked or already empty")
func remove_item(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _slots.size():
		push_error("[Inventory] remove_item: slot_index %d out of range." % slot_index)
		return false
	var slot: InventorySlot = _slots[slot_index]
	if slot == null:
		push_error("[Inventory] remove_item: slot_index %d is already empty." % slot_index)
		return false
	if slot.locked:
		push_error("[Inventory] remove_item: slot_index %d is locked (equipped/installed) — removal rejected." % slot_index)
		return false
	_slots[slot_index] = null
	return true


## Consumes `quantity_to_consume` units from a SINGLE stackable slot matching
## `definition.item_id` (Story 006, AC-17). Mutates `InventorySlot.quantity` in
## place at the existing array index — never re-indexes/compacts _slots
## (ADR-0016 Decision, GDD AC-17: index-stability is an explicit
## anti-requirement against "optimizing" this into a compaction pass).
##
## Single-slot only: if the same item_id happens to be split across two or
## more stacks (possible after add_stackable()'s overflow behavior, Story 001
## AC-4), only ONE matching stack is ever consumed from — this method does NOT
## aggregate/consume across multiple slots, even when the request exceeds one
## matching slot's quantity but two combined would cover it (in that case the
## call is rejected outright, same as any other insufficient-quantity case —
## see test_consume_stackable_two_unlocked_slots_not_aggregated_rejected).
## AC-17's own wording only describes a single-slot case ("a 99-quantity
## Material stack at slot N... slot N holds 59"); cross-slot consumption is a
## follow-up gap, not built speculatively here.
##
## Locked-slot skipping within that single-slot search: the search scans ALL
## slots matching item_id (not just the first one found) and skips any that
## are locked, picking the first UNLOCKED match that alone holds enough
## quantity to satisfy the request. This means a locked stack sitting at a
## lower index never blocks consumption from an eligible unlocked stack at a
## higher index — but it is still a single-slot decision: the search never
## sums quantity across two slots, locked or not, to decide eligibility.
##
## All-or-nothing: rejects the ENTIRE request (zero mutation, zero
## GEventBus.item_removed emission) if ANY of the following hold — this is a
## deliberately different idiom from add_stackable()'s partial-fulfillment
## "leftover" return: add_stackable() partially fills because pickup must
## never be blocked by a full stack (AC-4's explicit intent), but a partial
## consume would silently under-deliver a caller's recipe-cost assumption,
## which is worse than an explicit outright rejection:
##   - `definition` is null, or is a unique-instance definition (use
##     remove_item() for those instead — this method is stackables-only).
##   - `quantity_to_consume` <= 0.
##   - No stackable slot holding `definition.item_id` exists.
##   - The matching slot is locked (Story 004's equipped/installed invariant —
##     not textually required by AC-17, but consistent with remove_item()'s
##     established "a locked slot can't be mutated out from under an active
##     equip" principle).
##   - The matching slot's quantity is less than `quantity_to_consume`
##     (insufficient — rejected outright, no partial consumption of what IS
##     available).
##
## On success: decrements quantity in place, OR nulls the slot entirely if the
## decrement reaches exactly 0 (full depletion — same precedent remove_item()
## already established for a fully-removed slot: null, not "empty but
## present"). Emits GEventBus.item_removed.emit(item_id, item_type, quantity)
## synchronously (direct .emit(), not call_deferred — no cascade concern here,
## nothing else in this story chains off this emission).
##
## Returns the actual amount consumed (always == quantity_to_consume on
## success, since this method never partially fulfills), or 0 on any rejected
## call. 0 is an unambiguous failure sentinel because quantity_to_consume must
## be > 0 for any legitimate call.
##
## Usage:
##   var def := ItemDefinitionResource.new()
##   def.item_id = &"iron_ore"
##   def.item_type = &"Material"
##   def.is_unique_instance = false
##   var consumed := inventory.consume_stackable(def, 40)
##   # consumed == 40 on success; the matching slot's quantity drops by 40
##   # (or the slot becomes null if that was the last 40 in the stack).
func consume_stackable(definition: ItemDefinitionResource, quantity_to_consume: int) -> int:
	if definition == null:
		push_error("[Inventory] consume_stackable: definition must not be null.")
		return 0
	if definition.is_unique_instance:
		push_error("[Inventory] consume_stackable: '%s' is a unique-instance item — use remove_item()." % definition.item_id)
		return 0
	if quantity_to_consume <= 0:
		push_error("[Inventory] consume_stackable: quantity_to_consume must be > 0 (got %d)." % quantity_to_consume)
		return 0

	# Scan ALL slots matching item_id (not just the first) so a locked stack at
	# a lower index never blocks consumption from an eligible unlocked stack
	# at a higher index — still single-slot: never sums quantity across slots.
	var idx: int = -1
	var found_any_matching_item: bool = false
	for i: int in range(_slots.size()):
		var candidate: InventorySlot = _slots[i]
		if candidate == null or candidate.instance_id != -1 or candidate.item_id != definition.item_id:
			continue
		found_any_matching_item = true
		if candidate.locked:
			continue
		if candidate.quantity >= quantity_to_consume:
			idx = i
			break

	if idx == -1:
		if not found_any_matching_item:
			push_error("[Inventory] consume_stackable: no stackable slot found holding '%s'." % definition.item_id)
		else:
			push_error("[Inventory] consume_stackable: no unlocked slot holding '%s' has sufficient quantity for %d — rejected outright, no partial or cross-slot consumption." % [definition.item_id, quantity_to_consume])
		return 0

	var slot: InventorySlot = _slots[idx]
	slot.quantity -= quantity_to_consume
	if slot.quantity == 0:
		_slots[idx] = null

	GEventBus.item_removed.emit(String(definition.item_id), String(definition.item_type), quantity_to_consume)
	return quantity_to_consume


## ADR-0021 prerequisite fix (Story 004, Crafting Resolution Flow, Rule 8
## step c): consumes up to `quantity` units across ANY unlocked stackable
## slot whose ItemDefinitionResource.item_type matches `item_type` — unlike
## consume_stackable(), which targets one specific item_id, recipe inputs
## are item_type-keyed (TD-craft-001) and may need to draw from multiple
## distinct item_ids sharing that type to satisfy one requirement. Callers
## (Crafting) MUST call has_items() first to guarantee full satisfaction —
## this method consumes whatever is actually available up to `quantity` and
## returns the amount actually consumed (may be less than requested), it
## does not itself re-validate sufficiency. Emits item_removed once per
## affected slot (its own real item_id and the amount taken from it), not
## one aggregate call with no real item_id.
## `emit_events` defaults to true (Story 004's crafting-consumption
## behavior). Story 005 (Component Repair) passes false — AC-6 explicitly
## requires repair's Common-material payment to fire no item_removed at
## all, unlike a crafting resolution's material consumption.
func consume_by_type(item_type: String, quantity: int, emit_events: bool = true) -> int:
	if quantity <= 0:
		return 0
	var remaining: int = quantity
	for i: int in range(_slots.size()):
		if remaining <= 0:
			break
		var slot: InventorySlot = _slots[i]
		if slot == null or slot.instance_id != -1 or slot.locked:
			continue
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(slot.item_id)
		if definition == null or String(definition.item_type) != item_type:
			continue
		var take: int = mini(slot.quantity, remaining)
		slot.quantity -= take
		remaining -= take
		if emit_events:
			GEventBus.item_removed.emit(String(slot.item_id), item_type, take)
		if slot.quantity == 0:
			_slots[i] = null
	return quantity - remaining


## TD-craft-001/TD-defbuild-002 resolution (Sprint 6, S6-06b): rarity-keyed
## counterpart to consume_by_type() — mirrors it exactly (same unlocked+
## stackable filtering, same slot-clearing-at-zero behavior), draws from
## whichever item_type(s) share the given rarity, in slot order. Which
## specific item_type is drawn from first is deliberately unspecified/
## arbitrary (slot iteration order) — a rarity-keyed cost is "any N items of
## this rarity," not "N of a specific material," per Formula 1/3's own
## design intent.
func consume_by_rarity(rarity: String, quantity: int, emit_events: bool = true) -> int:
	if quantity <= 0:
		return 0
	var remaining: int = quantity
	for i: int in range(_slots.size()):
		if remaining <= 0:
			break
		var slot: InventorySlot = _slots[i]
		if slot == null or slot.instance_id != -1 or slot.locked:
			continue
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(slot.item_id)
		if definition == null or definition.rarity != rarity:
			continue
		var take: int = mini(slot.quantity, remaining)
		slot.quantity -= take
		remaining -= take
		if emit_events:
			GEventBus.item_removed.emit(String(slot.item_id), String(definition.item_type), take)
		if slot.quantity == 0:
			_slots[i] = null
	return quantity - remaining


## ADR-0021 prerequisite fix (Story 005, Component Repair): locates the slot
## by `instance_id` — NOT `item_id` as ADR-0021's own parameter naming
## suggests, since item_id identifies an item DEFINITION, not a specific
## copy; instance_id is this project's established sole key for unique-
## instance identity (control manifest, ADR-0016 Decision) and is the only
## way to target one specific damaged copy when multiple copies of the same
## item_id could exist. Sets damaged=false in place. Does NOT check `locked`
## (ADR-0021: in-place metadata mutations never check the equipped lock).
## Idempotent: returns true whether or not damaged was already false.
## Returns false only if instance_id is not found. Does not fire
## item_added/item_removed.
func clear_damaged_flag(instance_id: int) -> bool:
	for slot: InventorySlot in _slots:
		if slot != null and slot.instance_id == instance_id:
			slot.damaged = false
			return true
	return false


## Epic 08, Story 013 (ADR-0021/ADR-0025): imbues rune_id into the item
## identified by instance_id — NOT item_id as ADR-0021's own parameter naming
## suggests, same naming correction clear_damaged_flag() above already
## established for the identical ambiguity (item_id identifies a DEFINITION,
## not a specific copy; instance_id is this project's sole identity key for
## unique-instance items, control manifest/ADR-0016 Decision). Returns false
## — no mutation — if instance_id is not found or the target item's every
## rune slot is already filled (imbued_runes.size() >= rune_slot_count,
## AC-16(c)); the candidate rune is never consumed on a false return. Does
## NOT check `locked` (Forbidden rule — an explicit, architecturally-stated
## exemption to Rule 5, so a currently-equipped item can be imbued without an
## unequip->imbue->re-equip cycle, AC-16(a)). Does NOT fire item_added/
## item_removed (Guardrail) — this is an in-place metadata mutation, not a
## removal/recreation.
func apply_rune_to_item(instance_id: int, rune_id: String, _stat_delta: Dictionary) -> bool:
	for slot: InventorySlot in _slots:
		if slot == null or slot.instance_id != instance_id:
			continue
		if slot.imbued_runes.size() >= slot.rune_slot_count:
			return false
		slot.imbued_runes.append(StringName(rune_id))
		return true
	return false


## Sets or clears the equipped/installed lock on `slot_index` (Story 004,
## ADR-0016 Decision: Inventory owns this flag itself — it is set/cleared by
## whichever caller reacts to a real equip/unequip event; Hero/Tower's EventBus
## wiring in a later story calls this, Inventory does not query Hero/Tower live,
## per the control manifest's no-direct-runtime-Node-reference rule). Returns
## false — no mutation — for an out-of-range or currently-empty slot index;
## true on success.
##
## A locked slot is never null, so it already structurally counts toward
## capacity via _find_first_empty_slot()'s existing null-only check (AC-12) —
## no separate capacity-check code path was needed for that half of this story.
##
## Usage:
##   inventory.set_slot_locked(2, true)   # on equip
##   inventory.set_slot_locked(2, false)  # on unequip
func set_slot_locked(slot_index: int, locked: bool) -> bool:
	if slot_index < 0 or slot_index >= _slots.size():
		return false
	var slot: InventorySlot = _slots[slot_index]
	if slot == null:
		return false
	slot.locked = locked
	return true


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


## True if every rarity the cost row requires (value > 0) is met or exceeded by
## `available`. A rarity with cost 0 (not yet gated at this tier, GDD's "—" cells)
## is never checked, regardless of what `available` contains for it.
func _can_afford_expansion(cost: Dictionary, available: Dictionary[StringName, int]) -> bool:
	for key: StringName in [SlotExpansionCostTable.KEY_COMMON, SlotExpansionCostTable.KEY_UNCOMMON, SlotExpansionCostTable.KEY_RARE]:
		var required: int = cost.get(key, 0) as int
		if required <= 0:
			continue
		var have: int = available.get(key, 0)
		if have < required:
			return false
	return true

## Adds up to `amount` units to `slot`, never exceeding `cap`. Returns the amount
## actually added (0 if the slot is already at/over cap — rejected, not silently
## ignored: callers observe this via the return value). This is the ONLY place
## quantity is ever incremented on an existing slot; it never inspects item_id or
## instance_id itself — callers (add_stackable()) are responsible for only ever
## targeting a slot they've already confirmed is a valid merge target. Unique-instance
## slots are never passed here except at creation (quantity 0 -> 1), so a would-be
## "second unit into an already-occupied cap=1 slot" call correctly returns 0.
func _try_add_to_slot(slot: InventorySlot, cap: int, amount: int) -> int:
	var space: int = cap - slot.quantity
	if space <= 0:
		return 0
	var added: int = mini(space, amount)
	slot.quantity += added
	return added


## First null (empty) index in _slots, or -1 if full.
func _find_first_empty_slot() -> int:
	for i: int in range(_slots.size()):
		if _slots[i] == null:
			return i
	return -1


# ---------------------------------------------------------------------------
# SaveRestorer interface (ADR-0003, ADR-0016)
# ---------------------------------------------------------------------------

## ADR-0003 SaveRestorer interface (per save_persistence.gd's own doc comment).
## Called by GSavePersistence._collect_save_data() to key this system's entry in
## the master save Dictionary.
func get_save_key() -> String:
	return "inventory"


## ADR-0003 primitive-only rule: no Resource, no StringName as a Dictionary key or
## value — item_id and stat_overrides keys are converted to String explicitly here,
## matching hero.gd's String(_primary_class) / proximity_data idiom. Serializes the
## slot array (each InventorySlot -> flat Dictionary, or {} for an empty slot) plus
## _next_instance_id (ADR-0016 Consequences > Negative: must itself be persisted so
## unique-instance IDs stay stable and non-colliding across save/load) plus
## _slot_tier (Story 003 — must be persisted so a restored save doesn't silently
## revert an expanded Inventory back to 10 slots).
func get_save_data() -> Dictionary:
	var slot_data: Array = []
	for slot: InventorySlot in _slots:
		if slot == null:
			slot_data.append({})
			continue
		var overrides_data: Dictionary = {}
		for key: StringName in slot.stat_overrides:
			overrides_data[String(key)] = slot.stat_overrides[key]
		var imbued_runes_data: Array = []
		for rune_id: StringName in slot.imbued_runes:
			imbued_runes_data.append(String(rune_id))
		slot_data.append({
			"item_id": String(slot.item_id),
			"quantity": slot.quantity,
			"instance_id": slot.instance_id,
			"stat_overrides": overrides_data,
			"locked": slot.locked,
			"damaged": slot.damaged,
			"rune_slot_count": slot.rune_slot_count,
			"imbued_runes": imbued_runes_data,
		})
	return {
		"slots": slot_data,
		"next_instance_id": _next_instance_id,
		"slot_tier": _slot_tier,
	}


## Restores all Story-001/Story-003 persisted fields. Returns false (not void!) on
## any malformed/missing data so SavePersistence's _restore_all_systems() falls back
## to reset_to_defaults() for this system (matching hero.gd's restore_save_data()
## idiom). Validates presence and type of every expected key — for every slot entry
## too — before mutating any field, so a rejected payload has no partial-restore
## side effects.
##
## Story 003 addition: the expected slot-array size is no longer the fixed
## STARTING_SLOT_COUNT — it is derived from the restored `slot_tier` (0 = 10 slots,
## 1-5 = SlotExpansionCostTable's slots_after for that tier). A payload whose
## `slots` size doesn't match its own claimed `slot_tier` is rejected as malformed,
## same as any other internally-inconsistent save data.
func restore_save_data(data: Dictionary) -> bool:
	if not (data.has("slots") and data.has("next_instance_id") and data.has("slot_tier")):
		return false

	var slot_tier_raw: Variant = data["slot_tier"]
	if not (slot_tier_raw is int):
		return false
	var slot_tier: int = slot_tier_raw as int
	if slot_tier < 0 or slot_tier > SlotExpansionCostTable.MAX_TIER:
		return false

	var expected_slot_count: int = _expected_slot_capacity_for_tier(slot_tier)
	if expected_slot_count == -1:
		return false

	var slots_raw: Variant = data["slots"]
	if not (slots_raw is Array):
		return false
	var slots_array: Array = slots_raw as Array
	if slots_array.size() != expected_slot_count:
		return false

	var next_id_raw: Variant = data["next_instance_id"]
	if not (next_id_raw is int):
		return false

	var restored_slots: Array[InventorySlot] = []
	restored_slots.resize(expected_slot_count)

	for i: int in range(expected_slot_count):
		var entry_raw: Variant = slots_array[i]
		if not (entry_raw is Dictionary):
			return false
		var entry: Dictionary = entry_raw as Dictionary

		if entry.is_empty():
			restored_slots[i] = null
			continue

		if not (entry.has("item_id") and entry.has("quantity") and entry.has("instance_id")
				and entry.has("stat_overrides") and entry.has("locked")):
			return false

		var item_id_raw: Variant = entry["item_id"]
		var quantity_raw: Variant = entry["quantity"]
		var instance_id_raw: Variant = entry["instance_id"]
		var overrides_raw: Variant = entry["stat_overrides"]
		var locked_raw: Variant = entry["locked"]
		# "damaged" is a newer field (Story 005, ADR-0021) — defaults to false
		# for saves written before it existed, rather than rejecting the
		# whole payload as malformed for missing a field that didn't exist yet.
		var damaged_raw: Variant = entry.get("damaged", false)
		# "rune_slot_count"/"imbued_runes" (Epic 08, Story 010, ADR-0025) —
		# same backward-compat default rationale as "damaged" above.
		var rune_slot_count_raw: Variant = entry.get("rune_slot_count", 0)
		var imbued_runes_raw: Variant = entry.get("imbued_runes", [])

		if not (item_id_raw is String):
			return false
		if not (quantity_raw is int):
			return false
		if not (instance_id_raw is int):
			return false
		if not (overrides_raw is Dictionary):
			return false
		if not (locked_raw is bool):
			return false
		if not (damaged_raw is bool):
			return false
		if not (rune_slot_count_raw is int):
			return false
		if not (imbued_runes_raw is Array):
			return false

		var restored_overrides: Dictionary[StringName, float] = {}
		for key: Variant in (overrides_raw as Dictionary):
			if not (key is String):
				return false
			var value: Variant = (overrides_raw as Dictionary)[key]
			if not (value is float or value is int):
				return false
			restored_overrides[StringName(key as String)] = float(value)

		var restored_imbued_runes: Array[StringName] = []
		for rune_id: Variant in (imbued_runes_raw as Array):
			if not (rune_id is String):
				return false
			restored_imbued_runes.append(StringName(rune_id as String))

		var slot := InventorySlot.new()
		slot.item_id = StringName(item_id_raw as String)
		slot.quantity = quantity_raw as int
		slot.instance_id = instance_id_raw as int
		slot.stat_overrides = restored_overrides
		slot.locked = locked_raw as bool
		slot.damaged = damaged_raw as bool
		slot.rune_slot_count = rune_slot_count_raw as int
		slot.imbued_runes = restored_imbued_runes
		restored_slots[i] = slot

	_slots = restored_slots
	_next_instance_id = next_id_raw as int
	_slot_tier = slot_tier
	return true


## Clears all Story-001/Story-003 persisted fields to their starting values: 10
## empty slots, instance-id counter reset to 0, slot tier reset to 0 (un-expanded).
## Called by SavePersistence when no save data exists for this key, or when
## restore_save_data() rejects malformed data. Also called directly from _ready()
## (matching hero.gd's precedent) so an Inventory that never has
## GSavePersistence.load_slot() called on it (a quick mission start, or a test that
## add_child()s it) still has valid empty-slot state rather than field defaults.
## Idempotent — safe to call more than once in the same session without
## double-allocating slots (QA Test Cases, AC-1 edge case): it always reassigns
## _slots to a fresh 10-null array rather than appending.
func reset_to_defaults() -> void:
	_slots = []
	_slots.resize(STARTING_SLOT_COUNT)
	for i: int in range(STARTING_SLOT_COUNT):
		_slots[i] = null
	for slot_name: String in EQUIPMENT_SLOT_NAMES:
		var placeholder := InventorySlot.new()
		placeholder.locked = true
		_slots[EQUIPMENT_SLOT_INDEX[slot_name]] = placeholder
	_next_instance_id = 0
	_slot_tier = 0


## Expected slot-array size for a given completed-tier count (Story 003). 0 ->
## STARTING_SLOT_COUNT (the un-expanded base); 1-5 -> SlotExpansionCostTable's
## slots_after for that tier. Returns -1 for any tier outside [0, MAX_TIER] — a
## deliberately impossible sentinel size (never a valid slots_array.size()), so
## callers (restore_save_data()) can treat it as an unambiguous validation failure.
func _expected_slot_capacity_for_tier(tier: int) -> int:
	if tier == 0:
		return STARTING_SLOT_COUNT
	var row: Dictionary = SlotExpansionCostTable.get_cost_for_tier(tier)
	if row.is_empty():
		return -1
	return row[SlotExpansionCostTable.KEY_SLOTS_AFTER] as int
