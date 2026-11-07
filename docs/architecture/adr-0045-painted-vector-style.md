# ADR-0045: Painted-Vector Art Style for Mission Scenery

## Status

Accepted (2026-11-08). The user picked blend B and delegated the decisions: "keep going on your own. make your own decisions". This ADR amends ADR-0042 (the HD-2D look is now one of two styles per profile).

## Date

2026-11-08

## Context

The user asked to try a different art style. From a catalogue of 65 styles they liked "hand-painted, stylized" and "flat vector", and from three blends they picked **B, painted vector (balanced)**. A Blender render at the game camera with real terrain confirmed the look: `.superpowers/brainstorm/569-1794058960/content/style_B_render.png`.

The spec is `docs/superpowers/specs/2026-11-08-painted-vector-style-design.md`.

## Decision

- **`Hd2dSceneryProfile.art_style`** is `"hd2d"` (the ADR-0042 look) or `"painted"`. All 12 mission profiles are `"painted"`, each with its own palette (`painted_*` fields). The Sanctuary town stays `"hd2d"` for now. The setting is per profile, so it can be reverted per map.
- **New shaders:**
  - `painted_ground.gdshader`:
    - flat colour tiers per height level, with a soft gradient inside each tier;
    - a rim at each level's mid-height and a cool side band on slopes facing the camera;
    - warm noise patches, brush grain and the HD-2D lane mask;
    - banded sun light, smooth for point lights.
  - `painted_water.gdshader`: unshaded flat water with drifting strokes.
  - `painted_prop.gdshader`: a fill with a vertical gradient, tinted by instance colour, with the same banded light.
- **Painted mode in `Hd2dScenery`:**
  - It swaps the builders: grass cards become `tuft_mesh` tufts, lane-edge cards become taller tufts, flowers become a few soft blooms, bushes and broadleaf trees become sphere blobs, and pines become stacked cones.
  - `_paint_props()` repaints every remaining textured `StandardMaterial3D` (kit rocks, ruins, fence, spires, debris) as a painted fill in the texture's average colour. Glowing materials and tower models are left alone.
  - It skips the pixel-stepped cloud-shadow decals and the floating motes, scales haze by 0.35 and halves the miniature blur.
- **Terrain generator:** twin rivers stay centred in their own halves with a meander of at most 1.0, so their smoothed beds never merge. This was found live in The Mirefen.

## Consequences

- Terrain, lifts, picking and gameplay are unchanged; this is materials and dressing only.
- Draw calls measured live: The Gap 757, The Foothills 617, The Mirefen 577, The Duskwood 853, against 750–942 before. The scenery is still over the 200 budget (a pre-existing problem), and painted mode doesn't add to it.
- **Towers (added the same day):** in painted maps `TowerModel3D.set_painted_style(true)` re-shades every textured surface with `painted_tower.gdshader`: the tower's own texture, brightened ×1.18 and saturated ×1.2, under the same banded sun, with emission kept for glowing crowns. Flourishes added on rank-up are repainted. The Inventory preview keeps the original materials.
- 2D unit sprites keep their own look for now. Phase 2 restyles the tower textures and the kit props, and builds the queued 3D Sanctuary buildings in this style.
- MultiMesh instance transforms can't be read back headless, so tuft placement is checked live, not in unit tests.

## ADR Dependencies

| Relation | ADR |
|---|---|
| Depends on | ADR-0042 (Hd2dScenery), ADR-0044 (terrain heightfield) |
| Amends | ADR-0042 (adds a second art style) |

## Engine Compatibility

| Field | Value |
|---|---|
| Engine | Godot 4.6.2 |
| Domain | Rendering: spatial shaders with custom `light()` (`LIGHT_IS_DIRECTIONAL`), `NODE_POSITION_WORLD`, MultiMesh instance colours via `COLOR` |
| Verification | All three shaders live-compiled on 4.6.2.stable with no errors (The Gap, The Foothills, The Mirefen, The Duskwood). |
| Gotcha | Banding the attenuation of an omni light (campfires) draws hard stepped patches, so the bands apply to directional light only. |

## GDD Requirements Addressed

- `design/gdd/grid-system.md` / spec 2026-11-07-3d-terrain §6.1: high ground readable at a glance (tier colours and rims).
- Art direction: the user's style choice (art overhaul, `design/art/codex-art-overhaul.md` §1 "visual direction not locked").
