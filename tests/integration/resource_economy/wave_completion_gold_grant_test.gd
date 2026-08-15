## Integration tests for Formula 5 — Wave-Completion Gold Grant
## (design/gdd/resource-economy.md Rule 10), player-requested 2026-08-15.
##
## Closes acceptance criteria AC-18a/AC-18b/AC-19a/AC-19b, which were added
## to the GDD on 2026-07-14 alongside Formula 5 but never picked up by any
## story (Story 013 only covers the Scout starting grant, AC-09/AC-10) —
## this is the first real implementation and test coverage for them.
##
## Follows gold_track_scout_grant_test.gd's exact established convention:
## ResourceEconomy tests use add_child()-then-real-signal dispatch, observed
## via tests/helpers/event_bus_spy.gd's EventBusSpy.
extends GdUnitTestSuite

var _re: ResourceEconomy
var _spy: EventBusSpy


func before_test() -> void:
	_re = ResourceEconomy.new()
	add_child(_re)  # triggers _ready() — wave_started/wave_completed subscriptions are live
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.resources_changed)
	_spy.watch(GEventBus.materials_earned)
	_spy.watch(GEventBus.materials_spent)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null

	if _re != null and is_instance_valid(_re):
		remove_child(_re)
		_re.free()
	_re = null


# ---------------------------------------------------------------------------
# AC-18a/AC-18b: real worked examples from the GDD itself.
# ---------------------------------------------------------------------------

## AC-18a: wave 4 at WaveManager's documented default difficulty_growth_rate
## (0.20) -> wave_reward_scalar = 1.20^3 = 1.728 -> round(20 * 1.728) = 35.
func test_wave_4_default_difficulty_grants_35_gold() -> void:
	GEventBus.wave_started.emit(4, 6, 1.728)
	GEventBus.wave_completed.emit(4, 0, false)

	assert_int(_spy.count("resources_changed")).is_equal(1)
	var args: Array = (_spy.emissions["resources_changed"] as Array)[0]
	assert_int(args[0]).is_equal(35)
	assert_str(String(args[1])).is_equal("wave_completion_grant")


## AC-18b: wave 4 at the safe-range ceiling (0.25) -> wave_reward_scalar =
## 1.953 -> round(20 * 1.953) = 39.
func test_wave_4_ceiling_difficulty_grants_39_gold() -> void:
	GEventBus.wave_started.emit(4, 6, 1.953)
	GEventBus.wave_completed.emit(4, 0, false)

	assert_int(_spy.count("resources_changed")).is_equal(1)
	var args: Array = (_spy.emissions["resources_changed"] as Array)[0]
	assert_int(args[0]).is_equal(39)


# ---------------------------------------------------------------------------
# AC-19a: full 6-wave mission at default difficulty, exact per-wave amounts.
# ---------------------------------------------------------------------------

## Reproduces the GDD's own AC-19a worked totals: at r=0.20, waves 1-6 grant
## 20/24/29/35/41/50 gold respectively (sum 199) -- verifies both the exact
## per-wave sequence and the running total, since a single-wave test alone
## wouldn't catch a rounding-accumulation bug across a full mission.
func test_six_wave_mission_at_default_difficulty_matches_gdd_worked_totals() -> void:
	var scalars: Array[float] = [1.0, 1.2, 1.44, 1.728, 2.0736, 2.48832]
	var expected_grants: Array[int] = [20, 24, 29, 35, 41, 50]
	var running_total: int = 0

	for i: int in range(6):
		var wave_number: int = i + 1
		GEventBus.wave_started.emit(wave_number, 6, scalars[i])
		GEventBus.wave_completed.emit(wave_number, 0, false)
		var args: Array = (_spy.emissions["resources_changed"] as Array)[i]
		assert_int(args[0]) \
				.override_failure_message("wave %d expected %d gold, got %d" % [wave_number, expected_grants[i], args[0]]) \
				.is_equal(expected_grants[i])
		running_total += args[0] as int

	assert_int(_spy.count("resources_changed")).is_equal(6)
	assert_int(running_total).is_equal(199)


# ---------------------------------------------------------------------------
# Structural/edge-case coverage.
# ---------------------------------------------------------------------------

func test_grant_fires_only_resources_changed_never_materials_signals() -> void:
	GEventBus.wave_started.emit(1, 6, 1.0)
	GEventBus.wave_completed.emit(1, 0, false)

	assert_int(_spy.count("resources_changed")).is_equal(1)
	assert_int(_spy.count("materials_earned")).is_equal(0)
	assert_int(_spy.count("materials_spent")).is_equal(0)


## GDD Rule 10's text states no exception for a boss-breach wave -- the
## grant fires the same regardless of was_boss_breached.
func test_grant_fires_on_boss_breached_wave_completion_too() -> void:
	GEventBus.wave_started.emit(1, 6, 1.0)
	GEventBus.wave_completed.emit(1, 3, true)

	assert_int(_spy.count("resources_changed")).is_equal(1)
	var args: Array = (_spy.emissions["resources_changed"] as Array)[0]
	assert_int(args[0]).is_equal(20)


## A wave_completed with no prior wave_started on this instance falls back
## to the 1.0 default scalar -- documents the fallback explicitly, even
## though real gameplay always fires wave_started first for the same wave
## (WaveManager's own FSM: PRE_WAVE always precedes WAVE_ACTIVE).
func test_wave_completed_with_no_prior_wave_started_uses_default_scalar() -> void:
	GEventBus.wave_completed.emit(1, 0, false)

	assert_int(_spy.count("resources_changed")).is_equal(1)
	var args: Array = (_spy.emissions["resources_changed"] as Array)[0]
	assert_int(args[0]).is_equal(20)  # round(20 * 1.0)


func test_grant_is_observable_synchronously_immediately_after_emit_returns() -> void:
	GEventBus.wave_started.emit(1, 6, 1.0)
	GEventBus.wave_completed.emit(1, 0, false)

	# No await / process-frame yield above -- proves the grant is not
	# deferred to a later frame, matching ADR-0001 Rule 1's synchronous-
	# dispatch default (same proof pattern as gold_track_scout_grant_test.gd).
	assert_int(_spy.count("resources_changed")).is_equal(1)
