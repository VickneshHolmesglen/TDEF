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


## Mock with the optional exit-state hook (Hero uses it for full HP).
class _MockSystemWithExitData extends _MockSystem:
	func get_save_data_on_unregister() -> Dictionary:
		return {"exit": true}


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


# ---------------------------------------------------------------------------
# TD-save-001 debt closure: AC-12 — EventBus signal wiring for mission_launched
# ---------------------------------------------------------------------------

## AC-12 (part 1): _on_mission_launched() handler writes a checkpoint file for
## the currently active slot. Tests the handler logic directly.
func test_mission_launched_handler_saves_checkpoint_for_active_slot() -> void:
	# Arrange: real SavePersistence (not stub) so checkpoint I/O actually runs.
	var sp := SavePersistence.new()
	sp._ensure_save_dir()
	sp.set_active_slot(97)  # high slot to avoid collision with real saves
	sp._begin_fresh_session()  # automatic saves need a loaded/new game
	# Act
	sp._on_mission_launched("forest_01", PackedStringArray([]), 1)
	# Assert
	var checkpoint_path: String = UserDataPaths.root() + "saves/save_slot_97_checkpoint.dat"
	assert_bool(FileAccess.file_exists(checkpoint_path)).is_true()
	# Cleanup
	DirAccess.remove_absolute(checkpoint_path)
	sp.free()


## AC-12 (part 2): after _ready() connects to GEventBus, emitting
## GEventBus.mission_launched routes to _on_mission_launched() and creates
## the checkpoint — verifying the full signal-wiring chain end-to-end.
##
## No post-emit await: .emit() invokes connected handlers synchronously, so
## save_checkpoint() has already run by the time emit() returns — asserting
## immediately captures that. A trailing await here is actively wrong: the
## real WaveManager Autoload is also live in this test's tree and reacts to
## the same mission_launched emission. Given "forest_01" has no real
## WaveConfig content in this suite's environment, WaveManager fails its own
## load, hits 0 spawn cells, and short-circuits straight to MISSION_COMPLETE
## — which SceneManager turns into a scene_transition_completed("SANCTUARY")
## within 1-2 frames. sp is independently subscribed to that same signal and
## correctly (per its own documented Rule 5 "normal flow" behavior) deletes
## its own just-written checkpoint in response. A post-emit await gave that
## real, unrelated cascade enough time to race the assertion and delete the
## very file this test exists to confirm — confirmed via direct Godot MCP
## tracing (checkpoint present immediately after emit, gone by frame 1).
func test_mission_launched_signal_wired_after_ready_triggers_checkpoint() -> void:
	# Arrange: add to scene tree so _ready() fires and EventBus connections are made.
	var sp := SavePersistence.new()
	sp._ensure_save_dir()
	sp.set_active_slot(96)
	sp._begin_fresh_session()
	add_child(sp)
	await get_tree().process_frame  # allow _ready() to complete
	# Act: emit via GEventBus — should route to _on_mission_launched → save_checkpoint
	GEventBus.mission_launched.emit("forest_01", PackedStringArray([]), 1)
	# Assert — immediately, before any other Autoload's reaction to this same
	# signal can race back around and delete the checkpoint (see doc comment).
	var checkpoint_path: String = UserDataPaths.root() + "saves/save_slot_96_checkpoint.dat"
	assert_bool(FileAccess.file_exists(checkpoint_path)).is_true()
	# Cleanup: remove_child disconnects _exit_tree (which removes EventBus connections)
	remove_child(sp)
	sp.free()
	if FileAccess.file_exists(checkpoint_path):
		DirAccess.remove_absolute(checkpoint_path)


## Regression test for the 2026-08-17 fix: the SANCTUARY autosave trigger was
## previously gated on GEventBus.mission_phase_changed's new_phase ==
## "SANCTUARY", a value WaveManager's own Phase enum never actually emits —
## making this path permanently dead. Now driven by
## GEventBus.scene_transition_completed(target_context="SANCTUARY"), the same
## signal sanctuary_ui.gd/tarot.gd already key off of.
func test_scene_transition_completed_sanctuary_saves_slot_and_unpauses_autosave() -> void:
	# Arrange: add to scene tree so _ready() fires and EventBus connections are made.
	var sp := SavePersistence.new()
	sp._ensure_save_dir()
	sp.set_active_slot(95)
	sp._begin_fresh_session()
	add_child(sp)
	await get_tree().process_frame
	sp._autosave_timer.paused = true  # simulate having been paused during a mission
	var save_path: String = UserDataPaths.root() + "saves/save_slot_95.dat"
	# Act — no post-emit await needed: .emit() invokes connected handlers
	# synchronously (see the sibling mission_launched test's doc comment for
	# the race this avoids elsewhere in this file).
	GEventBus.scene_transition_completed.emit("SANCTUARY", "")
	# Assert
	assert_bool(FileAccess.file_exists(save_path)).is_true()
	assert_bool(sp._autosave_timer.paused).is_false()
	# Cleanup
	remove_child(sp)
	sp.free()
	DirAccess.remove_absolute(save_path)


## Regression (2026-11-03): with no slot loaded and no new game started, every
## automatic save path must leave the slot and its checkpoint alone. A mission
## run straight from the editor (or a script that changed scene without
## loading) otherwise overwrote slot 0 with an empty game on reaching the
## Sanctuary, and deleted its checkpoint.
func test_save_persistence_automatic_saves_without_session_do_not_touch_slot() -> void:
	# Arrange: a real slot and checkpoint on disk, but no session this run.
	var sp := SavePersistence.new()
	sp._ensure_save_dir()
	sp.set_active_slot(94)
	var save_path: String = UserDataPaths.root() + "saves/save_slot_94.dat"
	var checkpoint_path: String = UserDataPaths.root() + "saves/save_slot_94_checkpoint.dat"
	sp._write_slot(94, {"inventory": {"marker": "player data"}})
	sp._write_checkpoint(94, {"inventory": {"marker": "player data"}})
	add_child(sp)
	await get_tree().process_frame
	# Act: every automatic save trigger.
	sp._on_scene_transition_completed("SANCTUARY", "")
	sp._on_autosave_timer_timeout()
	sp._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)
	sp._on_mission_launched("the_gap", PackedStringArray([]), 1)
	await get_tree().process_frame  # the DEFEAT save is deferred
	# Assert: file untouched, checkpoint kept; the timer still unpauses.
	assert_dict(sp._read_slot(94)).is_equal({"inventory": {"marker": "player data"}})
	assert_bool(FileAccess.file_exists(checkpoint_path)).is_true()
	assert_bool(sp._autosave_timer.paused).is_false()
	# Cleanup
	remove_child(sp)
	sp.free()
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(checkpoint_path)


## Companion regression test: entering a mission must pause the autosave timer
## (previously piggybacked on the same dead "SANCTUARY" branch above).
func test_scene_transition_completed_mission_pauses_autosave() -> void:
	var sp := SavePersistence.new()
	sp._ensure_save_dir()
	add_child(sp)
	await get_tree().process_frame
	sp._autosave_timer.paused = false  # simulate having been unpaused at Sanctuary
	# Act
	GEventBus.scene_transition_completed.emit("MISSION", "the_gap")
	await get_tree().process_frame
	# Assert
	assert_bool(sp._autosave_timer.paused).is_true()
	# Cleanup
	remove_child(sp)
	sp.free()


# ---------------------------------------------------------------------------
# ADR-0003 (2026-07-18 revision): mid-session-restore for late registration.
# A SaveRestorer that calls register() AFTER load_slot() has already run
# (e.g. a scene-instanced system recreated on a Sanctuary<->Mission
# transition) must still be restored from the cached data, not left at
# @export defaults for the rest of the session.
# ---------------------------------------------------------------------------

func test_late_registration_after_load_restores_from_cached_data() -> void:
	# Arrange: a full load already happened with sys_a registered.
	var sys_a := _MockSystem.new()
	sys_a.save_key = "sys_a"
	_sp._registered_systems.append({"ref": sys_a, "key": "sys_a", "restore_order": 10})
	_sp._restore_all_systems({"sys_a": {"v": 1}, "sys_b": {"v": 2}}, 0)

	# Act: sys_b registers AFTER the load already completed (e.g. its owning
	# scene was just instanced for the first time this session).
	var sys_b := _MockSystem.new()
	sys_b.save_key = "sys_b"
	_sp.register(sys_b, 24)

	# Assert: sys_b was restored immediately from the cached data, not left default.
	assert_bool(sys_b.reset_called).is_false()
	assert_that(sys_b.restore_called_with).is_equal({"v": 2})


func test_late_registration_with_no_matching_key_calls_reset_to_defaults() -> void:
	# Arrange: a full load already happened, but the loaded save predates sys_c.
	var sys_a := _MockSystem.new()
	sys_a.save_key = "sys_a"
	_sp._registered_systems.append({"ref": sys_a, "key": "sys_a", "restore_order": 10})
	_sp._restore_all_systems({"sys_a": {"v": 1}}, 0)

	# Act: sys_c registers late, but the loaded save has no "sys_c" entry.
	var sys_c := _MockSystem.new()
	sys_c.save_key = "sys_c"
	_sp.register(sys_c, 24)

	# Assert: falls back to defaults, exactly like the initial-load missing-key case.
	assert_bool(sys_c.reset_called).is_true()
	assert_that(sys_c.restore_called_with).is_equal({})


## Changed 2026-11-02 (session carry-over): this test used to require every
## re-instance to restore the LOAD-TIME data ({"v": 42}), which is exactly the
## rollback bug -- hero XP reset every mission, Forge discoveries every
## Sanctuary visit. Each re-instance now restores the state the previous
## instance left with (the mock's get_save_data() is {"key": "sys_d"}).
func test_repeated_unregister_register_cycle_restores_latest_state() -> void:
	# Arrange: a load happened; the system is re-mounted several times in one
	# continuous session (Sanctuary <-> Mission <-> Sanctuary).
	_sp._restore_all_systems({"sys_d": {"v": 42}}, 0)

	# Act
	var first_instance := _MockSystem.new()
	first_instance.save_key = "sys_d"
	_sp.register(first_instance, 24)
	_sp.unregister(first_instance)

	var second_instance := _MockSystem.new()
	second_instance.save_key = "sys_d"
	_sp.register(second_instance, 24)

	# Assert: the first instance got the loaded data, the second the state
	# the first one left with.
	assert_that(first_instance.restore_called_with).is_equal({"v": 42})
	assert_that(second_instance.restore_called_with).is_equal({"key": "sys_d"})


func test_save_while_system_unmounted_keeps_its_last_state() -> void:
	# Arrange: sys_a stays mounted (autoload-like); sys_f is scene-scoped.
	var sys_a := _MockSystem.new()
	sys_a.save_key = "sys_a"
	_sp._registered_systems.append({"ref": sys_a, "key": "sys_a", "restore_order": 10})
	_sp._restore_all_systems({"sys_a": {"v": 1}, "sys_f": {"v": 7}, "sys_g": {"v": 9}}, 0)
	var sys_f := _MockSystem.new()
	sys_f.save_key = "sys_f"
	_sp.register(sys_f, 32)
	_sp.unregister(sys_f)

	# Act: a save while sys_f is not mounted (e.g. the DEFEAT save in a mission).
	var data: Dictionary = _sp._collect_save_data()

	# Assert: sys_f keeps the state it left with; sys_g (never mounted this
	# session) keeps its loaded data; sys_a is live.
	assert_that(data["sys_f"]).is_equal({"key": "sys_f"})
	assert_that(data["sys_g"]).is_equal({"v": 9})
	assert_that(data["sys_a"]).is_equal({"key": "sys_a"})


func test_unregister_prefers_get_save_data_on_unregister() -> void:
	# Arrange
	_sp._restore_all_systems({}, 0)
	var sys := _MockSystemWithExitData.new()
	sys.save_key = "sys_h"
	_sp.register(sys, 30)

	# Act
	_sp.unregister(sys)

	# Assert
	assert_that(_sp._last_loaded_data["sys_h"]).is_equal({"exit": true})


func test_start_new_game_drops_carry_over_from_an_earlier_load() -> void:
	# Arrange: slot 0 was loaded earlier this session with sys_i data.
	_sp._restore_all_systems({"sys_i": {"v": 3}}, 0)

	# Act: New Game on another slot, then sys_i mounts for the first time.
	_sp.start_new_game(1)
	var sys_i := _MockSystem.new()
	sys_i.save_key = "sys_i"
	_sp.register(sys_i, 24)

	# Assert: defaults, never slot 0's data; and nothing carried into a save.
	assert_bool(sys_i.reset_called).is_true()
	assert_that(sys_i.restore_called_with).is_equal({})
	assert_that(_sp._collect_save_data()).is_equal({"sys_i": {"key": "sys_i"}})


func test_unregister_before_any_load_does_not_touch_the_cache() -> void:
	# Arrange
	var sys := _MockSystem.new()
	sys.save_key = "sys_j"
	_sp.register(sys, 10)

	# Act
	_sp.unregister(sys)

	# Assert
	assert_bool(_sp._last_loaded_data.has("sys_j")).is_false()


func test_registration_before_any_load_does_not_restore() -> void:
	# Arrange/Act: register with no load_slot()/_restore_all_systems() having run yet
	# (e.g. main menu boot, before a save is loaded) — _has_loaded_data is false.
	var sys := _MockSystem.new()
	sys.save_key = "sys_e"
	_sp.register(sys, 10)

	# Assert: neither restore_save_data() nor reset_to_defaults() was called —
	# the system simply keeps its own @export defaults, exactly as before this fix.
	assert_bool(sys.reset_called).is_false()
	assert_that(sys.restore_called_with).is_equal({})
