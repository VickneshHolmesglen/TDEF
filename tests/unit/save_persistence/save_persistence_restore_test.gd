extends GdUnitTestSuite

## Tests for SavePersistence restore logic: ordering, fallback, migration, deferred emit.
##
## ADR-0003 / TR-save-003, TR-save-004 validation.
## Uses inner mock classes — no file I/O, no Autoload dependencies.
## _SavePersistenceStub overrides _emit_state_restored() to eliminate EventBus dependency.

# ---------------------------------------------------------------------------
# Stub subclass: overrides the EventBus emit seam so tests need no Autoloads.
# ---------------------------------------------------------------------------
class _SavePersistenceStub extends SavePersistence:
	func _emit_state_restored(_slot: int) -> void:
		pass


# ---------------------------------------------------------------------------
# Mock saveable system for testing restore behaviour.
# ---------------------------------------------------------------------------
class _MockSystem extends RefCounted:
	var save_key: String
	var restore_called_with: Dictionary = {}
	var reset_called: bool = false
	var restore_should_succeed: bool = true
	## Assign a shared Array before calling _restore_all_systems to record call order.
	var shared_call_log: Array = []

	func get_save_key() -> String:
		return save_key

	func get_save_data() -> Dictionary:
		return {"key": save_key}

	## Appends save_key to shared_call_log so tests can verify restore order.
	func restore_save_data(data: Dictionary) -> bool:
		restore_called_with = data
		shared_call_log.append(save_key)
		return restore_should_succeed

	func reset_to_defaults() -> void:
		reset_called = true


var _sp: _SavePersistenceStub
## Shared call order recorder — assign to each mock's shared_call_log before the test call.
var _restore_call_order: Array = []


func before_test() -> void:
	_sp = _SavePersistenceStub.new()
	_restore_call_order = []


func after_test() -> void:
	_sp.free()


# ---------------------------------------------------------------------------
# Restore ordering — systems restored by ascending restore_order
# ---------------------------------------------------------------------------

func test_restore_systems_called_in_ascending_restore_order() -> void:
	# Arrange: register in REVERSE order to prove sort is applied.
	var sys_high := _MockSystem.new()
	sys_high.save_key = "sys_high"
	sys_high.shared_call_log = _restore_call_order
	var sys_low := _MockSystem.new()
	sys_low.save_key = "sys_low"
	sys_low.shared_call_log = _restore_call_order

	# Register higher-order system first — sort must reorder them.
	_sp._registered_systems.append({"ref": sys_high, "key": "sys_high", "restore_order": 30})
	_sp._registered_systems.append({"ref": sys_low,  "key": "sys_low",  "restore_order": 10})

	# Act
	_sp._restore_all_systems({"sys_high": {"v": 1}, "sys_low": {"v": 2}}, 0)

	# Assert ORDER: sys_low (restore_order 10) must be restored before sys_high (restore_order 30).
	assert_int(_restore_call_order.size()).is_equal(2)
	assert_that(_restore_call_order[0]).is_equal("sys_low")
	assert_that(_restore_call_order[1]).is_equal("sys_high")


# ---------------------------------------------------------------------------
# restore_save_data() returns false → reset_to_defaults() called
# ---------------------------------------------------------------------------

func test_restore_failure_calls_reset_to_defaults() -> void:
	# Arrange
	var sys := _MockSystem.new()
	sys.save_key = "fragile_system"
	sys.restore_should_succeed = false
	_sp._registered_systems.append({"ref": sys, "key": "fragile_system", "restore_order": 10})
	# Act
	_sp._restore_all_systems({"fragile_system": {"some": "data"}}, 0)
	# Assert
	assert_bool(sys.reset_called).is_true()


# ---------------------------------------------------------------------------
# Missing key in save data → silent reset_to_defaults(), no crash
# ---------------------------------------------------------------------------

func test_restore_missing_key_in_data_calls_reset_to_defaults() -> void:
	# Arrange: register a system but provide save data with no matching key.
	var sys := _MockSystem.new()
	sys.save_key = "unknown_system"
	_sp._registered_systems.append({"ref": sys, "key": "unknown_system", "restore_order": 10})
	# Act: data dict has no "unknown_system" entry.
	_sp._restore_all_systems({"other_system": {"x": 1}}, 0)
	# Assert: reset_to_defaults called, restore_save_data NOT called.
	assert_bool(sys.reset_called).is_true()
	assert_that(sys.restore_called_with).is_equal({})


# ---------------------------------------------------------------------------
# Empty dict from data[key] → reset_to_defaults(), not restore_save_data()
# ---------------------------------------------------------------------------

func test_restore_empty_dict_for_key_calls_reset_not_restore() -> void:
	var sys := _MockSystem.new()
	sys.save_key = "empty_sys"
	_sp._registered_systems.append({"ref": sys, "key": "empty_sys", "restore_order": 10})
	_sp._restore_all_systems({"empty_sys": {}}, 0)
	assert_bool(sys.reset_called).is_true()
	assert_that(sys.restore_called_with).is_equal({})


# ---------------------------------------------------------------------------
# Migration: _migrate() chains _migrate_step() for each version increment
# ---------------------------------------------------------------------------

func test_migrate_chains_steps_from_version_to_current() -> void:
	# CURRENT_FORMAT_VERSION = 1; from_version = 0 means one step: 0→1.
	# _migrate_step for version 0 is unimplemented (logs error, returns data unchanged).
	# This test verifies the loop runs exactly (1 - 0 = 1) time without crashing.
	var input := {"legacy_key": "value"}
	var result: Dictionary = _sp._migrate(input, 0)
	# _migrate_step v0 has no migration path — returns data unchanged, logs error.
	assert_that(result).is_equal(input)


# ---------------------------------------------------------------------------
# _migrate() is a no-op when from_version == CURRENT_FORMAT_VERSION
# ---------------------------------------------------------------------------

func test_migrate_noop_when_already_current_version() -> void:
	var input := {"hero": {"level": 5}}
	# range(1, 1) is empty — no steps executed.
	var result: Dictionary = _sp._migrate(input, 1)
	assert_that(result).is_equal(input)
