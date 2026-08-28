# Art Generation Request — Forest Troll Walk Cycle (2026-08-29)

This file is meant to be uploaded directly into an image generator. Generate the
image, save it, and drop it into `assets/source/monsters/` as
`forest_troll_elite_walk.png` — Claude will handle slicing, alpha-cutting, and
wiring it into the game from there (see `design/art/animation-pipeline.md`).

## Reference (must match — this monster already has shipped static art)

`forest_troll_elite.png` already exists in `assets/art/monsters/` and is the
game's current idle/spawn pose for this monster. The walk cycle must be the
**same creature, same materials, same silhouette rules** — this is a new pose
set for an existing asset, not a redesign.

Original prompt (for reference, do not resend — describes the creature only):
> Isometric fantasy game monster asset, "Forest Troll", single creature
> centered on a plain dark background for easy cutout. A tall, moss-and-bark
> covered troll, roughly as wide as it is tall. Exactly ONE asymmetric
> protrusion breaking its own silhouette bounding box — a single oversized
> gnarled arm/claw held out to one side, larger and higher than the rest of
> the body, visibly off-balance and asymmetric (not a mirrored pair of arms).
> Organic, irregular, "grown not built" shape family — no straight edges, no
> right angles. Muted moss-green and bark-brown palette (approved green-skin
> exception, keep it desaturated/mossy, not a bright saturated "heal" green).
> One specular highlight on a wet bark surface. Painterly pixel-art,
> hand-painted miniature diorama style, fixed oblique isometric angle. Avoid
> pure blood-red, purple, or cyan anywhere.

## Sheet Specification

- **4 frames**, one full lumbering walk-cycle loop, side-on to the same fixed
  oblique isometric angle as the reference art (camera angle never changes
  between frames).
- **Single horizontal strip**, frames left to right, in gait order (frame 1
  loops back into frame 1).
- **Each frame must be the same fixed square canvas size** (e.g. 512×512) with
  the creature's silhouette consistently scaled and vertically anchored
  (ground-contact point at the same Y position in every frame). The oversized
  gnarled arm must stay on the SAME side of the body in every frame — do not
  let generation flip it left/right between frames.
- **Plain dark/black background**, identical across all 4 frames.
- No baked-in motion blur, speed lines, or ground shadow.

## Prompt to send

```
Isometric fantasy game monster sprite sheet, 4-frame lumbering walk cycle,
"Forest Troll" — same creature as this reference: tall, moss-and-bark covered
troll, roughly as wide as tall, one oversized gnarled arm/claw held out to
ONE side (larger and higher than the rest of the body, visibly asymmetric —
keep this arm on the same side of the body in every single frame, do not
mirror or flip it), muted moss-green and bark-brown palette, one specular
highlight on wet bark. Organic, irregular, "grown not built" shape family, no
straight edges. Painterly pixel-art, hand-painted miniature diorama style,
fixed oblique isometric angle — identical camera angle in all 4 frames.

Lay out exactly 4 frames left to right in a single horizontal strip, each
frame an identical fixed square canvas, plain dark/black background in every
frame. Frames show a heavy, lumbering gait cycle in order: (1) contact —
leading leg planted, the oversized arm trailing low near the ground, (2)
passing — body rising and shifting weight forward, the oversized arm swinging
slightly, (3) contact — opposite leg planted, the oversized arm trailing low
again, (4) passing — body rising, arm swinging, cycling back into frame 1.
This should read as heavy and unhurried, favoring the side the big arm is on.
Keep the creature's scale, silhouette proportions, and ground-contact height
identical across all 4 frames. No motion blur, no speed lines, no ground
shadow baked in.

Avoid pure blood-red, purple, or cyan anywhere in the art.
```

## After generation

1. Drop the raw sheet into `assets/source/monsters/forest_troll_elite_walk.png`.
2. Claude slices the 4 frames (uniform grid, same alpha-cut technique as every
   other monster) into individual frames under `assets/art/monsters/`.
3. Combine into a single atlas texture (idle + walk frames), then update
   `assets/data/creature_atlases/forest_troll_elite.tres` — repoint
   `atlas_texture` at the new combined atlas, update `atlas_columns`/
   `frame_count`, and add a new `"walk"` `CreatureAnimationClip`
   (`frame_count=4`, `loop=true`) alongside the existing `idle` clip.
   `MonsterSwarmRenderer3D` reads this at runtime (Epic 16 Story 6+) — not any
   legacy per-monster companion node, which is fully retired for this tier.
