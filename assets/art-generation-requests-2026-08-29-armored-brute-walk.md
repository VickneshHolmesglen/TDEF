# Art Generation Request — Armored Brute Walk Cycle (2026-08-29)

This file is meant to be uploaded directly into an image generator. Generate the
image, save it, and drop it into `assets/source/monsters/` as
`armored_brute_walk.png` — Claude will handle slicing, alpha-cutting, and
wiring it into the game from there (see `design/art/animation-pipeline.md`).

## Reference (must match — this monster already has shipped static art)

`armored_brute.png` already exists in `assets/art/monsters/` and is the
game's current idle/spawn pose for this monster. The walk cycle must be the
**same creature, same materials, same silhouette rules** — this is a new pose
set for an existing asset, not a redesign.

Original prompt (for reference, do not resend — describes the creature only):
> Isometric fantasy game monster asset, "Armored Brute", single creature
> centered on a plain dark background for easy cutout. A squat, heavily-built
> brute in crude riveted plate armor, wider than it is tall, low center of
> gravity, clean simple outline with no protrusion above its own shoulder
> line despite the bulk — mass reads through width, not height. One accent
> color zone (dull rust-orange armor trim) plus one specular highlight on a
> metal shoulder plate. Painterly pixel-art, hand-painted miniature diorama
> style, fixed oblique isometric angle. Avoid pure blood-red, purple, or cyan
> anywhere.

## Sheet Specification

- **4 frames**, one full heavy-stomp walk-cycle loop, side-on to the same
  fixed oblique isometric angle as the reference art (camera angle never
  changes between frames).
- **Single horizontal strip**, frames left to right, in gait order (frame 1
  loops back into frame 1).
- **Each frame must be the same fixed square canvas size** (e.g. 512×512) with
  the creature's silhouette consistently scaled and vertically anchored
  (ground-contact point at the same Y position in every frame).
- **Plain dark/black background**, identical across all 4 frames.
- No baked-in motion blur, speed lines, or ground shadow.

## Prompt to send

```
Isometric fantasy game monster sprite sheet, 4-frame heavy stomping walk
cycle, "Armored Brute" — same creature as this reference: squat, heavily-built
brute in crude riveted plate armor, wider than it is tall, low center of
gravity, dull rust-orange armor trim as the one accent zone, one specular
highlight on a metal shoulder plate. Silhouette stays wider than tall in every
frame, no protrusion above its own shoulder line. Painterly pixel-art,
hand-painted miniature diorama style, fixed oblique isometric angle —
identical camera angle in all 4 frames.

Lay out exactly 4 frames left to right in a single horizontal strip, each
frame an identical fixed square canvas, plain dark/black background in every
frame. Frames show a heavy, weighty stomping gait cycle in order: (1) contact
— leading foot planted hard, torso leaning into the step, (2) passing — body
rising, weight shifting through center, (3) contact — opposite foot planted
hard, torso leaning into the step, (4) passing — body rising, weight
shifting through center, cycling back into frame 1. This should read as slow
and heavy, not a sprint. Keep the creature's scale and ground-contact height
identical across all 4 frames — do not let it grow, shrink, or shift
vertically between frames. No motion blur, no speed lines, no ground shadow
baked in.

Avoid pure blood-red, purple, or cyan anywhere in the art.
```

## After generation

1. Drop the raw sheet into `assets/source/monsters/armored_brute_walk.png`.
2. Claude slices the 4 frames (uniform grid, same alpha-cut technique as every
   other monster) into individual frames under `assets/art/monsters/`.
3. Combine into a single atlas texture (idle + walk frames), then update
   `assets/data/creature_atlases/armored_brute.tres` — repoint
   `atlas_texture` at the new combined atlas, update `atlas_columns`/
   `frame_count`, and add a new `"walk"` `CreatureAnimationClip`
   (`frame_count=4`, `loop=true`) alongside the existing `idle` clip.
   `MonsterSwarmRenderer3D` reads this at runtime (Epic 16 Story 6+) — not any
   legacy per-monster companion node, which is fully retired for this tier.
