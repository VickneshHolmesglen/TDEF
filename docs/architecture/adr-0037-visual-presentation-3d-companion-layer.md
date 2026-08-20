# ADR-0037: 2D-Simulated Gameplay, 3D-Rendered Presentation — Visual Companion Layer

## Status
Accepted

## Date
2026-08-20

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Rendering |
| **Knowledge Risk** | MEDIUM — the core mechanism (`Node3D` children under a `Node2D` root) is a stable, pre-4.x Godot capability, not itself post-cutoff API risk. The MEDIUM rating is for adjacent post-cutoff rendering changes (D3D12 default backend on Windows, glow-before-tonemap reorder) that this ADR does not use but that later phases (VFX/lighting) will need to account for. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/engine-reference/godot/modules/rendering.md`; `docs/engine-reference/godot/modules/physics.md`; ADR-0004 (pathfinding strategy — `AStar2D`); ADR-0006 (`per_monster_physics_process` centralization ban, registry); ADR-0015 (2D collision layer convention); ADR-0019 (`per_projectile_physics_process` centralization ban, registry) |
| **Post-Cutoff APIs Used** | None. No `Compositor`, no `use_hdr_2d`, no AgX/glow changes — explicitly deferred to a later "Rendering polish" phase, out of scope here. |
| **Verification Required** | **Done, live-verified this session** (Godot MCP, pinned 4.6.2.stable binary): a `Node2D`-rooted scene (`EntityRoot`) parenting a `Node3D` subtree (`Camera3D` + `DirectionalLight3D` + two `MeshInstance3D`-bearing `PackedScene` instances from the newly-added "Tower Defense Models" GLB pack) renders correctly with zero runtime errors — confirms the mixed-root pattern this ADR depends on, not just an all-`Node3D` scene (which was verified separately in an earlier spike). Screenshot evidence: `prototypes/3d-tower-defense-kit-spike/mixed_root_check.tscn`. **Also reviewed by godot-specialist** (engine-idiom validation pass): pattern confirmed idiomatic and no post-4.3 API changes affect it; two non-blocking gotchas folded into Risks below. Still unverified, deferred to Phase 1 implementation: behavior under the project's actual `.import` pipeline for dozens of concurrently-loaded GLB instances (memory/load-time budget), and interaction with existing `CanvasLayer`-based `HUD`/`Camera2D` when a real `Camera3D` is added to the actual `MissionScene`/`TheGap` tree rather than this isolated test scene. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — purely additive to the existing 2D-simulation architecture. |
| **Enables** | The full 2D→3D visual pivot roadmap discussed with the user: Phase 1 (gameplay scene conversion — Hero/Monster/TowerInstance/TheGap/MissionScene gain visual-companion subtrees), Phase 2 (3D interaction/picking), Phase 3 (VFX/shaders → `spatial`), Phase 4 (rendering polish), Phase 5 (3D art pipeline), Phase 6 (content re-authoring). This ADR is Phase 0 only. |
| **Blocks** | Phase 1 implementation stories cannot start until this ADR is Accepted. |
| **Ordering Note** | Must be read alongside ADR-0004, ADR-0006, ADR-0015, ADR-0019 — this ADR does not modify any of them; it explicitly constrains the new visual layer to operate *inside* their existing rules (see Decision, Constraint 2 and 3 below), not alongside or in place of them. |

## Context

### Problem Statement

The user wants to move Sanctuary Defenders' visuals from 2D sprites to 3D models (a newly-added Kenney-style "Tower Defense Models" asset pack), while explicitly choosing to keep gameplay *simulation* — grid math, pathfinding, combat resolution — in its existing 2D form (`Vector2` positions, `AStar2D` pathing). A throwaway spike (`prototypes/3d-tower-defense-kit-spike/`) confirmed the asset pack imports and renders correctly, and that a `Node2D`-rooted scene can parent a `Node3D` subtree without error. What's missing is the actual architectural contract: how does an entity whose position is authoritatively computed in 2D (by code this decision must not touch — 550 `Vector2` call sites across 54 files, per survey) get a 3D visual representation that stays in sync, without violating this project's existing centralized-update-loop rules (ADR-0006, ADR-0019) or introducing a second, competing form of gameplay state?

### Constraints

- Must NOT modify any of the 550 existing `Vector2` position call sites, `AStar2D` pathfinding (ADR-0004), or any gameplay-logic script's simulation math. The 2D simulation remains the single source of truth for position.
- Must NOT add per-node `_physics_process`/`_process` overrides to entity scenes for the sync step — ADR-0006 and ADR-0019 both explicitly forbid per-entity physics-process overrides (Monster, Projectile) because engine sibling-order is not a guaranteed-stable execution order, and this project relies on deterministic centralized passes (`MonsterManager`, `ProjectileManager`) for correctness (e.g. DEAD-priority ordering). The visual sync must run inside those same centralized passes.
- Must not introduce a second authoritative position (no writing back from the 3D visual layer into gameplay state, ever — one-way data flow only, sim → visual).
- Must follow ADR-0009's `Resource` + `GameDataRegistry` + `validate()` convention for any new data-driven content (mesh mapping), consistent with how every other content type (items, recipes) is already authored.
- Must not require `use_hdr_2d` or any 2D-glow-adjacent rendering path (already-registered forbidden pattern, `technical-preferences.md`).

### Requirements

- Every gameplay entity type that currently renders as a 2D sprite (Hero, Monster, Tower, projectiles, ground/grid tiles) must be able to gain a 3D visual representation without its owning script's simulation logic changing.
- The visual layer must update automatically whenever the entity's 2D `position` changes, with no gameplay-visible latency (same-frame).
- Swapping which 3D model represents a given entity/component type must be a data change (new `.tres`), not a code change.
- The existing fixed 2D camera framing (`Camera2D`, no custom zoom/offset in `MissionScene.tscn`/`the_gap.tscn` today) must have a 3D equivalent that reproduces a comparable fixed top-down/angled view — no free-orbit, no rotation (user decision).

## Decision

**Visual Companion pattern**: every gameplay entity's existing `Node2D`-rooted scene (`Hero.tscn`, `MonsterInstance.tscn`, `TowerInstance.tscn`, pooled `ProjectileVisual.tscn`, `the_gap.tscn`'s `GridVisual`) gains one additional child subtree — a `Node3D` (e.g. `VisualCompanion3D`) holding a `MeshInstance3D` instantiated from a `PackedScene` (the entity's assigned 3D model). The entity's `Node2D` root, its script, and its `Vector2 position` remain completely unchanged and remain the single source of truth. Nothing new is written back to gameplay state from the visual layer.

**Important engine clarification (godot-specialist review)**: a `Node3D` child of a `Node2D` parent does **not** inherit the parent's 2D transform — `Node2D` and `Node3D` are entirely separate transform hierarchies in Godot. `VisualCompanion3D`'s position is never offset by its `Node2D` parent's `position`; `map_to_3d()`'s output must be treated as an absolute world position, set directly, not as a relative/local offset. The Architecture Diagram's parent/child nesting below is a *lifecycle* relationship only (the 3D node dies for free when its 2D parent is freed) — it is not a spatial-inheritance relationship.

**Position sync** happens inside each system's *already-centralized* update pass, never a new per-node override:
- `MonsterManager._physics_process`'s existing centralized pass gains one additional line per monster: `monster.visual_companion.position_3d = map_to_3d(monster.position)`.
- `ProjectileManager`'s existing centralized pass does the same for pooled projectiles.
- `TowerInstance`/`Hero` (not centrally managed at that granularity today) sync in their own existing `_process`/`_physics_process` — this is not a *new* per-node override, since these two already have one; it gains one line, not a new callback.

**Coordinate mapping** (the `map_to_3d()` contract, the one new piece of shared code this ADR introduces): `Vector3(pos2d.x, layer_height[entity_type], pos2d.y)` — the 2D plane maps onto the 3D XZ plane, Y is reserved purely for visual layering, never read by gameplay logic. `layer_height` is a small fixed per-entity-type constant table (ground/tile = 0, monster/tower visual anchors = 0 — confirmed by the spike's live-queried `AABB` data that these Kenney meshes already have their origin at their own base, needing no per-type vertical correction — VFX/floating elements get a small positive offset). No dynamic/computed sorting logic is introduced — the project has zero `z_index`/`y_sort` usage today (confirmed by codebase search), and a true 3D camera resolves visual overlap via hardware depth-testing, which is strictly better than what the project has today, not a new problem to solve.

**Mesh resolution is data-driven**: a new `VisualMeshMappingResource` (`class_name`, extends `Resource`, follows ADR-0009's `GameDataRegistry`-backed + `validate()` convention exactly, same as `RecipeResource`/`ItemDefinitionResource`) with fields `entity_or_component_id: StringName` and `mesh_scene: PackedScene` (a **typed** `PackedScene` export, not a string path — matches `ItemDefinitionResource.icon: Texture2D`'s existing precedent for typed asset-reference exports, confirmed by godot-specialist review; gets Godot's automatic UID-based dependency tracking so moving/renaming the underlying `.glb`-derived scene doesn't silently break the reference the way a raw string path would). One `.tres` per mapped entity/component type, e.g. `assets/data/visual_meshes/goblin.tres` → points at whatever `.glb`-derived `PackedScene` currently represents a goblin (placeholder Kenney pieces today, custom fantasy models later per Phase 6 — swapping is a `.tres` edit only). Loaded and validated by `GameDataRegistry` at boot alongside every other data Resource.

**Camera**: a single `Camera3D`, added once per mission scene (not per-entity), fixed-angle, non-rotating, positioned/oriented to reproduce a comparable framing to the current `Camera2D`'s default view. Exact transform values are an implementation-time tuning task (Phase 1), not an architectural decision — this ADR fixes only that it is one static `Camera3D`, sibling to the existing `Camera2D` and `HUD` `CanvasLayer` within the same scene tree (both may coexist during the phased migration; `Camera2D.enabled`/`Camera3D.current` are mutually exclusive at any moment but nothing forces an all-or-nothing cutover).

### Architecture Diagram

```
MissionScene (Node2D)                      [UNCHANGED — simulation root]
├── GameplayRoot (Node2D)
│   ├── MonsterManager (Node)               [UNCHANGED — owns Vector2 sim,
│   │                                         centralized _physics_process,
│   │                                         gains 1 sync line per monster]
│   ├── TowerSystem (Node)                  [UNCHANGED, same pattern]
│   ├── Hero (Node2D, CharacterBody2D)      [UNCHANGED sim; existing
│   │   └── VisualCompanion3D (Node3D)       _physics_process gains 1 line]
│   │       └── MeshInstance3D              [NEW — this ADR]
│   ├── MonstersContainer (Node2D)
│   │   └── <MonsterInstance> (Node2D)      [UNCHANGED sim]
│   │       └── VisualCompanion3D (Node3D)  [NEW]
│   │           └── MeshInstance3D
│   ├── Camera2D                            [UNCHANGED, coexists during migration]
│   ├── Camera3D                            [NEW — fixed, non-rotating]
│   └── HUD (CanvasLayer)                   [UNCHANGED — Control/screen-space,
│                                              renders identically regardless
│                                              of 2D or 3D world content]
└── GameDataRegistry (Autoload)
    └── VisualMeshMappingResource[]         [NEW data type — entity_id → mesh]
```

### Key Interfaces

- `VisualMeshMappingResource` (new `Resource` subclass): `entity_or_component_id: StringName`, `mesh_scene: PackedScene`. `validate() -> Array[String]` per ADR-0009's contract, confirming `mesh_scene` is assigned (non-null).
- `map_to_3d(pos2d: Vector2, layer_height: float) -> Vector3` (pure function, shared utility — exact file location is an implementation detail, not fixed by this ADR): `Vector3(pos2d.x, layer_height, pos2d.y)`.
- No new EventBus events, no new signals — this is a presentation-only addition with zero gameplay-observable surface. `event-bus.md` is not touched by this ADR.

## Alternatives Considered

### Alternative B: Convert scene roots to `Node3D`, positions to `Vector3`
- **Description**: Change entity scene root types from `Node2D`/`CharacterBody2D` to `Node3D`/`CharacterBody3D`; simulation code operates on `Vector3` (with a constant/ignored axis) instead of `Vector2`.
- **Pros**: Single unified position representation; no separate "sim vs. visual" position ever exists.
- **Cons**: Touches all 550 `Vector2` call sites and both pathfinding ADRs (ADR-0004/0005); the exact blast radius the user chose 2.5D specifically to avoid.
- **Rejection Reason**: Directly contradicts the user's explicit 2.5D decision (keep sim in `Vector2`, `AStar2D` unchanged).

### Alternative C: Fully parallel visual tree, driven by a separate controller
- **Description**: Existing 2D scenes stay entirely untouched (no new child nodes at all); a separate top-level "presentation controller" node reads entity positions from outside and spawns/moves independent 3D visual nodes in a wholly separate part of the scene tree.
- **Pros**: Zero changes to any existing entity `.tscn`/`.gd` file.
- **Cons**: Doubles the live node count (one 2D logic node + one fully separate 3D visual node per entity, with no parent/child relationship); requires the controller to independently track entity lifecycle (spawn/despawn) in parallel with `MonsterManager`'s own lifecycle tracking — a second bookkeeping system that can desync (e.g. a monster removed from `MonsterManager` but its visual companion orphaned if the controller's own cleanup has a bug the manager's does not).
- **Rejection Reason**: The Visual Companion pattern (Decision, above) gets the same "no simulation script changes" property without a second lifecycle-tracking system — a `Node3D` child dies for free when its `Node2D` parent (already lifecycle-managed by `MonsterManager`) is freed, which a fully parallel tree does not get automatically.

## Consequences

### Positive
- Zero changes to gameplay simulation code, pathfinding, or the 550 `Vector2` call sites — the highest-risk part of the codebase (per the coupling survey) is completely untouched.
- Reuses this project's existing centralized-update-pass architecture (ADR-0006/ADR-0019) rather than fighting it — the visual sync is one line inside code that already runs correctly and deterministically.
- Mesh swapping (Kenney placeholders → custom fantasy models, per Phase 6) is a pure data change once `VisualMeshMappingResource` exists — no code changes needed for future art passes.
- Live-verified (this session) rather than assumed: the mixed `Node2D`-root/`Node3D`-child pattern renders with zero errors on the pinned 4.6.2.stable binary.
- Entity lifecycle is free — a `Node3D` visual child is destroyed automatically when its already-managed `Node2D` parent is freed; no second cleanup path to keep in sync.

### Negative
- Every entity scene gains one additional child node and one additional line in its owning manager's update pass — a small, permanent complexity tax on every future entity type, forever (until/unless a full 3D pivot is later done, Alternative B).
- Two coordinate systems now coexist project-wide (`Vector2` sim, `Vector3` visual) — any future developer must understand the mapping contract (`map_to_3d`) or risk confusing which one is authoritative. Mitigated by: one-way data flow (sim → visual, never reverse) and this ADR's explicit statement that `Vector2` position remains sole source of truth.
- `Camera2D` and `Camera3D` coexisting mid-migration means two rendering paths are live simultaneously until Phase 1 fully lands per entity type — a partially-migrated state is possible and must be handled gracefully (see Risks).

### Risks
- **Risk**: A monster/tower/etc. gets a `VisualCompanion3D` added inconsistently (some entity instances have it, some don't, mid-migration), producing a visually broken mixed-2D/3D scene.
  - **Mitigation**: Phase 1 converts one full entity type at a time (e.g. all monsters, then all towers), never partially within a type. `VisualMeshMappingResource.validate()` fails loudly (per ADR-0009's boot-time validation contract) if an entity type is declared as 3D-visual but has no mapping entry, rather than silently falling back to invisible.
- **Risk**: Import-time cost of dozens of concurrently-loaded GLB `PackedScene` instances (memory/load-time) is unverified at real gameplay scale (the spike only tested a handful of static instances, not the ~100-monster MVP scale ADR-0004 already assumes for pathfinding).
  - **Mitigation**: Flagged explicitly as unverified in Engine Compatibility above; Phase 1's implementation must live-verify at realistic monster-count scale before Acceptance of any Phase 1 ADR, using the same MCP-live-verification method already established as this project's practice (`VERSION.md`).
- **Risk**: The fixed `Camera3D`'s exact framing might not actually reproduce the current `Camera2D` view closely enough for existing HUD layout assumptions (HUD element positions in `mission_hud.gd` may implicitly assume specific screen-space-to-world-space relationships).
  - **Mitigation**: Deferred to Phase 1 implementation as a tuning task with live screenshot comparison against the current 2D view, per this project's own `src/CLAUDE.md` verification-driven-development rule.
- **Risk** (godot-specialist review): during the per-entity-type migration window, an entity's old `Sprite2D`/`AnimatedSprite2D` and its new `VisualCompanion3D` mesh can be simultaneously present (Migration Plan, step 2). `CanvasItem` (2D) content always composites **on top of** 3D viewport content — same layering mechanism `HUD`'s `CanvasLayer` already uses today — so the two will never depth-sort or visually intermix; the sprite will always fully occlude the mesh underneath it, not blend or z-fight with it.
  - **Mitigation**: This is actually convenient, not a hazard — it means the old sprite visually "wins" automatically during an in-progress conversion (no glitchy double-render), and the new mesh only becomes visible once the sprite is deliberately hidden/removed at the end of that entity type's migration step. No code needs to enforce this; it falls out of Godot's existing compositing order for free.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| *(None — infrastructure ADR)* | This ADR is not driven by a specific GDD requirement; it is foundational infrastructure for a presentation-layer technology change the user requested directly, not a game-design mechanic. No GDD currently specifies "3D visuals" as a requirement. | N/A — flagged here per template convention rather than fabricating a GDD linkage that doesn't exist. |

## Performance Implications
- **CPU**: One additional `Vector3` assignment per visual-companion entity per frame, inside an already-running centralized loop — negligible (O(1) per entity, no new O(n²) or allocation in the hot path, per `engine-code.md`'s zero-allocation rule: `map_to_3d()` must return a value type, no heap allocation).
- **Memory**: Additional `Node3D`/`MeshInstance3D`/mesh-resource memory per visual entity, on top of existing `Sprite2D`/`AnimatedSprite2D` memory (both may coexist during migration) — unverified at real scale (see Risks); must be checked against the project's 1GB memory ceiling (`technical-preferences.md`) before Phase 1 Acceptance.
- **Load Time**: Additional `PackedScene`/GLB import and instantiation cost at mission load — unverified at real monster-roster scale (see Risks).
- **Network**: N/A — no networking in this project.

## Migration Plan

This ADR establishes the mechanism only; it does not migrate any entity itself. Migration is intentionally phased (see the roadmap referenced in ADR Dependencies → Enables), one entity type at a time, each phase gated by its own implementation stories and live-verification pass:
1. Phase 1: convert one entity type at a time (recommended order: static/simple first — ground/grid tiles, then `TowerInstance`, then `MonsterInstance`, then `Hero`, then pooled projectiles last since ADR-0019's pooling adds re-acquisition timing complexity).
2. `Sprite2D`/`AnimatedSprite2D` nodes are not removed until their `VisualCompanion3D` replacement is confirmed working and `Camera3D` is switched to `current = true` — both may render simultaneously (harmlessly overlapping) during a single entity type's transition window, never permanently.
3. No mass "flip a switch" cutover — this ADR does not assume a hard migration date, consistent with the user's stated "eventually" framing.

## Validation Criteria
- A converted entity type renders its 3D visual companion at visually-correct position/scale matching its 2D `position` at all times during gameplay (spot-checked via live screenshot comparison, not just static scene inspection).
- No entity's `Vector2 position` or pathfinding behavior changes measurably (existing unit/integration tests for that entity type continue passing unmodified).
- `VisualMeshMappingResource.validate()` correctly fails boot for a missing/invalid mesh mapping (unit test, mirroring existing `RecipeResource`/`ItemDefinitionResource` validation test patterns).
- Memory and load-time impact measured at realistic ~100-monster mission scale stays within existing project budgets (`technical-preferences.md`).

## Related Decisions
- ADR-0004 (Pathfinding Strategy) — unchanged, explicitly protected by this ADR's constraints.
- ADR-0005 (Grid System Data Model) — unchanged.
- ADR-0006 (implied by registry `per_monster_physics_process` entry) — this ADR's sync step must live inside, not beside, its centralized pass.
- ADR-0009 (Resource Data Model) — `VisualMeshMappingResource` follows this convention exactly.
- ADR-0015 (Collision layer convention) — unchanged by this ADR; Phase 2 (3D interaction/picking) will need its own follow-up ADR extending or paralleling it for `Area3D`.
- ADR-0019 (implied by registry `per_projectile_physics_process` entry) — same constraint as ADR-0006, applied to pooled projectiles.
- `prototypes/3d-tower-defense-kit-spike/spike.tscn` and `mixed_root_check.tscn` — throwaway live-verification evidence this ADR's claims are based on, not project source.
