# Art Generation Request — Rift Sentinel Glide Cycle (2026-08-29)

This file is meant to be uploaded directly into an image generator. Generate the
image, save it, and drop it into `assets/source/monsters/` as
`rift_sentinel_boss_glide.png` — Claude will handle slicing, alpha-cutting,
and wiring it into the game from there (see `design/art/animation-pipeline.md`).
Per that doc's own guidance, BOSS-tier is the one tier where richer motion is
explicitly justified (112px presentation).

**Note — this is a "glide," not a "walk"**: per this creature's own design
(a construct/guardian, "angular and constructed rather than organic"), its
locomotion should read as a slow hover/float with its orbiting rune-ring
rotating, not a leg-based gait. If a walking motion is truly unavoidable given
the reference art's silhouette, keep any leg movement minimal and grinding
(stone-on-stone), never a light or organic stride.

## Reference (must match — this monster already has shipped static art)

`rift_sentinel_boss.png` already exists in `assets/art/monsters/` and is the
game's current idle/spawn pose for this monster. **Known alpha-cut gotcha
carried over from the static art**: this creature's obsidian body reads
nearly identical to the background color by design and needed a much tighter
threshold than usual to cut cleanly — expect the same when slicing this sheet.
The glide cycle must be the **same creature, same materials, same silhouette
rules** — this is a new pose set for an existing asset, not a redesign.

Original prompt (for reference, do not resend — describes the creature only):
> Isometric fantasy game monster asset, "Rift Sentinel" boss, single creature
> centered on a plain dark background for easy cutout. A tall, imposing
> construct/guardian entity, deliberately oversized. One dominant mass (a
> towering armored torso built from dark stone or obsidian-like material,
> fused with glowing cracked seams) plus one secondary accent (a floating or
> orbiting secondary element — a rune-etched ring or shard). Cracked-seam glow
> should be a cool blue-white or amber-gold — explicitly NOT purple, NOT cyan.
> Dark grey/black stone body, angular and "constructed" rather than organic.
> Painterly pixel-art, hand-painted miniature diorama style, fixed oblique
> isometric angle.

## Sheet Specification

- **4 frames**, one full slow hover/glide cycle, side-on to the same fixed
  oblique isometric angle as the reference art.
- **Single horizontal strip**, frames left to right, in gait order (frame 1
  loops back into frame 1). The orbiting rune-ring must visibly progress
  around its orbit across the 4 frames (not stay static), reinforcing motion
  even though the main body barely displaces.
- **Each frame must be the same fixed square canvas size** (e.g. 768×768,
  matching this boss's larger on-screen presentation) with the creature's
  silhouette consistently scaled and vertically anchored (ground-contact/
  hover-height point at the same Y position in every frame).
- **Plain dark/black background**, identical across all 4 frames.
- No baked-in motion blur, speed lines, or ground shadow.

## Prompt to send

```
Isometric fantasy game monster sprite sheet, 4-frame slow hover/glide cycle,
"Rift Sentinel" boss — same creature as this reference: tall imposing
construct/guardian, dark grey/black obsidian-like stone body, angular and
constructed (not organic), one dominant mass (towering armored torso with
glowing cracked seams in cool blue-white or amber-gold, NOT purple, NOT cyan),
one orbiting rune-etched ring or shard as a secondary floating element.
Painterly pixel-art, hand-painted miniature diorama style, fixed oblique
isometric angle — identical camera angle in all 4 frames.

Lay out exactly 4 frames left to right in a single horizontal strip, each
frame an identical fixed square canvas, plain dark/black background in every
frame. The main body should barely displace between frames (a slow,
deliberate hover, not a walking stride) — the sense of motion comes primarily
from the orbiting rune-ring/shard visibly progressing around its orbit path
across the 4 frames, plus a subtle rise-and-fall bob in the body's hover
height: (1) body at hover-height low point, ring at orbit position A, (2)
body rising slightly, ring at orbit position B (90 degrees further around),
(3) body at hover-height high point, ring at orbit position C (180 degrees
from A), (4) body descending, ring at orbit position D (270 degrees from A),
cycling back into frame 1. Keep the creature's scale, silhouette proportions,
and the seam-glow color identical across all 4 frames. No motion blur, no
speed lines, no ground shadow baked in.

Avoid pure blood-red, purple, or cyan anywhere — this is NOT the
purple-tinted boss-ambient-VFX moment, just the creature's own base design.
```

## After generation

1. Drop the raw sheet into `assets/source/monsters/rift_sentinel_boss_glide.png`.
2. Claude slices the 4 frames into individual frames under
   `assets/art/monsters/`, using the same tight-threshold/connected-component
   technique the static art already required for this creature's near-black
   body.
3. Combine into a single atlas texture (idle + glide frames), then update
   `assets/data/creature_atlases/rift_sentinel_boss.tres` — repoint
   `atlas_texture` at the new combined atlas, update `atlas_columns`/
   `frame_count`, and add a new `"walk"` `CreatureAnimationClip` (reusing the
   standard clip name for engine-side consistency even though the visual
   motion is a glide — `frame_count=4`, `loop=true`) alongside the existing
   `idle` clip. Confirm `presentation_class` stays `exceptional` with
   `approved_presenter_class = &"BossCreaturePresenter3D"`.
