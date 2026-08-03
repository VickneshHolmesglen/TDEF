## Integration tests for Story 009 (TR-menag-001, capacity half; ADR-0026 +
## ADR-0024): HABITAT capacity base value (AC-6) and Defense Building's
## sanctuary_structure_built subscription-driven expansion (AC-7).
##
## Per the story's own Implementation Notes, an isolated Menagerie-side
## simulated event is an acceptable interim test path (qa-lead-approved) —
## Menagerie is instantiated directly (no add_child()), so
## _on_sanctuary_structure_built() is called directly rather than through a
## live EventBus round-trip, matching this project's established convention
## for testing EventBus handlers without a live subscription.
extends GdUnitTestSuite

var _menagerie: Menagerie


func before_test() -> void:
	_menagerie = Menagerie.new()


func after_test() -> void:
	if _menagerie != null and is_instance_valid(_menagerie):
		_menagerie.free()
	_menagerie = null


# ---------------------------------------------------------------------------
# AC-6: fresh save, no structures built -> exactly 4.
# ---------------------------------------------------------------------------

func test_fresh_habitat_capacity_is_exactly_four() -> void:
	assert_int(_menagerie._habitat_capacity).is_equal(4)


# ---------------------------------------------------------------------------
# AC-7: +2 per Habitat Expansion tier event, capped at 12 (4 tiers, since
# 2026-08-03's real habitat_expansion_tier_4 + tech_structural_3 addition —
# was capped at 10/3 tiers before); a 5th event is a no-op past the cap;
# ordering is not assumed, only counted.
# ---------------------------------------------------------------------------

func test_habitat_capacity_increments_by_two_per_tier_event() -> void:
	_menagerie._on_sanctuary_structure_built("habitat_expansion_tier_1", "habitat_expansion")
	assert_int(_menagerie._habitat_capacity).is_equal(6)

	_menagerie._on_sanctuary_structure_built("habitat_expansion_tier_2", "habitat_expansion")
	assert_int(_menagerie._habitat_capacity).is_equal(8)

	_menagerie._on_sanctuary_structure_built("habitat_expansion_tier_3", "habitat_expansion")
	assert_int(_menagerie._habitat_capacity).is_equal(10)

	_menagerie._on_sanctuary_structure_built("habitat_expansion_tier_4", "habitat_expansion")
	assert_int(_menagerie._habitat_capacity).is_equal(12)


func test_fifth_habitat_expansion_event_is_a_no_op_past_the_cap() -> void:
	for i: int in range(4):
		_menagerie._on_sanctuary_structure_built("habitat_expansion_tier_%d" % (i + 1), "habitat_expansion")
	assert_int(_menagerie._habitat_capacity).is_equal(12)

	_menagerie._on_sanctuary_structure_built("habitat_expansion_tier_5_hypothetical", "habitat_expansion")
	assert_int(_menagerie._habitat_capacity).is_equal(12)


func test_non_habitat_expansion_structure_does_not_affect_capacity() -> void:
	_menagerie._on_sanctuary_structure_built("watchtower_tier_1", "watchtower")
	assert_int(_menagerie._habitat_capacity).is_equal(4)
