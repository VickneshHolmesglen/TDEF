## Campaign unlocks + Ascension (2026-11-03): maps open in
## MissionEntry.campaign_order, tiers open one at a time, tiers above Brutal
## are Ascension ranks; and a won mission is recorded in the completion
## ledger (record_completion() had no production caller before).
##
## Real catalogue order: the_gap 1, the_foothills 2, the_narrows 3.
## MissionSelect.new() without add_child(), as the rest of this directory.
extends GdUnitTestSuite

var _mission_select: MissionSelect


func before_test() -> void:
	_mission_select = MissionSelect.new()
	_mission_select._restore_completed = true


func after_test() -> void:
	if _mission_select != null and is_instance_valid(_mission_select):
		_mission_select.free()
	_mission_select = null


func test_campaign_fresh_save_opens_only_the_first_map_on_normal() -> void:
	assert_bool(_mission_select.is_mission_unlocked("the_gap")).is_true()
	assert_int(_mission_select.get_highest_unlocked_tier("the_gap")).is_equal(1)
	assert_bool(_mission_select.is_mission_unlocked("the_foothills")).is_false()
	assert_str(_mission_select.get_unlock_prerequisite("the_foothills")).is_equal("the_gap")
	assert_int(_mission_select.get_highest_unlocked_tier("the_foothills")).is_equal(0)


func test_campaign_clearing_a_map_opens_the_next_map_and_its_own_next_tier() -> void:
	_mission_select.record_completion("the_gap", 1, 300.0)

	assert_bool(_mission_select.is_mission_unlocked("the_foothills")).is_true()
	assert_int(_mission_select.get_highest_unlocked_tier("the_gap")).is_equal(2)
	assert_int(_mission_select.get_highest_unlocked_tier("the_foothills")).is_equal(1)
	assert_bool(_mission_select.is_mission_unlocked("the_narrows")).is_false()


func test_campaign_can_launch_rejects_a_locked_tier_and_a_locked_map() -> void:
	_mission_select.select_mission("the_gap")
	_mission_select.set_difficulty_tier(2)
	assert_bool(_mission_select.can_launch()).is_false()

	_mission_select.select_mission("the_foothills")
	_mission_select.set_difficulty_tier(1)
	assert_bool(_mission_select.can_launch()).is_false()

	_mission_select.record_completion("the_gap", 1, 300.0)
	assert_bool(_mission_select.can_launch()).is_true()


func test_campaign_select_mission_never_defaults_onto_a_locked_tier() -> void:
	# the_narrows recommends Hard (2); with only Normal open it must pick Normal.
	_mission_select.record_completion("the_gap", 1, 300.0)
	_mission_select.record_completion("the_foothills", 1, 300.0)

	_mission_select.select_mission("the_narrows")

	assert_int(_mission_select.difficulty_tier).is_equal(1)


func test_campaign_clearing_brutal_opens_ascension_up_to_the_cap() -> void:
	_mission_select.record_completion("the_gap", DifficultyRewards.BRUTAL_TIER, 300.0)
	assert_int(_mission_select.get_highest_unlocked_tier("the_gap")).is_equal(DifficultyRewards.BRUTAL_TIER + 1)

	_mission_select.record_completion("the_gap", DifficultyRewards.MAX_TIER, 300.0)
	assert_int(_mission_select.get_highest_unlocked_tier("the_gap")).is_equal(DifficultyRewards.MAX_TIER)


func test_campaign_locks_disabled_opens_every_map_and_tier() -> void:
	_mission_select.campaign_locks_enabled = false

	assert_bool(_mission_select.is_mission_unlocked("the_narrows")).is_true()
	assert_int(_mission_select.get_highest_unlocked_tier("the_narrows")).is_equal(DifficultyRewards.MAX_TIER)


## Regression: a won mission was never recorded, so nothing could unlock and
## every card read "Not yet cleared".
func test_campaign_mission_complete_records_the_launched_mission_and_tier() -> void:
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.mission_completion_recorded)
	_mission_select.select_mission("the_gap")
	_mission_select.set_difficulty_tier(1)
	_mission_select.confirm_launch()

	_mission_select._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)

	assert_bool(_mission_select.get_completion_record("the_gap", 1).completed).is_true()
	assert_bool(_mission_select.is_mission_unlocked("the_foothills")).is_true()
	assert_int(spy.count("mission_completion_recorded")).is_equal(1)
	spy.disconnect_all()


func test_campaign_defeat_records_nothing() -> void:
	_mission_select.select_mission("the_gap")
	_mission_select.confirm_launch()

	_mission_select._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)

	assert_int(_mission_select.get_highest_completed_tier("the_gap")).is_equal(0)


func test_difficulty_rewards_ascension_scales_hp_faster_than_rewards() -> void:
	assert_float(DifficultyRewards.multiplier_for_tier(3)).is_equal_approx(1.7, 0.0001)
	assert_float(DifficultyRewards.ascension_hp_multiplier(3)).is_equal_approx(1.0, 0.0001)
	assert_float(DifficultyRewards.multiplier_for_tier(5)).is_equal_approx(1.7 * 1.12 * 1.12, 0.0001)
	assert_float(DifficultyRewards.ascension_hp_multiplier(5)).is_equal_approx(1.15 * 1.15, 0.0001)
	assert_float(DifficultyRewards.multiplier_for_tier(99)).is_equal_approx(DifficultyRewards.multiplier_for_tier(DifficultyRewards.MAX_TIER), 0.0001)


## Dev unlock-all switch: only a debug build with the setting ticked opens
## everything; a release export ignores the setting.
func test_campaign_dev_unlock_requires_debug_build_and_setting() -> void:
	assert_bool(MissionSelect.dev_unlock_requested(true, true)).is_true()
	assert_bool(MissionSelect.dev_unlock_requested(true, false)).is_false()
	assert_bool(MissionSelect.dev_unlock_requested(false, true)).is_false()


func test_campaign_dev_unlock_setting_ships_off() -> void:
	assert_bool(ProjectSettings.get_setting(MissionSelect.DEV_UNLOCK_SETTING, true)).is_false()
