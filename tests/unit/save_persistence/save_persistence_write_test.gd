extends GdUnitTestSuite

## Tests for SavePersistence file I/O: write, read, atomic rename, and tmp cleanup.
##
## ADR-0003 / TR-save-001, TR-save-002, TR-save-005 validation.
## Uses high slot indices (97–99) to avoid colliding with real save slots (0–2).
## Cleans up all written files in after_test().

const TEST_SLOT: int = 99
const TEST_SLOT_B: int = 98
const TEST_DIR: String = "user://saves/"
const TEST_DAT: String = "user://saves/save_slot_99.dat"
const TEST_TMP: String = "user://saves/save_slot_99.tmp"
const TEST_CHECKPOINT: String = "user://saves/save_slot_99_checkpoint.dat"

var _sp: SavePersistence


func before_test() -> void:
	_sp = SavePersistence.new()
	# Ensure the saves directory exists for tests that don't call _ensure_save_dir().
	_sp._ensure_save_dir()


func after_test() -> void:
	# Remove any files written during this test.
	for path: String in [TEST_DAT, TEST_TMP, TEST_CHECKPOINT,
			"user://saves/save_slot_98.dat", "user://saves/save_slot_98.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_sp.free()


# ---------------------------------------------------------------------------
# Write / read round-trip
# ---------------------------------------------------------------------------

func test_write_slot_returns_true_on_success() -> void:
	# Arrange
	var data := {"score": 42, "level": 3}
	# Act
	var result: bool = _sp._write_slot(TEST_SLOT, data)
	# Assert
	assert_bool(result).is_true()


func test_write_and_read_roundtrip_preserves_data() -> void:
	# Arrange
	var data := {"hero": {"level": 10, "xp": 500}, "gold": 1200}
	# Act
	_sp._write_slot(TEST_SLOT, data)
	var loaded: Dictionary = _sp._read_slot(TEST_SLOT)
	# Assert
	assert_that(loaded).is_equal(data)


func test_read_slot_returns_empty_when_file_absent() -> void:
	# Slot 98 has no file written in this test.
	var result: Dictionary = _sp._read_slot(TEST_SLOT_B)
	assert_that(result).is_equal({})


# ---------------------------------------------------------------------------
# Atomic write: .tmp renamed to .dat
# ---------------------------------------------------------------------------

func test_write_slot_dat_file_exists_after_write() -> void:
	_sp._write_slot(TEST_SLOT, {"x": 1})
	assert_bool(FileAccess.file_exists(TEST_DAT)).is_true()


func test_write_slot_tmp_file_absent_after_successful_write() -> void:
	# After a successful write, .tmp must be renamed to .dat — no .tmp residue.
	_sp._write_slot(TEST_SLOT, {"x": 1})
	assert_bool(FileAccess.file_exists(TEST_TMP)).is_false()


# ---------------------------------------------------------------------------
# Version header: too-new save returns empty (no crash)
# ---------------------------------------------------------------------------

func test_read_slot_returns_empty_when_version_newer_than_current() -> void:
	# Write a file with a version number far in the future.
	var tmp_path: String = "user://saves/save_slot_99.tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	file.store_32(9999)  # version 9999 > CURRENT_FORMAT_VERSION
	file.store_var({"data": "whatever"}, false)
	file.close()
	var dir := DirAccess.open(TEST_DIR)
	dir.rename(tmp_path, TEST_DAT)
	# Act
	var result: Dictionary = _sp._read_slot(TEST_SLOT)
	# Assert — must not crash; returns {} with an error logged
	assert_that(result).is_equal({})


# ---------------------------------------------------------------------------
# Corrupt file: non-Dictionary payload returns empty
# ---------------------------------------------------------------------------

func test_read_slot_returns_empty_on_corrupt_payload() -> void:
	# Write a valid header but store an Array instead of a Dictionary.
	var tmp_path: String = "user://saves/save_slot_99.tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	file.store_32(1)
	file.store_var([1, 2, 3], false)  # wrong type on purpose
	file.close()
	var dir := DirAccess.open(TEST_DIR)
	dir.rename(tmp_path, TEST_DAT)
	var result: Dictionary = _sp._read_slot(TEST_SLOT)
	assert_that(result).is_equal({})


# ---------------------------------------------------------------------------
# Tmp cleanup on _ready equivalent
# ---------------------------------------------------------------------------

func test_cleanup_tmp_files_removes_leftover_tmp() -> void:
	# Plant a .tmp file to simulate a prior crash.
	var file := FileAccess.open(TEST_TMP, FileAccess.WRITE)
	file.store_32(1)
	file.close()
	assert_bool(FileAccess.file_exists(TEST_TMP)).is_true()
	# Act
	_sp._cleanup_tmp_files()
	# Assert
	assert_bool(FileAccess.file_exists(TEST_TMP)).is_false()


# ---------------------------------------------------------------------------
# Save directory created if absent (smoke)
# ---------------------------------------------------------------------------

func test_ensure_save_dir_creates_directory() -> void:
	# This test just verifies the directory exists after _ensure_save_dir().
	# The saves/ dir was already created in before_test(), so this confirms
	# repeated calls are idempotent.
	_sp._ensure_save_dir()
	assert_bool(DirAccess.dir_exists_absolute(TEST_DIR)).is_true()
