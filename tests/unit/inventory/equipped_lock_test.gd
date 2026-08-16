## Unit tests for Inventory's equipped-item lock (Story 004, ADR-0016).
## Covers AC-11 (locked-item removal rejected, item unchanged; unlocked-item
## removal succeeds) and AC-12 (a locked slot counts toward capacity — never
## treated as available for a NEW item, for both unique-instance and stackable
## slot types).
##
## Inventory is instantiated directly (Inventory.new()) and reset_to_defaults()
## is called explicitly, mirroring slot_stack_model_test.gd / slot_expansion_test.gd's
## direct-instantiation convention (no scene-tree / Autoload dependency needed).
## No random seeds, no time dependence, no external I/O.
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
# Fixtures
# ---------------------------------------------------------------------------

func _make_unique_definition(item_id: StringName) -> ItemDefinitionResource:
	var def := ItemDefinitionResource.new()
	def.item_id = item_id
	def.item_type = &"Equipment"
	def.display_name = String(item_id)
	def.is_unique_instance = true
	return def


func _make_stackable_definition(item_id: StringName) -> ItemDefinitionResource:
	var def := ItemDefinitionResource.new()
	def.item_id = item_id
	def.item_type = &"Material"
	def.display_name = String(item_id)
	def.is_unique_instance = false
	return def


# ---------------------------------------------------------------------------
# AC-11: locked-item removal rejected, item unchanged
# ---------------------------------------------------------------------------

func test_remove_item_on_locked_slot_rejected_and_slot_unchanged() -> void:
	var def := _make_unique_definition(&"iron_sword")
	var idx: int = _inventory.add_unique_item(def, {&"damage": 12.0})
	_inventory.set_slot_locked(idx, true)

	var removed: bool = _inventory.remove_item(idx)

	assert_bool(removed).is_false()
	var contents: Dictionary = _inventory.get_slot_contents(idx)
	assert_bool(contents.is_empty()).is_false()
	assert_that(contents["item_id"]).is_equal("iron_sword")
	assert_bool(contents["locked"]).is_true()


## AC-11 "normal" case — Story 001 had no removal method to test at all, so this
## confirms the new remove_item() actually works on an unlocked slot.
func test_remove_item_on_unlocked_slot_succeeds_and_nulls_slot() -> void:
	var def := _make_unique_definition(&"iron_sword")
	var idx: int = _inventory.add_unique_item(def)

	var removed: bool = _inventory.remove_item(idx)

	assert_bool(removed).is_true()
	assert_bool(_inventory.is_slot_empty(idx)).is_true()
	assert_bool(_inventory.get_slot_contents(idx).is_empty()).is_true()


func test_remove_item_on_empty_slot_rejected() -> void:
	var removed: bool = _inventory.remove_item(0)
	assert_bool(removed).is_false()


## TD-inv-004: remove_item()'s documented/implemented behavior is a full null
## regardless of quantity (Story 006's consume_stackable() owns partial
## depletion, a separate method) -- no existing test exercised this against a
## stackable slot holding a PARTIAL quantity specifically (prior stackable
## coverage was full-stack or single-unit only). A future change that
## "helpfully" turned remove_item() into a decrement would not have been
## caught without this regression guard.
func test_remove_item_on_unlocked_partial_quantity_stackable_slot_nulls_the_whole_slot_not_decrements() -> void:
	var def := _make_stackable_definition(&"frost_silk")
	_inventory.add_stackable(def, 50)  # partial quantity, well under the 99 cap

	var removed: bool = _inventory.remove_item(0)

	assert_bool(removed).is_true()
	assert_bool(_inventory.is_slot_empty(0)).is_true()
	assert_bool(_inventory.get_slot_contents(0).is_empty()).is_true()


func test_remove_item_on_out_of_range_index_rejected() -> void:
	assert_bool(_inventory.remove_item(-1)).is_false()
	assert_bool(_inventory.remove_item(_inventory.get_slot_count())).is_false()


## AC-11 edge case — "no path should bypass the lock": remove_item() is the
## ONLY removal entry point Inventory's own script defines; there is no second
## mutation path (e.g. a hypothetical discard()) to separately audit. Only
## Inventory.gd's own declared methods are inspected here (via
## Script.get_script_method_list()) — Node's large inherited API surface
## (remove_child(), remove_from_group(), etc.) is irrelevant to this story's
## "no removal path bypasses the lock" guarantee and is deliberately excluded.
func test_remove_item_is_the_only_removal_entry_point_exposed() -> void:
	var script: Script = _inventory.get_script()
	var method_names: Array[String] = []
	for m: Dictionary in script.get_script_method_list():
		var mn: String = m["name"]
		if mn.begins_with("remove_") or mn.begins_with("discard"):
			method_names.append(mn)
	assert_array(method_names).contains_exactly(["remove_item"])


# ---------------------------------------------------------------------------
# set_slot_locked(): the mechanism a future Hero/Tower-wiring story will call
# ---------------------------------------------------------------------------

func test_set_slot_locked_true_then_false_round_trip() -> void:
	var def := _make_unique_definition(&"iron_sword")
	var idx: int = _inventory.add_unique_item(def)

	assert_bool(_inventory.set_slot_locked(idx, true)).is_true()
	assert_bool(_inventory.get_slot_contents(idx)["locked"]).is_true()

	assert_bool(_inventory.set_slot_locked(idx, false)).is_true()
	assert_bool(_inventory.get_slot_contents(idx)["locked"]).is_false()


func test_set_slot_locked_on_empty_slot_rejected() -> void:
	assert_bool(_inventory.set_slot_locked(0, true)).is_false()


func test_set_slot_locked_on_out_of_range_index_rejected() -> void:
	assert_bool(_inventory.set_slot_locked(-1, true)).is_false()
	assert_bool(_inventory.set_slot_locked(_inventory.get_slot_count(), true)).is_false()


# ---------------------------------------------------------------------------
# AC-12: a locked slot counts toward capacity — never treated as available for
# a NEW item, for both unique-instance (cap=1) and stackable (cap=99) slots.
# ---------------------------------------------------------------------------

## Fills every slot but one with unique items, then locks the last remaining
## empty slot's *occupant* — i.e. fills ALL slots (last one via add_unique_item
## too), locks it, and confirms the Inventory is fully at capacity: no further
## add_unique_item() call can place anything, matching the AC's "N-1 free-or-
## locked... reports as fully at capacity, not with one free slot" framing.
## Epic 08 Story 008 (ADR-0025); expanded 2026-08-16 alongside the 5->10
## equip-slot expansion: the LAST N indices of the base slot array are now
## permanently reserved, locked Hero equipment-slot placeholders (see
## Inventory.EQUIPMENT_SLOT_INDEX) — add_unique_item()'s _find_first_empty_
## slot() only ever finds the discretionary indices at fresh init, so this
## test fills exactly that many, not the full STARTING_SLOT_COUNT. Computed
## dynamically (STARTING_SLOT_COUNT - EQUIPMENT_SLOT_NAMES.size()) rather
## than hardcoded, so this test doesn't silently drift stale on the next
## slot-count change.
func test_locked_unique_instance_slot_counts_toward_capacity() -> void:
	var discretionary_count: int = Inventory.STARTING_SLOT_COUNT - Inventory.EQUIPMENT_SLOT_NAMES.size()
	var last_idx: int = -1
	for i: int in range(discretionary_count):
		var def := _make_unique_definition(StringName("sword_%d" % i))
		last_idx = _inventory.add_unique_item(def)
		assert_int(last_idx).is_equal(i)

	# Every discretionary slot is now occupied; lock the last one (simulating
	# it being equipped) and confirm the Inventory reports fully at capacity —
	# a new add attempt finds no open slot (the reserved equipment-slot
	# placeholders were never open to begin with).
	_inventory.set_slot_locked(last_idx, true)

	var overflow_def := _make_unique_definition(&"overflow_sword")
	var overflow_idx: int = _inventory.add_unique_item(overflow_def)

	assert_int(overflow_idx).is_equal(-1)
	# The locked slot's original item is still exactly what it was — capacity
	# pressure never evicts or overwrites a locked slot.
	var contents: Dictionary = _inventory.get_slot_contents(last_idx)
	assert_that(contents["item_id"]).is_equal("sword_%d" % (discretionary_count - 1))


## AC-12 distinct case (per story brief): a locked STACKABLE slot must also
## never be treated as an open merge target for the SAME item_id — confirming
## add_stackable()'s existing not-locked guard (inventory.gd line ~264) actually
## fires, rather than assuming it's implied by the unique-instance case above.
func test_locked_stackable_slot_not_treated_as_open_merge_target() -> void:
	var def := _make_stackable_definition(&"frost_silk")
	var idx: int = -1
	var leftover: int = _inventory.add_stackable(def, 5)
	assert_int(leftover).is_equal(0)

	# Find the slot that received it.
	for i: int in range(_inventory.get_slot_count()):
		var contents: Dictionary = _inventory.get_slot_contents(i)
		if not contents.is_empty() and contents["item_id"] == "frost_silk":
			idx = i
			break
	assert_int(idx).is_greater_equal(0)

	_inventory.set_slot_locked(idx, true)

	# Adding more of the same item_id must NOT merge into the locked stack —
	# it must open a fresh slot instead.
	var leftover_after_lock: int = _inventory.add_stackable(def, 3)
	assert_int(leftover_after_lock).is_equal(0)

	var locked_contents: Dictionary = _inventory.get_slot_contents(idx)
	assert_int(locked_contents["quantity"]).is_equal(5)  # unchanged by the second add

	# A second, distinct slot now holds the new quantity.
	var found_second_slot: bool = false
	for i: int in range(_inventory.get_slot_count()):
		if i == idx:
			continue
		var contents: Dictionary = _inventory.get_slot_contents(i)
		if not contents.is_empty() and contents["item_id"] == "frost_silk":
			assert_int(contents["quantity"]).is_equal(3)
			found_second_slot = true
	assert_bool(found_second_slot).is_true()


## AC-12 full-capacity framing, stackable variant: with every slot occupied
## (cap=99 stackable items filling all-but-one, and a locked stackable item in
## the last slot), the Inventory reports fully at capacity — add_stackable()
## returns the full quantity as leftover (nothing placed), not partial success.
## Epic 08 Story 008 (ADR-0025): indices 5-9 are now permanently reserved,
## locked Hero equipment-slot placeholders — only 5 discretionary indices are
## ever fillable, so "fully occupied" now means filling those 5, not
## get_slot_count()'s full 10.
func test_locked_stackable_slot_counts_toward_capacity_when_inventory_full() -> void:
	var discretionary_count: int = _inventory.get_slot_count() - Inventory.EQUIPMENT_SLOT_NAMES.size()
	for i: int in range(discretionary_count):
		var def := _make_stackable_definition(StringName("material_%d" % i))
		var leftover: int = _inventory.add_stackable(def, 1)
		assert_int(leftover).is_equal(0)

	# Lock the last discretionary slot (simulating an "installed" Tower
	# Component-equivalent stackable, or any locked stack) — Inventory is
	# already fully occupied by construction (every discretionary slot
	# non-null); locking one just confirms it is not somehow exempted from
	# the full-capacity result.
	_inventory.set_slot_locked(discretionary_count - 1, true)

	var overflow_def := _make_stackable_definition(&"overflow_material")
	var overflow_leftover: int = _inventory.add_stackable(overflow_def, 1)

	assert_int(overflow_leftover).is_equal(1)  # nothing placed — fully at capacity
