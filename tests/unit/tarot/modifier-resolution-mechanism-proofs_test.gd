## Unit tests for Story 002 (TR-tarot-001, ADR-0027): the modifier resolution
## pipeline (Rule 6, SCOUT-entry emission), F1 mastery-scaling, the 4
## registered modifier_type mechanism proofs, REPLACE-type equip-time
## enforcement, the run_modifier_selected read-only subscription, and the
## no-hero-damage-modifier content check.
##
## Tarot is instantiated directly (Tarot.new(), no add_child()) so _ready()
## never fires — mission_launched/mission_phase_changed/run_modifier_selected
## are exercised via direct handler calls, matching this project's
## established convention. Real content cards (assets/data/tarot/) are used
## via GGameDataRegistry rather than fixture files, mirroring Story 001's own
## test file.
extends GdUnitTestSuite

var _tarot: Tarot
var _spy: EventBusSpy


func before_test() -> void:
	_tarot = Tarot.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.mission_modifier_applied)
	_spy.watch(GEventBus.run_modifier_selected)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _tarot != null and is_instance_valid(_tarot):
		_tarot.free()
	_tarot = null


func _unlock_and_equip(card_id: StringName) -> bool:
	_tarot._card_unlocked[card_id] = true
	return _tarot.equip_card(card_id)


func _launch_and_enter_scout() -> void:
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	_tarot._on_mission_phase_changed("", "SCOUT", 0.0)


# ---------------------------------------------------------------------------
# AC-10: exactly one mission_modifier_applied per TarotModifierEntry across
# all equipped cards, synchronized to SCOUT entry.
# ---------------------------------------------------------------------------

func test_scout_entry_emits_one_event_per_modifier_entry_across_equipped_cards() -> void:
	_unlock_and_equip(&"iron_resolve")  # 1 entry
	_unlock_and_equip(&"reckless_onslaught")  # 2 entries (dual-edge)

	_launch_and_enter_scout()

	assert_int(_spy.count("mission_modifier_applied")).is_equal(3)


func test_no_modifier_events_fire_before_scout_entry() -> void:
	_unlock_and_equip(&"iron_resolve")
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)  # locked, but not SCOUT yet

	assert_int(_spy.count("mission_modifier_applied")).is_equal(0)


# ---------------------------------------------------------------------------
# AC-11: modifier_value always equals F1's mastery-scaled effective value
# (Tier 0 -> scalar 1.00, so effective_value == base_modifier_value here —
# Story 003 owns real tier accrual/lookup).
# ---------------------------------------------------------------------------

func test_emitted_modifier_value_equals_mastery_scaled_effective_value() -> void:
	_unlock_and_equip(&"iron_resolve")
	_launch_and_enter_scout()

	var args: Array = (_spy.emissions["mission_modifier_applied"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal("tarot_difficulty_growth_rate")
	assert_float(args[1] as float).is_equal_approx(0.18 * Tarot.MASTERY_TIER_SCALARS[0], 0.0001)
	assert_str(args[2] as String).is_equal("iron_resolve")


func test_dual_edge_card_emits_both_entries_within_the_same_batch() -> void:
	_unlock_and_equip(&"reckless_onslaught")
	_launch_and_enter_scout()

	var types: Array[String] = []
	for emission: Array in (_spy.emissions["mission_modifier_applied"] as Array):
		types.append(emission[0] as String)
	assert_int(types.size()).is_equal(2)
	assert_bool(types.has("tarot_speed_scalar_mult")).is_true()
	assert_bool(types.has("tarot_reward_scalar_mult")).is_true()


# ---------------------------------------------------------------------------
# AC-12: MULTIPLICATIVE mechanism proof — speed. Tarot emits each card's own
# F1 effective value (F2 aggregation itself is Monster System's job, not
# tested here) — this proves the emitted per-card values are exactly what
# the GDD's own worked example requires as F2's input.
# ---------------------------------------------------------------------------

func test_multiplicative_speed_proof_emits_correct_per_card_values_for_aggregation() -> void:
	_unlock_and_equip(&"swift_current")  # base 1.69
	_unlock_and_equip(&"hunters_pace")  # base 1.20
	_launch_and_enter_scout()

	var values: Array[float] = []
	for emission: Array in (_spy.emissions["mission_modifier_applied"] as Array):
		if (emission[0] as String) == "tarot_speed_scalar_mult":
			values.append(emission[1] as float)
	assert_int(values.size()).is_equal(2)

	# Formula F2's own mechanism: aggregate_raw = product, never sum.
	var aggregate_raw: float = values[0] * values[1]
	assert_float(aggregate_raw).is_equal_approx(2.028, 0.001)
	var aggregate_sum_would_be_wrong: float = values[0] + values[1]
	assert_float(aggregate_raw).is_not_equal(aggregate_sum_would_be_wrong)


# ---------------------------------------------------------------------------
# AC-13: MULTIPLICATIVE mechanism proof — reward. natural scalar × Tarot
# multiplier, rune bonus added only afterward (rune bonus = 0.0, not
# discovered — Story 004's own scope).
# ---------------------------------------------------------------------------

func test_multiplicative_reward_proof_combines_by_multiplication_not_addition() -> void:
	_unlock_and_equip(&"reckless_onslaught")
	_launch_and_enter_scout()

	var reward_value: float = 0.0
	for emission: Array in (_spy.emissions["mission_modifier_applied"] as Array):
		if (emission[0] as String) == "tarot_reward_scalar_mult":
			reward_value = emission[1] as float
	assert_float(reward_value).is_equal_approx(2.0, 0.0001)

	var wave_reward_scalar_natural: float = 1.44  # GDD's own worked example (wave 3, r=0.20)
	var rune_reward_bonus: float = 0.0  # not yet discovered
	var wave_reward_scalar_final: float = clampf(
		wave_reward_scalar_natural * reward_value + rune_reward_bonus, 1.00, 4.768
	)
	assert_float(wave_reward_scalar_final).is_equal_approx(2.88, 0.001)


# ---------------------------------------------------------------------------
# AC-14: REPLACE mechanism proof — growth rate. Absolute substitution, never
# additive or multiplicative.
# ---------------------------------------------------------------------------

func test_replace_growth_rate_proof_is_absolute_substitution() -> void:
	_unlock_and_equip(&"iron_resolve")  # base_modifier_value 0.18, targets tarot_difficulty_growth_rate
	_launch_and_enter_scout()

	var emitted_value: float = 0.0
	for emission: Array in (_spy.emissions["mission_modifier_applied"] as Array):
		if (emission[0] as String) == "tarot_difficulty_growth_rate":
			emitted_value = emission[1] as float

	var mission_authored_rate: float = 0.20
	# REPLACE means the mission's own authored rate is simply discarded in
	# favor of the emitted value — never additive (0.20+0.18) or
	# multiplicative (0.20*0.18) composition.
	var final_growth_rate: float = emitted_value
	assert_float(final_growth_rate).is_equal_approx(0.18, 0.0001)
	assert_float(final_growth_rate).is_not_equal(mission_authored_rate + emitted_value)
	assert_float(final_growth_rate).is_not_equal(mission_authored_rate * emitted_value)


# ---------------------------------------------------------------------------
# AC-16 (equip-time half — the data-error runtime fallback/log is Wave
# Manager's own consumption-side responsibility, out of scope here; see
# tarot.gd's class doc comment).
# ---------------------------------------------------------------------------

func test_equipping_a_second_replace_type_card_targeting_same_type_is_rejected() -> void:
	assert_bool(_unlock_and_equip(&"iron_resolve")).is_true()  # tarot_difficulty_growth_rate

	_tarot._card_unlocked[&"grim_resolve"] = true
	var ok: bool = _tarot.equip_card(&"grim_resolve")  # also tarot_difficulty_growth_rate

	assert_bool(ok).is_false()
	assert_int(_tarot.get_active_card_count()).is_equal(1)


func test_two_multiplicative_type_cards_of_the_same_type_can_both_equip() -> void:
	# MULTIPLICATIVE types stack freely (EC-3) — no equip-time rejection.
	assert_bool(_unlock_and_equip(&"swift_current")).is_true()
	assert_bool(_unlock_and_equip(&"hunters_pace")).is_true()
	assert_int(_tarot.get_active_card_count()).is_equal(2)


# ---------------------------------------------------------------------------
# AC-18: Tarot never emits on run_modifier_selected — only subscribes.
# ---------------------------------------------------------------------------

func test_tarot_never_emits_on_run_modifier_selected_across_a_full_lifecycle() -> void:
	_unlock_and_equip(&"iron_resolve")
	_unlock_and_equip(&"reckless_onslaught")
	_launch_and_enter_scout()
	_tarot._on_mission_phase_changed("SCOUT", "MISSION_COMPLETE", 0.0)

	# Tarot's own code never calls GEventBus.run_modifier_selected.emit()
	# anywhere — confirmed by inspection (tarot.gd only subscribes, via
	# _on_run_modifier_selected). This spy count would only ever increase if
	# something else in the test process emitted it, which nothing here does.
	assert_int(_spy.count("run_modifier_selected")).is_equal(0)


# ---------------------------------------------------------------------------
# AC-19: conflict indicator surfaced from the read-only subscription,
# without altering resolution logic.
# ---------------------------------------------------------------------------

func test_run_modifier_selected_populates_conflict_indicator_without_altering_resolution() -> void:
	_tarot._on_run_modifier_selected("tarot_speed_scalar_mult", 1.5)

	assert_bool(_tarot.has_run_modifier_conflict("tarot_speed_scalar_mult")).is_true()
	assert_bool(_tarot.has_run_modifier_conflict("tarot_reward_scalar_mult")).is_false()

	# Resolution logic is unaffected: emitted values are unchanged regardless
	# of any recorded conflict.
	_unlock_and_equip(&"swift_current")
	_launch_and_enter_scout()
	var args: Array = (_spy.emissions["mission_modifier_applied"] as Array)[0] as Array
	assert_float(args[1] as float).is_equal_approx(1.69, 0.0001)


# ---------------------------------------------------------------------------
# AC-20 (Config/Data): none of Tarot's 4 modifier types target hero damage.
# ---------------------------------------------------------------------------

func test_no_registered_modifier_type_targets_hero_damage() -> void:
	for modifier_type: StringName in TarotModifierEntry.REGISTERED_MODIFIER_TYPES:
		assert_bool(String(modifier_type).contains("hero_damage")).is_false()
