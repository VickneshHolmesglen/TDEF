# Art Generation Request — Bog Lurker Walk Cycle (2026-08-29)

This file is meant to be uploaded directly into an image generator. Generate the
image, save it, and drop it into `assets/source/monsters/` as
`bog_lurker_elite_walk.png` — Claude will handle slicing, alpha-cutting, and
wiring it into the game from there (see `design/art/animation-pipeline.md`).

## Reference (must match — this monster already has shipped static art)

`bog_lurker_elite.png` already exists in `assets/art/monsters/` and is the
game's current idle/spawn pose for this monster. The walk cycle must be the
**same creature, same materials, same silhouette rules** — this is a new pose
set for an existing asset, not a redesign. **Known alpha-cut gotcha carried
over from the static art**: this creature's dripping-slime tips are thin and
faded near the background color and needed the connected-component flood-fill
technique (not simple color-distance) to preserve — expect the same when
slicing this sheet.

Original prompt (for reference, do not resend — describes the creature only):
> Isometric fantasy game monster asset, "Bog Lurker", single creature centered
> on a plain dark background for easy cutout. A lean, amphibious ambush
> predator, roughly 1:1 height-to-width, low crouched stance suggesting a
> sudden lunge. Exactly ONE asymmetric protrusion breaking its own silhouette
> bounding box — one oversized clawed forelimb raised and extended to one
> side, clearly bigger/higher than its mirror limb (not symmetrical). Organic,
> irregular, "grown not built" shape family. Slick dark bog-green/grey hide
> (desaturated, murky) with pale bioluminescent throat markings as the one
> accent zone, one specular highlight on wet skin. Painterly pixel-art,
> hand-painted miniature diorama style, fixed oblique isometric angle. Avoid
> pure blood-red, purple, or cyan anywhere.

## Sheet Specification

- **4 frames**, one full low-crouched stalking cycle (not a sprint — this
  creature ambushes), side-on to the same fixed oblique isometric angle as
  the reference art.
- **Single horizontal strip**, frames left to right, in gait order (frame 1
  loops back into frame 1). The oversized clawed forelimb must stay on the
  SAME side of the body in every frame.
- **Each frame must be the same fixed square canvas size** (e.g. 512×512) with
  the creature's silhouette consistently scaled and vertically anchored
  (ground-contact point at the same Y position in every frame).
- **Plain dark/black background**, identical across all 4 frames.
- No baked-in motion blur, speed lines, or ground shadow.

## Prompt to send

```
Isometric fantasy game monster sprite sheet, 4-frame low crouched stalking
walk cycle, "Bog Lurker" — same creature as this reference: lean amphibious
ambush predator, roughly 1:1 height-to-width, one oversized clawed forelimb
extended to ONE side (keep it on the same side of the body in every frame, do
not mirror or flip it), slick dark bog-green/grey hide, pale bioluminescent
throat markings as the one accent zone, one specular highlight on wet skin.
Organic, irregular, "grown not built" shape family. Painterly pixel-art,
hand-painted miniature diorama style, fixed oblique isometric angle —
identical camera angle in all 4 frames.

Lay out exactly 4 frames left to right in a single horizontal strip, each
frame an identical fixed square canvas, plain dark/black background in every
frame. Frames show a low, tense stalking gait cycle in order: (1) contact —
leading leg planted, body kept low, oversized claw held forward and ready,
(2) passing — body sliding forward close to the ground, weight shifting, (3)
contact — opposite leg planted, body still low, claw still forward, (4)
passing — body sliding forward, cycling back into frame 1. This should read
as a predator stalking, not running upright — the body stays low and coiled
throughout. Keep the creature's scale, silhouette proportions, and
ground-contact height identical across all 4 frames. No motion blur, no speed
lines, no ground shadow baked in.

Avoid pure blood-red, purple, or cyan anywhere in the art.
```

## After generation

1. Drop the raw sheet into `assets/source/monsters/bog_lurker_elite_walk.png`.
2. Claude slices the 4 frames (connected-component flood-fill technique per
   the gotcha noted above, not simple color-distance) into individual frames
   under `assets/art/monsters/`.
3. Combine into a single atlas texture (idle + walk frames), then update
   `assets/data/creature_atlases/bog_lurker_elite.tres` — repoint
   `atlas_texture` at the new combined atlas, update `atlas_columns`/
   `frame_count`, and add a new `"walk"` `CreatureAnimationClip`
   (`frame_count=4`, `loop=true`) alongside the existing `idle` clip.
   `MonsterSwarmRenderer3D` reads this at runtime (Epic 16 Story 6+) — not any
   legacy per-monster companion node, which is fully retired for this tier.
