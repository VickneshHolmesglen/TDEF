## Unit tests for Story 004 (TR-tarot-003, ADR-0027): rune discovery firing
## on first-ever mission attempt, one-way-terminal Discovery Ledger
## semantics, and deck-independence of a discovered rune's state.
##
## AC-30/31's actual Formula F5 bonus-aggregation math is Story 005's own
## scope (this story's Out of Scope section) — the tests below verify the
## data-level guarantees this story is actually responsible for: a
## discovered rune's flag is readable independent of current equip state
## (AC-30), and a card's own Group 3 effect is never suppressed by rune
## discovery (AC-31's "neither suppresses the other" half, at the emission
## level Story 002 already built).
##
## Tarot is instantiated directly (Tarot.new(), no add_child()) — handler
## methods called directly, matching Stories 001-003's own convention.
extends GdUnitTestSuite

var _tarot: Tarot
var _spy: EventBusSpy


func before_test() -> void:
	_tarot = Tarot.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.mission_modifier_applied)
	_spy.watch(GEventBus.tarot_rune_discovered)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _tarot != null and is_instance_valid(_tarot):
		_tarot.free()
	_tarot = null


func _unlock_and_equip(card_id: StringName) -> bool:
	_tarot._card_unlocked[card_id] = true
	return _tarot.equip_card(card_id)


func _run_mission(outcome: String) -> void:
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	_tarot._on_mission_phase_changed("", "SCOUT", 0.0)
	_tarot._on_mission_phase_changed("SCOUT", outcome, 0.0)


# ---------------------------------------------------------------------------
# AC-27: an unequipped card fires no mission_modifier_applied at SCOUT entry.
# ---------------------------------------------------------------------------

func test_unequipped_card_fires_no_modifier_at_scout_entry() -> void:
	# iron_resolve is never equipped in this test.
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	_tarot._on_mission_phase_changed("", "SCOUT", 0.0)

	assert_int(_spy.count("mission_modifier_applied")).is_equal(0)


# ---------------------------------------------------------------------------
# AC-28: first-ever mission attempt with a card equipped fires
# tarot_rune_discovered exactly once, ledger transitions to DISCOVERED.
# ---------------------------------------------------------------------------

func test_first_mission_attempt_fires_rune_discovered_exactly_once() -> void:
	_unlock_and_equip(&"iron_resolve")
	assert_bool(_tarot.is_rune_discovered(&"rune_iron_resolve")).is_false()

	_run_mission("MISSION_COMPLETE")

	assert_int(_spy.count("tarot_rune_discovered")).is_equal(1)
	var args: Array = (_spy.emissions["tarot_rune_discovered"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal("rune_iron_resolve")
	assert_str(args[1] as String).is_equal("iron_resolve")
	assert_bool(_tarot.is_rune_discovered(&"rune_iron_resolve")).is_true()


func test_first_mission_attempt_via_defeat_also_discovers() -> void:
	_unlock_and_equip(&"iron_resolve")

	_run_mission("DEFEAT")

	assert_int(_spy.count("tarot_rune_discovered")).is_equal(1)
	assert_bool(_tarot.is_rune_discovered(&"rune_iron_resolve")).is_true()


# ---------------------------------------------------------------------------
# AC-29: an already-DISCOVERED rune never re-fires, regardless of further
# mission attempts.
# ---------------------------------------------------------------------------

func test_discovered_rune_never_refires_on_subsequent_attempts() -> void:
	_unlock_and_equip(&"iron_resolve")
	_run_mission("MISSION_COMPLETE")
	assert_int(_spy.count("tarot_rune_discovered")).is_equal(1)

	# Mission 2: same card, still equipped (deck unlocked after mission end).
	_run_mission("MISSION_COMPLETE")
	# Mission 3: DEFEAT this time.
	_run_mission("DEFEAT")

	assert_int(_spy.count("tarot_rune_discovered")).is_equal(1)
	assert_int(_tarot.get_mastery_missions_played(&"iron_resolve")).is_equal(3)


# ---------------------------------------------------------------------------
# AC-30: a DISCOVERED rune's state is readable independent of whether its
# card is currently equipped (Formula F5's own bonus math is Story 005's scope).
# ---------------------------------------------------------------------------

func test_discovered_rune_state_persists_after_card_is_unequipped() -> void:
	_unlock_and_equip(&"iron_resolve")
	_run_mission("MISSION_COMPLETE")
	assert_bool(_tarot.is_rune_discovered(&"rune_iron_resolve")).is_true()

	_tarot.unequip_card(&"iron_resolve")

	assert_bool(_tarot.is_rune_discovered(&"rune_iron_resolve")).is_true()


# ---------------------------------------------------------------------------
# AC-31: a DISCOVERED rune whose card IS equipped — the card's own Group 3
# effect still emits normally (not suppressed by discovery bookkeeping).
# ---------------------------------------------------------------------------

func test_cards_own_effect_still_emits_normally_after_its_rune_is_discovered() -> void:
	_unlock_and_equip(&"iron_resolve")
	_run_mission("MISSION_COMPLETE")
	assert_bool(_tarot.is_rune_discovered(&"rune_iron_resolve")).is_true()

	_spy.clear()
	_unlock_and_equip(&"iron_resolve")  # re-equip for the next mission
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	_tarot._on_mission_phase_changed("", "SCOUT", 0.0)

	assert_int(_spy.count("mission_modifier_applied")).is_equal(1)
	var args: Array = (_spy.emissions["mission_modifier_applied"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal("tarot_difficulty_growth_rate")


# ---------------------------------------------------------------------------
# EC-9: unequipping a card never "undiscovers" its rune.
# ---------------------------------------------------------------------------

func test_unequipping_never_undiscovers_a_rune() -> void:
	_unlock_and_equip(&"iron_resolve")
	_run_mission("MISSION_COMPLETE")

	_tarot.unequip_card(&"iron_resolve")
	_tarot.equip_card(&"iron_resolve")  # re-equip, still unlocked from before
	_tarot.unequip_card(&"iron_resolve")

	assert_bool(_tarot.is_rune_discovered(&"rune_iron_resolve")).is_true()


func test_unknown_card_id_does_not_crash_discovery_check() -> void:
	# _maybe_discover_rune's null-card guard is exercised here — an
	# _active_mission_deck entry with no matching GameDataRegistry card
	# (orphaned content) must never crash the terminal handler.
	_tarot._active_mission_deck = [&"unknown_card_id"]
	_tarot._on_mission_terminal("MISSION_COMPLETE")
	assert_int(_spy.count("tarot_rune_discovered")).is_equal(0)
