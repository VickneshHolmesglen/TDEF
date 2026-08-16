extends GdUnitTestSuite

## Integration tests for mid-mission pickup rejection (Story 005, AC-15).
##
## Unlike the Logic-story tests in tests/unit/inventory/ (which instantiate
## Inventory directly and never add_child() it), this is an Integration
## story per the story file's own Type field — Inventory is add_child()'d so
## its real _ready() runs (GSavePersistence.register(), reset_to_defaults()),
## and assertions go through the REAL GEventBus.item_added /
## GEventBus.item_pickup_rejected signals via EventBusSpy, matching
## tests/integration/monster/monster_manager_wave_completed_wiring_test.gd's
## established add_child()-plus-real-signal convention rather than a direct
## method-call bypass.
##
## Calls add_unique_item()/add_stackable() directly (no live EventBus
## SUBSCRIPTION wiring into Inventory exists or is added here — Inventory
## still has zero subscriptions, matching Stories 001-004/006's precedent;
## the story's "materials_earned" / "tower component return" framing is
## illustrative real-world context only, not a code path this test exercises).

var _inventory: Inventory
var _spy: EventBusSpy


func before_test() -> void:
	_inventory = Inventory.new()
	add_child(_inventory)  # triggers _ready() — GSavePersistence.register(), reset_to_defaults()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.item_added)
	_spy.watch(GEventBus.item_pickup_rejected)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	remove_child(_inventory)  # triggers _exit_tree() — GSavePersistence.unregister()
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


func _make_stackable_definition(item_id: StringName, item_type: StringName = &"Material") -> ItemDefinitionResource:
	var def := ItemDefinitionResource.new()
	def.item_id = item_id
	def.item_type = item_type
	def.display_name = String(item_id)
	def.is_unique_instance = false
	return def


## Fills all STARTING_SLOT_COUNT (10) slots with distinct unique-instance
## items via the real public API — no direct _slots mutation — so the
## inventory is genuinely full by the same definition Story 001 established.
## Epic 08 Story 008 (ADR-0025); expanded 2026-08-16 alongside the 5->10
## equip-slot expansion: the last N of STARTING_SLOT_COUNT are now
## permanently reserved, locked Hero equipment-slot placeholders (see
## Inventory.EQUIPMENT_SLOT_INDEX) — only the discretionary indices are ever
## findable by _find_first_empty_slot(), so "full" now means filling those,
## not the full STARTING_SLOT_COUNT (computed dynamically below).
func _fill_inventory_completely() -> void:
	var discretionary_count: int = Inventory.STARTING_SLOT_COUNT - Inventory.EQUIPMENT_SLOT_NAMES.size()
	for i: int in range(discretionary_count):
		var idx: int = _inventory.add_unique_item(_make_unique_definition(StringName("filler_%d" % i)))
		assert_int(idx).is_greater_equal(0)
	_spy.clear()  # discard the filler item_added emissions — tests assert only their own scenario's emissions


# ---------------------------------------------------------------------------
# AC-15 core case: full inventory rejects a pickup via item_pickup_rejected,
# item_added does NOT fire.
# ---------------------------------------------------------------------------

func test_add_unique_item_full_inventory_emits_rejected_not_added() -> void:
	_fill_inventory_completely()

	var idx: int = _inventory.add_unique_item(_make_unique_definition(&"overflow_sword"))

	assert_int(idx).is_equal(-1)
	assert_bool(_spy.was_emitted("item_added")).is_false()
	assert_bool(_spy.was_emitted("item_pickup_rejected")).is_true()
	assert_int(_spy.count("item_pickup_rejected")).is_equal(1)

	var args: Array = (_spy.emissions["item_pickup_rejected"] as Array)[0]
	assert_str(args[0]).is_equal("overflow_sword")
	assert_str(args[1]).is_equal("Equipment")
	assert_int(args[2]).is_equal(Inventory.STACK_CAP_UNIQUE)
	assert_str(args[3]).is_equal("inventory_full")


func test_add_stackable_full_inventory_emits_rejected_not_added() -> void:
	_fill_inventory_completely()

	var leftover: int = _inventory.add_stackable(_make_stackable_definition(&"iron_ore"), 5)

	assert_int(leftover).is_equal(5)
	assert_bool(_spy.was_emitted("item_added")).is_false()
	assert_bool(_spy.was_emitted("item_pickup_rejected")).is_true()
	assert_int(_spy.count("item_pickup_rejected")).is_equal(1)

	var args: Array = (_spy.emissions["item_pickup_rejected"] as Array)[0]
	assert_str(args[0]).is_equal("iron_ore")
	assert_str(args[1]).is_equal("Material")
	assert_int(args[2]).is_equal(5)
	assert_str(args[3]).is_equal("inventory_full")


# ---------------------------------------------------------------------------
# Non-full success case: proves item_added DOES fire under normal
# conditions, so the "does not fire" assertions above are meaningful rather
# than vacuously true (item_added had never been wired into any path prior
# to this story).
# ---------------------------------------------------------------------------

func test_add_unique_item_non_full_inventory_emits_item_added() -> void:
	var idx: int = _inventory.add_unique_item(_make_unique_definition(&"iron_sword"))

	assert_int(idx).is_equal(0)
	assert_bool(_spy.was_emitted("item_added")).is_true()
	assert_bool(_spy.was_emitted("item_pickup_rejected")).is_false()

	var args: Array = (_spy.emissions["item_added"] as Array)[0]
	assert_str(args[0]).is_equal("iron_sword")
	assert_str(args[1]).is_equal("Equipment")
	assert_int(args[2]).is_equal(Inventory.STACK_CAP_UNIQUE)


func test_add_stackable_non_full_inventory_emits_item_added() -> void:
	var leftover: int = _inventory.add_stackable(_make_stackable_definition(&"iron_ore"), 40)

	assert_int(leftover).is_equal(0)
	assert_bool(_spy.was_emitted("item_added")).is_true()
	assert_bool(_spy.was_emitted("item_pickup_rejected")).is_false()

	var args: Array = (_spy.emissions["item_added"] as Array)[0]
	assert_str(args[0]).is_equal("iron_ore")
	assert_str(args[1]).is_equal("Material")
	assert_int(args[2]).is_equal(40)


# ---------------------------------------------------------------------------
# Partial-placement case: some quantity placed (item_added), some leftover
# (item_pickup_rejected) — both fire from one add_stackable() call.
# ---------------------------------------------------------------------------

## Epic 08 Story 008 (ADR-0025): only 5 discretionary indices are ever
## fillable (indices 5-9 are permanently reserved, locked Hero equipment-slot
## placeholders) — "fill all but one" now means 4 of 5, not 9 of 10.
func test_add_stackable_partial_placement_emits_both_signals() -> void:
	var discretionary_count: int = Inventory.STARTING_SLOT_COUNT - Inventory.EQUIPMENT_SLOT_NAMES.size()
	# Fill all but one discretionary slot, leaving exactly one open (cap 99 per slot).
	for i: int in range(discretionary_count - 1):
		_inventory.add_unique_item(_make_unique_definition(StringName("filler_%d" % i)))
	_spy.clear()

	var leftover: int = _inventory.add_stackable(_make_stackable_definition(&"iron_ore"), 150)

	assert_int(leftover).is_equal(51)  # 150 - 99 (the one remaining slot's cap)
	assert_bool(_spy.was_emitted("item_added")).is_true()
	assert_bool(_spy.was_emitted("item_pickup_rejected")).is_true()

	var added_args: Array = (_spy.emissions["item_added"] as Array)[0]
	assert_int(added_args[2]).is_equal(99)

	var rejected_args: Array = (_spy.emissions["item_pickup_rejected"] as Array)[0]
	assert_int(rejected_args[2]).is_equal(51)
	assert_str(rejected_args[3]).is_equal("inventory_full")


# ---------------------------------------------------------------------------
# Caller-error cases: null / wrong-type definition rejections are pre-existing
# behavior (push_error()), NOT a fullness condition — item_pickup_rejected
# must NOT fire for these.
# ---------------------------------------------------------------------------

func test_add_unique_item_null_definition_does_not_emit_rejected() -> void:
	var idx: int = _inventory.add_unique_item(null)

	assert_int(idx).is_equal(-1)
	assert_bool(_spy.was_emitted("item_pickup_rejected")).is_false()
	assert_bool(_spy.was_emitted("item_added")).is_false()


func test_add_unique_item_wrong_type_definition_does_not_emit_rejected() -> void:
	var idx: int = _inventory.add_unique_item(_make_stackable_definition(&"iron_ore"))

	assert_int(idx).is_equal(-1)
	assert_bool(_spy.was_emitted("item_pickup_rejected")).is_false()
	assert_bool(_spy.was_emitted("item_added")).is_false()


func test_add_stackable_null_definition_does_not_emit_rejected() -> void:
	var leftover: int = _inventory.add_stackable(null, 10)

	assert_int(leftover).is_equal(10)
	assert_bool(_spy.was_emitted("item_pickup_rejected")).is_false()
	assert_bool(_spy.was_emitted("item_added")).is_false()


func test_add_stackable_wrong_type_definition_does_not_emit_rejected() -> void:
	var leftover: int = _inventory.add_stackable(_make_unique_definition(&"iron_sword"), 10)

	assert_int(leftover).is_equal(10)
	assert_bool(_spy.was_emitted("item_pickup_rejected")).is_false()
	assert_bool(_spy.was_emitted("item_added")).is_false()


## TD-inv-006: a zero/negative quantity is a caller error, not a fullness
## condition — same category as the null/wrong-type cases above. Neither
## signal may fire; a malformed negative-quantity item_pickup_rejected
## payload was exactly the real risk this guard closes.
func test_add_stackable_zero_or_negative_quantity_does_not_emit_either_signal() -> void:
	var leftover: int = _inventory.add_stackable(_make_stackable_definition(&"iron_ore"), -5)

	assert_int(leftover).is_equal(-5)
	assert_bool(_spy.was_emitted("item_pickup_rejected")).is_false()
	assert_bool(_spy.was_emitted("item_added")).is_false()


# ---------------------------------------------------------------------------
# QA edge case: a rejected pickup is NOT queued — a subsequently freed slot
# does not automatically retry/deliver it.
# ---------------------------------------------------------------------------

func test_freed_slot_after_rejection_does_not_auto_retry() -> void:
	_fill_inventory_completely()

	var idx: int = _inventory.add_unique_item(_make_unique_definition(&"overflow_sword"))
	assert_int(idx).is_equal(-1)
	assert_int(_spy.count("item_pickup_rejected")).is_equal(1)
	assert_int(_spy.count("item_added")).is_equal(0)

	# Free up a slot — nothing in Inventory should react to this by
	# delivering the previously-rejected "overflow_sword".
	assert_bool(_inventory.remove_item(0)).is_true()

	# No further emissions of either signal happened purely from freeing
	# the slot — no queueing, no automatic retry.
	assert_int(_spy.count("item_pickup_rejected")).is_equal(1)
	assert_int(_spy.count("item_added")).is_equal(0)

	# A fresh, explicit pickup call now succeeds normally (proves the slot
	# really is usable — it just required a new caller-initiated attempt).
	var retry_idx: int = _inventory.add_unique_item(_make_unique_definition(&"overflow_sword"))
	assert_int(retry_idx).is_equal(0)
	assert_int(_spy.count("item_added")).is_equal(1)
	var added_args: Array = (_spy.emissions["item_added"] as Array)[0]
	assert_str(added_args[0]).is_equal("overflow_sword")
