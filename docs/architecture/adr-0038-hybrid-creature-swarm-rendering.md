# ADR-0038: Hybrid Creature Swarm Rendering

## Status
Accepted

## Date
2026-08-24

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Rendering |
| **Knowledge Risk** | HIGH — this decision depends on instanced spatial shaders, per-instance custom data, transparency/depth behavior, and backend-specific rendering at swarm scale. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `deprecated-apis.md`; `breaking-changes.md`; `modules/rendering.md`; ADR-0006; ADR-0013; ADR-0037; `investigation-2026-08-24-hybrid-swarm-rendering.md`; Art Bible Sections 1, 3, 5 and 8 |
| **Post-Cutoff APIs Used** | Godot 4.6.2 `MultiMesh`, `MultiMeshInstance3D`, spatial shaders and the D3D12-default rendering path. |
| **Verification Required** | Satisfied 2026-08-24 — `prototypes/hybrid-swarm-pilot/` live-verified 3D transforms, custom-data round trips, atlas selection, the vertex-to-fragment varying pattern, the dense-handle register/update/remove/swap-remove lifecycle, transparency/ordering behavior, slope/occlusion contact shadows, and whole-scene draw-call/memory budgets on both D3D12 and Vulkan (identical results on both: 57 draw calls flat across 50-195 instances, 6-call swarm isolation delta, no shader compile errors). See the pilot's README.md for full evidence. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0006 (centralized monster processing); ADR-0013 (shared atlases and draw-call discipline); ADR-0037 (2D-authoritative simulation, `Camera3D`, and `VisualMath.map_to_3d()`). |
| **Supersedes** | ADR-0037 **only** where it assigns per-entity 3D mesh companions to monsters or Menagerie creatures. ADR-0037 remains authoritative for Hero, towers, buildings, terrain, projectiles, camera, coordinate mapping, and one-way simulation-to-presentation flow. ADR-0013 is superseded **only** for world-space mission-monster rendering; its shared-atlas principle and draw-call budget intent remain binding. |
| **Enables** | Hybrid swarm pilot, creature-atlas authoring contract, and replacement of the shipped monster mesh companion. |
| **Blocks** | Final creature renderer implementation and mass creature-art production. |

## Context

### Problem Statement

The locked Art Bible requires a physical 3D player/world domain and expressive 2D creatures composited inside it. Shipped ADR-0037 instead creates one `MeshInstance3D` companion per monster. Standard missions must show 100+ animated monsters at 60 FPS while the whole scene stays at or below 150 normal draw calls, 180 under swarm stress, and a 200 hard ceiling.

The solution must preserve the working `Area2D`/`Vector2` simulation, `AStar2D` paths, deterministic ADR-0006 passes, `Camera3D`, and `VisualMath.map_to_3d()`. Presentation may observe simulation but may never become gameplay authority.

### Constraints

- No per-monster `_process()` or `_physics_process()` and no EventBus traffic on the per-frame presentation hot path.
- No write-back from 3D presentation to monster simulation.
- Shared atlas, mesh, shader, and material resources; no unique runtime material per standard monster.
- Standard creatures must remain readable at 100+ density.
- `INSTANCE_CUSTOM` provides exactly four scalar channels; features cannot assume unbounded per-instance state.
- Transparent instances inside a `MultiMesh` cannot be assumed to sort correctly.
- `Viewport.use_hdr_2d` remains prohibited.

## Decision

### Rendering ownership

One scene-owned `MonsterSwarmRenderer3D` sits under mission presentation. `MonsterManager` remains the sole owner of monster lifecycle and movement. After ADR-0006 Pass 3 completes movement and resolves DEAD/BREACHED state, it directly publishes presentation operations to the renderer. No global events are introduced.

Standard monsters use preallocated `MultiMeshInstance3D` batches. A batch key is the complete tuple:

`(creature_family_atlas_id, mesh_layout_id, material_shader_variant_id, render_mode_id)`

Any difference in atlas, geometry, shader/material variant, alpha mode, or render state requires another batch. Each batch has one shared mesh and material set. Capacity is allocated before use; changing `instance_count` in the hot path is forbidden. `visible_instance_count` exposes the dense live prefix.

### Body and shadow submissions

The standard body stream is a vertical illustrated quad using a spatial atlas shader. The contact-shadow stream is a separate horizontal blob quad or a second material surface. Either arrangement is budgeted as a separate draw submission: a normal body-plus-shadow batch costs approximately two draw calls. Creature billboards do not cast real-time silhouette shadows and do not own dynamic lights.

The body uses alpha scissor as the baseline where art permits. Alpha hash may be accepted by pilot evidence. Alpha-blended creature bodies are not the default because Godot does not provide order-independent transparency and cannot guarantee per-instance transparent sorting. Soft blended pixels belong in separately budgeted VFX.

### Dense handles and lifecycle

Each live standard monster has a presentation handle containing a batch identity, slot index, and generation. Batch slots form a dense range `[0, live_count)`. Removal uses swap-remove: copy the final live slot into the removed slot, update the moved entity's reverse handle, clear the old final slot, decrement `live_count`, then set `visible_instance_count = live_count`. Stale generations must be rejected. Spawn fails loudly or uses an explicitly preallocated overflow batch; it never resizes a live batch silently.

The deterministic per-frame order is:

1. ADR-0006 Passes 1, 1b, and 2 mutate gameplay state.
2. Pass 3 advances ACTIVE monsters and resolves DEAD/BREACHED outcomes.
3. A presentation-sync step registers pending spawns, writes transforms/custom state for survivors, and unregisters resolved entities using dense swap-remove.
4. ADR-0006 Pass 4 flushes absorbed-damage events.

Presentation ordering cannot affect DEAD-before-BREACHED semantics. Death animation, if required, is a capped presentation-only effect spawned from a resolved snapshot; it does not keep a simulation entity alive.

### Per-instance channel budget

The four `INSTANCE_CUSTOM` scalars are fixed as:

| Channel | Meaning |
|---------|---------|
| `x` | Integer atlas frame index encoded as a float |
| `y` | Hit-flash amount, normalized `0.0..1.0` |
| `z` | Integer status/variant bit mask encoded as a float; exact bit allocation is versioned by the renderer contract |
| `w` | Facing/animation variant index encoded as a float |

This allocation may change only through a documented contract revision. `use_custom_data` must be enabled before `instance_count` is allocated. Per-instance color is reserved as an optional second channel set and must likewise be enabled before allocation; it is not part of the MVP contract.

In Godot 4.6.2, `INSTANCE_CUSTOM` is read in `vertex()`, copied into a `varying flat vec4`, and consumed in `fragment()`. Direct fragment-stage access is prohibited because it failed live verification on the pinned binary.

### Bosses, elites, and Menagerie

Bosses and visually exceptional elites may use dedicated `Sprite3D` or `AnimatedSprite3D` presenters when unique animation/tells would be harmed by batching. They remain centrally updated and have a content-defined concurrency cap proven in the pilot. They do not justify individual standard-monster nodes or materials.

Menagerie presentation is outside `MonsterManager` and the mission swarm renderer. It follows the same 2D-creature art ownership but may use individual presenters for showcase quality. This ADR supersedes the Menagerie's 3D-mesh end state, not its scene ownership.

## Architecture Diagram

```
MissionScene (Node2D; simulation root)
├── GameplayRoot (Node2D)
│   ├── MonsterManager
│   │   └── ADR-0006 passes + post-Pass-3 presentation sync
│   └── Monster entities (Area2D; no visual companion mesh)
└── PresentationRoot3D (Node3D)
    ├── Camera3D
    └── MonsterSwarmRenderer3D
        ├── StandardBodyBatches (MultiMeshInstance3D[])
        ├── ContactShadowBatches (MultiMeshInstance3D[])
        └── ExceptionalPresenters (capped Sprite3D/AnimatedSprite3D)
```

## Alternatives Considered

### Individual Sprite3D for every monster

Simpler animation authoring, but creates a node and commonly a draw/material burden per creature. Retained only as the capped boss/elite fallback.

### Keep 3D monster meshes

Already implemented by ADR-0037, but violates the locked art direction. Rejected.

### SubViewport/Canvas compositing

Adds viewport cost and complicates correct layering with the 3D world. Rejected.

### Custom RenderingDevice renderer

Could maximize control but introduces unnecessary native-level complexity before the engine-supported instancing path is measured. Deferred, not selected.

## Consequences

### Positive

- Preserves all authoritative gameplay and deterministic monster processing.
- Makes the new medium split intentional without returning to one node/material per standard creature.
- Makes animation, hit flash, status state, and shadows batch-compatible.
- Keeps atlas/material changes data-driven and measurable.

### Negative

- Requires custom atlas animation and state shaders instead of `Sprite3D` conveniences.
- Dense handles and swap-remove bookkeeping are more complex than child-node lifecycle.
- Body and shadow usually cost two submissions per batch.
- Standard creatures share a deliberately limited visual-state channel budget.

### Risks and Pilot Gates

The following are uncertainties to measure, not promises made by this ADR:

- CPU cost of transform and custom-data writes for 100–200 animated instances; bulk-buffer APIs are considered only if profiling proves necessary.
- Group-level MultiMesh culling and custom AABB behavior; lane/region partitioning may improve culling but increases draw calls.
- Alpha scissor versus alpha hash quality, mipmapped atlas gutters, edge dilation, anisotropy, and anti-aliasing.
- Fixed-yaw versus camera-facing billboarding, foot anchors, slopes, occlusion by towers, and depth-writing behavior.
- Contact-shadow offset, scale, and Z-fighting.
- Four-channel packing precision and shader behavior on D3D12 and Vulkan — verified identical (`prototypes/hybrid-swarm-pilot/README.md`).
- Boss/elite exception cap and layered animation requirements.
- Whole-scene draw calls, memory, load time, and frame time under a representative 100+ swarm.

## Performance Implications

- Target: 60 FPS with 100+ monsters.
- Whole scene: at most 150 draw calls normally, 180 under swarm stress, never above 200.
- Monster presentation updates remain O(n) inside the existing centralized frame.
- No allocation, material creation, scene instantiation, `instance_count` resizing, or EventBus emission in the recurring sync path.
- The pilot records CPU presentation time, render time, draw calls, memory, and shader compilation behavior on all target backends.

## Migration Plan

1. Build a separate `prototypes/hybrid-swarm-pilot/` with README and representative 3D backdrop.
2. Prove the batch, channel, shadow, transparency, culling, and backend gates.
3. Add creature-atlas mapping data and renderer contracts without changing gameplay behavior.
4. Replace `monster_instance.gd`'s shipped `_build_visual_companion()` mesh path and `monster_manager.gd`'s per-entity mesh sync with registration plus post-Pass-3 swarm sync.
5. Retire monster-only `assets/data/visual_meshes/enemy_ufo_a.tres` references after tests prove no consumer remains; do not remove Hero/tower/world mappings.
6. Replace ADR-0037 monster-companion tests with swarm lifecycle, batching, and simulation-regression evidence.
7. Migrate one creature family at a time. Preserve a debug fallback until each family passes visual and performance gates.

## Validation Criteria

- Existing monster movement, damage, death, breach, boss logic, and wave tests pass unmodified in behavior.
- 100+ standard creatures render at correct `VisualMath.map_to_3d()` positions with no per-monster process callbacks.
- Register/update/remove and swap-remove maintain correct entity-to-slot identity with no ghost or duplicated visuals.
- Atlas frame, hit flash, status mask, and facing/variant are independently demonstrated through the fixed four-channel contract.
- The shader uses vertex-stage `INSTANCE_CUSTOM` and a flat varying.
- Creature bodies show no unacceptable ordering artifacts under the chosen non-blended mode.
- Contact shadows remain grounded on representative slopes and do not Z-fight.
- Whole-scene draw calls and frame timing meet the stated budgets on D3D12 and Vulkan evidence runs.
- Boss/elite and Menagerie presenters remain bounded and outside the standard swarm lifecycle.

## Related Decisions

- ADR-0006 — authoritative centralized monster processing and lifecycle order.
- ADR-0013 — shared atlases and draw-call discipline; partially superseded as stated.
- ADR-0037 — mixed 2D simulation/3D presentation foundation; partially superseded as stated.
- `docs/architecture/hybrid-swarm-rendering-implementation-blueprint.md` — implementation handoff.
- `docs/architecture/investigation-2026-08-24-hybrid-swarm-rendering.md` — live engine evidence.
