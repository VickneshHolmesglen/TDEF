# QA Evidence: Grid/Terrain Visual Companion (Epic 15 Story 002)

**Story**: `production/epics/epic-15-3d-visual-presentation/story-002-grid-terrain-visual-companion.md`
**ADR**: `docs/architecture/adr-0037-visual-presentation-3d-companion-layer.md`
**Date**: 2026-08-20
**Status**: PARTIAL — AC-1, AC-2, and AC-3 have real automated coverage (below). AC-4 and AC-5
are **DEFERRED** pending a human live-screenshot / Remote Debugger session — see "Deferred
checks" below. No screenshot evidence is fabricated in this document.

---

## Automated coverage (this session)

`tests/integration/visual_presentation/grid_terrain_visual_companion_test.gd` exercises
`GridVisual.configure()` (`src/gameplay/missions/the_gap/grid_visual.gd`) directly, headless,
against a known 5x3 (and 2x1/2x2) test grid:

| AC | Test(s) | What it proves |
|---|---|---|
| AC-1 (mesh instantiation) | `test_configure_creates_exactly_one_mesh_instance_per_grid_cell` | For a 5x3 grid, `configure()` produces a `VisualCompanion3D` `Node3D` child holding **exactly** 15 child nodes (one per cell) — not hardcoded, not a fixed count. |
| AC-1 (data-driven resolution) | `test_configure_resolves_tile_mesh_via_real_visual_mesh_mapping_registry` | Confirms `assets/data/visual_meshes/tile_straight.tres` resolves through the **real, live** `GGameDataRegistry.get_visual_mesh_mapping()` autoload boot path (not an injected fixture) and every instantiated tile node is a real `Node3D`. |
| AC-2 (map_to_3d positioning) | `test_configure_places_each_tile_at_its_map_to_3d_cell_center_position` | Every tile's `position` exactly matches `VisualMath.map_to_3d(cell_center_2d, 0.0)` for its corresponding cell, where `cell_center_2d` is computed with the same `col * cell_size + cell_size * 0.5` convention as `Grid.cell_to_world()` (`src/foundation/grid/grid.gd`). Also asserts every tile's Y is exactly `0.0` (ADR-0037's ground/tile layer height). |
| AC-3 (zero simulation changes) | `test_configure_still_builds_the_2d_grid_texture_unchanged` | `configure()`'s pre-existing 2D behavior (`cols`/`rows`/`cell_size` assignment, `_texture` build) still runs to completion — the 3D companion build is additive, not a replacement or early-return. |
| Regression guard (lifecycle) | `test_reconfigure_rebuilds_companion_subtree_without_duplicating_tiles` | A second `configure()` call frees the previous `VisualCompanion3D` subtree rather than leaking or duplicating tile instances. |

All 5 tests are headless-executable and deterministic — no rendering, no timing dependency
beyond one `await get_tree().process_frame` for `queue_free()` completion in the last test.

---

## Deferred checks (require a human with a live rendered session)

**AC-4 (visual correctness — gapless, edge-to-edge tile layout)**
- The story's own QA Test Cases require this be checked via **live screenshot comparison**, not
  static scene inspection: "Verify: no gaps, no overlaps, no misaligned tiles... Pass condition:
  tile boundaries align edge-to-edge."
- This cannot be produced by this session (no screenshot capability available for this task).
  **DEFERRED** — needs a human (or a live Godot MCP `run_project` + `take_screenshot` session,
  per this project's own established live-verification pattern, e.g.
  `production/qa/evidence/hero-goal-cell-evidence.md`) to run a scratch/test scene instancing
  `GridVisual` with a real grid shape (e.g. "The Gap"'s actual 16x12 layout) and a temporary
  `Camera3D` (none exists in the real mission scene yet — that's Story 003, explicitly Out of
  Scope here per the story's own Implementation Notes), then visually confirm tile adjacency.
- The automated `test_configure_places_each_tile_at_its_map_to_3d_cell_center_position` test
  above proves the underlying **math** is gapless (adjacent cells' `map_to_3d()` positions are
  exactly `cell_size` apart on the X/Z plane, by construction of the shared `cell_center_2d`
  formula) — what remains unverified is whether the actual mesh asset's real-world scale matches
  `cell_size` (i.e., whether `tile-straight.glb`'s physical footprint is authored/scaled to tile
  seamlessly at this project's 64px `cell_size` convention). That scale check is exactly the kind
  of thing this project's own `VERSION.md` "always-verify-scale-live" lesson flags as
  screenshot-only, not derivable from position math alone.

**AC-5 (draw call budget, ≤200/frame project-wide)**
- Requires Remote Debugger or equivalent live measurement at MVP grid scale (The Gap's real
  16x12 = 192 cells), per the story's QA Test Cases.
- **DEFERRED** — not measurable without a live running session. Expected contribution: 192 tile
  `MeshInstance3D` draw calls is a meaningful fraction of the 200/frame budget on its own (before
  Stories 003-006 add tower/monster/hero/projectile companions), and is flagged here explicitly
  for follow-up rather than assumed safe. If this comes in over budget when measured, the likely
  mitigation is instancing/batching (e.g. `MultiMeshInstance3D` for the uniform tile case) —
  not attempted in this story since ADR-0037 and the story's Implementation Notes scope this as
  "proof the pipeline works," not a performance-optimized implementation.

---

## Deviations / judgment calls

- The story's QA Test Cases describe resolving "the tile type" (singular) via one
  `VisualMeshMappingResource` lookup — this implementation uses a single shared
  `entity_or_component_id` (`&"tile_straight"`) for every grid cell regardless of
  `Grid.CellType` (PLACEABLE/PATH/SPAWN/GOAL/BLOCKED all get the same 3D mesh). A per-CellType
  mesh set was judged out of scope: the ADR's own Migration Plan frames this story as proving the
  pipeline for "a genuinely static case," and per-CellType 3D terrain art does not yet exist as
  an authored asset set (mirroring the existing 2D per-mission terrain texture set would be a
  separate content-authoring pass, not a Story 002 architecture change).
- New data file: `assets/data/visual_meshes/tile_straight.tres`, mapping `&"tile_straight"` to
  `res://assets/Tower Defense Models/GLB format/tile-straight.glb` — chosen over
  `tile-straight-slope.glb`/other tile variants as the flattest, most generic ground tile in the
  Kenney pack, matching the story's own suggested example.
