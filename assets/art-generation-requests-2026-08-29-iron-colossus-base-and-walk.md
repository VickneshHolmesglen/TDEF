# Art Generation Request — Iron Colossus Base Pose + Walk Cycle (2026-08-29)

This file is meant to be uploaded directly into an image generator. **Unlike
every other item in this batch, this creature has NO shipped art at all yet**
(`assets/data/monsters/iron_colossus_elite.tres` exists in game data — stats,
waves, drop tables all real — but the art pipeline has never generated
anything for it; `production/art-overhaul-status.md` has tracked this as
blocked). This request covers both the missing base/idle pose AND its walk
cycle in one batch, so the two stay visually consistent from the start rather
than needing a second "match this existing art" pass later.

## Creature Brief

- **Tier**: Elite (`archetype_tag = "armored"`) — Elite shape rule applies:
  roughly 1:1 height:width, with exactly ONE asymmetric feature (a horn,
  blade, or oversized limb/weapon) that visibly breaks the silhouette's own
  bounding box. Symmetry reads as Standard tier — asymmetry is what signals
  Elite.
- **Stats context** (informs the design, do not render text/numbers):
  `base_hp = 320` (tanky — highest HP of any non-boss monster), `base_speed
  = 0.8` (the slowest monster in the game, even slower than Armored Brute's
  0.9) — this should read as an implacable, heavy, slow-grinding threat, not
  a fast or agile one.
- **Name**: "Iron Colossus" — lean into scale and metal mass. This is the
  `armored` archetype's most extreme expression (Armored Brute is this
  creature's Standard-tier sibling in theme, not literally related) — reuse
  that family's "mass reads through bulk, riveted/crude plate construction"
  visual language, scaled up and made more elaborate for Elite tier, plus one
  clear asymmetric feature Armored Brute doesn't have.

## Part 1 — Base/Idle Pose (single static image)

```
Isometric fantasy game monster asset, "Iron Colossus", single creature
centered on a plain dark background for easy cutout. A hulking, heavily-built
armored elite, roughly 1:1 height-to-width, built from thick riveted iron
plate with a crude, hammered/forged construction (not sleek or ornate — this
is brute industrial armor, not knightly finery). Exactly ONE asymmetric
protrusion breaking its own silhouette bounding box — one massively oversized
iron gauntlet/fist or a huge integrated hammer-arm, larger and higher than
the rest of the body, visibly off-balance and asymmetric (not a mirrored pair
of arms). Low, wide, implacable stance suggesting extreme weight and slow
inevitability rather than agility. One accent color zone (dull rust-orange or
worn bronze rivets/trim, matching this project's existing "armored" family
palette) plus one specular highlight on a large metal plate. Painterly
pixel-art, hand-painted miniature diorama style, fixed oblique isometric
angle. Avoid pure blood-red, purple, or cyan anywhere.
```

## Part 2 — Walk Cycle (4-frame sprite sheet, must match Part 1)

**Sheet Specification:**
- **4 frames**, one full slow, heavy, grinding walk-cycle loop, side-on to the
  same fixed oblique isometric angle as Part 1's base pose.
- **Single horizontal strip**, frames left to right, in gait order (frame 1
  loops back into frame 1). The oversized gauntlet/hammer-arm must stay on
  the SAME side of the body in every frame, matching Part 1.
- **Each frame must be the same fixed square canvas size** (e.g. 512×512) with
  the creature's silhouette consistently scaled and vertically anchored
  (ground-contact point at the same Y position in every frame) — and must
  match Part 1's own proportions and materials exactly.
- **Plain dark/black background**, identical across all 4 frames.
- No baked-in motion blur, speed lines, or ground shadow.

**Prompt to send** (run after Part 1 is approved, referencing it directly):
```
Isometric fantasy game monster sprite sheet, 4-frame slow heavy grinding walk
cycle, "Iron Colossus" — same creature as the reference base pose: hulking
armored elite, thick riveted crude iron plate, one massively oversized iron
gauntlet/hammer-arm held on ONE side (keep it on the same side of the body in
every frame, do not mirror or flip it), dull rust-orange/worn bronze rivets
as the one accent zone, one specular highlight on a large metal plate.
Painterly pixel-art, hand-painted miniature diorama style, fixed oblique
isometric angle — identical camera angle in all 4 frames.

Lay out exactly 4 frames left to right in a single horizontal strip, each
frame an identical fixed square canvas, plain dark/black background in every
frame. Frames show an extremely slow, heavy, grinding gait cycle in order:
(1) contact — leading foot planted with immense weight, oversized arm
trailing low, (2) passing — body barely rising, weight shifting through a
wide low stance, (3) contact — opposite foot planted with immense weight,
arm trailing low again, (4) passing — body barely rising, cycling back into
frame 1. This should read as the slowest, heaviest gait of any creature in
this batch — implacable, not agile. Keep the creature's scale, silhouette
proportions, and ground-contact height identical across all 4 frames and
consistent with the base pose. No motion blur, no speed lines, no ground
shadow baked in.

Avoid pure blood-red, purple, or cyan anywhere in the art.
```

## After generation

1. Drop Part 1's output into `assets/source/monsters/iron_colossus_elite.png`,
   Part 2's output into `assets/source/monsters/iron_colossus_elite_walk.png`.
2. Claude slices both (standard color-distance alpha-cut, spot-checking the
   darkest armor shadow against a bright backdrop first per this project's
   own "never assume last time's threshold works" rule) into
   `assets/art/monsters/`.
3. **This creature has no `CreatureAtlasMappingResource` at all yet** —
   unlike every other item in this batch, this is a net-new file, not an
   update. Create `assets/data/creature_atlases/iron_colossus_elite.tres`
   from scratch, mirroring `armored_brute.tres`'s structure: `creature_id =
   &"iron_colossus_elite"`, real `atlas_texture`/`atlas_columns`/
   `frame_count`, an `"idle"` clip (1 frame) and a `"walk"` clip (4 frames,
   `loop=true`). `presentation_class` should be `standard` (Elite tier still
   uses the batched swarm path — only Boss tier uses `exceptional`, per
   `ADR-0038` and this project's existing Elite-tier atlas mappings, e.g.
   `forest_troll_elite.tres`/`bog_lurker_elite.tres`, both `standard`).
4. Run `GameDataRegistry`'s boot validation (or the equivalent unit test) to
   confirm the new resource loads and validates cleanly — this is the one
   item in this batch that's genuinely new content, not an update to an
   already-validated resource, so it deserves that extra check.
