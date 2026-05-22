# Control Manifest

> **Engine**: Godot 4.6.2
> **Last Updated**: 2026-05-16
> **Manifest Version**: 2026-05-16
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004
> **Status**: Active — regenerate with `/create-control-manifest` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed
this date when created. `/story-readiness` compares a story's embedded version
to this field to detect stories written against stale rules. Always matches
`Last Updated` — they are the same date, serving different consumers.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine initialisation,
pathfinding system infrastructure*

### Required Patterns

**EventBus**

- **Declare all 70 cross-system signals in a single `EventBus` GDScript Autoload** — source: ADR-0001
- **Connect to EventBus signals in `_ready()`** — source: ADR-0001
- **Disconnect from EventBus signals in `_exit_tree()`** — this is mandatory; omitting it causes "call to freed object" crashes — source: ADR-0001
- **EventBus owns no game state — it is a pure dispatcher** — source: ADR-0001
- **Synchronous dispatch is the default for non-physics callers**: `EventBus.signal_name.emit(args)` — source: ADR-0001 Rule 1
- **Physics callers must use deferred dispatch**: `EventBus.signal_name.emit.call_deferred(args)` — applies inside `_physics_process`, `area_body_entered`, and similar physics callbacks — source: ADR-0001 Rule 2
- **Level-1 cascade emitters must also use deferred dispatch** — any subscriber that emits a further event must emit it deferred to avoid cascade cost stacking — source: ADR-0001 Rule 2
- **Events with 1–4 data fields: typed parameters directly on signal** — e.g. `signal wave_started(wave_number: int, total_waves: int, wave_difficulty: float)` — source: ADR-0001 Rule 3
- **Events with 5+ data fields: package payload into a custom `Resource` subclass** — e.g. `signal monster_died(payload: MonsterDiedEvent)` — source: ADR-0001 Rule 3
- **Cascade depth cap: maximum 2 levels** — a subscriber of a Level-1 cascade may not emit a further event — source: ADR-0001 Rule 4
- **Batch events at ≥ 20 firings per frame**: switch to a single deferred `{event_name}_batch` event with `Array[Resource]` payload — source: ADR-0001 Rule 5
- **Wave Manager owns the `monster_died` batch accumulator** — EventBus remains a pure dispatcher — source: ADR-0001 Rule 5

**Autoload Boot Order**

- **5-Autoload boot order is a build invariant** set in Project Settings → Autoloads before creating any scene:

  | Order | Autoload | Script |
  |-------|----------|--------|
  | 1 | `EventBus` | `src/core/event_bus.gd` |
  | 2 | `SavePersistence` | `src/core/save_persistence.gd` |
  | 3 | `Grid` | `src/core/grid.gd` |
  | 4 | `Pathfinding` | `src/core/pathfinding.gd` |
  | 5 | `SceneManager` | `src/core/scene_manager.gd` |

  — source: ADR-0002

- **Adding any new Autoload requires an ADR revision** to verify boot dependency ordering — source: ADR-0002
- **SceneManager publishes `scene_transition_started` before unloading the current scene** and `scene_transition_completed` after the new scene is ready — source: ADR-0002
- **SceneManager only initiates transitions in response to terminal mission events** (`mission_complete`, `hero_died`) — source: ADR-0002

**Save & Persistence**

- **Save file format: `store_32(CURRENT_FORMAT_VERSION)` as 4-byte header, then `store_var(data, false)` for the master Dictionary** — source: ADR-0003
- **Every `FileAccess.store_*()` call must check its `bool` return value** — these methods changed from `void` to `bool` in Godot 4.4; unchecked failures cause silent data corruption — source: ADR-0003
- **Atomic write pattern: write to `.tmp` first, then `DirAccess.rename(.tmp → .dat)`** — a crash mid-write must never produce a half-written `.dat` file — source: ADR-0003
- **Always use `store_var(data, false)`** — `full_objects = false` prevents Resource script paths from being embedded and breaking on file renames — source: ADR-0003
- **`get_save_data()` must return only primitives**: `int`, `float`, `bool`, `String`, `Array` (elements primitive), `Dictionary` (String keys, primitive values) — source: ADR-0003
- **`SavePersistence._ready()` scans `user://` for any `.tmp` files and deletes them** — a surviving `.tmp` means a prior crash; the `.dat` is the last good save — source: ADR-0003
- **Version migration uses sequential `_migrate_vN_to_vN+1()` functions** — migrations are append-only; never delete keys (mark unused with `_deprecated_` prefix) — source: ADR-0003
- **Migration unit tests are BLOCKING** — a migration function without a passing test cannot be merged (coding standards mandate this) — source: ADR-0003

**Pathfinding System**

- **Use `AStar2D` for all route computation** — one `AStar2D` instance per SPAWN cell — source: ADR-0004
- **Pre-compute route templates at SCOUT phase start**, after `GridConfig` is applied and before player tower placement — source: ADR-0004
- **`RouteTemplate` structure must contain `path: Array[Vector2i]` and `cell_index_map: Dictionary`** — `cell_index_map` provides O(1) reverse lookup from cell to path index — source: ADR-0004
- **Super-goal node: `SUPER_GOAL_ID = grid_cols × grid_rows`** — add to each `AStar2D` instance with `weight_scale = 0.0`; connect all GOAL cells to it (one-directional); run A* to `SUPER_GOAL_ID` then strip it from the result — source: ADR-0004
- **Subclass `AStar2D` in GDScript to override `_estimate_cost()`** — when `to_id == SUPER_GOAL_ID`, return `min(manhattan(cell_at(from_id), g) for g in goal_cells)` — source: ADR-0004
- **Assert at startup: `SUPER_GOAL_ID` never collides with any real cell ID** — the last valid real cell ID is `grid_cols × grid_rows − 1`; SUPER_GOAL_ID is always one past it — source: ADR-0004
- **Deferred dirty rebuild**: on tower event, mark affected templates dirty via `cell_index_map` lookup, then call `call_deferred("_rebuild_dirty_templates")` — source: ADR-0004
- **Batch multiple tower events in the same frame** — union their footprints and run one A* rebuild per SPAWN — source: ADR-0004
- **Emit `templates_ready(spawn_count, build_duration_ms)` via EventBus** after initial template build — this gates WaveManager from spawning — source: ADR-0004
- **Cell cost model**:

  | Cell Type | `weight_scale` |
  |-----------|---------------|
  | PATH | 1.0 |
  | SPAWN | 1.0 |
  | GOAL | 1.0 |
  | PLACEABLE (unoccupied) | 10.0 |
  | Tower (occupied PLACEABLE) | Disabled: `astar.set_point_disabled(id, true)` |

  — source: ADR-0004

- **`would_block_all_paths(footprint)` must use a temporary copy of the walkability map** — build temp `AStar2D` instances, return bool, never mutate cached template state — source: ADR-0004

### Forbidden Approaches

- **Never use untyped `Dictionary` payloads for signal parameters** — source: ADR-0001 Rule 3
- **Never emit a Level-1 cascade event synchronously** — it must be deferred to prevent frame budget overrun at peak wave volume — source: ADR-0001 Rule 2
- **Never implement cross-system communication via direct node-to-node signal connections** — creates brittle runtime Node references between systems — source: ADR-0001 (Alt A rejected)
- **Never use a message queue or object pooling pattern for event dispatch** — over-engineered for this scale; adds one-frame delay that breaks all GDD timing assumptions — source: ADR-0001 (Alt B rejected)
- **Never emit cascade events at depth 3+** — this is a design error, caught in design review — source: ADR-0001 Rule 4
- **Never add a 6th+ Autoload without an ADR revision** — risks systems subscribing to EventBus before it exists — source: ADR-0002
- **Autoloads must not own per-mission state** (wave count, spawn queue, phase) — per-mission state belongs in the mission scene — source: ADR-0002 (Alt C rejected)
- **Never embed `Resource` objects in `get_save_data()` output** — `store_var(data, false)` will silently drop or null them — source: ADR-0003
- **Never use `Vector2i`, `Vector2`, or `Vector3` directly in save data** — serialise as `Array[int]` or `Array[float]` instead — source: ADR-0003
- **Never use `Color` directly in save data** — serialise as `[float, float, float, float]` Array — source: ADR-0003
- **Never use `NodePath` or `Object` references in save data** — source: ADR-0003
- **Never use `store_var(data, true)`** — `full_objects = true` embeds script paths that break on file renames — source: ADR-0003
- **Never use JSON (`store_string` + `JSON.stringify`) for save format** — silently drops non-JSON types; worse error reporting — source: ADR-0003 (Alt A rejected)
- **Never use `ConfigFile` for save format** — flat key-value model cannot express nested save data without boilerplate — source: ADR-0003 (Alt B rejected)
- **Never use `NavigationServer2D` or `NavigationAgent2D` for monster routing** — significant API changes in Godot 4.0/4.2 (post-cutoff risk HIGH); per-monster path queries exceed frame budget at 100+ monsters — source: ADR-0004 (Alt A rejected)
- **Never rebuild route templates during `WAVE_ACTIVE`** — tower writes are locked by Grid during active waves — source: ADR-0004
- **Never mutate cached template state inside `would_block_all_paths()`** — it must be a pure read using a temp copy — source: ADR-0004

### Performance Guardrails

- **Total EventBus processing per frame: max 1.667 ms** (10% of 16.67 ms @ 60 FPS) — source: ADR-0001
- **Batch threshold: > 20 firings per frame per event type** — switch to `_batch` event — source: ADR-0001
- **Max cascade depth: 2 levels** — depth 3+ is a design error — source: ADR-0001
- **SCOUT start template build: < 1 ms total** at MVP (1 SPAWN, 16×12 grid) — source: ADR-0004
- **Tower placement A*: ~0.02 ms per SPAWN** at MVP — source: ADR-0004
- **Peak save allocation: < 1 MB** for MVP scope — source: ADR-0003

---

## Core Layer Rules

*Applies to: Hero entity, Monster entity, physics/collision, `get_path()` API usage during WAVE_ACTIVE*

### Required Patterns

- **Hero scene root: `CharacterBody2D`** — required for `move_and_slide()` physics-integrated movement — source: ADR-0002
- **Hero movement: `move_and_slide()` in `_physics_process()`** — source: ADR-0002
- **Hero input polling and attack timing: `_process()`** — source: ADR-0002
- **Hero attack range detection via a child `Area2D`** — not the `CharacterBody2D` root — source: ADR-0002
- **Monster scene root: `Area2D`** — position-based movement; no velocity, no `move_and_slide()` — source: ADR-0002
- **Monster position update: advance directly in `_physics_process()`** by reading the next step from its route template — source: ADR-0002
- **Monster `_pending_damage` buffer flush and position advance in the same `_physics_process()` call** — source: ADR-0002
- **Monsters use `get_path(from_cell, tier)` for route lookup** — O(1) template lookup + O(k) slice; no A* computation during WAVE_ACTIVE — source: ADR-0004
- **Monsters refresh their local path copies after receiving `path_invalidated` via EventBus** — source: ADR-0004
- **`would_block_all_paths(footprint)` is called only at tower placement confirmation** (on click/release), not on hover — source: ADR-0004

### Forbidden Approaches

- **Never use `CharacterBody2D` as the Monster scene root** — Jolt overhead for 100+ dynamic bodies exceeds the frame budget — source: ADR-0002 (Alt B rejected)
- **Never use `move_and_slide()` for monster movement** — position-based movement on discrete cell steps fights continuous physics integration — source: ADR-0002
- **Never run per-monster A* queries** — use route template lookup; 100 on-demand A* runs per placement event consumes the entire frame budget — source: ADR-0004 (Alt B rejected)
- **Never call `would_block_all_paths()` on hover or per-frame** — build cost is ~0.05–0.1 ms; at 60 hover events/second this spikes the frame budget — source: ADR-0004

### Performance Guardrails

- **100+ simultaneous `Area2D` monster instances must operate within frame budget at 60 FPS** on minimum-spec PC hardware — source: ADR-0002
- **`get_path()` allocation hotspot: ~2 500 `Vector2i` copies per frame** at 100 monsters × avg 25-cell slice — profile during prototyping; if allocation pressure is observed, refactor to return `(template_ref, start_index)` — source: ADR-0004
- **`would_block_all_paths()` cost: ~0.05–0.1 ms per call** — placement confirmation only, never per-frame — source: ADR-0004

---

## Feature Layer Rules

*Applies to: WaveManager spawn gating, tower placement gate, MVP SPAWN constraint*

### Required Patterns

- **WaveManager must implement a `_routes_ready: bool` flag** that stays `false` until `templates_ready` fires — source: ADR-0004
- **WaveManager must not emit `monster_spawn_requested` before `templates_ready`** — the `_routes_ready` flag enforces this gate — source: ADR-0004
- **WaveManager subscribes to `templates_ready` via EventBus to set `_routes_ready = true`** — source: ADR-0004
- **WaveManager owns the `monster_died` batch accumulator** — it collects individual events and emits `monster_died_batch` when the threshold is exceeded; EventBus does not accumulate — source: ADR-0001
- **MVP missions must use exactly one SPAWN cell** — the Voronoi partition (`_spawn_assignment`) is computed regardless, but multi-SPAWN missions are post-MVP — source: ADR-0004
- **Mission loading must validate SPAWN and GOAL cell counts before entering SCOUT** — a CI validator is required (GDD AC-13) to catch misconfigured missions before they hang — source: ADR-0004

### Forbidden Approaches

- **Never ship an MVP mission with more than one SPAWN cell** — multi-SPAWN is explicitly post-MVP — source: ADR-0004
- **Never implement WaveManager as an Autoload** — WaveManager owns per-mission state (wave count, spawn queue, phase) that must reset on mission restart — source: ADR-0002 (Alt C rejected)
- **Never allow SceneManager to hold direct references to scene-instanced nodes** beyond the lifetime of the active scene — source: ADR-0002

---

## Presentation Layer Rules

*Applies to: rendering, audio, UI, VFX, shaders, animations*

No ADR-sourced rules yet. Global engine reference entries below apply.

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `HeroManager`, `TowerComponent` |
| Variables / Functions | snake_case | `move_speed`, `take_damage()` |
| Signals / Events | snake_case, past tense | `health_changed`, `wave_completed` |
| Files | snake_case matching class | `hero_manager.gd` |
| Scenes | PascalCase matching root node | `HeroManager.tscn`, `TowerInstance.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH`, `BASE_CRIT_MULTIPLIER` |

### Performance Budgets

| Target | Value |
|--------|-------|
| Framerate | 60 FPS |
| Frame budget | 16.67 ms |
| Draw calls | 200 per frame |
| Memory ceiling | 1 GB |

### Approved Libraries / Addons

- GUT (gdUnit4) — approved for all automated testing

### Forbidden APIs (Godot 4.6.2)

These APIs are deprecated or replaced in Godot 4.x. Using them is a review blocker.

**Nodes & Classes**

| Forbidden | Use Instead | Deprecated Since |
|-----------|-------------|-----------------|
| `TileMap` | `TileMapLayer` | 4.3 |
| `VisibilityNotifier2D` | `VisibleOnScreenNotifier2D` | 4.0 |
| `VisibilityNotifier3D` | `VisibleOnScreenNotifier3D` | 4.0 |
| `YSort` | `Node2D.y_sort_enabled` | 4.0 |
| `Navigation2D` / `Navigation3D` | `NavigationServer2D` / `NavigationServer3D` | 4.0 |
| `EditorSceneFormatImporterFBX` | `EditorSceneFormatImporterFBX2GLTF` | 4.3 |

**Methods & Properties**

| Forbidden | Use Instead | Deprecated Since |
|-----------|-------------|-----------------|
| `yield()` | `await signal` | 4.0 |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 |
| `instance()` | `instantiate()` | 4.0 |
| `PackedScene.instance()` | `PackedScene.instantiate()` | 4.0 |
| `get_world()` | `get_world_3d()` | 4.0 |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 |
| `duplicate()` for nested resources | `duplicate_deep()` | 4.5 |
| `Skeleton3D.bone_pose_updated` signal | `skeleton_updated` | 4.3 |
| `AnimationPlayer.method_call_mode` | `AnimationMixer.callback_mode_method` | 4.3 |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | 4.3 |

**Forbidden Patterns**

| Forbidden Pattern | Use Instead | Reason |
|-------------------|-------------|--------|
| String-based `connect()` | Typed signal connections | Not type-safe; breaks on rename |
| `$NodePath` in `_process()` | `@onready var` cached reference | Path lookup overhead every frame |
| Untyped `Array` / `Dictionary` | `Array[Type]`, typed variables | Loses GDScript compiler optimisations |
| `Texture2D` in shader parameters | `Texture` base type | Changed in Godot 4.4 |
| Manual post-process viewport chains | `Compositor` + `CompositorEffect` | Structured post-processing since 4.3 |
| GodotPhysics3D for new projects | Jolt Physics 3D | Default since 4.6; better stability |

*Source: `docs/engine-reference/godot/deprecated-apis.md`*

### Cross-Cutting Constraints

- **All game code must include doc comments on public APIs** — coding standards
- **Gameplay values must be data-driven (external config), never hardcoded** — coding standards
- **All public methods must be unit-testable via dependency injection** — no singleton coupling in testable code — coding standards
- **Commits must reference the relevant design document or task ID** — coding standards
- **No system holds a direct runtime Node reference to any other system** — all cross-system communication goes through EventBus — source: ADR-0001
- **Autoload singletons have no access modifiers in GDScript** — convention and code review are the only enforcement mechanisms — source: ADR-0002
