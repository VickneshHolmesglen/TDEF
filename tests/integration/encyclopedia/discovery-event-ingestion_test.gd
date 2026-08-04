## Integration tests for Story 001 (epic-13-encyclopedia): Discovery Event
## Ingestion -- AC Groups 1-2 (Core Rules 1, 3, 8).
##
## Uses real scene instantiation (`add_child()`) exercising the real
## GEventBus -- not mocked.
extends GdUnitTestSuite

var _encyclopedia: Encyclopedia


func before_test() -> void:
	# Flush any deferred GEventBus emit still in flight from an earlier test
	# (ADR-0001 Rule 2 deferred-dispatch convention, event_bus.gd) BEFORE
	# connecting a fresh Encyclopedia below -- otherwise a stale queued
	# .emit.call_deferred() from a prior suite can resolve against THIS
	# instance instead of whichever instance was live when it was queued,
	# inflating this test's ledger with entries it never itself caused.
	# CI-only flake (2026-08-05): passes 100% locally on Windows but fails
	# reliably on the Linux GitHub Actions runner, where slower/different
	# frame-timing gives stale deferred calls more opportunity to land in
	# the wrong test's window -- same root cause across this file,
	# persistence-and-restore-order-safety_test.gd, and
	# wave_manager_config_loading_test.gd.
	await get_tree().process_frame
	_encyclopedia = Encyclopedia.new()
	add_child(_encyclopedia)


func after_test() -> void:
	if _encyclopedia != null and is_instance_valid(_encyclopedia):
		_encyclopedia.free()
	_encyclopedia = null


# ---------------------------------------------------------------------------
# AC-1 to AC-7: each category's mapped event creates exactly one entry.
# ---------------------------------------------------------------------------

func test_skill_unlocked_adds_one_skill_entry() -> void:
	GEventBus.skill_unlocked.emit("phys_cleave", 42)

	assert_int(_encyclopedia.get_category_count("skill")).is_equal(1)
	assert_bool(_encyclopedia.is_discovered("skill", "phys_cleave")).is_true()


func test_constellation_rune_discovered_adds_one_entry() -> void:
	GEventBus.constellation_rune_discovered.emit("rune_of_embers", "pattern_a")

	assert_int(_encyclopedia.get_category_count("constellation_rune")).is_equal(1)
	assert_bool(_encyclopedia.is_discovered("constellation_rune", "rune_of_embers")).is_true()


func test_tarot_rune_discovered_adds_one_entry() -> void:
	GEventBus.tarot_rune_discovered.emit("rune_of_frost", "card_the_hermit")

	assert_int(_encyclopedia.get_category_count("tarot_rune")).is_equal(1)
	assert_bool(_encyclopedia.is_discovered("tarot_rune", "rune_of_frost")).is_true()


func test_recipe_discovered_adds_one_entry_with_exactly_3_keys_and_no_category_field() -> void:
	# TEMPORARY DIAGNOSTIC (2026-08-05) -- CI-only failure investigation.
	# Remove once root cause is found. Dumps: how many listeners are on the
	# real recipe_discovered signal right before this test's own single
	# emit(), who they are (instance id / class / validity), and what
	# actually landed in this supposedly-fresh _encyclopedia's ledger.
	var conns: Array = GEventBus.recipe_discovered.get_connections()
	print("DIAG conns.size()=", conns.size())
	for c: Dictionary in conns:
		var target: Object = c.get("callable", Callable()).get_object()
		print("DIAG conn target=", target, " valid=", is_instance_valid(target),
			" class=", (target.get_class() if is_instance_valid(target) else "?"),
			" id=", (target.get_instance_id() if is_instance_valid(target) else -1))
	print("DIAG this _encyclopedia id=", _encyclopedia.get_instance_id())

	GEventBus.recipe_discovered.emit("iron_plate", "hero_equipment")

	print("DIAG post-emit entries=", _encyclopedia.get_entries())

	assert_int(_encyclopedia.get_category_count("recipe")).is_equal(1)
	var entries: Array = _encyclopedia.get_entries("recipe")
	var entry: Dictionary = entries[0]
	assert_array(entry.keys()).contains_exactly_in_any_order("category", "entry_id", "discovered_at")
	assert_bool(entry.has("recipe_category")).is_false()


func test_creature_acquired_adds_a_species_keyed_entry_not_instance_keyed() -> void:
	GEventBus.creature_acquired.emit(101, "glimmer_hare")

	assert_int(_encyclopedia.get_category_count("creature")).is_equal(1)
	assert_bool(_encyclopedia.is_discovered("creature", "glimmer_hare")).is_true()
	assert_bool(_encyclopedia.is_discovered("creature", "101")).is_false()


func test_creature_bred_adds_a_species_keyed_entry() -> void:
	GEventBus.creature_bred.emit(202, "moss_stag")

	assert_int(_encyclopedia.get_category_count("creature")).is_equal(1)
	assert_bool(_encyclopedia.is_discovered("creature", "moss_stag")).is_true()


func test_tech_unlocked_adds_one_entry() -> void:
	GEventBus.tech_unlocked.emit("watchtower_tier_2", "defense")

	assert_int(_encyclopedia.get_category_count("tech")).is_equal(1)
	assert_bool(_encyclopedia.is_discovered("tech", "watchtower_tier_2")).is_true()


# ---------------------------------------------------------------------------
# AC-8: a second individual of an already-discovered species is a no-op.
# ---------------------------------------------------------------------------

func test_second_bred_individual_of_a_discovered_species_does_not_add_a_new_entry() -> void:
	GEventBus.creature_acquired.emit(1, "glimmer_hare")
	var first_entries: Array = _encyclopedia.get_entries("creature")
	var first_discovered_at: int = first_entries[0].discovered_at

	GEventBus.creature_bred.emit(2, "glimmer_hare")

	assert_int(_encyclopedia.get_category_count("creature")).is_equal(1)
	var entries_after: Array = _encyclopedia.get_entries("creature")
	assert_int(entries_after[0].discovered_at).is_equal(first_discovered_at)


func test_second_acquired_individual_of_a_discovered_species_is_also_a_no_op() -> void:
	GEventBus.creature_bred.emit(1, "moss_stag")

	GEventBus.creature_acquired.emit(2, "moss_stag")

	assert_int(_encyclopedia.get_category_count("creature")).is_equal(1)


# ---------------------------------------------------------------------------
# AC-9: any duplicate (category, entry_id) discovery is a no-op.
# ---------------------------------------------------------------------------

func test_duplicate_skill_unlocked_does_not_change_ledger_size() -> void:
	GEventBus.skill_unlocked.emit("phys_cleave", 42)

	GEventBus.skill_unlocked.emit("phys_cleave", 99)

	assert_int(_encyclopedia.get_category_count("skill")).is_equal(1)


func test_duplicate_tech_unlocked_does_not_change_ledger_size() -> void:
	GEventBus.tech_unlocked.emit("watchtower_tier_2", "defense")

	GEventBus.tech_unlocked.emit("watchtower_tier_2", "defense")

	assert_int(_encyclopedia.get_category_count("tech")).is_equal(1)
