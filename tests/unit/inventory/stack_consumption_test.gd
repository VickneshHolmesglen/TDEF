## Unit tests for Inventory's partial-stack-consumption stability (Story 006,
## ADR-0016). Covers AC-17 (partial consumption preserves slot index, no
## compaction) and its QA Test Cases edge cases (full depletion, locked-slot
## rejection, not-found rejection, insufficient-quantity rejection).
##
## Inventory is instantiated directly (Inventory.new()) and reset_to_defaults()
## is called explicitly, mirroring equipped_lock_test.gd / slot_stack_model_test.gd's
## direct-instantiation convention (no scene-tree / GSavePersistence Autoload
## dependency needed, since _ready() is only invoked on add_child()).
##
## GEventBus.item_removed emission is asserted via tests/helpers/event_bus_spy.gd
## (EventBusSpy), the existing established precedent for EventBus signal
## assertions in this codebase (see tests/unit/damage_status/damage_status_test.gd's
## spy.watch(GEventBus.monster_damage_taken) usage) — reused here rather than
## inventing a new idiom, since GEventBus is a real project Autoload and this
## is the first Inventory story that requires a real emission (Stories 003/004
## deliberately deferred all EventBus work).
##
## No random seeds, no time dependence, no external I/O.
extends GdUnitTestSuite

var _inventory: Inventory
var _spy: EventBusSpy


func before_test() -> void:
	_inventory = Inventory.new()
	_inventory.reset_to_defaults()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.item_removed)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _inventory != null and is_instance_valid(_inventory):
		_inventory.free()
	_inventory = null


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

func _make_stackable_definition(item_id: StringName, item_type: StringName = &"Material") -> ItemDefinitionResource:
	var def := ItemDefinitionResource.new()
	def.item_id = item_id
	def.item_type = item_type
	def.display_name = String(item_id)
	def.is_unique_instance = false
	return def


func _make_unique_definition(item_id: StringName) -> ItemDefinitionResource:
	var def := ItemDefinitionResource.new()
	def.item_id = item_id
	def.item_type = &"Equipment"
	def.display_name = String(item_id)
	def.is_unique_instance = true
	return def


# ---------------------------------------------------------------------------
# AC-17 core case: 99 -> consume 40 -> 59 at the same index
# ---------------------------------------------------------------------------

func test_consume_stackable_partial_consumption_preserves_slot_index_and_quantity() -> void:
	var def := _make_stackable_definition(&"iron_ore")
	var leftover: int = _inventory.add_stackable(def, 99)
	assert_int(leftover).is_equal(0)

	var idx: int = -1
	for i: int in range(_inventory.get_slot_count()):
		var contents: Dictionary = _inventory.get_slot_contents(i)
		if not contents.is_empty() and contents["item_id"] == "iron_ore":
			idx = i
			break
	assert_int(idx).is_greater_equal(0)

	var consumed: int = _inventory.consume_stackable(def, 40)

	assert_int(consumed).is_equal(40)
	var contents_after: Dictionary = _inventory.get_slot_contents(idx)
	assert_bool(contents_after.is_empty()).is_false()
	assert_int(contents_after["quantity"]).is_equal(59)
	assert_that(contents_after["item_id"]).is_equal("iron_ore")


func test_consume_stackable_emits_item_removed_with_correct_payload() -> void:
	var def := _make_stackable_definition(&"iron_ore", &"Material")
	_inventory.add_stackable(def, 99)

	var consumed: int = _inventory.consume_stackable(def, 40)

	assert_int(consumed).is_equal(40)
	assert_bool(_spy.was_emitted("item_removed")).is_true()
	assert_int(_spy.count("item_removed")).is_equal(1)
	var args: Array = (_spy.emissions["item_removed"] as Array)[0]
	assert_str(args[0]).is_equal("iron_ore")
	assert_str(args[1]).is_equal("Material")
	assert_int(args[2]).is_equal(40)


# ---------------------------------------------------------------------------
# Full-depletion edge case: consuming exactly the full quantity nulls the slot
# ---------------------------------------------------------------------------

func test_consume_stackable_full_depletion_nulls_slot() -> void:
	var def := _make_stackable_definition(&"iron_ore")
	_inventory.add_stackable(def, 99)

	var idx: int = -1
	for i: int in range(_inventory.get_slot_count()):
		var contents: Dictionary = _inventory.get_slot_contents(i)
		if not contents.is_empty() and contents["item_id"] == "iron_ore":
			idx = i
			break
	assert_int(idx).is_greater_equal(0)

	var consumed: int = _inventory.consume_stackable(def, 99)

	assert_int(consumed).is_equal(99)
	assert_bool(_inventory.is_slot_empty(idx)).is_true()
	assert_bool(_inventory.get_slot_contents(idx).is_empty()).is_true()


func test_consume_stackable_full_depletion_emits_item_removed_with_full_quantity() -> void:
	var def := _make_stackable_definition(&"iron_ore", &"Material")
	_inventory.add_stackable(def, 99)

	var consumed: int = _inventory.consume_stackable(def, 99)

	assert_int(consumed).is_equal(99)
	assert_int(_spy.count("item_removed")).is_equal(1)
	var args: Array = (_spy.emissions["item_removed"] as Array)[0]
	assert_int(args[2]).is_equal(99)


# ---------------------------------------------------------------------------
# Locked-slot rejection (Story 004 precedent, not textually mandated by AC-17)
# ---------------------------------------------------------------------------

func test_consume_stackable_on_locked_slot_rejected_and_slot_unchanged() -> void:
	var def := _make_stackable_definition(&"iron_ore")
	_inventory.add_stackable(def, 99)

	var idx: int = -1
	for i: int in range(_inventory.get_slot_count()):
		var contents: Dictionary = _inventory.get_slot_contents(i)
		if not contents.is_empty() and contents["item_id"] == "iron_ore":
			idx = i
			break
	_inventory.set_slot_locked(idx, true)

	var consumed: int = _inventory.consume_stackable(def, 40)

	assert_int(consumed).is_equal(0)
	var contents_after: Dictionary = _inventory.get_slot_contents(idx)
	assert_int(contents_after["quantity"]).is_equal(99)
	assert_bool(_spy.was_emitted("item_removed")).is_false()


## Regression: a locked stack of the SAME item at a LOWER index must not block
## consumption from an eligible unlocked stack at a higher index. Locks a
## slot 0-equivalent stack first (via a decoy unique item occupying slot 0 is
## not needed — add_stackable() naturally places the first "iron_ore" stack at
## the first empty slot, then a second, distinct "iron_ore" stack is forced
## into a later slot by locking the first before adding more).
func test_consume_stackable_skips_locked_lower_index_slot_and_succeeds_against_unlocked_higher_index_slot() -> void:
	var def := _make_stackable_definition(&"iron_ore", &"Material")

	# First stack lands in the first empty slot (index 0 on a fresh Inventory).
	_inventory.add_stackable(def, 20)
	var locked_idx: int = -1
	for i: int in range(_inventory.get_slot_count()):
		var contents: Dictionary = _inventory.get_slot_contents(i)
		if not contents.is_empty() and contents["item_id"] == "iron_ore":
			locked_idx = i
			break
	assert_int(locked_idx).is_equal(0)
	_inventory.set_slot_locked(locked_idx, true)

	# Locking prevents add_stackable() from merging into it (Story 004), so
	# this second add opens a fresh, higher-index slot for the same item_id.
	_inventory.add_stackable(def, 50)
	var unlocked_idx: int = -1
	for i: int in range(_inventory.get_slot_count()):
		if i == locked_idx:
			continue
		var contents: Dictionary = _inventory.get_slot_contents(i)
		if not contents.is_empty() and contents["item_id"] == "iron_ore":
			unlocked_idx = i
			break
	assert_int(unlocked_idx).is_greater(locked_idx)

	var consumed: int = _inventory.consume_stackable(def, 40)

	assert_int(consumed).is_equal(40)
	# Locked, lower-index slot is completely untouched.
	var locked_contents: Dictionary = _inventory.get_slot_contents(locked_idx)
	assert_int(locked_contents["quantity"]).is_equal(20)
	assert_bool(locked_contents["locked"]).is_true()
	# Unlocked, higher-index slot absorbed the full consumption.
	var unlocked_contents: Dictionary = _inventory.get_slot_contents(unlocked_idx)
	assert_int(unlocked_contents["quantity"]).is_equal(10)
	assert_bool(_spy.was_emitted("item_removed")).is_true()
	var args: Array = (_spy.emissions["item_removed"] as Array)[0]
	assert_int(args[2]).is_equal(40)


## Two UNLOCKED slots of the same item_id where neither alone holds enough,
## but the sum across both would — must still be rejected outright. Proves
## single-slot-only is a deliberate, tested boundary, not just an untested
## side effect of the locked-skip fix above.
func test_consume_stackable_two_unlocked_slots_not_aggregated_rejected() -> void:
	var def := _make_stackable_definition(&"iron_ore")

	# Fill slot A to its stack cap (99), forcing overflow into slot B for the
	# remainder — two distinct unlocked "iron_ore" stacks, neither of which
	# alone holds 130.
	_inventory.add_stackable(def, 99)
	_inventory.add_stackable(def, 31)

	var matching_indices: Array[int] = []
	for i: int in range(_inventory.get_slot_count()):
		var contents: Dictionary = _inventory.get_slot_contents(i)
		if not contents.is_empty() and contents["item_id"] == "iron_ore":
			matching_indices.append(i)
	assert_int(matching_indices.size()).is_equal(2)

	var consumed: int = _inventory.consume_stackable(def, 130)

	assert_int(consumed).is_equal(0)
	assert_bool(_spy.was_emitted("item_removed")).is_false()
	# Neither slot was touched.
	for idx: int in matching_indices:
		var contents: Dictionary = _inventory.get_slot_contents(idx)
		assert_bool(contents["quantity"] == 99 or contents["quantity"] == 31).is_true()


# ---------------------------------------------------------------------------
# Not-found / not-stackable rejection
# ---------------------------------------------------------------------------

func test_consume_stackable_item_not_found_rejected() -> void:
	var def := _make_stackable_definition(&"iron_ore")

	var consumed: int = _inventory.consume_stackable(def, 1)

	assert_int(consumed).is_equal(0)
	assert_bool(_spy.was_emitted("item_removed")).is_false()


func test_consume_stackable_unique_instance_definition_rejected() -> void:
	var def := _make_unique_definition(&"iron_sword")
	_inventory.add_unique_item(def)

	var consumed: int = _inventory.consume_stackable(def, 1)

	assert_int(consumed).is_equal(0)
	assert_bool(_spy.was_emitted("item_removed")).is_false()


func test_consume_stackable_null_definition_rejected() -> void:
	var consumed: int = _inventory.consume_stackable(null, 1)

	assert_int(consumed).is_equal(0)
	assert_bool(_spy.was_emitted("item_removed")).is_false()


# ---------------------------------------------------------------------------
# Insufficient-quantity rejection — all-or-nothing, no partial consumption
# ---------------------------------------------------------------------------

func test_consume_stackable_insufficient_quantity_rejected_no_partial_consumption() -> void:
	var def := _make_stackable_definition(&"iron_ore")
	_inventory.add_stackable(def, 30)

	var idx: int = -1
	for i: int in range(_inventory.get_slot_count()):
		var contents: Dictionary = _inventory.get_slot_contents(i)
		if not contents.is_empty() and contents["item_id"] == "iron_ore":
			idx = i
			break

	var consumed: int = _inventory.consume_stackable(def, 40)

	assert_int(consumed).is_equal(0)
	var contents_after: Dictionary = _inventory.get_slot_contents(idx)
	assert_int(contents_after["quantity"]).is_equal(30)  # unchanged, not clamped to 0/partial
	assert_bool(_spy.was_emitted("item_removed")).is_false()


func test_consume_stackable_zero_or_negative_quantity_rejected() -> void:
	var def := _make_stackable_definition(&"iron_ore")
	_inventory.add_stackable(def, 10)

	assert_int(_inventory.consume_stackable(def, 0)).is_equal(0)
	assert_int(_inventory.consume_stackable(def, -5)).is_equal(0)
	assert_bool(_spy.was_emitted("item_removed")).is_false()


# ---------------------------------------------------------------------------
# Index stability across the whole array — not just the target slot
# ---------------------------------------------------------------------------

func test_consume_stackable_does_not_change_any_other_slot_index() -> void:
	var target_def := _make_stackable_definition(&"iron_ore")
	var other_def_a := _make_unique_definition(&"iron_sword")
	var other_def_b := _make_stackable_definition(&"silver_ingot")

	# Fill several slots in a known layout: [unique, target(stackable), other stackable]
	var idx_a: int = _inventory.add_unique_item(other_def_a)
	_inventory.add_stackable(target_def, 99)
	var idx_target: int = -1
	for i: int in range(_inventory.get_slot_count()):
		var contents: Dictionary = _inventory.get_slot_contents(i)
		if not contents.is_empty() and contents["item_id"] == "iron_ore":
			idx_target = i
			break
	_inventory.add_stackable(other_def_b, 12)
	var idx_b: int = -1
	for i: int in range(_inventory.get_slot_count()):
		var contents: Dictionary = _inventory.get_slot_contents(i)
		if not contents.is_empty() and contents["item_id"] == "silver_ingot":
			idx_b = i
			break

	# Snapshot every slot's item_id before consumption.
	var before_snapshot: Array[String] = []
	for i: int in range(_inventory.get_slot_count()):
		var contents: Dictionary = _inventory.get_slot_contents(i)
		before_snapshot.append(contents.get("item_id", "") as String)

	_inventory.consume_stackable(target_def, 40)

	for i: int in range(_inventory.get_slot_count()):
		var contents: Dictionary = _inventory.get_slot_contents(i)
		var current_id: String = contents.get("item_id", "") as String
		if i == idx_target:
			assert_str(current_id).is_equal("iron_ore")
			assert_int(contents["quantity"]).is_equal(59)
		else:
			assert_str(current_id).is_equal(before_snapshot[i])

	# Sanity: the unrelated slots are exactly where they were placed.
	var contents_a: Dictionary = _inventory.get_slot_contents(idx_a)
	assert_that(contents_a["item_id"]).is_equal("iron_sword")
	var contents_b: Dictionary = _inventory.get_slot_contents(idx_b)
	assert_that(contents_b["item_id"]).is_equal("silver_ingot")
	assert_int(contents_b["quantity"]).is_equal(12)
