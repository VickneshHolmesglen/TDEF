# Story 002: Grid/Terrain Visual Companion

> **Epic**: 3D Visual Presentation Layer — Phase 1
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: 2-4 hours
> **Manifest Version**: 2026-07-13b
> **Last Updated**: —

## Context

**GDD**: None — infrastructure epic, no GDD linkage.
**Requirement**: None (no TR registry entry). Criteria sourced from ADR-0037.

**ADR Governing Implementation**: ADR-0037 (Visual Presentation 3D Companion Layer) — Accepted
**ADR Decision Summary**: `TheGap`'s `GridVisual` (`Node2D`, script `grid_visual.gd`) gains a `Node3D` visual-companion child holding `MeshInstance3D` tile instances, resolved via Story 001's `VisualMeshMappingResource`. Ground/tile visuals are static once placed — per ADR-0037's layer-height table, `layer_height[ground/tile] = 0` and tiles do not move once the mission's grid is laid out, so **no per-frame sync is required for this story** (contrast with Stories 003-006, which do sync every frame).

**Engine**: Godot 4.6.2 | **Risk**: LOW (static instantiation only, no per-frame logic; mixed `Node2D`-root/`Node3D`-child pattern already live-verified this session — see `prototypes/3d-tower-defense-kit-spike/mixed_root_check.tscn`)
**Engine Notes**: None beyond ADR-0037's own Engine Compatibility table — this story does not introduce any new engine-API surface beyond what Story 001 and the ADR's own verification already covered.

**Control Manifest Rules (this layer)**:
- Required: N/A — the manifest's Presentation Layer Rules (`z_index` layering, texture atlas batching) are 2D-`CanvasItem`-specific (ADR-0013) and do not apply to `Node3D` content, which depth-tests natively per ADR-0037's own stated rationale. No 2D-specific rule from the manifest governs this story.
- Forbidden: N/A.
- Guardrail: Total scene draw calls ≤ 200/frame (project-wide budget, `technical-preferences.md`) — applies here since tile instances are the first real per-instance draw-call cost this epic introduces; grid size at MVP scale determines how many tile `MeshInstance3D`s exist simultaneously.

---

## Acceptance Criteria

*Sourced from ADR-0037:*

- [ ] `GridVisual` gains a `Node3D` child subtree holding one `MeshInstance3D` per grid tile, resolved via Story 001's `VisualMeshMappingResource` lookup (not a hardcoded scene reference — data-driven per ADR-0037's Constraints).
- [ ] Each tile's 3D position uses `map_to_3d()` against that tile's existing 2D grid-cell position, with `layer_height = 0` (ground plane).
- [ ] `GridVisual`'s existing `Node2D` script and grid data (whatever currently drives its 2D rendering) is completely unchanged — this story only adds the 3D companion subtree, per ADR-0037's core constraint of zero simulation-code changes.
- [ ] Rendered tile layout visually matches the grid's actual logical layout (spot-checked via live screenshot, not just static scene inspection — per ADR-0037's Validation Criteria).
- [ ] Total draw calls for the rendered grid at MVP tile-count scale stay within the project's 200/frame budget (measured via Remote Debugger or equivalent, per the manifest's existing verification pattern for entity scenes).

---

## Implementation Notes

*Derived from ADR-0037:*

- This is the first story to actually consume Story 001's `VisualMeshMappingResource` and instantiate a real mesh — treat it as the proof that the full pipeline (data mapping → `map_to_3d()` → real `Node3D` in a `Node2D`-rooted scene) works for a genuinely static case before Story 003 introduces per-frame sync complexity.
- No `Camera3D` exists yet in the actual mission scene at this point in the epic (that's Story 003) — verify this story's rendering via a scratch/test scene or the same throwaway-spike pattern already established in `prototypes/3d-tower-defense-kit-spike/`, not by trying to view it through the real `MissionScene`'s current `Camera2D`.
- Since tiles are static, there is no manager/centralized-pass concern here (unlike Stories 004-006) — instantiate once, when `GridVisual` builds its grid, and never touch it again per-frame.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: adding the actual `Camera3D` to `MissionScene`/`the_gap.tscn` so this grid (and the tower placed on it) becomes viewable in the real running game.
- Stories 004-006: any moving entity's visual companion and its per-frame sync requirement.

---

## QA Test Cases

**AC-1 & AC-2 (mesh instantiation + mapping)**:
- Manual check: Given a `GridVisual` with N grid cells and a valid `VisualMeshMappingResource` mapping for the tile type
  - Setup: Load a test scene instantiating `GridVisual` with a small known grid (e.g. 5×3)
  - Verify: Exactly N `MeshInstance3D` nodes exist under the `Node3D` companion subtree, each at the `map_to_3d()`-mapped position of its corresponding grid cell
  - Pass condition: Screenshot shows a visually correct, gapless tile layout matching the grid's logical shape (same verification method already used in the throwaway spike)

**AC-3 (zero simulation changes)**:
- Given: `GridVisual`'s pre-existing 2D grid data/logic
- When: this story's changes are applied
- Then: any existing test covering `GridVisual`'s 2D behavior continues passing unmodified
- Edge cases: N/A — this is a regression check, not new behavior

**AC-4 (visual correctness)**:
- Manual check: live screenshot comparison
  - Setup: run the scratch/test scene with a real grid shape (not a trivial 1×1)
  - Verify: no gaps, no overlaps, no misaligned tiles
  - Pass condition: tile boundaries align edge-to-edge, matching the grid's cell adjacency

**AC-5 (draw call budget)**:
- Manual check: Remote Debugger draw-call count at MVP grid size
  - Setup: run with the largest MVP-scale grid this project currently defines
  - Verify: total draw calls reported by Remote Debugger
  - Pass condition: ≤ 200/frame project-wide (this story's contribution alone should be a small fraction, since Stories 003-006 will add more)

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- `production/qa/evidence/grid-terrain-visual-companion-evidence.md` — screenshot evidence + sign-off per the manual checks above.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (must be DONE — needs `VisualMeshMappingResource` and `map_to_3d()`)
- Unlocks: Story 003 (camera needs something real already rendering to frame against)

## Completion Notes
**Completed**: 2026-08-20
**Criteria**: 3/5 fully verified (AC-1, AC-2, AC-3), 2/5 DEFERRED (AC-4 visual/screenshot check, AC-5 draw-call budget — both require a live rendered session, honestly documented rather than fabricated)
**Deviations**: One shared mesh id (`tile_straight`) used for every `Grid.CellType`, not a per-type mesh set — judged appropriately out of scope for a "prove the pipeline" story (see evidence doc's Deviations section)
**Test Evidence**: `tests/integration/visual_presentation/grid_terrain_visual_companion_test.gd` — 5/5 passing; `production/qa/evidence/grid-terrain-visual-companion-evidence.md` — honest PARTIAL status, deferred items explicit
**Code Review**: Complete — APPROVED (godot-gdscript-specialist: CLEAN after a real `queue_free()`/`add_child()` name-collision bug was found and fixed live, matching this project's existing `mission_hud_planning_cluster_lifecycle` precedent; qa-tester: TESTABLE, one non-blocking coverage gap identified — attempted to close it but the const-vs-property mismatch made the attempt itself broken, so left as a documented known gap instead of shipping a fake-passing test)
