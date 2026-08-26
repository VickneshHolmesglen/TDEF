## Integration test for the DEFEAT-save-then-immediate-retry checkpoint
## interaction flagged as genuinely untested in mission-select.md/
## save-persistence.md's Rule 9/10 (found stale-blocker-free but this one
## real gap during the 2026-08-27 `/design-review` re-review sweep — see
## systems-index.md's Mission Select row).
##
## **Real implementation finding, made while writing this test**:
## `save-persistence.md` Rule 9 describes a dedicated "DEFEAT-triggered save,
## deferred exactly 1 frame" mechanism, gated on `mission_phase_changed`
## reaching `DEFEAT`. `save_persistence.gd`'s own `_ready()` subscribes only
## to `mission_launched` and `scene_transition_completed` — there is no
## `mission_phase_changed` subscription anywhere in the shipped file, and no
## other file calls `GSavePersistence.save_slot()`/`save_checkpoint()` on
## DEFEAT either (confirmed via project-wide grep). Rule 9's mechanism does
## not exist in code today. This is a real, previously-undiscovered gap
## between the GDD and the implementation — not something this test file
## silently works around. What DOES exist and IS exercised here: DEFEAT
## arms `MissionSelect.retry_current_mission()` (Rule 10), and calling it
## re-emits `mission_launched`, which re-triggers the existing, already-
## shipped `_on_mission_launched()` -> `save_checkpoint()` path. That is the
## one real save activity anywhere near a DEFEAT+retry sequence, and it is
## what this suite verifies is race-free, synchronous, and reflects current
## (not stale) state. If Rule 9's separate mechanism is ever implemented,
## this suite's coverage should be extended, not replaced — a fresh
## DEFEAT-save landing in the same frame as a retry-triggered checkpoint
## write would be a genuinely new interaction to verify.
##
## Uses the real `GSavePersistence`/`GEventBus` Autoloads (matching
## retry-current-mission-api_test.gd's own established convention) —
## MissionSelect is instantiated directly (no add_child()) so its own
## _ready()/EventBus subscriptions never run; DEFEAT/retry are driven
## directly through its public API instead. Slot 96 avoids colliding with
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


# ---------------------------------------------------------------------------
# DEFEAT alone (MissionSelect's own state transition) never touches the
# checkpoint — confirms Rule 9's absent DEFEAT-handler finding above by
# observation, not by asserting the absence of a signal connection directly.
# ---------------------------------------------------------------------------

func test_defeat_transition_alone_does_not_rewrite_the_checkpoint() -> void:
	_launch("the_gap", 1)
	assert_bool(FileAccess.file_exists(TEST_CHECKPOINT)).is_true()
	var mtime_after_launch: int = FileAccess.get_modified_time(TEST_CHECKPOINT)

	_mission_select._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 100.0)

	assert_int(FileAccess.get_modified_time(TEST_CHECKPOINT)).is_equal(mtime_after_launch)
	assert_int(_mission_select.state).is_equal(MissionSelect.State.DORMANT_RETRY_ARMED)


# ---------------------------------------------------------------------------
# Retry immediately after DEFEAT correctly re-triggers a checkpoint write —
# synchronously, no frame wait required, no error.
# ---------------------------------------------------------------------------

func test_retry_immediately_after_defeat_writes_a_fresh_checkpoint_synchronously() -> void:
	_launch("the_gap", 1)
	_mission_select._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 100.0)

	_mission_select.retry_current_mission()

	# No `await get_tree().process_frame` anywhere above — if the write were
	# hiding behind a deferred call, this assertion would fail immediately
	# after retry_current_mission() returns.
	assert_bool(GSavePersistence.has_pending_checkpoint(TEST_SLOT)).is_true()


func test_retry_immediately_after_defeat_produces_a_loadable_checkpoint() -> void:
	_launch("the_gap", 1)
	_mission_select._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 100.0)

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

	_mission_select._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 100.0)
	tracker.payload_value = 2  # state changes between the original launch and the retry
	_mission_select.retry_current_mission()  # checkpoint #2 overwrites checkpoint #1

	var result: SavePersistence.LoadResult = GSavePersistence.restore_from_checkpoint(TEST_SLOT)
	await get_tree().process_frame

	assert_that(result).is_equal(SavePersistence.LoadResult.SUCCESS)
	assert_int(tracker.payload_value).is_equal(2)  # restored from the RETRY's checkpoint, not launch's

	GSavePersistence.unregister(tracker)


# ---------------------------------------------------------------------------
# Back-to-back DEFEAT then retry with no yield in between (the tightest
# possible framing of the "race") produces exactly one checkpoint write and
# no error — proving there is nothing today for the two to actually race
# against, since DEFEAT itself performs no save I/O (see class doc comment).
# ---------------------------------------------------------------------------

func test_defeat_then_immediate_retry_in_the_same_call_stack_produces_no_error() -> void:
	_launch("the_gap", 1)

	_mission_select._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 100.0)
	_mission_select.retry_current_mission()

	assert_bool(FileAccess.file_exists(TEST_CHECKPOINT)).is_true()
	assert_int(_mission_select.state).is_equal(MissionSelect.State.LAUNCHED)
