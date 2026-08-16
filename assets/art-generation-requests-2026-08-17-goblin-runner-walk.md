# Art Generation Request — Goblin Runner Walk Cycle (2026-08-17)

This file is meant to be uploaded directly into ChatGPT (or pasted as a single
prompt). Generate the image, save it, and drop it into `assets/source/monsters/`
as `goblin_runner_walk.png` — Claude will handle slicing, alpha-cutting, and
wiring it into the game from there (Art & Animation Pipeline Upgrade vertical
slice — see `design/art/animation-pipeline.md`).

**This is the project's first sprite-sheet (multi-frame) generation request.**
Everything before this was a single static image. Read the sheet spec below
carefully — a sheet that doesn't match it (uneven frame sizes, inconsistent
pose scale/position between frames) will need to be regenerated, since
automated slicing depends on the frames being deterministic.

## Reference (must match — this monster already has shipped static art)

`goblin_runner.png` already exists in `assets/art/monsters/` and is the game's
current idle/spawn pose for this monster. The walk cycle must be the **same
creature, same materials, same silhouette rules** — this is a new pose set for
an existing asset, not a redesign.

Original prompt (for reference, do not resend — describes the creature only):
> Isometric fantasy game monster asset, "Goblin Runner", single creature
> centered on a plain dark background for easy cutout. Small, wiry
> green-skinned goblin in light leather scraps, crouched low and lunging
> forward mid-sprint — built for speed, not toughness. Silhouette must be
> wider than it is tall, no part of the body rising above its own shoulder
> line, clean simple outline with no spikes or protrusions. One weapon (a
> small curved dagger) held low. One accent color zone only (worn red-brown
> leather straps) plus one specular highlight on exposed skin — no other
> surface detail. Painterly pixel-art, hand-painted miniature diorama style,
> fixed oblique isometric angle. Avoid pure blood-red, purple, or cyan
> anywhere. The creature's own skin can be green (muted olive-green, not a
> saturated "heal" green).

## Sheet Specification

- **4 frames**, one full walk-cycle loop (contact — passing — contact —
  passing), side-on to the same fixed oblique isometric angle as the
  reference art (camera angle never changes between frames).
- **Single horizontal strip**, frames left to right, in gait order (frame 1
  loops back into frame 1 — this must read as a continuous cycle, not a
  start/stop sequence).
- **Each frame must be the same fixed square canvas size** (e.g. 512×512) with
  the creature's silhouette consistently scaled and vertically anchored
  (feet/ground-contact point at the same Y position in every frame) — this is
  the single most important requirement for automated slicing to work
  cleanly. Do not let the creature grow, shrink, or drift between frames.
- **Plain dark/black background**, identical across all 4 frames, for the
  same color-distance alpha-cut technique already used on every other asset
  in this project.
- No baked-in motion blur, speed lines, or ground shadow — those are handled
  separately by this project's own rendering (Sprite2D scale/positioning,
  procedural shadow where applicable).

## Prompt to send

```
Isometric fantasy game monster sprite sheet, 4-frame walk cycle, "Goblin
Runner" — same creature as this reference: small, wiry green-skinned goblin
in light leather scraps, one small curved dagger held low, one accent color
zone (worn red-brown leather straps), one specular highlight on exposed skin,
muted olive-green skin (not saturated green), no other surface detail.
Silhouette wider than tall, no part of the body rising above its own shoulder
line, clean simple outline, no spikes or protrusions. Painterly pixel-art,
hand-painted miniature diorama style, fixed oblique isometric angle —
identical camera angle in all 4 frames.

Lay out exactly 4 frames left to right in a single horizontal strip, each
frame an identical fixed square canvas, plain dark/black background in every
frame. Frames show a continuous running-sprint gait cycle in order: (1)
contact — leading foot planted, low crouch, (2) passing — body mid-stride,
weight rising, (3) contact — opposite foot planted, low crouch, (4) passing —
body mid-stride, weight rising, cycling back into frame 1. Keep the
creature's scale and ground-contact height identical across all 4 frames — do
not let it grow, shrink, or shift vertically between frames. No motion blur,
no speed lines, no ground shadow baked in.

Avoid pure blood-red, purple, or cyan anywhere in the art.
```

## After generation

1. Drop the raw sheet into `assets/source/monsters/goblin_runner_walk.png`.
2. Claude slices the 4 frames (uniform grid, same alpha-cut technique as
   every other monster) into individual frames or a `SpriteFrames` resource
   under `assets/art/monsters/`.
3. Wired into `MonsterInstance` as a new `"move"` animation (per
   `design/art/animation-pipeline.md`'s naming convention), used only while
   `goblin_runner` is actively pathing — this is the vertical slice's one
   frame-animation asset; no other monster gets this treatment yet.
