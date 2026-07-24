## Unit tests for Story 006 (TR-tarot-001, ADR-0027): the edge cases owned
## by this story (EC-1, EC-9) — the other 2 (EC-2/EC-6, AC-37/38) are
## genuinely blocked on Wave Manager's/Monster System's own consumption-side
## aggregation logic, which does not exist yet (confirmed by inspection —
## neither subscribes to mission_modifier_applied). Not fabricated here; see
## this story's own file for the full accounting. EC-3/4/5/7/8 are already
## covered by Stories 002-005's own test files, per this story's Out of Scope.
##
## Tarot is instantiated directly (Tarot.new(), no add_child()) — handler
## methods called directly, matching this system's established convention.
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
# AC-36 (EC-1): 0 equipped cards at mission_launched — zero
# mission_modifier_applied events; previously-discovered rune bonuses
# (deck-composition-independent) still apply.
# ---------------------------------------------------------------------------

func test_zero_card_deck_emits_no_modifier_events() -> void:
	assert_int(_tarot.get_active_card_count()).is_equal(0)

	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	_tarot._on_mission_phase_changed("", "SCOUT", 0.0)

	assert_int(_spy.count("mission_modifier_applied")).is_equal(0)


func test_zero_card_deck_still_applies_previously_discovered_rune_bonus() -> void:
	# Discover a rune in an earlier mission...
	_unlock_and_equip(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	_tarot._on_mission_phase_changed("", "SCOUT", 0.0)
	_tarot._on_mission_phase_changed("SCOUT", "MISSION_COMPLETE", 0.0)
	assert_bool(_tarot.is_rune_discovered(&"rune_iron_resolve")).is_true()

	# ...then unequip everything for the next mission.
	_tarot.unequip_card(&"iron_resolve")
	assert_int(_tarot.get_active_card_count()).is_equal(0)

	# The rune's bonus is entirely deck-independent (Rule 16) — still
	# readable/applicable with a completely empty deck.
	var bonus: float = _tarot.compute_rune_bonus(&"tarot_difficulty_growth_rate")
	assert_float(bonus).is_equal_approx(0.05, 0.0001)  # iron_resolve's rune_bonus_flat default


# ---------------------------------------------------------------------------
# AC-39 (EC-9): a card whose rune is DISCOVERED, later unequipped and never
# re-equipped, still contributes its rune bonus every subsequent mission.
# ---------------------------------------------------------------------------

func test_rune_bonus_survives_permanent_unequip_across_multiple_missions() -> void:
	_unlock_and_equip(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	_tarot._on_mission_phase_changed("", "SCOUT", 0.0)
	_tarot._on_mission_phase_changed("SCOUT", "MISSION_COMPLETE", 0.0)
	assert_bool(_tarot.is_rune_discovered(&"rune_iron_resolve")).is_true()

	_tarot.unequip_card(&"iron_resolve")  # permanent — never re-equipped again

	# Mission 2 and 3, card never touched again.
	for _i in range(2):
		_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
		_tarot._on_mission_phase_changed("", "SCOUT", 0.0)
		_tarot._on_mission_phase_changed("SCOUT", "MISSION_COMPLETE", 0.0)

	assert_bool(_tarot.is_rune_discovered(&"rune_iron_resolve")).is_true()
	assert_float(_tarot.compute_rune_bonus(&"tarot_difficulty_growth_rate")).is_equal_approx(0.05, 0.0001)
	# Mastery counter froze at 1 — it only increments while equipped
	# (Rule 10), unaffected by the still-active rune bonus.
	assert_int(_tarot.get_mastery_missions_played(&"iron_resolve")).is_equal(1)

# ---------------------------------------------------------------------------
# AC-37 (EC-2) and AC-38 (EC-6) are NOT implemented in this file — deliberately,
# not by omission. Both require consumption-side logic that doesn't exist:
#
# AC-37 needs Monster System's own tarot_speed_scalar aggregation/clamp
# (the exact warning-log text is specified as something Monster System
# produces, per Story 002's own established F1-only boundary for Tarot).
#
# AC-38 needs Wave Manager's own tarot_wave_config_override consumption
# logic (discard-and-log on an invalid/missing target variant).
#
# Neither Monster System nor Wave Manager subscribes to
# mission_modifier_applied anywhere in this codebase (confirmed by
# inspection) — the same genuine downstream gap Story 002's own AC-15/17
# already flagged. No placeholder test is included for either: an empty
# passing test would misrepresent coverage that doesn't exist. Tracked in
# this story's own file instead.
# ---------------------------------------------------------------------------
