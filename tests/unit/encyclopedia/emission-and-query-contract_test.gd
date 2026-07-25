## Unit tests for Story 002 (epic-13-encyclopedia): Emission and Query
## Contract -- AC Group 3 + part of Group 5 (Core Rules 2, 4).
##
## Encyclopedia is instantiated directly (`Encyclopedia.new()`, no
## `add_child()`) so `_ready()` never fires and no real EventBus subscription
## exists -- this suite drives entries directly via `_try_add_entry()`
## (an internal call, matching this project's own direct-instantiation Logic
## test convention) so it can assert purely on the emission/query surface
## without depending on Story 001's own event-wiring being correct too.
extends GdUnitTestSuite

var _encyclopedia: Encyclopedia
var _spy: EventBusSpy


func before_test() -> void:
	_encyclopedia = Encyclopedia.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.encyclopedia_entry_added)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _encyclopedia != null and is_instance_valid(_encyclopedia):
		_encyclopedia.free()
	_encyclopedia = null


# ---------------------------------------------------------------------------
# AC-10/AC-11: encyclopedia_entry_added emission contract.
# ---------------------------------------------------------------------------

func test_genuinely_new_entry_emits_encyclopedia_entry_added_exactly_once() -> void:
	_encyclopedia._try_add_entry("skill", "phys_cleave")

	assert_int(_spy.count("encyclopedia_entry_added")).is_equal(1)
	assert_array(_spy.emissions["encyclopedia_entry_added"][0]).contains_exactly("skill", "phys_cleave")


func test_duplicate_entry_does_not_emit_encyclopedia_entry_added_again() -> void:
	_encyclopedia._try_add_entry("tech", "watchtower_tier_2")

	_encyclopedia._try_add_entry("tech", "watchtower_tier_2")

	assert_int(_spy.count("encyclopedia_entry_added")).is_equal(1)


func test_two_different_categories_each_emit_their_own_added_event() -> void:
	_encyclopedia._try_add_entry("creature", "glimmer_hare")
	_encyclopedia._try_add_entry("recipe", "iron_plate")

	assert_int(_spy.count("encyclopedia_entry_added")).is_equal(2)


# ---------------------------------------------------------------------------
# AC-14: get_entries() is generic across all categories.
# ---------------------------------------------------------------------------

func test_get_entries_with_no_argument_returns_entries_from_all_categories() -> void:
	_encyclopedia._try_add_entry("constellation_rune", "rune_of_embers")
	_encyclopedia._try_add_entry("creature", "glimmer_hare")
	_encyclopedia._try_add_entry("tech", "watchtower_tier_2")

	var all_entries: Array = _encyclopedia.get_entries()

	assert_int(all_entries.size()).is_equal(3)


func test_get_entries_filtered_by_category_returns_only_that_category() -> void:
	_encyclopedia._try_add_entry("creature", "glimmer_hare")
	_encyclopedia._try_add_entry("creature", "moss_stag")
	_encyclopedia._try_add_entry("tech", "watchtower_tier_2")

	var creature_entries: Array = _encyclopedia.get_entries("creature")

	assert_int(creature_entries.size()).is_equal(2)


func test_is_discovered_returns_true_for_known_and_false_for_unknown() -> void:
	_encyclopedia._try_add_entry("skill", "phys_cleave")

	assert_bool(_encyclopedia.is_discovered("skill", "phys_cleave")).is_true()
	assert_bool(_encyclopedia.is_discovered("skill", "never_unlocked")).is_false()
	assert_bool(_encyclopedia.is_discovered("tech", "phys_cleave")).is_false()


# ---------------------------------------------------------------------------
# AC-16: every entry's persisted shape is exactly 3 keys, no more/fewer.
# ---------------------------------------------------------------------------

func test_every_entry_has_exactly_3_keys_regardless_of_category() -> void:
	_encyclopedia._try_add_entry("recipe", "iron_plate")
	_encyclopedia._try_add_entry("creature", "glimmer_hare")
	_encyclopedia._try_add_entry("tarot_rune", "rune_of_frost")

	for entry: Dictionary in _encyclopedia.get_entries():
		assert_int(entry.keys().size()).is_equal(3)
		assert_bool(entry.has("category")).is_true()
		assert_bool(entry.has("entry_id")).is_true()
		assert_bool(entry.has("discovered_at")).is_true()
