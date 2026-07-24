# ADR-0009: Resource Data Model for Game Entities

## Status
Accepted

## Date
2026-05-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | LOW — `Resource` subclasses, `@export`, `ResourceLoader.load()`, `DirAccess` are all pre-4.x stable APIs. `DirAccess.get_files_at()` static method available since Godot 4.0. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `DirAccess.get_files_at("res://assets/data/monsters/")` returns correct file list in exported builds (PCK-backed `res://` scanning); test with one actual `.tres` file before authoring all content. Confirm `ResourceLoader.load()` with type hint (`as MonsterResource`) returns `null` — not a crash — on type mismatch. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Scene/Autoload structure — this ADR adds `GameDataRegistry` as Autoload position 5, shifting `SceneManager` to position 6; ADR-0002 boot order must be updated to reflect this); ADR-0006 (establishes `MonsterDamageTaken` Resource type and `MonsterResource` as the data source for monster entity state); ADR-0008 (establishes `duplicate_deep()` as the TowerComponent isolation pattern for mission instances) |
| **Enables** | Monster System implementation (MonsterRegistry lookup defined); Tower System implementation (TowerComponent schema and TowerPerkRegistry lookup defined); Wave Manager implementation (WaveConfig/WaveScript/WaveSpawnEntry schema defined) |
| **Blocks** | Monster System Core epic; Tower System Core epic; Wave Manager Feature epic (all depend on the Resource schemas being Accepted before stories can be authored) |
| **Ordering Note** | ADR-0002 revision is required before implementation. This ADR is self-sufficient for authoring; the boot order update in ADR-0002 (SceneManager shifted from position 5 to 6) is a registry-and-doc edit, not a blocking prerequisite for writing content `.tres` files. Accepted 2026-05-24 — ADR-0012 may now be promoted to Accepted. |

## Context

### Problem Statement

Six game entity types (Monster, WaveConfig, WaveScript, WaveSpawnEntry, four TowerComponent variants, TowerPerkRegistry) are defined as Godot Resource subclasses in their respective GDDs, but no ADR establishes: how scripts look up MonsterResources by `monster_id` at spawn time without embedding path strings in GDScript; whether nested wave data (WaveConfig → WaveScript → WaveSpawnEntry) lives in one file or several; how load-time validation is enforced across all Resource types; or how event-payload Resources (MonsterDamageTaken, HeroAutoAttackEvent, etc.) relate to persistent data Resources.

Two systems (MonsterSystem and Tower System) both need MonsterResource access at runtime — a shared lookup mechanism is necessary.

### Constraints
- No direct system-to-system references (ADR-0001: EventBus-only cross-system comms) — Resource files are data, not system calls, so `ResourceLoader.load()` is permitted
- TowerComponent Resources on mission instances must use `duplicate_deep()` (established in ADR-0008) — data resources are immutable; mission instances are deep copies
- Adding a new Autoload revises the boot order from ADR-0002 (currently: EventBus, SavePersistence, Grid, Pathfinding, SceneManager)
- Validation must be enforceable at load time without relying on caller discipline

### Requirements
- MonsterResource lookup by `monster_id: StringName` must be O(1) and available before the first `monster_spawn_requested` event fires
- WaveConfig must be loadable per-mission without scattering wave data across many files
- All data Resources must validate their field ranges on load; invalid data must log an error but must not crash the engine in release builds
- Event-payload Resources (short-lived, emitted via EventBus) must not be confused with persistent data Resources (authored as `.tres`, loaded at game or mission start)

## Decision

### Resource Hierarchy

All game entity Resources divide into two categories:

**Persistent data Resources** — authored as `.tres` files in `assets/data/`, loaded at boot or mission start, immutable at runtime:

```
Resource
├── MonsterResource          assets/data/monsters/{monster_id}.tres
├── WaveConfig               assets/data/waves/{mission_id}_waves.tres
│   └── [embedded] WaveScript (Array[WaveScript] inside WaveConfig)
│       └── [embedded] WaveSpawnEntry (Array[WaveSpawnEntry] inside WaveScript)
├── TowerPerkRegistry        assets/data/towers/perk_registry.tres
├── FoundationComponent      assets/data/towers/foundations/*.tres
├── WeaponComponent          assets/data/towers/weapons/*.tres
├── FocusComponent           assets/data/towers/focus/*.tres
└── PowerComponent           assets/data/towers/power/*.tres
```

**Event-payload Resources** — instantiated at emit time, short-lived, never stored as files:

```
Resource (short-lived — NOT .tres files)
├── MonsterDamageTaken       (ADR-0006, ADR-0007 — carries monster_damage_taken payload)
├── HeroAutoAttackEvent      (ADR-0007 — carries hero_auto_attacked payload)
├── TowerWaveSummary         (tower.md Rule 23 — carries tower_wave_summary payload)
├── TowerAuraPulseEvent      (tower.md Rule 5a — carries tower_aura_pulse payload)
└── WaveCompositionEntry     (event-bus.md — array element of wave_preview_available's
                               `composition` field, not itself a signal's sole payload;
                               added 2026-07-07 to replace an `Array[Dictionary]` that
                               violated event-bus.md Core Rule 4's Dictionary-payload ban)
```

These two categories must never be mixed: a data Resource must never be emitted as an EventBus payload; an event-payload Resource must never be saved as a `.tres` file.

### GameDataRegistry Autoload

A new Autoload, `GameDataRegistry`, is added at **boot position 5**. `SceneManager` shifts to position 6. Updated boot order: `EventBus(1), SavePersistence(2), Grid(3), Pathfinding(4), GameDataRegistry(5), SceneManager(6)`.

`GameDataRegistry._ready()` performs at game start:
1. Scans `res://assets/data/monsters/` via `DirAccess.get_files_at()` and loads every `.tres` found as `MonsterResource`, keying by `resource.monster_id`
2. Validates each MonsterResource via `resource.validate()`; `push_error()` per invalid field — does NOT abort
3. Preloads `res://assets/data/towers/perk_registry.tres` as `TowerPerkRegistry` and validates it

`GameDataRegistry` exposes two public methods only:
```gdscript
func get_monster_resource(monster_id: StringName) -> MonsterResource  # null if not found
func get_perk_registry() -> TowerPerkRegistry  # always non-null after _ready()
```

No other system accesses `MonsterResource` or `TowerPerkRegistry` directly by path. All lookups go through `GameDataRegistry`.

### WaveConfig — Embedded Nested Resources

One `WaveConfig.tres` per mission, stored in `assets/data/waves/`. `WaveScript` and `WaveSpawnEntry` are inline sub-Resources (Godot's embedded resource model) — no separate `.tres` files per wave or per entry. All wave data for a mission colocates in one file.

Wave Manager loads its `WaveConfig` via `ResourceLoader.load(wave_config_path)` where `wave_config_path` is passed in by the Mission Scene at load time (e.g., via an `@export var` on the Wave Manager node or via a mission data bus event). Wave Manager validates the loaded WaveConfig on receipt.

```gdscript
# WaveConfig schema
@export var wave_scripts: Array[WaveScript] = []
@export var difficulty_growth_rate: float = 0.20
@export var reward_base: float = 1.0

# WaveScript schema
@export var entries: Array[WaveSpawnEntry] = []

# WaveSpawnEntry schema
@export var monster_id: StringName = &""
@export var spawn_cell_index: int = -1  # -1 = round-robin
@export var pre_delay: float = 0.0      # seconds; >= 0.0
```

### TowerComponent Resources

TowerComponent `.tres` files (FoundationComponent, WeaponComponent, FocusComponent, PowerComponent) live in `assets/data/towers/` and are loaded with the player's inventory data at Sanctuary load time. They are not loaded by `GameDataRegistry` — the Save & Persistence system owns their load path.

At tower placement, `duplicate_deep()` is called on each of the four components per ADR-0008. The duplicated copies stored in `TowerMissionState` are mission-instance-only and are not validated again (validation has already occurred at inventory load time).

### Load-Time Validation Pattern

Every persistent data Resource subclass implements `validate() -> Array[String]` returning a list of error strings. An empty array means valid. `GameDataRegistry` calls `validate()` on each MonsterResource and on `TowerPerkRegistry` at boot, calling `push_error(err)` for each non-empty result. Wave Manager calls `wave_config.validate()` at mission load. Save & Persistence calls `component.validate()` for each TowerComponent at inventory load.

```gdscript
# Example — MonsterResource.validate()
func validate() -> Array[String]:
    var errors: Array[String] = []
    if monster_id == &"":
        errors.append("monster_id must not be empty")
    if base_hp <= 0.0:
        errors.append("base_hp must be > 0 (got %f)" % base_hp)
    if tier not in [0, 1, 2]:
        errors.append("tier must be 0/1/2 (got %d)" % tier)
    if tier == 2 and base_damage <= 0.0:
        errors.append("BOSS tier requires base_damage > 0")
    return errors
```

Validation must NOT abort the game in release builds — `push_error()` is the only consequence. In DEBUG builds, caller code may add `assert(errors.is_empty())` after validation if a hard stop is preferred during development.

### Architecture Diagram

```
Game Start
  GameDataRegistry._ready()
    ├── DirAccess.get_files_at("res://assets/data/monsters/")
    │     └── load each .tres → MonsterResource
    │           └── validate() → push_error() per issue
    └── load("res://assets/data/towers/perk_registry.tres") → TowerPerkRegistry
          └── validate() → push_error() per issue

Mission Start
  Wave Manager receives wave_config_path
    └── ResourceLoader.load(wave_config_path) → WaveConfig (embedded WaveScript/WaveSpawnEntry)
          └── wave_config.validate() → push_error() per issue

Save/Load
  SavePersistence loads TowerComponent .tres files from inventory save data
    └── component.validate() → push_error() per issue

Runtime (WAVE_ACTIVE)
  MonsterSystem._on_monster_spawn_requested(monster_id, ...)
    └── GameDataRegistry.get_monster_resource(monster_id)  → MonsterResource (or null → abort spawn)

Runtime (WAVE_ACTIVE)
  TowerSystem._on_tower_attacked(...)
    └── GameDataRegistry.get_monster_resource(monster_id)  → not called per-shot
    (archetype_tag already cached in _monster_cache from monster_spawned subscription)

Tower Placement (SCOUT/INTERMISSION)
  TowerSystem.place_tower()
    └── for each of 4 components: component.duplicate_deep()  → TowerMissionState  (ADR-0008)
```

### Key Interfaces

```gdscript
# GameDataRegistry (Autoload — boot position 5)
func get_monster_resource(monster_id: StringName) -> MonsterResource:
    return _monster_resources.get(monster_id, null)  # null → spawn abort

func get_perk_registry() -> TowerPerkRegistry:
    return _perk_registry  # always valid after _ready()

# Each data Resource subclass
func validate() -> Array[String]:
    ...  # returns [] on valid; one string per error

# MonsterResource fields (immutable at runtime)
@export var monster_id: StringName = &""
@export var display_name: String = ""
@export var tier: int = 0              # 0=STANDARD 1=ELITE 2=BOSS
@export var archetype_tag: StringName = &""  # &"armored" or &""
@export var base_hp: float = 100.0
@export var base_speed: float = 3.0
@export var base_damage: float = 0.0  # BOSS only
@export var drop_chance: float = 0.0
@export var wave_scale_factor: float = 1.0
@export var sprite_frames: SpriteFrames
@export var death_vfx_scene: PackedScene

# WaveConfig (embedded structure — one .tres per mission)
class_name WaveConfig extends Resource
@export var wave_scripts: Array[WaveScript] = []
@export var difficulty_growth_rate: float = 0.20
@export var reward_base: float = 1.0

class_name WaveScript extends Resource
@export var entries: Array[WaveSpawnEntry] = []

class_name WaveSpawnEntry extends Resource
@export var monster_id: StringName = &""
@export var spawn_cell_index: int = -1
@export var pre_delay: float = 0.0
```

## Alternatives Considered

### Alternative 1: `ResourceLoader.load()` per spawn (no registry Autoload)
- **Description**: MonsterSystem constructs a path `"res://assets/data/monsters/%s.tres" % monster_id` and calls `ResourceLoader.load()` per spawn
- **Pros**: No new Autoload; no boot order change; simpler
- **Cons**: Godot's resource cache is per-session, not pre-warmed. First-spawn of each monster type will have IO overhead. More importantly, Tower System also needs MonsterResource at spawn time (for `archetype_tag` caching from `monster_spawned`) — without a registry, both systems embed path-construction logic independently, creating a maintenance coupling between the directory structure and two GDScript files.
- **Rejection Reason**: Duplicate path-construction logic in two systems; first-spawn latency; no centralized validation at boot.

### Alternative 2: Separate `.tres` files per WaveScript
- **Description**: Each wave gets its own `wave_N.tres` file; WaveConfig holds an `Array[String]` of paths, loading each on demand
- **Pros**: Easier per-wave editing in version control (no merge conflicts in a single large .tres)
- **Cons**: Wave Manager must load multiple files per mission start; the Godot editor's inline resource authoring (click to expand sub-resources) is simpler with embedded resources; separating WaveSpawnEntry into dozens of files provides no authoring benefit that outweighs the complexity
- **Rejection Reason**: Embedded nested Resources are the idiomatic Godot pattern for this use case. Godot's `.tres` parser handles nested Resources correctly with no known issues.

### Alternative 3: TowerComponent files managed by GameDataRegistry
- **Description**: All `.tres` files — including TowerComponent variants — loaded and validated by GameDataRegistry at boot
- **Pros**: Single point of load-and-validate for all game data
- **Cons**: TowerComponent inventory is player-specific and changes over sessions; loading all authored components at boot loads data the player may never encounter. Save & Persistence already owns the load path for equipped components. Adding inventory management to GameDataRegistry blurs responsibility boundaries.
- **Rejection Reason**: TowerComponent lifecycle is save-data-driven, not boot-time-fixed. Save & Persistence (ADR-0003) is the correct owner.

## Consequences

### Positive
- Single lookup point for MonsterResource (`GameDataRegistry.get_monster_resource()`) — both MonsterSystem and Tower System use the same pre-validated cache
- WaveConfig's embedded structure makes mission authoring self-contained: one file holds all wave data for one mission
- Load-time validation is structurally enforced at GameDataRegistry._ready() and at mission-load time — no caller can skip it accidentally
- Event-payload Resources are formally distinct from data Resources — prevents accidental `.tres` serialization of short-lived objects

### Negative
- Boot order revision required (ADR-0002 must be updated to add GameDataRegistry at position 5)
- `DirAccess.get_files_at()` scan at boot is a one-time blocking load — must complete before the main menu appears. With 5–8 MonsterResource files at MVP, this is negligible; it must be profiled if monster count grows beyond ~50 at post-MVP scale
- WaveConfig embedded resources require the Godot editor to be used for authoring (cannot edit with a plain text editor); this is the normal Godot content workflow

### Risks
- **`DirAccess.get_files_at()` in exported builds**: The static method should work correctly with Godot's PCK-backed `res://`. Verification Required: test with one `.tres` file in a fresh export before committing to this pattern for all content. Mitigation: fallback is `ResourceLoader.load()` with explicit path list if scanning fails in export.
- **Invalid MonsterResource at spawn time**: If `validate()` found errors at boot but the game proceeded, `get_monster_resource()` still returns the invalid Resource. MonsterSystem must treat a non-null but unvalidated resource defensively. The documented mitigation: if `get_monster_resource()` returns `null` (missing resource) OR the registry logged errors for that ID, abort the spawn and log a system error. GameDataRegistry may optionally store invalid IDs in a `_invalid_ids: Dictionary` to enable this check.
- **WaveConfig size growth**: Each wave entry embeds spawn data inline. At 8 waves × 20 entries = 160 `WaveSpawnEntry` sub-resources per mission. Godot's .tres parser handles this without known issues at this scale; revisit if missions exceed 500 entries.

## GDD Requirements Addressed

| GDD System | TR-ID | Requirement | How This ADR Addresses It |
|------------|-------|-------------|--------------------------|
| tower.md | TR-tower-001 | 4 component slots; 4 archetypes; 4 tiers | Defines FoundationComponent, WeaponComponent, FocusComponent, PowerComponent as Resource subclasses with their authoritative field schemas from tower.md Rule 2a |
| tower.md | TR-tower-006 | Support archetype aura pulse model | Establishes `TowerAuraPulseEvent` as an event-payload Resource (short-lived, not persisted); formally distinguishes it from data Resources; its payload schema is the authoritative source for the `tower_aura_pulse` signal |
| wave-manager.md | TR-wave-002 | WaveConfig/WaveScript/WaveSpawnEntry Resources | Defines the three Resource types, their field schemas, the embedded nesting model, and how Wave Manager loads WaveConfig per mission |
| monster.md | TR-monster-002 | MonsterResource data-driven stats; 3 tiers | Documents MonsterResource schema and GameDataRegistry lookup pattern; full coverage depends on ADR-0006 reaching Accepted status |

## Performance Implications
- **CPU (boot)**: DirAccess scan + load of 5–8 MonsterResource files + 1 TowerPerkRegistry at boot. Estimated < 5 ms total. Profiling required if monster count exceeds 30.
- **CPU (runtime)**: `get_monster_resource()` is a Dictionary lookup — O(1), < 1 µs per call.
- **Memory**: 5–8 MonsterResource instances in memory for the session. Each Resource is small (~10 fields, no large textures — `sprite_frames` and `death_vfx_scene` are reference types, shared across all entities of the same type). Total: negligible.
- **Load Time**: WaveConfig embedded-resource load at mission start: single file, < 1 ms.
- **Network**: Not applicable.

## Migration Plan
Greenfield — no existing data files. Content pipeline:
1. Create `MonsterResource.gd`, `WaveConfig.gd`, `WaveScript.gd`, `WaveSpawnEntry.gd`, `TowerPerkRegistry.gd`, and the four TowerComponent GDScript files with `@export` fields matching the schemas above
2. Register `GameDataRegistry.gd` as Autoload in project settings at position 5; shift SceneManager to position 6
3. Update ADR-0002 and the architecture registry `autoload_boot_order` entry to reflect the new boot order
4. Author one sample `.tres` of each type and verify `GameDataRegistry._ready()` loads and validates correctly in both editor and export

## Validation Criteria
- `GameDataRegistry.get_monster_resource(&"goblin_runner")` returns the correct MonsterResource after `_ready()` completes
- `validate()` on a MonsterResource with an out-of-range `base_hp` returns a non-empty error array
- WaveConfig.tres with 3 WaveScripts each containing 5 WaveSpawnEntries loads correctly and `wave_scripts.size() == 3`
- A missing MonsterResource (`monster_id` not in registry) returns `null` from `get_monster_resource()` — no crash
- GameDataRegistry does not appear in the scene tree during WAVE_ACTIVE (Autoload lifetime check)

## Related Decisions
- ADR-0002 — Scene/Autoload structure (boot order revised by this ADR — GameDataRegistry at position 5)
- ADR-0003 — Save file format (TowerComponent load path owned by Save & Persistence, not GameDataRegistry)
- ADR-0006 — Monster movement (MonsterDamageTaken Resource type established; MonsterResource used as entity data source)
- ADR-0008 — Tower placement gate (`duplicate_deep()` for TowerComponent mission isolation)
