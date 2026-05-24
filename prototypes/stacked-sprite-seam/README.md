# Prototype: Stacked Sprite + 3D/2D Seam Validation

**Status**: Concluded — **PROCEED** verdict (Sprint 1, task S1-01, 2026-05-19)

## Hypothesis

The stacked-sprite technique (multiple 2D sprite layers offset upward in screen Y,
with a ground shadow at the base) will produce objects that appear to sit ON the
ground plane at the game's oblique angle in Godot 4.6.2, matching the "hand-crafted
diorama" feel specified in the art bible.

## How to Run

1. Open Godot 4.6.2 and load this project.
2. Open `prototypes/stacked-sprite-seam/StackedSpriteScene.tscn`.
3. Press **Run Scene** (F6).

No assets required — scene uses `ColorRect` nodes only. Runs in Vulkan or D3D12.

## Key Findings

- **Technique confirmed viable** in Godot 4.6.2 with correct Y-sort and z_index usage.
- **6–8 layers minimum** for convincing depth on main game objects (towers, hero, enemies). 4 layers is insufficient for player-facing objects.
- **Ground shadow is critical** — it is the primary grounding mechanism. Removing it produces a "floating" artifact regardless of layer count. Every production stacked-sprite entity must have a shadow child node.
- **Draw call budget implication**: at 8 layers, 20 towers + 30 enemies = 400 stacking draw calls alone, exceeding the 200 DC budget. Sprite atlasing and batching are mandatory in production.

See `REPORT.md` for full results table, per-object-class layer minimums, architecture requirements, and production effort estimates.

## Files

| File | Purpose |
|------|---------|
| `StackedSpriteScene.tscn` | Test scene — 5×6 tile grid with 3 test objects |
| `StackedSpritePrototype.gd` | Scene script — builds grid and stacked objects procedurally |
| `REPORT.md` | Full findings, metrics, and recommendations |

## Next Steps (production)

- Rewrite from scratch to production standards (prototype code is NOT migrated directly)
- See `REPORT.md → If Proceeding` for architecture requirements and minimum layer counts
- Atlas texture strategy should be decided before Foundation Epic stories are written
