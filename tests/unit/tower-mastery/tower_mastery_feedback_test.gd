## Unit tests for Story 013's TowerMasteryFeedback: arc creation/positioning
## from mastery_progress_updated, destroyed-anchor pause and automatic
## repositioning/resumption, staleness-based out-of-range pause, the
## skill_tree_point_earned/skill_tree_overflow_point_earned pulse hookup
## (replaces the pre-2026-08-31 skill_unlocked hookup — see
## tower_mastery_feedback.gd's own _on_skill_tree_point_earned doc comment),
## and post-fade arc cleanup.
##
## TowerMasteryFeedback is instantiated directly (no add_child()) so
## _ready() never fires — handler methods and _process() are called
## directly with a GridSpyDouble injected on _grid, matching this system's
## established test convention (Stories 007-011's own TowerMastery tests).
extends GdUnitTestSuite

var _feedback: TowerMasteryFeedback
var _grid: GridSpyDouble


func before_test() -> void:
	_feedback = TowerMasteryFeedback.new()
	_grid = GridSpyDouble.new()
	_feedback._grid = _grid


func after_test() -> void:
	if _feedback != null and is_instance_valid(_feedback):
		for signature: String in _feedback._arcs:
			var arc: TowerMasteryArc = _feedback._arcs[signature]
			if is_instance_valid(arc):
				arc.free()
		_feedback.free()
	_feedback = null
	_grid = null


func _place(tower_id: int, cell: Vector2i, foundation_id: String = "found_basic",
		weapon_id: String = "weap_frost_bolt", focus_id: String = "focus_none", power_id: String = "power_none") -> void:
	_grid.place(tower_id, cell)
	_feedback._on_tower_placed(TowerPlacedEvent.make(
		tower_id, cell, "BASIC", Vector2i.ONE, true, "", foundation_id, weapon_id, focus_id, power_id
	))


# ---------------------------------------------------------------------------
# Arc creation and world positioning from mastery_progress_updated
# ---------------------------------------------------------------------------

func test_mastery_progress_updated_creates_arc_at_towers_world_position() -> void:
	_place(1, Vector2i(2, 3))
	var signature: String = TowerMastery.compute_build_signature("found_basic", "weap_frost_bolt", "focus_none", "power_none")

	_feedback._on_mastery_progress_updated(1, signature, 40.0)

	assert_bool(_feedback._arcs.has(signature)).is_true()
	var arc: TowerMasteryArc = _feedback._arcs[signature]
	assert_that(arc.position).is_equal(_grid.cell_to_world(Vector2i(2, 3)))
	assert_float(arc.progress_percent).is_equal_approx(40.0, 0.0001)
	assert_int(arc.state).is_equal(TowerMasteryArc.State.ACCRUING)


func test_mastery_progress_updated_sets_the_arcs_archetype_from_tower_placed() -> void:
	_place(1, Vector2i(2, 3))
	var signature: String = TowerMastery.compute_build_signature("found_basic", "weap_frost_bolt", "focus_none", "power_none")

	_feedback._on_mastery_progress_updated(1, signature, 40.0)

	var arc: TowerMasteryArc = _feedback._arcs[signature]
	assert_str(arc.archetype).is_equal("BASIC")


func test_repeated_updates_reuse_the_same_arc_instance() -> void:
	_place(1, Vector2i(2, 3))
	var signature: String = TowerMastery.compute_build_signature("found_basic", "weap_frost_bolt", "focus_none", "power_none")

	_feedback._on_mastery_progress_updated(1, signature, 10.0)
	var arc_first: TowerMasteryArc = _feedback._arcs[signature]
	_feedback._on_mastery_progress_updated(1, signature, 20.0)
	var arc_second: TowerMasteryArc = _feedback._arcs[signature]

	assert_object(arc_first).is_same(arc_second)
	assert_float(arc_second.progress_percent).is_equal_approx(20.0, 0.0001)


# ---------------------------------------------------------------------------
# Destroyed-anchor pause and automatic resumption/repositioning
# ---------------------------------------------------------------------------

func test_tower_destroyed_pauses_its_signatures_arc_immediately() -> void:
	_place(1, Vector2i(2, 3))
	var signature: String = TowerMastery.compute_build_signature("found_basic", "weap_frost_bolt", "focus_none", "power_none")
	_feedback._on_mastery_progress_updated(1, signature, 30.0)

	_grid.remove(Vector2i(2, 3))
	_feedback._on_tower_destroyed(1, Vector2i(2, 3), "BASIC", [Vector2i(2, 3)], "")

	var arc: TowerMasteryArc = _feedback._arcs[signature]
	assert_int(arc.state).is_equal(TowerMasteryArc.State.PAUSED_DESTROYED)


func test_tower_removed_pauses_its_signatures_arc_immediately() -> void:
	_place(1, Vector2i(2, 3))
	var signature: String = TowerMastery.compute_build_signature("found_basic", "weap_frost_bolt", "focus_none", "power_none")
	_feedback._on_mastery_progress_updated(1, signature, 30.0)

	_grid.remove(Vector2i(2, 3))
	_feedback._on_tower_removed(1, Vector2i(2, 3), "BASIC", "")

	var arc: TowerMasteryArc = _feedback._arcs[signature]
	assert_int(arc.state).is_equal(TowerMasteryArc.State.PAUSED_DESTROYED)


func test_new_update_for_a_different_tower_with_same_signature_resumes_and_repositions_arc() -> void:
	_place(1, Vector2i(2, 3))
	var signature: String = TowerMastery.compute_build_signature("found_basic", "weap_frost_bolt", "focus_none", "power_none")
	_feedback._on_mastery_progress_updated(1, signature, 30.0)
	_grid.remove(Vector2i(2, 3))
	_feedback._on_tower_destroyed(1, Vector2i(2, 3), "BASIC", [Vector2i(2, 3)], "")

	# A different, still-live tower shares the signature and is now the
	# representative — TowerMastery would emit this on its next tick.
	_place(9, Vector2i(6, 6))
	_feedback._on_mastery_progress_updated(9, signature, 33.0)

	var arc: TowerMasteryArc = _feedback._arcs[signature]
	assert_int(arc.state).is_equal(TowerMasteryArc.State.ACCRUING)
	assert_that(arc.position).is_equal(_grid.cell_to_world(Vector2i(6, 6)))


# ---------------------------------------------------------------------------
# Staleness-based out-of-range pause (no explicit "left range" event exists)
# ---------------------------------------------------------------------------

func test_arc_pauses_out_of_range_after_stale_threshold_with_no_updates() -> void:
	_place(1, Vector2i(2, 3))
	var signature: String = TowerMastery.compute_build_signature("found_basic", "weap_frost_bolt", "focus_none", "power_none")
	_feedback._on_mastery_progress_updated(1, signature, 30.0)

	_feedback._process(TowerMasteryFeedback.STALE_THRESHOLD_SECONDS + 0.1)

	var arc: TowerMasteryArc = _feedback._arcs[signature]
	assert_int(arc.state).is_equal(TowerMasteryArc.State.PAUSED_OUT_OF_RANGE)


func test_arc_does_not_pause_before_stale_threshold_elapses() -> void:
	_place(1, Vector2i(2, 3))
	var signature: String = TowerMastery.compute_build_signature("found_basic", "weap_frost_bolt", "focus_none", "power_none")
	_feedback._on_mastery_progress_updated(1, signature, 30.0)

	_feedback._process(TowerMasteryFeedback.STALE_THRESHOLD_SECONDS * 0.5)

	var arc: TowerMasteryArc = _feedback._arcs[signature]
	assert_int(arc.state).is_equal(TowerMasteryArc.State.ACCRUING)


func test_fresh_update_before_stale_threshold_prevents_pause() -> void:
	_place(1, Vector2i(2, 3))
	var signature: String = TowerMastery.compute_build_signature("found_basic", "weap_frost_bolt", "focus_none", "power_none")
	_feedback._on_mastery_progress_updated(1, signature, 30.0)

	_feedback._process(TowerMasteryFeedback.STALE_THRESHOLD_SECONDS * 0.5)
	_feedback._on_mastery_progress_updated(1, signature, 31.0)  # hero still in range
	_feedback._process(TowerMasteryFeedback.STALE_THRESHOLD_SECONDS * 0.5)

	var arc: TowerMasteryArc = _feedback._arcs[signature]
	assert_int(arc.state).is_equal(TowerMasteryArc.State.ACCRUING)


# ---------------------------------------------------------------------------
# skill_tree_point_earned / skill_tree_overflow_point_earned hookup
# ---------------------------------------------------------------------------

func test_skill_tree_point_earned_triggers_pulse_on_the_towers_arc() -> void:
	_place(1, Vector2i(2, 3))
	var signature: String = TowerMastery.compute_build_signature("found_basic", "weap_frost_bolt", "focus_none", "power_none")
	_feedback._on_mastery_progress_updated(1, signature, 100.0)

	_feedback._on_skill_tree_point_earned("physical", 1)

	var arc: TowerMasteryArc = _feedback._arcs[signature]
	assert_int(arc.state).is_equal(TowerMasteryArc.State.UNLOCKED_PULSE)


func test_skill_tree_overflow_point_earned_triggers_pulse_on_the_towers_arc() -> void:
	_place(1, Vector2i(2, 3))
	var signature: String = TowerMastery.compute_build_signature("found_basic", "weap_frost_bolt", "focus_none", "power_none")
	_feedback._on_mastery_progress_updated(1, signature, 100.0)

	_feedback._on_skill_tree_overflow_point_earned(1)

	var arc: TowerMasteryArc = _feedback._arcs[signature]
	assert_int(arc.state).is_equal(TowerMasteryArc.State.UNLOCKED_PULSE)


func test_skill_tree_point_earned_for_unknown_tower_does_not_crash() -> void:
	_feedback._on_skill_tree_point_earned("physical", 999)
	assert_int(_feedback._arcs.size()).is_equal(0)


func test_skill_tree_overflow_point_earned_for_unknown_tower_does_not_crash() -> void:
	_feedback._on_skill_tree_overflow_point_earned(999)
	assert_int(_feedback._arcs.size()).is_equal(0)


# ---------------------------------------------------------------------------
# Post-fade cleanup
# ---------------------------------------------------------------------------

func test_arc_is_freed_after_destroyed_fade_completes() -> void:
	_place(1, Vector2i(2, 3))
	var signature: String = TowerMastery.compute_build_signature("found_basic", "weap_frost_bolt", "focus_none", "power_none")
	_feedback._on_mastery_progress_updated(1, signature, 30.0)
	_grid.remove(Vector2i(2, 3))
	_feedback._on_tower_destroyed(1, Vector2i(2, 3), "BASIC", [Vector2i(2, 3)], "")

	# TowerMasteryArc is a Node2D child normally driven by the engine's own
	# per-node _process() once it's live in a scene tree — since this arc
	# was never add_child()'d to a running tree in this unit test, its own
	# fade timer must be advanced directly here (mirrors
	# tower_mastery_arc_test.gd's own direct-_process() convention).
	var arc: TowerMasteryArc = _feedback._arcs[signature]
	arc._process(TowerMasteryArc.DESTROYED_FADE_SECONDS + 0.1)
	_feedback._process(0.016)

	assert_bool(_feedback._arcs.has(signature)).is_false()
