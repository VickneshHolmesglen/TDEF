## Unit tests for Story 010 (TR-towermast-001, ADR-0029): mastery_time
## accrual (Formula 1), progress_percent display clamp (Formula 2), and the
## set-before-emit unlock idempotency (Formula 3).
##
## TowerMastery is instantiated directly (TowerMastery.new(), no add_child())
## so _ready() never fires — handler methods and tick() are called directly
## with a GridSpyDouble injected on _grid, matching Stories 007-009's own
## established convention for this system's tests.
##
## Per the story's own note: "frost_bolt_skill_a" and any skill_id used here
## is illustrative only — no real skill catalogue exists yet (deferred
## content, Rule 7/ADR-0030). tower_mastery.gd's current implementation uses
## the build_signature itself as a placeholder skill_id, so these tests
## assert against the signature string, not a real catalogue entry.
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
	_spy.watch(GEventBus.skill_unlocked)


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
		tower_id, cell, "BASIC", Vector2i.ONE, true, "", "found_basic", "weap_frost_bolt", "focus_none", "power_none"
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
# AC-21: unlocked_skills[skill_id] set true BEFORE skill_unlocked emits;
# idempotent same-frame re-evaluation (cannot double-fire same tick)
# ---------------------------------------------------------------------------

func test_unlock_flag_set_before_emit_and_same_tick_reevaluation_does_not_refire() -> void:
	_place_and_track(0, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[0]

	_tower_mastery.tick(45.0)  # crosses threshold this tick

	assert_bool(_tower_mastery._unlocked_signatures.get(signature, false)).is_true()
	assert_int(_spy.count("skill_unlocked")).is_equal(1)

	# Same-tick re-evaluation (a second tick() call within the same frame,
	# simulating any re-entrant recompute) must not double-fire.
	_tower_mastery.tick(0.0)
	assert_int(_spy.count("skill_unlocked")).is_equal(1)


func test_skill_unlocked_uses_representative_live_tower_id() -> void:
	_place_and_track(5, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[5]

	_tower_mastery.tick(45.0)

	var emissions: Array = _spy.emissions["skill_unlocked"] as Array
	assert_str(emissions[0][0] as String).is_equal(signature)
	assert_int(emissions[0][1] as int).is_equal(5)


# ---------------------------------------------------------------------------
# AC-22: post-unlock accrual continues unbounded; skill_unlocked never
# re-fires for the same skill_id
# ---------------------------------------------------------------------------

func test_post_unlock_accrual_continues_unbounded_without_refiring() -> void:
	_place_and_track(0, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[0]

	_tower_mastery.tick(45.0)
	assert_int(_spy.count("skill_unlocked")).is_equal(1)

	_tower_mastery.tick(100.0)
	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(145.0, 0.0001)
	assert_int(_spy.count("skill_unlocked")).is_equal(1)

	var emissions: Array = _spy.emissions.get("mastery_progress_updated", []) as Array
	var last: Array = emissions[emissions.size() - 1] as Array
	assert_float(last[2] as float).is_equal_approx(100.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-23: two different build signatures accrue independently and in
# parallel (no "nearest tower wins")
# ---------------------------------------------------------------------------

func test_two_different_signatures_accrue_independently_in_parallel() -> void:
	_grid.place(1, Vector2i(2, 2))
	_tower_mastery._on_tower_placed(TowerPlacedEvent.make(
		1, Vector2i(2, 2), "BASIC", Vector2i.ONE, true, "", "found_basic", "weap_frost_bolt", "focus_none", "power_none"
	))
	var sig_frost: String = _tower_mastery._active_signature_by_tower[1]

	_grid.place(2, Vector2i(5, 5))
	_tower_mastery._on_tower_placed(TowerPlacedEvent.make(
		2, Vector2i(5, 5), "BASIC", Vector2i.ONE, true, "", "found_siege", "weap_cannon", "focus_none", "power_none"
	))
	var sig_siege: String = _tower_mastery._active_signature_by_tower[2]
	assert_str(sig_frost).is_not_equal(sig_siege)

	_tower_mastery._signatures_in_range[sig_frost] = true
	_tower_mastery._signatures_in_range[sig_siege] = true

	_tower_mastery.tick(10.0)

	assert_float(_tower_mastery.mastery_time[sig_frost]).is_equal_approx(10.0, 0.0001)
	assert_float(_tower_mastery.mastery_time[sig_siege]).is_equal_approx(10.0, 0.0001)
