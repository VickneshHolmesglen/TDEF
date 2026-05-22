# ADR-0003: Save File Format

## Status
Accepted

## Date
2026-05-16

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / Save & Persistence |
| **Knowledge Risk** | MEDIUM — `FileAccess.store_var()`, `store_32()`, and all `store_*` methods changed return type from `void` to `bool` in Godot 4.4. Every call must check its return value. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | `FileAccess.store_32()` (return bool — Godot 4.4+), `FileAccess.store_var()` (return bool — Godot 4.4+) |
| **Verification Required** | Verify `store_32()` and `store_var(data, false)` both return `true` on a valid write. Verify `get_32()` and `get_var(false)` behave correctly on the subsequent read. Verify `DirAccess.rename()` atomically replaces the .dat file with the .tmp file on Windows and Linux. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus — SavePersistence subscribes to auto-save triggers via EventBus); ADR-0002 (Scene/Autoload structure — SavePersistence is Autoload #2, boots before Grid and Pathfinding) |
| **Enables** | All Save & Persistence implementation stories; ADR-0009 (Resource data model — primitive-only serialisation rule constrains how Resources expose save data) |
| **Blocks** | Save & Persistence implementation stories cannot begin until this format is fixed — format changes after any story is implemented require migration work. |
| **Ordering Note** | Must be Accepted before any system implements `get_save_data()` or `apply_save_data()`. The primitive-only rule constrains every system's serialisation interface. |

## Context

### Problem Statement
Sanctuary Defenders must persist hero progression, inventory, tower builds, menagerie state, and mission unlock data across sessions in up to 3 save slots. The save format must survive game updates (schema migration), be resilient to mid-write crashes (atomic write), and integrate with Godot's `FileAccess` API as it stands in Godot 4.6. The game's GDD mandates atomic write (.tmp → rename to .dat) but defers the specific format decision to this ADR.

### Constraints
- `FileAccess.store_*` methods return `bool` in Godot 4.4+ (was `void` pre-4.4). Every write call must check the return value or data corruption goes undetected.
- Save state is structured (10 system keys), not flat — a key-value store format would require artificial namespacing.
- The save format must support forward migration: version N saves must be loadable and automatically upgraded by version N+1 code.
- No external serialisation libraries are approved. Only built-in Godot APIs.
- Resource objects must not be embedded directly in serialised data — script paths embedded by `store_var(resource, true)` break if source files are renamed or moved during development.

### Requirements
- Version header stored separately from game data so that migration can occur before data is parsed.
- All 10 MVP systems can expose their state via a `get_save_data() -> Dictionary` method returning only primitives.
- Save completes atomically: a crash mid-write cannot produce a half-written .dat file.
- A corrupted or version-mismatched file produces a clear error — no silent data loss or crash.
- Checkpoint saves (mid-mission) use the same format, stored at a separate path.

## Decision

### Format: `store_32()` version header + `store_var()` master Dictionary

The save file consists of two sequential segments:

1. **Version header** (4 bytes): `store_32(CURRENT_FORMAT_VERSION)` — written first. Allows migration detection before any game data is parsed.
2. **Master Dictionary** (variable length): `store_var(data, false)` — the full game state as a nested Dictionary. `full_objects = false` prevents Resource script paths from being embedded.

### Master Dictionary Structure

```gdscript
const CURRENT_FORMAT_VERSION: int = 1

# Top-level keys — one per saveable system
{
    "hero":              {},   # HeroSystem.get_save_data()
    "tower":             {},   # TowerSystem.get_save_data()
    "inventory":         {},   # InventorySystem.get_save_data()
    "menagerie":         {},   # MenagerieSystem.get_save_data()
    "defense_building":  {},   # DefenseBuildingSystem.get_save_data()
    "tarot":             {},   # TarotSystem.get_save_data() (future)
    "mission_select":    {},   # MissionSelectSystem.get_save_data()
    "hero_skill_build":  {},   # HeroSkillBuild.get_save_data() (future)
    "equipment_forge":   {},   # EquipmentForge.get_save_data() (future)
    "encyclopedia":      {},   # Encyclopedia.get_save_data() (future)
}
```

Systems not yet implemented return an empty Dictionary from `get_save_data()` and are silently skipped in `apply_save_data()`.

### Primitive-Only Rule

Every system's `get_save_data()` must return a Dictionary containing only these GDScript types:

- `int`, `float`, `bool`, `String`
- `Array` (elements must also be primitive)
- `Dictionary` (keys must be `String`; values must be primitive)

**Forbidden in save data:**
- `Resource` or any Resource subclass (embed script paths break on rename)
- `Vector2i`, `Vector2`, `Vector3` (use `[int, int]` or `[float, float, float]` Array instead)
- `Color` (use `[float, float, float, float]` Array instead)
- `NodePath`, `Object` references of any kind

This rule is enforced by code review. A future ADR or tooling addition may add a GUT test that calls `get_save_data()` on each registered system and validates all values are primitives.

### Write Implementation

```gdscript
const SAVE_PATH := "user://save_slot_%d.dat"
const TMP_PATH  := "user://save_slot_%d.tmp"

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

    # Atomic rename: .tmp → .dat
    var dir := DirAccess.open("user://")
    if dir == null or not dir.rename(tmp_path, dat_path) == OK:
        push_error("SavePersistence: atomic rename failed")
        return false

    return true
```

### Read Implementation

```gdscript
func _read_slot(slot: int) -> Dictionary:
    var dat_path := SAVE_PATH % slot

    if not FileAccess.file_exists(dat_path):
        return {}   # No save — caller treats as new game

    var file := FileAccess.open(dat_path, FileAccess.READ)
    if file == null:
        push_error("SavePersistence: cannot open %s for read" % dat_path)
        return {}

    var format_version: int = file.get_32()

    if format_version > CURRENT_FORMAT_VERSION:
        push_error("SavePersistence: save file version %d is newer than engine version %d — aborting load" % [format_version, CURRENT_FORMAT_VERSION])
        file.close()
        return {}

    var data: Variant = file.get_var(false)
    file.close()

    if not data is Dictionary:
        push_error("SavePersistence: save data is not a Dictionary — file may be corrupt")
        return {}

    if format_version < CURRENT_FORMAT_VERSION:
        data = _migrate(data, format_version)

    return data
```

### Migration Strategy

```gdscript
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
    var current := data
    for v in range(from_version, CURRENT_FORMAT_VERSION):
        current = _migrate_step(current, v)
    return current

func _migrate_step(data: Dictionary, from_version: int) -> Dictionary:
    match from_version:
        1:
            return _migrate_v1_to_v2(data)
        _:
            push_error("SavePersistence: no migration path from version %d" % from_version)
            return data
```

Each `_migrate_vN_to_vN+1()` function transforms the Dictionary structure from one schema to the next. Migrations are append-only — they never delete keys (mark unused keys with a `_deprecated_` prefix if needed). Migration unit tests are **required by coding standards** for every version increment.

### File Paths

| File | Purpose |
|------|---------|
| `user://save_slot_N.dat` | Primary save file for slot N (N = 0, 1, 2) |
| `user://save_slot_N.tmp` | Intermediate write target — renamed to .dat on success |
| `user://save_slot_N_checkpoint.dat` | Mid-mission checkpoint (same format, separate path) |

**Startup cleanup**: On `_ready()`, SavePersistence scans `user://` for any `.tmp` files and deletes them. A .tmp file surviving to the next launch means a crash occurred mid-write — the .dat (if it exists) is the last good save.

## Architecture Diagram

```
SAVE TRIGGER (EventBus: save_requested or auto_save_triggered)
  │
  ▼ SavePersistence._collect_save_data()
  ┌─────────────────────────────────┐
  │  call get_save_data() on each   │
  │  registered system              │
  │  → assemble master Dictionary   │
  └────────────┬────────────────────┘
               │
               ▼ _write_slot(slot, data)
  ┌─────────────────────────────────┐
  │  FileAccess.open(.tmp, WRITE)   │
  │  store_32(CURRENT_FORMAT_VER)   │  ← check bool return
  │  store_var(data, false)         │  ← check bool return
  │  file.close()                   │
  │  DirAccess.rename(.tmp → .dat)  │  ← atomic, crash-safe
  └─────────────────────────────────┘

LOAD TRIGGER (boot / slot selected)
  │
  ▼ SavePersistence._read_slot(slot)
  ┌─────────────────────────────────┐
  │  FileAccess.open(.dat, READ)    │
  │  get_32() → format_version      │
  │  if version > CURRENT → abort   │
  │  get_var(false) → Dictionary    │
  │  if version < CURRENT → migrate │
  └────────────┬────────────────────┘
               │
               ▼ call apply_save_data(data[key]) on each system
```

## Alternatives Considered

### Alternative A: JSON (FileAccess.store_string with JSON.stringify)
- **Description**: Serialize the master Dictionary to JSON text and write as a UTF-8 string.
- **Pros**: Human-readable for debugging; diff-friendly in version control for test fixtures.
- **Cons**: JSON requires custom serializers for non-JSON types (Vector2i, Color, enums mapped to int). GDScript's `JSON.stringify()` silently drops non-serializable values. Larger file size than binary. Slower parse time for large inventories.
- **Rejection Reason**: The primitive-only rule eliminates the human-readability advantage. `store_var()` handles nested Dictionaries and Arrays natively without serializer boilerplate. JSON error reporting is worse than `get_var()` type checking.

### Alternative B: ConfigFile (.cfg key-value store)
- **Description**: Use Godot's `ConfigFile` API, with one section per system and one key per data field.
- **Pros**: Built-in Godot API; human-readable; no version header needed (metadata section possible).
- **Cons**: ConfigFile is a flat key-value store — nested data (inventory item lists, monster menagerie entries) requires manual flattening or JSON-encoding values. Produces excessive key proliferation for complex save data. No built-in atomic write.
- **Rejection Reason**: The master Dictionary's nested structure cannot be expressed naturally as flat key-value sections without significant boilerplate. `store_var()` handles nesting natively.

### Alternative C: Custom binary packing (PackedByteArray)
- **Description**: Manually serialize each field using `encode_u32()`, `encode_float()`, `encode_utf8()` into a PackedByteArray, then write with `store_buffer()`.
- **Pros**: Smallest possible file size; maximum control over format; no Godot-internal format dependency.
- **Cons**: Requires a hand-written encode/decode pair for every field in every system. Schema changes require careful offset management. Significant implementation cost for a save system that is not performance-critical.
- **Rejection Reason**: Over-engineered for this project's scale. Save file I/O is not on the critical path — it happens on explicit triggers, not per-frame. `store_var()` binary format is compact and requires no manual encoding.

## Consequences

### Positive
- Single-call `store_var()` handles all nested Dictionaries and Arrays — no per-field serialization code.
- Version header is 4 bytes, read before any game data — migration detection is trivial.
- Atomic .tmp → .dat rename prevents half-written save files from corrupting the slot.
- `full_objects = false` prevents script-path embedding — the format is not broken by file renames.
- The primitive-only rule makes every system's `get_save_data()` output independently testable.

### Negative
- The `store_var()` binary format is Godot-internal and version-coupled — loading a 4.6 save file in a hypothetical Godot 5 port would require a dedicated export/import step, not raw file access.
- Every system must implement `get_save_data()` and `apply_save_data()` — no automatic serialisation of properties.
- Bool return checks on every `store_*` call add verbosity to the write function.

### Risks
- **Risk**: A developer embeds a Resource object in `get_save_data()` output. `store_var(data, false)` will silently drop the Resource or store a null. **Mitigation**: Primitive-only rule documented in this ADR and in coding standards. GUT test mandated (required per `coding-standards.md`).
- **Risk**: `DirAccess.rename()` on Windows fails if the .dat file is open by another process (e.g., cloud sync). **Mitigation**: Log the error; surface to player as "Save failed — close any file-syncing apps". Do not retry silently.
- **Risk**: A migration function has a bug that corrupts data on upgrade. **Mitigation**: Migration unit tests are BLOCKING per coding standards — a migration function without a passing test cannot be merged.
- **Risk**: Godot's internal `store_var()` binary format changes between minor versions. **Mitigation**: Format version header allows detection. If the format changes, a new migration step decodes old binary and re-encodes in the new format.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| save-persistence.md | Atomic write: .tmp → rename to .dat | Write implementation uses DirAccess.rename() as the final step |
| save-persistence.md | 3 save slots | File path template: `user://save_slot_N.dat` for N = 0, 1, 2 |
| save-persistence.md | Format version in file header | store_32(CURRENT_FORMAT_VERSION) as first 4 bytes |
| save-persistence.md | Migration: version N loads in version N+1 | _migrate() chains sequential _migrate_vN_to_vN+1() functions |
| save-persistence.md | Checkpoint save (mid-mission) | `user://save_slot_N_checkpoint.dat` uses same format at separate path |
| save-persistence.md | Auto-save on EventBus trigger | SavePersistence subscribes to `save_requested` via EventBus (ADR-0001) |

**Technical Requirements covered**: TR-save-001, TR-save-002, TR-save-003, TR-save-004, TR-save-005, TR-save-006

## Performance Implications
- **CPU**: `store_var()` serialisation is synchronous but not per-frame — acceptable for a triggered save. For large inventories (100+ items), profiling may reveal a need for async write in a future ADR.
- **Memory**: The master Dictionary is assembled in memory before write — peak allocation is the full save state. Estimated < 1 MB for MVP scope.
- **Load Time**: `get_var()` deserialisation is synchronous at boot — save data is loaded before the first scene. For MVP scope, negligible.
- **Network**: Not applicable (single-player only).

## Migration Plan
Greenfield project. `CURRENT_FORMAT_VERSION = 1` at launch. No version 0 files exist — the migration switch statement's first case handles v1→v2 (not yet needed). The `_migrate_step()` function is written defensively to log an error for unknown version numbers rather than silently corrupting data.

## Validation Criteria
- [ ] `store_32(CURRENT_FORMAT_VERSION)` returns `true` on a writable path.
- [ ] `store_var(data, false)` correctly round-trips a nested Dictionary containing int, float, bool, String, Array, and Dictionary values.
- [ ] A save written to .tmp and renamed to .dat produces a readable .dat file on the next `_read_slot()` call.
- [ ] A .tmp file left on disk at startup is deleted by `SavePersistence._ready()` cleanup.
- [ ] A save file with `format_version > CURRENT_FORMAT_VERSION` produces a logged error and returns `{}` — no crash.
- [ ] A save file with `format_version < CURRENT_FORMAT_VERSION` is successfully migrated by `_migrate()` — verified by unit test. **(BLOCKING — coding standards mandate migration unit test)**
- [ ] A system returning a Resource object in `get_save_data()` is caught by the GUT primitive-only validation test. **(BLOCKING)**

## Related Decisions
- ADR-0001 — EventBus architecture (SavePersistence subscribes to `save_requested` trigger)
- ADR-0002 — Scene and Autoload structure (SavePersistence is Autoload #2 — boots before Grid/Pathfinding, after EventBus)
- ADR-0009 — Resource data model (primitive-only rule constrains how Resources expose their state via `get_save_data()`)
- `design/gdd/save-persistence.md` — canonical GDD for Save & Persistence system
