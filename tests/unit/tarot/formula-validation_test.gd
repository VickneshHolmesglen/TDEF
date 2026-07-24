## Unit tests for Story 005 (TR-tarot-001/002/003, ADR-0027): anchors
## tarot.md's own F3-F6 worked examples as regression tests. F3/F4 are
## computed as pure formula-correctness assertions against Tarot's emitted
## F1 per-card values (F2/F3 aggregation itself is Wave Manager's/Monster
## System's own scope, per Story 002's own boundary) — F5/F6 exercise real
## Tarot production code (compute_rune_bonus()/get_mastery_tier()) directly.
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


func _launch_and_scout() -> void:
	_tarot._on_mission_launched("the_gap", PackedStringArray(), 1)
	_tarot._on_mission_phase_changed("", "SCOUT", 0.0)


# ---------------------------------------------------------------------------
# AC-32: F3 regression anchor — wave 3, r=0.20, one Legendary card
# solo-equipped at Tier 0, rune bonus 0.00 -> wave_reward_scalar_final = 2.88.
# ---------------------------------------------------------------------------

func test_f3_regression_anchor_wave_3_solo_reckless_onslaught_tier_0() -> void:
	_unlock_and_equip(&"reckless_onslaught")
	_launch_and_scout()

	var reward_value: float = 0.0
	for emission: Array in (_spy.emissions["mission_modifier_applied"] as Array):
		if (emission[0] as String) == "tarot_reward_scalar_mult":
			reward_value = emission[1] as float
	assert_float(reward_value).is_equal_approx(2.00, 0.0001)  # F1: 2.00 * m(0)=1.00

	var wave_reward_scalar_natural: float = 1.0 * pow(1.20, 2)  # wave 3, r=0.20
	assert_float(wave_reward_scalar_natural).is_equal_approx(1.44, 0.0001)

	var rune_reward_bonus: float = 0.0  # not discovered
	var wave_reward_scalar_final: float = clampf(
		wave_reward_scalar_natural * reward_value + rune_reward_bonus, 1.00, 4.768
	)
	assert_float(wave_reward_scalar_final).is_equal_approx(2.88, 0.001)


# ---------------------------------------------------------------------------
# AC-33: F4 dual-edge value coupling — both speed and reward sides read
# 2.00 in the same resolution pass (wave 1).
# ---------------------------------------------------------------------------

func test_f4_dual_edge_coupling_both_sides_equal_2_at_wave_1() -> void:
	_unlock_and_equip(&"reckless_onslaught")
	_launch_and_scout()

	var speed_value: float = 0.0
	var reward_value: float = 0.0
	for emission: Array in (_spy.emissions["mission_modifier_applied"] as Array):
		match emission[0] as String:
			"tarot_speed_scalar_mult":
				speed_value = emission[1] as float
			"tarot_reward_scalar_mult":
				reward_value = emission[1] as float

	var tarot_speed_scalar: float = clampf(speed_value, 0.50, 2.00)
	assert_float(tarot_speed_scalar).is_equal_approx(2.00, 0.0001)

	var wave_reward_scalar_natural_wave_1: float = 1.0  # s=1.00 at wave 1
	var wave_reward_scalar_final: float = clampf(
		wave_reward_scalar_natural_wave_1 * reward_value, 1.00, 4.768
	)
	assert_float(wave_reward_scalar_final).is_equal_approx(2.00, 0.0001)


# ---------------------------------------------------------------------------
# AC-34: F5 additive stacking and clamp — two discovered runes,
# rune_bonus_flat=0.05 each -> rune_reward_bonus = clamp(0.10, 0, 0.30) = 0.10.
# ---------------------------------------------------------------------------

func test_f5_additive_stacking_two_discovered_runes() -> void:
	_tarot._rune_discovered[&"rune_lucky_charm"] = true
	_tarot._rune_discovered[&"rune_golden_ticket"] = true

	var rune_reward_bonus: float = _tarot.compute_rune_bonus(&"tarot_reward_scalar_mult")

	assert_float(rune_reward_bonus).is_equal_approx(0.10, 0.0001)


func test_f5_undiscovered_runes_contribute_nothing() -> void:
	# lucky_charm/golden_ticket exist in content but are not marked discovered.
	var rune_reward_bonus: float = _tarot.compute_rune_bonus(&"tarot_reward_scalar_mult")
	assert_float(rune_reward_bonus).is_equal_approx(0.0, 0.0001)


## Only 3 real content cards target tarot_reward_scalar_mult today (max
## reachable sum 0.15 at 0.05 each) — not enough authored content to
## actually cross the 0.30 ceiling and prove the clamp engages, only that
## the result never exceeds it. Flagging this honestly rather than
## fabricating extra content cards solely to hit a number: a real clamp-
## engagement test needs 6+ discovered same-type runes, which doesn't exist
## in this project's content yet.
func test_f5_result_never_exceeds_the_0_30_ceiling() -> void:
	_tarot._rune_discovered[&"rune_lucky_charm"] = true
	_tarot._rune_discovered[&"rune_golden_ticket"] = true
	_tarot._rune_discovered[&"rune_reckless_onslaught"] = true  # also targets reward

	var rune_reward_bonus: float = _tarot.compute_rune_bonus(&"tarot_reward_scalar_mult")

	assert_float(rune_reward_bonus).is_less_equal(0.30)
	assert_float(rune_reward_bonus).is_equal_approx(0.15, 0.0001)


func test_f5_bonus_applies_regardless_of_deck_composition() -> void:
	# Neither card is equipped at all — Rule 16's "regardless of deck
	# composition" guarantee.
	_tarot._rune_discovered[&"rune_lucky_charm"] = true
	_tarot._rune_discovered[&"rune_golden_ticket"] = true
	assert_int(_tarot.get_active_card_count()).is_equal(0)

	var rune_reward_bonus: float = _tarot.compute_rune_bonus(&"tarot_reward_scalar_mult")

	assert_float(rune_reward_bonus).is_equal_approx(0.10, 0.0001)


# ---------------------------------------------------------------------------
# AC-35: F6 threshold boundary anchor.
# ---------------------------------------------------------------------------

func test_f6_boundary_anchor_across_all_5_tiers() -> void:
	var expectations: Dictionary[int, int] = {0: 0, 3: 1, 8: 2, 15: 3, 25: 4}
	for played: int in expectations:
		_tarot._mastery_missions_played[&"iron_resolve"] = played
		assert_int(_tarot.get_mastery_tier(&"iron_resolve")).is_equal(expectations[played])
