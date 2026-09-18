## Unit tests for Hero.get_effective_stat() (S4-03, story-001, ADR-0010 Formula 1).
## Formula: effective = max(0, max(0, base + flat) x clamp(1 + additive, -0.75, 3.0))
## No rounding is applied (see hero.gd doc comment) — tests compare with is_equal_approx().
extends GdUnitTestSuite

const STAT: StringName = &"physical_attack"

# Hero extends CharacterBody2D — Hero.new() allocates real PhysicsServer/
# RenderingServer RIDs (physics body + CanvasItem), unlike a plain Node or
# RefCounted. Must be freed explicitly in after_test(), or every test leaks
# server-side resources (confirmed: 8 orphan nodes + 8 leaked RIDs before
# this fix, one per test).
var _hero: Hero


func _make_hero(base: float, flat: float, additive: float) -> Hero:
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[STAT] = base
	_hero._flat_bonuses[STAT] = flat
	_hero._additive_bonuses[STAT] = additive
	return _hero


func after_test() -> void:
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


func test_effective_stat_with_base_flat_and_additive_returns_scaled_value() -> void:
	# AC-01: (50 + 12) x (1 + 0.45) = 89.9
	var hero := _make_hero(50.0, 12.0, 0.45)
	assert_float(hero.get_effective_stat(STAT)).is_equal_approx(89.9, 0.0001)


func test_effective_stat_with_zero_flat_bonus_applies_multiplier_to_base_only() -> void:
	# AC-01 edge: flat_bonus = 0 -> base x (1 + additive) directly
	var hero := _make_hero(50.0, 0.0, 0.5)
	assert_float(hero.get_effective_stat(STAT)).is_equal_approx(75.0, 0.0001)


func test_effective_stat_with_zero_additive_bonus_applies_base_plus_flat_only() -> void:
	# AC-01 edge: additive = 0 -> (base + flat) with multiplier = 1
	var hero := _make_hero(50.0, 12.0, 0.0)
	assert_float(hero.get_effective_stat(STAT)).is_equal_approx(62.0, 0.0001)


func test_effective_stat_with_additive_above_cap_clamps_multiplier_to_four() -> void:
	# AC-02: additive_bonus_total = 5.0 (above +3.00 cap) -> clamped to 3.0, multiplier = 4.0
	var hero := _make_hero(50.0, 12.0, 5.0)
	assert_float(hero.get_effective_stat(STAT)).is_equal_approx(62.0 * 4.0, 0.0001)


func test_effective_stat_with_additive_exactly_at_cap_passes_through_unclamped() -> void:
	# AC-02 edge: additive = 3.00 exactly -> multiplier = 4.0 (unclamped, matches the clamp boundary)
	var hero := _make_hero(50.0, 12.0, 3.0)
	assert_float(hero.get_effective_stat(STAT)).is_equal_approx(62.0 * 4.0, 0.0001)


func test_effective_stat_with_additive_slightly_above_cap_still_clamps_to_four() -> void:
	# AC-02 edge: additive = 3.001 -> clamped identically to the 3.00 boundary case
	var hero := _make_hero(50.0, 12.0, 3.001)
	assert_float(hero.get_effective_stat(STAT)).is_equal_approx(62.0 * 4.0, 0.0001)


func test_effective_stat_with_additive_below_floor_clamps_multiplier_to_quarter() -> void:
	# EC-1: additive_bonus_total = -1.5 (below -0.75 floor) -> clamped to -0.75, multiplier = 0.25
	var hero := _make_hero(50.0, 12.0, -1.5)
	assert_float(hero.get_effective_stat(STAT)).is_equal_approx(62.0 * 0.25, 0.0001)


func test_effective_stat_with_negative_intermediate_returns_zero() -> void:
	# EC-2: base + flat is negative -> intermediate clamped to 0 before the multiplier applies
	var hero := _make_hero(10.0, -50.0, 0.45)
	assert_float(hero.get_effective_stat(STAT)).is_equal_approx(0.0, 0.0001)

# ---------------------------------------------------------------------------
# _apply_stat_cap() — real, shipped branching logic with no dedicated AC in
# story-001 (Implementation Notes / Tuning Knobs only). Added during code
# review: all tests above use &"damage" (uncapped, falls through the match's
# default branch), so none of the 4 real cap branches had ever been exercised.
# ---------------------------------------------------------------------------

func _make_hero_for_stat(stat: StringName, base: float, flat: float, additive: float) -> Hero:
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[stat] = base
	_hero._flat_bonuses[stat] = flat
	_hero._additive_bonuses[stat] = additive
	return _hero


## Diminishing curve (Hero Combat & Stats Redesign, 2026-09-18): raw=1.0 ->
## (1.0 x 0.85) / (1.0 + 0.5) = 0.85 / 1.5 = 0.56667.
func test_effective_stat_crit_chance_curve_at_raw_one_returns_worked_example() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 1.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_equal_approx(0.56667, 0.0001)


## raw=0.1 (this project's placeholder base value) -> (0.1 x 0.85) / (0.1 + 0.5)
## = 0.085 / 0.6 = 0.14167.
func test_effective_stat_crit_chance_curve_at_placeholder_base_value() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 0.1, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_equal_approx(0.14167, 0.0001)


## Asymptotic approach: a very large raw value must never reach or exceed 0.85.
func test_effective_stat_crit_chance_never_reaches_hard_cap_at_large_raw() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 1000.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_less(0.85)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_greater(0.84)


func test_effective_stat_crit_chance_zero_raw_returns_zero() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 0.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_equal_approx(0.0, 0.0001)


## raw=0.5 -> (0.5 x 0.85) / (0.5 + 0.5) = 0.425 / 1.0 = 0.425 (the curve's own
## documented "half of hard cap at raw=scaling_constant" property).
func test_effective_stat_crit_chance_curve_half_cap_at_scaling_constant() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 0.5, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_equal_approx(0.425, 0.0001)


func test_effective_stat_elemental_resist_fire_above_cap_clamps_to_seventy_five_percent() -> void:
	var hero := _make_hero_for_stat(&"elemental_resist_fire", 1.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"elemental_resist_fire")).is_equal_approx(0.75, 0.0001)


func test_effective_stat_elemental_resist_frost_above_cap_clamps_to_seventy_five_percent() -> void:
	var hero := _make_hero_for_stat(&"elemental_resist_frost", 1.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"elemental_resist_frost")).is_equal_approx(0.75, 0.0001)


func test_effective_stat_lifesteal_above_cap_clamps_to_forty_percent() -> void:
	var hero := _make_hero_for_stat(&"lifesteal", 1.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"lifesteal")).is_equal_approx(0.4, 0.0001)


func test_effective_stat_cdr_above_cap_clamps_to_seventy_five_percent() -> void:
	var hero := _make_hero_for_stat(&"cdr", 1.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"cdr")).is_equal_approx(0.75, 0.0001)


# ---------------------------------------------------------------------------
# Crit Multiplier diminishing curve (Hero Combat & Stats Redesign, 2026-09-18)
# get_effective_stat(&"crit_multiplier") now returns the FULL multiplier
# (base 1.5 + curved bonus), not a bonus-only value.
# ---------------------------------------------------------------------------

func test_effective_stat_crit_multiplier_zero_raw_returns_base_only() -> void:
	var hero := _make_hero_for_stat(&"crit_multiplier", 0.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_multiplier")).is_equal_approx(1.5, 0.0001)


## raw=1.0 -> 1.5 + (1.0 x 2.0) / (1.0 + 1.0) = 1.5 + 1.0 = 2.5
func test_effective_stat_crit_multiplier_curve_at_raw_one() -> void:
	var hero := _make_hero_for_stat(&"crit_multiplier", 1.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_multiplier")).is_equal_approx(2.5, 0.0001)


func test_effective_stat_crit_multiplier_never_reaches_hard_cap_at_large_raw() -> void:
	var hero := _make_hero_for_stat(&"crit_multiplier", 1000.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_multiplier")).is_less(3.5)
	assert_float(hero.get_effective_stat(&"crit_multiplier")).is_greater(3.4)


# ---------------------------------------------------------------------------
# Luck diminishing curve (new stat, Hero Combat & Stats Redesign, 2026-09-18)
# ---------------------------------------------------------------------------

func test_effective_stat_luck_zero_raw_returns_zero() -> void:
	var hero := _make_hero_for_stat(&"luck", 0.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"luck")).is_equal_approx(0.0, 0.0001)


## raw=0.5 -> (0.5 x 0.35) / (0.5 + 0.5) = 0.175 / 1.0 = 0.175
func test_effective_stat_luck_curve_half_cap_at_scaling_constant() -> void:
	var hero := _make_hero_for_stat(&"luck", 0.5, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"luck")).is_equal_approx(0.175, 0.0001)


func test_effective_stat_luck_never_reaches_hard_cap_at_large_raw() -> void:
	var hero := _make_hero_for_stat(&"luck", 1000.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"luck")).is_less(0.35)
	assert_float(hero.get_effective_stat(&"luck")).is_greater(0.34)


# ---------------------------------------------------------------------------
# _effective_crit_chance() — Crit Chance + Luck combined, re-clamped
# (Hero Combat & Stats Redesign, 2026-09-18, Section 3.4.2)
# ---------------------------------------------------------------------------

func test_effective_crit_chance_sums_crit_chance_and_luck_curves() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 0.5, 0.0, 0.0)
	hero._base_stats[&"luck"] = 0.5
	# crit_chance curve: 0.425 (Task 2's worked example). luck curve: 0.175
	# (Task 2's worked example). Sum = 0.6.
	assert_float(hero._effective_crit_chance()).is_equal_approx(0.6, 0.0001)


func test_effective_crit_chance_clamps_combined_sum_to_cap() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 1000.0, 0.0, 0.0)
	hero._base_stats[&"luck"] = 1000.0
	# Both curves individually approach their own caps (0.85 + 0.35 = 1.2 max
	# possible sum) — the combined result must still clamp to 0.85, not 1.2.
	assert_float(hero._effective_crit_chance()).is_equal_approx(0.85, 0.0001)


func test_effective_crit_chance_zero_luck_equals_bare_crit_chance() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 0.5, 0.0, 0.0)
	assert_float(hero._effective_crit_chance()).is_equal_approx(
		hero.get_effective_stat(&"crit_chance"), 0.0001)
