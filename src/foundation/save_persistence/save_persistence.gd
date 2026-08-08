class_name SavePersistence
extends Node

## SavePersistence — Autoload #2 (boot order: EventBus → SavePersistence → Grid → Pathfinding).
##
## Manages 3 save slots with atomic .tmp→.dat writes, version-headered binary
## format, ordered system restore, and autosave gating via a child Timer node.
##
## Registered systems must implement:
##   get_save_key() -> String
##   get_save_data() -> Dictionary  (primitives only — see ADR-0003)
##   restore_save_data(data: Dictionary) -> bool
##   reset_to_defaults() -> void
##
## EC-3/EC-5 backend (2026-08-01, `save-persistence.md`'s own Edge Cases —
## documented since this GDD was authored, never implemented until now):
## `load_slot()` now distinguishes NOT_FOUND / VERSION_TOO_NEW /
## CORRUPT_RECOVERED / SUCCESS instead of a plain bool, so a caller can tell
## "no save" apart from "a save exists but couldn't be used." EC-5 (total
## save corruption — the file exists but its data can't be parsed as a
## Dictionary) renames the file to `save_slot_N.corrupt` (preserved for
## debugging, matching the GDD's own wording), resets every registered
## system to defaults, and still emits `sanctuary_state_restored` — the
## game proceeds with a fresh Sanctuary rather than getting stuck. A
## version-too-new file (AC-11, already-implemented "downgrade blocked"
## behavior) is deliberately NOT treated as EC-5 corruption — the file
## itself is fine, just newer than this build supports, so it is left
## completely untouched, matching AC-11's own "save file is not modified."
## EC-3 (checkpoint exists on startup, implying a mid-mission crash) adds
## `has_pending_checkpoint()`/`restore_from_checkpoint()` — the two real
## choices `save-persistence.md`'s own Interface Requirements note names as
## Main Menu/Mission Select's UI responsibility to present, not this
## system's. Both `load_slot()` and `restore_from_checkpoint()` delete any
## pending checkpoint afterward ("the checkpoint is deleted after either
## choice"); `save_slot()` also now deletes it on an ordinary successful
## save, per Rule 5's own already-documented-but-previously-unimplemented
## "normal flow" cleanup ("when any post-mission save fires... the
## checkpoint file for that slot is deleted immediately after").
##
## This pass is backend only — no new Main Menu/UI dialog was built for
## EC-3's recovery choice or EC-5's player-facing warning. Both existing
## `load_slot()` call sites (Main Menu's Continue/Load Game) already ignore
## their return value, so this change is non-breaking there; wiring the
## actual recovery-choice/warning UI on top of this real API is a natural,
## separately-scoped follow-up.

const CURRENT_FORMAT_VERSION: int = 1
const SAVE_DIR: String = "user://saves/"
const SAVE_PATH: String = "user://saves/save_slot_%d.dat"
const TMP_PATH: String = "user://saves/save_slot_%d.tmp"
const CHECKPOINT_PATH: String = "user://saves/save_slot_%d_checkpoint.dat"
const CORRUPT_PATH: String = "user://saves/save_slot_%d.corrupt"
const AUTOSAVE_INTERVAL: float = 300.0

## Outcome of load_slot()/restore_from_checkpoint() — richer than a bool so
## a caller can distinguish "no save" from "a save exists but couldn't be
## used," and react differently to each (see class doc comment).
enum LoadResult {
	SUCCESS,
	NOT_FOUND,
	VERSION_TOO_NEW,       ## AC-11: file untouched, load aborted
	CORRUPT_RECOVERED,     ## EC-5: file renamed to .corrupt, all systems reset to defaults
	CHECKPOINT_CORRUPT,    ## EC-3 checkpoint-specific: checkpoint discarded, .dat is untouched and still loadable
}

enum _ReadFailureReason { VERSION_TOO_NEW, CORRUPT }

var _registered_systems: Array = []
var _active_slot: int = 0
var _autosave_timer: Timer

## Mid-session-restore fix (ADR-0003, 2026-07-18 revision). Caches the last
## successfully loaded master Dictionary so a SaveRestorer that registers
## AFTER load_slot() already ran (a scene-instanced system recreated on a
## Sanctuary<->Mission transition — Constellation, Crafting, Tarot, Equipment
## Forge, Tower Mastery) is still restored, instead of silently sitting at
## @export defaults for the rest of the session.
var _last_loaded_data: Dictionary = {}
var _has_loaded_data: bool = false

## TD-save-001 (fixed 2026-07-08): test-only injection seams forcing store_32()
## or store_var() to be treated as failed, without needing a full FileAccess
## mock (FileAccess's write methods are native/non-virtual and cannot be
## subclassed to fake a failure). Separate flags so each abort branch
## (AC-3) is independently testable. Production code never sets these.
var _force_store_32_failure: bool = false
var _force_store_var_failure: bool = false


func _ready() -> void:
	_ensure_save_dir()
	_cleanup_tmp_files()
	_setup_autosave_timer()
	GEventBus.mission_launched.connect(_on_mission_launched)
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)


func _exit_tree() -> void:
	GEventBus.mission_launched.disconnect(_on_mission_launched)
	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)


## restore_order registry (TD-hero-004, fixed 2026-07-08) — every system that
## calls register() below, listed here so a reviewer can check a new
## registration for collisions without grepping the whole codebase. ADR-0003's
## Decision Summary reserves the band: Foundation 0-9, Core 10-49, Feature 50+.
## Update this list whenever a new SaveRestorer implementor is added.
##
##   restore_order | System    | Layer      | Source
##   --------------|-----------|------------|----------------------------------
##   10            | Inventory | Core       | src/core/inventory/inventory.gd
##                 |           |            | (Story-001, ADR-0016) —
##                 |           |            | GSavePersistence.register(self, 10)
##   30            | Hero      | Core       | src/core/hero/hero.gd (Story-008,
##                 |           |            | ADR-0003) — GSavePersistence.register(self, 30)
##
## Inventory (restore_order=10) now runs before Hero (restore_order=30) during a
## restore pass, giving the first real cross-system verification of ADR-0003's
## "runs after Foundation, before Feature layer" / ascending-restore_order
## ordering claim — see tests/unit/save_persistence/save_persistence_restore_test.gd's
## ordering test for the general mechanism this relies on.

## Register a saveable system. Call from the system's _ready().
## If a save has already been loaded this session, the newly-registered
## system is immediately restored (or defaulted) from the cached data —
## see _restore_one() / ADR-0003's 2026-07-18 revision.
func register(system_ref: Object, restore_order: int) -> void:
	_registered_systems.append({
		"ref": system_ref,
		"key": system_ref.get_save_key(),
		"restore_order": restore_order,
	})
	if _has_loaded_data:
		_restore_one(system_ref)


## Unregister a system. Call from _exit_tree() to prevent stale refs.
func unregister(system_ref: Object) -> void:
	for i: int in range(_registered_systems.size() - 1, -1, -1):
		if _registered_systems[i].ref == system_ref:
			_registered_systems.remove_at(i)


## Switch which slot future save/load calls target.
func set_active_slot(slot: int) -> void:
	_active_slot = slot


## Real bug found and fixed 2026-08-08: Main Menu's New Game path called only
## set_active_slot() then transitioned straight to Sanctuary, never calling
## load_slot() (there's nothing to load — the slot is empty) and therefore
## never emitting sanctuary_state_restored. Every system gated on that signal
## (most visibly MissionSelect._restore_completed, which can_launch() checks
## before every real mission launch) stayed permanently false for the rest of
## the session — a New Game player could open Mission Select, pick a mission,
## press Confirm Launch, and nothing would happen, with no error and no
## feedback. Mirrors _recover_from_corrupt_save()'s already-tested "fresh
## Sanctuary" pattern (reset every registered system to its own defaults,
## then emit sanctuary_state_restored) instead of inventing a new one.
func start_new_game(slot: int) -> void:
	_active_slot = slot
	for entry in _registered_systems:
		entry.ref.reset_to_defaults()
	_emit_state_restored(slot)


## Serialise all registered systems and write slot to disk atomically.
## Emits GEventBus.game_saved on success. Rule 5: a successful save is the
## "normal flow" completing, so any pending checkpoint for this slot (a
## crash-recovery artifact only) is no longer needed and is deleted.
func save_slot(slot: int) -> bool:
	var data := _collect_save_data()
	var ok := _write_slot(slot, data)
	if ok:
		_delete_checkpoint_if_exists(slot)
		GEventBus.game_saved.emit(slot, Time.get_unix_time_from_system())
	return ok


## Write a mid-mission checkpoint in the same format, at a separate path.
func save_checkpoint(slot: int) -> bool:
	var data := _collect_save_data()
	return _write_checkpoint(slot, data)


## Read slot from disk and restore all registered systems in restore_order.
## Emits GEventBus.sanctuary_state_restored deferred 1 frame after restore
## loop (SUCCESS and CORRUPT_RECOVERED both emit it — CORRUPT_RECOVERED
## still ends with a real, restored [default] Sanctuary state, per EC-5).
## See class doc comment for the full LoadResult contract.
func load_slot(slot: int) -> LoadResult:
	var dat_path := SAVE_PATH % slot
	if not FileAccess.file_exists(dat_path):
		return LoadResult.NOT_FOUND
	var data := _read_slot(slot)
	if data.is_empty():
		if _classify_read_failure(dat_path) == _ReadFailureReason.VERSION_TOO_NEW:
			return LoadResult.VERSION_TOO_NEW  # AC-11: aborted, file left untouched
		_recover_from_corrupt_save(slot, dat_path)  # EC-5
		return LoadResult.CORRUPT_RECOVERED
	_active_slot = slot
	_restore_all_systems(data, slot)
	_delete_checkpoint_if_exists(slot)
	return LoadResult.SUCCESS


## EC-3: true when a mid-mission checkpoint exists for `slot` — under
## normal play a checkpoint is deleted the moment its slot is next saved
## (Rule 5) or its own recovery choice is resolved, so a checkpoint still
## present on startup means the game crashed mid-mission and never got the
## chance to clean it up. UI's own responsibility (per this GDD's Interface
## Requirements) to check this and present the EC-3 recovery choice.
func has_pending_checkpoint(slot: int) -> bool:
	return FileAccess.file_exists(CHECKPOINT_PATH % slot)


## EC-3's "Restore from checkpoint" choice. A corrupt checkpoint does NOT
## reset registered systems to defaults the way a corrupt main save does
## (EC-5) — the checkpoint is explicitly "advisory" (Rule 5) and a good
## save_slot_N.dat likely still exists, so the caller should fall back to
## load_slot() instead of losing the player's real progress over a bad
## crash-recovery artifact. The checkpoint is deleted regardless of outcome
## ("the checkpoint is deleted after either choice").
func restore_from_checkpoint(slot: int) -> LoadResult:
	var checkpoint_path: String = CHECKPOINT_PATH % slot
	if not FileAccess.file_exists(checkpoint_path):
		return LoadResult.NOT_FOUND
	var data := _read_checkpoint_file(slot)
	if data.is_empty():
		_delete_checkpoint_if_exists(slot)
		return LoadResult.CHECKPOINT_CORRUPT
	_active_slot = slot
	_restore_all_systems(data, slot)
	_delete_checkpoint_if_exists(slot)
	return LoadResult.SUCCESS


## EC-5: the main save file exists but its data could not be parsed. Rename
## it to `save_slot_N.corrupt` (preserved for debugging, matching the GDD's
## own wording — never silently deleted), reset every registered system to
## its own defaults, and still emit sanctuary_state_restored so the caller
## proceeds into a real (fresh) Sanctuary rather than a stuck/undefined
## state. This slot becomes the active slot going forward, matching "the
## game has started fresh" — the next real save will (correctly) overwrite
## the space the corrupt file used to occupy.
func _recover_from_corrupt_save(slot: int, dat_path: String) -> void:
	var corrupt_path: String = CORRUPT_PATH % slot
	var dir := DirAccess.open(SAVE_DIR)
	if dir != null:
		if FileAccess.file_exists(corrupt_path):
			dir.remove(corrupt_path)  # an older .corrupt from a prior crash — don't block the rename over it
		var err: Error = dir.rename(dat_path, corrupt_path)
		if err != OK:
			push_error("SavePersistence: failed to rename corrupt save '%s' -> '%s': %s" % [
					dat_path, corrupt_path, error_string(err)])
	for entry in _registered_systems:
		entry.ref.reset_to_defaults()
	_active_slot = slot
	_emit_state_restored(slot)


func _delete_checkpoint_if_exists(slot: int) -> void:
	var checkpoint_path: String = CHECKPOINT_PATH % slot
	if not FileAccess.file_exists(checkpoint_path):
		return
	var dir := DirAccess.open(SAVE_DIR)
	if dir != null:
		dir.remove(checkpoint_path)


# ---------------------------------------------------------------------------
# Initialisation helpers
# ---------------------------------------------------------------------------

func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _cleanup_tmp_files() -> void:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tmp"):
			var err: Error = dir.remove(fname)
			if err != OK:
				push_warning("SavePersistence: failed to remove tmp '%s': %s" % [fname, error_string(err)])
		fname = dir.get_next()
	dir.list_dir_end()


func _setup_autosave_timer() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL
	_autosave_timer.autostart = false
	_autosave_timer.one_shot = false
	_autosave_timer.paused = true
	_autosave_timer.timeout.connect(_on_autosave_timer_timeout)
	add_child(_autosave_timer)
	_autosave_timer.start()


# ---------------------------------------------------------------------------
# Serialisation
# ---------------------------------------------------------------------------

func _collect_save_data() -> Dictionary:
	var data: Dictionary = {}
	for entry in _registered_systems:
		data[entry.key] = entry.ref.get_save_data()
	return data


func _restore_all_systems(data: Dictionary, slot: int) -> void:
	_last_loaded_data = data
	_has_loaded_data = true
	var sorted: Array = _registered_systems.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.restore_order < b.restore_order
	)
	for entry in sorted:
		_restore_one(entry.ref)
	_emit_state_restored(slot)


## Restores a single system from the cached _last_loaded_data. Shared by both
## the initial full-load pass (_restore_all_systems) and late registration
## (register(), above) so the two code paths can never drift out of sync.
func _restore_one(system_ref: Object) -> void:
	var key: String = system_ref.get_save_key()
	var sys_data: Dictionary = _last_loaded_data.get(key, {})
	if sys_data.is_empty():
		system_ref.reset_to_defaults()
		return
	if not system_ref.restore_save_data(sys_data):
		push_error("SavePersistence: restore failed for '%s' — calling reset_to_defaults()" % key)
		system_ref.reset_to_defaults()


## Overridable seam for unit tests — subclass stubs this to avoid EventBus dependency.
func _emit_state_restored(slot: int) -> void:
	GEventBus.sanctuary_state_restored.emit.call_deferred(slot)


# ---------------------------------------------------------------------------
# File I/O
# ---------------------------------------------------------------------------

func _write_slot(slot: int, data: Dictionary) -> bool:
	var tmp_path := TMP_PATH % slot
	var dat_path := SAVE_PATH % slot
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SavePersistence: cannot open '%s' for write" % tmp_path)
		return false
	if _force_store_32_failure or not file.store_32(CURRENT_FORMAT_VERSION):
		push_error("SavePersistence: failed to write version header to '%s'" % tmp_path)
		file.close()
		return false
	if _force_store_var_failure or not file.store_var(data, false):
		push_error("SavePersistence: failed to write data to '%s'" % tmp_path)
		file.close()
		return false
	file.close()
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null or not dir.rename(tmp_path, dat_path) == OK:
		push_error("SavePersistence: atomic rename '%s' → '%s' failed" % [tmp_path, dat_path])
		return false
	return true


func _write_checkpoint(slot: int, data: Dictionary) -> bool:
	var path := CHECKPOINT_PATH % slot
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SavePersistence: cannot open checkpoint '%s' for write" % path)
		return false
	if _force_store_32_failure or not file.store_32(CURRENT_FORMAT_VERSION):
		push_error("SavePersistence: failed to write checkpoint version header")
		file.close()
		return false
	if _force_store_var_failure or not file.store_var(data, false):
		push_error("SavePersistence: failed to write checkpoint data")
		file.close()
		return false
	file.close()
	return true


func _read_slot(slot: int) -> Dictionary:
	return _read_save_file(SAVE_PATH % slot)


func _read_checkpoint_file(slot: int) -> Dictionary:
	return _read_save_file(CHECKPOINT_PATH % slot)


## Shared by _read_slot()/_read_checkpoint_file() — identical format, only
## the path differs. _read_slot()'s own signature/behavior (empty
## Dictionary on any failure) is preserved exactly for its existing direct
## unit-test coverage in save_persistence_write_test.gd.
func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var format_version: int = file.get_32()
	if format_version > CURRENT_FORMAT_VERSION:
		push_error("SavePersistence: version %d > current %d — cannot load '%s'" % [format_version, CURRENT_FORMAT_VERSION, path])
		file.close()
		return {}
	var data: Variant = file.get_var(false)
	file.close()
	if not data is Dictionary:
		push_error("SavePersistence: save data is not a Dictionary — corrupt file '%s'" % path)
		return {}
	if format_version < CURRENT_FORMAT_VERSION:
		data = _migrate(data, format_version)
	return data


## Re-checks a file _read_save_file() already reported empty for, to tell
## load_slot() whether that empty result meant "version too new" (AC-11 —
## leave the file alone) or genuine corruption (EC-5 — recover from it).
## A second file open is a deliberate, cheap tradeoff to keep
## _read_save_file()'s own contract (and its existing test coverage)
## completely untouched rather than threading a reason code through it.
func _classify_read_failure(path: String) -> _ReadFailureReason:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _ReadFailureReason.CORRUPT
	var format_version: int = file.get_32()
	file.close()
	if format_version > CURRENT_FORMAT_VERSION:
		return _ReadFailureReason.VERSION_TOO_NEW
	return _ReadFailureReason.CORRUPT


# ---------------------------------------------------------------------------
# Migration
# ---------------------------------------------------------------------------

func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	var current: Dictionary = data
	for v: int in range(from_version, CURRENT_FORMAT_VERSION):
		current = _migrate_step(current, v)
	return current


func _migrate_step(data: Dictionary, from_version: int) -> Dictionary:
	match from_version:
		_:
			push_error("SavePersistence: no migration path from version %d" % from_version)
			return data


# ---------------------------------------------------------------------------
# EventBus handlers
# ---------------------------------------------------------------------------

func _on_mission_launched(_mission_id: String, _modifiers: PackedStringArray, _difficulty_tier: int) -> void:
	save_checkpoint(_active_slot)


func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	if new_phase == "SANCTUARY":
		_autosave_timer.paused = false
		save_slot(_active_slot)
	else:
		_autosave_timer.paused = true


func _on_autosave_timer_timeout() -> void:
	save_slot(_active_slot)
