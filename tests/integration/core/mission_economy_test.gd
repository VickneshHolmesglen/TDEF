## Integration tests for MissionEconomy, Epic 03 Story 013, ADR-0018.
##
## Covers AC-11 (resets to 0 on mission_launched, including a second launch in
## the same session), AC-12 (accumulates correctly across sequential deltas),
## and AC-13 (can_afford() boundary — cost == balance returns true, not
## strictly less-than). Also covers the QA Test Cases' explicit edge case: a
## delta that drives the balance negative is applied as-is (no silent
## clamping), and can_afford() correctly returns false for any positive cost
## afterward.
##
## GMissionEconomy is a real, live Autoload in the test runner (boots before
## any test scene, per ADR-0018) — this suite does NOT instantiate a second
## copy via .new(). It uses the global GMissionEconomy/GEventBus singleton
## references directly, matching the established convention for other
## Autoload-backed cross-suite state in this codebase (see
## tests/integration/mission_scene/mission_scene_the_gap_test.gd's after_test()
## resetting the real GGrid Autoload directly). Because _gold_balance is real,
## persistent singleton state — not a fresh instance per test — every test
## here resets it to a known 0 baseline in before_test() by emitting the real
## GEventBus.mission_launched signal (the same reset trigger production code
## uses), rather than reaching into _gold_balance directly.
extends GdUnitTestSuite


func before_test() -> void:
	# TD-test-004: broadcasting the real mission_launched signal here (as
	# before_test/after_test setup/teardown boilerplate, not as the thing
	# under test) cascades into WaveManager/SavePersistence/Menagerie/
	# HeroSkillBuild/Tarot's own handlers too, and repeating that across many
	# gdUnit4 test-case boundaries in one suite run is a confirmed orphan-leak
	# mechanism (see docs/tech-debt-register.md). Calling MissionEconomy's own
	# reset handler directly resets the exact same state without cascading
	# into those other 4 systems' handlers -- the 2 tests that specifically
	# verify the broadcast mechanism itself (AC-11) still use the real
	# GEventBus.mission_launched.emit() inside their own test bodies.
	GMissionEconomy._on_mission_launched("test_mission", PackedStringArray(), 1)


func after_test() -> void:
	GMissionEconomy._on_mission_launched("test_mission", PackedStringArray(), 1)


# ---------------------------------------------------------------------------
# AC-11: resets to 0 on mission_launched, including a second launch in the
# same session (not just cold boot).
# ---------------------------------------------------------------------------

func test_mission_launched_resets_balance_to_zero_after_prior_gold() -> void:
	GEventBus.resources_changed.emit(500, &"test_source")
	assert_int(GMissionEconomy.get_gold_balance()).is_equal(500)

	GEventBus.mission_launched.emit("test_mission", PackedStringArray(), 1)

	assert_int(GMissionEconomy.get_gold_balance()).is_equal(0)


func test_second_mission_launched_in_same_session_resets_cleanly() -> void:
	GEventBus.mission_launched.emit("first_mission", PackedStringArray(), 1)
	GEventBus.resources_changed.emit(200, &"test_source")
	assert_int(GMissionEconomy.get_gold_balance()).is_equal(200)

	GEventBus.mission_launched.emit("second_mission", PackedStringArray(), 2)

	assert_int(GMissionEconomy.get_gold_balance()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-12: balance accumulates correctly across sequential deltas.
# ---------------------------------------------------------------------------

func test_balance_accumulates_scout_grant_then_tower_placement_spend() -> void:
	GEventBus.resources_changed.emit(150, &"mission_start_grant")
	GEventBus.resources_changed.emit(-30, &"tower_placement")

	assert_int(GMissionEconomy.get_gold_balance()).is_equal(120)


## AC-12 edge case: a delta that would drive the balance negative is applied
## as-is — no silent clamping.
func test_negative_delta_drives_balance_negative_without_clamping() -> void:
	GEventBus.resources_changed.emit(50, &"test_source")
	GEventBus.resources_changed.emit(-80, &"test_source")

	assert_int(GMissionEconomy.get_gold_balance()).is_equal(-30)


## QA Test Cases edge case: after a negative balance, can_afford() correctly
## returns false for any positive cost.
func test_can_afford_returns_false_for_any_positive_cost_after_negative_balance() -> void:
	GEventBus.resources_changed.emit(50, &"test_source")
	GEventBus.resources_changed.emit(-80, &"test_source")
	assert_int(GMissionEconomy.get_gold_balance()).is_equal(-30)

	assert_bool(GMissionEconomy.can_afford(1)).is_false()
	assert_bool(GMissionEconomy.can_afford(30)).is_false()


# ---------------------------------------------------------------------------
# AC-13: can_afford() boundary — cost == balance returns true, not strictly
# less-than.
# ---------------------------------------------------------------------------

func test_can_afford_returns_true_when_cost_exactly_equals_balance() -> void:
	GEventBus.resources_changed.emit(120, &"test_source")
	assert_int(GMissionEconomy.get_gold_balance()).is_equal(120)

	assert_bool(GMissionEconomy.can_afford(120)).is_true()


func test_can_afford_returns_false_when_cost_exceeds_balance_by_one() -> void:
	GEventBus.resources_changed.emit(120, &"test_source")
	assert_int(GMissionEconomy.get_gold_balance()).is_equal(120)

	assert_bool(GMissionEconomy.can_afford(121)).is_false()


func test_can_afford_returns_true_when_cost_is_strictly_less_than_balance() -> void:
	GEventBus.resources_changed.emit(120, &"test_source")

	assert_bool(GMissionEconomy.can_afford(119)).is_true()
