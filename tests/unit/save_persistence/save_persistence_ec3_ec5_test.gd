extends GdUnitTestSuite

## Tests for SavePersistence's EC-3 (crash recovery)/EC-5 (corrupt-save)
## backend, added 2026-08-01. Both were documented in save-persistence.md
## since this GDD was authored but never implemented until this pass — see
## save_persistence.gd's own class doc comment for the full contract.
##
## Uses slot 97 to avoid colliding with save_persistence_write_test.gd's
## own 98/99 convention (real save slots 0-2, high numbers for disposable
## test fixtures). Cleans up all written files in after_test().

const TEST_SLOT: int = 97
var TEST_DIR: String = UserDataPaths.root() + "saves/"
var TEST_DAT: String = UserDataPaths.root() + "saves/save_slot_97.dat"
var TEST_TMP: String = UserDataPaths.root() + "saves/save_slot_97.tmp"
var TEST_CHECKPOINT: String = UserDataPaths.root() + "saves/save_slot_97_checkpoint.dat"
var TEST_CORRUPT: String = UserDataPaths.root() + "saves/save_slot_97.corrupt"

var _sp: SavePersistence


func before_test() -> void:
	_sp = SavePersistence.new()
	_sp._ensure_save_dir()


func after_test() -> void:
	for path: String in [TEST_DAT, TEST_TMP, TEST_CHECKPOINT, TEST_CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_sp.free()


func _write_raw(path: String, version: int, payload: Variant) -> void:
	var file := FileAccess.open(TEST_TMP, FileAccess.WRITE)
	file.store_32(version)
	file.store_var(payload, false)
	file.close()
	var dir := DirAccess.open(TEST_DIR)
	dir.rename(TEST_TMP, path)


class _TrackingSystem extends RefCounted:
	var reset_called: bool = false
	var restore_called_with: Dictionary = {}
	func get_save_key() -> String: return "tracking_system"
	func get_save_data() -> Dictionary: return {"value": 42}
	func restore_save_data(data: Dictionary) -> bool:
		restore_called_with = data
		return true
	func reset_to_defaults() -> void: reset_called = true


# ---------------------------------------------------------------------------
# load_slot() — NOT_FOUND / VERSION_TOO_NEW / SUCCESS baseline
# ---------------------------------------------------------------------------

func test_load_slot_returns_not_found_when_no_file_exists() -> void:
	assert_that(_sp.load_slot(TEST_SLOT)).is_equal(SavePersistence.LoadResult.NOT_FOUND)


## AC-11 (already-implemented "downgrade blocked"): a version-too-new file
## must NOT be treated as EC-5 corruption — left completely untouched, no
## system reset.
func test_load_slot_returns_version_too_new_and_leaves_file_untouched() -> void:
	_write_raw(TEST_DAT, 9999, {"data": "whatever"})
	var system := _TrackingSystem.new()
	_sp.register(system, 10)

	var result: SavePersistence.LoadResult = _sp.load_slot(TEST_SLOT)

	assert_that(result).is_equal(SavePersistence.LoadResult.VERSION_TOO_NEW)
	assert_bool(FileAccess.file_exists(TEST_DAT)).is_true()  # untouched, not renamed
	assert_bool(FileAccess.file_exists(TEST_CORRUPT)).is_false()
	assert_bool(system.reset_called).is_false()


# ---------------------------------------------------------------------------
# EC-5 — total save corruption
# ---------------------------------------------------------------------------

func test_load_slot_on_corrupt_payload_returns_corrupt_recovered() -> void:
	_write_raw(TEST_DAT, 1, [1, 2, 3])  # wrong type on purpose — not a Dictionary

	var result: SavePersistence.LoadResult = _sp.load_slot(TEST_SLOT)

	assert_that(result).is_equal(SavePersistence.LoadResult.CORRUPT_RECOVERED)


func test_ec5_renames_the_corrupt_file_and_preserves_it() -> void:
	_write_raw(TEST_DAT, 1, [1, 2, 3])

	_sp.load_slot(TEST_SLOT)

	assert_bool(FileAccess.file_exists(TEST_DAT)).is_false()  # gone from its original path
	assert_bool(FileAccess.file_exists(TEST_CORRUPT)).is_true()  # preserved for debugging, not deleted


func test_ec5_resets_every_registered_system_to_defaults() -> void:
	_write_raw(TEST_DAT, 1, [1, 2, 3])
	var system_a := _TrackingSystem.new()
	var system_b := _TrackingSystem.new()
	_sp.register(system_a, 10)
	_sp.register(system_b, 20)

	_sp.load_slot(TEST_SLOT)

	assert_bool(system_a.reset_called).is_true()
	assert_bool(system_b.reset_called).is_true()


## EC-5: "the game has started fresh" — proceeds with a real, restored
## (default) Sanctuary state rather than getting stuck. sanctuary_state_
## restored is deferred one frame (AC-8's own established pattern).
func test_ec5_still_emits_sanctuary_state_restored() -> void:
	_write_raw(TEST_DAT, 1, [1, 2, 3])
	var received: Array = []
	var handler := func(slot: int) -> void: received.append(slot)
	GEventBus.sanctuary_state_restored.connect(handler)

	_sp.load_slot(TEST_SLOT)
	await get_tree().process_frame

	assert_array(received).contains([TEST_SLOT])
	GEventBus.sanctuary_state_restored.disconnect(handler)


func test_ec5_overwriting_a_prior_corrupt_file_does_not_error() -> void:
	# Simulate a second crash-recovery pass finding a .corrupt file already
	# present from an earlier one — must not block the new rename.
	var file := FileAccess.open(TEST_CORRUPT, FileAccess.WRITE)
	file.store_string("stale corrupt file from an earlier recovery")
	file.close()
	_write_raw(TEST_DAT, 1, [1, 2, 3])

	var result: SavePersistence.LoadResult = _sp.load_slot(TEST_SLOT)

	assert_that(result).is_equal(SavePersistence.LoadResult.CORRUPT_RECOVERED)
	assert_bool(FileAccess.file_exists(TEST_CORRUPT)).is_true()


# ---------------------------------------------------------------------------
# EC-3 — checkpoint exists on startup (crash recovery)
# ---------------------------------------------------------------------------

func test_has_pending_checkpoint_false_when_none_exists() -> void:
	assert_bool(_sp.has_pending_checkpoint(TEST_SLOT)).is_false()


func test_has_pending_checkpoint_true_when_one_exists() -> void:
	_sp._write_checkpoint(TEST_SLOT, {"value": 1})
	assert_bool(_sp.has_pending_checkpoint(TEST_SLOT)).is_true()


func test_restore_from_checkpoint_returns_not_found_when_none_exists() -> void:
	assert_that(_sp.restore_from_checkpoint(TEST_SLOT)).is_equal(SavePersistence.LoadResult.NOT_FOUND)


func test_restore_from_checkpoint_success_restores_checkpoint_data() -> void:
	var system := _TrackingSystem.new()
	_sp.register(system, 10)
	# Checkpoint payload is keyed by save_key, matching the real
	# _collect_save_data()/_restore_one() structure -- not a flat dict.
	_sp._write_checkpoint(TEST_SLOT, {"tracking_system": {"value": 99}})

	var result: SavePersistence.LoadResult = _sp.restore_from_checkpoint(TEST_SLOT)
	await get_tree().process_frame

	assert_that(result).is_equal(SavePersistence.LoadResult.SUCCESS)
	assert_int(system.restore_called_with.get("value", -1)).is_equal(99)


## "The checkpoint is deleted after either choice" — restore_from_checkpoint
## is one of the two EC-3 choices.
func test_restore_from_checkpoint_success_deletes_the_checkpoint() -> void:
	_sp._write_checkpoint(TEST_SLOT, {"value": 1})

	_sp.restore_from_checkpoint(TEST_SLOT)

	assert_bool(FileAccess.file_exists(TEST_CHECKPOINT)).is_false()


## A corrupt checkpoint must NOT reset registered systems to defaults the
## way EC-5 does — the checkpoint is "advisory" (Rule 5); a good
## save_slot_N.dat likely still exists, and load_slot() is the caller's
## fallback, not a forced reset of real progress.
func test_restore_from_checkpoint_on_corrupt_checkpoint_does_not_reset_systems() -> void:
	_write_raw(TEST_CHECKPOINT, 1, [1, 2, 3])
	var system := _TrackingSystem.new()
	_sp.register(system, 10)

	var result: SavePersistence.LoadResult = _sp.restore_from_checkpoint(TEST_SLOT)

	assert_that(result).is_equal(SavePersistence.LoadResult.CHECKPOINT_CORRUPT)
	assert_bool(system.reset_called).is_false()


func test_restore_from_checkpoint_on_corrupt_checkpoint_still_deletes_it() -> void:
	_write_raw(TEST_CHECKPOINT, 1, [1, 2, 3])

	_sp.restore_from_checkpoint(TEST_SLOT)

	assert_bool(FileAccess.file_exists(TEST_CHECKPOINT)).is_false()


## The OTHER EC-3 choice — "Load last Sanctuary save" (load_slot()) — must
## also delete a pending checkpoint, per the identical "either choice" rule.
func test_load_slot_success_also_deletes_a_pending_checkpoint() -> void:
	# At least one registered system, so _collect_save_data() isn't a truly
	# empty dict -- an empty {} is indistinguishable from a failed read by
	# load_slot()'s own is_empty() check, same ambiguity _read_slot() has
	# always had; irrelevant in real play (systems are always registered)
	# but real for this isolated fixture.
	_sp.register(_TrackingSystem.new(), 10)
	_sp.save_slot(TEST_SLOT)  # writes TEST_DAT; save_slot()'s own Rule 5 cleanup runs here too
	# if a checkpoint existed, so re-create it afterward to isolate load_slot()'s own deletion.
	_sp._write_checkpoint(TEST_SLOT, {"value": 1})

	_sp.load_slot(TEST_SLOT)

	assert_bool(FileAccess.file_exists(TEST_CHECKPOINT)).is_false()


# ---------------------------------------------------------------------------
# Rule 5 — normal flow: a successful save deletes any pending checkpoint
# ---------------------------------------------------------------------------

func test_save_slot_deletes_a_pending_checkpoint_on_success() -> void:
	_sp._write_checkpoint(TEST_SLOT, {"value": 1})

	_sp.save_slot(TEST_SLOT)

	assert_bool(FileAccess.file_exists(TEST_CHECKPOINT)).is_false()


func test_save_slot_with_no_checkpoint_does_not_error() -> void:
	assert_bool(_sp.save_slot(TEST_SLOT)).is_true()
	assert_bool(FileAccess.file_exists(TEST_CHECKPOINT)).is_false()


# ---------------------------------------------------------------------------
# start_new_game() — regression guard for the real bug found and fixed
# 2026-08-08: Main Menu's New Game path called only set_active_slot(), never
# load_slot() (nothing to load on an empty slot) and therefore never emitted
# sanctuary_state_restored. Every system gated on that signal (most visibly
# MissionSelect._restore_completed, which can_launch() checks before every
# real mission launch) stayed permanently false for a New Game session — a
# real player could reach Mission Select, pick a mission, press Confirm
# Launch, and nothing would happen, with no error and no feedback. Mirrors
# EC-5's already-tested "fresh Sanctuary" pattern above.
# ---------------------------------------------------------------------------

func test_start_new_game_sets_active_slot() -> void:
	_sp.start_new_game(TEST_SLOT)
	assert_int(_sp._active_slot).is_equal(TEST_SLOT)


func test_start_new_game_resets_every_registered_system_to_defaults() -> void:
	var system_a := _TrackingSystem.new()
	var system_b := _TrackingSystem.new()
	_sp.register(system_a, 10)
	_sp.register(system_b, 20)

	_sp.start_new_game(TEST_SLOT)

	assert_bool(system_a.reset_called).is_true()
	assert_bool(system_b.reset_called).is_true()


func test_start_new_game_emits_sanctuary_state_restored() -> void:
	var received: Array = []
	var handler := func(slot: int) -> void: received.append(slot)
	GEventBus.sanctuary_state_restored.connect(handler)

	_sp.start_new_game(TEST_SLOT)
	await get_tree().process_frame

	assert_array(received).contains([TEST_SLOT])
	GEventBus.sanctuary_state_restored.disconnect(handler)


func test_start_new_game_does_not_write_any_file() -> void:
	_sp.start_new_game(TEST_SLOT)
	assert_bool(FileAccess.file_exists(TEST_DAT)).is_false()
