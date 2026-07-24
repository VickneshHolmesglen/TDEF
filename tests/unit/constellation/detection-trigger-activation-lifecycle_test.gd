## Unit tests for Story 002 (TR-const-001, ADR-0022): synchronous per-event
## detection trigger and activation lifecycle (Core Rules 3-4, 6).
##
## Same fixture conventions as pattern-catalogue-eligibility-matching_test.gd
## (Constellation.new() with no add_child(), GridSpyDouble injected on
## _grid, handler methods called directly rather than via a live EventBus
## emission).
extends GdUnitTestSuite

var _constellation: Constellation
var _grid: GridSpyDouble
var _spy: EventBusSpy


func before_test() -> void:
	_constellation = Constellation.new()
	_grid = GridSpyDouble.new()
	_constellation._grid = _grid
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.constellation_activated)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _constellation != null and is_instance_valid(_constellation):
		_constellation.free()
	_constellation = null
	_grid = null


func _place(tower_id: int, cell: Vector2i, tag: String) -> void:
	_grid.place(tower_id, cell)
	_constellation._on_tower_placed(TowerPlacedEvent.make(tower_id, cell, "BASIC", Vector2i.ONE, true, tag))


## See pattern-catalogue-eligibility-matching_test.gd's own copy of this
## helper for the full rationale: overlapping shapes (e.g. any 4-in-a-row
## also contains two valid triad_line sub-instances) are intrinsic, correct
## activations per Core Rule 6/AC-26 — tests must filter by pattern_id
## rather than assert a raw total.
func _count_activations_for(pattern_id: String) -> int:
	var count: int = 0
	for emission: Array in (_spy.emissions.get("constellation_activated", []) as Array):
		if (emission[0] as String) == pattern_id:
			count += 1
	return count


# ---------------------------------------------------------------------------
# AC-7: Recheck resolves synchronously, no await/frame advance needed
# ---------------------------------------------------------------------------

func test_recheck_resolves_synchronously_within_same_call() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")

	# No await/frame advance anywhere above or below this line — the
	# assertion below observes state that must already be correct the
	# instant the completing call returns.
	_place(3, Vector2i(4, 4), "solar")
	assert_int(_spy.count("constellation_activated")).is_equal(1)


# ---------------------------------------------------------------------------
# AC-8: Two independent placement events each trigger their own recheck
# ---------------------------------------------------------------------------

func test_two_independent_events_each_trigger_own_recheck_no_batching() -> void:
	_place(1, Vector2i(2, 4), "solar")  # completes nothing
	assert_int(_spy.count("constellation_activated")).is_equal(0)

	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "solar")  # completes triad_line
	assert_int(_spy.count("constellation_activated")).is_equal(1)


# ---------------------------------------------------------------------------
# AC-9: Activation fires exactly once; a later unrelated recheck does not re-fire
# ---------------------------------------------------------------------------

func test_activation_fires_exactly_once_with_correct_pattern_id_quad_line() -> void:
	_place(1, Vector2i(3, 5), "solar")
	_place(2, Vector2i(4, 5), "solar")
	# (3,5),(4,5),(5,5) is itself a valid triad_line — activates
	# independently the instant it's complete (Core Rule 6/AC-26), before
	# the 4th tower below turns the same run into a quad_line too.
	_place(3, Vector2i(5, 5), "solar")
	assert_int(_count_activations_for("triad_line@(3,5)")).is_equal(1)

	_place(4, Vector2i(6, 5), "solar")
	# This same placement also completes a second, independent triad_line
	# (4,5),(5,5),(6,5) — again correct, not a defect.
	assert_int(_count_activations_for("triad_line@(4,5)")).is_equal(1)

	assert_int(_count_activations_for("quad_line@(3,5)")).is_equal(1)
	var args: Array = []
	for emission: Array in (_spy.emissions["constellation_activated"] as Array):
		if (emission[0] as String) == "quad_line@(3,5)":
			args = emission
	assert_that(args[1] as Vector2i).is_equal(Vector2i(3, 5))
	assert_float(args[3] as float).is_equal_approx(0.135, 0.001)

	# An unrelated later placement, far from this instance, must not re-fire it.
	_place(5, Vector2i(20, 20), "solar")
	assert_int(_count_activations_for("quad_line@(3,5)")).is_equal(1)


# ---------------------------------------------------------------------------
# AC-12/AC-26: Two overlapping instances activate independently, no precedence
# ---------------------------------------------------------------------------

func test_single_event_completing_two_shapes_fires_both_independently() -> void:
	# l_corner@(20,20) (base orientation) needs (20,20),(21,20),(22,20),(20,21).
	# A SEPARATE, deliberately-overlapping triad_line@(20,21) (45-degree
	# diagonal) needs (20,21),(21,22),(22,23) — sharing member cell (20,21)
	# with the l_corner, but along a different axis so it does not coincide
	# with the l_corner's own run. Placing every member except the shared
	# cell first, then completing (20,21) last, makes that single placement
	# event complete both shapes simultaneously.
	#
	# Note: the l_corner's own 3-cell run (20,20),(21,20),(22,20) is itself
	# a valid triad_line@(20,20) — an intrinsic, independently-correct
	# activation (Core Rule 6/AC-26) that fires earlier, before the shared
	# cell is placed. This is asserted explicitly below, not treated as noise.
	_place(1, Vector2i(21, 20), "solar")
	_place(2, Vector2i(22, 20), "solar")
	_place(3, Vector2i(21, 22), "solar")
	_place(4, Vector2i(22, 23), "solar")
	assert_int(_count_activations_for("triad_line@(20,20)")).is_equal(0)

	_place(5, Vector2i(20, 20), "solar")  # completes the l_corner's own run
	assert_int(_count_activations_for("triad_line@(20,20)")).is_equal(1)
	assert_int(_count_activations_for("l_corner@(20,20)")).is_equal(0)
	assert_int(_count_activations_for("triad_line@(20,21)")).is_equal(0)

	# This single event completes BOTH l_corner@(20,20) (the shared cell)
	# AND the separate diagonal triad_line@(20,21) — two independent
	# activations from one placement event (AC-12), sharing member tower 6.
	var count_before: int = _spy.count("constellation_activated")
	_place(6, Vector2i(20, 21), "solar")
	var new_emissions: Array = (_spy.emissions["constellation_activated"] as Array).slice(count_before)

	assert_int(new_emissions.size()).is_equal(2)
	var new_pattern_ids: Array[String] = []
	for emission: Array in new_emissions:
		new_pattern_ids.append(emission[0] as String)
	assert_bool(new_pattern_ids.has("l_corner@(20,20)")).is_true()
	assert_bool(new_pattern_ids.has("triad_line@(20,21)")).is_true()

	# No precedence/suppression — each carries its own independently-correct
	# bonus_value (0.155 for l_corner, 0.100 for triad_line).
	for emission: Array in new_emissions:
		var pattern_id: String = emission[0] as String
		var bonus_value: float = emission[3] as float
		if pattern_id == "l_corner@(20,20)":
			assert_float(bonus_value).is_equal_approx(0.155, 0.001)
		elif pattern_id == "triad_line@(20,21)":
			assert_float(bonus_value).is_equal_approx(0.100, 0.001)
