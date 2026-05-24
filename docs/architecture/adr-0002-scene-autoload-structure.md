# ADR-0002: Scene and Autoload Structure

## Status
Accepted

## Date
2026-05-16

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / Scene Management |
| **Knowledge Risk** | LOW — Autoload lifecycle, CharacterBody2D, Area2D, and scene transition APIs are in LLM training data and unchanged through 4.6 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Verify Autoload boot order is reflected in Project Settings. Verify SceneManager.gd can call `get_tree().change_scene_to_packed()` without ordering issues (boots 6th, after all data Autoloads). Verify WaveManager initialises to IDLE at boot and holds no scene-node references at startup. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus must be Accepted — SceneManager uses EventBus for scene-state broadcasts) |
| **Enables** | ADR-0005 (Grid system — Autoload #3); ADR-0006 (Monster movement — confirms Area2D scene root); all Foundation and Core implementation stories |
| **Blocks** | All implementation stories. Autoload boot order must be set in Project Settings before any scene can be run. |
| **Ordering Note** | Autoload #1 (EventBus) confirmed by ADR-0001. This ADR confirms the full 7-Autoload order and the Autoload/scene-instanced boundary for all 25 systems. Revised 2026-05-23: ADR-0009 added GameDataRegistry at position 5, SceneManager shifted to 6. Revised 2026-05-24: ADR-0012 confirmed WaveManager as Autoload at position 7, superseding the scene-instanced classification in the original decision (see Alternative C revision note). |

## Context

### Problem Statement
The game has 25 systems split across two top-level contexts (SANCTUARY and MISSION). Four systems require persistence across all scenes. One additional system must own scene loading/unloading between contexts. All other systems are context-specific and must be scene-instanced. This ADR establishes the Autoload boundary, boot order, scene hierarchy, and scene root node choices for mission-active entities.

### Constraints
- EventBus must boot first (all systems subscribe in `_ready()`).
- Save & Persistence must restore state before scene-instanced systems initialise, but after EventBus exists to receive auto-save triggers.
- Grid must boot before Pathfinding (Pathfinding reads Grid at startup).
- Pathfinding must exist before any mission scene loads (dispatches `templates_ready`).
- Sanctuary state must survive scene transitions — owned by Autoloads, not scene-instanced nodes.

### Requirements
- Autoload boot order is a deterministic invariant in Project Settings.
- Scene transitions between SANCTUARY and MISSION must handle loading screens and cleanup.
- Hero requires physics-based movement (`move_and_slide()`).
- Monster requires overlap detection but position-based movement (no physics-driven velocity).
- Wave Manager owns the inner mission phase FSM — it is an Autoload (position 7) that initialises to IDLE and communicates exclusively via EventBus (no direct references to scene-instanced nodes). See ADR-0012.

## Decision

### Autoload Boot Order (Project Settings → Autoloads)

| Order | Autoload | Script | Reason | Added by |
|-------|----------|--------|--------|----------|
| 1 | `EventBus` | `src/core/event_bus.gd` | All other Autoloads subscribe to it in `_ready()` | ADR-0002 |
| 2 | `SavePersistence` | `src/core/save_persistence.gd` | Boots before Grid/Pathfinding; subscribes to EventBus auto-save triggers | ADR-0002 |
| 3 | `Grid` | `src/core/grid.gd` | Pathfinding reads Grid at startup to build initial AStar2D graph | ADR-0002 |
| 4 | `Pathfinding` | `src/core/pathfinding.gd` | Dispatches `templates_ready`; must exist before mission scenes load | ADR-0002 |
| 5 | `GameDataRegistry` | `src/core/game_data_registry.gd` | Preloads all MonsterResources and TowerPerkRegistry at boot; must exist before WaveManager or any mission scene loads data | ADR-0009 |
| 6 | `SceneManager` | `src/core/scene_manager.gd` | Owns SANCTUARY↔MISSION transitions; boots after all data Autoloads | ADR-0002 (revised) |
| 7 | `WaveManager` | `src/gameplay/wave_manager.gd` | Mission FSM Autoload; initialises to IDLE; boots after all infrastructure and data Autoloads; communicates exclusively via EventBus | ADR-0012 |

**This order is a build invariant.** Adding any new Autoload requires an ADR revision to verify boot dependency ordering.

### Autoload / Scene-Instanced Boundary

| System | Type | Rationale |
|--------|------|-----------|
| EventBus | Autoload #1 | Cross-context infrastructure |
| Save & Persistence | Autoload #2 | Cross-context state; must survive scene transitions |
| Grid | Autoload #3 | Cross-context spatial data; read by Tower, Pathfinding, Hero |
| Pathfinding | Autoload #4 | Cross-context route service; must pre-exist mission scene |
| GameDataRegistry | Autoload #5 | Preloads entity Resource definitions at boot; read by WaveManager and Monster System |
| SceneManager | Autoload #6 | Cross-context transition owner |
| WaveManager | Autoload #7 | Mission FSM Autoload; IDLE between missions; EventBus-only cross-system communication; no direct scene-node references (see ADR-0012) |
| Hero | Scene-instanced | Mission-only; recreated each mission |
| TowerManager | Scene-instanced | Mission-only |
| MonsterManager | Scene-instanced | Mission-only |
| DamageStatusSystem | Scene-instanced | Mission-only |
| ConstellationSystem | Scene-instanced | Mission-only |
| Inventory, Resource Economy | Scene-instanced | State owned by Save; subscribe to EventBus |
| Crafting, Menagerie, Defense Building | Scene-instanced | Sanctuary context only |
| All Presentation (HUD, UI) | Scene-instanced | Context-specific |

### Scene Hierarchy

**Mission Scene** (`MissionScene.tscn`, root: `Node`):
```
MissionScene (Node)
├── World (Node2D — TileMapLayer, background, grid visuals)
├── TowerManager (Node)
│     └── [TowerInstance children — Node2D, one per placed tower]
├── MonsterManager (Node)
│     └── [MonsterInstance children — Area2D, one per live monster]
├── Hero (CharacterBody2D)
├── DamageStatusSystem (Node)
├── WaveManager (Node)
├── ConstellationSystem (Node)
└── MissionHUD (CanvasLayer)
```

**Sanctuary Scene** (`SanctuaryScene.tscn`, root: `Node`):
```
SanctuaryScene (Node)
├── SanctuaryWorld (Node2D — background, structures, visual state)
├── CraftingSystem (Node)
├── MenagerieSystem (Node)
├── DefenseBuildingSystem (Node)
├── InventorySystem (Node)
├── ResourceEconomy (Node)
├── MissionSelectSystem (Node)
└── SanctuaryUI (CanvasLayer)
```

### Entity Scene Root Choices

**Hero: `CharacterBody2D`**
- Requires `move_and_slide()` for physics-integrated player movement.
- `_physics_process()` for movement; `_process()` for input polling and attack timing.
- Attack range detection via a child `Area2D` (not the root node).

**Monster: `Area2D`**
- Position-based movement: monster position updated directly each `_physics_process()` by reading the next step in its route template. No velocity, no `move_and_slide()`.
- `Area2D` used for GOAL cell breach detection (overlap with goal zone triggers `monster_breached`).
- `_pending_damage` buffer flush and position advance occur in the same `_physics_process()` call.
- 100+ simultaneous Area2D instances avoid the inter-monster Jolt collision overhead that CharacterBody2D would require.

### SceneManager Responsibilities

```gdscript
# SceneManager (Autoload #6)
func transition_to_mission(mission_id: String) -> void
func transition_to_sanctuary() -> void

# Uses EventBus:
# Publishes scene_transition_started before unloading current scene
# Publishes scene_transition_completed after new scene is ready
```

**Context boundary rule**: SceneManager owns SANCTUARY↔MISSION loading/unloading. Wave Manager owns the inner mission phase FSM (SCOUT→WAVE_ACTIVE→INTERMISSION→MISSION_COMPLETE/DEFEAT). These two FSMs are independent — SceneManager does not know which mission phase is active; Wave Manager does not know which scene is loaded.

**Transition safety**: SceneManager only initiates transitions in response to terminal mission events (`mission_complete`, `hero_died`) — events Wave Manager emits only after its FSM has reached a terminal state. Mid-wave transitions are architecturally impossible.

### Architecture Diagram

```
PROJECT LAUNCH
  │
  ▼ Autoloads boot in order
  EventBus(1) → SavePersistence(2) → Grid(3) → Pathfinding(4) → GameDataRegistry(5) → SceneManager(6) → WaveManager(7)
  │
  ▼ SceneManager loads initial scene
  ┌──────────────────┐         ┌─────────────────────────┐
  │  SanctuaryScene  │  Scene  │     MissionScene        │
  │  Crafting        │  Mgr    │  Hero (CharacterBody2D) │
  │  Menagerie       │  loads  │  MonsterMgr (Area2D)    │
  │  Defense Bldg    │ ◄─────► │  TowerMgr (Node2D)      │
  │  Inventory       │         │  D&S, Constellation     │
  │  Resource Econ   │         │  MissionHUD             │
  └──────────────────┘         └─────────────────────────┘
  Autoloads persist across both scenes (EventBus, Save, Grid, Pathfinding, GameDataRegistry, SceneManager, WaveManager)
  WaveManager idles in IDLE state during SanctuaryScene; activates on mission_launched
```

## Alternatives Considered

### Alternative A: Root scene with scene swap (no SceneManager Autoload)
- **Description**: A persistent root scene is the main scene. SANCTUARY and MISSION sub-scenes are added/removed as children of a container node.
- **Pros**: No 5th Autoload; transitions handled inline by the root scene script.
- **Cons**: Root scene takes on SceneManager responsibilities without the clean Autoload lifecycle. Loading screens require additional scene tree manipulation. The Autoload pattern is already established for the other 4 infrastructure systems.
- **Rejection Reason**: Functionally equivalent to a SceneManager Autoload but with less clear ownership. Consistency with the existing 4 Autoloads favours a 5th dedicated Autoload.

### Alternative B: Monster as CharacterBody2D
- **Description**: Monsters use CharacterBody2D and `move_and_slide()` along route templates.
- **Pros**: Godot-native movement; built-in collision with environment.
- **Cons**: 100+ simultaneous CharacterBody2D instances each request Jolt collision resolution. Inter-monster collisions require avoidance logic. Physics-driven movement on a discrete cell-step route fights continuous physics integration.
- **Rejection Reason**: Jolt overhead for 100+ dynamic bodies exceeds the frame budget. Position-based Area2D achieves the same route-following with negligible physics cost. Monster GDD explicitly specifies Area2D root.

### Alternative C: Wave Manager as a 6th Autoload (original — superseded 2026-05-24)
- **Description**: Wave Manager is persistent across scenes as an Autoload.
- **Original rejection reason**: Per-mission state belongs in the mission scene; WaveManager depends on MissionScene-local nodes (MonsterManager, TowerManager) — an Autoload cannot safely hold direct node references.
- **Superseded by**: ADR-0012 established that WaveManager communicates exclusively via EventBus (no direct scene-node references). State is reset to IDLE between missions (EC-9 reset). These two design constraints — EventBus-only communication and explicit IDLE reset — resolve the original concern. WaveManager was reclassified as Autoload #7 by ADR-0012, and this ADR revised accordingly. The "per-mission state" concern is moot because the FSM's IDLE state is its between-mission resting state, not "no state."

## Consequences

### Positive
- The 7-Autoload order is a single, verifiable invariant — simple to audit in Project Settings.
- Scene-instanced systems reset cleanly on scene reload without Autoload cleanup complexity.
- SceneManager owns loading screens and transition cleanup as a single responsibility.
- Area2D monster roots allow 100+ simultaneous entities within the performance budget.

### Negative
- 5 global Autoload singletons — GDScript has no access modifiers to prevent misuse. Convention and code review are the only enforcement mechanisms.
- SceneManager exists in Sanctuary even when idle. Its idle state must be well-defined (no active mission reference held).

### Risks
- **Risk**: A developer adds an 8th Autoload without checking boot order → systems subscribe to EventBus before it exists. **Mitigation**: Boot order documented here and in the control manifest. New Autoloads require an ADR revision.
- **Risk**: SceneManager initiates a transition mid-wave. **Mitigation**: SceneManager only responds to terminal mission events (`mission_complete`, `hero_died`) which Wave Manager emits only from terminal FSM states.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-concept.md | Core Rule 10: framework-first architecture | Autoload boundary separates persistent infrastructure from context-specific gameplay |
| game-concept.md | States table: SANCTUARY / SCOUT / WAVE_ACTIVE / INTERMISSION / MISSION_COMPLETE / DEFEAT | SceneManager owns SANCTUARY↔MISSION boundary; Wave Manager owns inner FSM |
| hero.md | CharacterBody2D scene root | Confirmed in Entity Scene Root Choices |
| monster.md | Area2D scene root; position-based movement | Confirmed; CharacterBody2D alternative explicitly rejected |
| pathfinding.md | Pathfinding Autoload; boots before mission scenes | Confirmed as Autoload #4 |
| save-persistence.md | Sanctuary state survives scene transitions | SavePersistence as Autoload #2 — persists across all scenes |

**Technical Requirements covered**: TR-gc-002, TR-gc-003, TR-hero-001, TR-monster-001, TR-monster-004, TR-path-001

## Performance Implications
- **CPU**: 5 Autoloads with negligible per-frame overhead (EventBus and Grid have no `_process`).
- **Memory**: Area2D instances have a smaller physics footprint than CharacterBody2D — no velocity integration or dynamic collision resolution against other monsters.
- **Load Time**: SceneManager enables async loading screens — mission scene loads while transition UI is visible.
- **Network**: Not applicable.

## Migration Plan
Greenfield project. Set Project Settings → Autoloads in this exact order before creating any scene.

## Validation Criteria
- [ ] Project Settings → Autoloads lists all 7 in correct order: EventBus, SavePersistence, Grid, Pathfinding, GameDataRegistry, SceneManager, WaveManager.
- [ ] All scene-instanced systems connect to EventBus in `_ready()` without null-reference errors.
- [ ] SceneManager.transition_to_mission() and transition_to_sanctuary() complete without orphaned nodes or dangling connections.
- [ ] 100 simultaneous Area2D monster instances on a 16×12 grid at 60 FPS on minimum-spec PC hardware — confirmed by performance test.
- [ ] Hero `move_and_slide()` produces physics-integrated movement at configured move_speed.

## Related Decisions
- ADR-0001 — EventBus architecture (SceneManager and WaveManager use EventBus)
- ADR-0004 — Pathfinding strategy (Pathfinding as Autoload #4)
- ADR-0005 — Grid system (Autoload #3 — boots after EventBus and SavePersistence, before Pathfinding)
- ADR-0006 — Monster movement (Area2D root confirmed here)
- ADR-0009 — Resource data model (introduced GameDataRegistry as Autoload #5; SceneManager shifted to #6)
- ADR-0012 — Wave Manager FSM (confirmed WaveManager as Autoload #7; superseded Alternative C scene-instanced classification)
- `design/gdd/game-concept.md` — States and Transitions table
