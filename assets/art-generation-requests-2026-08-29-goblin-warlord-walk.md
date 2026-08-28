# Art Generation Request — Goblin Warlord Walk Cycle (2026-08-29)

This file is meant to be uploaded directly into an image generator. Generate the
image, save it, and drop it into `assets/source/monsters/` as
`goblin_warlord_boss_walk.png` — Claude will handle slicing, alpha-cutting,
and wiring it into the game from there (see `design/art/animation-pipeline.md`).
Per that doc's own guidance, BOSS-tier is the one tier where richer motion is
explicitly justified (112px presentation), so this sheet can afford a bit more
weight/flourish than the standard-tier walk cycles in this same batch.

## Reference (must match — this monster already has shipped static art)

`goblin_warlord_boss.png` already exists in `assets/art/monsters/` and is the
game's current idle/spawn pose for this monster. The walk cycle must be the
**same creature, same materials, same silhouette rules** — this is a new pose
set for an existing asset, not a redesign.

Original prompt (for reference, do not resend — describes the creature only):
> Isometric fantasy game monster asset, "Goblin Warlord" boss, single creature
> centered on a plain dark background for easy cutout. A massive goblin
> chieftain, deliberately oversized relative to a normal goblin — reads as
> "too large to be a standard enemy" instantly. Heavy ornate armor assembled
> from scavenged/mismatched plates, one dominant mass (a huge armored
> torso/gut) plus one secondary accent (a large banner or standard mounted on
> its back). One held ranged weapon (a crude thrown spear or hooked javelin).
> Dull green skin (approved exception, muted/desaturated), dark leather and
> scavenged bronze/iron armor. Painterly pixel-art, hand-painted miniature
> diorama style, fixed oblique isometric angle. Avoid pure blood-red, purple,
> or cyan anywhere.

## Sheet Specification

- **4 frames**, one full heavy ponderous march cycle, side-on to the same
  fixed oblique isometric angle as the reference art.
- **Single horizontal strip**, frames left to right, in gait order (frame 1
  loops back into frame 1). The back-mounted banner and held spear/javelin
  must stay on their same respective sides/positions in every frame.
- **Each frame must be the same fixed square canvas size** (e.g. 768×768 —
  larger than the standard-tier sheets in this batch, matching this boss's
  own larger on-screen presentation) with the creature's silhouette
  consistently scaled and vertically anchored (ground-contact point at the
  same Y position in every frame).
- **Plain dark/black background**, identical across all 4 frames.
- No baked-in motion blur, speed lines, or ground shadow.

## Prompt to send

```
Isometric fantasy game monster sprite sheet, 4-frame heavy ponderous march
cycle, "Goblin Warlord" boss — same creature as this reference: massive
oversized goblin chieftain, heavy ornate armor from scavenged/mismatched
plates, one dominant mass (huge armored torso/gut), a large banner/standard
mounted on its back swaying with each step, one held ranged weapon (crude
thrown spear or hooked javelin), dull green skin (muted/desaturated), dark
leather and scavenged bronze/iron armor. Painterly pixel-art, hand-painted
miniature diorama style, fixed oblique isometric angle — identical camera
angle in all 4 frames.

Lay out exactly 4 frames left to right in a single horizontal strip, each
frame an identical fixed square canvas, plain dark/black background in every
frame. Frames show a slow, heavy, commanding march cycle in order: (1)
contact — leading foot planted with full weight, banner swaying back, (2)
passing — body rising, torso mass shifting, banner swaying forward, (3)
contact — opposite foot planted with full weight, banner swaying back again,
(4) passing — body rising, banner swaying forward, cycling back into frame 1.
This should read as slow, heavy, and commanding — never a sprint. Keep the
creature's scale, silhouette proportions, and ground-contact height identical
across all 4 frames. No motion blur, no speed lines, no ground shadow baked
in.

Avoid pure blood-red, purple, or cyan anywhere — this is NOT the
purple-tinted boss-ambient-VFX moment, just the creature's own base design.
```

## After generation

1. Drop the raw sheet into `assets/source/monsters/goblin_warlord_boss_walk.png`.
2. Claude slices the 4 frames into individual frames under
   `assets/art/monsters/` (standard color-distance alpha-cut, unless the
   sheet needs the connected-component technique — spot-check the darkest
   armor shadow against a bright backdrop before trusting a simple threshold).
3. Combine into a single atlas texture (idle + walk frames), then update
   `assets/data/creature_atlases/goblin_warlord_boss.tres` — repoint
   `atlas_texture` at the new combined atlas, update `atlas_columns`/
   `frame_count`, and add a new `"walk"` `CreatureAnimationClip`
   (`frame_count=4`, `loop=true`) alongside the existing `idle` clip. Confirm
   `presentation_class` stays `exceptional` with the correct
   `approved_presenter_class` (`BossCreaturePresenter3D`) — boss-tier creatures
   don't share the batched swarm `MultiMesh` path the standard-tier walk
   cycles in this batch do.
