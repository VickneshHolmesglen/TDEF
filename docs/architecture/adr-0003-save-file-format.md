# ADR-0003: Save File Format

## Status
Accepted

## Date
2026-05-16

> **Revised 2026-07-13** — resolves the BLOCKING "SaveRestorer interface drift" conflict
> found by `/architecture-review` (`docs/architecture/architecture-review-2026-07-13b.md`).
> This ADR originally specified `get_save_data() -> Dictionary` + `apply_save_data(data[key])`
> against a static, hardcoded master-Dictionary key list. ADR-0010 (Hero), ADR-0016
> (Inventory), and ADR-0017 (Resource Economy) — plus the already-shipped
> `src/foundation/save_persistence/save_persistence.gd` autoload — were all written
> against a different interface (`get_save_key()` / `restore_save_data()` /
> `reset_to_defaults()` / `register(self, restore_order)`) that this ADR never defined,
> with ADR-0016 incorrectly citing it as "the already-Accepted SaveRestorer pattern
> (ADR-0003)". The Decision section below is corrected to document the interface that
> was actually built and that every consuming ADR actually depends on. No behavioral
> change to shipped code — this revision brings the ADR's text in line with reality.

> **Revised 2026-07-18** — resolves the project-wide **mid-session-restore gap**
> flagged by ADR-0029's godot-specialist review and confirmed against 5 scene-instanced
> systems in `docs/registry/architecture.yaml` (Constellation, Crafting, Tarot,
> Equipment Forge, Tower Mastery — all `MissionScene`/`SanctuaryScene` children,
> destroyed and recreated on every scene transition). Previously, `_restore_all_systems()`
> only ran once, at `load_slot()` time, against whatever was registered *at that instant*
> — a `SaveRestorer` that registers later in the same play session (because its owning
> scene was just reloaded) was never restored at all; its data silently stayed at
> `@export` defaults for the rest of the session, even though a save had already been
> loaded. This revision adds a cached-restore path: `SavePersistence` remembers the last
> successfully loaded master Dictionary, and `register()` immediately restores (or
> defaults) any system that registers after that point — no new Autoload
> reclassifications, no re-running the full restore pass, no new EventBus event. Unblocks
> the persistence-dependent stories flagged against this gap in Epics 05–08.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / Save & Persistence |
| **Knowledge Risk** | MEDIUM — `FileAccess.store_var()`, `store_32()`, and all `store_*` methods changed return type from `void` to `bool` in Godot 4.4. Every call must check its return value. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | `FileAccess.store_32()` (return bool — Godot 4.4+), `FileAccess.store_var()` (return bool — Godot 4.4+) |
| **Verification Required** | ~~Verify `store_32()` and `store_var(data, false)` both return `true` on a valid write. Verify `get_32()` and `get_var(false)` behave correctly on the subsequent read. Verify `DirAccess.rename()` atomically replaces the .dat file with the .tmp file on Windows and Linux.~~ **VERIFIED 2026-07-13** — live smoke test via MCP `run_script` against the actual pinned Godot 4.6.2.stable.official.71f334935 binary. Registered a test `SaveRestorer`, called `GSavePersistence.save_slot()` then `load_slot()` on an unused slot: `save_ok=true`, `.dat` written, `.tmp` correctly absent afterward (atomic rename via `DirAccess.rename()` confirmed), `load_ok=true`, restored data byte-identical to what was saved (nested Dictionary/Array/bool/float round-tripped through `store_var`/`get_var` correctly), no spurious `reset_to_defaults()` fallback triggered, zero runtime warnings/errors. `bool`-return semantics for `store_32()`/`store_var()` behave exactly as the shipped code assumes. Test artifact (`save_slot_9.dat`) removed after verification — no residual state left in the project's real save slots (0–2). ~~Verify the 2026-07-18 late-registration fix (`_last_loaded_data` cache) restores a system that registers after `load_slot()`, restores it identically across repeated unregister/register cycles, and falls back to `reset_to_defaults()` for a missing key.~~ **VERIFIED 2026-07-18** — live `run_script` against the real shipped `save_persistence.gd`: late registration, repeated re-registration, and missing-key fallback all confirmed correct; pre-existing restore-ordering/failure-fallback behavior re-verified with no regressions. This same live-verification pass also surfaced and fixed an unrelated, project-wide environment issue (stale `.godot/global_script_class_cache.cfg` blocking the entire project from booting) — see `docs/engine-reference/godot/VERSION.md` and `.claude/docs/context-management.md`. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus — SavePersistence subscribes to auto-save triggers via EventBus); ADR-0002 (Scene/Autoload structure — SavePersistence is Autoload #2, boots before Grid and Pathfinding) |
| **Enables** | All Save & Persistence implementation stories; ADR-0009 (Resource data model — primitive-only serialisation rule constrains how Resources expose save data); ADR-0010 (Hero), ADR-0016 (Inventory), ADR-0017 (Resource Economy) — all three register against the `SaveRestorer` interface this ADR now formally defines |
| **Blocks** | Save & Persistence implementation stories cannot begin until this format is fixed — format changes after any story is implemented require migration work. |
| **Ordering Note** | Must be Accepted before any system implements `get_save_key()`, `get_save_data()`, `restore_save_data()`, or `reset_to_defaults()`. The primitive-only rule constrains every system's serialisation interface. `restore_order` bands: Foundation 0–9, Core 10–49, Feature 50+ — a system registering must pick an order consistent with its dependency layer (see Decision). |

## Context

### Problem Statement
Sanctuary Defenders must persist hero progression, inventory, tower builds, menagerie state, and mission unlock data across sessions in up to 3 save slots. The save format must survive game updates (schema migration), be resilient to mid-write crashes (atomic write), and integrate with Godot's `FileAccess` API as it stands in Godot 4.6. The game's GDD mandates atomic write (.tmp → rename to .dat) but defers the specific format decision to this ADR.

### Constraints
- `FileAccess.store_*` methods return `bool` in Godot 4.4+ (was `void` pre-4.4). Every write call must check the return value or data corruption goes undetected.
- Save state is structured (one entry per registered system), not flat — a key-value store format would require artificial namespacing.
- The save format must support forward migration: version N saves must be loadable and automatically upgraded by version N+1 code.
- No external serialisation libraries are approved. Only built-in Godot APIs.
- Resource objects must not be embedded directly in serialised data — script paths embedded by `store_var(resource, true)` break if source files are renamed or moved during development.
- The set of saveable systems is not fixed at design time — systems are added incrementally (Hero shipped first; Inventory and Resource Economy were designed and ADR'd months later). The save interface must support dynamic registration rather than a hardcoded key list decided up front.

### Requirements
- Version header stored separately from game data so that migration can occur before data is parsed.
- Every saveable system registers itself with `SavePersistence` and exposes its state via a `get_save_data() -> Dictionary` method returning only primitives.
- Save completes atomically: a crash mid-write cannot produce a half-written .dat file.
- A corrupted or version-mismatched file produces a clear error — no silent data loss or crash.
- Checkpoint saves (mid-mission) use the same format, stored at a separate path.
- Systems restore in a well-defined order (`restore_order`), so a system can safely assume any lower-`restore_order` peer has already restored.
- A system whose save data is missing or fails to restore falls back to a known-good default state rather than crashing or restoring partial state.

## Decision

### The `SaveRestorer` Interface (canonical — registration-based, not a fixed key list)

Any system that persists state implements four methods and registers itself with the `SavePersistence` Autoload in its own `_ready()`:

```gdscript
# Required interface — every saveable system implements all four:
func get_save_key() -> String            # unique string key, e.g. "hero", "inventory"
func get_save_data() -> Dictionary        # primitives only — see Primitive-Only Rule below
func restore_save_data(data: Dictionary) -> bool   # true = restored successfully
func reset_to_defaults() -> void          # called when this system's data is absent or restore fails

# Registration — call from _ready() / unregister from _exit_tree():
SavePersistence.register(self, restore_order)   # restore_order: int, see band table below
SavePersistence.unregister(self)
```

There is **no fixed, hardcoded top-level key list**. `SavePersistence` builds the master Dictionary dynamically at save time from whatever systems are currently registered — a new saveable system (Menagerie, Defense Building, Tarot, etc.) needs no change to `SavePersistence` or this ADR, only its own ADR/story defining its `get_save_key()`/`get_save_data()`/`restore_save_data()`/`reset_to_defaults()` and a `restore_order` value.

### `restore_order` Bands

| Band | Range | Rationale |
|------|-------|-----------|
| Foundation | 0–9 | Infrastructure systems with no gameplay dependencies (reserved; none currently register — Grid and Pathfinding have no save state) |
| Core | 10–49 | Core-layer gameplay systems that may depend on each other's already-restored state |
| Feature | 50+ | Feature-layer systems that may depend on Core-layer systems having restored first |

A system registering with a given `restore_order` may assume any *already-registered* system with a strictly lower `restore_order` has finished restoring by the time its own `restore_save_data()` is called. It must not assume anything about systems with a higher `restore_order`. Currently registered: Hero at `restore_order=30` (Core), Inventory at `restore_order=10` (Core), per each system's own ADR (ADR-0010, ADR-0016). This band table is authoritative — a new system's ADR must cite it when picking a `restore_order`, rather than inventing a value in isolation.

### Master Dictionary Structure (assembled dynamically)

```gdscript
const CURRENT_FORMAT_VERSION: int = 1

# Built at save time from every currently-registered system —
# keys are whatever each system's get_save_key() returns, not a fixed list:
{
    "hero":       {},   # Hero.get_save_data()        — restore_order 30
    "inventory":  {},   # InventorySystem.get_save_data() — restore_order 10
    # ... any future system that has called SavePersistence.register()
}
```

A system that has never registered simply has no entry — there is nothing to "silently skip," since the Dictionary is built from the registration list, not from a fixed schema. On load, a registered system whose key is absent from the loaded Dictionary (e.g. a save file written before that system existed) calls `reset_to_defaults()` instead of `restore_save_data()`.

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

### Registration / Restore Implementation (matches shipped `save_persistence.gd`)

```gdscript
var _registered_systems: Array = []   # [{ ref, key, restore_order }, ...]

# --- Mid-session-restore fix (2026-07-18 revision) ---
# Caches the most recently loaded master Dictionary so a SaveRestorer that
# registers AFTER the initial load_slot() pass (a scene-instanced system
# recreated on a Sanctuary<->Mission transition, e.g. Constellation, Crafting,
# Tarot, Equipment Forge, Tower Mastery) still gets its data restored, instead
# of silently sitting at @export defaults for the rest of the play session.
var _last_loaded_data: Dictionary = {}
var _has_loaded_data: bool = false

func register(system_ref: Object, restore_order: int) -> void:
    _registered_systems.append({
        "ref": system_ref,
        "key": system_ref.get_save_key(),
        "restore_order": restore_order,
    })
    # Late registration: a full load already happened this session (or this is
    # a re-registration after the same scene reloaded) — restore this one
    # system immediately from the cached data rather than waiting for a load
    # that already happened and will not happen again.
    if _has_loaded_data:
        _restore_one(system_ref)

func unregister(system_ref: Object) -> void:
    for i in range(_registered_systems.size() - 1, -1, -1):
        if _registered_systems[i].ref == system_ref:
            _registered_systems.remove_at(i)

func _collect_save_data() -> Dictionary:
    var data: Dictionary = {}
    for entry in _registered_systems:
        data[entry.key] = entry.ref.get_save_data()
    return data

# Restores a single system from the cached _last_loaded_data. Shared by both
# the initial full-load pass (_restore_all_systems) and late registration
# (register(), above) so the two code paths can never drift out of sync.
func _restore_one(system_ref: Object) -> void:
    var key: String = system_ref.get_save_key()
    var sys_data: Dictionary = _last_loaded_data.get(key, {})
    if sys_data.is_empty():
        system_ref.reset_to_defaults()
        return
    if not system_ref.restore_save_data(sys_data):
        push_error("SavePersistence: restore failed for '%s' — calling reset_to_defaults()" % key)
        system_ref.reset_to_defaults()

func _restore_all_systems(data: Dictionary, slot: int) -> void:
    _last_loaded_data = data
    _has_loaded_data = true
    var sorted := _registered_systems.duplicate()
    sorted.sort_custom(func(a, b): return a.restore_order < b.restore_order)
    for entry in sorted:
        _restore_one(entry.ref)
    GEventBus.sanctuary_state_restored.emit.call_deferred(slot)
```

**Scope of the fix — what it does and does not solve:**
- A late-registering system's own `restore_save_data()` is guaranteed to run against the same data every already-restored system saw at the original `load_slot()` — `_last_loaded_data` is not re-read from disk, so this is not a second load, just a second application of the same in-memory result.
- `restore_order` still governs the *original* full-load pass's ordering. A late registrant's restore is **not** re-ordered against other systems — it runs alone, immediately, at `register()` time. This is safe for every system currently flagged against this gap (Constellation, Crafting, Tarot, Equipment Forge, Tower Mastery) because none of their `restore_save_data()` implementations read another system's *live* restored state — each restores only its own ledger(s) (confirmed against each system's own ADR/registry entry). A future scene-instanced `SaveRestorer` whose restore logic needs to read another system's already-restored state at restore time would need a different mechanism than this one — flag that case explicitly if it arises, do not assume this fix covers it.
- No new EventBus event fires for a late, single-system restore — `sanctuary_state_restored` remains a one-time signal for the original full load. A UI that needs to reflect a late-restored system's state should pull it via that system's own synchronous getter at open time (the same pull-not-push precedent already used by Hero Skill Build's `get_passive_loadout()`), not wait for a second global "restored" broadcast that does not exist.
- `_has_loaded_data`/`_last_loaded_data` persist for the remainder of the process — they are only replaced by a subsequent successful `load_slot()` (e.g., the player loads a different save slot). A "new game" flow that never calls `load_slot()` leaves `_has_loaded_data` false, and every system simply keeps its `@export` defaults, exactly as before this revision.

### Write Implementation

```gdscript
const SAVE_DIR  := "user://saves/"
const SAVE_PATH := "user://saves/save_slot_%d.dat"
const TMP_PATH  := "user://saves/save_slot_%d.tmp"

func save_slot(slot: int) -> bool:
    var data := _collect_save_data()
    var ok := _write_slot(slot, data)
    if ok:
        GEventBus.game_saved.emit(slot, Time.get_unix_time_from_system())
    return ok

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

### Read Implementation

```gdscript
func load_slot(slot: int) -> bool:
    var data := _read_slot(slot)
    if data.is_empty():
        return false
    _active_slot = slot
    _restore_all_systems(data, slot)
    return true

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

Each `_migrate_vN_to_vN+1()` function transforms the Dictionary structure from one schema to the next. Migrations are append-only — they never delete keys (mark unused keys with a `_deprecated_` prefix if needed). Migration unit tests are **required by coding standards** for every version increment. Because the master Dictionary's keys now come from dynamic registration rather than a fixed list, a migration function must not assume any particular set of keys is present — it should only transform keys it recognizes and pass unrecognized keys through unchanged.

### File Paths

| File | Purpose |
|------|---------|
| `user://saves/save_slot_N.dat` | Primary save file for slot N (N = 0, 1, 2) |
| `user://saves/save_slot_N.tmp` | Intermediate write target — renamed to .dat on success |
| `user://saves/save_slot_N_checkpoint.dat` | Mid-mission checkpoint (same format, separate path) |

**Startup cleanup**: On `_ready()`, SavePersistence scans `user://saves/` for any `.tmp` files and deletes them. A .tmp file surviving to the next launch means a crash occurred mid-write — the .dat (if it exists) is the last good save.

## Architecture Diagram

```
SAVE TRIGGER (EventBus: mission_launched (checkpoint) / mission_phase_changed → SANCTUARY / autosave timer)
  │
  ▼ SavePersistence._collect_save_data()
  ┌─────────────────────────────────────────┐
  │  for each REGISTERED system:             │
  │    data[system.get_save_key()] =         │
  │      system.get_save_data()              │
  │  → assemble master Dictionary dynamically│
  └────────────┬──────────────────────────────┘
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
               ▼ _restore_all_systems(data, slot)
  ┌───────────────────────────────────────────────┐
  │  cache data → _last_loaded_data, mark loaded   │
  │  sort registered systems by restore_order asc  │
  │  for each, in order: _restore_one(ref)         │
  │  emit sanctuary_state_restored (deferred 1 fr.)│
  └─────────────────────────────────────────────────┘

LATE REGISTRATION (2026-07-18 revision) — a scene-instanced SaveRestorer
(Constellation/Crafting/Tarot/EquipmentForge/TowerMastery) is recreated on a
Sanctuary<->Mission transition, AFTER the load above already completed once:
  │
  ▼ register(system_ref, restore_order)
  ┌─────────────────────────────────────────────────┐
  │  append to _registered_systems (as before)      │
  │  if _has_loaded_data: _restore_one(system_ref)  │
  │    → looks itself up in the cached              │
  │      _last_loaded_data, restores or defaults    │
  │      immediately — no re-load, no new event     │
  └─────────────────────────────────────────────────┘
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

### Alternative E (considered in the 2026-07-18 revision): Reclassify all 5 affected scene-instanced systems as Autoload instead of caching restore data

- **Description**: Make Constellation, Crafting, Tarot, Equipment Forge, and Tower Mastery Autoloads (matching the 5 systems already reclassified earlier this session for direct-call or scene-transition-survival reasons), so none of them are ever destroyed/recreated and the restore gap cannot occur for them at all.
- **Pros**: Sidesteps the problem entirely for these 5 systems — no new SavePersistence logic needed.
- **Cons**: Doesn't fix the underlying gap — any *future* scene-instanced `SaveRestorer` would hit the identical problem and need its own case-by-case Autoload promotion. Five more global singletons for no reason beyond dodging a persistence gap (unlike the prior five reclassifications, none of which were justified by persistence alone — each had an independent direct-call or scene-survival requirement per its own ADR). Increases the Autoload count `docs/registry/architecture.yaml` is already flagging as worth watching (per ADR-0002's own Risks section, referenced by every prior reclassification this session).
- **Rejection Reason**: A project-wide, SavePersistence-side fix solves this class of problem once, for every current and future scene-instanced system, rather than requiring a bespoke architectural promotion per affected system. The cost (a `Dictionary` cache plus a few lines in `register()`) is far lower than five additional Autoloads.

### Alternative F (considered in the 2026-07-18 revision): Re-run the entire `_restore_all_systems()` pass on every `register()` call, not just the newly-registered system

- **Description**: Instead of restoring only the late-registering system, re-run the full sorted loop over every currently-registered system whenever any one of them registers.
- **Pros**: Marginally simpler mental model — one restore path instead of two.
- **Cons**: Wasteful — every already-loaded system would have its `restore_save_data()` re-invoked on every scene transition, even those that never left memory (e.g., Autoloads). Riskier — a `restore_save_data()` implementation that has any observable side effect beyond setting its own fields (e.g., an EventBus emission) would incorrectly re-fire that side effect for systems that were never actually reloaded.
- **Rejection Reason**: Restoring only the system that actually just (re-)registered is both cheaper and strictly safer — it cannot affect any system whose state was never invalidated.

### Alternative D (considered in this revision): Keep the original fixed top-level key list, update each system ADR to conform to it instead
- **Description**: Instead of correcting this ADR, revise ADR-0010/0016/0017 (and the shipped `save_persistence.gd`) to drop `get_save_key()`/`restore_save_data()`/`reset_to_defaults()`/`register()` and adopt the original `apply_save_data(data[key])` + hardcoded key list.
- **Pros**: Would leave this ADR's original text untouched.
- **Cons**: Would require reverting already-shipped, tested code (`save_persistence.gd`, `save_persistence_write_test.gd`, `save_persistence_restore_test.gd`) and three Accepted ADRs. The registration-based interface is also a strictly better fit for this project's incremental-system-design reality (new saveable systems are added by their own ADR months apart, not all decided up front).
- **Rejection Reason**: Higher cost, no benefit — the registration-based interface is what was actually built, tested, and is already load-bearing for three Accepted ADRs.

## Consequences

### Positive
- Single-call `store_var()` handles all nested Dictionaries and Arrays — no per-field serialization code.
- Version header is 4 bytes, read before any game data — migration detection is trivial.
- Atomic .tmp → .dat rename prevents half-written save files from corrupting the slot.
- `full_objects = false` prevents script-path embedding — the format is not broken by file renames.
- The primitive-only rule makes every system's `get_save_data()` output independently testable.
- **Registration-based interface** (this revision) means new saveable systems need no change to `SavePersistence` or this ADR — only their own ADR defines `get_save_key()`/`get_save_data()`/`restore_save_data()`/`reset_to_defaults()` and a `restore_order`.
- **Ordered restore with `reset_to_defaults()` fallback** (this revision) means a missing or corrupt entry for one system degrades gracefully to that system's defaults instead of blocking the whole load or requiring the fixed-key-list's "silently skip" behavior.
- **Cached mid-session restore** (2026-07-18 revision) unblocks every persistence-dependent story currently flagged against this gap in Epics 05–08 (Constellation, Crafting, Tarot, Equipment Forge, Tower Mastery) without requiring any of them to become Autoloads, and without adding any new engine API surface — it is a `Dictionary` cache plus a few lines in an already-existing method.

### Negative
- The `store_var()` binary format is Godot-internal and version-coupled — loading a 4.6 save file in a hypothetical Godot 5 port would require a dedicated export/import step, not raw file access.
- Every system must implement `get_save_key()`, `get_save_data()`, `restore_save_data()`, and `reset_to_defaults()`, and explicitly `register()`/`unregister()` — no automatic serialisation of properties, and a system that forgets to register is silently excluded from save/load with no error.
- Bool return checks on every `store_*` call add verbosity to the write function.
- `restore_order` collisions between two systems are not automatically detected — a new system's ADR must manually check the band table (see Decision) before picking a value.

### Risks
- **Risk**: A developer embeds a Resource object in `get_save_data()` output. `store_var(data, false)` will silently drop the Resource or store a null. **Mitigation**: Primitive-only rule documented in this ADR and in coding standards. GUT test mandated (required per `coding-standards.md`).
- **Risk**: `DirAccess.rename()` on Windows fails if the .dat file is open by another process (e.g., cloud sync). **Mitigation**: Log the error; surface to player as "Save failed — close any file-syncing apps". Do not retry silently.
- **Risk**: A migration function has a bug that corrupts data on upgrade. **Mitigation**: Migration unit tests are BLOCKING per coding standards — a migration function without a passing test cannot be merged.
- **Risk**: Godot's internal `store_var()` binary format changes between minor versions. **Mitigation**: Format version header allows detection. If the format changes, a new migration step decodes old binary and re-encodes in the new format.
- **Risk** (new, this revision): A system forgets to call `SavePersistence.register()` in `_ready()`. **Mitigation**: its data is silently absent from every save — no error is raised. Recommend a future GUT test enumerating expected registrants (Hero, Inventory, and each future saveable system per its own ADR) and asserting each is registered at boot.
- **Risk** (new, this revision): Two systems pick colliding `restore_order` values. **Mitigation**: the band table and the "list every registrant" comment convention in `save_persistence.gd` (see Decision) make collisions visible to a reviewer; no runtime detection exists yet.
- **Risk** (new, 2026-07-18 revision): A late-registering system's `restore_save_data()` implicitly assumes another system's *live* restored state is available at restore time (not just its own persisted data). **Mitigation**: this fix restores late registrants alone, immediately, outside the sorted `restore_order` pass — it does not preserve cross-system restore-order guarantees for late registrants. Confirmed safe today because none of the 5 currently-affected systems' restore logic reads another system's live state (verified against each system's own ADR/registry entry). Any future scene-instanced `SaveRestorer` with a genuine cross-system restore-time dependency must flag it explicitly rather than assume this fix covers it — it does not.
- **Risk** (new, 2026-07-18 revision): `_last_loaded_data` grows stale relative to disk if a system's on-disk save data changes without a fresh `load_slot()` (there is no such path today — saves only change via explicit `save_slot()` triggers, which don't touch `_last_loaded_data`). **Mitigation**: not currently reachable given the existing save/load trigger set; flagged here so a future save-trigger addition re-checks this assumption before shipping.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| save-persistence.md | Atomic write: .tmp → rename to .dat | Write implementation uses DirAccess.rename() as the final step |
| save-persistence.md | 3 save slots | File path template: `user://saves/save_slot_N.dat` for N = 0, 1, 2 |
| save-persistence.md | Format version in file header | store_32(CURRENT_FORMAT_VERSION) as first 4 bytes |
| save-persistence.md | Migration: version N loads in version N+1 | _migrate() chains sequential _migrate_vN_to_vN+1() functions |
| save-persistence.md | Checkpoint save (mid-mission) | `user://saves/save_slot_N_checkpoint.dat` uses same format at separate path |
| save-persistence.md | Auto-save on EventBus trigger | SavePersistence subscribes to `mission_launched` / `mission_phase_changed` via EventBus (ADR-0001) |
| save-persistence.md | Restore order 10–33; deferred 1 frame | `restore_order` band table + `_restore_all_systems()` ordered loop (this revision); `sanctuary_state_restored` emitted deferred via `call_deferred` |
| inventory.md (ADR-0016), resource-economy.md (ADR-0017), hero.md (ADR-0010) | `SaveRestorer` registration interface | This revision formally defines `get_save_key()`/`get_save_data()`/`restore_save_data()`/`reset_to_defaults()`/`register()` as canonical — matches what all three ADRs and the shipped code already depend on |
| constellation.md (ADR-0022), crafting.md (ADR-0023), tarot.md (ADR-0027), equipment-forge.md (ADR-0025), tower-mastery.md (ADR-0029) | Mid-session-restore for scene-instanced `SaveRestorer`s destroyed/recreated on Sanctuary<->Mission transitions | 2026-07-18 revision's cached-restore path in `register()` — restores or defaults a late-registering system immediately from `_last_loaded_data`, unblocking these 5 systems' persistence-dependent stories |

**Technical Requirements covered**: TR-save-001, TR-save-002, TR-save-003, TR-save-004, TR-save-005, TR-save-006

## Performance Implications
- **CPU**: `store_var()` serialisation is synchronous but not per-frame — acceptable for a triggered save. For large inventories (100+ items), profiling may reveal a need for async write in a future ADR.
- **Memory**: The master Dictionary is assembled in memory before write — peak allocation is the full save state. Estimated < 1 MB for MVP scope.
- **Load Time**: `get_var()` deserialisation is synchronous at boot — save data is loaded before the first scene. For MVP scope, negligible.
- **Network**: Not applicable (single-player only).

## Migration Plan
Greenfield project. `CURRENT_FORMAT_VERSION = 1` at launch. No version 0 files exist — the migration switch statement's first case handles v1→v2 (not yet needed). The `_migrate_step()` function is written defensively to log an error for unknown version numbers rather than silently corrupting data. This revision changes no on-disk format and requires no data migration — it only corrects the ADR text to match the interface the shipped code already implements.

## Validation Criteria
- [ ] `store_32(CURRENT_FORMAT_VERSION)` returns `true` on a writable path.
- [ ] `store_var(data, false)` correctly round-trips a nested Dictionary containing int, float, bool, String, Array, and Dictionary values.
- [ ] A save written to .tmp and renamed to .dat produces a readable .dat file on the next `_read_slot()` call.
- [ ] A .tmp file left on disk at startup is deleted by `SavePersistence._ready()` cleanup.
- [ ] A save file with `format_version > CURRENT_FORMAT_VERSION` produces a logged error and returns `{}` — no crash.
- [ ] A save file with `format_version < CURRENT_FORMAT_VERSION` is successfully migrated by `_migrate()` — verified by unit test. **(BLOCKING — coding standards mandate migration unit test)**
- [ ] A system returning a Resource object in `get_save_data()` is caught by the GUT primitive-only validation test. **(BLOCKING)**
- [ ] Two registered systems restore in ascending `restore_order` — verified by unit test asserting call order. **(new, this revision)**
- [ ] A registered system whose key is absent from loaded data calls `reset_to_defaults()`, not `restore_save_data()`. **(new, this revision)**
- [ ] A registered system whose `restore_save_data()` returns `false` triggers `reset_to_defaults()` and a logged error, not a crash or partial-restore state. **(new, this revision)**
- [x] A `SaveRestorer` that calls `register()` AFTER `load_slot()` has already completed successfully is immediately restored (or defaulted) from the cached `_last_loaded_data` — verified by a unit test that: loads a slot with system A already registered, then registers system B afterward, and asserts `B.restore_save_data()` (or `reset_to_defaults()`) was called with the correct data before `register()` returns. **(new, 2026-07-18 revision, BLOCKING)** — **VERIFIED 2026-07-18** via live Godot MCP `run_script` against the real shipped `save_persistence.gd`, plus `tests/unit/save_persistence/save_persistence_restore_test.gd`'s new `test_late_registration_after_load_restores_from_cached_data`/`test_late_registration_with_no_matching_key_calls_reset_to_defaults` cases.
- [x] Unregistering and re-registering the same system multiple times within one session (simulating repeated Sanctuary<->Mission scene reloads with no new save/load in between) restores it identically every time from the same cached data. **(new, 2026-07-18 revision, BLOCKING)** — **VERIFIED 2026-07-18** via live MCP run and `test_repeated_unregister_register_cycle_restores_identically_each_time`.
- [x] A late-registering system whose key is absent from `_last_loaded_data` calls `reset_to_defaults()`, not `restore_save_data()` — mirrors the existing initial-load behavior for a missing key. **(new, 2026-07-18 revision)** — **VERIFIED 2026-07-18**, same live MCP run.

## Related Decisions
- ADR-0001 — EventBus architecture (SavePersistence subscribes to `mission_launched`/`mission_phase_changed` triggers)
- ADR-0002 — Scene and Autoload structure (SavePersistence is Autoload #2 — boots before Grid/Pathfinding, after EventBus)
- ADR-0009 — Resource data model (primitive-only rule constrains how Resources expose their state via `get_save_data()`)
- ADR-0010 — Hero Tower-Synced Class (registers via this ADR's `SaveRestorer` interface at `restore_order=30`)
- ADR-0016 — Inventory Storage Model (registers via this ADR's `SaveRestorer` interface at `restore_order=10`; previously miscited this ADR's interface before this revision)
- ADR-0017 — Resource Economy Drop Resolution (depends on this ADR's Save & Persistence boundary, though Resource Economy itself does not register — see ADR-0017 for its own state-ownership scope)
- ADR-0022 — Constellation Pattern-Detection Data Structure (its Discovery Ledger is one of the 5 systems this revision's fix unblocks)
- ADR-0023 — Crafting Recipe Data Model (its Discovery Ledger is one of the 5 systems this revision's fix unblocks)
- ADR-0025 — Equipment Forge Cross-System Aggregation (one of the 5 systems this revision's fix unblocks)
- ADR-0027 — Tarot Modifier Aggregation Pipeline (one of the 5 systems this revision's fix unblocks)
- ADR-0029 — Tower Mastery Proximity-Detection Strategy (its godot-specialist review first surfaced this gap as a project-wide issue, not unique to Tower Mastery)
- `design/gdd/save-persistence.md` — canonical GDD for Save & Persistence system
- `docs/architecture/architecture-review-2026-07-13b.md` — identified the interface-drift conflict the 2026-07-13 revision resolves
