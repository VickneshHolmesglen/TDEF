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
- **Per-mission profiles (added 2026-10-11, same day):**
  - `MissionScene` builds the scenery on `grid_initialized` from
    `assets/data/hd2d/<mission_id>_scenery.tres`. It stays inactive behind the
    Mission Select screen and turns on at `mission_launched`.
  - With no profile, the flat 2D `GridVisual` remains.
  - Profiles exist for The Gap, The Foothills, The Hollow and The Narrows.
- **Profile features beyond the base layer:**
  - `lane_shimmer`: a scrolling, glinting river lane (The Narrows).
  - `lane_scale`: cobble size on the road.
  - `lane_edge_cards`: reeds or dry tufts along the banks.
  - `spire_count`: rock spires.
  - `crystal_clusters`: emissive crystal clusters, each with its own light.
  - Grass, foliage and ruin tints.
- **Readability rule:**
  - Tall props (trees, spires) are only placed where their on-screen height
    (`cos(pitch)`) clears every lane and landmark cell (`_clear_above`).
  - Mission maps fill the screen, so border dressing prefers the in-grid
    blocked cells over the off-map margin.
- **Units (2026-10-12):**
  - `GroundShadow` puts a contact shadow under the hero, monsters and towers.
  - The profile's `unit_tint` is applied as a `CanvasModulate` ("UnitLight")
    on the 2D gameplay canvas. The HUD is a `CanvasLayer`, so it is
    unaffected.
- **Sprite pixel conversion (2026-10-12, user decision: "pixelate all of
  them"):**
  - All 252 character, gear, monster, tower, item and species sprites under
    `assets/art/` are pixel art, converted by
    `tools/asset-pipeline/hd2d/pixelate_sprites.py --batch`.
  - Each output keeps its source's **exact dimensions**: the sprite is
    converted at low resolution, then scaled back up with nearest-neighbour.
    So frame slicing, gear overlays, tower layer stacking and every
    texture-size-based fit work unchanged, and pixel edges stay crisp under
    the default linear filtering.
  - Sheets are converted frame by frame and share one palette.
  - Pixel density per category is matched to on-screen size, about 1.4
    screen px per sprite pixel.
  - The painted originals are kept in `assets/source/painted/` (with a
    `.gdignore`, so Godot never imports them). They are the batch's only
    input, so re-tuning never pixelates twice.
- **Effects (2026-10-12):** `PixelVfx` gives every effect a pixel style.
  - Particles are square, unrotated and sized in whole pixels, with a stepped
    fade and stepped motion.
  - Rings are drawn as pixel blocks; projectile trails are hard-edged.
  - A dying monster's ghost breaks apart in blocks the size of its own art
    pixels (`dissolve.gdshader`'s `cells`).
- **UI skin (2026-10-12):** `Hd2dTheme` is the project theme.
  - Fonts: Cinzel for headings, Alegreya Sans for body text (both OFL).
  - Frames: pixel 9-slice frames generated by `generate_ui_skin.py`.
  - `ShellChromeStyle` gained textured `skin_*` helpers next to its restyled
    flat boxes.
- **Sanctuary diorama (2026-10-12):**
  - `Hd2dTownBackdrop`, a SubViewport with its own World3D, renders an
    `Hd2dScenery` into the diorama's `Background` texture.
  - `Hd2dScenery.frame_rect()` frames the diorama's own rect, so the town's
    2D building buttons stay on top, unchanged.
  - `town_cells()` lays out a dirt pad and L-path per building, the castle
    plaza (GOAL) and a gate road (SPAWN, off the bottom edge).
  - The Sanctuary building art joined the pixel conversion (sanctuary
    category, 96 px).

- **Kit models (2026-10-15):** CC0 Kenney Nature Kit meshes replace the
  primitive stand-ins.
  - Coverage: rocks, spires, pines, landmark columns and rubble, plus a new
    `debris` pass of stumps, logs and mushrooms on the blocked border.
  - Source: 24 `.glb` files in `assets/art/hd2d/kit/`, chosen per profile
    with `kit_*` lists. An empty list keeps the primitive.
  - **Reskin, not Kenney colours.** `_kit_surface_material()` maps each
    Kenney material name (`leafs*`, `wood*`, `grass`, `dirt`, `stone*`,
    `_defaultMat`) onto the profile's pixel textures. Those are world-space
    triplanar with one repeat per `width × ground_texel_px`, so prop pixels
    match the ground's, and stretched meshes never stretch texels. Only
    mushroom caps and stems keep their own (toned-down) colour.
  - **Layout-stable.** The primitive paths keep their exact `_rng` draws.
    Kit variant, yaw and debris come from a separate `_kit_rng`
    (`rng_seed + 7919`), so enabling the kit never moves anything.
  - **Photo-sourced textures.** `generate_hd2d_textures.py::photo_sets()`
    reduces CC0 Poly Haven scans (`assets/source/kits/polyhaven_ground/`) to
    64 px in mission palettes (`*kit_rock`, mossy `kit_ruin_stone`), plus an
    opaque `*kit_foliage` for 3D pine canopies. The leaf cards are cut-outs
    and can't wrap a solid mesh.

- **Atmosphere pass (2026-10-15):** an `Atmosphere` profile group adds
  depth and motion without touching gameplay.
  - Drifting cloud shadows: two decals of one seamless noise tile, slid
    and wrapped each frame (`cloud_shadow_*`).
  - Motes: dust, spores or fireflies as GPU particles (`motes_*`, `mote_*`).
  - Depth haze (`FOG_MODE_DEPTH`), 3D-only bloom, and a tilt-shift blur on
    the top and bottom screen edges (`CameraAttributesPractical` DOF). Haze
    and blur distances follow zoom (`_sync_depth_effects()`). Only the 3D
    layer blurs, so units and towers stay sharp, which is the HD-2D look.
  - More dressing: small stones on lane banks (`kit_bank_debris`), campfires
    with a flickering light, and low in-field clutter on missions
    (`debris_field_share` capped by `field_debris_max_px`, so a tower simply
    covers it).
  - Every new knob defaults off. The passes run after every `_rng` draw,
    so existing layouts are unchanged. Bloom uses the scenery's own
    Environment, never `Viewport.use_hdr_2d`.