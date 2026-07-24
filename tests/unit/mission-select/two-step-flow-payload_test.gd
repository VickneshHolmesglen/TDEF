## Unit tests for Story 011 (TR-missel-001, ADR-0028): the two-step
## select->configure->launch flow (Rule 6, AC-15/16/17) and mission_launched's
## payload assembly (Rule 7, AC-18/19).
##
## MissionSelect is instantiated directly (MissionSelect.new(), no
## add_child()) — matching this system's established test convention.
extends GdUnitTestSuite

var _mission_select: MissionSelect
var _spy: EventBusSpy


func before_test() -> void:
	_mission_select = MissionSelect.new()
	_mission_select._restore_completed = true  # Story 012's gate — not under test here
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.mission_selected)
	_spy.watch(GEventBus.mission_launched)
	_spy.watch(GEventBus.run_modifier_selected)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _mission_select != null and is_instance_valid(_mission_select):
		_mission_select.free()
	_mission_select = null


# ---------------------------------------------------------------------------
# AC-15: selection transitions without commitment
# ---------------------------------------------------------------------------

func test_select_mission_emits_mission_selected_and_enters_configuring() -> void:
	_mission_select.select_mission("the_gap")
	assert_int(_spy.count("mission_selected")).is_equal(1)
	var emission: Array = (_spy.emissions["mission_selected"] as Array)[0]
	assert_str(emission[0] as String).is_equal("the_gap")
	assert_int(_mission_select.state).is_equal(MissionSelect.State.CONFIGURING)
	assert_bool(_spy.was_emitted("mission_launched")).is_false()


# ---------------------------------------------------------------------------
# AC-16: direct re-selection resets state
# ---------------------------------------------------------------------------

func test_select_mission_from_configuring_resets_modifiers_and_tier() -> void:
	_mission_select.select_mission("the_gap")  # recommended_difficulty_tier = 1
	_mission_select.set_difficulty_tier(3)
	_mission_select.set_run_modifier(&"extend_waves", 2.0)
	_spy.clear()

	_mission_select.select_mission("the_narrows")  # recommended_difficulty_tier = 2

	assert_int(_spy.count("mission_selected")).is_equal(1)
	var emission: Array = (_spy.emissions["mission_selected"] as Array)[0]
	assert_str(emission[0] as String).is_equal("the_narrows")
	assert_int(_mission_select.difficulty_tier).is_equal(2)
	assert_int(_mission_select.state).is_equal(MissionSelect.State.CONFIGURING)

	# Modifiers reset to 0.0 defaults — confirm via payload assembly, the
	# only externally observable proof of the internal reset.
	_mission_select.confirm_launch()
	var launch_emission: Array = (_spy.emissions["mission_launched"] as Array)[0]
	assert_array(launch_emission[1] as PackedStringArray).is_empty()


# ---------------------------------------------------------------------------
# AC-17: silent back-out
# ---------------------------------------------------------------------------

func test_back_out_to_browsing_emits_no_event() -> void:
	_mission_select.select_mission("the_gap")
	_spy.clear()

	_mission_select.back_out_to_browsing()

	assert_int(_mission_select.state).is_equal(MissionSelect.State.BROWSING)
	assert_bool(_spy.was_emitted("mission_selected")).is_false()
	assert_bool(_spy.was_emitted("mission_launched")).is_false()
	assert_bool(_spy.was_emitted("run_modifier_selected")).is_false()


# ---------------------------------------------------------------------------
# AC-18: non-zero-only payload inclusion
# ---------------------------------------------------------------------------

func test_confirm_launch_omits_still_zero_modifiers() -> void:
	_mission_select.select_mission("the_gap")
	_mission_select.set_run_modifier(&"extend_waves", 1.0)
	_mission_select.set_run_modifier(&"difficulty_growth_boost", 0.0)  # left at default

	_mission_select.confirm_launch()

	var emission: Array = (_spy.emissions["mission_launched"] as Array)[0]
	var modifiers: PackedStringArray = emission[1] as PackedStringArray
	assert_array(modifiers).contains_exactly([&"extend_waves"])


# ---------------------------------------------------------------------------
# AC-19: empty array when all defaults
# ---------------------------------------------------------------------------

func test_confirm_launch_emits_empty_array_when_all_modifiers_default() -> void:
	_mission_select.select_mission("the_gap")

	_mission_select.confirm_launch()

	var emission: Array = (_spy.emissions["mission_launched"] as Array)[0]
	var modifiers: PackedStringArray = emission[1] as PackedStringArray
	assert_array(modifiers).is_not_null()
	assert_array(modifiers).is_empty()
	assert_int(_mission_select.state).is_equal(MissionSelect.State.LAUNCHED)


# ---------------------------------------------------------------------------
# mission_launched payload — mission_id/difficulty_tier carried correctly
# ---------------------------------------------------------------------------

func test_confirm_launch_emits_correct_mission_id_and_difficulty_tier() -> void:
	_mission_select.select_mission("the_narrows")
	_mission_select.set_difficulty_tier(3)

	_mission_select.confirm_launch()

	var emission: Array = (_spy.emissions["mission_launched"] as Array)[0]
	assert_str(emission[0] as String).is_equal("the_narrows")
	assert_int(emission[2] as int).is_equal(3)
