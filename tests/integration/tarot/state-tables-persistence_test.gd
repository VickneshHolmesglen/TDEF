## Integration tests for Story 007 (TR-tarot-002/003, ADR-0027): the Deck
## Lock Lifecycle and Rune Discovery Ledger state tables, and the
## SaveRestorer round-trip at restore_order=22.
##
## Tarot is instantiated directly (no add_child()) so _ready() never fires —
## GSavePersistence.register() is never called, avoiding pollution of the
## real Autoload's _registered_systems list. Round-trips call
## get_save_data()/restore_save_data() directly between two local instances,
## matching this project's established persistence-test convention
## (menagerie/persistence_test.gd, tower-mastery's own cross-mission test).
extends GdUnitTestSuite

var _tarot: Tarot


func before_test() -> void:
	_tarot = Tarot.new()


func after_test() -> void:
	if _tarot != null and is_instance_valid(_tarot):
		_tarot.free()
	_tarot = null


func _unlock_and_equip(card_id: StringName) -> bool:
	_tarot._card_unlocked[card_id] = true
	return _tarot.equip_card(card_id)


# ---------------------------------------------------------------------------
# restore_order=22 (save-persistence.md's already-assigned Feature-layer slot)
# ---------------------------------------------------------------------------

func test_restore_order_is_22() -> void:
	assert_int(Tarot.RESTORE_ORDER).is_equal(22)


# ---------------------------------------------------------------------------
# AC-40/41: Deck Lock Lifecycle — EDITABLE -> LOCKED on mission_launched,
# LOCKED -> EDITABLE on mission end (either outcome).
# ---------------------------------------------------------------------------

func test_editable_to_locked_on_mission_launched_stays_locked_through_wave_active() -> void:
	_unlock_and_equip(&"iron_resolve")

	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	assert_bool(_tarot.unequip_card(&"iron_resolve")).is_false()  # locked

	_tarot._on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)
	assert_bool(_tarot.unequip_card(&"iron_resolve")).is_false()  # still locked mid-mission


func test_locked_to_editable_on_mission_complete() -> void:
	_unlock_and_equip(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)

	_tarot._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)

	assert_bool(_tarot.unequip_card(&"iron_resolve")).is_true()  # editable again


func test_locked_to_editable_on_defeat() -> void:
	_unlock_and_equip(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)

	_tarot._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)

	assert_bool(_tarot.unequip_card(&"iron_resolve")).is_true()  # editable again


## Real bug fixed 2026-07-25: pause_menu.gd's "Quit to Sanctuary" option calls
## SceneManager.transition_to_sanctuary() directly with no mission_phase_changed
## emission -- without this handler, _locked would stay permanently true after
## a mid-mission quit. scene_transition_completed("SANCTUARY", ...) must
## unlock even when no MISSION_COMPLETE/DEFEAT ever fired.
func test_locked_to_editable_on_scene_transition_to_sanctuary_with_no_terminal_phase() -> void:
	_unlock_and_equip(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	assert_bool(_tarot.unequip_card(&"iron_resolve")).is_false()  # locked, mid-mission quit incoming

	_tarot._on_scene_transition_completed("SANCTUARY", "")

	assert_bool(_tarot.unequip_card(&"iron_resolve")).is_true()  # editable again


func test_scene_transition_to_mission_does_not_unlock() -> void:
	_unlock_and_equip(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)

	_tarot._on_scene_transition_completed("MISSION", "the_gap")

	assert_bool(_tarot.unequip_card(&"iron_resolve")).is_false()  # still locked


# ---------------------------------------------------------------------------
# AC-42: Tier 3 -> Tier 4 transition at mastery_missions_played crossing 25,
# terminal regardless of further missions.
# ---------------------------------------------------------------------------

func test_tier_3_to_tier_4_transition_at_25_missions_played() -> void:
	_tarot._mastery_missions_played[&"iron_resolve"] = 24
	assert_int(_tarot.get_mastery_tier(&"iron_resolve")).is_equal(3)

	_tarot._mastery_missions_played[&"iron_resolve"] = 25
	assert_int(_tarot.get_mastery_tier(&"iron_resolve")).is_equal(4)


func test_tier_4_is_terminal_regardless_of_further_missions() -> void:
	_tarot._mastery_missions_played[&"iron_resolve"] = 25
	assert_int(_tarot.get_mastery_tier(&"iron_resolve")).is_equal(4)

	_tarot._mastery_missions_played[&"iron_resolve"] = 100
	assert_int(_tarot.get_mastery_tier(&"iron_resolve")).is_equal(4)
	assert_float(Tarot.MASTERY_TIER_SCALARS[4]).is_equal_approx(1.75, 0.0001)


# ---------------------------------------------------------------------------
# AC-43: UNDISCOVERED default state at fresh save/playthrough start.
# ---------------------------------------------------------------------------

func test_fresh_tarot_instance_has_no_discovered_runes() -> void:
	assert_bool(_tarot.is_rune_discovered(&"rune_iron_resolve")).is_false()
	assert_float(_tarot.compute_rune_bonus(&"tarot_difficulty_growth_rate")).is_equal_approx(0.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-44: DISCOVERED state survives a save reload in a later session, never
# reverts. Full save/load round-trip across all 4 persisted structures.
# ---------------------------------------------------------------------------

func test_save_load_round_trip_preserves_all_4_ledgers() -> void:
	_unlock_and_equip(&"iron_resolve")
	_unlock_and_equip(&"reckless_onslaught")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	_tarot._on_mission_phase_changed("", "SCOUT", 0.0)
	_tarot._on_mission_phase_changed("SCOUT", "MISSION_COMPLETE", 0.0)
	assert_bool(_tarot.is_rune_discovered(&"rune_iron_resolve")).is_true()

	var data: Dictionary = _tarot.get_save_data()

	var restored := Tarot.new()
	var ok: bool = restored.restore_save_data(data)

	assert_bool(ok).is_true()
	assert_bool(restored.is_rune_discovered(&"rune_iron_resolve")).is_true()
	assert_int(restored.get_mastery_missions_played(&"iron_resolve")).is_equal(1)
	assert_bool(restored._card_unlocked.get(&"iron_resolve", false)).is_true()
	assert_bool(restored._current_deck.has(&"iron_resolve")).is_true()
	assert_bool(restored._current_deck.has(&"reckless_onslaught")).is_true()
	restored.free()


func test_active_mission_deck_is_never_persisted() -> void:
	_unlock_and_equip(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	assert_int(_tarot._active_mission_deck.size()).is_equal(1)

	var data: Dictionary = _tarot.get_save_data()

	assert_bool(data.has("active_mission_deck")).is_false()


func test_get_save_data_returns_only_primitive_types() -> void:
	_unlock_and_equip(&"iron_resolve")
	var data: Dictionary = _tarot.get_save_data()

	for key: Variant in (data["mastery_missions_played"] as Dictionary):
		assert_bool(key is String).is_true()
	for key: Variant in (data["card_unlocked"] as Dictionary):
		assert_bool(key is String).is_true()
	for entry: Variant in (data["deck_template"] as Array):
		assert_bool(entry is String).is_true()


func test_restore_save_data_rejects_malformed_payload() -> void:
	var ok: bool = _tarot.restore_save_data({
		"mastery_missions_played": "not_a_dict",
		"rune_discovered": {},
		"card_unlocked": {},
		"deck_template": [],
	})
	assert_bool(ok).is_false()


func test_reset_to_defaults_clears_all_persisted_structures() -> void:
	_unlock_and_equip(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	_tarot._on_mission_phase_changed("", "SCOUT", 0.0)
	_tarot._on_mission_phase_changed("SCOUT", "MISSION_COMPLETE", 0.0)

	_tarot.reset_to_defaults()

	assert_int(_tarot.get_mastery_missions_played(&"iron_resolve")).is_equal(0)
	assert_bool(_tarot.is_rune_discovered(&"rune_iron_resolve")).is_false()
	assert_int(_tarot.get_active_card_count()).is_equal(0)
