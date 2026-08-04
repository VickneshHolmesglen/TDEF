## Integration tests for Story 003 (epic-13-encyclopedia): Persistence and
## Restore-Order Safety -- AC Group 4 + remainder of Group 5 (Interactions
## table, Edge Cases).
##
## Uses real scene instantiation (`add_child()`) exercising the real
## GEventBus/GSavePersistence -- not mocked.
extends GdUnitTestSuite

var _encyclopedia: Encyclopedia


func before_test() -> void:
	# Flush any deferred GEventBus emit still in flight from an earlier test
	# (ADR-0001 Rule 2 deferred-dispatch convention, event_bus.gd) BEFORE
	# connecting a fresh Encyclopedia below -- otherwise a stale queued
	# .emit.call_deferred() from a prior suite can resolve against THIS
	# instance instead of whichever instance was live when it was queued,
	# inflating this test's ledger (and anything saved/restored from it)
	# with entries it never itself caused. CI-only flake (2026-08-05): see
	# discovery-event-ingestion_test.gd's identical fix for the full
	# root-cause writeup.
	await get_tree().process_frame
	_encyclopedia = Encyclopedia.new()
	add_child(_encyclopedia)


func after_test() -> void:
	if _encyclopedia != null and is_instance_valid(_encyclopedia):
		_encyclopedia.free()
	_encyclopedia = null


# ---------------------------------------------------------------------------
# AC-12: full multi-category round-trip.
# ---------------------------------------------------------------------------

func test_save_then_restore_round_trips_entries_across_multiple_categories() -> void:
	GEventBus.creature_acquired.emit(1, "glimmer_hare")
	GEventBus.tech_unlocked.emit("watchtower_tier_2", "defense")
	GEventBus.recipe_discovered.emit("iron_plate", "hero_equipment")
	var saved_data: Dictionary = _encyclopedia.get_save_data()

	var fresh := Encyclopedia.new()
	add_child(fresh)
	var restore_ok: bool = fresh.restore_save_data(saved_data)

	assert_bool(restore_ok).is_true()
	assert_int(fresh.get_entries().size()).is_equal(3)
	assert_bool(fresh.is_discovered("creature", "glimmer_hare")).is_true()
	assert_bool(fresh.is_discovered("tech", "watchtower_tier_2")).is_true()
	assert_bool(fresh.is_discovered("recipe", "iron_plate")).is_true()

	# discovered_at must round-trip identically, not just entry presence.
	var original_entry: Dictionary = _encyclopedia.get_entries("tech")[0]
	var restored_entry: Dictionary = fresh.get_entries("tech")[0]
	assert_int(restored_entry.discovered_at).is_equal(original_entry.discovered_at)

	fresh.free()


# ---------------------------------------------------------------------------
# AC-13: fresh save reports 0 entries across every category.
# ---------------------------------------------------------------------------

func test_reset_to_defaults_produces_zero_entries_in_every_category() -> void:
	GEventBus.skill_unlocked.emit("phys_cleave", 1)

	_encyclopedia.reset_to_defaults()

	for category: String in ["skill", "constellation_rune", "tarot_rune", "recipe", "creature", "tech"]:
		assert_int(_encyclopedia.get_category_count(category)).is_equal(0)


## Defense-in-depth against a corrupted/hand-edited save (flagged during
## code review, matching the same bug class already found and fixed in
## Menagerie's own restore_save_data()): a malformed payload must be
## rejected outright, with no partial-restore side effects, not silently
## coerced or allowed to throw a runtime type error.
func test_restore_rejects_malformed_entries_array_without_a_partial_restore() -> void:
	GEventBus.skill_unlocked.emit("phys_cleave", 1)

	var ok: bool = _encyclopedia.restore_save_data({"entries": "not_an_array"})

	assert_bool(ok).is_false()
	# Original ledger untouched -- a rejected payload has no side effects.
	assert_bool(_encyclopedia.is_discovered("skill", "phys_cleave")).is_true()


func test_restore_rejects_entries_containing_a_non_dictionary_element() -> void:
	var ok: bool = _encyclopedia.restore_save_data({"entries": [{"category": "skill", "entry_id": "phys_cleave", "discovered_at": 100}, "not_a_dict"]})

	assert_bool(ok).is_false()


func test_restore_rejects_an_entry_with_wrong_field_types() -> void:
	var ok: bool = _encyclopedia.restore_save_data({"entries": [{"category": "skill", "entry_id": "phys_cleave", "discovered_at": "not_a_number"}]})

	assert_bool(ok).is_false()


func test_restore_with_empty_entries_matches_reset_to_defaults() -> void:
	GEventBus.skill_unlocked.emit("phys_cleave", 1)

	_encyclopedia.restore_save_data({"entries": []})

	assert_int(_encyclopedia.get_entries().size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-15a: restore never re-fires inbound events, never emits
# encyclopedia_entry_added for entries the save data already contains.
# ---------------------------------------------------------------------------

func test_restore_does_not_reemit_any_inbound_discovery_event() -> void:
	GEventBus.creature_acquired.emit(1, "glimmer_hare")
	var saved_data: Dictionary = _encyclopedia.get_save_data()

	var spy := EventBusSpy.new()
	spy.watch(GEventBus.creature_acquired)
	spy.watch(GEventBus.tech_unlocked)
	spy.watch(GEventBus.skill_unlocked)

	var fresh := Encyclopedia.new()
	add_child(fresh)
	fresh.restore_save_data(saved_data)

	assert_bool(spy.was_emitted("creature_acquired")).is_false()
	assert_bool(spy.was_emitted("tech_unlocked")).is_false()
	assert_bool(spy.was_emitted("skill_unlocked")).is_false()

	spy.disconnect_all()
	fresh.free()


func test_restore_does_not_emit_encyclopedia_entry_added_for_restored_entries() -> void:
	GEventBus.tech_unlocked.emit("watchtower_tier_2", "defense")
	var saved_data: Dictionary = _encyclopedia.get_save_data()

	var spy := EventBusSpy.new()
	spy.watch(GEventBus.encyclopedia_entry_added)

	var fresh := Encyclopedia.new()
	add_child(fresh)
	fresh.restore_save_data(saved_data)

	assert_bool(spy.was_emitted("encyclopedia_entry_added")).is_false()

	spy.disconnect_all()
	fresh.free()


func test_repeated_restore_of_the_same_data_never_reemits_encyclopedia_entry_added() -> void:
	GEventBus.tech_unlocked.emit("watchtower_tier_2", "defense")
	var saved_data: Dictionary = _encyclopedia.get_save_data()
	_encyclopedia.restore_save_data(saved_data)

	var spy := EventBusSpy.new()
	spy.watch(GEventBus.encyclopedia_entry_added)

	_encyclopedia.restore_save_data(saved_data)

	assert_bool(spy.was_emitted("encyclopedia_entry_added")).is_false()
	spy.disconnect_all()


# ---------------------------------------------------------------------------
# AC-15b: a real save/restore cycle across Encyclopedia + 2 upstream
# systems does not cause either upstream system to fire a live discovery
# event as a side effect of its own restore.
# ---------------------------------------------------------------------------

func test_full_save_restore_cycle_does_not_cause_upstream_systems_to_refire_discovery_events() -> void:
	# Constellation and Tarot are scene-instanced (not Autoloads) -- real
	# instances added to the tree, matching their own test suites' own
	# convention.
	var constellation := Constellation.new()
	add_child(constellation)
	var tarot := Tarot.new()
	add_child(tarot)

	# Real upstream discovery, real Encyclopedia entry as a side effect.
	GEventBus.constellation_rune_discovered.emit("rune_of_embers", "pattern_a")
	GEventBus.tarot_rune_discovered.emit("rune_of_frost", "card_the_hermit")
	assert_bool(_encyclopedia.is_discovered("constellation_rune", "rune_of_embers")).is_true()
	assert_bool(_encyclopedia.is_discovered("tarot_rune", "rune_of_frost")).is_true()

	var constellation_save: Dictionary = constellation.get_save_data()
	var tarot_save: Dictionary = tarot.get_save_data()
	var encyclopedia_save: Dictionary = _encyclopedia.get_save_data()

	var spy := EventBusSpy.new()
	spy.watch(GEventBus.constellation_rune_discovered)
	spy.watch(GEventBus.tarot_rune_discovered)

	# Real restore against real instances -- the upstream side of the
	# "not a race" claim (Edge Cases) is jointly owned with these systems'
	# own restore behavior, not something Encyclopedia can prove alone.
	constellation.restore_save_data(constellation_save)
	tarot.restore_save_data(tarot_save)
	_encyclopedia.restore_save_data(encyclopedia_save)

	assert_bool(spy.was_emitted("constellation_rune_discovered")).is_false()
	assert_bool(spy.was_emitted("tarot_rune_discovered")).is_false()

	spy.disconnect_all()
	constellation.free()
	tarot.free()
