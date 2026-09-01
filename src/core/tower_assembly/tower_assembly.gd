class_name TowerAssembly
extends Node

## Tower Assembly's assembled-blueprint container (player-requested, 2026-08-11).
##
## GDD source: design/quick-specs/tower-assembly-2026-08-11.md.
## Deliberately scene-instanced, NOT an Autoload — mirrors Crafting's/
## EquipmentForge's/BuildingUpgrade's own ADR-0023/ADR-0025 precedent (this
## system, like them, is Sanctuary-only). Its one real instance lives as a
## shell-owned child of SanctuaryUI.tscn, discovered via the
## "tower_assembly" group.
##
## Bridges the real, pre-existing gap the quick-spec's own Motivation
## documents: Crafting's tower_component recipes produce Inventory items
## with a component_resource_path (ItemDefinitionResource, 2026-08-11), but
## nothing previously read that path back into a real, placeable
## TowerBlueprintData. This system is that missing read.

const RESTORE_ORDER: int = 36  ## matches save-persistence.md's table — independent at restore time, after Encyclopedia (35)
const GROUP_NAME: StringName = &"tower_assembly"
const BASE_ASSEMBLY_COST: int = 8  ## safe range 5-15, per the quick-spec's Formula 1

## tower_id -> the 4 source component_resource_path strings used to build it
## (foundation/weapon/focus/power keys) — save/restore's own reconstruction
## record; the live TowerBlueprintData itself is never directly serialized.
var _assembly_sources: Dictionary[StringName, Dictionary] = {}
var _assembly_counter: int = 0


func _ready() -> void:
	add_to_group(GROUP_NAME)
	GSavePersistence.register(self, RESTORE_ORDER)


func _exit_tree() -> void:
	GSavePersistence.unregister(self)


## Resolves instance_id to its real component Resource (re-loaded fresh from
## its ItemDefinitionResource.component_resource_path, per-call — the
## returned Resource is a live cache reference, callers must duplicate_deep()
## before mutating). Returns null for any invalid state: unknown/empty slot,
## quantity <= 0 (same transient-state guard inventory_screen.gd's own
## _apply_slot_visual() fix established 2026-08-10), damaged, wrong
## item_type, or a missing/empty component_resource_path.
func _resolve_component_resource(instance_id: int) -> Resource:
	var contents: Dictionary = GInventory.get_slot_contents_by_instance_id(instance_id)
	if contents.is_empty():
		return null
	if (contents.get("quantity", 0) as int) <= 0:
		return null
	if contents.get("damaged", false):
		return null
	var item_id: String = contents["item_id"] as String
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))
	if definition == null or definition.item_type != &"TowerComponent":
		return null
	if definition.component_resource_path == "":
		return null
	return ResourceLoader.load(definition.component_resource_path)


## Finds the slot index currently holding instance_id — Inventory.remove_item()
## takes a slot index, not an instance_id, and no public instance_id-to-index
## lookup exists (a narrow, single-call-site need; not worth a new Inventory
## API for, unlike has_specific_item()). Returns -1 if not found.
func _find_slot_index(instance_id: int) -> int:
	for i: int in range(GInventory.get_slot_count()):
		var contents: Dictionary = GInventory.get_slot_contents(i)
		if (contents.get("instance_id", -1) as int) == instance_id:
			return i
	return -1


func _consume_component_instance(instance_id: int) -> void:
	var slot_index: int = _find_slot_index(instance_id)
	if slot_index == -1:
		return
	var contents: Dictionary = GInventory.get_slot_contents(slot_index)
	var item_id: String = contents["item_id"] as String
	GInventory.remove_item(slot_index)
	# remove_item() does not emit item_removed itself — matches
	# consume_by_type()'s own event-emission responsibility, per this
	# system's own quick-spec.
	GEventBus.item_removed.emit(item_id, "TowerComponent", 1)


## Formula 1 (quick-spec): simplified since every assembled tower always has
## all 4 slots filled by this method's own precondition.
func _compute_placement_cost(foundation: FoundationComponent) -> int:
	return roundi(BASE_ASSEMBLY_COST * foundation.tier_cost_factor * 1.75)


## Tier-gated required-slot count (new 2026-09-01, player-requested — "the
## number of slots required would start at 3 and go up the higher the tier
## of the tower"). Foundation+Weapon are always required (unconditional, as
## before); Shaft/Top/Focus/Power phase in one at a time as `tier` (read from
## the SUPPLIED Foundation instance, before any other slot is checked) rises.
## Any slot NOT required at a given tier may still be supplied — this only
## gates what happens when a slot is left unsupplied (instance_id == -1):
## required-and-missing rejects the whole assembly; optional-and-missing
## substitutes a fresh, inert default component instead of demanding one
## (mirrors TowerBlueprintData's own null-Shaft/Top inert convention).
const REQUIRED_AT_TIER: Dictionary[String, int] = {
	"shaft": 1, "top": 2, "focus": 3, "power": 4,
}


func _is_required_at_tier(slot: String, tier: int) -> bool:
	return tier >= REQUIRED_AT_TIER.get(slot, 1)


## Combines 3-6 owned crafted tower components (Foundation+Weapon always
## required; Shaft/Top/Focus/Power phase in by tier, see REQUIRED_AT_TIER)
## into a new, placeable TowerBlueprintData. Re-validates every supplied
## input before any mutation (matches Crafting's own stale-UI defense) — on
## any failure, returns &"" with zero side effects: nothing consumed,
## nothing registered, no event. `*_instance_id` defaults of -1 mean "not
## supplied" — legal only for a slot this tower's tier doesn't require yet.
##
## On success: duplicate_deep()'s each resolved component (ADR-0008's own
## deep-copy policy — this blueprint's components must be independent of
## whatever future assembly reuses the same source component_resource_path),
## consumes only the ACTUALLY-SUPPLIED source items (an auto-defaulted
## optional slot consumes nothing — there was no owned item to consume),
## registers the new blueprint via GameDataRegistry.register_dynamic_tower_blueprint(),
## and emits tower_assembled. Returns the new tower_id, or &"" on rejection.
func assemble_tower(foundation_instance_id: int, weapon_instance_id: int, focus_instance_id: int, power_instance_id: int,
		display_name: String, shaft_instance_id: int = -1, top_instance_id: int = -1) -> StringName:
	var foundation: FoundationComponent = _resolve_component_resource(foundation_instance_id) as FoundationComponent
	var weapon: WeaponComponent = _resolve_component_resource(weapon_instance_id) as WeaponComponent
	if foundation == null or weapon == null:
		return &""
	var tier: int = foundation.tier

	var focus: FocusComponent = _resolve_optional_component(focus_instance_id, "focus", tier, FocusComponent.new()) as FocusComponent
	var power: PowerComponent = _resolve_optional_component(power_instance_id, "power", tier, PowerComponent.new()) as PowerComponent
	var shaft: ShaftComponent = _resolve_optional_component(shaft_instance_id, "shaft", tier, ShaftComponent.new()) as ShaftComponent
	var top: TopComponent = _resolve_optional_component(top_instance_id, "top", tier, TopComponent.new()) as TopComponent
	if focus == null or power == null or shaft == null or top == null:
		return &""

	_assembly_counter += 1
	var tower_id := StringName("assembled_%d" % _assembly_counter)

	var blueprint := TowerBlueprintData.new()
	blueprint.tower_id = tower_id
	blueprint.display_name = display_name
	blueprint.foundation = foundation.duplicate_deep()
	blueprint.weapon = weapon.duplicate_deep()
	blueprint.focus = focus.duplicate_deep()
	blueprint.power = power.duplicate_deep()
	blueprint.shaft = shaft.duplicate_deep()
	blueprint.top = top.duplicate_deep()
	blueprint.placement_cost = _compute_placement_cost(blueprint.foundation)

	# Captured BEFORE consumption — resource_path is set automatically by
	# ResourceLoader.load() on any disk-backed Resource; simpler and safer
	# than re-deriving it from Inventory after the source items are gone.
	# An auto-defaulted optional slot (in-memory ShaftComponent.new(), never
	# loaded from disk) has an EMPTY resource_path — restore_save_data()
	# treats an empty path as "re-default this slot," never attempts to load it.
	var sources: Dictionary = {
		"foundation_path": foundation.resource_path,
		"weapon_path": weapon.resource_path,
		"focus_path": focus.resource_path,
		"power_path": power.resource_path,
		"shaft_path": shaft.resource_path,
		"top_path": top.resource_path,
		"display_name": display_name,
		"placement_cost": blueprint.placement_cost,
	}

	_consume_component_instance(foundation_instance_id)
	_consume_component_instance(weapon_instance_id)
	if focus_instance_id != -1:
		_consume_component_instance(focus_instance_id)
	if power_instance_id != -1:
		_consume_component_instance(power_instance_id)
	if shaft_instance_id != -1:
		_consume_component_instance(shaft_instance_id)
	if top_instance_id != -1:
		_consume_component_instance(top_instance_id)

	GGameDataRegistry.register_dynamic_tower_blueprint(blueprint)
	_assembly_sources[tower_id] = sources
	GEventBus.tower_assembled.emit(String(tower_id), display_name)
	return tower_id


## Resolves one of the 4 tier-gated slots (focus/power/shaft/top).
## `instance_id == -1` means "not supplied": legal (returns `default`,
## already an inert `Component.new()`) only if `slot` isn't required yet at
## `tier`; returns null (caller treats as a hard rejection) if it IS required
## and wasn't supplied, or if a supplied instance_id fails to resolve.
func _resolve_optional_component(instance_id: int, slot: String, tier: int, default: Resource) -> Resource:
	if instance_id == -1:
		if _is_required_at_tier(slot, tier):
			return null
		return default
	return _resolve_component_resource(instance_id)


func get_assembled_blueprint(tower_id: StringName) -> TowerBlueprintData:
	return GGameDataRegistry.get_all_tower_blueprints().get(tower_id, null)


func get_all_assembled_tower_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for tower_id: StringName in _assembly_sources:
		ids.append(tower_id)
	return ids


# ---------------------------------------------------------------------------
# SaveRestorer interface (ADR-0003)
# ---------------------------------------------------------------------------

func get_save_key() -> String:
	return "tower_assembly"


## Note: this reads each source path straight from _assembly_sources (the
## record kept at assembly time) rather than the resolved TowerBlueprintData
## itself — the blueprint's own component sub-resources have no
## `resource_path` of their own once duplicate_deep()'d, only the original
## standalone .tres files do.
func get_save_data() -> Dictionary:
	var assemblies: Dictionary = {}
	for tower_id: StringName in _assembly_sources:
		assemblies[String(tower_id)] = _assembly_sources[tower_id]
	return {
		"assembly_counter": _assembly_counter,
		"assemblies": assemblies,
	}


## Re-loads each assembly's recorded component paths fresh and re-registers
## the resulting blueprint — the same duplicate_deep() composition
## assemble_tower() itself performs, just replayed from saved paths instead
## of live Inventory instance_ids (nothing is re-consumed; the source items
## were already spent at original assembly time).
##
## Shaft/Top (new 2026-09-01): `shaft_path`/`top_path` are read via
## `entry_dict.get(..., "")`, not `entry_dict[...]` — a save written before
## this feature existed has neither key at all, and an auto-defaulted
## optional slot (assemble_tower()'s own in-memory ShaftComponent.new(),
## never loaded from disk) has an empty string for its path. Both cases
## resolve to a fresh, inert default component here, exactly matching
## assemble_tower()'s own "optional slot, not supplied" behavior — never a
## restore failure.
func restore_save_data(data: Dictionary) -> bool:
	var counter: Variant = data.get("assembly_counter", null)
	var assemblies_raw: Variant = data.get("assemblies", null)
	if not (counter is int) or not (assemblies_raw is Dictionary):
		return false

	var restored_sources: Dictionary[StringName, Dictionary] = {}
	for key: Variant in (assemblies_raw as Dictionary):
		if not (key is String):
			return false
		var entry: Variant = (assemblies_raw as Dictionary)[key]
		if not (entry is Dictionary):
			return false
		var entry_dict: Dictionary = entry as Dictionary
		if not (entry_dict.has("foundation_path") and entry_dict.has("weapon_path") and entry_dict.has("focus_path") and entry_dict.has("power_path") and entry_dict.has("display_name") and entry_dict.has("placement_cost")):
			return false
		var tower_id := StringName(key as String)
		restored_sources[tower_id] = entry_dict

		var foundation: FoundationComponent = ResourceLoader.load(entry_dict["foundation_path"] as String) as FoundationComponent
		var weapon: WeaponComponent = ResourceLoader.load(entry_dict["weapon_path"] as String) as WeaponComponent
		var focus: FocusComponent = _load_or_default_optional(entry_dict.get("focus_path", "") as String, FocusComponent.new()) as FocusComponent
		var power: PowerComponent = _load_or_default_optional(entry_dict.get("power_path", "") as String, PowerComponent.new()) as PowerComponent
		var shaft: ShaftComponent = _load_or_default_optional(entry_dict.get("shaft_path", "") as String, ShaftComponent.new()) as ShaftComponent
		var top: TopComponent = _load_or_default_optional(entry_dict.get("top_path", "") as String, TopComponent.new()) as TopComponent
		if foundation == null or weapon == null or focus == null or power == null or shaft == null or top == null:
			continue  ## content moved/renamed since this save was written — skip, don't fail the whole restore

		var blueprint := TowerBlueprintData.new()
		blueprint.tower_id = tower_id
		blueprint.display_name = entry_dict["display_name"] as String
		blueprint.placement_cost = entry_dict["placement_cost"] as int
		blueprint.foundation = foundation.duplicate_deep()
		blueprint.weapon = weapon.duplicate_deep()
		blueprint.focus = focus.duplicate_deep()
		blueprint.power = power.duplicate_deep()
		blueprint.shaft = shaft.duplicate_deep()
		blueprint.top = top.duplicate_deep()
		GGameDataRegistry.register_dynamic_tower_blueprint(blueprint)

	_assembly_counter = counter as int
	_assembly_sources = restored_sources
	return true


## Empty path (never-persisted, auto-defaulted slot, or a pre-2026-09-01 save
## missing the key entirely) -> `default` (already inert). Non-empty path ->
## load it, same "content moved/renamed" null-on-failure contract as the
## required-slot loads above.
func _load_or_default_optional(path: String, default: Resource) -> Resource:
	if path == "":
		return default
	return ResourceLoader.load(path)


func reset_to_defaults() -> void:
	_assembly_sources = {}
	_assembly_counter = 0
