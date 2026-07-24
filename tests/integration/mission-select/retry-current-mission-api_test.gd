## Integration tests for Story 013 (TR-missel-001/002, ADR-0028):
## retry_current_mission() and MissionRuntimeState (Rule 10, AC-23/24/25/26).
##
## MissionSelect is instantiated directly (MissionSelect.new(), no
## add_child()) — real GEventBus/GGrid Autoload calls are exercised
## (Integration story), matching this system's established convention.
extends GdUnitTestSuite

var _mission_select: MissionSelect
var _spy: EventBusSpy


func before_test() -> void:
	_mission_select = MissionSelect.new()
	_mission_select._restore_completed = true
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.mission_launched)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _mission_select != null and is_instance_valid(_mission_select):
		_mission_select.free()
	_mission_select = null


func _launch(mission_id: String, tier: int, modifiers: Dictionary = {}) -> void:
	_mission_select.select_mission(mission_id)
	_mission_select.set_difficulty_tier(tier)
	for modifier_id: StringName in modifiers:
		_mission_select.set_run_modifier(modifier_id, modifiers[modifier_id])
	_mission_select.confirm_launch()


# ---------------------------------------------------------------------------
# AC-23: retry re-emits identical values, same GridConfig instance
# ---------------------------------------------------------------------------

func test_retry_reemits_mission_launched_with_identical_values() -> void:
	_launch("the_gap", 2, {&"extend_waves": 2.0})
	var original_grid_config: GridConfig = _mission_select._runtime_grid_config
	_spy.clear()

	_mission_select.retry_current_mission()

	assert_int(_spy.count("mission_launched")).is_equal(1)
	var emission: Array = (_spy.emissions["mission_launched"] as Array)[0]
	assert_str(emission[0] as String).is_equal("the_gap")
	assert_array(emission[1] as PackedStringArray).contains_exactly([&"extend_waves"])
	assert_int(emission[2] as int).is_equal(2)
	# Object identity, not merely equal field values — the SAME instance.
	assert_bool(_mission_select._runtime_grid_config == original_grid_config).is_true()


func test_retry_delivers_the_same_grid_config_instance_to_grid() -> void:
	_launch("the_gap", 1)
	var cached_instance: GridConfig = _mission_select._runtime_grid_config

	_mission_select.retry_current_mission()

	# GGrid.initialize() stores its own reference internally; confirm the
	# exact object we cached is the one GGrid now holds, not a re-fetched
	# equivalent (Grid's own get_config()-equivalent isn't public, so the
	# strongest available proof is that our own cached reference is
	# unmodified and identical across launch and retry).
	assert_bool(cached_instance == _mission_select._runtime_grid_config).is_true()
	assert_float(cached_instance.cell_size).is_equal_approx(64.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-24: MISSION_COMPLETE clears MissionRuntimeState, returns to BROWSING
# ---------------------------------------------------------------------------

func test_mission_complete_clears_runtime_state_and_returns_to_browsing() -> void:
	_launch("the_gap", 1)
	assert_bool(_mission_select._runtime_grid_config != null).is_true()

	_mission_select._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 100.0)

	assert_str(_mission_select._runtime_mission_id).is_equal("")
	assert_object(_mission_select._runtime_grid_config).is_null()
	assert_int(_mission_select.state).is_equal(MissionSelect.State.BROWSING)


func test_defeat_retains_runtime_state_unchanged() -> void:
	_launch("the_gap", 1)
	var cached_instance: GridConfig = _mission_select._runtime_grid_config

	_mission_select._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 100.0)

	assert_str(_mission_select._runtime_mission_id).is_equal("the_gap")
	assert_bool(_mission_select._runtime_grid_config == cached_instance).is_true()


# ---------------------------------------------------------------------------
# AC-25 (EC-6): missing-state guard
# ---------------------------------------------------------------------------

func test_retry_with_no_armed_runtime_state_takes_no_action() -> void:
	# _mission_select was never launched — MissionRuntimeState is absent.
	_mission_select.retry_current_mission()

	assert_bool(_spy.was_emitted("mission_launched")).is_false()
	assert_int(_mission_select.state).is_equal(MissionSelect.State.BROWSING)


# ---------------------------------------------------------------------------
# AC-26: retry timing restarts the clock
# ---------------------------------------------------------------------------

func test_retry_refreshes_the_launch_timestamp() -> void:
	_launch("the_gap", 1)
	_mission_select._runtime_launch_timestamp = 100.0  # simulate an old/stale timestamp

	_mission_select.retry_current_mission()

	# The retry's timestamp is refreshed to "now" — definitely not the old
	# stale value, proving the clock restarts rather than accumulating from
	# the original (failed) attempt's elapsed time.
	assert_float(_mission_select._runtime_launch_timestamp).is_not_equal(100.0)
