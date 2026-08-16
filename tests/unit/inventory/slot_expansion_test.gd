## Unit tests for Inventory's slot expansion & cost table (Story 003, ADR-0016).
## Covers AC-8 (tier-progression sequence, no-skip-a-tier), AC-9 (exact cost table
## values + out-of-range tier failure), AC-10 (Tier 4 rarity gate, Tier 1-3 never
## require Rare), AC-16 (max-tier block, checkable eligibility query, no side
## effects on an ineligible/unaffordable attempt).
##
## SlotExpansionCostTable is tested directly and statically (no Inventory instance
## needed) for AC-9/AC-10, mirroring tab_categorization_test.gd's static-function
## testing style. Inventory-instance tests (AC-8/AC-16) follow
## slot_stack_model_test.gd's before_test()/after_test() direct-instantiation
## convention. No random seeds, no time dependence, no external I/O.
extends GdUnitTestSuite

var _inventory: Inventory


func before_test() -> void:
	_inventory = Inventory.new()
	_inventory.reset_to_defaults()


func after_test() -> void:
	if _inventory != null and is_instance_valid(_inventory):
		_inventory.free()
	_inventory = null


# ---------------------------------------------------------------------------
# AC-9: cost table exact match, out-of-range tier fails explicitly
# ---------------------------------------------------------------------------

func test_cost_table_tier_1_matches_gdd_exactly() -> void:
	var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(1)
	assert_int(cost[SlotExpansionCostTable.KEY_SLOTS_AFTER]).is_equal(20)
	assert_int(cost[SlotExpansionCostTable.KEY_COMMON]).is_equal(10)
	assert_int(cost[SlotExpansionCostTable.KEY_UNCOMMON]).is_equal(0)
	assert_int(cost[SlotExpansionCostTable.KEY_RARE]).is_equal(0)


func test_cost_table_tier_2_matches_gdd_exactly() -> void:
	var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(2)
	assert_int(cost[SlotExpansionCostTable.KEY_SLOTS_AFTER]).is_equal(26)
	assert_int(cost[SlotExpansionCostTable.KEY_COMMON]).is_equal(18)
	assert_int(cost[SlotExpansionCostTable.KEY_UNCOMMON]).is_equal(4)
	assert_int(cost[SlotExpansionCostTable.KEY_RARE]).is_equal(0)


func test_cost_table_tier_3_matches_gdd_exactly() -> void:
	var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(3)
	assert_int(cost[SlotExpansionCostTable.KEY_SLOTS_AFTER]).is_equal(32)
	assert_int(cost[SlotExpansionCostTable.KEY_COMMON]).is_equal(28)
	assert_int(cost[SlotExpansionCostTable.KEY_UNCOMMON]).is_equal(10)
	assert_int(cost[SlotExpansionCostTable.KEY_RARE]).is_equal(0)


func test_cost_table_tier_4_matches_gdd_exactly() -> void:
	var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(4)
	assert_int(cost[SlotExpansionCostTable.KEY_SLOTS_AFTER]).is_equal(38)
	assert_int(cost[SlotExpansionCostTable.KEY_COMMON]).is_equal(36)
	assert_int(cost[SlotExpansionCostTable.KEY_UNCOMMON]).is_equal(18)
	assert_int(cost[SlotExpansionCostTable.KEY_RARE]).is_equal(5)


func test_cost_table_tier_5_matches_gdd_exactly() -> void:
	var cost: Dictionary = SlotExpansionCostTable.get_cost_for_tier(5)
	assert_int(cost[SlotExpansionCostTable.KEY_SLOTS_AFTER]).is_equal(44)
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
# AC-8: tier progression sequence 14->20->26->32->38->44, no tier skipping
# ---------------------------------------------------------------------------

func test_fresh_inventory_starts_at_tier_zero_with_fourteen_slots() -> void:
	assert_int(_inventory.get_current_slot_tier()).is_equal(0)
	assert_int(_inventory.get_slot_count()).is_equal(14)


func test_full_tier_progression_sequence_matches_gdd_exactly() -> void:
	var expected_capacities: Array[int] = [20, 26, 32, 38, 44]
	for i: int in range(expected_capacities.size()):
		var available: Dictionary[StringName, int] = {
			SlotExpansionCostTable.KEY_COMMON: 999,
			SlotExpansionCostTable.KEY_UNCOMMON: 999,
			SlotExpansionCostTable.KEY_RARE: 999,
		}
		var expanded: bool = _inventory.attempt_expand_slots(available)
		assert_bool(expanded).is_true()
		assert_int(_inventory.get_slot_count()).is_equal(expected_capacities[i])
		assert_int(_inventory.get_current_slot_tier()).is_equal(i + 1)


## AC-8 edge case: skipping a tier via any code path must be impossible —
## attempt_expand_slots() only ever advances _slot_tier by exactly one per
## successful call, regardless of how much material is supplied.
func test_expansion_never_skips_a_tier_even_with_excess_materials() -> void:
	var available: Dictionary[StringName, int] = {
		SlotExpansionCostTable.KEY_COMMON: 100000,
		SlotExpansionCostTable.KEY_UNCOMMON: 100000,
		SlotExpansionCostTable.KEY_RARE: 100000,
	}
	_inventory.attempt_expand_slots(available)
	assert_int(_inventory.get_current_slot_tier()).is_equal(1)
	assert_int(_inventory.get_slot_count()).is_equal(20)


func test_expansion_growing_slots_preserves_existing_slot_contents_and_indices() -> void:
	var def := ItemDefinitionResource.new()
	def.item_id = &"frost_silk"
	def.item_type = &"Material"
	def.display_name = "Frost Silk"
	def.is_unique_instance = false
	_inventory.add_stackable(def, 7)

	var available: Dictionary[StringName, int] = {SlotExpansionCostTable.KEY_COMMON: 10}
	_inventory.attempt_expand_slots(available)

	var contents: Dictionary = _inventory.get_slot_contents(0)
	assert_that(contents["item_id"]).is_equal("frost_silk")
	assert_int(contents["quantity"]).is_equal(7)


func test_expansion_unaffordable_returns_false_with_no_side_effects() -> void:
	var available: Dictionary[StringName, int] = {SlotExpansionCostTable.KEY_COMMON: 5}  # tier 1 needs 10

	var expanded: bool = _inventory.attempt_expand_slots(available)

	assert_bool(expanded).is_false()
	assert_int(_inventory.get_current_slot_tier()).is_equal(0)
	assert_int(_inventory.get_slot_count()).is_equal(14)


func test_expansion_missing_rarity_key_entirely_treated_as_zero_available() -> void:
	var available: Dictionary[StringName, int] = {}  # no "common" key at all

	var expanded: bool = _inventory.attempt_expand_slots(available)

	assert_bool(expanded).is_false()
	assert_int(_inventory.get_current_slot_tier()).is_equal(0)


## TD-inv-003 item 3: an explicit {key: 0} must reject identically to the
## missing-key case above — previously only guaranteed by code inspection of
## _can_afford_expansion()'s `.get(key, 0)` default, not by a test.
func test_expansion_explicit_zero_rarity_key_treated_identically_to_missing_key() -> void:
	var available: Dictionary[StringName, int] = {
		SlotExpansionCostTable.KEY_COMMON: 0,  # explicitly present, but zero
	}

	var expanded: bool = _inventory.attempt_expand_slots(available)

	assert_bool(expanded).is_false()
	assert_int(_inventory.get_current_slot_tier()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-16: max-tier expansion block — eligibility checkable before attempting,
# no deduction, no side effects
# ---------------------------------------------------------------------------

func _max_out_inventory_tier() -> void:
	var available: Dictionary[StringName, int] = {
		SlotExpansionCostTable.KEY_COMMON: 999,
		SlotExpansionCostTable.KEY_UNCOMMON: 999,
		SlotExpansionCostTable.KEY_RARE: 999,
	}
	for i: int in range(SlotExpansionCostTable.MAX_TIER):
		_inventory.attempt_expand_slots(available)


func test_can_expand_slots_true_before_max_tier() -> void:
	assert_bool(_inventory.can_expand_slots()).is_true()


func test_can_expand_slots_false_at_max_tier_checkable_before_attempting() -> void:
	_max_out_inventory_tier()
	assert_int(_inventory.get_current_slot_tier()).is_equal(5)
	assert_int(_inventory.get_slot_count()).is_equal(44)

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
	var available: Dictionary[StringName, int] = {
		SlotExpansionCostTable.KEY_COMMON: 999,
		SlotExpansionCostTable.KEY_UNCOMMON: 999,
		SlotExpansionCostTable.KEY_RARE: 999,
	}

	var expanded: bool = _inventory.attempt_expand_slots(available)

	assert_bool(expanded).is_false()
	assert_int(_inventory.get_current_slot_tier()).is_equal(5)
	assert_int(_inventory.get_slot_count()).is_equal(44)
	# The caller's availability Dictionary is untouched — attempt_expand_slots()
	# never mutates it (this story's scoping: caller owns real spending).
	assert_int(available[SlotExpansionCostTable.KEY_COMMON]).is_equal(999)


# ---------------------------------------------------------------------------
# Save/restore round trip: _slot_tier persistence (Story 003 extension of
# Story 001's SaveRestorer contract)
# ---------------------------------------------------------------------------

func test_save_restore_round_trip_preserves_slot_tier_and_expanded_capacity() -> void:
	var available: Dictionary[StringName, int] = {
		SlotExpansionCostTable.KEY_COMMON: 999,
		SlotExpansionCostTable.KEY_UNCOMMON: 999,
		SlotExpansionCostTable.KEY_RARE: 999,
	}
	_inventory.attempt_expand_slots(available)
	_inventory.attempt_expand_slots(available)
	var data: Dictionary = _inventory.get_save_data()
	assert_int(data["slot_tier"]).is_equal(2)

	var restored := Inventory.new()
	var ok: bool = restored.restore_save_data(data)

	assert_bool(ok).is_true()
	assert_int(restored.get_current_slot_tier()).is_equal(2)
	assert_int(restored.get_slot_count()).is_equal(26)
	restored.free()


func test_restore_save_data_rejects_slot_count_mismatched_with_claimed_tier() -> void:
	var data: Dictionary = _inventory.get_save_data()
	data["slot_tier"] = 2  # claims tier 2 (26 slots) but "slots" array is still 14 entries

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
	var available: Dictionary[StringName, int] = {SlotExpansionCostTable.KEY_COMMON: 999}
	_inventory.attempt_expand_slots(available)
	assert_int(_inventory.get_current_slot_tier()).is_equal(1)

	_inventory.reset_to_defaults()

	assert_int(_inventory.get_current_slot_tier()).is_equal(0)
	assert_int(_inventory.get_slot_count()).is_equal(14)
