# Painted-Vector Art Style (B) — Design

Date: 2026-11-08
Status: Approved by delegation. On 2026-11-08 the user picked blend **B** ("painted vector, balanced") from the hand-painted and flat-vector options and said: "keep going on your own. make your own decisions. based on my previous decisions, make decisions for me and keep working". The calls below are Claude's, made from the user's earlier choices.
Reference render: `.superpowers/brainstorm/569-1794058960/content/style_B_render.png` (Blender mock, game camera, real terrain heights).

## 1. Intent

Replace the HD-2D pixel look with a clean, bright **painted vector** look:
- crisp shapes and flat colour tiers, softened by painted light;
- faint brush grain and warm colour patches;
- hills that read instantly as high ground.

This follows the user's earlier choices: smooth 3D over pixelated, rolling hills, high ground readable by colour, and hand-painted + flat vector, balanced.

## 2. Look rules

- **Ground:**
  - flat colour tiers by height level, a lighter tier per level, with a soft gradient inside each tier;
  - a thin outline at each level's mid-height;
  - darker, cooler front-facing slopes (the side band);
  - low-frequency warm patches and faint directional brush grain;
  - no pixel snapping and no pixel textures.
- **Lane:** a clean sand-coloured shape with a soft darker lip. Landmarks use a pale flagstone colour.
- **Water:** flat blue with painted ripple strokes and pale glints, gently moving.
- **Lighting:** soft banded ("painted") diffuse light, with 3–4 smooth tones instead of a continuous gradient. Warm sun, cool shadows.
- **Dressing:**
  - grass cards become small painted tufts (3-sided blades);
  - broadleaf trees and bushes become rounded painted blobs;
  - pines become stacked painted cones;
  - every prop uses one painted-prop shader (flat colour with a vertical gradient and the same banded light).
- **Per-map character:** each mission's scenery profile carries its own painted palette (tier low/high, side shade, lane, water). Examples: The Foothills is golden, the marsh maps are olive, The Ashfields is grey-brown, The Duskwood is deep green.

## 3. Scope

**Phase 1 (this project):**
- ground, lane, water and lighting;
- tufts, painted trees, bushes and pines;
- a palette on all 12 mission profiles.

**Kept as-is in phase 1:**
- kit rocks, ruins, spires, crystals, debris and campfires (their textures are already smooth);
- towers (smooth 3D);
- the 2D unit sprites;
- the UI;
- the Sanctuary town scenery.

**Phase 2 (later):**
- restyle the towers' textures and the kit props to match;
- the 3D Sanctuary buildings (the queued project), made in this style from the start.

## 4. Architecture

- `Hd2dSceneryProfile.art_style` is either `"hd2d"` (today's look) or `"painted"`. All 12 mission profiles switch to `"painted"`. The Sanctuary town stays `"hd2d"` until phase 2. A profile can be switched back, so the change is reversible per map.
- The painted palette lives in new profile fields, with defaults in code.
- New shaders:
  - `painted_ground.gdshader` (ground, lane mask, tiers, rim, side band, grain, banded `light()`);
  - `painted_water.gdshader`;
  - `painted_prop.gdshader` (props).
- `Hd2dScenery` picks the ground, water and dressing builders by `art_style`; the terrain heightfield, lifts and picking are unchanged.
- Performance: tufts are one MultiMesh, and the trees share a handful of meshes and materials. The style must not add draw calls compared with today.

## 5. Testing

- Unit tests:
  - painted profiles validate;
  - the ground uses the painted shader when `art_style == "painted"` and the HD-2D shader otherwise;
  - tufts and painted trees are built only in painted mode and never on the lane or in water.
- Live checks (every new shader): The Foothills, The Mirefen, The Gap and The Duskwood, screenshotted and compared against the reference render, with the debug output read.
