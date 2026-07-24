# S4-02 — GameDataRegistry Autoload

**Story ID**: S4-02
**Epic**: Foundation
**Layer**: Foundation
**Type**: Integration
**Owner**: engine-programmer
**Sprint**: 4
**Estimate**: 1.5 days (revised from 1.0 day during `/story-readiness` — original
estimate didn't account for `TowerPerkRegistry` not existing yet and
`MonsterResource` needing a new `validate()` method; see Gaps found 2026-07-03)
**Status**: Complete
**Manifest Version**: 2026-05-16

## Context

**GDD**: None — this is an ADR-only requirement, same situation as S4-01. Not
present in `design/gdd/systems-index.md`. Requirements below are sourced
directly from ADR-0009's "GameDataRegistry Autoload" section.

**Requirement**: No TR-ID exists for this system. Track by ADR reference only.

**ADR Governing Implementation**: `docs/architecture/adr-0009-resource-data-model.md` (Accepted 2026-05-24)

**ADR Decision Summary**: GameDataRegistry is Autoload #5 (shifting SceneManager
to #6). At `_ready()` it scans `res://assets/data/monsters/` for every `.tres`
file, loads each as a `MonsterResource` keyed by `resource.monster_id`, calls
`validate()` on each and `push_error()`s per invalid field (does not abort),
then preloads and validates `res://assets/data/towers/perk_registry.tres` as a
`TowerPerkRegistry`. It exposes exactly two public methods —
`get_monster_resource(monster_id) -> MonsterResource` (nullable) and
`get_perk_registry() -> TowerPerkRegistry` (always non-null after `_ready()`).
No other system may access `MonsterResource` or `TowerPerkRegistry` by path
directly — all lookups go through GameDataRegistry.

**Engine**: Godot 4.6.2 | **Risk**: LOW — `DirAccess.get_files_at()`,
`ResourceLoader.load()`, and Autoload registration are stable APIs unchanged
through 4.6. No post-cutoff API risk.

**Engine Notes**: `DirAccess.get_files_at()` is the confirmed API for directory
scanning in Godot 4.x (not the older `Directory` singleton, deprecated pre-4.0).

**Control Manifest Rules (Foundation layer)**:
- Required: All `MonsterResource`/`TowerPerkRegistry` lookups go through
  `GameDataRegistry` — no other system loads these by path directly
- Required: `validate()` is called on every loaded resource at boot;
  invalid entries are logged via `push_error()`, not silently dropped, and do
  not abort boot
- Forbidden: GameDataRegistry loading `TowerComponent` files (FoundationComponent,
  WeaponComponent, FocusComponent, PowerComponent) — those are owned by Save &
  Persistence at Sanctuary load time, not by GameDataRegistry
- **Note**: same control-manifest staleness caveat as S4-01 — ADR-0009 is authoritative.

## Dependencies

- ADR-0004 (Pathfinding) — Accepted, satisfied (Sprint 2). GameDataRegistry
  boots at position 5, immediately after Pathfinding at position 4.

## Files to Create

- `src/core/game_data_registry.gd` — GameDataRegistry autoload
- `src/core/tower/tower_perk_registry.gd` — **new**: `TowerPerkRegistry` Resource
  subclass did not exist anywhere in the codebase prior to this story (verified by
  grep — only referenced in architecture docs). Schema per `design/gdd/tower.md`
  Rule 12a: maps `perk_type: String → {label: String, description: String,
  archetype_restrictions: Array[String]}`. Minimal MVP scope — just enough for
  `GameDataRegistry` to load, validate, and expose it; full perk-application logic
  belongs to the Tower System, not this story.
- `assets/data/towers/perk_registry.tres` — **new**: one sample `TowerPerkRegistry`
  instance populated with the 4 MVP perk types from tower.md Rule 12a
  (`DAMAGE_BOOST`, `RANGE_BOOST`, `SPEED_BOOST`, `AURA_EXTEND`), sufficient to
  prove the loader works. Full perk content authoring beyond these 4 entries is
  out of scope.
- `assets/data/monsters/goblin_runner.tres` — **new**: one sample `MonsterResource`
  instance, sufficient to prove the loader works. Full monster roster authoring
  is out of scope (separate content-production task).
- **Modify** `src/core/monster/monster_resource.gd` (from S3-02) — add
  `validate() -> Array[String]` method. This did not exist prior to this story
  (verified by grep) but `GameDataRegistry`'s design (ADR-0009) requires calling
  it on every loaded `MonsterResource`.
- `tests/unit/game_data_registry/game_data_registry_test.gd`

## Acceptance Criteria

- [ ] AC-1: `GameDataRegistry` registers as Autoload #5 in `project.godot`,
      immediately after `GPathfindingSystem` (#4) and before `GSceneManager` (#6)
- [ ] AC-2: `_ready()` loads every `.tres` file in `res://assets/data/monsters/`
      as a `MonsterResource`, keyed by `resource.monster_id`
- [ ] AC-3: `_ready()` calls `validate()` on each loaded `MonsterResource`;
      any non-empty result is logged via `push_error()` per invalid field, but
      boot does not abort
- [ ] AC-4: `_ready()` preloads `res://assets/data/towers/perk_registry.tres`
      as `TowerPerkRegistry` and validates it the same way
- [ ] AC-5: `get_monster_resource(monster_id: StringName) -> MonsterResource`
      returns the correct resource for a known ID, and `null` for an unknown ID
- [ ] AC-6: `get_perk_registry() -> TowerPerkRegistry` is always non-null after
      `_ready()` completes
- [ ] AC-7: GameDataRegistry does not appear in the scene tree during
      WAVE_ACTIVE (Autoload lifetime check — it's a pure data cache, no
      per-frame processing)
- [ ] AC-8: GameDataRegistry does NOT load `TowerComponent` files
      (FoundationComponent, WeaponComponent, FocusComponent, PowerComponent) —
      confirmed by source inspection, those paths are untouched by this Autoload

## Implementation Notes (from ADR-0009)

```gdscript
# GameDataRegistry (Autoload — boot position 5)

func _ready() -> void:
    _load_monster_resources()
    _load_perk_registry()

func _load_monster_resources() -> void:
    var dir_path := "res://assets/data/monsters/"
    for file_name in DirAccess.get_files_at(dir_path):
        if not file_name.ends_with(".tres"):
            continue
        var resource: MonsterResource = ResourceLoader.load(dir_path + file_name)
        var errors: Array[String] = resource.validate()
        for err: String in errors:
            push_error("[GameDataRegistry] %s: %s" % [file_name, err])
        _monster_resources[resource.monster_id] = resource

func _load_perk_registry() -> void:
    _perk_registry = ResourceLoader.load("res://assets/data/towers/perk_registry.tres")
    var errors: Array[String] = _perk_registry.validate()
    for err: String in errors:
        push_error("[GameDataRegistry] perk_registry.tres: %s" % err)

func get_monster_resource(monster_id: StringName) -> MonsterResource:
    return _monster_resources.get(monster_id, null)

func get_perk_registry() -> TowerPerkRegistry:
    return _perk_registry
```

**Validation contract**: every persistent data Resource subclass implements
`validate() -> Array[String]` returning a list of error strings (empty = valid).
This is a project-wide convention shared with Wave Manager's `WaveConfig.validate()`
and Save & Persistence's per-component `validate()` calls — GameDataRegistry does
not invent a new validation pattern, it reuses the existing one.

**Invalid-resource-at-spawn-time mitigation** (per ADR-0009 Risks section): if
`validate()` found errors at boot but the game proceeded, `get_monster_resource()`
still returns the invalid Resource — callers must treat a non-null but
unvalidated resource defensively. MonsterSystem's spawn logic should abort the
spawn and log a system error if `get_monster_resource()` returns `null`.

### `MonsterResource.validate()` (new method — added by this story)

```gdscript
# Added to src/core/monster/monster_resource.gd
func validate() -> Array[String]:
    var errors: Array[String] = []
    if monster_id == &"":
        errors.append("monster_id must not be empty")
    if base_hp <= 0.0:
        errors.append("base_hp must be > 0 (got %.2f)" % base_hp)
    if base_speed <= 0.0:
        errors.append("base_speed must be > 0 (got %.2f)" % base_speed)
    if tier == 2:  # BOSS
        if base_damage <= 0.0:
            errors.append("BOSS tier requires base_damage > 0")
        if base_attack_interval <= 0.0:
            errors.append("BOSS tier requires base_attack_interval > 0")
        if boss_attack_range_cells <= 0:
            errors.append("BOSS tier requires boss_attack_range_cells > 0")
    return errors
```

### `TowerPerkRegistry` (new Resource class — added by this story)

Schema per `design/gdd/tower.md` Rule 12a: maps `perk_type` (String) to a
`{label, description, archetype_restrictions}` entry. Minimal MVP form —
this story only needs enough structure for `GameDataRegistry` to load and
validate it; a Dictionary-based `@export var perks: Dictionary` is sufficient
rather than a nested Resource-per-entry structure, since the Tower System
(not this story) is what consumes individual perk entries at runtime.

```gdscript
# src/core/tower/tower_perk_registry.gd
class_name TowerPerkRegistry
extends Resource

## Maps perk_type (String, e.g. "DAMAGE_BOOST") to its display/validity data.
## Schema: design/gdd/tower.md Rule 12a.
## entries[perk_type] = { "label": String, "description": String,
##                         "archetype_restrictions": Array[String] }
@export var entries: Dictionary = {}

const VALID_PERK_TYPES: Array[String] = [
    "DAMAGE_BOOST", "RANGE_BOOST", "SPEED_BOOST", "AURA_EXTEND"
]

func validate() -> Array[String]:
    var errors: Array[String] = []
    for perk_type: String in VALID_PERK_TYPES:
        if not entries.has(perk_type):
            errors.append("Missing required perk_type entry: %s" % perk_type)
            continue
        var entry: Dictionary = entries[perk_type]
        if not entry.has("label") or String(entry["label"]) == "":
            errors.append("%s: missing or empty label" % perk_type)
        if not entry.has("archetype_restrictions"):
            errors.append("%s: missing archetype_restrictions" % perk_type)
    return errors
```

## Out of Scope

- `TowerComponent` files (FoundationComponent, WeaponComponent, FocusComponent,
  PowerComponent) — owned by Save & Persistence at Sanctuary load time, not this story
- `WaveConfig` loading — Wave Manager loads its own `WaveConfig.tres` via
  `ResourceLoader.load()` directly (per-mission, passed in by the Mission Scene),
  not through GameDataRegistry
- Full monster roster / perk content authoring beyond the one sample
  `MonsterResource` and one sample `TowerPerkRegistry` (with its 4 MVP perk
  entries) needed to prove the loaders work — bulk content authoring is a
  separate, ongoing content-production task
- Tower System's actual perk-application logic (DAMAGE_BOOST/RANGE_BOOST/etc.
  effects on a placed tower) — `TowerPerkRegistry` as defined here only stores
  display/validity data; applying perk effects is Tower System's job
- Equip-time SPEED_BOOST validation (tower.md Rule 12a's "Foundation-plus-Weapon
  combination exceeds 4.0" check) — that fires when a full 4-slot loadout is
  assembled in the Sanctuary, not at `GameDataRegistry` boot time

## QA Test Cases

- **AC-1**: Autoload registration order
  - Given: `project.godot`
  - When: `[autoload]` section is read
  - Then: `GGameDataRegistry` appears immediately after `GPathfindingSystem` and before `GSceneManager`

- **AC-2/AC-5**: Monster resource loading and lookup
  - Given: one sample `MonsterResource` `.tres` authored at `res://assets/data/monsters/goblin_runner.tres` with `monster_id = &"goblin_runner"`
  - When: `_ready()` runs, then `get_monster_resource(&"goblin_runner")` is called
  - Then: returns the correct MonsterResource
  - Edge cases: `get_monster_resource(&"nonexistent")` returns `null`

- **AC-3**: Validation logging without abort
  - Given: a `MonsterResource` `.tres` with a deliberately invalid field (e.g. negative `base_hp`)
  - When: `_ready()` runs
  - Then: `push_error()` is called with a message identifying the file and the invalid field; `_ready()` still completes (boot does not abort)

- **AC-4/AC-6**: Perk registry preload
  - Given: `res://assets/data/towers/perk_registry.tres` exists (sample authored)
  - When: `_ready()` runs
  - Then: `get_perk_registry()` returns non-null
  - Edge cases: if the file is missing, `_ready()` still completes without crashing (logs an error) — `get_perk_registry()` may return null in that specific failure case; document this exception explicitly in the implementation

- **AC-7**: Autoload lifetime check
  - Given: a live scene tree with GameDataRegistry booted
  - When: the scene tree is inspected during a simulated WAVE_ACTIVE phase
  - Then: GameDataRegistry is present as an Autoload node (root-level), with no per-frame `_process`/`_physics_process` override doing per-frame work

- **AC-8**: TowerComponent isolation (static/structural check)
  - Given: `src/core/game_data_registry.gd`
  - When: source is inspected
  - Then: no reference to `FoundationComponent`, `WeaponComponent`, `FocusComponent`, or `PowerComponent` paths exists anywhere in the file

- **`MonsterResource.validate()`** (new method):
  - Given: a `MonsterResource` with `monster_id = &""`
  - When: `validate()` is called
  - Then: returns an array containing an error about empty `monster_id`
  - Edge cases: `base_hp = 0.0` → error; `tier = 2` (BOSS) with `base_damage = 0.0` → error; a fully valid STANDARD-tier resource → empty array

- **`TowerPerkRegistry.validate()`** (new class):
  - Given: a `TowerPerkRegistry` missing an `entries["SPEED_BOOST"]` key
  - When: `validate()` is called
  - Then: returns an array containing "Missing required perk_type entry: SPEED_BOOST"
  - Edge cases: all 4 required perk types present with valid `label` and `archetype_restrictions` → empty array; an entry present but with an empty `label` → error

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/game_data_registry/game_data_registry_test.gd` — AC-1 through AC-8
- Test coverage for `MonsterResource.validate()` and `TowerPerkRegistry.validate()`
  may live in the same file or in `tests/unit/monster/` and `tests/unit/tower/`
  respectively, following existing project convention for per-system test placement

**Status**: [ ] Not yet created

## Dependencies

- Depends on: None — this is a Foundation-layer building block with no dependency on other Sprint 4 work
- Unlocks: S4-01 (SceneManager — boot order requires GameDataRegistry complete first), S4-03 (Hero Stat Resolution — Hero reads MonsterResource data for target archetype tags via GameDataRegistry-populated caches)

## Completion Notes
**Completed**: 2026-07-03
**Criteria**: 8/8 passing (AC-1 through AC-8), plus both embedded `validate()` test-case sections. 30/30 automated tests passing, 0 errors, 0 failures.
**Deviations**: Advisory only — AC-1's text says "before `GSceneManager`," which doesn't exist yet; actual implementation correctly places `GGameDataRegistry` before the already-registered `GWaveManager` instead (verified architecturally correct). S4-01 will need to insert itself between the two when implemented. TD-test-001 (orphan-node warnings on an `assert_error` pattern, already logged, 0 test failures).
**Test Evidence**: Integration — `tests/unit/game_data_registry/game_data_registry_test.gd` (13 tests), `tests/unit/monster/monster_resource_validate_test.gd` (10 tests), `tests/unit/tower/tower_perk_registry_test.gd` (7 tests) — 30 total, all passing.
**Code Review**: Complete — 3 Required Changes found and fixed (TowerPerkRegistry.validate() crash-on-malformed-input, silent missing-directory failure, 2 missing regression tests), re-reviewed, verdict APPROVED.
