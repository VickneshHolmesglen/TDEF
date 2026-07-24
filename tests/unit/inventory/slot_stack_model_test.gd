## Unit tests for Inventory's slot/stack model (Story 001, ADR-0016).
## Covers AC-1, AC-2, AC-3, AC-4, AC-18 and their QA Test Cases edge cases.
##
## Inventory is instantiated directly (Inventory.new()) and reset_to_defaults()
## is called explicitly rather than add_child()-ing it — mirrors
## game_data_registry_test.gd / monster_resource_validate_test.gd's direct-call
## convention for logic that has no scene-tree dependency. This also avoids any
## GSavePersistence Autoload dependency, since _ready() (which calls
## GSavePersistence.register()) is only invoked by the engine on add_child().
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
# AC-1: fresh init exposes exactly 10 empty slots
# ---------------------------------------------------------------------------

## Epic 08 Story 008 (ADR-0025): the last 5 indices (5-9) are now permanently
## reserved, locked Hero equipment slots (Rule 5a — "locked items still
## occupy and count against the current slot cap") — only indices 0-4 are
## discretionary-empty at fresh init. See Inventory.EQUIPMENT_SLOT_INDEX.
func test_fresh_init_exposes_ten_empty_slots() -> void:
	assert_int(_inventory.get_slot_count()).is_equal(10)
	for i: int in range(5):
		assert_bool(_inventory.is_slot_empty(i)).is_true()
	for i: int in range(5, 10):
		assert_bool(_inventory.is_slot_empty(i)).is_false()  # reserved equipment slot placeholder


## AC-1 edge case: initializing twice in the same session must not double-allocate slots.
func test_reset_to_defaults_called_twice_does_not_double_allocate() -> void:
	var def := _make_stackable_definition(&"frost_silk")
	_inventory.add_stackable(def, 5)

	_inventory.reset_to_defaults()
	_inventory.reset_to_defaults()

	assert_int(_inventory.get_slot_count()).is_equal(10)
	for i: int in range(5):
		assert_bool(_inventory.is_slot_empty(i)).is_true()


# ---------------------------------------------------------------------------
# AC-2: one stack per slot invariant
# ---------------------------------------------------------------------------

func test_get_slot_contents_on_occupied_slot_returns_single_item_and_quantity() -> void:
	var def := _make_stackable_definition(&"frost_silk")
	_inventory.add_stackable(def, 7)

	var contents: Dictionary = _inventory.get_slot_contents(0)

	assert_bool(contents.is_empty()).is_false()
	assert_that(contents["item_id"]).is_equal("frost_silk")
	assert_int(contents["quantity"]).is_equal(7)


## AC-2 edge case: querying an empty slot returns a well-defined empty result, not an error.
func test_get_slot_contents_on_empty_slot_returns_empty_dictionary_not_error() -> void:
	var contents: Dictionary = _inventory.get_slot_contents(3)
	assert_that(contents).is_equal({})


func test_get_slot_contents_out_of_range_index_returns_empty_dictionary_not_error() -> void:
	var contents: Dictionary = _inventory.get_slot_contents(999)
	assert_that(contents).is_equal({})


# ---------------------------------------------------------------------------
# AC-3: unique-instance cap enforcement
# ---------------------------------------------------------------------------

func test_add_unique_item_creates_stack_with_quantity_one_and_cap_one() -> void:
	var def := _make_unique_definition(&"iron_sword")

	var slot_index: int = _inventory.add_unique_item(def, {&"damage": 12.0})

	assert_int(slot_index).is_equal(0)
	var contents: Dictionary = _inventory.get_slot_contents(slot_index)
	assert_int(contents["quantity"]).is_equal(1)
	# cap is not itself a returned field — verify cap=1 behaviorally: a second unit
	# targeting the same slot must be rejected (see test below), so quantity can
	# never exceed 1 for a unique-instance slot.


## AC-3 edge case: attempting to add a second unit of the SAME instance ID to an
## already-occupied cap=1 slot must be rejected, not silently ignored. Exercises
## the internal _try_add_to_slot() helper directly — the only code path that ever
## increments an existing slot's quantity — since add_unique_item()'s public
## contract never targets an occupied slot (it always allocates a new one).
func test_try_add_to_slot_rejects_second_unit_on_occupied_cap_one_slot() -> void:
	var def := _make_unique_definition(&"iron_sword")
	var slot_index: int = _inventory.add_unique_item(def, {&"damage": 12.0})
	var slot: InventorySlot = _inventory._slots[slot_index]
	assert_int(slot.quantity).is_equal(1)

	var added: int = _inventory._try_add_to_slot(slot, Inventory.STACK_CAP_UNIQUE, 1)

	assert_int(added).is_equal(0)
	assert_int(slot.quantity).is_equal(1)


func test_add_unique_item_rejects_non_unique_definition() -> void:
	var def := _make_stackable_definition(&"frost_silk")
	var slot_index: int = _inventory.add_unique_item(def)
	assert_int(slot_index).is_equal(-1)
	for i: int in range(5):
		assert_bool(_inventory.is_slot_empty(i)).is_true()


# ---------------------------------------------------------------------------
# AC-4: stackable overflow to new slot
# ---------------------------------------------------------------------------

func test_add_stackable_overflows_full_stack_to_new_slot() -> void:
	var def := _make_stackable_definition(&"frost_silk")
	var leftover_initial: int = _inventory.add_stackable(def, 99)
	assert_int(leftover_initial).is_equal(0)
	assert_int(_inventory.get_slot_contents(0)["quantity"]).is_equal(99)

	var leftover: int = _inventory.add_stackable(def, 1)

	assert_int(leftover).is_equal(0)
	assert_int(_inventory.get_slot_contents(0)["quantity"]).is_equal(99)
	assert_int(_inventory.get_slot_contents(1)["quantity"]).is_equal(1)
	assert_that(_inventory.get_slot_contents(1)["item_id"]).is_equal("frost_silk")


func test_add_stackable_fills_existing_partial_stack_before_opening_new_slot() -> void:
	var def := _make_stackable_definition(&"frost_silk")
	_inventory.add_stackable(def, 50)

	var leftover: int = _inventory.add_stackable(def, 10)

	assert_int(leftover).is_equal(0)
	assert_int(_inventory.get_slot_contents(0)["quantity"]).is_equal(60)
	assert_bool(_inventory.is_slot_empty(1)).is_true()


func test_add_stackable_rejects_unique_instance_definition() -> void:
	var def := _make_unique_definition(&"iron_sword")
	var leftover: int = _inventory.add_stackable(def, 3)
	assert_int(leftover).is_equal(3)
	for i: int in range(5):
		assert_bool(_inventory.is_slot_empty(i)).is_true()


# ---------------------------------------------------------------------------
# AC-18: stat-rolled duplicates never merge
# ---------------------------------------------------------------------------

func test_add_unique_item_twice_same_definition_occupies_distinct_slots_never_merge() -> void:
	var def := _make_unique_definition(&"iron_sword")

	var first_index: int = _inventory.add_unique_item(def, {&"damage": 12.0})
	var second_index: int = _inventory.add_unique_item(def, {&"damage": 18.0})

	assert_int(first_index).is_not_equal(second_index)
	assert_int(_inventory.get_slot_contents(first_index)["quantity"]).is_equal(1)
	assert_int(_inventory.get_slot_contents(second_index)["quantity"]).is_equal(1)
	var first_instance: int = _inventory.get_slot_contents(first_index)["instance_id"]
	var second_instance: int = _inventory.get_slot_contents(second_index)["instance_id"]
	assert_int(first_instance).is_not_equal(second_instance)


## AC-18 edge case: merging must be keyed on instance ID, never on stat equality —
## verify this holds even when the two rolls produce byte-identical stat blocks.
func test_add_unique_item_twice_with_identical_stat_overrides_still_never_merge() -> void:
	var def := _make_unique_definition(&"iron_sword")
	var identical_stats: Dictionary[StringName, float] = {&"damage": 12.0, &"crit_chance": 0.05}

	var first_index: int = _inventory.add_unique_item(def, identical_stats)
	var second_index: int = _inventory.add_unique_item(def, identical_stats)

	assert_int(first_index).is_not_equal(second_index)
	var first_instance: int = _inventory.get_slot_contents(first_index)["instance_id"]
	var second_instance: int = _inventory.get_slot_contents(second_index)["instance_id"]
	assert_int(first_instance).is_not_equal(second_instance)
	# Stat blocks are byte-identical by construction here — proves non-merge is
	# NOT keyed on stat comparison.
	assert_that(_inventory.get_slot_contents(first_index)["stat_overrides"]).is_equal(
		_inventory.get_slot_contents(second_index)["stat_overrides"]
	)


# ---------------------------------------------------------------------------
# ADR-0016 Validation Criteria: save-data primitives + instance-id round trip
# ---------------------------------------------------------------------------

func test_get_save_data_returns_only_primitive_types() -> void:
	var unique_def := _make_unique_definition(&"iron_sword")
	var stackable_def := _make_stackable_definition(&"frost_silk")
	_inventory.add_unique_item(unique_def, {&"damage": 12.0})
	_inventory.add_stackable(stackable_def, 5)

	var data: Dictionary = _inventory.get_save_data()

	assert_bool(data.has("slots")).is_true()
	assert_bool(data.has("next_instance_id")).is_true()
	assert_bool(data["next_instance_id"] is int).is_true()
	var slots: Array = data["slots"] as Array
	assert_int(slots.size()).is_equal(10)
	for entry: Variant in slots:
		assert_bool(entry is Dictionary).is_true()
		var entry_dict: Dictionary = entry as Dictionary
		if entry_dict.is_empty():
			continue
		assert_bool(entry_dict["item_id"] is String).is_true()
		assert_bool(entry_dict["quantity"] is int).is_true()
		assert_bool(entry_dict["instance_id"] is int).is_true()
		assert_bool(entry_dict["locked"] is bool).is_true()
		var overrides: Dictionary = entry_dict["stat_overrides"] as Dictionary
		for key: Variant in overrides:
			assert_bool(key is String).is_true()
			assert_bool(overrides[key] is float).is_true()


func test_save_restore_round_trip_preserves_next_instance_id_and_slots() -> void:
	var unique_def := _make_unique_definition(&"iron_sword")
	_inventory.add_unique_item(unique_def, {&"damage": 12.0})
	_inventory.add_unique_item(unique_def, {&"damage": 18.0})
	var data: Dictionary = _inventory.get_save_data()

	var restored := Inventory.new()
	var ok: bool = restored.restore_save_data(data)

	assert_bool(ok).is_true()
	assert_int(restored.get_slot_contents(0)["instance_id"]).is_equal(0)
	assert_int(restored.get_slot_contents(1)["instance_id"]).is_equal(1)
	# Adding a third unique item after restore must not collide with restored IDs.
	var third_index: int = restored.add_unique_item(unique_def, {&"damage": 20.0})
	assert_int(restored.get_slot_contents(third_index)["instance_id"]).is_equal(2)
	restored.free()


func test_restore_save_data_rejects_malformed_data_and_returns_false() -> void:
	var ok: bool = _inventory.restore_save_data({"slots": "not_an_array", "next_instance_id": 0})
	assert_bool(ok).is_false()

	var ok_missing_key: bool = _inventory.restore_save_data({"slots": []})
	assert_bool(ok_missing_key).is_false()
