# S2-02 — Save & Persistence Autoload Implementation

**Story ID**: S2-02
**Epic**: Foundation
**Layer**: Foundation
**Type**: Integration
**Owner**: godot-gdscript-specialist
**Sprint**: 2
**Estimate**: 1.5 days
**Status**: Complete
**Manifest Version**: 2026-05-16

## TR Coverage

| TR-ID | Requirement |
|-------|-------------|
| TR-save-001 | 3 save slots; atomic write (.tmp → .dat) |
| TR-save-002 | FileAccess bool return check (Godot 4.4+ MEDIUM risk) |
| TR-save-003 | Restore order 10–33; sanctuary_state_restored deferred 1 frame |
| TR-save-004 | Format version + migration registry |
| TR-save-005 | Save format: store_32 header + store_var master Dictionary |
| TR-save-006 | 4 auto-save triggers via EventBus |

## ADR Governing Implementation

`docs/architecture/adr-0003-save-file-format.md` (Accepted 2026-05-16)

## Dependencies

- S2-01 EventBus Autoload — Complete (2026-05-25)

## Files to Create / Modify

- `src/foundation/save_persistence/save_persistence.gd` — create (SavePersistence Autoload)

## Test Evidence

- `tests/unit/save_persistence/save_persistence_write_test.gd` — write / read / atomic rename / cleanup
- `tests/unit/save_persistence/save_persistence_restore_test.gd` — restore order / deferred emit / fallback

## Acceptance Criteria

- [ ] Atomic `.tmp→.dat` write succeeds; previous `.dat` intact on write failure (GDD AC-5, TR-save-001)
- [ ] 3 save slots; paths follow `user://saves/save_slot_N.dat` (GDD Formula 1)
- [ ] Every `store_32()` and `store_var()` call checks its `bool` return; write aborts on `false` (TR-save-002)
- [ ] `store_var(data, false)` enforced — `full_objects = false` always (ADR-0003)
- [ ] `format_version` written first via `store_32(CURRENT_FORMAT_VERSION)` (TR-save-005)
- [ ] `_read_slot()` reads version header first: version > CURRENT → error + `{}`; version < CURRENT → `_migrate()` (GDD AC-11)
- [ ] Registered systems restored in ascending `restore_order` (Inventory=10 before EquipmentForge=32) (GDD AC-6, TR-save-003)
- [ ] `sanctuary_state_restored` deferred exactly 1 frame after restore loop completes (GDD AC-8, TR-save-003)
- [ ] `_ready()` scans `user://saves/` for `.tmp` files and deletes them (ADR-0003, GDD EC-2)
- [ ] `register(system_ref: Object, restore_order: int)` API implemented (GDD Core Rule 3)
- [ ] `restore_save_data(data: Dictionary) -> bool` — systems return `false` on failure; S&P calls `reset_to_defaults()` on that system (design decision: bool over void for testability) (GDD AC-7)
- [ ] Subscribes to `mission_launched` (checkpoint write) and `mission_phase_changed` (post-mission save + autosave gating) via EventBus (TR-save-006)
- [ ] Autosave timer implemented as a child `Timer` node; `timer.paused = true` outside SANCTUARY phase; interval = 300.0 s (GDD AC-9, design decision: Timer node over _process() accumulator)
- [ ] `_migrate()` chains `_migrate_step()` from `from_version` to `CURRENT_FORMAT_VERSION` (TR-save-004)
- [ ] `saves/` subdirectory created on `_ready()` if absent (GDD Formula 1 note)
- [ ] Unit tests: ≥8 tests pass across `tests/unit/save_persistence/`

## Implementation Notes (from ADR-0003)

### Constants
```gdscript
const CURRENT_FORMAT_VERSION: int = 1
const SAVE_DIR     := "user://saves/"
const SAVE_PATH    := "user://saves/save_slot_%d.dat"
const TMP_PATH     := "user://saves/save_slot_%d.tmp"
const CHECKPOINT_PATH := "user://saves/save_slot_%d_checkpoint.dat"
```

### Write Pattern (every store_* must check bool return)
```gdscript
func _write_slot(slot: int, data: Dictionary) -> bool:
    var tmp_path := TMP_PATH % slot
    var dat_path := SAVE_PATH % slot
    var file := FileAccess.open(tmp_path, FileAccess.WRITE)
    if file == null:
        push_error("SavePersistence: cannot open %s for write" % tmp_path)
        return false
    if not file.store_32(CURRENT_FORMAT_VERSION):
        push_error("SavePersistence: failed to write version header")
        file.close()
        return false
    if not file.store_var(data, false):
        push_error("SavePersistence: failed to write save data")
        file.close()
        return false
    file.close()
    var dir := DirAccess.open(SAVE_DIR)
    if dir == null or not dir.rename(tmp_path, dat_path) == OK:
        push_error("SavePersistence: atomic rename failed")
        return false
    return true
```

### Read Pattern
```gdscript
func _read_slot(slot: int) -> Dictionary:
    var dat_path := SAVE_PATH % slot
    if not FileAccess.file_exists(dat_path):
        return {}
    var file := FileAccess.open(dat_path, FileAccess.READ)
    if file == null:
        return {}
    var format_version: int = file.get_32()
    if format_version > CURRENT_FORMAT_VERSION:
        push_error("SavePersistence: version %d > current %d" % [format_version, CURRENT_FORMAT_VERSION])
        file.close()
        return {}
    var data: Variant = file.get_var(false)
    file.close()
    if not data is Dictionary:
        push_error("SavePersistence: data is not a Dictionary — corrupt file")
        return {}
    if format_version < CURRENT_FORMAT_VERSION:
        data = _migrate(data, format_version)
    return data
```

### Migration Scaffold
```gdscript
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
    var current := data
    for v: int in range(from_version, CURRENT_FORMAT_VERSION):
        current = _migrate_step(current, v)
    return current

func _migrate_step(data: Dictionary, from_version: int) -> Dictionary:
    match from_version:
        _:
            push_error("SavePersistence: no migration path from version %d" % from_version)
            return data
```

### Restore Loop
```gdscript
# After sorting registered systems by restore_order ascending:
for entry in _registered_systems:
    var sys_data: Dictionary = data.get(entry.key, {})
    if sys_data.is_empty():
        entry.ref.reset_to_defaults()
        continue
    if not entry.ref.restore_save_data(sys_data):
        push_error("SavePersistence: restore failed for %s" % entry.key)
        entry.ref.reset_to_defaults()
# Deferred emit — 1 frame after all restore_save_data() calls:
EventBus.sanctuary_state_restored.emit.call_deferred(slot)
```

### GDD vs ADR Path Note
> GDD Formula 1 specifies `user://saves/` subdirectory; ADR-0003 code sketch omits it.
> Follow the GDD (more explicit): use `user://saves/`. Create the directory in `_ready()`.

## Out of Scope

- No implementations of `get_save_data()` / `restore_save_data()` / `reset_to_defaults()` in dependent systems (each system's own story)
- No save slot selection UI (Mission Select UI story)
- No checkpoint recovery choice dialog (Main Menu story)
- No save encryption (GDD OQ-2 deferred)
- No primitive-only validation GUT test (ADR-0003 follow-up story)
- No `_migrate_v1_to_v2()` — CURRENT_FORMAT_VERSION = 1; no v0 files exist at launch
- No `save_slot_count` tuning knob UI exposure (GDD Tuning Knobs — data-driven constant only)

## Completion Notes
**Completed**: 2026-05-25
**Criteria**: 14/16 verified (2 advisory — see below)
**Deviations**:
- `unregister()` method added beyond story scope — useful cleanup helper, no functional harm
- AC-3 (store_*/abort path) untestable without FileAccess DI seam — logic verified by code inspection
- AC-8 (deferred emit timing), AC-10 (`register()` API direct test), AC-12 (EventBus signal wiring) have no automated tests — logged as tech debt TD-save-001
**Test Evidence**: `tests/unit/save_persistence/save_persistence_write_test.gd` (8 tests), `tests/unit/save_persistence/save_persistence_restore_test.gd` (6 tests) — 14 total
**Code Review**: Complete — 4 required changes fixed (dir.remove error check, timer signal ordering, ordering test assertion, EventBus stub seam)
