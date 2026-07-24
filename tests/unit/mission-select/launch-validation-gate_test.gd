## Unit tests for Story 012 (TR-missel-001, ADR-0028): the Launch validation
## gate (Rule 8, AC-20/21/22).
##
## MissionSelect is instantiated directly (MissionSelect.new(), no
## add_child()) — matching this system's established test convention.
## _restore_completed is set directly as a test seam since _ready() (which
## would normally wire the sanctuary_state_restored subscription) never runs
## without add_child().
extends GdUnitTestSuite

var _mission_select: MissionSelect
var _spy: EventBusSpy


func before_test() -> void:
	_mission_select = MissionSelect.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.mission_launched)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _mission_select != null and is_instance_valid(_mission_select):
		_mission_select.free()
	_mission_select = null


# ---------------------------------------------------------------------------
# AC-20: no-selection block (BROWSING, no mission_id selected)
# ---------------------------------------------------------------------------

func test_confirm_launch_blocked_when_state_is_browsing() -> void:
	_mission_select._restore_completed = true
	# state defaults to BROWSING — no select_mission() call.
	assert_int(_mission_select.state).is_equal(MissionSelect.State.BROWSING)

	_mission_select.confirm_launch()

	assert_bool(_spy.was_emitted("mission_launched")).is_false()
	assert_int(_mission_select.state).is_equal(MissionSelect.State.BROWSING)


func test_can_launch_false_when_state_is_browsing() -> void:
	_mission_select._restore_completed = true
	assert_bool(_mission_select.can_launch()).is_false()


# ---------------------------------------------------------------------------
# AC-21: pre-restore defensive guard
# ---------------------------------------------------------------------------

func test_confirm_launch_blocked_when_restore_not_completed() -> void:
	_mission_select._restore_completed = false
	_mission_select.select_mission("the_gap")

	_mission_select.confirm_launch()

	assert_bool(_spy.was_emitted("mission_launched")).is_false()
	assert_int(_mission_select.state).is_equal(MissionSelect.State.CONFIGURING)


func test_completion_records_read_empty_before_restore() -> void:
	_mission_select._restore_completed = false
	var record: MissionCompletionRecord = _mission_select.get_completion_record("the_gap", 1)
	assert_bool(record.completed).is_false()
	assert_float(record.best_time_seconds).is_equal_approx(-1.0, 0.0001)


func test_confirm_launch_succeeds_once_restore_signaled() -> void:
	_mission_select._restore_completed = false
	_mission_select.select_mission("the_gap")
	_mission_select.confirm_launch()
	assert_bool(_spy.was_emitted("mission_launched")).is_false()

	_mission_select._on_sanctuary_state_restored(1)  # simulates the real subscription firing
	_mission_select.confirm_launch()

	assert_bool(_spy.was_emitted("mission_launched")).is_true()
	assert_int(_mission_select.state).is_equal(MissionSelect.State.LAUNCHED)


# ---------------------------------------------------------------------------
# AC-22: tier guarantee holds in practice
# ---------------------------------------------------------------------------

func test_can_launch_tier_check_always_passes_after_select_mission() -> void:
	_mission_select._restore_completed = true
	_mission_select.select_mission("the_gap")
	# Rule 3's default-to-recommended guarantees difficulty_tier is always
	# valid the moment CONFIGURING is entered — no code path leaves it unset.
	assert_bool(_mission_select.difficulty_tier >= 1 and _mission_select.difficulty_tier <= 3).is_true()
	assert_bool(_mission_select.can_launch()).is_true()


func test_can_launch_true_for_all_three_valid_tiers() -> void:
	_mission_select._restore_completed = true
	_mission_select.select_mission("the_gap")
	for tier: int in [1, 2, 3]:
		_mission_select.set_difficulty_tier(tier)
		assert_bool(_mission_select.can_launch()).is_true()


# ---------------------------------------------------------------------------
# can_launch()'s unresolvable-mission_id guard (code review finding —
# keeps confirm_launch() symmetric with retry_current_mission()'s EC-6 guard)
# ---------------------------------------------------------------------------

func test_can_launch_false_when_selected_mission_id_no_longer_resolves() -> void:
	_mission_select._restore_completed = true
	_mission_select.select_mission("the_gap")
	_mission_select._current_mission_id = "unknown_mission_never_shipped"  # simulates a vanished mission
	assert_bool(_mission_select.can_launch()).is_false()
