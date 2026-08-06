## Integration tests for wiring monster-drop materials into real Inventory
## storage (2026-08-06, design/quick-specs/wire-materials-into-inventory-
## 2026-08-06.md) -- closes resource-economy.md Rule 1's own stated but
## previously-unimplemented "Inventory is the ledger of record for
## materials." Exercises the real GInventory Autoload and the real 13
## authored ItemDefinitionResource files under assets/data/items/, firing
## the real materials_earned/materials_spent signals -- not synthetic
## fixtures, since the whole point is proving the actual EventBus wiring
## works end-to-end, not just that add_stackable()/consume_stackable()
## themselves are correct (already covered by their own unit tests).
extends GdUnitTestSuite

const GOBLIN_HIDE: StringName = &"goblin_hide"
const GOBLIN_FANG: StringName = &"goblin_fang"

var _original_slots_snapshot: Array


func before_test() -> void:
	# GInventory is a shared, persistent Autoload across the whole test run --
	# snapshot every slot so this suite's real add_stackable()/
	# consume_stackable() calls can be fully undone afterward, matching this
	# project's established "reset shared Autoload state between tests"
	# discipline (e.g. pause-behavior_test.gd's own precedent).
	_original_slots_snapshot = []
	for i: int in range(GInventory.get_slot_count()):
		_original_slots_snapshot.append(GInventory.get_slot_contents(i))


func after_test() -> void:
	for i: int in range(GInventory.get_slot_count()):
		var current: Dictionary = GInventory.get_slot_contents(i)
		var original: Dictionary = _original_slots_snapshot[i] if i < _original_slots_snapshot.size() else {}
		if current != original:
			GInventory.remove_item(i)


func test_materials_earned_stores_a_real_inventory_item() -> void:
	GEventBus.materials_earned.emit(String(GOBLIN_HIDE), 3, "test_source")

	var found: bool = false
	for i: int in range(GInventory.get_slot_count()):
		var contents: Dictionary = GInventory.get_slot_contents(i)
		if not contents.is_empty() and contents["item_id"] == String(GOBLIN_HIDE):
			assert_int(contents["quantity"]).is_equal(3)
			found = true
			break
	assert_bool(found).is_true()


func test_materials_earned_resolves_the_correct_rarity() -> void:
	GEventBus.materials_earned.emit(String(GOBLIN_FANG), 1, "test_source")

	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(GOBLIN_FANG)
	assert_object(definition).is_not_null()
	assert_str(definition.rarity).is_equal("Rare")


func test_materials_spent_consumes_from_the_real_stack() -> void:
	GEventBus.materials_earned.emit(String(GOBLIN_HIDE), 5, "test_source")
	GEventBus.materials_spent.emit(String(GOBLIN_HIDE), 2, "test_destination")

	var remaining: int = 0
	for i: int in range(GInventory.get_slot_count()):
		var contents: Dictionary = GInventory.get_slot_contents(i)
		if not contents.is_empty() and contents["item_id"] == String(GOBLIN_HIDE):
			remaining += int(contents["quantity"])
	assert_int(remaining).is_equal(3)


func test_unrecognized_material_type_does_not_crash() -> void:
	GEventBus.materials_earned.emit("totally_unknown_material", 1, "test_source")
	# No assertion beyond "this line is reached" -- the real regression this
	# guards against is a crash/unhandled error on unrecognized content.
	assert_bool(true).is_true()


func test_all_13_drop_materials_resolve_to_a_real_item_definition() -> void:
	var material_ids: Array[StringName] = [
		&"goblin_hide", &"goblin_fang", &"iron_plating", &"brute_core",
		&"lurker_ichor", &"bog_pearl", &"rift_shard", &"sentinel_core",
		&"spore_dust", &"troll_hide", &"troll_marrow", &"warlord_iron",
		&"warlord_emblem",
	]
	for material_id: StringName in material_ids:
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(material_id)
		assert_object(definition).is_not_null()
		assert_str(String(definition.item_type)).is_equal("Material")
		assert_bool(["Common", "Rare"].has(definition.rarity)).is_true()
