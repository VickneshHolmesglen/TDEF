## Unit tests for Hero.get_effective_stat() (S4-03, story-001, ADR-0010 Formula 1).
## Formula: effective = max(0, max(0, base + flat) x clamp(1 + additive, -0.75, 3.0))
## No rounding is applied (see hero.gd doc comment) — tests compare with is_equal_approx().
extends GdUnitTestSuite

const STAT: StringName = &"damage"

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


func test_effective_stat_crit_chance_above_cap_clamps_to_eighty_percent() -> void:
	# Formula 1 alone would resolve to 1.0 (base=1.0, no flat/additive) — cap clamps to 0.80.
	var hero := _make_hero_for_stat(&"crit_chance", 1.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_equal_approx(0.8, 0.0001)


func test_effective_stat_crit_chance_exactly_at_cap_passes_through_unclamped() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 0.8, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_equal_approx(0.8, 0.0001)


func test_effective_stat_crit_chance_below_cap_is_unaffected() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 0.5, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_equal_approx(0.5, 0.0001)


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
