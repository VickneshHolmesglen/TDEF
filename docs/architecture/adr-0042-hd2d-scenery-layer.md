# ADR-0042: HD-2D Scenery Layer Under the 2D Gameplay Canvas

## Status

Accepted (user-directed, 2026-10-11)

## Date

2026-10-11

## Context

The user set the target look with `docs/images/graphics.PNG`: HD-2D, meaning a
pixel-painted 2D ground with real 3D grass, trees and props, a tilted camera
and warm light. They asked for "2d background with 3d extras". They also said
Codex can no longer generate art, so Claude Code authors the assets.

The dormant full-3D path (ADR-0037/0040, `ENABLE_3D_PRESENTATION_MODE`) was
emulated live in The Gap the same day. The result was a grey, unlit void with
tiny or missing stand-in meshes. Worse, every 2D overlay (route arrows,
placement cursor, damage numbers, hero feedback) stayed in Camera2D space and
would misalign under a perspective camera. Cutting over to full 3D means
rebuilding all of those. That is a large job and not what was asked for.

## Decision

Render the scenery in 3D **underneath** the unchanged 2D gameplay canvas.
Gameplay, picking (`get_global_mouse_position`), entity sprites, the HUD and
every overlay stay exactly as they are.

- **Node:** `Hd2dScenery` (`src/presentation/hd2d/`) under the mission's
  `PresentationRoot3D`.
  - It holds its own **orthographic** `Camera3D`, tilted by
    `camera_pitch_deg`.
  - Its `follow_camera(Camera2D)` re-derives the ortho size and centre from
    the Camera2D every frame, so zoom, framing and shake stay locked.
- **Alignment:** `to_world(p2d) = (x, h, y / sin(pitch))`.
  - An orthographic camera maps ground depth to screen by `sin(pitch)`, so
    stretching depth by its inverse cancels it exactly. Every ground point
    lands on the same pixel as the 2D map.
  - Upright props still show their sides, foreshortened by `cos(pitch)`.
  - Covered by `tests/unit/visual_presentation/hd2d_scenery_test.gd`.
- **Isolation:**
  - Every scenery node is on layer 12 (`RENDER_LAYER = 1 << 11`), including
    the sun. The camera's `cull_mask` is that layer only.
  - So the dormant ADR-0037 companions sharing the World3D are never drawn.
  - The environment is set on the camera itself, not a global
    `WorldEnvironment`.
- **Data-driven:**
  - `Hd2dSceneryProfile` holds the textures, densities, light and pitch, one
    `.tres` per mission under `assets/data/hd2d/`.
  - The Gap uses `the_gap_scenery.tres`.
  - A missing profile falls back to the flat 2D `GridVisual`.
- **Assets:** generated procedurally by
  `tools/asset-pipeline/hd2d/generate_hd2d_textures.py` (low-res palette
  textures, nearest-filtered in-engine). Grass, flowers and shrubs are
  MultiMesh crossed cards (`hd2d_foliage_card.gdshader`: top-only wind sway,
  up-facing normals). The ground is `hd2d_ground.gdshader`, a lane mask with
  pixel-snapped, noise-jittered edges.
- **Integration in The Gap:** `the_gap.gd::_build_scenery()` builds it after
  the Camera2D framing and hides `GridVisual`. It is skipped when
  `ENABLE_3D_PRESENTATION_MODE` is true.

## Consequences

- **Positive:**
  - The HD-2D look ships without touching gameplay, picking or any overlay.
  - All scenery is regenerable from code.
  - Per-mission looks are a `.tres` edit.
- **Negative:**
  - The 3D layer always renders behind the 2D canvas, so units are never
    occluded by grass or trees. In practice they stand on top of tall grass
    rather than in it.
  - Entity sprites stay 2D-canvas rather than lit billboards.
- **Gotcha found (live, 2026-10-11):**
  - A `Light3D` is culled by the camera's `cull_mask` through its own
    `layers`, not only through `light_cull_mask`.
  - Left on the default layer 1, the scenery camera dropped its own sun, and
    only ambient light reached the ground. Raising light energy made no
    difference.
- **Not yet done:**
  - `MissionScene.tscn` (the other mission scene) still uses the 2D terrain.
    Wiring it is the same `_build_scenery` call plus one profile per mission.
