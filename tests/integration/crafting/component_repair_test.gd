## Integration tests for Story 005 (TR-craft-003, repair half; ADR-0023 +
## ADR-0021): Component Repair — in-place damaged-flag mutation via
## Inventory.clear_damaged_flag(), distinct from Crafting Resolution (AC-6),
## and Formula 3's exact tier-scaled cost (AC-9).
##
## TD-craft-001/TD-defbuild-002 RESOLVED (Sprint 6, S6-06b): repair's Common-
## material cost check uses the rarity vocabulary Formula 1/3 was always
## authored against, now checked/paid via Inventory.has_items_by_rarity()/
## consume_by_rarity() (see crafting.gd's resolve_repair() doc comment). A
## genuine, schema-valid Material item with `rarity="Common"` is seeded into
## the real GInventory Autoload to exercise AC-6's success path.
extends GdUnitTestSuite

var _crafting: Crafting
var _spy: EventBusSpy


func before_test() -> void:
	_crafting = Crafting.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.component_repaired)
	_spy.watch(GEventBus.component_crafted)
	_spy.watch(GEventBus.item_added)
	_spy.watch(GEventBus.item_removed)
	GInventory.reset_to_defaults()


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _crafting != null and is_instance_valid(_crafting):
		_crafting.free()
	_crafting = null
	GInventory.reset_to_defaults()


## has_items_by_rarity()/consume_by_rarity() resolve rarity via
## GGameDataRegistry.get_item_definition(slot.item_id) — a fabricated
## item_id ("test_material_common") is never in the registry and silently
## fails to count (found via live MCP verification, not a hypothetical).
## Returns the genuine registered `common_scrap` (rarity=Common) definition
## instead.
func _make_common_definition() -> ItemDefinitionResource:
	return GGameDataRegistry.get_item_definition(&"common_scrap")


func _seed_damaged_component(quality_tier: int) -> int:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"iron_foundation_component")
	var overrides: Dictionary[StringName, float] = {&"quality_tier": float(quality_tier)}
	var slot_index: int = GInventory.add_unique_item(def, overrides)
	var contents: Dictionary = GInventory.get_slot_contents(slot_index)
	var instance_id: int = contents["instance_id"] as int
	# Mark damaged directly — no game action currently sets this yet (Tower
	# System's damage-on-return isn't wired to Inventory yet); matches the
	# story's own framing ("GIVEN a damaged=true... instance").
	for slot: InventorySlot in GInventory._slots:
		if slot != null and slot.instance_id == instance_id:
			slot.damaged = true
	return instance_id


# ---------------------------------------------------------------------------
# AC-6: damaged instance + sufficient Common -> repaired in place, no new
# item, no component_crafted, no item_added/item_removed, component_repaired
# fires exactly once.
# ---------------------------------------------------------------------------

func test_resolve_repair_success_flips_damaged_false_fires_component_repaired_only() -> void:
	var instance_id: int = _seed_damaged_component(1)  # Tier 1 -> cost round(4*1.0)=4
	GInventory.add_stackable(_make_common_definition(), 4)
	# Seeding the repair-cost material above genuinely emits item_added (it's
	# a real, registered item now — see _make_common_definition()'s doc
	# comment) — clear the spy so AC-6's "no item_added/item_removed" assertion
	# below is scoped to resolve_repair() itself, not this arrange-phase setup.
	_spy.clear()

	var result: bool = _crafting.resolve_repair(instance_id)

	assert_bool(result).is_true()
	var contents: Dictionary = GInventory.get_slot_contents_by_instance_id(instance_id)
	assert_bool(contents["damaged"] as bool).is_false()
	assert_int(_spy.count("component_repaired")).is_equal(1)
	assert_bool(_spy.was_emitted("component_crafted")).is_false()
	assert_bool(_spy.was_emitted("item_added")).is_false()
	assert_bool(_spy.was_emitted("item_removed")).is_false()


func test_resolve_repair_rejected_when_insufficient_common_material() -> void:
	var instance_id: int = _seed_damaged_component(1)
	GInventory.add_stackable(_make_common_definition(), 1)  # below the required 4

	var result: bool = _crafting.resolve_repair(instance_id)

	assert_bool(result).is_false()
	var contents: Dictionary = GInventory.get_slot_contents_by_instance_id(instance_id)
	assert_bool(contents["damaged"] as bool).is_true()  # unchanged
	assert_bool(_spy.was_emitted("component_repaired")).is_false()


func test_resolve_repair_rejected_for_non_damaged_instance() -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"iron_foundation_component")
	var slot_index: int = GInventory.add_unique_item(def, {&"quality_tier": 1.0})
	var instance_id: int = (GInventory.get_slot_contents(slot_index)["instance_id"] as int)
	GInventory.add_stackable(_make_common_definition(), 10)

	var result: bool = _crafting.resolve_repair(instance_id)
	assert_bool(result).is_false()


# ---------------------------------------------------------------------------
# AC-9: Formula 3 — Tier 4 repair cost is exactly 16 Common; Tier 1 is 4.
# ---------------------------------------------------------------------------

func test_repair_common_cost_tier_4_is_16() -> void:
	assert_int(Crafting.repair_common_cost(4)).is_equal(16)


func test_repair_common_cost_tier_1_is_4() -> void:
	assert_int(Crafting.repair_common_cost(1)).is_equal(4)
