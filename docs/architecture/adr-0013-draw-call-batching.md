# ADR-0013: Sprite Atlas Strategy for Draw-Call Budget Compliance

## Status
Accepted

## Date
2026-06-30

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Presentation / Rendering |
| **Knowledge Risk** | MEDIUM — CanvasItem batching conditions changed in Godot 4.4+ |
| **Post-Cutoff APIs** | 2D batching is on by default in Godot 4.4+; verify Project Settings → Rendering → 2D confirms no override disables it |
| **Verification Required** | Profile actual DC count in Remote Debugger before Sprint 3 entity stories close |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (scene hierarchy — entities are Node2D based) |
| **Risk Mitigated** | T1 — Draw call budget exceeded by stacked-sprite entities |
| **Enables** | Sprint 3 Monster entity, Tower entity, Hero entity scene stories |
| **Blocks** | Any story that creates entity scenes with stacked AnimatedSprite2D layers |

## Context

### Problem Statement

The stacked-sprite technique confirmed by S1-01 uses one AnimatedSprite2D node per
visual layer per entity. At 8 layers per entity:

| Scenario | Entities | DC from entities | Budget | Overage |
|----------|----------|-----------------|--------|---------|
| Sprint 3 MVP | 20 towers + 30 monsters | 400 | 200 | 2× |

Background, UI, grid, and VFX draw calls are additive — entity stacking alone
exhausts the entire budget.

### Godot 4 2D Batching Mechanics

Godot 4 batches consecutive 2D draw calls automatically when **all** of the
following hold:
1. Same texture (or atlas region from the same atlas)
2. Same CanvasItem material
3. Same blend mode

The critical constraint is **shared texture**: if every entity layer references a
unique texture file, no batching occurs. If all entities of the same class share one
atlas, all same-class same-z-layer draws collapse to a single call.

### Constraints

- Art pipeline must produce shared atlas sheets, not per-frame individual files
- `SpriteFrames` resources must reference atlas regions
- Z-ordering must use `z_index` on nodes — not CanvasLayer per entity (CanvasLayer
  forces a new rendering context and breaks batching)

## Decision

### Strategy: Shared Per-Class Texture Atlas

Each entity class gets a **single shared atlas texture** containing all animation
frames for all layers.

**Atlas layout**:
- Rows: one per visual layer (0 = base, 1 = detail, …, 7 = top)
- Columns: animation frames
- Format: PNG or WebP, power-of-two dimensions, imported as Atlas in Godot

**Batching outcome** — all entities of the same class at the same z-layer share one
texture and batch into one draw call:

| Layer band | Entity classes | Draw calls |
|------------|---------------|------------|
| layer-0 | tower_basic, monster_tier1 | 2 |
| layer-1…7 | same | 2 × 7 = 14 |
| **Total entity DC** | | **16** |

Combined with background (~5), UI (~10), grid (~4), VFX (~5): **≈ 40 DC total** —
well within the 200 DC budget at MVP entity counts.

### Z-Ordering Rule

```
layer_z_index = entity_base_z + (layer_index × 2)

Entity base z_index values:
  PLACEABLE / ground effects = 0
  Tower                      = 10
  Monster                    = 20
  Hero                       = 30
  UI / HUD                   = 100+
```

Same-layer sprites from different entities of the same class will have identical
z_index — this is intentional and required for batching. Godot renders them in
scene-tree order when z_index values are equal.

### Entity Scene Structure

```
TowerInstance (Node2D, z_index = 10)
├── LayerBase   (AnimatedSprite2D, z_index = 0,  frames = tower_basic_atlas)
├── LayerDetail (AnimatedSprite2D, z_index = 2,  frames = tower_basic_atlas)
├── LayerEffect (AnimatedSprite2D, z_index = 4,  frames = tower_basic_atlas)
└── LayerTop    (AnimatedSprite2D, z_index = 6,  frames = tower_basic_atlas)
```

The `SpriteFrames` resource (`tower_basic_atlas`) is a shared `.tres` file
referenced by all TowerInstance scenes of the same class — never duplicated per instance.

### Implementation Guidelines

1. **One SpriteFrames atlas per entity class** — shared across all instances; never call `.duplicate()` on a SpriteFrames resource at runtime
2. **Import textures as Atlas** in Godot import settings (not as individual frames)
3. **Verify batching before closing Sprint 3 entity stories** — check Remote Debugger → Monitors → 2D Draw Calls; target ≤ 60 DC for complete scene
4. **No CanvasLayer per entity** — CanvasLayer creates a new rendering context and breaks batching; use z_index only
5. **Profile before adding complexity** — do not introduce MultiMeshInstance2D unless profiling shows atlas batching is insufficient at actual entity counts

### Consequences

- Art pipeline must deliver shared atlas sheets before entity scene stories can begin; this is a Sprint 3 art dependency
- `SpriteFrames` resources are shared References — entity instances must not hold unique copies
- At MVP entity counts (≤ 50 total entities) this strategy is sufficient; at post-MVP counts (100+ entities) re-evaluate MultiMeshInstance2D for same-tier layers

## Alternatives Considered

**Alt A — MultiMeshInstance2D per layer**: GPU-instanced rendering of all same-layer sprites in one call. Optimal for static, unanimated entities. **Rejected**: entities have animation states and per-instance material modulation; MultiMesh does not support per-instance AnimationPlayer integration cleanly. Re-evaluate post-MVP.

**Alt B — SubViewport compositing per entity**: Each entity renders all layers to a SubViewport, output composited as a single sprite (N layers → 1 DC per entity). **Rejected**: SubViewport has fixed overhead (~1 ms/frame per viewport); 50 entities × 1 ms = 50 ms — catastrophic frame budget overrun.

**Alt C — Custom _draw() per entity**: Override `_draw()` on entity root to emit all layer draw calls in one pass regardless of texture. **Rejected** for MVP: requires manual frame tracking and loses AnimationPlayer integration. Valid escape hatch if atlas batching proves insufficient at scale.
