# Control Manifest

> **Engine**: Godot 4.6.2
> **Last Updated**: 2026-07-13
> **Manifest Version**: 2026-07-13b
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011, ADR-0012, ADR-0013, ADR-0014, ADR-0015, ADR-0016, ADR-0017, ADR-0018, ADR-0019
> **Status**: Active — regenerate with `/create-control-manifest` when ADRs change. ADR-0019's rules are now fully broken out below (Feature Layer).

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
pause system, collision-layer convention*

### Required Patterns

**EventBus**

- Declare all cross-system signals (currently 74) in a single `EventBus` GDScript Autoload — source: ADR-0001
- Connect to EventBus signals in `_ready()`; disconnect in `_exit_tree()` (mandatory — omitting it causes "call to freed object" crashes) — source: ADR-0001
- EventBus owns no game state — it is a pure dispatcher — source: ADR-0001
- Synchronous dispatch is the default for non-physics callers: `EventBus.signal_name.emit(args)` — source: ADR-0001 Rule 1
- Physics callers use deferred dispatch: `EventBus.signal_name.emit.call_deferred(args)` — source: ADR-0001 Rule 2
- When *guaranteed next-frame* (not end-of-current-frame) delivery is required, use `await get_tree().process_frame` before emitting instead of `call_deferred` — both are approved mechanisms; choose based on required delivery timing — source: ADR-0001 Rule 2 (amended), ADR-0007
- Level-1 cascade emitters must also use deferred dispatch — source: ADR-0001 Rule 2
- Events with 1–4 fields: typed parameters directly on the signal. Events with ≥5 fields: package the payload into a custom `Resource` subclass — source: ADR-0001 Rule 3
- Cascade depth cap: maximum 2 levels (a Level-1 subscriber's own emission may not itself cascade further) — source: ADR-0001 Rule 4
- Batch at ≥20 firings/frame: switch to a single deferred `{event_name}_batch` event with an `Array[Resource]` payload — source: ADR-0001 Rule 5
- **Documented exception**: `MonsterManager` emits `monster_died`, `monster_breached`, `boss_died`, `monster_cell_entered` synchronously from `_physics_process` (audited 2026-07-08 — no shipped subscriber reads `MonsterManager`'s live collections mid-mutation). Do not treat this as a template for new code; re-justify per-case — source: ADR-0001 Amendment 2026-07-08

**Scene / Autoload Structure**

- Autoload boot order is a build invariant: `EventBus(1), SavePersistence(2), Grid(3), Pathfinding(4), GameDataRegistry(5), SceneManager(6), WaveManager(7), MissionEconomy(8)` — source: ADR-0002, ADR-0009, ADR-0012, ADR-0018
- Adding any new Autoload requires an ADR revision to verify boot dependency ordering — source: ADR-0002
- Hero: `CharacterBody2D` scene root, `move_and_slide()` for physics-integrated movement — source: ADR-0002
- Monster: `Area2D` scene root, position-based movement (`global_position` set directly, no velocity/`move_and_slide()`) — source: ADR-0002, ADR-0006
- SceneManager only initiates SANCTUARY↔MISSION transitions in response to terminal mission events (`mission_complete`, `hero_died`) — never mid-wave — source: ADR-0002

**Save & Persistence**

- Save format: `store_32(CURRENT_FORMAT_VERSION)` header, then `store_var(data, false)` for the master Dictionary — source: ADR-0003
- Check the `bool` return of every `FileAccess.store_32()`/`store_var()`/`store_string()`/`store_buffer()` call — Godot 4.4+ changed these from `void` to `bool` — source: ADR-0003
- `get_save_data()` must return **only** primitives: `int`, `float`, `bool`, `String`, `Array` (primitive elements), `Dictionary` (`String` keys, primitive values) — source: ADR-0003
- Atomic write: write to `.tmp`, then `DirAccess.rename()` to the final `.dat` path — never write `.dat` directly — source: ADR-0003
- Every migration function (`_migrate_vN_to_vN+1`) requires a passing unit test — **BLOCKING**, cannot merge without it — source: ADR-0003
- On startup, delete any stray `.tmp` files before attempting a load (crash-recovery cleanup) — source: ADR-0003

**Grid System**

- Two typed internal structures: `_cell_types: Dictionary[Vector2i, CellType]` (static per mission) and `_occupancy: Dictionary[Vector2i, int]` (mutable during `ACTIVE_WRITABLE`) — source: ADR-0005
- Read API is a documented direct-call exception to EventBus-only (per-frame spatial queries are too expensive to route through EventBus) — source: ADR-0005
- Write API (`place_tower()`, `remove_tower()`) is callable only by Tower System — source: ADR-0005
- All array/Dictionary-returning read functions must return **copies** (`.duplicate()`), never internal references — source: ADR-0005
- `world_to_cell()` uses `floor()`, not integer truncation — required for correct behavior at negative world positions — source: ADR-0005
- Grid state machine (`UNINITIALIZED → ACTIVE_WRITABLE → ACTIVE_READONLY`) is driven exclusively by the `mission_phase_changed` EventBus subscription — source: ADR-0005

**Pause System**

- `SceneTree.paused` (`get_tree().paused`) is the single source of truth for "the game is paused" — no parallel custom pause flag — source: ADR-0014
- The Pause Menu `CanvasLayer` must set `process_mode = Node.PROCESS_MODE_ALWAYS` — it is the only process-mode override in the codebase — source: ADR-0014
- Any future `SceneTree.create_timer()` call for a gameplay-relevant duration **must** pass `process_always: false` explicitly (the parameter defaults to `true`, i.e. ignores pause) — standing rule, not a one-off fix — source: ADR-0014
- `game_paused`/`game_unpaused` EventBus signals are informational only — no system may gate its own `_process`/`_physics_process`/Timer logic on them; `SceneTree.paused` already does that natively — source: ADR-0014

**Collision Layer Convention**

- Layer 1 = Environment (BLOCKED-cell tilemap collision, tower physics bodies — not yet built). Layer 2 = Hero (`collision_layer=2`, `collision_mask=1`) — source: ADR-0015
- Any future physics body that Hero must be blocked by must use layer 1 (`Hero.COLLISION_LAYER_ENVIRONMENT`) — do not invent a new layer number — source: ADR-0015

### Forbidden Approaches

- **Never hold a direct Node reference to another system at runtime** (`direct_cross_system_node_reference`) — breaks cross-system isolation and testability — source: ADR-0001
- **Never use untyped `Dictionary` as an EventBus signal payload** (`dictionary_event_payload`) — loses type safety and compiler optimisations — source: ADR-0001
- **Never emit a synchronous Level-1 EventBus cascade** (`synchronous_level1_cascade`) — multiplies frame cost by `(1 + D × S_avg)`; at peak wave volume this alone can consume 50% of the EventBus frame budget — source: ADR-0001
- **Never call `SceneTree.change_scene_to_file()`/`change_scene_to_packed()` directly from a gameplay system** (`direct_scene_transition`) — bypasses SceneManager's loading screen, cleanup, and EventBus broadcast — source: ADR-0002
- **Never transition scenes during `WAVE_ACTIVE`** (`mid_wave_scene_transition`) — leaves live EventBus subscriptions in partially-torn-down states, guaranteed crash — source: ADR-0002
- **Never use `CharacterBody2D` for Monster entities** — physics solver separates overlapping bodies, breaking the required cell co-occupancy (100+ monsters must be able to share a cell) — source: ADR-0002, ADR-0006
- **Never return a Resource instance (or `Vector2i`/`Color`/`NodePath`) from `get_save_data()`** (`resource_object_in_save_data`) — `store_var(data, true)` embeds script paths that break on file rename; `store_var(data, false)` silently drops non-primitives — source: ADR-0003
- **Never assume a `FileAccess.store_*()` call succeeded without checking its `bool` return** (`unchecked_fileaccess_write`) — silent write failure on full disk / permission errors, with no player feedback — source: ADR-0003
- **Never cache `Grid.get_walkable_cell_map()` across a `tower_placed`/`tower_removed` event** (`stale_walkability_map`) — a correctness bug, not just a performance one; routes monsters through occupied cells — source: ADR-0005
- **Never call `Grid.place_tower()`/`remove_tower()` from any system other than Tower System** (`grid_write_outside_tower_system`) — breaks the single-writer invariant every other system trusts — source: ADR-0005
- **Never use a `TileMapLayer` as the Grid's authoritative data store** — couples visual rendering to a pure data structure; Grid must remain a stateless-between-missions Autoload — source: ADR-0005
- **Never thread a custom EventBus-driven pause flag through every timer-owning system** — this is the class of bug (a system is missed) that the engine-native `SceneTree.paused` approach was specifically chosen to avoid — source: ADR-0014
- **Never invent a new collision-layer number for a physics body Hero should be blocked by** — reuse layer 1 — source: ADR-0015
- **Never add Monster entities to the Hero/Environment collision-layer system** — Monster is `Area2D` and is deliberately exempt — source: ADR-0015

### Performance Guardrails

- Total EventBus processing per frame: ≤ 1.667 ms (10% of the 16.67 ms frame budget) — source: ADR-0001
- Per-event-type budget at 8 concurrent event types: ~0.208 ms — source: ADR-0001
- Batch-dispatch threshold: any event type firing > 20 times/frame must switch to batched deferred dispatch — source: ADR-0001
- 100 simultaneous `Area2D` Monster instances at 60 FPS on minimum-spec hardware — source: ADR-0002, ADR-0006

---

## Core Layer Rules

*Applies to: pathfinding, monster movement/combat, damage resolution, tower placement,
entity data schemas, hero systems, inventory, resource economy, mission economy*

### Required Patterns

**Pathfinding**

- Use `AStar2D` for all route computation — never `NavigationServer2D`/`NavigationAgent2D` (high post-cutoff API risk, mismatched to the discrete-grid model) — source: ADR-0004
- One route template (`path: Array[Vector2i]` + `cell_index_map: Dictionary`) per SPAWN cell, built once at SCOUT phase start — source: ADR-0004
- `get_path()` during `WAVE_ACTIVE` is O(1) template lookup + O(k) slice — no A* computation on the hot path — source: ADR-0004
- `would_block_all_paths()` is called **only** on placement confirmation, never on hover — source: ADR-0004
- Deferred dirty-template rebuild batches multiple tower events in the same frame into one `path_invalidated` emission — source: ADR-0004
- `templates_ready` event must gate Wave Manager's first `monster_spawn_requested` — source: ADR-0004

**Monster System**

- Scene root: `Area2D`, position-based movement (`global_position` set directly from `direction × scaled_speed × delta`) — source: ADR-0006
- All per-entity logic (damage, BOSS attack, movement, absorbed flush) runs inside a single centralized `MonsterManager._physics_process`, in 4 fixed sequential passes (Damage → BOSS Logic → Movement → Absorbed Flush) — source: ADR-0006
- `_pending_damage: Array[MonsterDamageTaken]` is appended to on receipt and drained only in Pass 1 — never applied inline from the EventBus handler — source: ADR-0006
- `_pending_absorbed: Dictionary[int, float]` accumulates per-entity across a frame; flush exactly once per entity per frame in Pass 4, then clear — source: ADR-0006
- `active_monsters` is rebuilt via `Array.filter()` at the end of the movement pass — never `Array.erase()` inside a loop — source: ADR-0006
- BOSS animation: two stacked `AnimatedSprite2D` nodes (base = walk, overlay = attack/attack_prepare) — not `AnimationTree` additive blend — source: ADR-0006

**Damage & Status Pipeline**

- Deferred damage events use `await get_tree().process_frame` (not `call_deferred`) to guarantee next-frame delivery into `MonsterManager`'s Pass 1 — source: ADR-0007
- `is_instance_valid(self)` must be the **first statement** after every `await` in any async EventBus subscriber, project-wide — source: ADR-0007
- Lifesteal round-trip: register `_lifesteal_pending[target_id] = fraction` before deferring; resolve on `monster_hp_absorbed` receipt; erase after resolving; clear entirely on `wave_completed` — source: ADR-0007
- `hero_healed`'s synchronous Level-1 cascade from `monster_hp_absorbed` is a documented, narrow exemption (bounded by hero attack rate) — revisit if hero attack rate approaches the 20/frame batch threshold — source: ADR-0007

**Tower Placement Gate**

- `place_tower()` runs exactly 4 sequential gates in order (Phase → Resource → Grid footprint → Path integrity), short-circuiting on first failure — source: ADR-0008
- `get_placement_preview()` (hover) runs Gates 1–3 only and must **never** call `would_block_all_paths()` — source: ADR-0004, ADR-0008
- `Resource.duplicate_deep()` (not shallow `duplicate()`) is required at placement commit for all 4 TowerComponent Resources, isolating mission-instance state from inventory — source: ADR-0008
- All data nested inside a component Resource (e.g. perk data inside `FoundationComponent`) must itself be a `Resource` subclass — `duplicate_deep()` only deep-copies `Resource` subclasses — source: ADR-0008
- `TowerMissionState` must never be assigned to an `@export` property on any Autoload or persistent node — source: ADR-0008

**Resource Data Model**

- `GameDataRegistry` (Autoload #5) is the sole lookup point for `MonsterResource`/`TowerPerkRegistry`/`ItemDefinitionResource`/`DropTableResource` — no system constructs its own `res://assets/data/...` path — source: ADR-0009
- Persistent data Resources (`.tres`, boot/mission-loaded, immutable) and event-payload Resources (short-lived, emitted, never saved) are strictly separate categories — never mix them — source: ADR-0009
- Every persistent data Resource subclass implements `validate() -> Array[String]`; `push_error()` per issue, never abort in release builds — source: ADR-0009

**Hero — Tower-Synced Class / Tower Affinity**

- `_tower_cache: Dictionary` is populated **exclusively** via EventBus subscriptions (`tower_placed`, `tower_removed`, `tower_destroyed`) — Hero System never queries Tower System or Grid for tower data directly — source: ADR-0010
- Tower Affinity recomputes only on tower lifecycle events — never per-frame — source: ADR-0010
- Proximity accumulation (`_physics_process`) is active only during `WAVE_ACTIVE` + `INTERMISSION` (`_proximity_active` flag) — source: ADR-0010

**Inventory**

- Two-tier model: static `ItemDefinitionResource` (via `GameDataRegistry`) + runtime `InventorySlot` (`RefCounted`, **not** a `Resource`) — source: ADR-0016
- `instance_id` (monotonic counter, `-1` = stackable) is the sole key for unique-instance identity — never key stacking/merge/lock logic on `item_id` or stat equality — source: ADR-0016
- Equip-time isolation uses `Dictionary.duplicate(true)` (stat_overrides is flat primitives — `duplicate_deep()` is reserved for genuine nested-Resource graphs) — source: ADR-0016
- `restore_order = 10` (matches `save-persistence.md`'s own Formula 4 table; must stay below Hero's 30) — source: ADR-0016, ADR-0003

**Resource Economy**

- Implemented as a scene-instanced node (**not** an Autoload) with a mission-scoped subscription lifecycle — matches ADR-0002's existing boundary classification — source: ADR-0017
- Sole owned mutable state is one cached scalar, `_menagerie_quality_bonus: float` — no accumulator, no transaction log, no per-kill history — source: ADR-0017
- `monster_died` and `monsters_died_batch` must resolve identically, entry-by-entry — relies on the project-wide guarantee that a kill fires exactly one of the two, never both — source: ADR-0017

**Mission Economy (Gold Balance)**

- `MissionEconomy` (Autoload #8) is the sole owner of `_gold_balance: int` — mutated **only** via its `resources_changed` EventBus subscription, reset to 0 only on `mission_launched` — source: ADR-0018
- Reads (`get_gold_balance()`, `can_afford(cost)`) are direct-call, not EventBus round-trip — same exception class as Grid's read API — source: ADR-0018
- No `SaveRestorer` registration — gold is ephemeral per-mission state, structurally identical to other unsaved mission-runtime scalars — source: ADR-0018

### Forbidden Approaches

- **Never run individual A* queries during `WAVE_ACTIVE`** (`per_monster_astar_during_wave`) — all path lookups must use `PathfindingSystem.get_path()`'s pre-computed templates — source: ADR-0004
- **Never call `would_block_all_paths()` on hover** (`would_block_all_paths_on_hover`) — constructs temp `AStar2D` instances; at 60 FPS this would consume the entire frame budget — source: ADR-0004
- **Never use `NavigationServer2D`/`NavigationAgent2D`** for this project's discrete-grid routing — high post-cutoff API risk (4.0 and 4.2 breaking changes) and a poor fit for cell-step movement — source: ADR-0004
- **Never let `MonsterEntity` scene nodes define their own `_physics_process`** (`per_monster_physics_process`) — scene-tree call order is not guaranteed stable, breaking the DEAD-priority invariant — source: ADR-0006
- **Never use `Resource.duplicate()` (shallow) to isolate TowerComponent instances** (`shallow_duplicate_for_components`) — leaves nested Resources shared between mission instance and inventory item — source: ADR-0008
- **Never emit `monster_damage_taken` synchronously from a `tower_attacked`/`hero_auto_attacked` subscriber** (`synchronous_damage_application`) — creates a 3-level synchronous cascade, exceeding ADR-0001's 2-level cap — source: ADR-0007
- **Never emit a persistent data Resource (`MonsterResource`, `WaveConfig`, etc.) as an EventBus signal payload** (`data_resource_as_event_payload`) — creates GC/ownership ambiguity; use a dedicated event-payload Resource subclass instead — source: ADR-0009
- **Never have Hero System hold a direct reference to or call Tower System** (`hero_queries_tower_system_directly`) — Tower System is scene-instanced, Hero is not; route all tower data through the `_tower_cache` EventBus pattern — source: ADR-0010
- **Never key Inventory stacking, locking, or merge logic on `item_id` or stat-value equality** — always key on `instance_id` — source: ADR-0016
- **Never fold `DropTableResource`/`DropEntry` content directly into `MonsterResource`** — breaks drop-table reuse across monster types sharing one table — source: ADR-0017
- **Never let Wave Manager or Tower System own the gold balance** — ownership belongs to `MissionEconomy` specifically; extending an unrelated Autoload/system blurs responsibility and creates an architecturally-backwards dependency — source: ADR-0018
- **Never read the gold balance via an EventBus broadcast + local cache** — the direct-call API exists precisely because Tower's placement-confirmation check (ADR-0008 Gate 2) needs a synchronous, non-stale answer — source: ADR-0018

### Performance Guardrails

- `get_path()`: ≤ 1 ms for 100 calls in a single physics frame (measured, includes GC-inclusive p99.9) — source: ADR-0004
- `would_block_all_paths()`: ≤ 5 ms p99 / ≤ 10 ms p99.9 at maximum grid dimensions — source: ADR-0004
- Monster System `_physics_process`: ≤ 2 ms/frame at 150 active entities; ≤ 4 ms/frame for a 22-entity lethal-AoE frame — source: ADR-0006
- Tower placement gate: negligible CPU except the path-integrity check (Gate 4), which shares the pathfinding budget above — source: ADR-0008
- Resource Economy / Mission Economy: negligible — event-triggered only, never per-frame — source: ADR-0017, ADR-0018

---

## Feature Layer Rules

*Applies to: mission phase FSM, wave sequencing, projectile pooling*

### Required Patterns

**Wave Manager FSM**

- `enum Phase` + a single `_transition_to(new_phase)` entry point — direct assignment to `_phase` outside this method is forbidden — source: ADR-0012
- All phase timers are scene-tree `Timer` nodes (`one_shot = true`), with directly-invokable callbacks for unit testing — never gate test timing via `Engine.time_scale` — source: ADR-0012
- The spawn coroutine applies a three-guard check (`is_instance_valid(self)`, `_spawn_active`, `_phase == Phase.WAVE_ACTIVE`) immediately after every `await` boundary — source: ADR-0012
- `_phase_locked` must be the first check in every EventBus handler; `hero_died`'s handler sets it as its first operation, before any other processing — source: ADR-0012
- `_wave_clear_fired` latch must be checked before any wave-clear path emits `wave_completed`, preventing a same-frame double-clear race — source: ADR-0012

**Projectile Pooling** *(ADR-0019, added 2026-07-13b)*

- `ProjectileManager` is a scene-instanced child node of Tower System's own node tree — **not** an Autoload, **not** a top-level scene-tree peer/sibling system. `TowerSystem → ProjectileManager.fire(...)` is an intra-system method call, mirroring the `_monster_cache` ownership relationship — requires no new EventBus contract — source: ADR-0019
- `ProjectileManager` owns a single **centralized** `_physics_process` pass over the entire pool, mirroring `MonsterManager`'s pattern (ADR-0006) — source: ADR-0019
- Fixed-size pool, pre-instantiated once at mission start: `projectile_pool_size = ceil(max_active_towers_homing(32) × max_attack_speed(4.0) × base_flight_time_sec(0.5) × 3.0)` = default **192**. No runtime growth — source: ADR-0019
- Use `_free_indices: Array[int]` as an O(1) acquire/release stack — source: ADR-0019
- Pool exhaustion degrades gracefully: `fire()` returns `false` (dropped shot, tower's attack timer still resets), `push_warning()` logged — never a crash — source: ADR-0019
- Re-acquisition throttle: `MAX_REACQUISITIONS_PER_FRAME = 8`, counter reset each `_physics_process` call, to bound the cost of mass-kill events — source: ADR-0019
- `Projectile` is a plain `Node2D` — arrival and re-acquisition are cache/ID-driven via `TowerSystem._monster_cache`, not spatial-overlap-driven — source: ADR-0019
- On release, both `visible = false` **and** `process_mode = Node.PROCESS_MODE_DISABLED` must be set; on activate, both `visible = true` **and** `process_mode = Node.PROCESS_MODE_INHERIT` — `visible = false` alone does not stop a child `AnimatedSprite2D`'s internal frame timer from advancing. Use `PROCESS_MODE_DISABLED`, not `PROCESS_MODE_PAUSABLE` (which only reacts to `SceneTree.paused`) — source: ADR-0019
- `activate()` must reset stale transform (`rotation = 0.0`) and stale tint/alpha (`modulate = Color.WHITE`) carried over from a pool slot's prior use — source: ADR-0019
- `HOMING` tracks its target by `entity_id`, re-acquires bounded strictly to the firing tower's own range/cone (never a global search) on target death, and self-destructs via `_release()` with no damage/detonation/error if no valid target is found. When the frame's re-acquisition budget is exhausted, the projectile drifts toward its last tracked position and retries next frame rather than being denied outright — source: ADR-0019
- `BALLISTIC` continues to the target's last-known world position; deals no damage if that position is empty on arrival; AoE-tagged `BALLISTIC` still detonates (possibly on zero targets) — source: ADR-0019
- On arrival, damage is delivered through the existing, unmodified `tower_attacked` → Damage & Status pipeline (ADR-0007) — this ADR only changes *when* `tower_attacked` fires for pooled types (delayed by flight time), never how damage resolves downstream. Emission stays deferred (`call_deferred`), matching ADR-0007's pattern — source: ADR-0019
- `BEAM` and `AURA` weapon types are unaffected — `BEAM` still emits `tower_attacked` immediately at fire time with no pool involvement; `AURA` has no projectiles — source: ADR-0019
- Pooled visuals must share a per-projectile-type atlas (one for all `HOMING`, one for all `BALLISTIC`), following ADR-0013's shared-atlas/`z_index` convention — source: ADR-0019, ADR-0013
- `push_warning()` has no built-in debug/release gating in Godot — it always executes in both build types. Guard explicitly with `OS.is_debug_build()` at the call site if genuinely debug-only logging is desired — source: ADR-0019

### Forbidden Approaches

- **Never assign `WaveManager._phase` directly from any method other than `_transition_to()`** (`direct_phase_assignment`) — bypasses the `_phase_locked` check, timer cancellation, and `mission_phase_changed` emission simultaneously — source: ADR-0012
- **Never implement the mission FSM as a per-phase state-class hierarchy** — the spawn coroutine cannot be cleanly isolated in a state class without becoming a thin wrapper anyway — source: ADR-0012
- **Never give a pooled `Projectile` its own `_physics_process`** — all updates flow through `ProjectileManager`'s single centralized pass; a stray per-instance `_physics_process` on any `Projectile`/`ProjectileManager` script is a static-analysis (grep) validation failure — source: ADR-0019
- **Never use `Area2D`/physical overlap detection for projectile arrival** — arrival and re-acquisition are already fully cache/ID-driven; an `Area2D` would add unused Physics-server overhead for 192 instances — source: ADR-0019
- **Never let `HOMING` re-acquisition search beyond the firing tower's own range/cone** — no global search — source: ADR-0019
- **Never grow the projectile pool at runtime** — `instantiate()`/`queue_free()` per shot is explicitly rejected; violates the project's zero-allocation-hot-path rule and the GDD's own pool-size tuning knobs — source: ADR-0019
- **Never use a per-tower local projectile pool** — fragments the shared 192-slot budget, which is explicitly a *global* sizing formula, not a per-tower one — source: ADR-0019
- **Never build a generic `NodePool` utility at this stage** — premature generalization; no second pooled entity type exists yet in any Accepted ADR — source: ADR-0019
- **Never simplify the release/activate reset to only `visible`** — `process_mode` must also be toggled, or the hidden node's children keep processing — source: ADR-0019

### Performance Guardrails

- `ProjectileManager._physics_process` iterates the full 192-slot pool each frame, skipping inactive slots (`if p.active`) — estimated well under 0.1 ms/frame at MVP entity counts; profile once implemented (no dedicated budget registered yet) — source: ADR-0019
- Pool warm-up (192 `instantiate()` calls) is a one-time cost at mission scene load, not a per-frame cost — source: ADR-0019
- `max_active_towers_homing = 32` is provisional — flagged as a revisit risk once map/PLACEABLE-cell counts finalize; pool-exhaustion graceful degradation is the interim mitigation, not a fix — source: ADR-0019

---

## Presentation Layer Rules

*Applies to: sprite rendering/batching, UI focus and gamepad navigation*

### Required Patterns

- Each entity class uses a **single shared per-class texture atlas** — never call `.duplicate()` on a `SpriteFrames` resource at runtime — source: ADR-0013
- Z-ordering via `z_index` only (`layer_z_index = entity_base_z + layer_index × 2`) — never a `CanvasLayer` per entity — source: ADR-0013
- Import textures as Atlas in Godot's import settings, not as individual per-frame files — source: ADR-0013
- Verify actual draw-call count via Remote Debugger before closing any entity-scene story — target ≤ 60 DC for a complete scene at MVP entity counts — source: ADR-0013
- `InputModeTracker` (reusable, scene-instanced — **not** an Autoload) is instanced per interactive UI screen to detect mouse vs. keyboard/gamepad input — source: ADR-0011
- Detect input mode via `_input()`, **not** `_unhandled_input()` — Controls with `mouse_filter = STOP` (the `Button`/`TextureButton` default) consume mouse-button events before they reach `_unhandled_input`, causing missed mode-change detection — source: ADR-0011
- Every focusable widget on a tracked screen gates its focus-ring visual on `has_focus() AND tracker.is_focus_ring_visible()` — mouse hover remains a fully separate signal (`mouse_entered`/`mouse_exited`), never merged into one "highlighted" state — source: ADR-0011
- `focus_neighbor_top/bottom/left/right` must be wired explicitly per interactive grid at scene-build time wherever custom adjacency (e.g. tab-wrap-at-edge) is required — do not rely on Godot's automatic nearest-neighbor traversal for this — source: ADR-0011

### Forbidden Approaches

- **Never use `CanvasLayer` per entity for z-ordering** — creates a new rendering context and breaks 2D draw-call batching — source: ADR-0013
- **Never reach for `MultiMeshInstance2D` per layer at MVP** — does not support per-instance `AnimationPlayer` integration cleanly; re-evaluate only if profiling at 100+ entities shows atlas batching is insufficient — source: ADR-0013
- **Never use SubViewport-per-entity compositing** — fixed ~1 ms/frame overhead per viewport; catastrophic at realistic entity counts (50 × 1 ms = 50 ms) — source: ADR-0013
- **Never assume `grab_focus()` affects mouse focus** — Godot 4.6 split them; `grab_focus()` only ever moves keyboard/gamepad focus — source: ADR-0011, `docs/engine-reference/godot/modules/ui.md`
- **Never render an always-visible focus ring with no input-mode detection** — contradicts the project's own "distinct from hover" UI requirement and misleads mouse-only players — source: ADR-0011
- **Never introduce a project-wide `FocusManager` Autoload for input-mode tracking** — a UI screen's input mode has no meaning outside that screen's lifetime; use the scene-instanced `InputModeTracker` pattern instead — source: ADR-0011

### Performance Guardrails

- Total scene draw calls: ≤ 200/frame (project-wide budget) — source: `.claude/docs/technical-preferences.md`
- Entity-scene draw calls at MVP counts: target ≤ 60 DC for a complete scene — source: ADR-0013

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `HeroManager`, `TowerComponent` |
| Variables/Functions | snake_case | `move_speed`, `take_damage()` |
| Signals | snake_case, past tense | `health_changed`, `wave_completed`, `item_equipped` |
| Files | snake_case matching class | `hero_manager.gd` |
| Scenes | PascalCase matching root node | `HeroManager.tscn`, `TowerInstance.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH`, `BASE_CRIT_MULTIPLIER` |

Source: `.claude/docs/technical-preferences.md`

### Performance Budgets

| Target | Value |
|--------|-------|
| Target Framerate | 60 FPS |
| Frame Budget | 16.67 ms |
| Draw Calls | ≤ 200/frame |
| Memory Ceiling | 1 GB |

Source: `.claude/docs/technical-preferences.md`

### Testing

- Framework: GUT (Godot Unit Testing)
- Minimum coverage: 80% for Logic and Integration stories (Visual/Feel and Config/Data stories exempt)
- Required tests: balance formulas, gameplay systems, networking (if applicable)

Source: `.claude/docs/technical-preferences.md`

### Approved Libraries / Addons

None configured yet — add only when actively integrating, per `technical-preferences.md`'s own instruction (no speculative additions).

### Forbidden APIs (Godot 4.6.2)

These APIs are deprecated as of the pinned engine version — use the listed replacement:

| Deprecated | Use Instead | Since |
|------------|-------------|-------|
| `TileMap` | `TileMapLayer` | 4.3 |
| `VisibilityNotifier2D`/`3D` | `VisibleOnScreenNotifier2D`/`3D` | 4.0 |
| `YSort` | `Node2D.y_sort_enabled` | 4.0 |
| `Navigation2D`/`3D` | `NavigationServer2D`/`3D` | 4.0 |
| `yield()` | `await signal` | 4.0 |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 |
| `instance()` / `PackedScene.instance()` | `instantiate()` | 4.0 |
| `get_world()` | `get_world_3d()` | 4.0 |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 |
| `duplicate()` for nested resources | `duplicate_deep()` | 4.5 |
| GodotPhysics3D (new projects) | Jolt Physics 3D | 4.6 default (2D unaffected) |

**Patterns** (not just APIs) also forbidden project-wide: string-based `connect()`; `$NodePath` lookups inside `_process()` (cache via `@onready` instead); untyped `Array`/`Dictionary` where a typed variant is available; `Texture2D` in shader parameters (use base `Texture` type, changed in 4.4).

Source: `docs/engine-reference/godot/deprecated-apis.md`

### Cross-Cutting Constraints

- No system other than Save & Persistence may call `FileAccess` directly (enforced by code review — a process criterion, not a runtime check) — source: ADR-0003
- Every EventBus subscription established in `_ready()` must be disconnected in `_exit_tree()`, project-wide, with no exceptions — source: ADR-0001
- The `await` + `is_instance_valid(self)` guard pattern established in ADR-0007 is the standing idiom for **any** async EventBus subscriber added anywhere in the project going forward, not just Damage & Status — source: ADR-0007
- Known outstanding housekeeping (not a rule violation, but not yet done): `resources_changed` and `item_pickup_rejected` are real, in-use signals still undocumented in `event-bus.md`'s formal catalogue — see `production/epics/epic-03-core-economy/EPIC.md`
