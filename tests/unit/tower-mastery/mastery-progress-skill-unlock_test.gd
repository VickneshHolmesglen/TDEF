## Unit tests for Story 010 (TR-towermast-001, ADR-0029): mastery_time
## accrual (Formula 1), progress_percent display clamp (Formula 2), and
## Formula 3's skill_tree_point_earned granting (revised 2026-09-01 for
## hero-skill-tree.md/tower-mastery.md's Rule 13 revision — Tower Mastery no
## longer unlocks a skill directly; it grants a repeating, archetype-keyed
## skill tree point on every whole multiple of MASTERY_THRESHOLD_SECONDS
## crossed, tracked via points_granted_count rather than a one-shot flag).
##
## TowerMastery is instantiated directly (TowerMastery.new(), no add_child())
## so _ready() never fires — handler methods and tick() are called directly
## with a GridSpyDouble injected on _grid, matching Stories 007-009's own
## established convention for this system's tests.
##
## "physical" (the archetype string TowerPlacedEvent.make()'s 3rd argument
## carries here) is used as a valid, real archetype value throughout — Hero
## Skill Tree's own point-crediting handler validates against the 4 real
## archetype strings, so these tests use one rather than the pre-revision
## placeholder "BASIC" to stay representative of a real emission.
extends GdUnitTestSuite

var _tower_mastery: TowerMastery
var _grid: GridSpyDouble
var _spy: EventBusSpy


func before_test() -> void:
	_tower_mastery = TowerMastery.new()
	_grid = GridSpyDouble.new()
	_tower_mastery._grid = _grid
	_tower_mastery._current_phase = "WAVE_ACTIVE"
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.mastery_progress_updated)
	_spy.watch(GEventBus.skill_tree_point_earned)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _tower_mastery != null and is_instance_valid(_tower_mastery):
		_tower_mastery.free()
	_tower_mastery = null
	_grid = null


func _place_and_track(tower_id: int, cell: Vector2i) -> void:
	_grid.place(tower_id, cell)
	_tower_mastery._on_tower_placed(TowerPlacedEvent.make(
		tower_id, cell, "physical", Vector2i.ONE, true, "", "found_basic", "weap_frost_bolt", "focus_none", "power_none"
	))
	_tower_mastery._signatures_in_range[_tower_mastery._active_signature_by_tower[tower_id]] = true


# ---------------------------------------------------------------------------
# AC-19: mastery_time sums correctly across mission boundaries
# (Formula 1 worked example: 18 + 30 = 48)
# ---------------------------------------------------------------------------

func test_mastery_time_sums_across_mission_boundaries() -> void:
	_place_and_track(0, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[0]

	_tower_mastery.tick(18.0)  # Mission 1
	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(18.0, 0.0001)

	# Mission 2: different tower_id, same signature, hero re-tracks it.
	_place_and_track(2, Vector2i(5, 5))
	_tower_mastery.tick(30.0)

	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(48.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-20: progress_percent clamps at 100.0 for display even though
# underlying mastery_time exceeds threshold
# ---------------------------------------------------------------------------

func test_progress_percent_clamps_at_100_while_mastery_time_exceeds_threshold() -> void:
	_place_and_track(0, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[0]

	_tower_mastery.tick(48.0)  # exceeds MASTERY_THRESHOLD_SECONDS (45.0)

	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(48.0, 0.0001)
	var emissions: Array = _spy.emissions.get("mastery_progress_updated", []) as Array
	var last: Array = emissions[emissions.size() - 1] as Array
	assert_str(last[1] as String).is_equal(signature)
	assert_float(last[2] as float).is_equal_approx(100.0, 0.0001)


func test_progress_percent_reflects_partial_progress_below_threshold() -> void:
	_place_and_track(0, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[0]

	_tower_mastery.tick(22.5)  # exactly half of the 45.0 threshold

	var emissions: Array = _spy.emissions.get("mastery_progress_updated", []) as Array
	var last: Array = emissions[emissions.size() - 1] as Array
	assert_str(last[1] as String).is_equal(signature)
	assert_float(last[2] as float).is_equal_approx(50.0, 0.0001)


# ---------------------------------------------------------------------------
# Formula 3 (revised 2026-09-01): points_granted_count[signature] set BEFORE
# skill_tree_point_earned emits; idempotent same-frame re-evaluation (a
# repeat tick() call within the same frame, crossing no NEW multiple, must
# not double-fire).
# ---------------------------------------------------------------------------

func test_point_grant_count_set_before_emit_and_same_tick_reevaluation_does_not_refire() -> void:
	_place_and_track(0, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[0]

	_tower_mastery.tick(45.0)  # crosses 1 whole multiple this tick

	assert_int(_tower_mastery.points_granted_count.get(signature, 0)).is_equal(1)
	assert_int(_spy.count("skill_tree_point_earned")).is_equal(1)

	# Same-tick re-evaluation (a second tick() call within the same frame,
	# simulating any re-entrant recompute) crosses no further multiple and
	# must not double-fire.
	_tower_mastery.tick(0.0)
	assert_int(_spy.count("skill_tree_point_earned")).is_equal(1)


func test_skill_tree_point_earned_carries_archetype_and_representative_live_tower_id() -> void:
	_place_and_track(5, Vector2i(2, 2))

	_tower_mastery.tick(45.0)

	var emissions: Array = _spy.emissions["skill_tree_point_earned"] as Array
	assert_str(emissions[0][0] as String).is_equal("physical")
	assert_int(emissions[0][1] as int).is_equal(5)


# ---------------------------------------------------------------------------
# Rule 14 (past-100% continuation, revised 2026-09-01): post-grant accrual
# continues unbounded AND grants a further point on every subsequent whole
# multiple of MASTERY_THRESHOLD_SECONDS crossed — this is the behavior
# change from the pre-revision one-shot skill_unlocked: the point economy is
# a repeating faucet, not a single unlock.
# ---------------------------------------------------------------------------

func test_post_grant_accrual_continues_and_grants_further_points_on_each_crossing() -> void:
	_place_and_track(0, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[0]

	_tower_mastery.tick(45.0)  # 1st crossing (45.0 / 45.0 = 1)
	assert_int(_spy.count("skill_tree_point_earned")).is_equal(1)

	_tower_mastery.tick(100.0)  # mastery_time now 145.0 -> floor(145/45) = 3 total crossings
	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(145.0, 0.0001)
	assert_int(_tower_mastery.points_granted_count[signature]).is_equal(3)
	assert_int(_spy.count("skill_tree_point_earned")).is_equal(3)  # 1 + 2 more granted this tick

	var emissions: Array = _spy.emissions.get("mastery_progress_updated", []) as Array
	var last: Array = emissions[emissions.size() - 1] as Array
	assert_float(last[2] as float).is_equal_approx(100.0, 0.0001)


# ---------------------------------------------------------------------------
# A signature with no tracked archetype (e.g. no tower_placed ever set one)
# never grants a point — a missing archetype is a data gap, not a "grant
# under an empty-string archetype" fallback.
# ---------------------------------------------------------------------------

func test_no_grant_fires_when_signature_has_no_tracked_archetype() -> void:
	_grid.place(0, Vector2i(2, 2))
	var signature: String = TowerMastery.compute_build_signature("found_basic", "weap_frost_bolt", "focus_none", "power_none")
	_tower_mastery._active_signature_by_tower[0] = signature
	_tower_mastery._signatures_in_range[signature] = true
	# Deliberately never call _on_tower_placed(), so _archetype_by_signature
	# has no entry for this signature.

	_tower_mastery.tick(45.0)

	assert_int(_spy.count("skill_tree_point_earned")).is_equal(0)
	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(45.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-23: two different build signatures accrue independently and in
# parallel (no "nearest tower wins")
# ---------------------------------------------------------------------------

func test_two_different_signatures_accrue_independently_in_parallel() -> void:
	_grid.place(1, Vector2i(2, 2))
	_tower_mastery._on_tower_placed(TowerPlacedEvent.make(
		1, Vector2i(2, 2), "physical", Vector2i.ONE, true, "", "found_basic", "weap_frost_bolt", "focus_none", "power_none"
	))
	var sig_frost: String = _tower_mastery._active_signature_by_tower[1]

	_grid.place(2, Vector2i(5, 5))
	_tower_mastery._on_tower_placed(TowerPlacedEvent.make(
		2, Vector2i(5, 5), "ranged", Vector2i.ONE, true, "", "found_siege", "weap_cannon", "focus_none", "power_none"
	))
	var sig_siege: String = _tower_mastery._active_signature_by_tower[2]
	assert_str(sig_frost).is_not_equal(sig_siege)

	_tower_mastery._signatures_in_range[sig_frost] = true
	_tower_mastery._signatures_in_range[sig_siege] = true

	_tower_mastery.tick(10.0)

	assert_float(_tower_mastery.mastery_time[sig_frost]).is_equal_approx(10.0, 0.0001)
	assert_float(_tower_mastery.mastery_time[sig_siege]).is_equal_approx(10.0, 0.0001)
