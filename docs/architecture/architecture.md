# Sanctuary Defenders — Master Architecture

## Document Status

- Version: 2
- Last Updated: 2026-05-22
- Engine: Godot 4.6.2 / GDScript
- GDDs Covered: game-concept, event-bus, grid-system, save-persistence, hero, tower, monster, damage-status, pathfinding, wave-manager (10 GDDs; 9 MVP systems + root concept)
- ADRs Referenced: ADR-0001 (EventBus — Accepted), ADR-0002 (Scene/Autoload — Accepted), ADR-0003 (Save format — Accepted), ADR-0004 (Pathfinding — Accepted), ADR-0005 (Grid data model — Accepted), ADR-0008 (Tower placement gate — Accepted 2026-05-19)
- Technical Director Sign-Off: 2026-05-15 — APPROVED WITH CONDITIONS (OQ-2: performance budgets must be configured in technical-preferences.md before Pre-Production gate check)
- Lead Programmer Feasibility: N/A (lean mode — LP-FEASIBILITY skipped)

---

## Engine Knowledge Gap Summary

**Engine**: Godot 4.6.2 | **LLM training covers**: up to ~Godot 4.3 | **Post-cutoff versions**: 4.4, 4.5, 4.6

### HIGH RISK Domains

| Domain | Key Change | Systems Affected |
|--------|-----------|-----------------|
| UI / Focus | Dual-focus system (4.6): `grab_focus()` sets keyboard/gamepad focus only; mouse focus is independent. All interactive widgets must be tested under both K/M and gamepad. | Mission HUD, Sanctuary UI, Tarot Deck UI |
| Rendering | Glow applied before tonemapping (4.6) — visual output differs from pre-4.6 expectations. D3D12 is now the default renderer on Windows (4.6). Shader uniforms use `Texture`, not `Texture2D`. | Any system with post-processing or custom shaders |

### MEDIUM RISK Domains

| Domain | Key Change | Systems Affected |
|--------|-----------|-----------------|
| FileAccess | `store_string()`, `store_var()`, `store_line()`, `store_csv_line()` return `bool` in 4.4+ (was `void`). Unhandled return = silent write failure in static-typed GDScript. | Save & Persistence |
| Resources | `duplicate()` does not deep-copy nested Resources in 4.5+. Must use `duplicate_deep()` for nested Resource hierarchies. | Any system copying composite Resources (TowerComponent, WaveConfig) |

### LOW RISK Domains (safe for all MVP systems)

| Domain | Reason |
|--------|--------|
| Signals / Autoload | GDScript signal system and Autoload pattern unchanged through 4.6 |
| 2D Physics (Area2D, CharacterBody2D) | Jolt default only affects 3D physics; 2D is unchanged |
| AStar2D | C++ implementation unchanged through 4.6 |
| Audio | No API changes 4.4–4.6 |
| Animation (2D) | AnimationMixer (4.3, in training data); IK restoration is 3D only |

### Systems in HIGH/MEDIUM Risk Domains

| System | Domain | Risk |
|--------|--------|------|
| Save & Persistence | FileAccess | MEDIUM — must check every store_* bool return |
| Mission HUD | UI dual-focus | HIGH — verify all widgets under K/M and gamepad |
| Sanctuary UI | UI dual-focus | HIGH — multi-panel gamepad d-pad navigation |
| Tarot Deck UI | UI dual-focus | HIGH |
| Any future shader work | Rendering | HIGH — shader texture type + glow timing |
| Any Resource copying | Resources | MEDIUM — use duplicate_deep() for nested Resources |

---

## System Layer Map

### Layer Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                              │
│  23 Mission HUD · 24 Sanctuary UI · 25 Tarot Deck UI            │
│  Audio System                                                    │
├──────────────────────────────────────────────────────────────────┤
│  ADVANCED FEATURE LAYER                                          │
│  Hero Skill Build · Equipment Forge · Encyclopedia               │
├──────────────────────────────────────────────────────────────────┤
│  FEATURE LAYER                                                   │
│  Wave Manager · Constellation · Crafting · Menagerie             │
│  Defense Building · Tarot · Tower Mastery · Mission Select       │
├──────────────────────────────────────────────────────────────────┤
│  CORE LAYER                                                      │
│  Hero · Tower · Monster · Damage & Status                        │
│  Inventory · Resource Economy                                    │
├──────────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER                                                │
│  EventBus · Grid · Save & Persistence · Pathfinding             │
├──────────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER  [Godot 4.6.2 / GDScript / Windows+Linux+macOS] │
└──────────────────────────────────────────────────────────────────┘
```

**Pathfinding placement rationale**: Although the systems-index lists Pathfinding in Core
(it depends on Grid), its Autoload boot position (4th), spatial-service role, and
`templates_ready` event that gates Monster spawning give it Foundation behaviour. Hero, Tower,
Monster, and Wave Manager all depend on it being ready before they can act.

### System Layer Assignment

| # | System | Layer | Priority | Engine Risk | Risk Reason |
|---|--------|-------|----------|-------------|-------------|
| 1 | EventBus System | Foundation | MVP | LOW | GDScript signals + Autoload — unchanged API |
| 2 | Grid System | Foundation | MVP | LOW | Array/Dictionary only — no engine-specific API |
| 3 | Save & Persistence System | Foundation | MVP | **MEDIUM** | `FileAccess.store_*` returns `bool` in 4.4+ (was `void`). Must check return values in static-typed GDScript. |
| 4 | Pathfinding System | Foundation | MVP | LOW | AStar2D (C++ backed) — unchanged. Deliberately avoids NavigationServer (post-cutoff MEDIUM risk). |
| 5 | Hero System | Core | MVP | LOW | CharacterBody2D + AnimatedSprite2D — 2D APIs unchanged 4.4–4.6 |
| 6 | Tower System | Core | MVP | LOW | Data-driven Resource composition; no direct physics API |
| 7 | Monster System | Core | MVP | LOW | Area2D root — 2D physics unchanged; Jolt default only affects 3D |
| 8 | Damage & Status System | Core | MVP | LOW | Pure logic + EventBus; `await get_tree().process_frame` unchanged |
| 9 | Inventory System | Core | VS | LOW | Resource serialization; inherits Save MEDIUM risk at persistence boundary |
| 10 | Resource Economy System | Core | VS | LOW | EventBus + data; no direct engine API |
| 11 | Wave Manager | Feature | MVP | LOW | Orchestration logic; Resources + Timer nodes — unchanged |
| 12 | Constellation System | Feature | VS | LOW | Grid spatial queries + EventBus |
| 13 | Crafting System | Feature | VS | LOW | Pure data manipulation + EventBus |
| 14 | Tarot System | Feature | VS | LOW | Data + EventBus; modifies WaveConfig pre-launch |
| 15 | Menagerie System | Feature | Alpha | LOW | Data + EventBus + Save |
| 16 | Defense Building System | Feature | Alpha | LOW | Data + EventBus + Save |
| 17 | Tower Mastery System | Feature | Alpha | LOW | Hero proximity detection via Grid; no novel APIs |
| 18 | Mission Select System | Feature | Alpha | LOW | Save read + EventBus; UI boundary in Presentation |
| 19 | Hero Skill Build System | Advanced | Alpha | LOW | Data + EventBus |
| 20 | Equipment Forge System | Advanced | Alpha | LOW | Data aggregation across 7 systems via EventBus |
| 21 | Encyclopedia System | Advanced | Full | LOW | Save read + EventBus |
| 22 | Mission HUD | Presentation | VS | **HIGH** | Dual-focus (4.6): `grab_focus()` sets keyboard/gamepad focus only — mouse focus is separate. All interactive widgets must support both input modes. |
| 23 | Sanctuary UI | Presentation | Alpha | **HIGH** | Same dual-focus risk. Gamepad d-pad navigation through multi-panel layout is particularly affected. |
| 24 | Tarot Deck UI | Presentation | Alpha | **HIGH** | Same dual-focus risk. |
| 25 | Audio System | Presentation | Full | LOW | No audio API changes 4.4–4.6. |

### Engine Risk Summary (Foundation + Core)

| System | Risk | Specific API Concern |
|--------|------|----------------------|
| Save & Persistence | MEDIUM | `store_string()`, `store_var()`, `store_line()`, `store_csv_line()` all return `bool` in 4.4+. Every store call must check its return value. |
| All Presentation systems | HIGH | `grab_focus()` in Godot 4.6 sets accessibility/keyboard focus only. Mouse focus state is independent. Verify all interactive widgets under both K/M and gamepad. |

---

## Module Ownership

### Foundation Layer

#### EventBus (Autoload — 1st boot)

| Attribute | Detail |
|-----------|--------|
| **Owns** | All 70 named signal declarations; cascade depth counter per dispatch chain; deferred dispatch queue for physics-thread callers |
| **Exposes** | One signal per event (e.g. `signal monster_died(payload: MonsterDiedEvent)`); `dispatch(event_name: StringName, payload)` method; `dispatch_deferred(event_name, payload)` for physics callers |
| **Consumes** | Nothing — pure pub/sub; no subscriptions of its own |
| **Engine APIs** | `Signal` (GDScript built-in), `Callable`, `call_deferred()` |
| **Engine Risk** | LOW — signal system unchanged through 4.6 |

**Performance contract**: ≤1.667 ms/frame total EventBus processing (10% of 16.67 ms budget). Max cascade depth: 2 levels. Batch threshold: 20 `monster_died` events/frame before switching to `monsters_died_batch`.

---

#### Grid (Autoload — 3rd boot)

| Attribute | Detail |
|-----------|--------|
| **Owns** | 16×12 cell array; CellType per cell (`EMPTY`, `SPAWN`, `GOAL`, `PATH`, `BLOCKED`); tower occupancy map (`cell_index → tower_id`); walkability cache |
| **Exposes** | `get_cell_type(cell: Vector2i) → CellType`; `get_tower_at(cell) → int`; `is_walkable(cell) → bool`; `world_to_cell(pos: Vector2) → Vector2i` (uses `floor()`); `cell_to_world(cell) → Vector2`; `get_spawn_cells() → Array[Vector2i]`; `get_goal_cells() → Array[Vector2i]` |
| **Consumes** | Nothing at runtime — read-only after Tower System writes placements |
| **Write API** | Tower System only: `place_tower(cell, tower_id)`; `remove_tower(cell)` — each publishes via EventBus |
| **Engine APIs** | `Array`, `Dictionary`, `Vector2i`, `Vector2` — no Godot node API |
| **Engine Risk** | LOW |

Returns copies, not references — callers cannot mutate Grid state through returned values.

---

#### Save & Persistence (Autoload — 2nd boot)

| Attribute | Detail |
|-----------|--------|
| **Owns** | 3 save slot files (`user://save_slot_{0,1,2}.dat`); active slot index; format version number; migration registry; exclusive FileAccess handle |
| **Exposes** | `save(slot: int) → bool`; `load(slot: int) → bool`; `get_state(key: StringName) → Variant`; `set_state(key: StringName, value: Variant)`; `slot_exists(slot: int) → bool` |
| **Consumes** | EventBus: `mission_launched`, `wave_completed`, `mission_complete`, `hero_died` (4 auto-save triggers) |
| **Engine APIs** | `FileAccess` (**MEDIUM RISK**: `store_*` returns `bool` in 4.4+, was `void`); `DirAccess` for atomic write temp file |
| **Engine Risk** | **MEDIUM** — every `store_*` call must check its `bool` return; unhandled failure = silent data loss |

**Atomic write protocol**: write to `save_slot_N.tmp` → verify → rename to `.dat`. On load failure, attempt `.tmp` recovery.

**Restore order**: systems register a `restore_order` integer (10–33); `sanctuary_state_restored` dispatched deferred 1 frame after all systems loaded.

---

#### Pathfinding (Autoload — 4th boot)

| Attribute | Detail |
|-----------|--------|
| **Owns** | `AStar2D` instance; route template cache (`spawn_id → Array[Vector2i]`); `_spawn_assignment: Dictionary[int, int]` (monster_id → spawn_id); super-goal node; dirty flag; `cell_index_map` |
| **Exposes** | `get_path(from_cell: Vector2i, tier: int) → Array[Vector2i]`; `would_block_all_paths(cell: Vector2i) → bool`; `is_rebuild_pending() → bool`; dispatches `templates_ready` on first successful build |
| **Consumes** | Grid: reads cell types and walkability; EventBus: `tower_placed`, `tower_removed` → triggers dirty rebuild |
| **Engine APIs** | `AStar2D` (C++ — unchanged through 4.6) |
| **Engine Risk** | LOW |

**Deferred dirty rebuild**: `tower_placed`/`tower_removed` sets dirty flag → rebuilds at next frame start. `templates_ready` dispatched only after first complete build; subsequent rebuilds are silent.

---

### Core Layer

#### Hero

| Attribute | Detail |
|-----------|--------|
| **Owns** | Player `CharacterBody2D` scene; 12 stats (`max_hp`, `hp`, `move_speed`, `attack_range`, `attack_speed`, `crit_chance`, `crit_multiplier`, `lifesteal`, `tower_affinity`, `tower_proximity_radius`, `skill_cooldown_reduction`, `bonus_tier`); 4 active skill slots + Ultimate; Tower-Synced Class state; Tower Affinity accumulator |
| **Exposes** | `take_damage(amount: float, source_id: int)` → publishes `hero_incoming_damage`; `heal(amount: float)`; `get_stat(stat: StringName) → float`; `get_position() → Vector2` |
| **Consumes** | EventBus: `tower_placed`, `tower_removed` (proximity re-scan); `monster_died` (targeting cleanup) |
| **Engine APIs** | `CharacterBody2D`, `move_and_slide()`, `AnimatedSprite2D`, `Area2D` (attack hitbox) |
| **Engine Risk** | LOW |

---

#### Tower

| Attribute | Detail |
|-----------|--------|
| **Owns** | Per-tower `Node2D` scene; component slot state (foundation/weapon/focus/power); archetype (Sentinel/Barrage/Support/Arcane); tier (1–4); pre-placement perk flag; monster cache (populated via EventBus — no direct Monster refs) |
| **Exposes** | `get_stats() → Dictionary`; `swap_component(slot: StringName, component: Resource)`; `can_place(cell: Vector2i) → bool` (calls `Pathfinding.would_block_all_paths()`) |
| **Consumes** | EventBus: `monster_spawned` (cache add), `monster_died` (cache remove), `wave_state_changed` (block/unblock placement) |
| **Engine APIs** | `Node2D`, `Timer` (attack cooldown), `Area2D` (range detection) |
| **Engine Risk** | LOW |

Placement is blocked during `WAVE_ACTIVE` — Tower System rejects all placement and removal requests when `wave_state == WAVE_ACTIVE`.

---

#### Monster

| Attribute | Detail |
|-----------|--------|
| **Owns** | Per-monster `Area2D` scene; `MonsterResource` (data-driven stats); `_pending_damage: float` buffer; `_pending_absorbed: float` accumulator; movement position (position-based via `_physics_process`); tier (Normal/Elite/Boss) |
| **Exposes** | `apply_damage(amount: float, type: StringName)` (buffers into `_pending_damage`); `get_id() → int`; `get_position() → Vector2` |
| **Consumes** | Pathfinding: reads route template per spawn; EventBus: `status_effect_applied` |
| **Engine APIs** | `Area2D`, `AnimatedSprite2D` (dual-layer), `_physics_process()` for buffer flush + position update |
| **Engine Risk** | LOW — Area2D and 2D physics unchanged through 4.6 |

`_pending_damage` buffer and `_pending_absorbed` accumulator flush at start of each `_physics_process` call.

---

#### Damage & Status

| Attribute | Detail |
|-----------|--------|
| **Owns** | `_lifesteal_pending: Dictionary[int, float]` (source_id → pending heal); status effect registry; hit resolution pipeline (raw → mitigated → absorbed → applied); DoT tick scheduler |
| **Exposes** | No direct call API — all input via EventBus |
| **Consumes** | EventBus: `hero_incoming_damage`, `tower_attack_hit`, `status_effect_applied`; dispatches `hero_damage_taken`, `monster_hp_changed`, `hero_healed` |
| **Engine APIs** | `await get_tree().process_frame`; `is_instance_valid(self)` guard after every await |
| **Engine Risk** | LOW |

Every `await get_tree().process_frame` is immediately followed by `if not is_instance_valid(self): return`.

---

#### Inventory *(GDD not authored — interface provisional)*

| Attribute | Detail |
|-----------|--------|
| **Owns** | Item slot array; item Resource definitions; stack counts |
| **Exposes** | `add_item(item: Resource)`; `remove_item(item_id: int)`; `get_items() → Array[Resource]` |
| **Consumes** | EventBus: `item_dropped`, `item_crafted`; Save & Persistence for serialization |
| **Engine Risk** | LOW (inherits Save MEDIUM risk at persistence boundary) |

---

#### Resource Economy *(GDD not authored — interface provisional)*

| Attribute | Detail |
|-----------|--------|
| **Owns** | Per-resource-type counts; transaction log |
| **Exposes** | `get_amount(resource_type: StringName) → int`; `spend(type, amount) → bool`; `earn(type, amount)` |
| **Consumes** | EventBus: `monster_died` (material drop), `wave_completed` (wave reward) |
| **Engine Risk** | LOW |

---

### Feature, Advanced, Presentation Layer (Summary)

| Module | Owns | Key EventBus Role |
|--------|------|-------------------|
| Wave Manager | WaveConfig/WaveScript Resources; wave phase FSM (7 states); spawn queue; watchdog Timer | Publishes `wave_started`, `wave_completed`, `monster_spawn_requested`; subscribes `templates_ready`, `monster_died`, `monster_breached` |
| Constellation | Pattern registry; active bonus map | Subscribes `tower_placed`, `tower_removed`; publishes `constellation_activated`, `constellation_broken` |
| Crafting | Recipe registry; in-progress craft state | Publishes `item_crafted` |
| Tarot | Deck state; per-mission modifier payload | Publishes `tarot_modifiers_ready` pre-Scout |
| Menagerie | Creature state; happiness score; material quality tier | Publishes `menagerie_quality_changed` |
| Defense Building | Tech tree unlock state | Publishes `tech_unlocked` |
| Tower Mastery | Proximity learning counters | Subscribes `hero_position_changed`, `tower_placed` |
| Mission Select | Mission manifest; unlock state | Publishes `mission_selected` |
| Hero Skill Build | Skill loadout; Ultimate combination matrix | Reads Tower Mastery state via EventBus |
| Equipment Forge | Equipment assembly rules | Aggregates Hero, Crafting, Menagerie, Constellation, Tarot, Inventory state |
| Encyclopedia | Discovery registry | Subscribes to numerous events |
| Mission HUD | Real-time display widgets | Read-only EventBus subscriber ⚠️ HIGH: dual-focus (4.6) |
| Sanctuary UI | Tab/panel navigation | ⚠️ HIGH: dual-focus + gamepad d-pad |
| Tarot Deck UI | Card selection interface | ⚠️ HIGH: dual-focus |
| Audio System | Sound bus management; music cue state | EventBus subscriber — responds with audio |

---

### Dependency Diagram (Foundation + Core)

```
PLATFORM  [Godot 4.6.2 / GDScript]
  │
FOUNDATION
  ├─ EventBus  ◄──────────────────────────── (all systems publish/subscribe)
  ├─ Grid
  ├─ Save & Persistence
  └─ Pathfinding ──► Grid (reads walkability)
  │
CORE
  ├─ Hero ──────────────► EventBus, Grid, Save
  ├─ Tower ─────────────► EventBus, Grid, Save
  │    └─ placement guard ──► Pathfinding.would_block_all_paths()
  ├─ Monster ───────────► EventBus, Grid
  │    └─ route query ──────► Pathfinding.get_path()
  ├─ D&S ───────────────► EventBus
  ├─ Inventory ─────────► EventBus, Save
  └─ Resource Economy ──► EventBus, Save
```

---

## Data Flow

### Scenario 1 — Frame Update Path

Two loops run simultaneously during `WAVE_ACTIVE`. Both on the main thread — separation is tick-rate, not threading.

```
INPUT (every _process frame)
  └─► Hero._process()
        ├─ read InputMap → compute move vector
        ├─ call move_and_slide()
        └─ if attack triggered → publish hero_auto_attacked (EventBus)
              └─► D&S subscribes → resolves hit → publishes monster_hp_changed
                    └─► Monster subscribes → buffers into _pending_damage

PHYSICS TICK (_physics_process)
  Monster._physics_process()
    ├─ flush _pending_damage → apply to hp
    ├─ if hp <= 0 → publish monster_died (EventBus, deferred)
    └─ advance position along route template (position-based movement)

  Tower (Timer-driven, not frame-driven)
    └─ on Timer.timeout → scan monster cache → publish tower_attack_hit (EventBus)
          └─► D&S subscribes → resolves damage → publishes monster_hp_changed
```

All cross-system data passes through EventBus payloads. No module holds a direct reference to another module's nodes.

---

### Scenario 2 — Event/Signal Path

```
SYNCHRONOUS (default):
  Publisher.dispatch("event_name", payload)
    → EventBus.emit_signal("event_name", payload)
      → subscribers called inline, in connection order
      → cascade counter incremented per dispatch chain

DEFERRED (physics callers only):
  Monster._physics_process() → EventBus.dispatch_deferred("monster_died", payload)
    → EventBus.call_deferred("emit_signal", "monster_died", payload)
      → subscribers called at end of frame, outside physics step

BATCHED (high-frequency):
  If monster_died count > 20 in one frame:
    → individual monster_died events suppressed
    → monsters_died_batch(payload: Array) dispatched instead
```

**Cascade rule**: Subscriber publishing an event = Level 1. Subscriber of that publishing again = Level 2. Level 3 is forbidden — EventBus logs a warning and does not dispatch.

---

### Scenario 3 — Save/Load Path

```
AUTO-SAVE (triggered by EventBus):
  mission_launched | wave_completed | mission_complete | hero_died
    └─► Save & Persistence → save(active_slot)
          ├─ each system: _collect_save_data() → Dictionary
          ├─ Save aggregates into one Variant
          ├─ FileAccess.open("user://save_slot_N.tmp", WRITE)
          │    └─ store_var(data) → check bool return  ← MEDIUM RISK (4.4+)
          ├─ FileAccess.close()
          ├─ DirAccess.rename(".tmp" → ".dat")
          └─ publish save_completed (EventBus)

LOAD (game start / slot select):
  Save & Persistence.load(slot)
    ├─ FileAccess.open("user://save_slot_N.dat", READ)
    ├─ data = get_var()
    ├─ for each system in restore_order (10 → 33):
    │    system._restore_save_data(data[system_key])
    ├─ FileAccess.close()
    └─ await get_tree().process_frame
         └─ publish sanctuary_state_restored (EventBus, deferred 1 frame)
```

**What is serialized**: Sanctuary state only — hero equipment, inventory, menagerie, tech unlocks, Tarot deck, mission unlock flags. Mission runtime state is never saved; missions always restart from Scout on defeat.

**Save format**: deferred to ADR-0003.

---

### Scenario 4 — Initialization Order

```
ENGINE BOOT — Autoloads in declared order:
  1. EventBus          — signals declared; no subscribers yet
  2. Save & Persistence — subscribes auto-save triggers on EventBus
  3. Grid              — initializes 16×12 cell array from level data
  4. Pathfinding       — reads Grid; builds initial AStar2D graph
       └─ dispatches templates_ready when first build complete

SCENE LOAD (mission or sanctuary):
  └─► SceneManager loads scene → instantiates system nodes
        ├─ Hero.ready()          — reads save state; subscribes EventBus
        ├─ TowerManager.ready()  — restores placed towers from Scout snapshot
        ├─ MonsterManager.ready()— subscribes templates_ready (spawn gate)
        └─ WaveManager.ready()   — subscribes templates_ready; holds spawn queue
```

**Critical invariant**: No system may call `Pathfinding.get_path()` or `Pathfinding.would_block_all_paths()` before `templates_ready` fires. Wave Manager and Monster Manager enforce this with `_routes_ready: bool`.

**Wave Manager dual gate** (INTERMISSION → PRE_WAVE): Wave Manager calls `Pathfinding.is_rebuild_pending()` before transitioning. If `true`, it waits for the next `templates_ready` signal before proceeding to `PRE_WAVE`. This ensures towers placed during INTERMISSION are reflected in spawn routes before the next wave begins.

---

## API Boundaries

All contracts below are written in GDScript pseudocode matching project naming conventions. These are the interfaces programmers implement against.

### EventBus

```gdscript
# Autoload: EventBus
# All signals are typed. Resource subclasses for payloads with 5+ fields;
# primitives/Dictionary for smaller payloads.

func dispatch(event_name: StringName, payload: Variant) -> void
func dispatch_deferred(event_name: StringName, payload: Variant) -> void

# Invariants:
# 1. Never call dispatch() from a subscriber at cascade depth 2 (Level 3 = forbidden).
# 2. Never hold a payload Resource reference beyond the subscriber's call frame.
# 3. _physics_process callers MUST use dispatch_deferred.
```

### Grid

```gdscript
# Autoload: Grid
# All read methods return copies. Returned values must not be mutated.

func get_cell_type(cell: Vector2i) -> CellType
func get_tower_at(cell: Vector2i) -> int          # -1 if no tower
func is_walkable(cell: Vector2i) -> bool
func world_to_cell(pos: Vector2) -> Vector2i      # uses floor(); always in-bounds
func cell_to_world(cell: Vector2i) -> Vector2     # center of cell
func get_spawn_cells() -> Array[Vector2i]
func get_goal_cells() -> Array[Vector2i]

# Write API — Tower System only. All other callers: forbidden.
func place_tower(cell: Vector2i, tower_id: int) -> void
func remove_tower(cell: Vector2i) -> void

# Invariants:
# 1. world_to_cell() always returns an in-bounds cell — callers must not
#    pass world positions outside grid bounds.
# 2. Grid does not enforce WAVE_ACTIVE block — Tower System does, before calling Grid.
# 3. place_tower/remove_tower are the only write paths. No other system writes.
```

### Save & Persistence

```gdscript
# Autoload: SavePersistence
# Exclusive FileAccess. Never open save files directly from outside this module.

func save(slot: int) -> bool                      # false = write failure
func load(slot: int) -> bool                      # false = file missing or corrupt
func slot_exists(slot: int) -> bool
func get_state(key: StringName) -> Variant        # null if key absent
func set_state(key: StringName, value: Variant) -> void

# Systems implement these to participate in save/load:
# func _collect_save_data() -> Dictionary
# func _restore_save_data(data: Dictionary) -> void
# const RESTORE_ORDER: int = <10–33>

# Invariants:
# 1. save() and load() are never concurrent — exclusive file handle, main thread only.
# 2. _restore_save_data() called in RESTORE_ORDER ascending order. A system must not
#    depend on a peer's restored state unless that peer's RESTORE_ORDER is strictly lower.
# 3. sanctuary_state_restored dispatched exactly once per load, deferred 1 frame.
# 4. Every FileAccess.store_* call checks its bool return. Failure → save() returns
#    false and publishes save_failed (EventBus).
```

### Pathfinding

```gdscript
# Autoload: Pathfinding

func get_path(from_cell: Vector2i, tier: int) -> Array[Vector2i]  # [] if not ready; tier selects route template set
func would_block_all_paths(cell: Vector2i) -> bool               # pure read; no graph mutation
func is_rebuild_pending() -> bool                                 # true if dirty flag set but rebuild not yet run

# Invariants:
# 1. get_path() MUST NOT be called before templates_ready fires.
#    Enforce with _routes_ready: bool in every spawning system.
# 2. would_block_all_paths() is speculative and synchronous. Result valid for
#    current frame only — do not cache across frames.
# 3. Graph rebuilds deferred (next frame) after tower changes. In-flight monsters
#    continue using their assigned pre-change template — this is acceptable.
# 4. is_rebuild_pending() is used by Wave Manager at INTERMISSION → PRE_WAVE to
#    determine whether to wait for a fresh templates_ready before spawning.
```

### Hero

```gdscript
# Node: Hero (CharacterBody2D)

func take_damage(amount: float, source_id: int) -> void   # publishes hero_incoming_damage
func apply_damage(amount: float) -> void                  # called by D&S only
func heal(amount: float) -> void                          # called by D&S only
func get_stat(stat: StringName) -> float
func get_position() -> Vector2

# Invariants:
# 1. take_damage() publishes only — D&S is the sole caller of apply_damage().
#    No other system calls apply_damage() directly.
# 2. Stat reads return current effective value (base + bonuses). Do not cache
#    across frames during combat.
```

### Tower

```gdscript
# Node: TowerInstance (Node2D)
func get_stats() -> Dictionary                     # copy; do not mutate
func swap_component(slot: StringName, component: Resource) -> void
func can_place(cell: Vector2i) -> bool

# TowerManager (scene-level manager)
func place_tower(cell: Vector2i, archetype: StringName, components: Dictionary) -> bool
func remove_tower(cell: Vector2i) -> bool

# Invariants:
# 1. place_tower() returns false during WAVE_ACTIVE. No placement is queued.
# 2. Grid.place_tower() is never called without can_place() returning true.
# 3. Monster cache populated exclusively via EventBus. No direct Monster Node refs.
```

### Monster

```gdscript
# Node: MonsterInstance (Area2D)
func apply_damage(amount: float, type: StringName) -> void  # buffers only
func get_id() -> int
func get_position() -> Vector2

# MonsterManager (scene-level manager)
func spawn(monster_resource: MonsterResource, spawn_id: int) -> void

# Invariants:
# 1. apply_damage() buffers into _pending_damage only. hp mutation in _physics_process.
# 2. MonsterManager.spawn() called only after templates_ready fires.
# 3. Position is position-based. Do not use CharacterBody2D movement APIs on Monster.
```

### Damage & Status

```gdscript
# Node: DamageStatusSystem
# No direct call API — all input and output via EventBus.

# Subscriptions: hero_incoming_damage, tower_attack_hit, status_effect_applied
# Publications:  hero_damage_taken, hero_healed, monster_hp_changed

# Invariants:
# 1. Every await get_tree().process_frame is immediately followed by:
#    if not is_instance_valid(self): return
# 2. D&S publishes results — Hero and Monster subscribe. D&S never calls
#    apply_damage() or heal() directly on peer nodes.
# 3. _lifesteal_pending cleared after each resolution cycle (once per frame).
```

---

## ADR Audit

Six ADRs accepted as of 2026-05-22. Coverage: **29 / 57** requirements covered (ADR-0001–0005 + ADR-0008). Full traceability detail in `docs/architecture/architecture-traceability.md` (TR Registry v3, last updated 2026-05-22).

| ADR | System | Status | TRs Covered |
|-----|--------|--------|-------------|
| ADR-0001 | EventBus architecture | Accepted | TR-eb-001–006, TR-gc-001 |
| ADR-0002 | Scene and Autoload structure | Accepted | TR-gc-002, TR-gc-003 (partial), TR-hero-001, TR-monster-001, TR-monster-004, TR-path-001 |
| ADR-0003 | Save file format | Accepted | TR-save-001–006 |
| ADR-0004 | Pathfinding strategy | Accepted | TR-path-001–006, TR-path-007 (partial), TR-wave-004 |
| ADR-0005 | Grid system data model | Accepted | TR-grid-001–004 |
| ADR-0006 | Monster movement | Pending | TR-monster-002–003, 005–006 |
| ADR-0007 | Damage pipeline | Pending | TR-ds-001–005, TR-hero-004, TR-tower-003 |
| ADR-0008 | Tower placement gate | **Accepted (2026-05-19)** | TR-tower-002, TR-tower-004, TR-tower-005 |
| ADR-0009 | Resource data model | Pending | TR-monster-002, TR-wave-002, TR-tower-001, TR-tower-006 |
| ADR-0010 | Hero Tower-Synced Class | Deferred | TR-hero-002, 003, 005, 006 |
| ADR-0011 | UI dual-focus | Deferred | All Presentation system TRs |
| ADR-0012 | Wave Manager FSM | Recommended | TR-wave-001, 003, 005, 006, 007 |

### Traceability Matrix

| Req ID | GDD | Requirement | ADR Coverage | Status |
|--------|-----|-------------|--------------|--------|
| TR-eb-001 | event-bus | 70-event typed signal catalogue | ADR-0001 | ✅ |
| TR-eb-002 | event-bus | Cascade depth ≤ 2 levels enforced at runtime | ADR-0001 | ✅ |
| TR-eb-003 | event-bus | Deferred dispatch for physics callers | ADR-0001 | ✅ |
| TR-eb-004 | event-bus | Batch threshold 20/frame for monster_died | ADR-0001 | ✅ |
| TR-eb-005 | event-bus | Resource subclass payloads for 5+ field events | ADR-0001 | ✅ |
| TR-eb-006 | event-bus | ≤1.667ms/frame total EventBus processing | ADR-0001 | ✅ |
| TR-grid-001 | grid-system | 16×12 default grid; 5 cell types | ADR-0005 | ✅ |
| TR-grid-002 | grid-system | Direct read API (Autoload); write restricted to Tower | ADR-0005 | ✅ |
| TR-grid-003 | grid-system | world_to_cell uses floor() | ADR-0005 | ✅ |
| TR-grid-004 | grid-system | Returns copies, not references | ADR-0005 | ✅ |
| TR-save-001 | save-persistence | 3 save slots; atomic write (.tmp → .dat) | ADR-0003 | ✅ |
| TR-save-002 | save-persistence | FileAccess bool return check (4.4+ MEDIUM risk) | ADR-0003 | ✅ |
| TR-save-003 | save-persistence | Restore order 10–33; sanctuary_state_restored deferred 1 frame | ADR-0003 | ✅ |
| TR-save-004 | save-persistence | Format version + migration registry | ADR-0003 | ✅ |
| TR-save-005 | save-persistence | Save format decision | ADR-0003 | ✅ |
| TR-save-006 | save-persistence | 4 auto-save triggers via EventBus | ADR-0003 | ✅ |
| TR-hero-001 | hero | CharacterBody2D scene root | ADR-0002 | ✅ |
| TR-hero-002 | hero | 12 stats; Tower-Synced Class (Chebyshev 3-cell) | — (ADR-0010 deferred) | ❌ |
| TR-hero-003 | hero | Tower Affinity sqrt scaling | — (ADR-0010 deferred) | ❌ |
| TR-hero-004 | hero | Event-driven targeting (no direct Monster refs) | — (ADR-0007 pending) | ❌ |
| TR-hero-005 | hero | 4 active skills + Ultimate | — (ADR-0010 deferred) | ❌ |
| TR-hero-006 | hero | 6 stat formulas (crit, lifesteal, affinity, etc.) | — (ADR-0010 deferred) | ❌ |
| TR-tower-001 | tower | 4 component slots; 4 archetypes; 4 tiers | — (ADR-0009 pending) | ❌ |
| TR-tower-002 | tower | Placement blocked during WAVE_ACTIVE | ADR-0008 | ✅ |
| TR-tower-003 | tower | Monster cache via EventBus; no direct Monster refs | — (ADR-0007 pending) | ❌ |
| TR-tower-004 | tower | would_block_all_paths() gate before placement | ADR-0008 | ✅ |
| TR-tower-005 | tower | Pre-placement perk (Scout phase only) | ADR-0008 | ✅ |
| TR-tower-006 | tower | Support archetype aura pulse model | — (ADR-0009 pending) | ❌ |
| TR-monster-001 | monster | Area2D scene root (not CharacterBody2D) | ADR-0002 | ✅ |
| TR-monster-002 | monster | MonsterResource data-driven stats; 3 tiers | — (ADR-0006, ADR-0009 pending) | ❌ |
| TR-monster-003 | monster | _pending_damage buffer flushed in _physics_process | — (ADR-0006 pending) | ❌ |
| TR-monster-004 | monster | Position-based movement (not physics-driven) | ADR-0002, ADR-0004 | ✅ |
| TR-monster-005 | monster | Dual-layer AnimatedSprite2D | — (ADR-0006 pending) | ❌ |
| TR-monster-006 | monster | Boss scan throttle + prepare-frames telegraph | — (ADR-0006 pending) | ❌ |
| TR-ds-001 | damage-status | Two pipelines: direct hit + DoT | — (ADR-0007 pending) | ❌ |
| TR-ds-002 | damage-status | await + is_instance_valid guard pattern | — (ADR-0007 pending) | ❌ |
| TR-ds-003 | damage-status | _lifesteal_pending Dictionary[int, float] | — (ADR-0007 pending) | ❌ |
| TR-ds-004 | damage-status | 5 status effect types + stack/duration rules | — (ADR-0007 pending) | ❌ |
| TR-ds-005 | damage-status | No direct call API — EventBus only | — (ADR-0007 pending) | ❌ |
| TR-path-001 | pathfinding | AStar2D Autoload (not NavigationServer) | ADR-0004 | ✅ |
| TR-path-002 | pathfinding | Route templates with cell_index_map | ADR-0004 | ✅ |
| TR-path-003 | pathfinding | Super-goal node for multi-goal convergence | ADR-0004 | ✅ |
| TR-path-004 | pathfinding | templates_ready event gates all spawning | ADR-0004 | ✅ |
| TR-path-005 | pathfinding | would_block_all_paths() speculative check | ADR-0004 | ✅ |
| TR-path-006 | pathfinding | Deferred dirty rebuild on tower changes | ADR-0004 | ✅ |
| TR-path-007 | pathfinding | 100+ simultaneous agents at 60 FPS | ADR-0004 | ⚠ Partial (budgeted; C1 HIGH risk — stress prototype required Sprint 1/2) |
| TR-wave-001 | wave-manager | 7-state phase lifecycle FSM | — (ADR-0012 recommended) | ❌ |
| TR-wave-002 | wave-manager | WaveConfig/WaveScript/WaveSpawnEntry Resources | — (ADR-0009 pending) | ❌ |
| TR-wave-003 | wave-manager | BOSS breach = wave-clear | — (ADR-0012 recommended) | ❌ |
| TR-wave-004 | wave-manager | templates_ready gate before first spawn | ADR-0004 | ✅ |
| TR-wave-005 | wave-manager | Wave-stuck watchdog (30s stalled / 60s force-clear) | — (ADR-0012 recommended) | ❌ |
| TR-wave-006 | wave-manager | wave_reward_scalar semantic contract | — (ADR-0012 recommended) | ❌ |
| TR-wave-007 | wave-manager | Penultimate-wave rule (sub-boss at wave N-1) | — (ADR-0012 recommended) | ❌ |
| TR-gc-001 | game-concept | All 9 systems communicate via EventBus only | ADR-0001 | ✅ |
| TR-gc-002 | game-concept | Autoload boot order: EB → Save → Grid → Path | ADR-0002 | ✅ |
| TR-gc-003 | game-concept | Mission states: SCOUT/WAVE_ACTIVE/INTERMISSION/etc. | ADR-0002 | ⚠ Partial (outer FSM only; Wave Manager inner FSM → ADR-0012) |
| TR-gc-004 | game-concept | 15–25 min default mission (session length formula) | — (design tuning, not architecture) | N/A |

**Coverage**: 29 / 57 requirements covered (51%). Remaining gaps closed by ADR-0006 (Monster movement), ADR-0007 (Damage pipeline), ADR-0009 (Resource data model), ADR-0012 (Wave Manager FSM), ADR-0010 (Hero, deferred), ADR-0011 (UI dual-focus, deferred).

---

## Required ADRs

### Accepted (Foundation + Core baseline)

**ADR-0001 — EventBus architecture** ✅ Accepted
Covers: TR-eb-001–006, TR-gc-001
Decision: single Autoload pub/sub backbone; typed signals; cascade depth limit; deferred dispatch for physics callers; batch threshold for high-frequency events.

**ADR-0002 — Scene and Autoload structure** ✅ Accepted
Covers: TR-gc-002, TR-gc-003 (partial), TR-hero-001, TR-monster-001, TR-monster-004, TR-path-001
Decision: Autoload boot order (EventBus → Save → Grid → Pathfinding); Autoloads vs scene-instanced nodes; CharacterBody2D vs Area2D scene root rationale.

**ADR-0003 — Save file format and serialization strategy** ✅ Accepted
Covers: TR-save-001–006
Decision: file format, atomic write protocol, version migration, FileAccess bool-return handling (4.4+ MEDIUM risk).

**ADR-0004 — Pathfinding: AStar2D route templates over NavigationServer** ✅ Accepted
Covers: TR-path-001–007, TR-wave-004
Decision: AStar2D over NavigationServer (post-cutoff risk avoidance); route template caching; super-goal node; deferred dirty rebuild; templates_ready gate; `get_path(from_cell)` API; `is_rebuild_pending()` for Wave Manager dual gate.

**ADR-0005 — Grid system data model** ✅ Accepted
Covers: TR-grid-001–004
Decision: 16×12 array; 5 CellTypes; Autoload with restricted write API (Tower System only); returns copies not references.

**ADR-0008 — Tower placement gate: 4-gate sequential check** ✅ Accepted (2026-05-19)
Covers: TR-tower-002, TR-tower-004, TR-tower-005
Decision: Phase → Resource → Footprint → Path integrity gates; `get_placement_preview()` runs Gates 1–3 only (no path check on hover); `duplicate_deep()` at commit for WaveConfig/TowerComponent (MEDIUM risk — 4.5+ API); `TowerMissionState` as RefCounted mission copy.

### Pending — write before the relevant system is implemented

**ADR-0006 — Monster movement: position-based over physics-driven**
Covers: TR-monster-002, TR-monster-003, TR-monster-005, TR-monster-006
Decision scope: Area2D root; position-based movement in _physics_process; _pending_damage buffer pattern; MonsterResource data model; dual-layer AnimatedSprite2D; why not CharacterBody2D.

**ADR-0007 — Damage pipeline: deferred dispatch and is_instance_valid guard**
Covers: TR-ds-001–005, TR-hero-004, TR-tower-003
Decision scope: EventBus-only D&S API surface; await + guard pattern; _lifesteal_pending; no direct node refs between combat systems.

**ADR-0009 — Resource data model for game entities**
Covers: TR-monster-002, TR-wave-002, TR-tower-001, TR-tower-006
Decision scope: MonsterResource, WaveConfig, WaveScript, WaveSpawnEntry, TowerComponent as Resource subclasses; which systems use Resources vs Dictionaries.

**ADR-0012 — Wave Manager FSM** (recommended)
Covers: TR-wave-001, TR-wave-003, TR-wave-005, TR-wave-006, TR-wave-007
Decision scope: 7-state FSM lifecycle; _wave_clear_fired latch; watchdog timer (30s stalled / 60s force-clear); BOSS breach = wave-clear; wave_reward_scalar contract; penultimate-wave sub-boss rule.

### Deferred — write when relevant GDDs land

**ADR-0010 — Hero Tower-Synced Class and Tower Affinity scaling**
Covers: TR-hero-002, TR-hero-003, TR-hero-005, TR-hero-006
Deferred: pure design logic with no novel engine APIs — fully specified in hero.md GDD.

**ADR-0011 — UI dual-focus handling for Godot 4.6**
Covers: HIGH risk in all Presentation systems
Deferred: no Presentation GDDs authored yet. Write when Mission HUD GDD moves beyond skeleton.

**Next ADRs to write**: ADR-0006 (Monster movement) and ADR-0007 (Damage pipeline) — both required before Monster and Damage & Status enter implementation. ADR-0012 (Wave Manager FSM) recommended before Wave Manager implementation.

---

## Architecture Principles

These five principles govern all technical decisions for Sanctuary Defenders. They are derived from the game concept, the 9 MVP GDDs, and the technical constraints of Godot 4.6.2.

**1. The EventBus is the only channel.**
No system holds a direct node reference to another system. All cross-system communication — damage application, wave state changes, tower placement, monster death — passes through typed EventBus signals. This is non-negotiable: it is the mechanism by which deep cross-system synergies (hero equipment affecting tower stats, Tarot altering wave composition) are made possible without brittle direct dependencies.

**2. Autoloads own infrastructure; scenes own gameplay.**
The four Autoloads (EventBus, Save, Grid, Pathfinding) are stateless services or read-mostly data structures. They boot in declared order, have no gameplay knowledge, and expose narrow read/write APIs. Gameplay logic lives in scene-instanced nodes. This separation keeps boot order deterministic and makes each system independently testable.

**3. Physics callers defer; main-thread callers are synchronous.**
Any event published from `_physics_process` uses `dispatch_deferred`. This prevents physics-thread subscribers from mutating scene state mid-step. The one structural invariant this creates: Monster HP changes are always applied one frame after the hit that caused them. This is a known, intentional latency — not a bug.

**4. Data-driven over hardcoded.**
MonsterResource, WaveConfig, WaveScript, TowerComponent, and all balance values are Godot Resource subclasses loaded from `.tres` files. No gameplay constants are hardcoded in GDScript. This makes tuning, modding, and content addition independent of code changes.

**5. Engine API choices are conservative and verified.**
Where a post-cutoff Godot API exists that the LLM cannot reliably reason about (NavigationServer 4.5+, dual-focus UI 4.6), the architecture deliberately uses the older, verified alternative (AStar2D, explicit focus management). Every engine API used in Foundation and Core layer code must be cross-referenced against `docs/engine-reference/godot/` before implementation.

---

## Open Questions

| # | Question | Blocking | Resolved By |
|---|----------|----------|-------------|
| OQ-1 | ~~Save file format: ConfigFile vs JSON vs binary store_var?~~ **RESOLVED** — ADR-0003 Accepted 2026-05-15. Decision recorded in ADR-0003. | — | ✅ ADR-0003 |
| OQ-2 | Performance target for frame budget, draw calls, and memory ceiling are not yet configured in technical-preferences.md. These are needed before any performance AC can be written for implementation stories. | Blocks implementation story sign-off | User decision — update technical-preferences.md |
| OQ-3 | SceneManager ownership: which node/Autoload owns scene transitions between SANCTUARY and MISSION states? This was not covered by any MVP GDD. | Blocks ADR-0002 | ADR-0002 |
| OQ-4 | ~~duplicate_deep() usage policy.~~ **RESOLVED** — ADR-0008 Accepted 2026-05-19. Decision: `duplicate_deep()` required at Tower placement commit and WaveConfig copy; `TowerMissionState` as RefCounted mission copy. MEDIUM risk: 4.5+ API (Knowledge Risk: MEDIUM in ADR-0008). | — | ✅ ADR-0008 |
| OQ-5 | Grid dimensions are 16×12 default but the GDD notes this is configurable per mission. The architecture does not yet specify how per-mission grid dimensions are communicated to Grid at mission load time. | Blocks mission-variable layout support | Mission Select GDD (not yet authored) |
