# Hybrid Swarm Rendering — Qwen Implementation Blueprint

## Purpose and authority

This is the no-ambiguity implementation handoff for ADR-0038. **Qwen authors all GDScript, shaders, scenes, resources, and tests.** Codex owns this architecture; implementation must not change the medium split or gameplay rules. If a named path differs in the live tree, Qwen must report the discrepancy before substituting an architecture.

## Non-negotiable boundaries

- `MonsterEntity`/`MonsterManager` keep `Area2D`, `Vector2`, pathfinding, damage, lifecycle, and ADR-0006 ordering authoritative.
- No per-monster `_process()`/`_physics_process()`.
- No EventBus event for recurring presentation synchronization.
- Presentation never writes gameplay state.
- No unique material per standard creature and no runtime `instance_count` resizing.
- `Viewport.use_hdr_2d` is forbidden.
- Hero, tower, terrain, building, camera, and projectile portions of ADR-0037 are untouched.

## File and module ownership

### New production modules

| Proposed path | Responsibility |
|---------------|----------------|
| `src/core/visual_presentation/creature_atlas_mapping_resource.gd` | Typed Resource describing creature ID/family, atlas texture, grid, animation clips, body dimensions/foot anchor, batch/render variant, and validation. No runtime state. |
| `src/core/visual_presentation/monster_presentation_handle.gd` | Value-like handle: batch ID/key, slot index, generation. No Node ownership. |
| `src/core/visual_presentation/monster_presentation_snapshot.gd` | Compact immutable-per-publish presentation input: entity ID, mapped world transform, frame, flash, status mask, facing/variant, lifecycle presentation command. |
| `src/core/visual_presentation/monster_swarm_batch.gd` | Owns one dense body MultiMesh, one dense shadow MultiMesh, reverse slot map, generations, capacity, swap-remove, and shared resource references. No gameplay queries. |
| `src/core/visual_presentation/monster_swarm_renderer_3d.gd` | Scene-owned façade: resolves mappings, owns batches and capped exceptional presenters, registers/updates/unregisters handles, exposes diagnostics. No `_process()` required. |
| `src/core/visual_presentation/monster_swarm_renderer_3d.tscn` | `Node3D` renderer scene containing batch roots and exceptional-presenter root. |
| `src/shaders/creature_swarm_body.gdshader` | Spatial cutout atlas shader; vertex-stage custom-data capture; flat varying; frame/flash/status/facing decode. |
| `src/shaders/creature_contact_shadow.gdshader` | Unlit grounded shadow-blob shader; no dynamic light/shadow casting. |
| `src/core/visual_presentation/boss_creature_presenter_3d.gd` and `.tscn` | Capped individual `Sprite3D`/`AnimatedSprite3D` presentation for Boss/approved exceptional elite only. Centrally driven. |

### Existing production files Qwen may change

| Path | Exact change boundary |
|------|-----------------------|
| `src/core/monster/monster_manager.gd` | Inject/cache renderer; queue/register spawn presentation; add deterministic post-Pass-3 sync; unregister resolved entities; remove only the shipped per-monster mesh sync call. Do not reorder or reinterpret gameplay passes. |
| `src/core/monster/monster_instance.gd` | Remove/disable monster `_build_visual_companion()`, mesh mapping lookup, companion field, and companion sync API after migration tests exist. Retain simulation, collision, and any data needed to form presentation snapshots. Replace material-uniform hit-flash ownership with manager-readable presentation state; no per-node tween callback in the final standard path. |
| `src/scenes/MissionScene.tscn` | **No `PresentationRoot3D` node exists yet** — verified against the live file: `Camera3D` (line 59) is currently a direct child of `GameplayRoot` (the `Node2D` simulation root), not of any `Node3D` wrapper. Create `PresentationRoot3D (Node3D)` as a sibling of `GameplayRoot`, reparent the existing `Camera3D` under it (per ADR-0037's own clarification, a `Node3D` anywhere under a `Node2D` ancestor does not inherit that ancestor's 2D transform regardless of nesting depth, so this reparent does not change `Camera3D`'s behavior), and add `MonsterSwarmRenderer3D` as its sibling. This is new scene structure, not an addition beneath something already there — do not skip verifying this against the live `.tscn` before implementing. Do not restructure the simulation root or HUD otherwise. |
| `src/gameplay/missions/the_gap/the_gap.tscn` | Same situation — verified: `Camera3D` (line 38) is currently a direct child of the scene root, no `PresentationRoot3D` exists. Same fix as `MissionScene.tscn` above, only if The Gap owns its mission presentation subtree separately; do not duplicate two active renderers in one running mission. |
| `src/core/game_data_registry.gd` | Load and validate creature-atlas mapping Resources following current registry conventions. Preserve visual-mesh mappings for non-creatures. |

### Data and migration ownership

- Add creature atlas mappings under `assets/data/creature_atlases/`.
- Raw generated sheets remain under `assets/source/`; only processed engine-ready atlases enter `assets/art/`.
- `assets/data/visual_meshes/enemy_ufo_a.tres` is a migration target only. Remove it only after `rg` proves no remaining reference and relevant tests pass. Never delete non-creature ADR-0037 mappings.
- Menagerie scenes and scripts are not changed by the mission pilot. A later Menagerie story uses individual showcase presenters and its own scene owner.

## Required scene tree

```
MissionScene (Node2D)
├── GameplayRoot (Node2D)
│   ├── MonsterManager
│   └── MonstersContainer (Area2D entities; presentation-free)
├── PresentationRoot3D (Node3D)
│   ├── Camera3D
│   └── MonsterSwarmRenderer3D
│       ├── StandardBodyBatches (Node3D)
│       │   └── runtime MultiMeshInstance3D per BatchKey
│       ├── ContactShadowBatches (Node3D)
│       │   └── runtime MultiMeshInstance3D per BatchKey
│       └── ExceptionalPresenters (Node3D; hard-capped pool)
└── HUD (CanvasLayer)
```

Exactly one active mission renderer exists. It is scene-owned, never an autoload.

## Data contracts

### BatchKey

Immutable equality/hash fields:

1. `creature_family_atlas_id: StringName`
2. `mesh_layout_id: StringName`
3. `material_shader_variant_id: StringName`
4. `render_mode_id: StringName`

Do not omit mesh/material/render state. A `MultiMesh` has one Mesh; incompatible geometry or material must not share a batch.

### CreatureAtlasMappingResource

Required validated fields:

- creature/content ID and family-atlas ID;
- engine-ready atlas `Texture2D` reference;
- positive atlas columns/rows and frame count within grid capacity;
- named animation clips with start frame, frame count, positive FPS, and loop flag;
- world width/height and foot-anchor offset;
- mesh-layout, shader-variant, and render-mode IDs;
- standard versus exceptional presentation class;
- preallocated batch-capacity requirement or capacity class;
- status-mask schema version.

Validation fails boot/content validation for missing textures, invalid frame ranges, non-positive dimensions/FPS, unknown render modes, or exceptional assets without an approved presenter class.

### PresentationHandle

Fields: `entity_id`, `batch_id`, `slot_index`, `generation`. Every mutating renderer API validates all four. Generation increments whenever a slot identity is invalidated. A stale handle returns a controlled failure in debug/tests and must never mutate a replacement occupant.

### PresentationSnapshot

Fields: entity ID; `Transform3D` generated from `VisualMath.map_to_3d()` plus art foot anchor; atlas frame; hit-flash amount; status mask; facing/animation variant; exceptional flag; body/shadow scale. It contains no HP, movement velocity, path, target, or mutable gameplay object reference.

## Fixed custom-data budget

`MultiMesh.use_custom_data = true` is set before `instance_count`.

| Component | Contract |
|-----------|----------|
| `x` | Atlas frame index as exactly representable small integer float |
| `y` | Hit flash `0.0..1.0` |
| `z` | Versioned integer status/variant bit mask |
| `w` | Facing/animation variant index |

The pilot must prove required precision across target renderers. Do not opportunistically reuse a channel. If MVP cannot fit, stop and revise ADR-0038 rather than silently packing incompatible semantics. Per-instance color remains disabled unless a separately approved requirement consumes it.

## Shader contract

- `INSTANCE_CUSTOM` is accessed only in `vertex()`.
- `vertex()` assigns it to `varying flat vec4 instance_state`.
- `fragment()` reads `instance_state`; direct fragment access to `INSTANCE_CUSTOM` is prohibited on the pinned engine.
- Body shader computes atlas UVs from integer-like frame plus shared atlas dimensions.
- Hit flash/status feedback is calculated from instance state and shared uniforms; no per-instance material duplication.
- Baseline body mode uses alpha scissor and writes depth. Alpha hash is an evidence-backed optional variant. Alpha blend is reserved for separate VFX.
- Billboard behavior must rotate/construct only the vertical body vertices. The horizontal contact-shadow stream remains world-grounded.
- Atlas imports require mipmaps, edge dilation/gutters, and pilot-approved filtering. No lighting is painted into albedo.

## Dense batch algorithm

### Allocation

1. Resolve BatchKey and predeclared capacity before the wave/mission uses it.
2. Enable transform format, custom data, and any approved color data while `instance_count == 0`.
3. Set fixed `instance_count = capacity` once.
4. Initialize `live_count = 0`, `visible_instance_count = 0`, dense entity array, reverse entity-to-handle map, and generations.

### Register

1. Reject duplicate live entity ID.
2. If `live_count == capacity`, route only to a predeclared overflow batch or fail loudly; never resize.
3. Select `slot = live_count`, increment/assign generation, store entity ID in dense slot, create reverse handle.
4. Write initial body transform/custom data and shadow transform.
5. Increment `live_count`; update both visible counts.

### Update

1. Validate entity ID, batch ID, slot, and generation.
2. Write body transform and custom data.
3. Write shadow transform/custom state if the shadow contract needs it.
4. Perform no allocation, resource load, material duplication, signal emission, or gameplay query.

### Remove by swap

1. Validate handle.
2. `last = live_count - 1`.
3. If `slot != last`, copy last slot's transforms/custom data and entity ID into `slot`; update the moved entity's reverse handle to the new slot without changing its identity generation.
4. Invalidate removed entity generation and erase its reverse entry.
5. Clear/hide the old last slot defensively.
6. Decrement `live_count`; set body and shadow `visible_instance_count` to the same dense prefix.
7. Assert body/shadow counts, dense IDs, and reverse handles agree in debug/test builds.

## MonsterManager frame ordering

Do not insert presentation work inside damage/status/boss rules. Required order:

1. Pass 1 damage.
2. Pass 1b status effects.
3. Pass 2 boss logic.
4. Pass 3 movement and DEAD/BREACHED resolution.
5. `PRESENTATION SYNC`: drain pending registrations; snapshot/update surviving ACTIVE entities at their final same-frame position; unregister DEAD/BREACHED or wave-cleared entities using swap-remove; optionally spawn capped presentation-only death effects.
6. Pass 4 absorbed flush.

**Confirmed against the live file, not hypothetical**: `monster_manager.gd`'s
`_pass3_movement()` (lines 380-397) already rebuilds `active_monsters` at the
end of Pass 3 to include only `lifecycle_state == ACTIVE` entities — DEAD and
BREACHED entities are already gone from that array before any later step,
including the existing Pass 3c visual sync, ever sees them. The existing Pass
3c doc comment (lines 441-447) confirms this is deliberate: a resolved entity
is "skipped for free" today only because its old `VisualCompanion3D` child
gets freed for free when its already-`queue_free()`'d `MonsterEntity` leaves
the tree — a mechanism a dense `MultiMesh` slot has no equivalent for, since
there is no node to free. **Reuse the existing precedent for this**:
`_pending_deaths` (line 86, doc comment: "ADR-0033 — frame-scoped, flushed
each frame in Pass 4") already captures resolved entity data before this same
swap-buffer rebuild discards it, for consumption later in the same frame —
the presentation-sync unregister list should follow this same pattern
(captured during/before Pass 3's rebuild, consumed by the sync step), not be
independently re-derived. Separately, `_advance_entity()` (line 419) already
emits `GEventBus.monster_breached` at the exact moment of breach, before the
rebuild — a valid data source for capturing the resolved ID even though the
"no EventBus on the recurring hot path" rule (correctly) rules out using it
as the *position-sync* mechanism itself; death/breach is a once-per-entity
event, not a recurring one, so consuming the signal's payload (or mirroring
its data into a pending list the way `_pending_deaths` already does) does not
conflict with that rule. Do not retain dead gameplay nodes just for visuals
and do not change DEAD-before-BREACHED behavior.

## Boss and elite policy

- Boss uses the dedicated presenter pool; anticipated concurrency is content-capped and verified.
- Elite uses standard batching unless an approved visual requirement needs unique tells unavailable through the four-channel shader contract.
- Exceptional presenters have no independent process callback. MonsterManager publishes the same snapshots to their pool.
- Their draw calls count toward whole-scene limits.
- Existing two-layer boss animation behavior must be reproduced visibly; implementation may use layered `Sprite3D` nodes inside one capped presenter.

## Menagerie separation

Menagerie creatures do not register with `MonsterManager` or `MonsterSwarmRenderer3D`. A later Menagerie-specific presenter may reuse atlas mappings and shaders but is scene-owned by the Menagerie and may use individual `Sprite3D`/`AnimatedSprite3D` nodes for inspection quality. Do not add a global creature-rendering autoload.

## Shadow stream

- One shadow instance corresponds to each standard body slot and follows identical dense ordering.
- It uses a horizontal quad/blob at pilot-tuned ground offset to prevent Z-fighting.
- Body and shadow transforms may differ in scale, orientation, and Y offset but share entity identity.
- Body billboard casts no real-time shadow. Shadow material is unlit, restrained, and may fade by shared parameters only.
- Body plus shadow normally equals two draw submissions per BatchKey and is counted as such.

## Migration from shipped ADR-0037 monster code

1. Characterize current tests and capture baseline gameplay/performance evidence.
2. Add renderer/data types and pilot without touching shipped monster companions.
3. Add a temporary explicit presentation-mode switch for tests/migration only; default behavior must be unambiguous per environment.
4. Integrate MonsterManager registration/post-Pass-3 sync while keeping gameplay results identical.
5. Redirect hit-flash/status visual state into snapshots/custom data. Replace the per-monster `ShaderMaterial`/Tween mutation path for standard monsters with manager/renderer-owned decay state; do not retain duplicate flashes.
6. Switch standard monsters to swarm mode and stop creating `_build_visual_companion()` mesh children.
7. Migrate Boss to its capped presenter and verify layered tells.
8. Replace `monster_visual_companion_test.gd` expectations with swarm tests; retain all non-monster ADR-0037 tests.
9. Prove no reference to the enemy UFO mesh mapping remains, then retire that monster-only placeholder mapping.
10. Remove the temporary migration switch after all creature families and regression tests pass.

## Story-sized implementation sequence

### Story 1 — Isolated pilot scaffold

Create `prototypes/hybrid-swarm-pilot/` and README, fixed camera/lighting/backdrop, instrumentation, and synthetic atlas. No production integration.

### Story 2 — Batch core and lifecycle tests

Implement BatchKey, handle, fixed-capacity batch, register/update/swap-remove, body/shadow parity, stale-handle rejection, overflow behavior.

### Story 3 — Spatial atlas and feedback shaders

Implement varying rule, frame selection, scissor/hash comparison, hit flash, status/facing decode, mip/edge tests.

### Story 4 — Pilot stress and backend evidence

Run 50, 100, 150, and 200 instances; overlapping/slope/occlusion cases; D3D12, Vulkan, macOS; record CPU/GPU/draw/memory evidence. Decide alpha mode, AABB/partition policy, and exceptional cap.

### Story 5 — Data registry integration

Implement mapping Resource, fixtures, validation, duplicate handling, and registry lookup without changing live monsters.

### Story 6 — Mission renderer scene integration

Add exactly one renderer to MissionScene/The Gap ownership, dependency wiring, diagnostics, and empty-renderer smoke tests.

### Story 7 — MonsterManager standard swarm migration

Add spawn handles and post-Pass-3 sync; migrate standard monsters; remove standard mesh companion construction/sync; preserve all simulation behavior.

### Story 8 — Hit/status/death presentation migration

Replace per-node hit material/Tween behavior, test channel isolation and rapid hits, and add capped death presentation if required.

### Story 9 — Boss/elite exceptional path

Implement capped presenter pool and reproduce required layered boss animation/tells without callbacks.

### Story 10 — Cleanup and production gate

Remove migration switch, retire monster-only placeholder mesh data, update tests/docs, run full regression and final art-pipeline acceptance capture.

## Test and evidence matrix

| Area | Required evidence |
|------|-------------------|
| Resource validation | Valid mapping loads; missing atlas, bad grid/frame/FPS/dimensions/render mode fail; duplicate IDs fail. |
| Dense lifecycle | Register to capacity, duplicate rejection, every removal position, repeated swap-remove, stale handle, overflow, wave clear, body/shadow parity. |
| Simulation regression | Existing movement, slow/DoT, damage, death-before-breach, boss, spawn, wave-complete tests retain gameplay results. |
| Same-frame sync | Final Pass-3 position is visible in the presentation snapshot that frame; dead/breached instances do not ghost. |
| Shader channels | Frame, flash, status mask, and facing vary independently across adjacent instances; vertex-to-flat-varying path compiles cleanly. |
| Transparency | Dense overlapping swarm comparison proves selected scissor/hash mode has acceptable ordering and edges. |
| Grounding | Flat and sloped samples show correct foot anchor, shadow contact, no Z-fighting, and correct tower occlusion. |
| Culling | Custom AABB retains visible edge instances; camera movement/framing causes no early disappearance; partition choice measured. |
| Performance | 50/100/150/200 instance captures: presentation CPU, frame CPU/GPU, FPS, draw calls, memory, shader compilation/stutter. |
| Backends | Repeat visual and performance gates on Windows D3D12, Vulkan, and macOS target renderer. |
| Exceptional | Maximum simultaneous Boss/elite presenters stay within cap, reproduce tells, and keep scene below draw-call ceiling. |
| Menagerie | Architectural test/assertion confirms it has no dependency on MonsterManager or mission renderer. |
| Cleanup | `rg` shows no standard-monster mesh-companion or enemy-UFO mapping references; Hero/tower/world ADR-0037 tests remain. |

## Acceptance criteria

Implementation is complete only when all statements below are true:

1. At least 100 standard monsters animate and react independently inside the 3D battlefield at 60 FPS on the reference target.
2. Whole-scene draw calls are `<=150` normal, `<=180` stress, and never `>200` in recorded gates.
3. No standard monster owns a `MeshInstance3D`, `Sprite3D`, unique material, process callback, or authoritative 3D position.
4. Every live standard entity maps to exactly one valid dense body slot and one matching shadow slot; every removed entity maps to none.
5. Swap-remove and stale handles cannot mutate the wrong creature.
6. Presentation uses the post-Pass-3 position and does not change ADR-0006 gameplay ordering or results.
7. All four custom-data channels work concurrently through the vertex-to-flat-varying shader contract.
8. Selected body transparency has no unacceptable swarm sorting artifacts; blended transparency is confined to separately budgeted VFX.
9. Contact shadows ground creatures without real-time billboard shadow casting or per-creature lights.
10. Backend evidence exists for D3D12, Vulkan, and macOS, including visual captures and profiler numbers.
11. Boss/elite exceptions remain centrally updated, pooled/capped, and inside the draw-call budget.
12. Menagerie remains separate from mission swarm ownership.
13. Existing gameplay tests and all non-monster ADR-0037 presentation tests pass.
14. Monster-only shipped ADR-0037 mesh-companion code/data is removed only after replacement evidence passes.
15. The Art Bible pilot gate is explicitly signed off before mass creature-art production begins.

## Stop conditions for Qwen

Qwen must stop and report rather than improvise if:

- four custom-data scalars cannot express approved MVP states;
- actual scene ownership would create two active renderers;
- Pass-3 filtering makes resolved identity unavailable without gameplay-order changes;
- a required alpha mode violates the no-blended-standard-body rule;
- a backend cannot compile the varying shader or meet the hard ceiling;
- the Boss concurrency/tell requirement exceeds the approved exceptional cap;
- implementation would modify Hero/tower/world ADR-0037 behavior or Menagerie ownership.
