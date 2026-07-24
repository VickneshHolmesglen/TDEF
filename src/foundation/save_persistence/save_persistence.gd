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

const CURRENT_FORMAT_VERSION: int = 1
const SAVE_DIR: String = "user://saves/"
const SAVE_PATH: String = "user://saves/save_slot_%d.dat"
const TMP_PATH: String = "user://saves/save_slot_%d.tmp"
const CHECKPOINT_PATH: String = "user://saves/save_slot_%d_checkpoint.dat"
const AUTOSAVE_INTERVAL: float = 300.0

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


## Serialise all registered systems and write slot to disk atomically.
## Emits GEventBus.game_saved on success.
func save_slot(slot: int) -> bool:
	var data := _collect_save_data()
	var ok := _write_slot(slot, data)
	if ok:
		GEventBus.game_saved.emit(slot, Time.get_unix_time_from_system())
	return ok


## Write a mid-mission checkpoint in the same format, at a separate path.
func save_checkpoint(slot: int) -> bool:
	var data := _collect_save_data()
	return _write_checkpoint(slot, data)


## Read slot from disk and restore all registered systems in restore_order.
## Emits GEventBus.sanctuary_state_restored deferred 1 frame after restore loop.
## Returns false if the file is absent or corrupt.
func load_slot(slot: int) -> bool:
	var data := _read_slot(slot)
	if data.is_empty():
		return false
	_active_slot = slot
	_restore_all_systems(data, slot)
	return true


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
	var dat_path := SAVE_PATH % slot
	if not FileAccess.file_exists(dat_path):
		return {}
	var file := FileAccess.open(dat_path, FileAccess.READ)
	if file == null:
		return {}
	var format_version: int = file.get_32()
	if format_version > CURRENT_FORMAT_VERSION:
		push_error("SavePersistence: version %d > current %d — cannot load '%s'" % [format_version, CURRENT_FORMAT_VERSION, dat_path])
		file.close()
		return {}
	var data: Variant = file.get_var(false)
	file.close()
	if not data is Dictionary:
		push_error("SavePersistence: save data is not a Dictionary — corrupt file '%s'" % dat_path)
		return {}
	if format_version < CURRENT_FORMAT_VERSION:
		data = _migrate(data, format_version)
	return data


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
