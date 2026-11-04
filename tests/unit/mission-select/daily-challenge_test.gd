## Daily Challenge (design/quick-specs/daily-challenge-2026-11-04.md): one
## seeded run per UTC day; streak and first-clear shards.
extends GdUnitTestSuite

var _mission_select: MissionSelect


func before_test() -> void:
	GInventory.reset_to_defaults()
	_mission_select = MissionSelect.new()
	_mission_select._restore_completed = true


func after_test() -> void:
	if _mission_select != null and is_instance_valid(_mission_select):
		_mission_select.free()
	_mission_select = null
	GInventory.reset_to_defaults()


func test_daily_date_key_and_previous_day() -> void:
	assert_str(DailyChallenge.date_key(0.0)).is_equal("1970-01-01")
	assert_str(DailyChallenge.previous_date_key("2026-03-01")).is_equal("2026-02-28")
	assert_str(DailyChallenge.previous_date_key("2027-01-01")).is_equal("2026-12-31")


func test_daily_roll_is_deterministic_and_order_independent() -> void:
	# Arrange
	var ids: Array[String] = ["the_gap", "the_foothills", "the_narrows"]
	var reversed: Array[String] = ["the_narrows", "the_foothills", "the_gap"]
	# Act
	var a: Dictionary = DailyChallenge.roll("2026-11-04", ids)
	var b: Dictionary = DailyChallenge.roll("2026-11-04", reversed)
	# Assert
	assert_str(a["mission_id"]).is_equal(b["mission_id"])
	assert_dict(a["modifiers"]).is_equal(b["modifiers"])


func test_daily_roll_always_turns_on_a_modifier() -> void:
	var ids: Array[String] = ["the_gap"]
	for day: int in 60:
		var key: String = DailyChallenge.date_key(1_760_000_000.0 + 86400.0 * day)
		var modifiers: Dictionary = DailyChallenge.roll(key, ids)["modifiers"]
		var any_on: bool = false
		for value: float in modifiers.values():
			any_on = any_on or value != 0.0
		assert_bool(any_on).override_failure_message("no modifier on " + key).is_true()


func test_daily_map_layout_is_the_same_all_day() -> void:
	var first: GridConfig = MapGenerator.generate(16, 12, 64.0, DailyChallenge.rng_for("2026-11-04"))
	var second: GridConfig = MapGenerator.generate(16, 12, 64.0, DailyChallenge.rng_for("2026-11-04"))
	var other_day: GridConfig = MapGenerator.generate(16, 12, 64.0, DailyChallenge.rng_for("2026-11-05"))
	assert_dict(first.cells).is_equal(second.cells)
	assert_bool(first.cells == other_day.cells).is_false()


func test_daily_streak_and_shards() -> void:
	assert_int(DailyChallenge.next_streak("2026-11-04", "2026-11-03", 4)).is_equal(5)
	assert_int(DailyChallenge.next_streak("2026-11-04", "2026-11-01", 4)).is_equal(1)
	assert_int(DailyChallenge.next_streak("2026-11-04", "2026-11-04", 4)).is_equal(4)
	assert_int(DailyChallenge.clear_shards(1)).is_equal(5)
	assert_int(DailyChallenge.clear_shards(3)).is_equal(7)
	assert_int(DailyChallenge.clear_shards(30)).is_equal(12)


func test_daily_select_uses_the_rolled_setup_on_an_unlocked_map() -> void:
	# Arrange: a fresh save has only the_gap open.
	var now: float = 1_762_214_400.0  # 2025-11-04 UTC
	var setup: Dictionary = _mission_select.get_daily_setup(now)
	# Act
	var ok: bool = _mission_select.select_daily(now)
	# Assert
	assert_bool(ok).is_true()
	assert_str(setup["mission_id"]).is_equal("the_gap")
	assert_bool(_mission_select.is_daily_selected()).is_true()
	assert_int(_mission_select.state).is_equal(MissionSelect.State.CONFIGURING)
	assert_int(_mission_select.difficulty_tier).is_equal(1)
	for modifier_id: StringName in (setup["modifiers"] as Dictionary):
		assert_float(_mission_select.get_run_modifier_value(modifier_id)).is_equal(setup["modifiers"][modifier_id])
	assert_bool(_mission_select.can_launch()).is_true()


func test_daily_changing_the_setup_makes_it_a_normal_run() -> void:
	_mission_select.select_daily(1_762_214_400.0)
	_mission_select.set_run_modifier(&"extend_waves", 0.0)
	assert_bool(_mission_select.is_daily_selected()).is_false()


func test_daily_first_clear_advances_streak_and_grants_shards_once() -> void:
	# Arrange: yesterday cleared with a 2-day streak.
	_mission_select._daily_last_cleared = "2026-11-03"
	_mission_select._daily_streak = 2
	_mission_select._runtime_daily_date = "2026-11-04"
	# Act
	_mission_select._record_daily_clear()
	_mission_select._record_daily_clear()  # a repeat clear the same day
	# Assert: streak 3, 5 + 2 shards, delivered to the bag once.
	assert_int(_mission_select.get_daily_streak()).is_equal(3)
	assert_bool(_mission_select.has_cleared_daily("2026-11-04")).is_true()
	assert_int(GInventory.count_by_material_id(AscensionRewards.SHARD_ITEM_ID)).is_equal(7)


func test_daily_record_round_trips_through_save_data() -> void:
	_mission_select._daily_last_cleared = "2026-11-04"
	_mission_select._daily_streak = 6
	var data: Dictionary = _mission_select.get_save_data()
	var restored := MissionSelect.new()
	assert_bool(restored.restore_save_data(data)).is_true()
	assert_int(restored.get_daily_streak()).is_equal(6)
	assert_str(restored.get_daily_last_cleared()).is_equal("2026-11-04")
	var legacy: Dictionary = {"completion_ledger": {}}
	assert_bool(restored.restore_save_data(legacy)).is_true()
	assert_int(restored.get_daily_streak()).is_equal(0)
	restored.free()
