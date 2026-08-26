## Integration test for the DEFEAT-save-then-immediate-retry checkpoint
## interaction flagged as genuinely untested in mission-select.md/
## save-persistence.md's Rule 9/10 (found stale-blocker-free but this one
## real gap during the 2026-08-27 `/design-review` re-review sweep — see
## systems-index.md's Mission Select row).
##
## **Real implementation finding, made while first writing this test
## (2026-08-27)**: `save-persistence.md` Rule 9 describes a dedicated
## "DEFEAT-triggered save, deferred exactly 1 frame" mechanism, gated on
## `mission_phase_changed` reaching `DEFEAT`. At the time, `save_persistence.gd`
## had no `mission_phase_changed` subscription at all — Rule 9's mechanism
## did not exist in shipped code, logged as `TD-save-004`
## (`docs/tech-debt-register.md`).
##
## **TD-save-004 fixed same day**: `save_persistence.gd` now subscribes to
## `mission_phase_changed` and, on `DEFEAT`, calls
## `save_slot.call_deferred(_active_slot)` — same one-frame-defer idiom as
## `sanctuary_state_restored` elsewhere in that file, letting any same-frame
## EventBus cascade (e.g. Tower's `tower_destroyed` ->
## `tower_component_returned` -> Inventory's `item_added`) finish before
## `get_save_data()` is called on any registered system. This suite now
## covers BOTH real save paths near a DEFEAT+retry sequence: the new
## deferred `save_slot()` write triggered by DEFEAT itself, and the
## pre-existing, already-shipped `mission_launched` -> `save_checkpoint()`
## write triggered by a subsequent `retry_current_mission()` call.
##
## Uses the real `GSavePersistence`/`GEventBus` Autoloads (matching
## retry-current-mission-api_test.gd's own established convention) —
## MissionSelect is instantiated directly (no add_child()) so its own
## _ready()/EventBus subscriptions never run; retry is driven through its
## public API directly, but DEFEAT is emitted on the real `GEventBus` (same
## pattern as `tests/integration/audio/pause-behavior_test.gd`) so
## `GSavePersistence`'s real handler actually fires — calling
## `_mission_select._on_mission_phase_changed()` directly, as sibling tests
## in this directory do, would only flip MissionSelect's own local state and
## never reach SavePersistence at all. Slot 96 avoids colliding with
## 97/98/99, already claimed by save_persistence_ec3_ec5_test.gd,
## save_persistence_write_test.gd, and main_menu_test.gd respectively.
extends GdUnitTestSuite

const TEST_SLOT: int = 96
const TEST_DAT: String = "user://saves/save_slot_96.dat"
const TEST_CHECKPOINT: String = "user://saves/save_slot_96_checkpoint.dat"

var _mission_select: MissionSelect
var _original_active_slot: int


class _TrackingSystem extends RefCounted:
	var payload_value: int = 0
	func get_save_key() -> String: return "checkpoint_race_tracking_system"
	func get_save_data() -> Dictionary: return {"value": payload_value}
	func restore_save_data(data: Dictionary) -> bool:
		payload_value = data.get("value", -1)
		return true
	func reset_to_defaults() -> void: payload_value = 0


func before_test() -> void:
	_original_active_slot = GSavePersistence._active_slot
	GSavePersistence.set_active_slot(TEST_SLOT)
	_mission_select = MissionSelect.new()
	_mission_select._restore_completed = true


func after_test() -> void:
	GSavePersistence.set_active_slot(_original_active_slot)
	for path: String in [TEST_DAT, TEST_CHECKPOINT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if _mission_select != null and is_instance_valid(_mission_select):
		_mission_select.free()
	_mission_select = null


func _launch(mission_id: String, tier: int) -> void:
	_mission_select.select_mission(mission_id)
	_mission_select.set_difficulty_tier(tier)
	_mission_select.confirm_launch()


## Simulates a real DEFEAT phase transition. Two calls, not one: our
## isolated `_mission_select` is a bare `MissionSelect.new()` (no
## `add_child()`, matching this directory's own convention), so it was never
## connected to the real `GEventBus.mission_phase_changed` via its own
## `_ready()` — the direct call updates ITS local state (mirrors what every
## sibling test in this directory already does), while the real emit is what
## reaches `GSavePersistence`, the actual live Autoload under test here. In
## production both reactions come from the same single emit, since
## MissionSelect there IS the real, `_ready()`-connected Autoload.
func _emit_defeat() -> void:
	_mission_select._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 100.0)
	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "DEFEAT", 100.0)


# ---------------------------------------------------------------------------
# TD-save-004 regression: DEFEAT now defers a real full save_slot() write —
# not immediately (still correctly deferred, per Rule 9), but it does land
# after one frame, unlike before the fix (where nothing ever wrote at all).
# ---------------------------------------------------------------------------

func test_defeat_does_not_write_synchronously_but_does_write_after_one_frame() -> void:
	_launch("the_gap", 1)
	assert_bool(FileAccess.file_exists(TEST_DAT)).is_false()

	_emit_defeat()

	# Still deferred immediately after the emit returns — Rule 9's "wait for
	# this frame's other synchronous handlers to finish" guarantee would be
	# violated by an immediate write.
	assert_bool(FileAccess.file_exists(TEST_DAT)).is_false()

	await get_tree().process_frame

	assert_bool(FileAccess.file_exists(TEST_DAT)).is_true()


func test_defeat_deferred_save_captures_state_current_at_defeat_time() -> void:
	var tracker := _TrackingSystem.new()
	GSavePersistence.register(tracker, 9000)  # deliberately far outside the real 1-36 range in use
	tracker.payload_value = 7

	_launch("the_gap", 1)
	_emit_defeat()
	await get_tree().process_frame

	var result: SavePersistence.LoadResult = GSavePersistence.load_slot(TEST_SLOT)
	await get_tree().process_frame

	assert_that(result).is_equal(SavePersistence.LoadResult.SUCCESS)
	assert_int(tracker.payload_value).is_equal(7)

	GSavePersistence.unregister(tracker)


# ---------------------------------------------------------------------------
# DEFEAT's deferred full save never touches the checkpoint file — the two
# writes remain on separate paths (save_slot_N.dat vs. save_slot_N_checkpoint.dat).
# ---------------------------------------------------------------------------

func test_defeat_transition_does_not_rewrite_the_checkpoint() -> void:
	_launch("the_gap", 1)
	assert_bool(FileAccess.file_exists(TEST_CHECKPOINT)).is_true()
	var mtime_after_launch: int = FileAccess.get_modified_time(TEST_CHECKPOINT)

	_emit_defeat()
	await get_tree().process_frame

	assert_int(FileAccess.get_modified_time(TEST_CHECKPOINT)).is_equal(mtime_after_launch)
	assert_int(_mission_select.state).is_equal(MissionSelect.State.DORMANT_RETRY_ARMED)


# ---------------------------------------------------------------------------
# Retry immediately after DEFEAT correctly re-triggers a checkpoint write —
# synchronously, no frame wait required, no error — regardless of whether
# DEFEAT's own deferred save_slot() write has landed yet.
# ---------------------------------------------------------------------------

func test_retry_immediately_after_defeat_writes_a_fresh_checkpoint_synchronously() -> void:
	_launch("the_gap", 1)
	_emit_defeat()

	_mission_select.retry_current_mission()

	# No `await get_tree().process_frame` anywhere above — if the write were
	# hiding behind a deferred call, this assertion would fail immediately
	# after retry_current_mission() returns.
	assert_bool(GSavePersistence.has_pending_checkpoint(TEST_SLOT)).is_true()


func test_retry_immediately_after_defeat_produces_a_loadable_checkpoint() -> void:
	_launch("the_gap", 1)
	_emit_defeat()

	_mission_select.retry_current_mission()
	var result: SavePersistence.LoadResult = GSavePersistence.restore_from_checkpoint(TEST_SLOT)
	await get_tree().process_frame

	assert_that(result).is_equal(SavePersistence.LoadResult.SUCCESS)


# ---------------------------------------------------------------------------
# The retry-triggered checkpoint reflects state AT RETRY TIME, not a stale
# copy from the original (pre-DEFEAT) launch — the exact concern a "race"
# framing implies (an old/incomplete snapshot winning over a fresher one).
# ---------------------------------------------------------------------------

func test_retry_checkpoint_reflects_current_state_not_the_stale_original_launch() -> void:
	var tracker := _TrackingSystem.new()
	GSavePersistence.register(tracker, 9000)  # deliberately far outside the real 1-36 range in use

	tracker.payload_value = 1
	_launch("the_gap", 1)  # checkpoint #1 written with payload_value == 1

	_emit_defeat()
	tracker.payload_value = 2  # state changes between the original launch and the retry
	_mission_select.retry_current_mission()  # checkpoint #2 overwrites checkpoint #1

	var result: SavePersistence.LoadResult = GSavePersistence.restore_from_checkpoint(TEST_SLOT)
	await get_tree().process_frame

	assert_that(result).is_equal(SavePersistence.LoadResult.SUCCESS)
	assert_int(tracker.payload_value).is_equal(2)  # restored from the RETRY's checkpoint, not launch's

	GSavePersistence.unregister(tracker)


# ---------------------------------------------------------------------------
# Back-to-back DEFEAT then retry with no yield in between (the tightest
# possible framing of the original "race" concern): DEFEAT's deferred
# save_slot() write and retry's synchronous save_checkpoint() write both end
# up pending/executed for the same slot in quick succession. Both must land
# without error or corrupting each other's file.
# ---------------------------------------------------------------------------

func test_defeat_then_immediate_retry_in_the_same_call_stack_produces_no_error() -> void:
	_launch("the_gap", 1)

	_emit_defeat()
	_mission_select.retry_current_mission()
	await get_tree().process_frame  # let DEFEAT's deferred save_slot() land too

	assert_bool(FileAccess.file_exists(TEST_CHECKPOINT)).is_true()
	assert_bool(FileAccess.file_exists(TEST_DAT)).is_true()
	assert_int(_mission_select.state).is_equal(MissionSelect.State.LAUNCHED)
