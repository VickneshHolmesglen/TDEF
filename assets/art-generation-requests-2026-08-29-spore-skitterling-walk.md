# Art Generation Request — Spore Skitterling Walk Cycle (2026-08-29)

This file is meant to be uploaded directly into an image generator. Generate the
image, save it, and drop it into `assets/source/monsters/` as
`spore_skitterling_walk.png` — Claude will handle slicing, alpha-cutting, and
wiring it into the game from there (see `design/art/animation-pipeline.md`).

## Reference (must match — this monster already has shipped static art)

`spore_skitterling.png` already exists in `assets/art/monsters/` and is the
game's current idle/spawn pose for this monster. The walk cycle must be the
**same creature, same materials, same silhouette rules** — this is a new pose
set for an existing asset, not a redesign.

Original prompt (for reference, do not resend — describes the creature only):
> Isometric fantasy game monster asset, "Spore Skitterling", single creature
> centered on a plain dark background for easy cutout. A small many-legged
> fungal/insectoid creature, low and scuttling, wider than tall, clean simple
> outline with no protrusion above its own shoulder line. Body reads as a
> mushroom-cap fused with an insect thorax — pale mottled cap-shell on top,
> skittering segmented legs beneath. One accent color zone (sickly
> yellow-green spore markings — muted/desaturated olive, explicitly NOT a
> bright healthy green) plus one specular highlight on the cap-shell.
> Painterly pixel-art, hand-painted miniature diorama style, fixed oblique
> isometric angle. Avoid pure blood-red, purple, or cyan anywhere.

## Sheet Specification

- **4 frames**, one full scuttle-cycle loop, side-on to the same fixed oblique
  isometric angle as the reference art (camera angle never changes between
  frames).
- **Single horizontal strip**, frames left to right, in gait order (frame 1
  loops back into frame 1 — must read as a continuous cycle, not a
  start/stop sequence).
- **Each frame must be the same fixed square canvas size** (e.g. 512×512) with
  the creature's silhouette consistently scaled and vertically anchored
  (ground-contact point at the same Y position in every frame) — the single
  most important requirement for automated slicing. Do not let the creature
  grow, shrink, or drift between frames.
- **Plain dark/black background**, identical across all 4 frames, for the
  same color-distance alpha-cut technique used on every other asset.
- No baked-in motion blur, speed lines, or ground shadow.

## Prompt to send

```
Isometric fantasy game monster sprite sheet, 4-frame skitter/scuttle cycle,
"Spore Skitterling" — same creature as this reference: small many-legged
fungal/insectoid creature, mushroom-cap fused with an insect thorax, pale
mottled cap-shell on top, segmented skittering legs beneath, sickly
yellow-green spore markings (muted/desaturated olive, not bright healthy
green), one specular highlight on the cap-shell. Silhouette wider than tall,
no protrusion above its own shoulder line, clean simple outline. Painterly
pixel-art, hand-painted miniature diorama style, fixed oblique isometric
angle — identical camera angle in all 4 frames.

Lay out exactly 4 frames left to right in a single horizontal strip, each
frame an identical fixed square canvas, plain dark/black background in every
frame. Frames show a continuous low, scuttling multi-legged gait cycle in
order: (1) legs splayed wide to one side, body low, (2) legs gathering
underneath, body compact, (3) legs splayed wide to the opposite side, body
low, (4) legs gathering underneath, body compact, cycling back into frame 1.
Keep the creature's scale and ground-contact height identical across all 4
frames — do not let it grow, shrink, or shift vertically between frames. No
motion blur, no speed lines, no ground shadow baked in.

Avoid pure blood-red, purple, or cyan anywhere in the art.
```

## After generation

1. Drop the raw sheet into `assets/source/monsters/spore_skitterling_walk.png`.
2. Claude slices the 4 frames (uniform grid, same alpha-cut technique as every
   other monster) into individual frames under `assets/art/monsters/`.
3. Combine into a single atlas texture (idle + walk frames), then update
   `assets/data/creature_atlases/spore_skitterling.tres` — repoint
   `atlas_texture` at the new combined atlas, update `atlas_columns`/
   `frame_count`, and add a new `"walk"` `CreatureAnimationClip`
   (`frame_count=4`, `loop=true`) alongside the existing `idle` clip.
   `MonsterSwarmRenderer3D` reads this at runtime (Epic 16 Story 6+) — not any
   legacy per-monster companion node, which is fully retired for this tier.
