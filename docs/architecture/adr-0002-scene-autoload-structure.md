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
| **Ordering Note** | Autoload #1 (EventBus) confirmed by ADR-0001. This ADR confirms the full Autoload order and the Autoload/scene-instanced boundary for all 25 systems. Revised 2026-05-23: ADR-0009 added GameDataRegistry at position 5, SceneManager shifted to 6. Revised 2026-05-24: ADR-0012 confirmed WaveManager as Autoload at position 7, superseding the scene-instanced classification in the original decision (see Alternative C revision note). Revised 2026-07-13: ADR-0018 added MissionEconomy at position 8 (owns the runtime gold balance; boots after WaveManager). **Revised 2026-07-17 (five times, same session)**: (1) Inventory reclassified **Autoload #9** (ADR-0016 correction) — ADR-0021's cross-system methods must be callable as bare globals (ADR-0020 Criterion A). (2) **DefenseBuilding added Autoload #10** (ADR-0024) for the identical reason (`is_tech_unlocked()`), renumbered from an original #9 once Inventory claimed that slot. (3) **Menagerie added Autoload #11** (ADR-0026) for the identical reason again (`request_sacrifice()`, Criterion B, called by Equipment Forge/ADR-0025). (4) **MissionSelect added Autoload #12** (ADR-0028) — this one for a *second*, independent reason beyond the Criterion-B `retry_current_mission()` call: `MissionRuntimeState` must survive the SANCTUARY→MISSION scene transition, which a scene-instanced node (its original classification here) cannot do since it is freed on scene unload. (5) **HeroSkillBuild added Autoload #13** (ADR-0030) for the same scene-transition-survival class of reason as MissionSelect — its resolved Ultimate/active-slot state must exist continuously across the SANCTUARY→MISSION boundary so a freshly-instantiated Hero receives it at `mission_launched`. Five Sanctuary-context systems in a row were originally designed as scene-instanced per this ADR's own Boundary table and each had to be corrected once their actual GDD-specified requirements were examined — exactly the recurring pattern this ADR's own Risks section (added after the third correction, and explicitly not sufficient to prevent the fourth or fifth) flagged as worth checking for on every new ADR. With all 11 originally-required ADRs from the 2026-07-17 review now written, this pattern should be considered closed for this batch — any future Sanctuary-context system ADR should check this boundary table *first*. The tables below are updated accordingly; this remains a 13-Autoload build invariant, not 8. **Revised 2026-07-25**: `SceneManager` gained a 3rd top-level scene-transition context, `TAROT_DECK` (`transition_to_tarot_deck_ui()`, mirroring `transition_to_sanctuary()` exactly, loading the new `TarotDeckUIScene.tscn`), closing Sanctuary UI Epic 10 Story 010's/Tarot Deck UI Epic 11 Story 002's own flagged "no scene-transition entry point exists" gap. This Decision's own Problem Statement below still says "two top-level contexts (SANCTUARY and MISSION)" — that sentence is now stale; not rewritten in place so this note stays the visible record of the drift rather than silently editing history. A future formal revision pass should fold `TAROT_DECK` into the Decision text itself and resolve ADR-0020's still-open Criterion A/B classification of the Loadout call (sanctuary-ui.md OQ-9) in the same pass. **Revised 2026-07-25 (same day, separate finding)**: unlike `TAROT_DECK`, the `MISSION` context did NOT gain a new top-level context — `res://src/scenes/MissionScene.tscn` now exists for the first time (previously `SceneManager.DEFAULT_MISSION_SCENE_PATH` resolved to nothing) and is a single scene that hosts BOTH the Mission Select browsing/configuring screen and the live gameplay assembly, switching between them internally based on `MissionSelect.state` — the same shell-plus-switchable-content pattern `SanctuaryUI`/`TarotDeckUI` already use, applied inside one context rather than by adding a 4th. `Sanctuary UI`'s `confirm_launch_depart()` now calls `GSceneManager.transition_to_mission("")` for real, closing Epic 10 Story 009's own flagged "no Mission Select browsing screen exists" gap. Two real bugs found and fixed in `MissionSelect` while building this: `confirm_launch()` had never called `Grid.initialize()` on first launch (only `retry_current_mission()` did), and `reset_to_defaults()` left `state`/`_current_mission_id`/`difficulty_tier`/`_run_modifiers`/all `_runtime_*` fields untouched. Live-verified end-to-end via Godot MCP. |

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
- Mission Economy owns the runtime gold balance — it is an Autoload (position 8) that resets to 0 on `mission_launched`, mutates only via the `resources_changed` EventBus subscription, and exposes a direct-call read API (`get_gold_balance()`, `can_afford()`) for latency-sensitive callers such as Tower's placement gate. See ADR-0018.

## Decision

### Autoload Boot Order (Project Settings → Autoloads)

| Order | Autoload | Script | Reason | Added by |
|-------|----------|--------|--------|----------|
| 1 | `EventBus` | `src/core/event_bus.gd` | All other Autoloads subscribe to it in `_ready()` | ADR-0002 |
| 2 | `SavePersistence` | `src/core/save_persistence.gd` | Boots before Grid/Pathfinding; subscribes to EventBus auto-save triggers | ADR-0002 |
| 3 | `Grid` | `src/core/grid.gd` | Pathfinding reads Grid at startup to build initial AStar2D graph | ADR-0002 |
| 4 | `Pathfinding` | `src/core/pathfinding.gd` | Dispatches `templates_ready`; must exist before mission scenes load | ADR-0002 |
| 5 | `GameDataRegistry` | `src/core/game_data_registry.gd` | Preloads all MonsterResources and TowerPerkRegistry at boot; must exist before WaveManager or any mission scene loads data | ADR-0009 (Accepted 2026-05-24) |
| 6 | `SceneManager` | `src/core/scene_manager.gd` | Owns SANCTUARY↔MISSION transitions; boots after all data Autoloads | ADR-0002 (revised) |
| 7 | `WaveManager` | `src/gameplay/wave_manager.gd` | Mission FSM Autoload; initialises to IDLE; boots after all infrastructure and data Autoloads; communicates exclusively via EventBus | ADR-0012 (Accepted 2026-05-24) |
| 8 | `MissionEconomy` | `src/core/mission_economy.gd` | Owns the runtime gold balance (`_gold_balance: int`); resets on `mission_launched`, mutates only via `resources_changed`; boots after WaveManager | ADR-0018 (Accepted 2026-07-13) |
| 9 | `Inventory` | `src/core/inventory.gd` | Owns `inventory_item_data`; exposes `has_items()`/`has_room_for()`/`clear_damaged_flag()`/`apply_rune_to_item()` as direct-call methods (ADR-0020 Criterion A) to Crafting, Equipment Forge, Menagerie, Defense Building; only depends on GameDataRegistry (#5), appended after MissionEconomy to avoid renumbering 1–8 | ADR-0016 (Accepted 2026-07-11; Autoload status resolved 2026-07-17), ADR-0021 |
| 10 | `DefenseBuilding` | `src/core/defense_building.gd` | Owns the tech/structure ledgers; exposes `is_tech_unlocked()` as a direct-call method (ADR-0020 Criterion A) to Crafting; boots after Inventory since it calls Inventory's methods | ADR-0024 (Proposed 2026-07-17) |
| 11 | `Menagerie` | `src/core/menagerie.gd` | Owns creature lifecycle state; exposes `request_sacrifice()` as a direct-call method (ADR-0020 Criterion B) to Equipment Forge; boots after DefenseBuilding, no Autoload-time dependency between the two | ADR-0026 (Proposed 2026-07-17) |
| 12 | `MissionSelect` | `src/core/mission_select.gd` | Owns mission catalogue completion state and `MissionRuntimeState`; exposes `retry_current_mission()` as a direct-call method (ADR-0020 Criterion B) to Mission HUD; MissionRuntimeState must survive the SANCTUARY→MISSION scene transition, which requires Autoload status independent of the direct-call reason; boots after Menagerie, no Autoload-time dependency between the two | ADR-0028 (Proposed 2026-07-17) |
| 13 | `HeroSkillBuild` | `src/core/hero_skill_build.gd` | Owns equippable-skill library, active/passive slot bindings, and Ultimate derivation; resolved Ultimate/slot state must exist continuously across the SANCTUARY→MISSION transition so a freshly-instantiated Hero receives it at `mission_launched`; boots after MissionSelect, no Autoload-time dependency between the two | ADR-0030 (Proposed 2026-07-17) |
| 14 | `AudioSystem` | `src/core/audio/audio_system.gd` | Owns the procedural bus graph and generic EventBus-driven cue dispatch; must be cross-context (bus volumes and cue mappings apply identically in Sanctuary and Mission); no Autoload-time dependency on 9-13, appended after HeroSkillBuild to avoid renumbering | **None** — Epic 12 shipped without a dedicated ADR (matches Sanctuary UI/Tarot Deck UI's own established precedent, per `epic-12-audio-system/EPIC.md`'s own Governing ADRs table); backfilled into this table 2026-08-12 |
| 15 | `Encyclopedia` | `src/core/encyclopedia/encyclopedia.gd` | Owns the cross-system discovery ledger (species/rune/recipe entries); must be cross-context since discovery events fire from both Mission (monster/rune discovery) and Sanctuary (crafting/menagerie) systems; `SaveRestorer` at `restore_order=35`, the highest in the project (restores last, after every system it logs discoveries from); boots after AudioSystem, no Autoload-time dependency | **None** — Epic 13 shipped without a dedicated ADR (same established precedent, per `epic-13-encyclopedia/EPIC.md`'s own Governing ADRs table); backfilled into this table 2026-08-12 |
| 16 | `Tarot` | `src/core/tarot/tarot.gd` | Owns the Tarot deck/mastery/rune-discovery ledgers; converted from scene-instanced (its original ADR-0027 classification) to Autoload to fix a live save-data-loss bug (`production/qa/bugs/BUG-0001.md`) and make its `is_card_unlocked()` reachable from Sanctuary UI (ADR-0034's flagged gap); boots after Encyclopedia, no Autoload-time dependency | ADR-0035 (Accepted 2026-08-12) |

**This order is a build invariant.** Adding any new Autoload requires an ADR revision to verify boot dependency ordering. **16 Autoloads total** (corrected 2026-08-12 — this table previously stopped at 13 despite `project.godot` already listing 16; see this ADR's own "Known staleness" note, now resolved by this backfill).

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
| MissionEconomy | Autoload #8 | Owns the runtime gold balance; resets on `mission_launched`; EventBus-only mutation, direct-call read API (see ADR-0018) |
| Inventory | Autoload #9 | Owns `inventory_item_data`; direct-call query/mutation API consumed by 4 Sanctuary systems (see ADR-0016 correction, ADR-0021) — **reclassified 2026-07-17**, was originally scene-instanced in this ADR |
| DefenseBuilding | Autoload #10 | Owns the tech/structure ledgers; direct-call read API (`is_tech_unlocked()`) consumed by Crafting (see ADR-0024) — **added 2026-07-17** |
| Menagerie | Autoload #11 | Owns creature lifecycle state; direct-call action API (`request_sacrifice()`) consumed by Equipment Forge (see ADR-0026) — **reclassified 2026-07-17**, was originally scene-instanced in this ADR |
| MissionSelect | Autoload #12 | Owns mission completion ledger and `MissionRuntimeState`; direct-call action API (`retry_current_mission()`) consumed by Mission HUD (see ADR-0028) — **reclassified 2026-07-17**, was originally scene-instanced in this ADR; `MissionRuntimeState` survival across the SANCTUARY→MISSION scene transition is an independent, additional reason for Autoload status beyond the direct-call requirement |
| HeroSkillBuild | Autoload #13 | Owns equippable-skill library, active/passive slot bindings, Ultimate derivation (see ADR-0030) — **new system, added 2026-07-17**; resolved Ultimate/slot state must exist continuously across the SANCTUARY→MISSION transition so a freshly-instantiated Hero receives it at `mission_launched` |
| AudioSystem | Autoload #14 | Owns the procedural bus graph and generic cue dispatch; cross-context by nature (bus volumes/cue mappings apply identically in both scenes) — **added 2026-07-25, backfilled into this table 2026-08-12**, no dedicated ADR (Epic 12's own established precedent) |
| Encyclopedia | Autoload #15 | Owns the cross-system discovery ledger; cross-context since discovery events fire from both Mission and Sanctuary systems; `SaveRestorer` at `restore_order=35` (highest in the project) — **added 2026-07-25, backfilled into this table 2026-08-12**, no dedicated ADR (Epic 13's own established precedent) |
| Tarot | Autoload #16 | Owns the Tarot deck/mastery/rune-discovery ledgers; direct-call read API (`is_card_unlocked()`) consumed by Building Upgrade — **reclassified 2026-08-12** from scene-instanced (its original ADR-0027 classification), fixing a live save-data-loss bug and a Sanctuary-UI-reachability gap in the same change (see ADR-0035) |
| Hero | Scene-instanced | Mission-only; recreated each mission |
| TowerManager | Scene-instanced | Mission-only |
| MonsterManager | Scene-instanced | Mission-only |
| DamageStatusSystem | Scene-instanced | Mission-only |
| ConstellationSystem | Scene-instanced | Mission-only |
| Resource Economy | Scene-instanced | State owned by Save; subscribes to EventBus; no direct-call surface (see ADR-0017) |
| Crafting | Scene-instanced | Sanctuary context only; no other system calls into it directly |
| Equipment Forge | Scene-instanced | Sanctuary context only; calls Inventory/Menagerie as caller, but nothing calls into it directly (see ADR-0025) |
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
├── ConstellationSystem (Node)
└── MissionHUD (CanvasLayer)
```
> **Note**: `WaveManager` is Autoload #7 — not a scene-instanced child of MissionScene.
> It initialises to IDLE at boot and activates on `mission_launched` via EventBus (see ADR-0012).
```

**Sanctuary Scene** (`SanctuaryScene.tscn`, root: `Node`):
```
SanctuaryScene (Node)
├── SanctuaryWorld (Node2D — background, structures, visual state)
├── CraftingSystem (Node)
├── EquipmentForgeSystem (Node)
├── ResourceEconomy (Node)
└── SanctuaryUI (CanvasLayer)
```
> **Note** (revised 2026-07-17, four times, same session): `InventorySystem`, `DefenseBuildingSystem`, `MenagerieSystem`, and `MissionSelectSystem` are **not** children of this scene — all four are Autoloads (#9, #10, #11, #12 respectively, see Autoload Boot Order above), each reclassified from an original scene-instanced listing here so their query/mutation/action methods are callable as direct-Autoload calls (ADR-0020 Criterion A/B) by Crafting, Equipment Forge, Mission HUD, and each other, without any of those callers holding a node reference into this scene. MissionSelect's reclassification (ADR-0028) has a second, independent justification beyond the direct-call requirement: its `MissionRuntimeState` must survive the SANCTUARY→MISSION scene transition, which this scene's own teardown would otherwise destroy. `EquipmentForgeSystem` remains scene-instanced (added to this hierarchy 2026-07-17) — nothing calls into it directly, only out of it, so it needs no Autoload status (see ADR-0025 Alternative B).

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
  EventBus(1) → SavePersistence(2) → Grid(3) → Pathfinding(4) → GameDataRegistry(5) → SceneManager(6) → WaveManager(7) → MissionEconomy(8) → Inventory(9) → DefenseBuilding(10) → Menagerie(11) → MissionSelect(12) → HeroSkillBuild(13) → AudioSystem(14) → Encyclopedia(15) → Tarot(16)
  │
  ▼ SceneManager loads initial scene
  ┌──────────────────┐         ┌─────────────────────────┐
  │  SanctuaryScene  │  Scene  │     MissionScene        │
  │  Crafting        │  Mgr    │  Hero (CharacterBody2D) │
  │  EquipmentForge  │  loads  │  MonsterMgr (Area2D)    │
  │  Resource Econ   │ ◄─────► │  TowerMgr (Node2D)      │
  │                  │         │  D&S, Constellation     │
  │                  │         │  MissionHUD             │
  └──────────────────┘         └─────────────────────────┘
  Autoloads persist across both scenes (EventBus, Save, Grid, Pathfinding, GameDataRegistry, SceneManager, WaveManager, MissionEconomy, Inventory, DefenseBuilding, Menagerie, MissionSelect, HeroSkillBuild, AudioSystem, Encyclopedia, Tarot)
  WaveManager idles in IDLE state during SanctuaryScene; activates on mission_launched
  MissionEconomy holds a stale balance during SanctuaryScene; resets to 0 on the next mission_launched
  Inventory, DefenseBuilding, Menagerie, MissionSelect, and HeroSkillBuild are always live (both scenes) but their screens are only reachable while SanctuaryScene is loaded — Sanctuary-only per their own GDDs' Rule 11/similar. MissionSelect's MissionRuntimeState and HeroSkillBuild's resolved Ultimate/slot bindings are the two pieces of this group actively read DURING MissionScene (the former by retry_current_mission() on DEFEAT; the latter by the freshly-instantiated Hero at mission_launched) — the others are read only in Sanctuary.
  AudioSystem and Encyclopedia are genuinely cross-context (bus/cue state and discovery logging both apply in either scene). Tarot is read during MissionScene too, as of ADR-0036 — Wave Manager's own consumption of mission_modifier_applied calls GTarot.compute_rune_bonus() at every WAVE_ACTIVE entry.
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
- The 10-Autoload order is a single, verifiable invariant — simple to audit in Project Settings.
- Scene-instanced systems reset cleanly on scene reload without Autoload cleanup complexity.
- SceneManager owns loading screens and transition cleanup as a single responsibility.
- Area2D monster roots allow 100+ simultaneous entities within the performance budget.
- Inventory/DefenseBuilding/Menagerie/MissionSelect/HeroSkillBuild as Autoloads means their direct-call query/action APIs (ADR-0021, ADR-0024, ADR-0026, ADR-0028, ADR-0030) never require a caller to hold a node reference into any of the five — closes the gap that would otherwise force Crafting/Equipment Forge/Mission HUD/Hero into an ADR-0001 violation just to read their state or trigger their actions.
- MissionSelect's and HeroSkillBuild's Autoload status additionally means their session-critical state (`MissionRuntimeState`, resolved Ultimate/slot bindings) genuinely survives the SANCTUARY→MISSION transition — bugs both ADR-0028 and ADR-0030 caught before they could manifest as runtime data-loss defects.

### Negative
- 16 global Autoload singletons (corrected 2026-08-12 — this figure was left at 13 for over two weeks after AudioSystem/Encyclopedia shipped, and Tarot's own conversion added a 16th; see "Known staleness" note below) — GDScript has no access modifiers to prevent misuse. Convention and code review are the only enforcement mechanisms.
- SceneManager exists in Sanctuary even when idle. Its idle state must be well-defined (no active mission reference held).
- Inventory, DefenseBuilding, Menagerie, MissionSelect, and HeroSkillBuild now persist for the entire game lifetime rather than being freed/recreated with the Sanctuary scene — their internal state must be explicitly reset only via `SaveRestorer.reset_to_defaults()` (a new-game path), never implicitly by scene teardown, since there is no scene teardown for an Autoload. (MissionSelect's `MissionRuntimeState` and HeroSkillBuild's resolved Ultimate are the exceptions within this group — both are explicitly never persisted, so `reset_to_defaults()` need not clear them, only each system's actually-persisted structures.)

### Risks
- **Risk**: A developer adds a 14th Autoload without checking boot order → systems subscribe to EventBus before it exists. **Mitigation**: Boot order documented here and in the control manifest. New Autoloads require an ADR revision.
- **Risk** (pattern observed 2026-07-17, five times in one session — the strengthened mitigation added after the third occurrence did not prevent the fourth or fifth): a system's GDD specifies a cross-system call, or a state-survival requirement, that only becomes possible once that system is reclassified from scene-instanced to Autoload, and this ADR — despite self-declaring the Autoload boundary a "build invariant" — was not updated in lockstep each time until an explicit follow-up pass caught it. **Mitigation (closed for this batch)**: any future ADR that (a) adds a direct-call exception (ADR-0020 Criterion A/B) to a system currently listed as scene-instanced in this ADR's Boundary table, OR (b) requires state to survive a SANCTUARY↔MISSION scene transition for a system not already an Autoload, must update this ADR's boot-order table, boundary table, scene hierarchy, and validation criteria in the same pass. All 11 originally-required ADRs from the 2026-07-17 architecture review are now written (ADR-0020 through ADR-0030) — five of them needed this correction. Any *future* system's ADR (beyond this batch) should check this Boundary table **before** drafting, not after; this pattern should now be considered a known, closed risk for the current batch rather than an open one.
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
- **CPU**: 16 Autoloads (corrected 2026-08-12, was stale at 8), the large majority with negligible per-frame overhead (EventBus, Grid, MissionEconomy, and most of the later-added query/ledger Autoloads have no `_process`).
- **Memory**: Area2D instances have a smaller physics footprint than CharacterBody2D — no velocity integration or dynamic collision resolution against other monsters.
- **Load Time**: SceneManager enables async loading screens — mission scene loads while transition UI is visible.
- **Network**: Not applicable.

## Migration Plan
Greenfield project. Set Project Settings → Autoloads in this exact order before creating any scene.

## Validation Criteria
- [x] Project Settings → Autoloads lists all 16 in correct order: EventBus, SavePersistence, Grid, Pathfinding, GameDataRegistry, SceneManager, WaveManager, MissionEconomy, Inventory, DefenseBuilding, Menagerie, MissionSelect, HeroSkillBuild, AudioSystem, Encyclopedia, Tarot. Confirmed against `project.godot`'s real `[autoload]` section 2026-08-12.
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
- ADR-0018 — Mission Economy gold balance (added MissionEconomy as Autoload #8)
- ADR-0016 — Inventory Storage Model (resolved Inventory's Autoload status to #9, 2026-07-17)
- ADR-0021 — Inventory cross-system query/mutation API (the reason Inventory needed Autoload status)
- ADR-0024 — Defense Building tech tree data model (added DefenseBuilding as Autoload #10, 2026-07-17)
- ADR-0025 — Equipment Forge cross-system aggregation (the reason Menagerie needed Autoload status)
- ADR-0026 — Menagerie creature lifecycle state machine (added Menagerie as Autoload #11, 2026-07-17)
- ADR-0028 — Mission Select runtime state and retry architecture (added MissionSelect as Autoload #12, 2026-07-17)
- ADR-0030 — Hero Skill Build Ultimate lookup-table architecture (added HeroSkillBuild as Autoload #13, 2026-07-17)
- ADR-0035 — Tarot Autoload Conversion (added Tarot as an Autoload, 2026-08-12 — fixes `production/qa/bugs/BUG-0001.md`)
- ADR-0036 — Tarot Modifier Consumption (Wave Manager reads `GTarot.compute_rune_bonus()` directly, made possible by ADR-0035's conversion)
- `production/epics/epic-12-audio-system/EPIC.md` — AudioSystem shipped as Autoload #14 without a dedicated ADR (established precedent)
- `production/epics/epic-13-encyclopedia/EPIC.md` — Encyclopedia shipped as Autoload #15 without a dedicated ADR (same precedent)
- `design/gdd/game-concept.md` — States and Transitions table

**Known staleness — RESOLVED 2026-08-12**: this ADR's own Autoload position table was previously last fully revised 2026-07-17 (through Autoload #13, HeroSkillBuild) and had never been updated for `AudioSystem` (#14, no dedicated ADR), `Encyclopedia` (#15, no dedicated ADR), or `Tarot` (#16, ADR-0035) — all three backfilled into this ADR's boot-order table, boundary table, architecture diagram, and every stale count reference (13→16) in this pass.
