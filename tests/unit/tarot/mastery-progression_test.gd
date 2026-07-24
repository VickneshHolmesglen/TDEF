## Unit tests for Story 003 (TR-tarot-002, ADR-0027): mastery XP accrual on
## mission end (Rule 10/EC-5, no outcome gate), Formula F6's tier lookup,
## Formula F1's mastery scaling, and the tier-up-affects-magnitude-only
## guarantee.
##
## Tarot is instantiated directly (Tarot.new(), no add_child()) — handler
## methods called directly, matching Stories 001-002's own convention.
extends GdUnitTestSuite

var _tarot: Tarot
var _spy: EventBusSpy


func before_test() -> void:
	_tarot = Tarot.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.mission_modifier_applied)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _tarot != null and is_instance_valid(_tarot):
		_tarot.free()
	_tarot = null


func _unlock_and_equip(card_id: StringName) -> bool:
	_tarot._card_unlocked[card_id] = true
	return _tarot.equip_card(card_id)


# ---------------------------------------------------------------------------
# AC-21: mastery_missions_played increments by exactly 1 on MISSION_COMPLETE.
# ---------------------------------------------------------------------------

func test_mission_complete_increments_mastery_by_exactly_1() -> void:
	_unlock_and_equip(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)

	_tarot._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)

	assert_int(_tarot.get_mastery_missions_played(&"iron_resolve")).is_equal(1)


# ---------------------------------------------------------------------------
# AC-22: mastery persists through DEFEAT, byte-identical to MISSION_COMPLETE.
# ---------------------------------------------------------------------------

func test_defeat_increments_mastery_identically_to_mission_complete() -> void:
	_unlock_and_equip(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)

	_tarot._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)

	assert_int(_tarot.get_mastery_missions_played(&"iron_resolve")).is_equal(1)


func test_both_terminal_outcomes_produce_identical_side_effects() -> void:
	var tarot_complete := Tarot.new()
	tarot_complete._card_unlocked[&"iron_resolve"] = true
	tarot_complete.equip_card(&"iron_resolve")
	tarot_complete._on_mission_launched("the_gap", PackedStringArray(), 1)
	tarot_complete._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)

	_unlock_and_equip(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	_tarot._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)

	assert_int(tarot_complete.get_mastery_missions_played(&"iron_resolve")).is_equal(
		_tarot.get_mastery_missions_played(&"iron_resolve")
	)
	tarot_complete.free()


# ---------------------------------------------------------------------------
# AC-23: a card NOT present in _active_mission_deck has no change.
# ---------------------------------------------------------------------------

func test_non_equipped_card_mastery_is_unaffected_by_mission_end() -> void:
	_unlock_and_equip(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)

	_tarot._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)

	assert_int(_tarot.get_mastery_missions_played(&"reckless_onslaught")).is_equal(0)


# ---------------------------------------------------------------------------
# AC-24: F6 boundary lookup — mastery_missions_played=10 resolves to tier 2
# (Adept), identically whether read immediately or later.
# ---------------------------------------------------------------------------

func test_f6_lookup_resolves_10_missions_played_to_tier_2() -> void:
	_tarot._mastery_missions_played[&"iron_resolve"] = 10

	assert_int(_tarot.get_mastery_tier(&"iron_resolve")).is_equal(2)
	# Read again later — recomputed each time, never cached/stale.
	assert_int(_tarot.get_mastery_tier(&"iron_resolve")).is_equal(2)


func test_f6_lookup_thresholds_are_monotonic_and_terminal_at_4() -> void:
	var expectations: Dictionary[int, int] = {
		0: 0, 2: 0, 3: 1, 7: 1, 8: 2, 14: 2, 15: 3, 24: 3, 25: 4, 100: 4,
	}
	for played: int in expectations:
		_tarot._mastery_missions_played[&"iron_resolve"] = played
		assert_int(_tarot.get_mastery_tier(&"iron_resolve")).is_equal(expectations[played])


# ---------------------------------------------------------------------------
# AC-25: F1 mastery scaling — base_modifier_value=1.30 at tier 2 (m=1.30) ->
# effective_modifier_value = 1.69.
# ---------------------------------------------------------------------------

func test_f1_scaling_computes_correct_effective_value_at_tier_2() -> void:
	_unlock_and_equip(&"swift_current")  # base_modifier_value 1.69 (Story 002's content)
	_tarot._mastery_missions_played[&"swift_current"] = 8  # tier 2

	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	_tarot._on_mission_phase_changed("", "SCOUT", 0.0)

	var args: Array = (_spy.emissions["mission_modifier_applied"] as Array)[0] as Array
	# swift_current's base_modifier_value is 1.69 (Story 002's own content
	# authoring) — at tier 2 (m=1.30): 1.69 * 1.30 = 2.197.
	assert_float(args[1] as float).is_equal_approx(1.69 * 1.30, 0.0001)


# ---------------------------------------------------------------------------
# AC-26: tier-up changes magnitude only — modifier_type unchanged, no new
# entries, deck-slot cost unchanged.
# ---------------------------------------------------------------------------

func test_tier_up_changes_only_magnitude_not_type_entries_or_slot_cost() -> void:
	_unlock_and_equip(&"iron_resolve")
	_tarot._mastery_missions_played[&"iron_resolve"] = 0  # tier 0

	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	_tarot._on_mission_phase_changed("", "SCOUT", 0.0)
	var before: Array = (_spy.emissions["mission_modifier_applied"] as Array)[0] as Array
	var slot_count_before: int = _tarot.get_active_card_count()

	_spy.clear()
	_tarot._on_mission_phase_changed("SCOUT", "MISSION_COMPLETE", 0.0)  # unlocks
	_tarot._mastery_missions_played[&"iron_resolve"] = 8  # tier 2 now

	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	_tarot._on_mission_phase_changed("", "SCOUT", 0.0)
	var after: Array = (_spy.emissions["mission_modifier_applied"] as Array)[0] as Array

	assert_int(_spy.count("mission_modifier_applied")).is_equal(1)  # still 1 entry, no new one added
	assert_str(after[0] as String).is_equal(before[0] as String)  # modifier_type unchanged
	assert_float(after[1] as float).is_not_equal(before[1] as float)  # magnitude changed
	assert_int(_tarot.get_active_card_count()).is_equal(slot_count_before)  # deck-slot cost unchanged
