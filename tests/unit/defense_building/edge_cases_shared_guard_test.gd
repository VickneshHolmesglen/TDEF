## Unit tests for Story 026 (TR-defbuild-001, edge-case half; ADR-0024):
## stale-UI rejection (AC-37) and the shared, cross-ledger `_action_resolving`
## double-confirm guard (AC-38). AC-39 (unknown tech_id/structure_id in a
## restored save) is explicitly out of scope per the story text — no test
## function for it.
##
## Exercises the real, authored res://assets/data/defense_building/ content
## via the GGameDataRegistry Autoload, same rationale as every other
## defense_building test. TD-defbuild-002 FULLY RESOLVED (vocabulary: Sprint
## 6 S6-06b; consumption: 2026-08-25): real material_costs are rarity-keyed,
## checked via Inventory.has_items_by_rarity() and now genuinely spent via
## consume_by_rarity() on success — see currency_dual_gate_test.gd's class
## doc comment for the full explanation, including why
## _make_rarity_definition() must return a genuinely REGISTERED item_id
## (has_items_by_rarity() resolves rarity via
## GGameDataRegistry.get_item_definition(slot.item_id), not the definition
## object passed to add_stackable() — a fabricated item_id silently never
## counts, found via live MCP verification).
extends GdUnitTestSuite

const TECH_PRODUCTION_2: StringName = &"tech_production_2"
const HABITAT_TIER_1: StringName = &"habitat_expansion_tier_1"

var _defense_building: DefenseBuilding
var _spy: EventBusSpy


func _make_rarity_definition(rarity: StringName) -> ItemDefinitionResource:
	var item_id: StringName = &"common_scrap" if rarity == &"Common" else &"iron_ore"
	return GGameDataRegistry.get_item_definition(item_id)


func before_test() -> void:
	_defense_building = DefenseBuilding.new()
	_defense_building._is_sanctuary = true
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.resources_changed)
	_spy.watch(GEventBus.tech_unlocked)
	_spy.watch(GEventBus.sanctuary_structure_built)
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
# AC-37: stale UI — a precondition (materials) becomes insufficient between
# render and click. Rule 9 step (b) rejects in full, zero side effects, and
# critically the guard is released afterward so the NEXT legitimate attempt
# can still succeed (a single rejection must not permanently disable future
# actions).
# ---------------------------------------------------------------------------

func test_stale_ui_rejection_has_zero_side_effects_and_does_not_lock_out_future_attempts() -> void:
	# Materials were sufficient when the (hypothetical) UI rendered, but have
	# since been spent elsewhere — simulate by draining Inventory right
	# before "click."
	GInventory.reset_to_defaults()
	var rejected: bool = _defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)

	assert_bool(rejected).is_false()
	assert_bool(_defense_building.is_tech_unlocked(TECH_PRODUCTION_2)).is_false()
	assert_bool(_spy.was_emitted("resources_changed")).is_false()
	assert_bool(_spy.was_emitted("tech_unlocked")).is_false()
	assert_bool(_defense_building._action_resolving).is_false()  # guard released, not stuck

	# The next legitimate attempt (materials now available) must still succeed.
	GInventory.add_stackable(_make_rarity_definition(&"Common"), 100)
	var succeeded: bool = _defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)
	assert_bool(succeeded).is_true()


# ---------------------------------------------------------------------------
# AC-38: a second confirmation arriving while _action_resolving is already
# true is rejected outright — no queueing — and the guard is SHARED across
# both ledgers (a tech-unlock in flight blocks a structure-build attempt,
# and vice versa), preventing the cross-ledger double-spend race.
# ---------------------------------------------------------------------------

func test_resolve_tech_unlock_rejected_outright_while_action_resolving_is_true() -> void:
	_defense_building._action_resolving = true
	var result: bool = _defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)

	assert_bool(result).is_false()
	assert_bool(_defense_building.is_tech_unlocked(TECH_PRODUCTION_2)).is_false()
	assert_bool(_spy.was_emitted("resources_changed")).is_false()
	assert_bool(_spy.was_emitted("tech_unlocked")).is_false()


func test_resolve_structure_build_rejected_outright_while_action_resolving_is_true() -> void:
	_defense_building._action_resolving = true
	var result: bool = _defense_building.resolve_structure_build(HABITAT_TIER_1)

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("resources_changed")).is_false()
	assert_bool(_spy.was_emitted("sanctuary_structure_built")).is_false()


func test_guard_is_shared_across_ledgers_tech_unlock_in_flight_blocks_structure_build() -> void:
	# Simulates a tech-unlock confirm and a structure-build confirm "arriving
	# in the same frame" — the guard being set (as if mid-resolution) by one
	# must reject the other, DIFFERENT-ledger action, not just a same-ledger
	# repeat. This is the specific cross-ledger case AC-38/ADR-0024 calls out
	# as the reason for one shared flag instead of two per-ledger ones.
	_defense_building._action_resolving = true
	var structure_result: bool = _defense_building.resolve_structure_build(HABITAT_TIER_1)
	assert_bool(structure_result).is_false()
	assert_bool(_spy.was_emitted("sanctuary_structure_built")).is_false()


func test_guard_is_shared_across_ledgers_structure_build_in_flight_blocks_tech_unlock() -> void:
	_defense_building._action_resolving = true
	var tech_result: bool = _defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)
	assert_bool(tech_result).is_false()
	assert_bool(_spy.was_emitted("tech_unlocked")).is_false()


func test_guard_releases_after_successful_resolve_allowing_a_subsequent_different_action() -> void:
	var first: bool = _defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)
	assert_bool(first).is_true()
	assert_bool(_defense_building._action_resolving).is_false()  # released after success

	# A second, different action immediately afterward must not be blocked —
	# the guard only rejects TRUE concurrent/reentrant attempts, not
	# sequential ones after a completed resolve.
	var second: bool = _defense_building.resolve_structure_build(HABITAT_TIER_1)
	assert_bool(second).is_true()
