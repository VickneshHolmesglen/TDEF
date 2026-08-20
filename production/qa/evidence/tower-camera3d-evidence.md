# QA Evidence: Tower Visual Companion + Camera3D (Epic 15 Story 003)

**Story**: `production/epics/epic-15-3d-visual-presentation/story-003-tower-camera3d.md`
**ADR**: `docs/architecture/adr-0037-visual-presentation-3d-companion-layer.md`
**Date**: 2026-08-20
**Status**: PARTIAL — AC-1, AC-2, AC-3, and AC-4 have real automated coverage
(`tests/integration/visual_presentation/tower_camera_companion_test.gd`). AC-5 and AC-6 are
**DEFERRED** pending a human live-screenshot / Remote Debugger session — see "Deferred checks"
below. No screenshot evidence is fabricated in this document.

---

## Automated coverage (this session)

`tests/integration/visual_presentation/tower_camera_companion_test.gd` exercises
`TowerInstance.configure()` (`src/core/tower/tower_instance.gd`) and the real
`the_gap.tscn`/`MissionScene.tscn` scene trees directly, headless:

| AC | Test(s) | What it proves |
|---|---|---|
| AC-1 (companion + mesh resolution) | `test_configure_creates_visual_companion_with_a_real_node3d_mesh_child` | `configure()` produces a `VisualCompanion3D` `Node3D` child holding exactly one real `Node3D` mesh instance, resolved through the **real, live** `GGameDataRegistry.get_visual_mesh_mapping()` boot path against the shipped `assets/data/visual_meshes/tower_round.tres` mapping (not an injected fixture). |
| AC-2 (map_to_3d sync, correct call order) | `test_configure_places_companion_mesh_at_map_to_3d_of_tower_position` | The companion mesh's `position` exactly matches `VisualMath.map_to_3d(tower.position, 0.0)`, exercised with this project's real call order (`position` set before `configure()`, mirroring `mission_scene.gd`/`the_gap.gd`'s `_on_tower_placed`). |
| AC-2 (edge case — no drift) | `test_configure_called_twice_with_unchanged_position_does_not_drift` | Calling `configure()` again with an unchanged `position` produces an identical companion-mesh position — no accumulation/drift. |
| AC-2 (edge case — grid boundary) | `test_configure_at_grid_boundary_position_maps_correctly` | A tower at The Gap's bottom-right-most cell center still maps 1:1 onto the XZ plane with no correction. |
| AC-2 (no new callback — real source scan) | `test_tower_instance_script_declares_no_process_or_physics_process_callback` | Direct text scan of `tower_instance.gd` confirms zero `func _process(`/`func _physics_process(` declarations — TowerInstance had zero before this story (verified via grep during implementation) and still has zero now; the sync line lives in `configure()`, the pre-existing per-tower "apply visual state" entry point, not a new per-frame override. See **Deviations** below for why this differs from ADR-0037's literal framing. |
| AC-3 (Camera3D present, the_gap.tscn) | `test_the_gap_scene_has_camera2d_and_camera3d_siblings` | A real `the_gap.tscn` instance has both `Camera2D` and `Camera3D` as siblings. |
| AC-3 (Camera3D present, MissionScene.tscn) | `test_mission_scene_has_camera2d_and_camera3d_siblings` | A real `MissionScene.tscn` instance (via `GdUnitSceneRunner`) has both `GameplayRoot/Camera2D` and `GameplayRoot/Camera3D`. |
| AC-3 (fixed-angle, non-rotating, non-cutover) | `test_the_gap_scene_camera3d_is_fixed_angle_and_not_current_by_default` | `Camera3D.current == false` at scene load — Camera2D remains the active view by default, per ADR-0037's "no mass flip-the-switch cutover" Migration Plan; there is no script driving the Camera3D's rotation (a plain, static scene node), satisfying "non-rotating." |
| AC-4 (toggle coexistence) | `test_toggling_current_between_camera2d_and_camera3d_does_not_error` | Disabling `Camera2D`/enabling `Camera3D.current` and back does not error. |
| AC-4 (edge case — both current) | `test_both_cameras_current_simultaneously_does_not_crash` | Both cameras enabled/current at once does not crash (render correctness not asserted — only graceful behavior, per the story's own QA Test Cases). |
| AC-4 (edge case — neither current) | `test_neither_camera_current_does_not_crash` | Neither camera enabled/current does not crash. |

All tests are headless-executable and deterministic — no rendering, no timing dependency.
Scene-tree tests (`the_gap.tscn`) re-initialize `GGrid` in cleanup, matching
`mission_scene_the_gap_test.gd`'s own established cross-suite-isolation fix.

---

## Deferred checks (require a human with a live rendered session)

**AC-5 (combined visual correctness — tower + grid together, correct scale/position)**
- The story's own QA Test Cases require this be checked via **live screenshot**, not static scene
  inspection: "Verify: tower renders at the correct grid cell, correct relative scale to the
  tiles... Pass condition: no floating/sunken/misaligned tower relative to its tile."
- This cannot be produced by this session (no screenshot capability available for this task).
  **DEFERRED** — needs a human (or a live Godot MCP `run_project` + `take_screenshot` session,
  per this project's own established live-verification pattern) to launch a real mission (The
  Gap), place a tower, switch `Camera3D.current = true`, and visually confirm alignment.
- **Known, inherited scale caveat** (not introduced by this story): `VisualMath.map_to_3d()` is a
  1:1 passthrough of 2D world units onto the 3D XZ plane (no unit-conversion factor) — the same
  convention Story 002's grid tiles already ship with. The Kenney "Tower Defense Models" GLB
  meshes (`tower-round-base.glb`, etc.) are typically authored at a small (~1-2 unit) native
  scale, while this project's grid uses 64-world-unit cells. If Story 002's tiles have not
  separately had this reconciled, the tower mesh added here will inherit the identical
  small-relative-to-cell-spacing scale mismatch — this is a pre-existing, already-flagged
  tuning gap (ADR-0037's Risks: "the fixed Camera3D's exact framing might not actually
  reproduce..."), not a new defect from this story, and is exactly the kind of thing this
  project's own "always-verify-scale-live" lesson (`docs/engine-reference/godot/VERSION.md`)
  flags as screenshot-only.
- **Known, inherited lighting caveat**: no `DirectionalLight3D`/`WorldEnvironment` exists
  anywhere in `src/` yet (confirmed by search during this story) — `MeshInstance3D` content may
  render dark/unlit under the default environment until a lighting setup is added. This is
  explicitly out of this story's scope (ADR-0037 frames rendering/VFX polish as a later phase)
  but will affect what a live screenshot actually shows; flagged here so it isn't mistaken for a
  positioning bug during the deferred manual check.

**AC-6 (HUD unaffected by which camera is active)**
- The story's own QA Test Cases require this be checked via manual toggle-and-compare: "Setup:
  toggle between the two cameras with HUD visible... Pass condition: no visual regression in HUD
  layout, opacity, or interactivity."
- **DEFERRED** — requires a live rendered session with real HUD content on screen. The automated
  suite above proves the two cameras coexist in the scene tree without error under every
  current/enabled combination (AC-4), which is the mechanical precondition for this check, but
  does not itself verify pixel-level HUD appearance.
- Per ADR-0037's own stated expectation ("`CanvasLayer` compositing is unaffected by 2D-vs-3D
  world content" — the same mechanism `HUD`'s `CanvasLayer` already relies on today regardless of
  what's in the 2D/3D world beneath it), no HUD-side regression is architecturally expected; this
  deferred check exists to confirm that expectation against the real renderer, not because a
  specific risk was identified.

---

## Deviations / judgment calls

- **TowerInstance had zero existing `_process()`/`_physics_process()` callbacks, not one.**
  ADR-0037's Decision section states: "`TowerInstance`/`Hero`... sync in their own existing
  `_process`/`_physics_process` — this is not a *new* per-node override, since these two already
  have one." A grep of `tower_instance.gd` prior to this story's changes found **zero** such
  declarations. This is a factual gap between the ADR's assumption and the actual codebase, not
  something this implementation silently papered over.
  - **Resolution**: rather than adding a *new* `_process()`/`_physics_process()` override (which
    would violate AC-2's literal requirement — "no new `_process`/`_physics_process` callback is
    added"), the one-line sync call was placed inside `configure()`, TowerInstance's actual
    pre-existing "apply visual state" entry point. This is a legitimate fit for the story's real
    intent (sync on every relevant position-affecting event, without adding a new per-frame
    override) because, in this codebase's real usage, a `TowerInstance`'s `position` is set
    exactly once — by its owning mission scene (`mission_scene.gd`/`the_gap.gd`'s
    `_on_tower_placed`) — strictly *before* `configure()` is ever called, and is never touched
    again afterward (no tower-repositioning feature exists). The story's own QA Test Cases hedge
    this exact case with "if applicable" ("the tower's `position` changes... or the scene first
    loads"), consistent with towers being static once placed. This also mirrors
    `grid_visual.gd`'s own, already-shipped precedent (Story 002): build/sync once from the
    entity's existing configuration method, since that entity type does not move after placement
    — as opposed to Stories 004-006's centralized per-frame managers, which is the pattern
    actually needed for entities that *do* move continuously.
  - **Flagging this explicitly** per this project's collaboration protocol: this is a deviation
    from the ADR's stated assumption, not from its actual architectural constraint (no new
    per-node override) — the constraint is satisfied more strictly than the ADR's own text
    implies was necessary.
- Single shared mesh id (`tower_round`, reusing Story 001's existing
  `assets/data/visual_meshes/tower_round.tres`) used for every tower archetype/element — no new
  `.tres` was authored. Matches the story's explicit scope ("at least one tower type... do not
  attempt to convert every tower variant") and the task brief's own suggested placeholder id.
- Camera3D transform values (`position = Vector3(512, 650, 840)`,
  `rotation_degrees = Vector3(-55, 0, 0)`) were computed to roughly center over The Gap's
  16x12-cell / 64px-cell-size (1024x768 world-unit) grid, pitched down ~55 degrees — a
  starting-point tuning value per the story's own Implementation Notes ("exact transform values
  are a tuning task, not a fixed number this story must match precisely"), not a live-verified
  final framing. The same values were applied to both `MissionScene.tscn` and `the_gap.tscn`
  since both currently share the same grid dimensions; a future mission with a different grid
  size would need its own tuning pass (out of this story's scope).
- `Camera3D.current` defaults to `false` in both scenes (`Camera2D.enabled = true` unchanged) —
  per ADR-0037's Migration Plan ("no mass 'flip a switch' cutover"), Camera2D remains the active
  view until a later story explicitly cuts over.
