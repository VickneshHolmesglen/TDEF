## Unit tests for Story 009 (TR-missel-003, ADR-0028): difficulty-tier
## selection (Rule 3, AC-4/AC-5) and per-tier completion tracking (Rule 4,
## Formula 3, AC-6/AC-7/AC-8).
##
## MissionSelect is instantiated directly (MissionSelect.new(), no
## add_child()) — matching Tarot/Menagerie's established test convention.
## select_mission() reads real GGameDataRegistry content (the_gap:
## recommended_difficulty_tier=1, the_narrows: recommended_difficulty_tier=2,
## both authored in Story 008) rather than a fabricated stub, since the
## Autoload is live in the gdUnit4 test runtime.
extends GdUnitTestSuite

var _mission_select: MissionSelect


func before_test() -> void:
	_mission_select = MissionSelect.new()


func after_test() -> void:
	if _mission_select != null and is_instance_valid(_mission_select):
		_mission_select.free()
	_mission_select = null


# ---------------------------------------------------------------------------
# AC-4: tier defaults to recommended_difficulty_tier, freely changeable
# ---------------------------------------------------------------------------

func test_select_mission_defaults_difficulty_tier_to_recommended() -> void:
	_mission_select.select_mission("the_narrows")  # recommended_difficulty_tier = 2
	assert_int(_mission_select.difficulty_tier).is_equal(2)


func test_set_difficulty_tier_allows_any_of_the_three_values() -> void:
	_mission_select.select_mission("the_narrows")
	_mission_select.set_difficulty_tier(1)
	assert_int(_mission_select.difficulty_tier).is_equal(1)
	_mission_select.set_difficulty_tier(3)
	assert_int(_mission_select.difficulty_tier).is_equal(3)
	_mission_select.set_difficulty_tier(2)
	assert_int(_mission_select.difficulty_tier).is_equal(2)


# ---------------------------------------------------------------------------
# AC-5: tier changes emit zero EventBus events
# ---------------------------------------------------------------------------

func test_set_difficulty_tier_emits_no_eventbus_events() -> void:
	# No difficulty_tier_selected (or equivalent) signal exists anywhere in
	# the frozen event contract (Rule 3) — watch every Mission-Select-adjacent
	# signal that could plausibly carry a tier change and confirm none fire.
	var spy: EventBusSpy = EventBusSpy.new()
	spy.watch(GEventBus.mission_selected)
	spy.watch(GEventBus.mission_launched)
	spy.watch(GEventBus.run_modifier_selected)
	_mission_select.select_mission("the_gap")
	spy.clear()  # select_mission() itself is Story 011's mission_selected trigger — not under test here
	_mission_select.set_difficulty_tier(1)
	_mission_select.set_difficulty_tier(3)
	_mission_select.set_difficulty_tier(2)
	assert_bool(spy.was_emitted("mission_selected")).is_false()
	assert_bool(spy.was_emitted("mission_launched")).is_false()
	assert_bool(spy.was_emitted("run_modifier_selected")).is_false()
	spy.disconnect_all()


# ---------------------------------------------------------------------------
# AC-1/EC-1 (via get_completion_record): absent entry == default record
# ---------------------------------------------------------------------------

func test_get_completion_record_returns_default_when_absent() -> void:
	var record: MissionCompletionRecord = _mission_select.get_completion_record("mission_02", 1)
	assert_bool(record.completed).is_false()
	assert_float(record.best_time_seconds).is_equal_approx(-1.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-6: per-tier independence
# ---------------------------------------------------------------------------

func test_record_completion_tracks_tiers_independently() -> void:
	_mission_select.record_completion("mission_02", 1, 900.0)

	var tier_1: MissionCompletionRecord = _mission_select.get_completion_record("mission_02", 1)
	assert_bool(tier_1.completed).is_true()
	assert_float(tier_1.best_time_seconds).is_equal_approx(900.0, 0.0001)

	var tier_2: MissionCompletionRecord = _mission_select.get_completion_record("mission_02", 2)
	assert_bool(tier_2.completed).is_false()
	assert_float(tier_2.best_time_seconds).is_equal_approx(-1.0, 0.0001)

	var tier_3: MissionCompletionRecord = _mission_select.get_completion_record("mission_02", 3)
	assert_bool(tier_3.completed).is_false()
	assert_float(tier_3.best_time_seconds).is_equal_approx(-1.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-7: monotonic best-time — slower attempt never regresses the record
# ---------------------------------------------------------------------------

func test_record_completion_slower_attempt_does_not_regress_best_time() -> void:
	_mission_select.record_completion("mission_02", 2, 980.0)
	_mission_select.record_completion("mission_02", 2, 1200.0)  # slower

	var record: MissionCompletionRecord = _mission_select.get_completion_record("mission_02", 2)
	assert_float(record.best_time_seconds).is_equal_approx(980.0, 0.0001)


func test_record_completion_faster_attempt_improves_best_time() -> void:
	_mission_select.record_completion("mission_02", 2, 1140.0)
	_mission_select.record_completion("mission_02", 2, 980.0)  # faster

	var record: MissionCompletionRecord = _mission_select.get_completion_record("mission_02", 2)
	assert_float(record.best_time_seconds).is_equal_approx(980.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-8: sentinel replacement — -1.0 replaced by first real completion
# ---------------------------------------------------------------------------

func test_record_completion_replaces_sentinel_with_first_real_time() -> void:
	var before_record: MissionCompletionRecord = _mission_select.get_completion_record("mission_03", 3)
	assert_float(before_record.best_time_seconds).is_equal_approx(-1.0, 0.0001)

	_mission_select.record_completion("mission_03", 3, 750.0)

	var after_record: MissionCompletionRecord = _mission_select.get_completion_record("mission_03", 3)
	assert_bool(after_record.completed).is_true()
	assert_float(after_record.best_time_seconds).is_equal_approx(750.0, 0.0001)
