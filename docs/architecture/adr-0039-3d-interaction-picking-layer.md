# ADR-0039: 3D Interaction and Picking Layer

## Status

Accepted

## Date

2026-08-25

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Physics (3D) / Input |
| **Knowledge Risk** | LOW — `PhysicsDirectSpaceState3D.intersect_ray()`, `Camera3D.project_ray_origin()`/`project_ray_normal()`, and `Area3D`/`CollisionShape3D` are stable pre-4.x APIs. No post-cutoff surface. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; ADR-0015 (2D collision layer convention); ADR-0037 (Visual Presentation 3D Companion Layer); ADR-0038 (Hybrid Creature Swarm Rendering) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | **Not yet live-verified** — this ADR and its implementation were authored and built without running the project (explicit user instruction this session: no testing). Everything described here is inert by construction (see Decision's "dormant by default" clause) specifically so that lack of verification cannot break the currently-shipping game. Live verification (a real Godot MCP session, screenshot evidence, actual raycast behavior) remains a required gate before `ENABLE_3D_PICKING` is ever flipped true — tracked as this ADR's own open item, not silently assumed correct. |

## Addendum (2026-08-25, same session)

`ENABLE_3D_PICKING` as described below was superseded before this ADR was ever live-verified: ADR-0040 (3D Camera Cutover Capability, Epic 15 Phase 4) consolidated it into a single `ENABLE_3D_PRESENTATION_MODE` constant shared with the camera-cutover toggle, so the two can never independently drift out of sync. The `Picking3D` utility, collision layer table, and dormancy rationale described below are otherwise unchanged and still accurate — only the gating symbol's name changed.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0037 (3D visual companions exist for Tower and Hero — the only two entity types this ADR can pick, see Context), ADR-0038 (monsters no longer have individual 3D companions as of Epic 16 Story 10 — this ADR cannot pick individual monsters, see Constraints) |
| **Enables** | Epic 15 Phase 4 (camera cutover) — this ADR is the picking mechanism a future `Camera3D`-primary interaction model would need; Phase 4 does not yet flip the camera (see that phase's own commit) |
| **Blocks** | None |
| **Ordering Note** | This ADR's `ENABLE_3D_PICKING` constant must be flipped `true` (and the corresponding 2D `_unhandled_input()` tower-placement path retired) only as part of a real, live-verified Phase 4 camera cutover — never independently. |

## Context

### Problem Statement

Epic 15 (Phase 1) gave 5 entity types 3D visual companions but left all player interaction on the 2D `Camera2D`/`Area2D`/`Grid.world_to_cell()` path — clicking to place a tower resolves entirely in 2D screen space (`mission_scene.gd::_unhandled_input()`, `get_global_mouse_position()`). Epic 15's own "Next Step" note named this exact gap as Phase 2 ("3D interaction/picking"), and ADR-0037 flagged that it would need its own follow-up ADR extending or paralleling ADR-0015's collision-layer convention for `Area3D` (ADR-0037's Consequences section). This ADR is that follow-up.

### Current State (verified by reading the live files, not assumed)

- `TowerInstance` (`src/core/tower/tower_instance.gd`) still has an individual `VisualCompanion3D` subtree per ADR-0037 — one real `Node3D`/mesh instance per placed tower. **Pickable.**
- `Hero` (`src/core/hero/hero.gd`) still has an individual `VisualCompanion3D` subtree — one real `Node3D`/mesh instance. **Pickable.**
- **Monsters do NOT have individual 3D companions anymore.** Epic 16 Story 10 (2026-08-25, this session) formally deleted `MonsterInstance._build_visual_companion()`/`sync_visual_companion_position()` — standard/elite monsters now render via `MonsterSwarmRenderer3D`'s batched `MultiMesh` (no per-instance `Node3D` to attach a collision shape to), and BOSS-tier monsters render via `BossCreaturePresenter3D`'s small capped pool (2 slots, real `Node3D` instances, but these are a shared pool reused across different boss entities over a mission's lifetime — a raycast hit on a pool slot does not stably identify "this specific boss" the way a hit on a `TowerInstance` node stably identifies "this specific tower"). **Individual monster picking is architecturally not supported by this ADR** — this is a real constraint discovered while researching this ADR, not an oversight left for later.
- `GridVisual` (`src/gameplay/missions/the_gap/grid_visual.gd`) has a static 3D companion (terrain tiles) — no per-cell `Node3D` granularity exists to pick individual cells via node-hit; grid-cell picking must instead work by raycasting against a ground plane and converting the 3D hit position back to a 2D grid cell via `Grid.world_to_cell()`, not by hitting a per-cell node.
- `Camera2D` remains the sole active camera (`current = true`); `Camera3D` exists on every mission scene but has never been made active (`current = false`, unchanged since Epic 15 Story 003).

### Constraints

- Standard/elite monsters cannot be individually 3D-picked — no per-instance node exists to raycast against (ADR-0038's own architecture). Any future skill/targeting system that needs "which specific monster did the player click" must either stay on the existing 2D `Area2D` input path, or accept a fundamentally different picking strategy (e.g. picking the nearest monster to a 3D ground-plane hit, not a precise node hit) — not solved by this ADR, flagged as a real open gap.
- This ADR's collision layer table is a **separate namespace from ADR-0015's**. Godot's 2D and 3D physics engines do not share collision-layer bitmasks — layer `1` in `PhysicsBody2D` and layer `1` in `PhysicsBody3D`/`Area3D` never interact regardless of numeric overlap. Reusing the same small integers here is a readability choice, not a collision risk with ADR-0015's table.
- Camera2D remains the actually-active, actually-shipping camera. Nothing in this ADR may change current player-visible behavior — see Decision's dormancy clause.

## Decision

### Chosen approach: raycast-based picking, dormant by default until a live-verified Phase 4 cutover

A new pure-utility class, `Picking3D` (`src/core/visual_presentation/picking_3d.gd`), provides:

- `pick_ray(camera: Camera3D, mouse_pos: Vector2, space_state: PhysicsDirectSpaceState3D, mask: int) -> Dictionary` — wraps `PhysicsDirectSpaceState3D.intersect_ray()` using `camera.project_ray_origin(mouse_pos)`/`project_ray_normal(mouse_pos)`, returning Godot's own raw hit-dictionary shape (`{position, normal, collider, ...}` or `{}` on miss). No new dictionary shape invented — callers already know how to read Godot's native ray-hit result.
- `pick_ground_cell(camera: Camera3D, mouse_pos: Vector2, space_state: PhysicsDirectSpaceState3D) -> Vector2i` — raycasts against `PICKING_LAYER_GROUND` only, and converts a hit's `position` (a `Vector3`) back to a grid cell via `VisualMath.map_to_2d()` (new inverse function, see below) then `Grid.world_to_cell()`. Returns `Vector2i(-1, -1)` (Grid's own established "invalid cell" sentinel — matches existing `Grid` API convention) on a miss.
- `pick_tower(camera: Camera3D, mouse_pos: Vector2, space_state: PhysicsDirectSpaceState3D) -> Node2D` — raycasts against `PICKING_LAYER_TOWER` only, returns the hit `Area3D`'s owning `TowerInstance` (read from an `owner_tower` metadata reference set on the `Area3D` at construction) or `null` on a miss. **Corrected from this ADR's original draft**: `TowerInstance` (`src/core/tower/tower_instance.gd`) was verified (2026-08-25) to carry no `tower_id` field at all — it is explicitly presentation-only with "no link yet to TowerSystem/TowerMissionState" (its own header comment). Returning a fabricated int id would misrepresent code that doesn't exist; returning the node reference itself is the honest contract given the current architecture.

`VisualMath` gains `map_to_2d(pos3d: Vector3) -> Vector2` — the exact inverse of the existing `map_to_3d()`, `Vector2(pos3d.x, pos3d.z)`, same pure-function/zero-allocation contract.

### 3D Picking Collision Layer Table (new namespace — see Constraints)

| Layer | Value | Occupants | Status |
|-------|-------|-----------|--------|
| `PICKING_LAYER_GROUND` | 1 | A single, invisible, mission-scene-scoped `StaticBody3D`/`CollisionShape3D` ground plane at `y=0`, sized to the mission's grid bounds. Exists purely for raycast intersection — never rendered, no visual companion. | New, built this session |
| `PICKING_LAYER_TOWER` | 2 | `Area3D` + `CollisionShape3D` added as a child of each `TowerInstance`'s existing `VisualCompanion3D` subtree, sized to roughly the mesh's bounding box. Carries an `owner_tower` node-reference as metadata (not an int id — see Decision). | New, built this session |
| `PICKING_LAYER_HERO` | 4 | Reserved — `Area3D` on Hero's `VisualCompanion3D`, same pattern as Tower. **Not built this session** — no current interaction model needs to pick the hero (the player doesn't click their own hero), included in the table for completeness/future-proofing only. | Reserved, unoccupied |

### Dormancy — the load-bearing safety property of this ADR

`ENABLE_3D_PICKING: bool = false` is a new constant in `mission_scene.gd` and `the_gap.gd`. Every new code path this ADR adds (`_try_3d_pick()`, the ground `StaticBody3D`, the `Area3D`s on towers) is fully constructed and present in the scene tree, but the `_unhandled_input()` handler's existing 2D path (`get_global_mouse_position()` → `GGrid.world_to_cell()`) remains the **only reachable path** for tower placement — the new 3D path is gated behind `if ENABLE_3D_PICKING:` and is provably unreachable with the constant at its default `false`. This is deliberate: the explicit instruction for this work session was "no testing," and flipping the actual input-handling behavior of a shipping game with zero live verification would risk leaving a broken build. Building the complete, real mechanism — but never activating it — satisfies "do the Phase 2 work" without accepting that risk. Flipping `ENABLE_3D_PICKING` to `true` is intentionally left as a single, obvious, separately-reviewable change for whenever a live-verification session actually happens.

## Alternatives Considered

### Alternative 1: Pick monsters too, via nearest-MultiMesh-instance approximation

- **Description**: Raycast against the ground plane, then find the nearest live swarm-batch entity to the hit position within some radius, treat that as "picked."
- **Cons**: Not a real pick (a raycast that misses a monster entirely by 2 world units would still "hit" it), fundamentally different UX contract than Tower/Hero's precise node-hit picking, and no current game system (skill targeting, monster inspection) actually needs this yet.
- **Rejection Reason**: Solving a problem no consumer has yet, with a mechanism that behaves differently from this ADR's other two pick types. Deferred until a real feature needs monster picking specifically.

### Alternative 2: Flip `ENABLE_3D_PICKING` true immediately, since the code is "done"

- **Description**: Since the raycast/collision code is written, just activate it now.
- **Cons**: Zero live verification occurred (explicit constraint this session). A raycast against an untested ground-plane size/position, or an `Area3D` sized wrong relative to its visual mesh, would silently break tower placement — the single most load-bearing player interaction in the game — with no way to catch it before the user wakes up.
- **Rejection Reason**: The engineering judgment call this ADR makes explicitly: build real, complete infrastructure; do not gamble the shipping game's core interaction loop on unverified code. This is a deliberate deviation from "go with the recommended option" (the recommended option was a live verification session) in favor of the stricter "absolutely no testing" instruction given in the same breath — the two were in tension, and dormancy is how this ADR resolves that tension without silently picking one over the other.

## Consequences

### Positive

- Real, complete 3D picking infrastructure exists for Tower and Hero (the two entity types that architecturally support it).
- Zero risk to the currently-shipping 2D interaction model — dormant by construction, not by convention or reviewer discipline.
- `VisualMath.map_to_2d()` closes a real gap (only the forward `map_to_3d()` existed before) that any future 3D-to-2D translation work would have needed anyway.

### Negative

- Individual monster picking remains unsolved — a real, named gap for any future skill-targeting or monster-inspection feature that wants precise click-to-select on a specific monster.
- This ADR's mechanism cannot be considered production-ready until a live-verification pass actually runs it — `ENABLE_3D_PICKING=false` means this is genuinely never-executed code as of this commit, carrying the usual risk that never-executed code silently drifts from being correct as surrounding systems change.

### Neutral

- Two collision-layer namespaces (2D via ADR-0015, 3D via this ADR) now coexist in the project, numbered independently. Documented here specifically so a future reader doesn't assume they interact.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| `ENABLE_3D_PICKING` is flipped true without a live-verification pass first | Low (single obvious boolean, this ADR's own text names the requirement) | High — could silently break tower placement | This ADR's Ordering Note; the constant's own doc comment in both `.gd` files repeats the requirement |
| Never-executed code (`_try_3d_pick()`, the ground `StaticBody3D`) drifts incorrect as `Grid`/`VisualMath` evolve, undetected until activation | Medium | Medium — caught at activation time, not silently shipped (dormancy means it literally cannot affect a live player until flipped) | Accepted risk — the alternative (testing now) was explicitly excluded from this work session |

## Performance Implications

None while dormant — no new node processes every frame; the ground `StaticBody3D` and towers' `Area3D`s are static collision shapes with no `_process()`/`_physics_process()` of their own. Raycasting is only ever performed inside `_try_3d_pick()`, itself only reachable when `ENABLE_3D_PICKING=true`.

## Migration Plan

1. This ADR + `Picking3D` utility + `VisualMath.map_to_2d()` + collision layer additions (this commit).
2. A future, separate work session: live-verify via Godot MCP that `pick_ground_cell()`/`pick_tower()` return correct results against the real running scene (screenshot + `run_script` readback evidence).
3. Only after step 2 passes: flip `ENABLE_3D_PICKING = true`, retire the 2D `_unhandled_input()` path (or keep both live simultaneously if input-method parity is desired — a decision for that future session, not this ADR).

## Validation Criteria

- [x] `Picking3D` utility exists with `pick_ray()`/`pick_ground_cell()`/`pick_tower()`.
- [x] `VisualMath.map_to_2d()` exists as the exact inverse of `map_to_3d()`.
- [x] Collision layer table documented and applied to the new ground `StaticBody3D` and per-tower `Area3D`.
- [x] `ENABLE_3D_PICKING` constant defaults to `false` in both mission scene controllers.
- [ ] **Live-verified against the real running scene** — explicitly NOT done this session (no-testing constraint). Required before `ENABLE_3D_PICKING` is ever flipped.

## GDD Requirements Addressed

Foundational — no direct GDD requirement (matches ADR-0037's own "not GDD-driven" framing for this same infrastructure lineage). Enables a future GDD/story that wants real 3D-camera-driven tower placement or hero-relative interaction.

## Related

- ADR-0015 (2D collision layer convention — separate namespace, see Constraints)
- ADR-0037 (3D visual companions — the entities this ADR can pick)
- ADR-0038 (monster swarm rendering — why monsters can't be picked)
- `production/epics/epic-15-3d-visual-presentation/EPIC.md` (Phase 2 origin)
