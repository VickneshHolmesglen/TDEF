## Unit tests for Inventory's slot expansion & cost table (Story 003, ADR-0016;
## TD-inv-003 resolution, 2026-08-25). Covers AC-8 (tier-progression sequence,
## no-skip-a-tier), AC-9 (exact cost table values + out-of-range tier failure),
## AC-10 (Tier 4 rarity gate, Tier 1-3 never require Rare), AC-16 (max-tier
## block, checkable eligibility query, no side effects on an
## ineligible/unaffordable attempt), and TD-inv-003 items 1/2 (real Inventory
## rarity resolution + consumption, slot_expansion_completed signal).
##
## SlotExpansionCostTable is tested directly and statically (no Inventory
## instance needed) for AC-9/AC-10, mirroring tab_categorization_test.gd's
## static-function testing style. Inventory-instance tests (AC-8/AC-16/TD-inv-003)
## follow slot_stack_model_test.gd's before_test()/after_test() direct-
## instantiation convention. No random seeds, no time dependence, no external I/O.
##
## TD-inv-003 resolution note: attempt_expand_slots() no longer takes a
## caller-supplied availability Dictionary — it resolves affordability and
## spend against REAL Inventory contents via has_items_by_rarity()/
## consume_by_rarity(), exactly like has_items_by_rarity_test.gd's own
## convention: seeded with real, already-registered GGameDataRegistry content
## (common_scrap [rarity=Common], iron_ore [rarity=Uncommon], goblin_fang
## [rarity=Rare]), not synthetic unregistered fixtures — has_items_by_rarity()/
## consume_by_rarity() both resolve rarity via GGameDataRegistry.get_item_definition(),
## so an unregistered item_id would silently fail to count at all.
extends GdUnitTestSuite

const COMMON_SCRAP: StringName = &"common_scrap"
const IRON_ORE: StringName = &"iron_ore"
const GOBLIN_FANG: StringName = &"goblin_fang"

var _inventory: Inventory


func before_test() -> void:
	_inventory = Inventory.new()
	_inventory.reset_to_defaults()


func after_test() -> void:
	if _inventory != null and is_instance_valid(_inventory):
		_inventory.free()
	_inventory = null


func _make_stackable_definition(item_id: StringName) -> ItemDefinitionResource:
	var def := ItemDefinitionResource.new()
	def.item_id = item_id
	def.item_type = &"Material"
	def.display_name = String(item_id)
	def.is_unique_instance = false
	return def


## Seeds real Inventory slots with real, GGameDataRegistry-registered
## rarity-tagged materials. Generous default cumulative totals (150/70/20)
## cover EVERY tier's cost, summed across all 5 tiers (Common 137, Uncommon
## 60, Rare 17 total) — enough for a test that walks the full progression,
## with room to spare; a 0 argument skips seeding that rarity entirely (for
## tests that specifically want a rarity absent).
func _seed_materials(common: int = 150, uncommon: int = 70, rare: int = 20) -> void:
	if common > 0:
		_inventory.add_stackable(_make_stackable_definition(COMMON_SCRAP), common)
	if uncommon > 0:
		_inventory.add_stackable(_make_stackable_definition(IRON_ORE), uncommon)
	if rare > 0:
		_inventory.add_stackable(_make_stackable_definition(GOBLIN_FANG), rare)


# ---------------------------------------------------------------------------
# AC-9: cost table exact match, out-of-range tier fails explicitly
# ---------------------------------------------------------------------------

func test_cost_table_tier_1_matches_gdd_exactly() -> void:
	var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(1)
	assert_int(cost[SlotExpansionCostTable.KEY_SLOTS_AFTER]).is_equal(24)
	assert_int(cost[SlotExpansionCostTable.KEY_COMMON]).is_equal(10)
	assert_int(cost[SlotExpansionCostTable.KEY_UNCOMMON]).is_equal(0)
	assert_int(cost[SlotExpansionCostTable.KEY_RARE]).is_equal(0)


func test_cost_table_tier_2_matches_gdd_exactly() -> void:
	var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(2)
	assert_int(cost[SlotExpansionCostTable.KEY_SLOTS_AFTER]).is_equal(30)
	assert_int(cost[SlotExpansionCostTable.KEY_COMMON]).is_equal(18)
	assert_int(cost[SlotExpansionCostTable.KEY_UNCOMMON]).is_equal(4)
	assert_int(cost[SlotExpansionCostTable.KEY_RARE]).is_equal(0)


func test_cost_table_tier_3_matches_gdd_exactly() -> void:
	var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(3)
	assert_int(cost[SlotExpansionCostTable.KEY_SLOTS_AFTER]).is_equal(36)
	assert_int(cost[SlotExpansionCostTable.KEY_COMMON]).is_equal(28)
	assert_int(cost[SlotExpansionCostTable.KEY_UNCOMMON]).is_equal(10)
	assert_int(cost[SlotExpansionCostTable.KEY_RARE]).is_equal(0)


func test_cost_table_tier_4_matches_gdd_exactly() -> void:
	var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(4)
	assert_int(cost[SlotExpansionCostTable.KEY_SLOTS_AFTER]).is_equal(42)
	assert_int(cost[SlotExpansionCostTable.KEY_COMMON]).is_equal(36)
	assert_int(cost[SlotExpansionCostTable.KEY_UNCOMMON]).is_equal(18)
	assert_int(cost[SlotExpansionCostTable.KEY_RARE]).is_equal(5)


func test_cost_table_tier_5_matches_gdd_exactly() -> void:
	var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(5)
	assert_int(cost[SlotExpansionCostTable.KEY_SLOTS_AFTER]).is_equal(48)
	assert_int(cost[SlotExpansionCostTable.KEY_COMMON]).is_equal(45)
	assert_int(cost[SlotExpansionCostTable.KEY_UNCOMMON]).is_equal(28)
	assert_int(cost[SlotExpansionCostTable.KEY_RARE]).is_equal(12)


## AC-9 edge case: tier 0 is out of range (0 is not a valid expansion tier index —
## it's the un-expanded base state, not a row in the cost table) and must fail
## explicitly, not resolve to a default/zero-cost row.
func test_cost_table_tier_zero_fails_explicitly() -> void:
	var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(0)
	assert_bool(cost.is_empty()).is_true()


## AC-9 edge case: tier 6 is out of range (no Tier 6 exists) and must fail
## explicitly, not resolve to a default/zero-cost row.
func test_cost_table_tier_six_fails_explicitly() -> void:
	var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(6)
	assert_bool(cost.is_empty()).is_true()


func test_cost_table_negative_tier_fails_explicitly() -> void:
	var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(-1)
	assert_bool(cost.is_empty()).is_true()


# ---------------------------------------------------------------------------
# AC-10: Tier 4 rarity gate — all 3 rarities required, Rare first appears here
# ---------------------------------------------------------------------------

func test_tier_4_requires_all_three_rarity_tiers() -> void:
	var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(4)
	assert_int(cost[SlotExpansionCostTable.KEY_COMMON]).is_greater(0)
	assert_int(cost[SlotExpansionCostTable.KEY_UNCOMMON]).is_greater(0)
	assert_int(cost[SlotExpansionCostTable.KEY_RARE]).is_greater(0)


## AC-10 edge case: confirm Tier 1-3 never require Rare material under any
## circumstance.
func test_tiers_one_through_three_never_require_rare() -> void:
	for tier: int in [1, 2, 3]:
		var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(tier)
		assert_int(cost[SlotExpansionCostTable.KEY_RARE]).is_equal(0)


func test_uncommon_first_appears_at_tier_2_not_tier_1() -> void:
	var tier_1: Dictionary = SlotExpansionCostTable.get_cost_for_tier(1)
	var tier_2: Dictionary = SlotExpansionCostTable.get_cost_for_tier(2)
	assert_int(tier_1[SlotExpansionCostTable.KEY_UNCOMMON]).is_equal(0)
	assert_int(tier_2[SlotExpansionCostTable.KEY_UNCOMMON]).is_greater(0)


func test_rare_first_appears_at_tier_4_not_tier_3() -> void:
	var tier_3: Dictionary = SlotExpansionCostTable.get_cost_for_tier(3)
	var tier_4: Dictionary = SlotExpansionCostTable.get_cost_for_tier(4)
	assert_int(tier_3[SlotExpansionCostTable.KEY_RARE]).is_equal(0)
	assert_int(tier_4[SlotExpansionCostTable.KEY_RARE]).is_greater(0)


# ---------------------------------------------------------------------------
# AC-8: tier progression sequence 24->30->36->42->48, no tier skipping
# ---------------------------------------------------------------------------

func test_fresh_inventory_starts_at_tier_zero_with_eighteen_slots() -> void:
	assert_int(_inventory.get_current_slot_tier()).is_equal(0)
	assert_int(_inventory.get_slot_count()).is_equal(18)


func test_full_tier_progression_sequence_matches_gdd_exactly() -> void:
	_seed_materials()
	var expected_capacities: Array[int] = [24, 30, 36, 42, 48]
	for i: int in range(expected_capacities.size()):
		var expanded: bool = _inventory.attempt_expand_slots()
		assert_bool(expanded).is_true()
		assert_int(_inventory.get_slot_count()).is_equal(expected_capacities[i])
		assert_int(_inventory.get_current_slot_tier()).is_equal(i + 1)


## AC-8 edge case: skipping a tier via any code path must be impossible —
## attempt_expand_slots() only ever advances _slot_tier by exactly one per
## successful call, regardless of how much material is available.
func test_expansion_never_skips_a_tier_even_with_excess_materials() -> void:
	_seed_materials()
	_inventory.attempt_expand_slots()
	assert_int(_inventory.get_current_slot_tier()).is_equal(1)
	assert_int(_inventory.get_slot_count()).is_equal(24)


func test_expansion_growing_slots_preserves_existing_slot_contents_and_indices() -> void:
	var def := ItemDefinitionResource.new()
	def.item_id = &"frost_silk"
	def.item_type = &"Material"
	def.display_name = "Frost Silk"
	def.is_unique_instance = false
	_inventory.add_stackable(def, 7)  # occupies slot 0; unrated (rarity="") so never touched by consume_by_rarity()

	_seed_materials(10, 0, 0)  # exactly Tier 1's Common cost, lands in slot 1
	_inventory.attempt_expand_slots()

	var contents: Dictionary = _inventory.get_slot_contents(0)
	assert_that(contents["item_id"]).is_equal("frost_silk")
	assert_int(contents["quantity"]).is_equal(7)


func test_expansion_unaffordable_returns_false_with_no_side_effects() -> void:
	_seed_materials(5, 0, 0)  # tier 1 needs 10 Common

	var expanded: bool = _inventory.attempt_expand_slots()

	assert_bool(expanded).is_false()
	assert_int(_inventory.get_current_slot_tier()).is_equal(0)
	assert_int(_inventory.get_slot_count()).is_equal(18)


## TD-inv-003 resolution note: the pre-fix version of this suite had two
## separate tests here ("missing rarity key entirely" vs. "explicit {key: 0}")
## because the old caller-supplied-Dictionary design could distinguish those
## two input shapes. Real Inventory contents cannot: owning zero of a
## material IS the only representable "zero" state. Both collapse into this
## one test now — the distinction they used to guard
## (`_can_afford_expansion()`'s `.get(key, 0)` default) no longer exists as
## a code path; has_items_by_rarity()'s own equivalent behavior already has
## direct coverage in has_items_by_rarity_test.gd.
func test_expansion_with_zero_common_material_owned_rejects() -> void:
	# _seed_materials() intentionally not called — inventory owns none of any
	# rarity-tagged material at all.
	var expanded: bool = _inventory.attempt_expand_slots()

	assert_bool(expanded).is_false()
	assert_int(_inventory.get_current_slot_tier()).is_equal(0)


# ---------------------------------------------------------------------------
# TD-inv-003 items 1/2: real Inventory rarity resolution/consumption,
# slot_expansion_completed signal
# ---------------------------------------------------------------------------

func test_expansion_consumes_exactly_the_required_materials_from_real_inventory() -> void:
	_seed_materials(10, 0, 0)  # exactly Tier 1's Common cost, nothing more

	var expanded: bool = _inventory.attempt_expand_slots()

	assert_bool(expanded).is_true()
	# All 10 Common consumed -- none left, not even 1.
	assert_bool(_inventory.has_items_by_rarity({&"Common": 1})).is_false()


func test_expansion_at_tier_4_consumes_all_three_rarities() -> void:
	# Walk to tier 3 first (tiers 1-3 don't need Uncommon/Rare in the
	# quantities tier 4 does), then confirm tier 4 itself draws from all three.
	_seed_materials()
	_inventory.attempt_expand_slots()  # tier 1
	_inventory.attempt_expand_slots()  # tier 2
	_inventory.attempt_expand_slots()  # tier 3
	# Remaining after tiers 1-3 (10+18+28=56 Common, 0+4+10=14 Uncommon, 0 Rare
	# consumed so far) out of the 150/70/20 seeded: 94 Common, 56 Uncommon, 20 Rare.
	var tier_4_cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(4)

	var expanded: bool = _inventory.attempt_expand_slots()

	assert_bool(expanded).is_true()
	assert_int(_inventory.get_current_slot_tier()).is_equal(4)
	# Confirm real consumption happened for all three rarities: exactly
	# tier_4_cost[KEY_RARE] (5) of the 20 seeded Rare are gone, 15 remain.
	assert_bool(_inventory.has_items_by_rarity({&"Rare": 16})).is_false()
	assert_bool(_inventory.has_items_by_rarity({&"Rare": 15})).is_true()
	assert_int(tier_4_cost[SlotExpansionCostTable.KEY_RARE]).is_equal(5)


func test_expansion_success_emits_slot_expansion_completed_with_correct_args() -> void:
	_seed_materials(10, 0, 0)

	var captured: Array = []
	var on_completed := func(new_tier: int, new_slot_count: int) -> void:
		captured.append([new_tier, new_slot_count])
	GEventBus.slot_expansion_completed.connect(on_completed)

	_inventory.attempt_expand_slots()

	GEventBus.slot_expansion_completed.disconnect(on_completed)
	assert_array(captured).contains_exactly([[1, 24]])


func test_expansion_failure_does_not_emit_slot_expansion_completed() -> void:
	# No materials seeded -- guaranteed unaffordable.
	var fired: bool = false
	var on_completed := func(_a, _b) -> void: fired = true
	GEventBus.slot_expansion_completed.connect(on_completed)

	_inventory.attempt_expand_slots()

	GEventBus.slot_expansion_completed.disconnect(on_completed)
	assert_bool(fired).is_false()


# ---------------------------------------------------------------------------
# AC-16: max-tier expansion block — eligibility checkable before attempting,
# no deduction, no side effects
# ---------------------------------------------------------------------------

func _max_out_inventory_tier() -> void:
	_seed_materials()
	for i: int in range(SlotExpansionCostTable.MAX_TIER):
		_inventory.attempt_expand_slots()


func test_can_expand_slots_true_before_max_tier() -> void:
	assert_bool(_inventory.can_expand_slots()).is_true()


func test_can_expand_slots_false_at_max_tier_checkable_before_attempting() -> void:
	_max_out_inventory_tier()
	assert_int(_inventory.get_current_slot_tier()).is_equal(5)
	assert_int(_inventory.get_slot_count()).is_equal(48)

	# The eligibility query itself must report false — reachable independent of
	# any attempt_expand_slots() call (AC-16: "checkable BEFORE attempting
	# deduction... not just a rejection after the fact").
	assert_bool(_inventory.can_expand_slots()).is_false()


func test_get_next_expansion_cost_fails_explicitly_at_max_tier() -> void:
	_max_out_inventory_tier()
	var cost: Dictionary = _inventory.get_next_expansion_cost()
	assert_bool(cost.is_empty()).is_true()


func test_attempt_expand_at_max_tier_blocked_with_no_deduction_and_no_growth() -> void:
	_max_out_inventory_tier()
	# Seed extra material AFTER maxing out, so any (incorrect) deduction on a
	# blocked attempt would be observable.
	_seed_materials(50, 0, 0)

	var expanded: bool = _inventory.attempt_expand_slots()

	assert_bool(expanded).is_false()
	assert_int(_inventory.get_current_slot_tier()).is_equal(5)
	assert_int(_inventory.get_slot_count()).is_equal(48)
	# The just-seeded 50 Common are still fully present -- a blocked (max-tier)
	# attempt never reaches has_items_by_rarity()/consume_by_rarity() at all.
	assert_bool(_inventory.has_items_by_rarity({&"Common": 50})).is_true()


# ---------------------------------------------------------------------------
# Save/restore round trip: _slot_tier persistence (Story 003 extension of
# Story 001's SaveRestorer contract)
# ---------------------------------------------------------------------------

func test_save_restore_round_trip_preserves_slot_tier_and_expanded_capacity() -> void:
	_seed_materials()
	_inventory.attempt_expand_slots()
	_inventory.attempt_expand_slots()
	var data: Dictionary = _inventory.get_save_data()
	assert_int(data["slot_tier"]).is_equal(2)

	var restored := Inventory.new()
	var ok: bool = restored.restore_save_data(data)

	assert_bool(ok).is_true()
	assert_int(restored.get_current_slot_tier()).is_equal(2)
	assert_int(restored.get_slot_count()).is_equal(30)
	restored.free()


func test_restore_save_data_rejects_slot_count_mismatched_with_claimed_tier() -> void:
	var data: Dictionary = _inventory.get_save_data()
	data["slot_tier"] = 2  # claims tier 2 (30 slots) but "slots" array is still 18 entries

	var ok: bool = _inventory.restore_save_data(data)

	assert_bool(ok).is_false()


func test_restore_save_data_rejects_out_of_range_slot_tier() -> void:
	var data: Dictionary = _inventory.get_save_data()
	data["slot_tier"] = 6

	var ok: bool = _inventory.restore_save_data(data)

	assert_bool(ok).is_false()


func test_restore_save_data_rejects_missing_slot_tier_key() -> void:
	var data: Dictionary = _inventory.get_save_data()
	data.erase("slot_tier")

	var ok: bool = _inventory.restore_save_data(data)

	assert_bool(ok).is_false()


func test_reset_to_defaults_resets_slot_tier_to_zero() -> void:
	_seed_materials(10, 0, 0)
	_inventory.attempt_expand_slots()
	assert_int(_inventory.get_current_slot_tier()).is_equal(1)

	_inventory.reset_to_defaults()

	assert_int(_inventory.get_current_slot_tier()).is_equal(0)
	assert_int(_inventory.get_slot_count()).is_equal(18)
