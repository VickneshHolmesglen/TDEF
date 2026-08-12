## Integration tests for Story 001 (TR-tarot-001, ADR-0027): TarotCardResource/
## TarotModifierEntry data model, deck equip/unequip with slot-cap
## enforcement, and the mission_launched deck-lock snapshot.
##
## Tarot is instantiated directly (Tarot.new(), no add_child()) so _ready()
## never fires — GEventBus subscriptions are never wired live; the
## mission_launched/mission_phase_changed handlers are called directly with
## real payloads, matching this project's established direct-handler-call
## convention (Constellation/TowerMastery's own test files).
##
## Per this story's own file: mastery_tier/mastery_missions_played/unlocked
## are deliberately NOT fields on TarotCardResource (ADR-0027 resolves
## tarot.md's own Rule 1 inconsistency — those 3 fields are exactly the
## "mutable per-playthrough state" ADR-0003's resource_object_in_save_data
## forbidden pattern bars from a shared boot-loaded Resource). `unlocked`
## lives on Tarot's own `_card_unlocked` dictionary instead (a
## TarotProgressLedger slice) — AC-1's tests below reflect this resolved
## divergence rather than the GDD's stale field table.
extends GdUnitTestSuite

var _tarot: Tarot


func before_test() -> void:
	_tarot = Tarot.new()


func after_test() -> void:
	if _tarot != null and is_instance_valid(_tarot):
		_tarot.free()
	_tarot = null


func _unlock(card_id: StringName) -> void:
	_tarot._card_unlocked[card_id] = true


# ---------------------------------------------------------------------------
# AC-1 (Config/Data): TarotCardResource/TarotModifierEntry field presence
# and types.
# ---------------------------------------------------------------------------

func test_tarot_card_resource_has_the_correct_static_fields() -> void:
	var card := TarotCardResource.new()
	card.card_id = &"test_card"
	card.rarity = "Common"
	card.linked_rune_id = &"rune_test_card"
	var entry := TarotModifierEntry.new()
	entry.modifier_type = &"tarot_difficulty_growth_rate"
	entry.base_modifier_value = 0.2
	card.modifiers = [entry]

	assert_str(String(card.card_id)).is_equal("test_card")
	assert_str(card.rarity).is_equal("Common")
	assert_str(String(card.linked_rune_id)).is_equal("rune_test_card")
	assert_int(card.modifiers.size()).is_equal(1)
	assert_str(String(card.modifiers[0].modifier_type)).is_equal("tarot_difficulty_growth_rate")
	assert_float(card.modifiers[0].base_modifier_value).is_equal_approx(0.2, 0.0001)


func test_real_content_files_load_and_validate_via_game_data_registry() -> void:
	var iron_resolve: TarotCardResource = GGameDataRegistry.get_tarot_card(&"iron_resolve")
	assert_object(iron_resolve).is_not_null()
	assert_bool(iron_resolve.validate()).is_true()

	var reckless: TarotCardResource = GGameDataRegistry.get_tarot_card(&"reckless_onslaught")
	assert_object(reckless).is_not_null()
	assert_bool(reckless.validate()).is_true()


# ---------------------------------------------------------------------------
# AC-3 (Config/Data): every modifiers entry's modifier_type is one of the 4
# registered types, validated pre-ship.
# ---------------------------------------------------------------------------

func test_validate_rejects_an_unregistered_modifier_type() -> void:
	var card := TarotCardResource.new()
	card.card_id = &"bad_card"
	card.rarity = "Common"
	var entry := TarotModifierEntry.new()
	entry.modifier_type = &"not_a_registered_type"
	card.modifiers = [entry]

	assert_bool(card.validate()).is_false()


func test_validate_accepts_all_4_registered_modifier_types() -> void:
	for modifier_type: StringName in TarotModifierEntry.REGISTERED_MODIFIER_TYPES:
		var card := TarotCardResource.new()
		card.card_id = &"card_%s" % modifier_type
		card.rarity = "Common"
		var entry := TarotModifierEntry.new()
		entry.modifier_type = modifier_type
		card.modifiers = [entry]
		assert_bool(card.validate()).is_true()


func test_validate_rejects_invalid_rarity() -> void:
	var card := TarotCardResource.new()
	card.card_id = &"bad_rarity"
	card.rarity = "Mythic"  # not one of Common/Rare/Legendary
	var entry := TarotModifierEntry.new()
	entry.modifier_type = &"tarot_difficulty_growth_rate"
	card.modifiers = [entry]

	assert_bool(card.validate()).is_false()


# ---------------------------------------------------------------------------
# AC-4 (data-model level — full emission-batch behavior is Story 002's own
# scope; this confirms the dual-edge card correctly carries both entries).
# ---------------------------------------------------------------------------

func test_dual_edge_card_carries_both_modifier_entries() -> void:
	var reckless: TarotCardResource = GGameDataRegistry.get_tarot_card(&"reckless_onslaught")
	assert_object(reckless).is_not_null()
	assert_int(reckless.modifiers.size()).is_equal(2)

	var types: Array[String] = []
	for entry: TarotModifierEntry in reckless.modifiers:
		types.append(String(entry.modifier_type))
	assert_bool(types.has("tarot_speed_scalar_mult")).is_true()
	assert_bool(types.has("tarot_reward_scalar_mult")).is_true()


# ---------------------------------------------------------------------------
# AC-2: Tarot never writes to a card's unlocked field, only reads it
# (equip_card's gate reads _card_unlocked; no method on Tarot ever sets it).
# ---------------------------------------------------------------------------

func test_equip_rejects_a_card_that_is_not_unlocked() -> void:
	# Uses an unregistered card_id (not "iron_resolve") so this AC-2 seam
	# test is independent of any real card's content-authored
	# unlock_tech_id — Common cards like iron_resolve are unlocked from the
	# start by content design (see TarotCardResource.unlock_tech_id and
	# assets/data/tarot/*.tres), so they would no longer prove this gate.
	var ok: bool = _tarot.equip_card(&"unregistered_test_card")
	assert_bool(ok).is_false()
	assert_int(_tarot.get_active_card_count()).is_equal(0)


func test_equip_succeeds_once_card_is_unlocked() -> void:
	_unlock(&"iron_resolve")
	var ok: bool = _tarot.equip_card(&"iron_resolve")
	assert_bool(ok).is_true()
	assert_int(_tarot.get_active_card_count()).is_equal(1)


# ---------------------------------------------------------------------------
# AC-5: deck slot cap enforced — a 6th equip attempt is rejected, no event.
# ---------------------------------------------------------------------------

func test_equipping_a_6th_card_is_rejected_when_deck_is_at_slot_count() -> void:
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.tarot_deck_changed)

	for i in range(Tarot.TAROT_DECK_SLOT_COUNT):
		var card_id: StringName = StringName("card_%d" % i)
		_unlock(card_id)
		assert_bool(_tarot.equip_card(card_id)).is_true()
	assert_int(_tarot.get_active_card_count()).is_equal(Tarot.TAROT_DECK_SLOT_COUNT)

	var event_count_before: int = spy.count("tarot_deck_changed")
	_unlock(&"sixth_card")
	var ok: bool = _tarot.equip_card(&"sixth_card")

	assert_bool(ok).is_false()
	assert_int(_tarot.get_active_card_count()).is_equal(Tarot.TAROT_DECK_SLOT_COUNT)
	assert_int(spy.count("tarot_deck_changed")).is_equal(event_count_before)
	spy.disconnect_all()


# ---------------------------------------------------------------------------
# AC-6/AC-7: equip/unequip fire tarot_deck_changed with the correct count.
# ---------------------------------------------------------------------------

func test_equip_fires_tarot_deck_changed_with_incremented_count() -> void:
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.tarot_deck_changed)

	_unlock(&"iron_resolve")
	_tarot.equip_card(&"iron_resolve")

	assert_int(spy.count("tarot_deck_changed")).is_equal(1)
	var args: Array = (spy.emissions["tarot_deck_changed"] as Array)[0] as Array
	assert_int(args[0] as int).is_equal(1)
	spy.disconnect_all()


func test_unequip_fires_tarot_deck_changed_with_decremented_count() -> void:
	_unlock(&"iron_resolve")
	_unlock(&"reckless_onslaught")
	_tarot.equip_card(&"iron_resolve")
	_tarot.equip_card(&"reckless_onslaught")

	var spy := EventBusSpy.new()
	spy.watch(GEventBus.tarot_deck_changed)

	var ok: bool = _tarot.unequip_card(&"iron_resolve")

	assert_bool(ok).is_true()
	assert_int(spy.count("tarot_deck_changed")).is_equal(1)
	var args: Array = (spy.emissions["tarot_deck_changed"] as Array)[0] as Array
	assert_int(args[0] as int).is_equal(1)
	spy.disconnect_all()


# ---------------------------------------------------------------------------
# AC-8/AC-9: mission_launched snapshots the deck; the snapshot is immutable
# for the mission's duration and independent of later Sanctuary-side state.
# ---------------------------------------------------------------------------

func test_mission_launched_snapshots_current_deck() -> void:
	_unlock(&"iron_resolve")
	_unlock(&"reckless_onslaught")
	_tarot.equip_card(&"iron_resolve")
	_tarot.equip_card(&"reckless_onslaught")

	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)

	assert_int(_tarot._active_mission_deck.size()).is_equal(2)
	assert_bool(_tarot._active_mission_deck.has(&"iron_resolve")).is_true()
	assert_bool(_tarot._active_mission_deck.has(&"reckless_onslaught")).is_true()


func test_deck_edits_are_rejected_while_locked_and_snapshot_is_untouched() -> void:
	_unlock(&"iron_resolve")
	_unlock(&"reckless_onslaught")
	_tarot.equip_card(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)

	var equip_ok: bool = _tarot.equip_card(&"reckless_onslaught")
	var unequip_ok: bool = _tarot.unequip_card(&"iron_resolve")

	assert_bool(equip_ok).is_false()
	assert_bool(unequip_ok).is_false()
	assert_int(_tarot._active_mission_deck.size()).is_equal(1)
	assert_bool(_tarot._active_mission_deck.has(&"iron_resolve")).is_true()


func test_mission_end_unlocks_the_deck_for_editing_again() -> void:
	_unlock(&"iron_resolve")
	_tarot.equip_card(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	assert_bool(_tarot.unequip_card(&"iron_resolve")).is_false()  # locked

	_tarot._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)

	_unlock(&"reckless_onslaught")
	assert_bool(_tarot.equip_card(&"reckless_onslaught")).is_true()


func test_active_mission_deck_does_not_alias_current_deck() -> void:
	_unlock(&"iron_resolve")
	_tarot.equip_card(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)

	# Mutating the returned snapshot directly must never alter Tarot's own
	# internal state — proves _active_mission_deck was populated via
	# .duplicate(), not a shared Array reference.
	_tarot._active_mission_deck.append(&"should_not_leak_back")

	assert_int(_tarot._current_deck.size()).is_equal(1)
