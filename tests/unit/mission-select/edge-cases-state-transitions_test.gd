## Unit tests for Story 014 (TR-missel-003, ADR-0028): edge cases (EC-1/EC-5)
## and state transitions (AC-29/AC-30).
##
## MissionSelect is instantiated directly (MissionSelect.new(), no
## add_child()) so _ready() never fires — GSavePersistence.register() is
## never called, avoiding pollution of the real Autoload's registered-systems
## list. get_save_data()/restore_save_data() are called directly, matching
## Tarot's established persistence-test convention.
extends GdUnitTestSuite

var _mission_select: MissionSelect


func before_test() -> void:
	_mission_select = MissionSelect.new()


func after_test() -> void:
	if _mission_select != null and is_instance_valid(_mission_select):
		_mission_select.free()
	_mission_select = null


func _launch(mission_id: String) -> void:
	_mission_select._restore_completed = true
	_mission_select.select_mission(mission_id)
	_mission_select.confirm_launch()


func test_restore_order_is_11() -> void:
	assert_int(MissionSelect.RESTORE_ORDER).is_equal(11)


# ---------------------------------------------------------------------------
# AC-27 (EC-1): no-data-yet display, already structural, confirmed here
# ---------------------------------------------------------------------------

func test_ec1_mission_with_no_records_reads_default_for_every_tier() -> void:
	for tier: int in [1, 2, 3]:
		var record: MissionCompletionRecord = _mission_select.get_completion_record("never_attempted", tier)
		assert_bool(record.completed).is_false()
		assert_float(record.best_time_seconds).is_equal_approx(-1.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-28 (EC-5): orphaned completion record retained, warned, load never blocks
# ---------------------------------------------------------------------------

func test_ec5_orphaned_mission_id_is_retained_and_load_does_not_fail() -> void:
	var payload: Dictionary = {
		"completion_ledger": {
			"unknown_mission_never_shipped": {
				"1": {"completed": true, "best_time_seconds": 500.0},
			},
		},
	}

	var ok: bool = _mission_select.restore_save_data(payload)

	assert_bool(ok).is_true()  # load never blocks or fails on an orphan
	var record: MissionCompletionRecord = _mission_select.get_completion_record("unknown_mission_never_shipped", 1)
	assert_bool(record.completed).is_true()
	assert_float(record.best_time_seconds).is_equal_approx(500.0, 0.0001)


func test_get_save_data_round_trips_completion_ledger() -> void:
	_mission_select.record_completion("the_gap", 1, 900.0)
	_mission_select.record_completion("the_narrows", 2, 300.0)

	var saved: Dictionary = _mission_select.get_save_data()
	assert_bool(saved.has("completion_ledger")).is_true()
	# MissionRuntimeState is never persisted (Rule 10).
	assert_bool(saved.has("runtime_mission_id")).is_false()
	assert_bool(saved.has("runtime_grid_config")).is_false()

	var restored: MissionSelect = MissionSelect.new()
	var ok: bool = restored.restore_save_data(saved)
	assert_bool(ok).is_true()

	var record: MissionCompletionRecord = restored.get_completion_record("the_gap", 1)
	assert_bool(record.completed).is_true()
	assert_float(record.best_time_seconds).is_equal_approx(900.0, 0.0001)
	restored.free()


func test_reset_to_defaults_clears_completion_ledger() -> void:
	_mission_select.record_completion("the_gap", 1, 900.0)
	_mission_select.reset_to_defaults()
	var record: MissionCompletionRecord = _mission_select.get_completion_record("the_gap", 1)
	assert_bool(record.completed).is_false()
	assert_float(record.best_time_seconds).is_equal_approx(-1.0, 0.0001)


func test_restore_save_data_rejects_malformed_payload() -> void:
	assert_bool(_mission_select.restore_save_data({})).is_false()
	assert_bool(_mission_select.restore_save_data({"completion_ledger": "not_a_dict"})).is_false()


func test_restore_save_data_rejects_wrong_typed_leaf_values() -> void:
	# "completed" as a String instead of bool must be rejected, not coerced.
	var bad_completed: Dictionary = {
		"completion_ledger": {"the_gap": {"1": {"completed": "yes", "best_time_seconds": 500.0}}},
	}
	assert_bool(_mission_select.restore_save_data(bad_completed)).is_false()

	# "best_time_seconds" as a String instead of float must be rejected, not coerced.
	var bad_time: Dictionary = {
		"completion_ledger": {"the_gap": {"1": {"completed": true, "best_time_seconds": "fast"}}},
	}
	assert_bool(_mission_select.restore_save_data(bad_time)).is_false()


func test_restore_save_data_rejects_non_numeric_tier_key() -> void:
	var payload: Dictionary = {
		"completion_ledger": {"the_gap": {"abc": {"completed": true, "best_time_seconds": 500.0}}},
	}
	assert_bool(_mission_select.restore_save_data(payload)).is_false()


# ---------------------------------------------------------------------------
# AC-29: only documented transitions reachable, full sequence
# ---------------------------------------------------------------------------

func test_full_documented_state_sequence() -> void:
	# BROWSING (initial)
	assert_int(_mission_select.state).is_equal(MissionSelect.State.BROWSING)

	# BROWSING -> CONFIGURING (select_mission)
	_mission_select._restore_completed = true
	_mission_select.select_mission("the_gap")
	assert_int(_mission_select.state).is_equal(MissionSelect.State.CONFIGURING)

	# CONFIGURING -> LAUNCHED (confirm_launch)
	_mission_select.confirm_launch()
	assert_int(_mission_select.state).is_equal(MissionSelect.State.LAUNCHED)

	# LAUNCHED -> DORMANT_RETRY_ARMED (DEFEAT)
	_mission_select._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 10.0)
	assert_int(_mission_select.state).is_equal(MissionSelect.State.DORMANT_RETRY_ARMED)

	# DORMANT_RETRY_ARMED -> LAUNCHED (retry)
	_mission_select.retry_current_mission()
	assert_int(_mission_select.state).is_equal(MissionSelect.State.LAUNCHED)

	# LAUNCHED -> BROWSING (MISSION_COMPLETE)
	_mission_select._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 20.0)
	assert_int(_mission_select.state).is_equal(MissionSelect.State.BROWSING)


func test_browsing_to_launched_directly_is_unreachable() -> void:
	# No select_mission() call — can_launch() must reject from BROWSING.
	_mission_select._restore_completed = true
	assert_bool(_mission_select.can_launch()).is_false()
	_mission_select.confirm_launch()
	assert_int(_mission_select.state).is_equal(MissionSelect.State.BROWSING)


# ---------------------------------------------------------------------------
# AC-30: no reaction to irrelevant phases
# ---------------------------------------------------------------------------

func test_irrelevant_phases_do_not_change_state_while_launched() -> void:
	_launch("the_gap")
	assert_int(_mission_select.state).is_equal(MissionSelect.State.LAUNCHED)

	for phase: String in ["SCOUT", "PRE_WAVE", "WAVE_ACTIVE", "INTERMISSION"]:
		_mission_select._on_mission_phase_changed("", phase, 0.0)
		assert_int(_mission_select.state).is_equal(MissionSelect.State.LAUNCHED)


func test_irrelevant_phases_do_not_clear_runtime_state() -> void:
	_launch("the_gap")
	var cached_instance: GridConfig = _mission_select._runtime_grid_config

	_mission_select._on_mission_phase_changed("", "SCOUT", 0.0)

	assert_bool(_mission_select._runtime_grid_config == cached_instance).is_true()
	assert_str(_mission_select._runtime_mission_id).is_equal("the_gap")
