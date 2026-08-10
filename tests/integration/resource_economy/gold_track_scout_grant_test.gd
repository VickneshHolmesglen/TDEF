## Integration tests for the Scout Phase starting gold grant, Epic 03 Story 013,
## ADR-0017 (emission side) / ADR-0018 (balance side is covered separately by
## tests/integration/core/mission_economy_test.gd).
##
## Covers AC-09 (gold deltas fire exclusively as resources_changed — never
## materials_earned/materials_spent) and AC-10 (mission_phase_changed(new_phase=
## "SCOUT") triggers resources_changed(50, "mission_start_grant") exactly once,
## synchronously — see the "before the phase timer starts" note below).
## Value lowered from 150 to 50, 2026-08-11 — see ResourceEconomy.
## SCOUT_STARTING_GOLD's own doc comment for the recalibration rationale.
##
## AC-10 wording note ("before the phase timer starts"): ADR-0001 Rule 1 makes
## EventBus dispatch synchronous by default, and WaveManager's own
## mission_phase_changed.emit() call (wave_manager.gd, _transition_to()) happens
## strictly before its _enter_phase()->_enter_scout()->_scout_timer.start() call
## in the same function body. There is no timer-observable ordering to assert
## directly from this test's vantage point (ResourceEconomy never touches
## WaveManager's timer), so what IS testable and asserted here instead is the
## synchronous-dispatch guarantee itself: the grant is observably complete
## (recorded by the spy) by the time GEventBus.mission_phase_changed.emit(...)
## returns control to the caller — i.e. it cannot be deferred to a later frame
## or queued behind anything. Given WaveManager's own emit-then-start-timer
## ordering (unchanged by this story), that synchronous completion is what
## guarantees the grant precedes the timer start in real gameplay.
##
## Follows despawn_drop_suppression_test.gd's established convention:
## ResourceEconomy tests use add_child()-then-real-signal dispatch, observed via
## tests/helpers/event_bus_spy.gd's EventBusSpy. No drop-table seeding is needed
## here — the Scout grant path does not touch GameDataRegistry at all.
extends GdUnitTestSuite

var _re: ResourceEconomy
var _spy: EventBusSpy


func before_test() -> void:
	_re = ResourceEconomy.new()
	add_child(_re)  # triggers _ready() — GEventBus.mission_phase_changed subscription is live
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
# AC-10: SCOUT entry grants exactly once, with the correct payload.
# ---------------------------------------------------------------------------

func test_mission_phase_changed_to_scout_emits_resources_changed_50_mission_start_grant() -> void:
	GEventBus.mission_phase_changed.emit("IDLE", "SCOUT", 0.0)

	assert_int(_spy.count("resources_changed")).is_equal(1)
	var args: Array = (_spy.emissions["resources_changed"] as Array)[0]
	assert_int(args[0]).is_equal(ResourceEconomy.SCOUT_STARTING_GOLD)
	assert_str(String(args[1])).is_equal("mission_start_grant")


## AC-10: the grant is observable (already recorded by the spy) synchronously,
## immediately after the emit() call returns — proving it is not deferred to a
## later frame or queued, per ADR-0001 Rule 1's synchronous-dispatch default.
## See the file-level doc comment above for why this is the testable proxy for
## "before the phase timer starts."
func test_scout_grant_is_observable_synchronously_immediately_after_emit_returns() -> void:
	GEventBus.mission_phase_changed.emit("IDLE", "SCOUT", 0.0)

	# No await / process-frame yield anywhere above this line — if the grant
	# were deferred (call_deferred or a queued signal), this assertion would
	# see count == 0 here and only pass after a frame boundary.
	assert_int(_spy.count("resources_changed")).is_equal(1)


## AC-10 edge case (QA Test Cases): a non-SCOUT transition must not grant.
func test_mission_phase_changed_to_non_scout_phase_does_not_grant() -> void:
	GEventBus.mission_phase_changed.emit("SCOUT", "PRE_WAVE", 0.0)

	assert_int(_spy.count("resources_changed")).is_equal(0)


## AC-10 edge case (QA Test Cases, flagged as ambiguous — see this suite's
## file-level doc comment and the requesting agent's report): a SECOND SCOUT
## transition delivered to the SAME ResourceEconomy node instance DOES grant
## again. This is deliberate, not a bug: AC-10's own wording is "fires exactly
## once" GIVEN one mission_phase_changed(new_phase="SCOUT") dispatch — i.e.
## once per transition, not once per node lifetime. The story's Implementation
## Notes resolve the realistic double-grant concern (mission restart after
## DEFEAT) structurally: ADR-0017 makes ResourceEconomy a fresh node instance
## per mission, so that scenario never reaches this code path with a SECOND
## SCOUT dispatch on the SAME instance in the first place. This test proves
## ResourceEconomy adds no artificial internal dedup on top of that — if a
## future caller ever DID deliver two real SCOUT transitions to one instance,
## the player would correctly receive two grants, not silently lose the second.
func test_second_scout_transition_on_same_node_instance_grants_again() -> void:
	GEventBus.mission_phase_changed.emit("IDLE", "SCOUT", 0.0)
	GEventBus.mission_phase_changed.emit("PRE_WAVE", "SCOUT", 1.0)

	assert_int(_spy.count("resources_changed")).is_equal(2)


# ---------------------------------------------------------------------------
# AC-09: exclusivity — this delta fires ONLY as resources_changed, never
# materials_earned/materials_spent.
# ---------------------------------------------------------------------------

func test_scout_grant_fires_only_resources_changed_never_materials_signals() -> void:
	GEventBus.mission_phase_changed.emit("IDLE", "SCOUT", 0.0)

	assert_int(_spy.count("resources_changed")).is_equal(1)
	assert_int(_spy.count("materials_earned")).is_equal(0)
	assert_int(_spy.count("materials_spent")).is_equal(0)
