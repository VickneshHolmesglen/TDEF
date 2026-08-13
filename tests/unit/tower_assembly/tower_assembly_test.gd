## Unit tests for TowerAssembly (player-requested, design/quick-specs/
## tower-assembly-2026-08-11.md).
##
## Real content exercised throughout: iron_foundation_component (Foundation,
## tier 1, tier_cost_factor 1.0), advanced_weapon_component (Weapon),
## basic_focus_component (Focus, the new recipe this quick-spec added),
## tier4_power_component (Power). GInventory is a real, persistent Autoload —
## TD-test-004 convention: reset directly in before_test()/after_test().
extends GdUnitTestSuite

const FOUNDATION_ITEM: StringName = &"iron_foundation_component"
const WEAPON_ITEM: StringName = &"advanced_weapon_component"
const FOCUS_ITEM: StringName = &"basic_focus_component"
const POWER_ITEM: StringName = &"tier4_power_component"

var _tower_assembly: TowerAssembly


func before_test() -> void:
	_tower_assembly = TowerAssembly.new()
	add_child(_tower_assembly)
	GInventory.reset_to_defaults()


func after_test() -> void:
	if _tower_assembly != null and is_instance_valid(_tower_assembly):
		remove_child(_tower_assembly)
		_tower_assembly.free()
	_tower_assembly = null
	GInventory.reset_to_defaults()


## Places one of each real crafted component into Inventory (via
## add_unique_item(), matching Crafting's own resolve_craft() call
## convention for tower_component outputs) and returns their 4 instance_ids
## in (foundation, weapon, focus, power) order. add_unique_item() returns a
## SLOT INDEX, not an instance_id (see inventory.gd:553-578) — the real
## instance_id must be read back via get_slot_contents().
func _seed_full_component_set() -> Array[int]:
	var foundation_def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(FOUNDATION_ITEM)
	var weapon_def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(WEAPON_ITEM)
	var focus_def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(FOCUS_ITEM)
	var power_def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(POWER_ITEM)
	var foundation_idx: int = GInventory.add_unique_item(foundation_def)
	var weapon_idx: int = GInventory.add_unique_item(weapon_def)
	var focus_idx: int = GInventory.add_unique_item(focus_def)
	var power_idx: int = GInventory.add_unique_item(power_def)
	var foundation_id: int = GInventory.get_slot_contents(foundation_idx)["instance_id"] as int
	var weapon_id: int = GInventory.get_slot_contents(weapon_idx)["instance_id"] as int
	var focus_id: int = GInventory.get_slot_contents(focus_idx)["instance_id"] as int
	var power_id: int = GInventory.get_slot_contents(power_idx)["instance_id"] as int
	return [foundation_id, weapon_id, focus_id, power_id]


# ---------------------------------------------------------------------------
# Content sanity — the 4 real component_resource_path links this whole
# suite depends on
# ---------------------------------------------------------------------------

func test_all_four_real_tower_component_items_resolve_to_a_real_component() -> void:
	for item_id: StringName in [FOUNDATION_ITEM, WEAPON_ITEM, FOCUS_ITEM, POWER_ITEM]:
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(item_id)
		assert_object(definition).is_not_null()
		assert_str(definition.component_resource_path).is_not_equal("")
		var component: Resource = ResourceLoader.load(definition.component_resource_path)
		assert_object(component).is_not_null()


func test_foundation_item_resolves_to_a_real_foundation_component() -> void:
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(FOUNDATION_ITEM)
	var component: Resource = ResourceLoader.load(definition.component_resource_path)
	assert_bool(component is FoundationComponent).is_true()


# ---------------------------------------------------------------------------
# assemble_tower() — happy path
# ---------------------------------------------------------------------------

func test_assemble_tower_with_all_four_real_components_succeeds() -> void:
	var ids: Array[int] = _seed_full_component_set()

	var tower_id: StringName = _tower_assembly.assemble_tower(ids[0], ids[1], ids[2], ids[3], "My Custom Tower")

	assert_that(tower_id).is_not_equal(&"")


func test_assembled_blueprint_is_immediately_registered_and_placeable() -> void:
	var ids: Array[int] = _seed_full_component_set()
	var tower_id: StringName = _tower_assembly.assemble_tower(ids[0], ids[1], ids[2], ids[3], "My Custom Tower")

	var registered: Dictionary = GGameDataRegistry.get_all_tower_blueprints()
	assert_bool(registered.has(tower_id)).is_true()
	var blueprint: TowerBlueprintData = registered[tower_id]
	assert_str(blueprint.display_name).is_equal("My Custom Tower")
	assert_bool(blueprint.validate()).is_true()


func test_assembled_blueprint_composes_the_correct_component_stats() -> void:
	var ids: Array[int] = _seed_full_component_set()
	var tower_id: StringName = _tower_assembly.assemble_tower(ids[0], ids[1], ids[2], ids[3], "My Custom Tower")

	var blueprint: TowerBlueprintData = GGameDataRegistry.get_all_tower_blueprints()[tower_id]
	assert_str(blueprint.foundation.component_id).is_equal("found_iron_t1")
	assert_str(blueprint.weapon.component_id).is_equal("weap_advanced_t2")
	assert_str(blueprint.focus.component_id).is_equal("focus_basic_t1")
	assert_str(blueprint.power.component_id).is_equal("power_tier4")


func test_assembled_blueprint_components_are_independent_deep_copies() -> void:
	# ADR-0008 Component Deep-Copy Policy: two separate assemblies from the
	# same source component_resource_path must never share the same
	# component instance (a mutation on one must never affect the other).
	var ids_a: Array[int] = _seed_full_component_set()
	var tower_a: StringName = _tower_assembly.assemble_tower(ids_a[0], ids_a[1], ids_a[2], ids_a[3], "Tower A")
	var ids_b: Array[int] = _seed_full_component_set()
	var tower_b: StringName = _tower_assembly.assemble_tower(ids_b[0], ids_b[1], ids_b[2], ids_b[3], "Tower B")

	var blueprint_a: TowerBlueprintData = GGameDataRegistry.get_all_tower_blueprints()[tower_a]
	var blueprint_b: TowerBlueprintData = GGameDataRegistry.get_all_tower_blueprints()[tower_b]
	assert_bool(blueprint_a.foundation == blueprint_b.foundation).is_false()

	blueprint_a.foundation.damaged = true
	assert_bool(blueprint_b.foundation.damaged).is_false()


func test_assemble_tower_consumes_the_four_source_items() -> void:
	var ids: Array[int] = _seed_full_component_set()
	_tower_assembly.assemble_tower(ids[0], ids[1], ids[2], ids[3], "My Custom Tower")

	for instance_id: int in ids:
		assert_bool(GInventory.get_slot_contents_by_instance_id(instance_id).is_empty()).is_true()


func test_assemble_tower_fires_tower_assembled_exactly_once() -> void:
	var ids: Array[int] = _seed_full_component_set()
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.tower_assembled)

	var tower_id: StringName = _tower_assembly.assemble_tower(ids[0], ids[1], ids[2], ids[3], "My Custom Tower")

	assert_int(spy.count("tower_assembled")).is_equal(1)
	var args: Array = (spy.emissions["tower_assembled"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal(String(tower_id))
	assert_str(args[1] as String).is_equal("My Custom Tower")
	spy.disconnect_all()


func test_placement_cost_derives_from_foundation_tier_cost_factor() -> void:
	var ids: Array[int] = _seed_full_component_set()
	var tower_id: StringName = _tower_assembly.assemble_tower(ids[0], ids[1], ids[2], ids[3], "My Custom Tower")

	var blueprint: TowerBlueprintData = GGameDataRegistry.get_all_tower_blueprints()[tower_id]
	# iron_foundation_component's tier_cost_factor is 1.0 -> round(8 * 1.0 * 1.75) = 14
	assert_int(blueprint.placement_cost).is_equal(14)


# ---------------------------------------------------------------------------
# assemble_tower() — rejection paths, zero side effects
# ---------------------------------------------------------------------------

func test_assemble_tower_rejects_a_missing_instance_id_with_zero_side_effects() -> void:
	var ids: Array[int] = _seed_full_component_set()
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.tower_assembled)
	spy.watch(GEventBus.item_removed)
	var bogus_instance_id: int = 999999

	var tower_id: StringName = _tower_assembly.assemble_tower(bogus_instance_id, ids[1], ids[2], ids[3], "Should Not Exist")

	assert_that(tower_id).is_equal(&"")
	assert_int(spy.count("tower_assembled")).is_equal(0)
	assert_int(spy.count("item_removed")).is_equal(0)
	# The 3 valid source items were never consumed either -- an all-or-nothing rejection.
	for instance_id: int in [ids[1], ids[2], ids[3]]:
		assert_bool(GInventory.get_slot_contents_by_instance_id(instance_id).is_empty()).is_false()
	spy.disconnect_all()


func test_assemble_tower_rejects_a_wrong_component_type_in_a_slot() -> void:
	var ids: Array[int] = _seed_full_component_set()
	# Swap weapon and foundation instance_ids into the wrong slots.
	var tower_id: StringName = _tower_assembly.assemble_tower(ids[1], ids[0], ids[2], ids[3], "Wrong Slots")

	assert_that(tower_id).is_equal(&"")


func test_assemble_tower_rejects_a_non_tower_component_item() -> void:
	var salve_def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"healing_salve")
	GInventory.add_stackable(salve_def, 1)
	var salve_instance_id: int = -1
	for i: int in range(GInventory.get_slot_count()):
		var contents: Dictionary = GInventory.get_slot_contents(i)
		if contents.get("item_id", "") == "healing_salve":
			salve_instance_id = contents["instance_id"] as int
			break

	var ids: Array[int] = _seed_full_component_set()
	# healing_salve is a stackable CraftedGood, not a unique instance -- its
	# instance_id is always -1, so this also exercises "instance_id -1
	# resolves to nothing meaningful" as a rejection path.
	var tower_id: StringName = _tower_assembly.assemble_tower(salve_instance_id, ids[1], ids[2], ids[3], "Should Reject")
	assert_that(tower_id).is_equal(&"")


# ---------------------------------------------------------------------------
# SaveRestorer round-trip
# ---------------------------------------------------------------------------

func test_save_and_restore_round_trip_reregisters_the_blueprint() -> void:
	var ids: Array[int] = _seed_full_component_set()
	var tower_id: StringName = _tower_assembly.assemble_tower(ids[0], ids[1], ids[2], ids[3], "Persisted Tower")
	var saved: Dictionary = _tower_assembly.get_save_data()

	var fresh := TowerAssembly.new()
	var restored: bool = fresh.restore_save_data(saved)

	assert_bool(restored).is_true()
	var registered: Dictionary = GGameDataRegistry.get_all_tower_blueprints()
	assert_bool(registered.has(tower_id)).is_true()
	assert_str((registered[tower_id] as TowerBlueprintData).display_name).is_equal("Persisted Tower")
	fresh.free()


func test_restore_preserves_the_assembly_counter_to_avoid_id_collisions() -> void:
	var ids: Array[int] = _seed_full_component_set()
	_tower_assembly.assemble_tower(ids[0], ids[1], ids[2], ids[3], "First Tower")
	var saved: Dictionary = _tower_assembly.get_save_data()

	var fresh := TowerAssembly.new()
	fresh.restore_save_data(saved)
	var new_ids: Array[int] = _seed_full_component_set()
	var second_tower_id: StringName = fresh.assemble_tower(new_ids[0], new_ids[1], new_ids[2], new_ids[3], "Second Tower")

	assert_that(second_tower_id).is_not_equal(&"assembled_1")  # must not collide with the restored session's own first assembly
	fresh.free()


func test_restore_rejects_malformed_payload() -> void:
	assert_bool(_tower_assembly.restore_save_data({})).is_false()
	assert_bool(_tower_assembly.restore_save_data({"assembly_counter": "not an int", "assemblies": {}})).is_false()
	assert_bool(_tower_assembly.restore_save_data({"assembly_counter": 0, "assemblies": "not a dictionary"})).is_false()
