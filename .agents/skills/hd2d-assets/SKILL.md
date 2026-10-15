---
name: hd2d-assets
description: "Author or re-tune HD-2D art for Sanctuary Defenders: procedural textures, foliage cards, UI skin frames, pixel-converted sprites, and per-mission scenery profiles (ADR-0042). Use when adding a new texture/prop/sprite, a new mission's scenery, or changing the look of grass, ground, trees or UI frames."
argument-hint: "[texture <name> | sprite <path> | mission <mission_id> | ui-skin | retune <profile>]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash
---

# HD-2D Asset Authoring

Target look: `docs/images/graphics.PNG`. That means a pixel-painted 2D ground,
3D grass, trees and props, an orthographic tilted camera and warm light.
Codex no longer generates art, so Codex authors every asset procedurally.
The architecture is in `docs/architecture/adr-0042-hd2d-scenery-layer.md`.
Read it before changing anything structural.

## Pick the route

| Need | Tool | Output |
|------|------|--------|
| Ground, foliage card, prop texture (bark, rock, ruin, water, reeds) | `tools/asset-pipeline/hd2d/generate_hd2d_textures.py` | `assets/art/hd2d/*.png` |
| Panel, button, tab, focus or bar frame | `tools/asset-pipeline/hd2d/generate_ui_skin.py` | `assets/ui/skin/*.png` |
| New or replaced character, monster, tower, item or building sprite | `tools/asset-pipeline/hd2d/pixelate_sprites.py` | `assets/art/**` (same size as the source) |
| A new mission's look | New `Hd2dSceneryProfile` `.tres` | `assets/data/hd2d/<mission_id>_scenery.tres` |

Run every script from the repo root: `python tools/asset-pipeline/hd2d/<script>.py`.

## Rules

1. **Deterministic.** The texture generator seeds `RNG` once. To add a
   texture, add a function plus a `save()` call. Do not reseed. Drawing
   before existing calls shifts every later texture, so append new draws at
   the end of `main()` / `mission_sets()`.
2. **Low-res plus a palette.** Draw at low resolution with a small palette
   (`palette_map` + `dither`). The engine filters these nearest. Never author
   smooth gradients; quantise them into bands.
3. **Sprites: always from the originals.** `pixelate_sprites.py --batch`
   reads `assets/source/painted/` (same relative paths). A new painted sprite
   goes there first, then run the batch. Never pixelate a file that is
   already in `assets/art/`, because it would be converted twice.
   - Output keeps the source's exact pixel dimensions, so atlas slicing, gear
     overlays and tower stacking keep working.
   - Pixel density per category lives in `plan()`. Add a category there, not
     an ad-hoc size.
   - Before a batch, use `--preview OUT.png SRC.png` to compare heights.
4. **Import settings.**
   - `assets/art/hd2d`, `terrain`, `props` and `towers` stay **lossless**
     (some are read with `get_pixel()`, and towers need exact alpha).
   - Other new art that is at least 256 px goes to VRAM Compressed BPTC
     (`compress/mode=2`, `high_quality=true`). See the VRAM audit memory.
   - After replacing a PNG, the stale `.godot/imported` cache can keep
     serving the old pixels. Reimport with
     `Godot.exe --headless --editor --path . --quit`.
5. **Profiles, not code.** A mission's look (densities, tints, pitch, light,
   `lane_shimmer`, `spire_count`, `crystal_clusters`, `lane_edge_cards`, the
   kit lists, and the Atmosphere group: clouds, motes, haze, bloom,
   `tilt_shift`) is a
   `.tres` edit. Copy the closest existing profile in `assets/data/hd2d/`.
   With no profile, the mission falls back to the flat `GridVisual`.
6. **Readability.** Tall props only go where `cos(pitch)` × height clears
   lanes and landmarks (`_clear_above`). Grass height is in
   `grass_height_px` and has been cut twice at the user's request; keep it
   short.
7. **Layering gotchas.**
   - Every scenery node, including lights, must be on `RENDER_LAYER`
     (layer 12). A `Light3D` outside the camera's `cull_mask` is silently
     ignored.
   - Never put `#` comments inside `.tscn`/`.tres` blocks.
8. **New shader?** Read `design/art/animation-pipeline.md` first, keep it to
   one named effect in `src/shaders/`, and live-check it. Headless tests
   cannot compile shaders.

## Done checklist

- [ ] Script edits keep earlier outputs byte-identical (`git diff --stat assets/art/hd2d` shows only the intended files)
- [ ] Import mode correct (rule 4) and editor reimport run
- [ ] Profile or texture wired; the `.tres` has no comments
- [ ] Screenshot taken only if the user asked for a live check (project rule: no unrequested testing)
- [ ] `production/art-overhaul-status.md` updated
