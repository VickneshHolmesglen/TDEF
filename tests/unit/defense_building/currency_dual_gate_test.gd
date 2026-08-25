## Unit tests for Story 022 (TR-defbuild-001, currency half; ADR-0024):
## DefenseBuilding.resolve_tech_unlock()/resolve_structure_build()'s gold-debit
## emission and dual-gate rejection behavior.
##
## Exercises the real, authored res://assets/data/defense_building/ content
## via the GGameDataRegistry Autoload (no fixture injection) — same rationale
## as every other defense_building test. Story 025 landed real gold_cost/
## material_costs values (previously all 0/{}) — AC-20/AC-21's exact-payload
## assertions read the live authored value dynamically (not a hardcoded 0),
## so they remain correct either way.
##
## TD-defbuild-002 FULLY RESOLVED (vocabulary: Sprint 6 S6-06b; consumption:
## 2026-08-25): real material_costs are keyed by RARITY ("Common"/"Uncommon"/
## "Rare"), and DefenseBuilding checks them via Inventory.has_items_by_rarity()
## — a genuine aggregation axis on ItemDefinitionResource.rarity, separate
## from has_items()'s item_type sum — AND now actually consumes them via
## Inventory.consume_by_rarity() on a successful resolve (step d of ADR-0024
## Rule 9, previously the one deliberately-deferred sub-step). See
## test_resolve_tech_unlock_consumes_real_materials_from_inventory below for
## the direct proof. has_items_by_rarity()/consume_by_rarity() both resolve
## each slot's rarity via
## GGameDataRegistry.get_item_definition(slot.item_id) — NOT from the
## ItemDefinitionResource object passed to add_stackable() — so seeding must
## use a genuinely REGISTERED item_id (found live-MCP-verifying this fix; a
## fabricated item_id silently resolves to null and never counts).
## _make_rarity_definition() returns the real `common_scrap`/`iron_ore`
## definitions from GGameDataRegistry. GInventory is the real global
## Autoload — reset in both before_test() and after_test() to avoid leaking
## seeded items into other test files that also touch it.
##
## AC-18: now directly testable at the DefenseBuilding level (Story 025's
## real material_costs unblocked it) — see
## test_resolve_tech_unlock_rejected_by_insufficient_materials below. The
## underlying has_items() rejection logic is still separately unit-tested in
## isolation at tests/unit/inventory/has_items_test.gd.
##
## AC-19: DEFERRED — gold-balance ownership (who validates affordability) is
## a pre-existing, unresolved project-wide gap (ADR-0024 Decision, Core Rule
## 7); resolve_tech_unlock()/resolve_structure_build() do not independently
## re-validate gold sufficiency, matching every other gold-spending system's
## self-debit convention in this project. No test function for this reason —
## see defense_building.gd's resolve_tech_unlock() doc comment for the full
## rationale.
extends GdUnitTestSuite

const TECH_PRODUCTION_2: StringName = &"tech_production_2"
const TECH_PRODUCTION_3: StringName = &"tech_production_3"
const HABITAT_TIER_1: StringName = &"habitat_expansion_tier_1"
const HABITAT_TIER_2: StringName = &"habitat_expansion_tier_2"

var _defense_building: DefenseBuilding
var _spy: EventBusSpy


## TD-defbuild-002 RESOLVED — see class doc comment. has_items_by_rarity()/
## consume_by_rarity() resolve a slot's rarity via
## GGameDataRegistry.get_item_definition(slot.item_id) — they never look at
## the ItemDefinitionResource object passed to add_stackable() directly. A
## fabricated item_id (e.g. "test_material_Common") is NOT in the registry
## (only res://assets/data/items/*.tres content is), so it silently resolves
## to null and never counts toward any rarity total — a real bug found via
## live MCP verification, not a hypothetical. Returns the genuine registered
## `common_scrap` (rarity=Common) / `iron_ore` (rarity=Uncommon) definition
## instead.
func _make_rarity_definition(rarity: StringName) -> ItemDefinitionResource:
	var item_id: StringName = &"common_scrap" if rarity == &"Common" else &"iron_ore"
	return GGameDataRegistry.get_item_definition(item_id)


func before_test() -> void:
	_defense_building = DefenseBuilding.new()
	# Story 024 gates resolve_*() on is_locked() (defaults true/LOCKED since
	# _ready() never fires without add_child()) — these tests are about
	# currency/dual-gate behavior specifically, which only ever happens in
	# Sanctuary in real gameplay, so force the Sanctuary context directly
	# rather than exercising the full scene_transition_completed subscription
	# path (that's persistence_through_defeat_test.gd's job, Story 024).
	_defense_building._is_sanctuary = true
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.resources_changed)
	GInventory.reset_to_defaults()
	GInventory.add_stackable(_make_rarity_definition(&"Common"), 100)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _defense_building != null and is_instance_valid(_defense_building):
		_defense_building.free()
	_defense_building = null
	GInventory.reset_to_defaults()


# ---------------------------------------------------------------------------
# AC-20: tech node unlock resolves -> resources_changed(-gold_cost, "tech_unlock")
# fires with the exact negative value and source tag.
# ---------------------------------------------------------------------------

func test_resolve_tech_unlock_emits_resources_changed_with_correct_payload() -> void:
	var tech_node: TechNodeResource = GGameDataRegistry.get_tech_node(TECH_PRODUCTION_2)
	var result: bool = _defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)

	assert_bool(result).is_true()
	assert_bool(_spy.was_emitted("resources_changed")).is_true()
	assert_int(_spy.count("resources_changed")).is_equal(1)
	var args: Array = (_spy.emissions["resources_changed"] as Array)[0] as Array
	assert_int(args[0] as int).is_equal(-tech_node.gold_cost)
	assert_that(args[1] as StringName).is_equal(&"tech_unlock")
	assert_bool(_defense_building.is_tech_unlocked(TECH_PRODUCTION_2)).is_true()


func test_resolve_tech_unlock_rejected_by_eligibility_gate_emits_nothing() -> void:
	# tech_production_3's prerequisite (tech_production_2) is not unlocked —
	# can_unlock_tech() rejects before the gold-debit/materials-check is ever
	# reached. Confirms resolve_tech_unlock() doesn't bypass Story 019's
	# eligibility gate.
	var result: bool = _defense_building.resolve_tech_unlock(TECH_PRODUCTION_3)

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("resources_changed")).is_false()
	assert_bool(_defense_building.is_tech_unlocked(TECH_PRODUCTION_3)).is_false()


# ---------------------------------------------------------------------------
# AC-21: structure build resolves -> resources_changed(-gold_cost, "structure_built")
# fires with source tag "structure_built".
# ---------------------------------------------------------------------------

func test_resolve_structure_build_emits_resources_changed_with_correct_payload() -> void:
	var structure: StructureResource = GGameDataRegistry.get_structure(HABITAT_TIER_1)
	var result: bool = _defense_building.resolve_structure_build(HABITAT_TIER_1)

	assert_bool(result).is_true()
	assert_bool(_spy.was_emitted("resources_changed")).is_true()
	assert_int(_spy.count("resources_changed")).is_equal(1)
	var args: Array = (_spy.emissions["resources_changed"] as Array)[0] as Array
	assert_int(args[0] as int).is_equal(-structure.gold_cost)
	assert_that(args[1] as StringName).is_equal(&"structure_built")
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_1)).is_false()  # now BUILT


func test_resolve_structure_build_rejected_by_eligibility_gate_emits_nothing() -> void:
	# habitat_expansion_tier_2's prerequisite (tier_1) is not built yet —
	# can_build_structure() rejects before gold-debit is ever reached.
	var result: bool = _defense_building.resolve_structure_build(HABITAT_TIER_2)

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("resources_changed")).is_false()


# ---------------------------------------------------------------------------
# AC-18: sufficient gold but insufficient materials -> rejected in full, gold
# alone is never sufficient on its own. Now directly testable at the
# DefenseBuilding level since Story 025 landed real material_costs.
# ---------------------------------------------------------------------------

func test_resolve_tech_unlock_rejected_by_insufficient_materials() -> void:
	# tech_production_2 requires 15 Common — start from a materials-empty
	# Inventory (undo before_test()'s 100-Common seed for this one test) so
	# the eligibility gate passes but the materials gate does not.
	GInventory.reset_to_defaults()
	var result: bool = _defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("resources_changed")).is_false()
	assert_bool(_defense_building.is_tech_unlocked(TECH_PRODUCTION_2)).is_false()


func test_resolve_structure_build_rejected_by_insufficient_materials() -> void:
	GInventory.reset_to_defaults()
	var result: bool = _defense_building.resolve_structure_build(HABITAT_TIER_1)

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("resources_changed")).is_false()
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_1)).is_true()  # still eligible, never built


# ---------------------------------------------------------------------------
# TD-defbuild-002 step (d): a successful resolve actually spends the real
# materials, not just checks them.
# ---------------------------------------------------------------------------

func test_resolve_tech_unlock_consumes_real_materials_from_inventory() -> void:
	# before_test() seeded 100 Common; tech_production_2 costs 15 Common.
	var result: bool = _defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)

	assert_bool(result).is_true()
	# 85 remain (100 - 15) -- enough for 85 but not 86.
	assert_bool(GInventory.has_items_by_rarity({&"Common": 86})).is_false()
	assert_bool(GInventory.has_items_by_rarity({&"Common": 85})).is_true()


func test_resolve_structure_build_consumes_real_materials_from_inventory() -> void:
	# before_test() seeded 100 Common; habitat_expansion_tier_1 costs 20 Common.
	var result: bool = _defense_building.resolve_structure_build(HABITAT_TIER_1)

	assert_bool(result).is_true()
	assert_bool(GInventory.has_items_by_rarity({&"Common": 81})).is_false()
	assert_bool(GInventory.has_items_by_rarity({&"Common": 80})).is_true()


func test_resolve_tech_unlock_rejection_consumes_nothing() -> void:
	GInventory.reset_to_defaults()  # insufficient materials, guaranteed rejection
	var result: bool = _defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)

	assert_bool(result).is_false()
	# has_items_by_rarity()'s own materials-check gate returns false BEFORE
	# consume_by_rarity() is ever reached -- an empty inventory stays exactly
	# that empty, not partially/incorrectly drained.
	assert_int(GInventory.get_slot_count()).is_equal(Inventory.STARTING_SLOT_COUNT)
