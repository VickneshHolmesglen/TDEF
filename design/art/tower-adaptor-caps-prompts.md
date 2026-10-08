# Tower Adaptor Caps — Codex Generation Prompts

**Created**: 2026-10-09 (Claude Code)
**Tracker**: `production/art-overhaul-status.md` → Backlog → "Tower adaptor caps" batch (one row per shape)
**Bound by**: `design/art/codex-art-overhaul.md` (division of labour §3, alpha-cut §5.2, naming §5.3, scale §5.5)
**Code**: `TowerInstance.with_adaptor_caps()` / `stack_layers()` (`src/core/tower/tower_instance.gd`)

## 0. Why these exist

A tower is three stacked pieces: Base, Shaft and Top. Each comes in 9 shape families:
round, square, octagon, hexplank, triangle, tiered, scalloped, stump and stonemound. In the
Inventory tower preview the player can mix any Top with any Shaft and any Shaft with any
Base. Pieces of the same family fit perfectly. Mixed families are joined, but the outlines
disagree (a square shaft standing on a round base's top face, a top balanced on the triangle
shaft's tiny apex). See `production/qa/evidence/tower-combos-2026-10-09/` for every
combination.

The fix (player decision 2026-10-09) is **one adaptor cap per shape family**. A cap
sits on top of a piece of its own family, matches that piece's top-face outline exactly, and
ends in a **standard round socket**. Every upper piece of any family then stands on that same
socket. The game inserts a cap **only where two different families meet**. Matched towers
are unchanged.

```
  any Top / any Shaft
  ───(standard round socket)───   <- identical on all 9 caps
  [ cap_<shape> ]                 <- outline matches <shape>'s top face
  [ <shape> Base or Shaft ]
```

**9 images total.** The same cap is used on both Bases and Shafts of its family; the game
scales it to the piece underneath it.

## 1. Shared rules (apply to every prompt)

- **Medium and style**: match the existing tower pieces exactly. Stylised fantasy, painted
  3D-look, dark grey dressed stone with bronze or brass banding and rivets, warm wood where
  the family uses it. Soft key light from the upper left.
- **Camera**: the same three-quarter view as the existing pieces, about 35° down,
  facing front. The cap's outline must line up with the reference piece's top face, so do not
  change the angle.
- **Reference image**: generate each cap **as an edit/continuation of its family's shaft
  image** (`assets/art/towers/tower_shaft_<shape>.png`). The cap must sit on that
  shaft's top face: its bottom edge follows the top face's outline and covers it completely, with the
  same width. Then output **the cap alone** on the background below. Do not include the shaft.
- **Standard socket**: the top of every cap is the same round socket. It is a raised
  circular stone ring with a single bronze band, about **70% of the cap's width** in
  diameter, with a flat circular stone top face. Generate `round` first and use it as the
  socket reference for the other 8, so all 9 sockets have the same proportions, banding and
  height relative to their cap's width.
- **Height**: low and squat. From the bottom edge to the socket top, about **35–45% of the
  cap's width**. It is a transition piece, not a new storey.
- **Background**: a flat, solid `#FF00FF` magenta background. That is a standalone
  instruction: no gradient, vignette, ground or shadow plane.
- **No text**: no text, letters, frame or border. That is a standalone sentence.
- **Canvas**: 1024×1024, cap centred and filling about 80% of the width.

Template (prepend to each shape prompt below):

> Stylised fantasy painted 3D-look tower part, three-quarter view about 35° down, soft
> light from the upper left, dark grey dressed stone with bronze bands and rivets, matching
> the reference tower shaft. A low adaptor cap: {SHAPE PROMPT}. It rises to a raised round
> stone socket with one bronze band, about 70% of the cap's width, with a flat circular top.
> Cap only, centred on a flat solid #FF00FF magenta background. No text, no letters, no
> frame, no border.

## 2. Prompts

### 2.1 Round (`round`): generate first; it is the socket reference
> A circular stone lid that exactly covers the round shaft's top face, its edge a stone ring
> with a bronze band, stepping inward to the socket.

### 2.2 Square (`square`)
> A square stone lid with bronze corner brackets that exactly covers the square shaft's
> top face, its four sides chamfering inward to the round socket.

### 2.3 Octagon (`octagon`)
> An eight-sided stone lid with bronze edging that exactly covers the octagonal shaft's top
> face, its faceted rim stepping inward to the round socket.

### 2.4 Hexplank (`hexplank`)
> A hexagonal lid of dark wooden planks with a bronze-banded rim that closes the open
> hexagonal plank crate completely, like a crate lid, with the round stone socket set into its
> centre. Its outline matches the crate's hexagonal rim.

### 2.5 Triangle (`triangle`): the most important one
> A flared capital, like the head of a column. It starts as a small square collar that
> exactly fits the narrow apex plate of the tapered triangular pillar and flares outward
> and upward in stone with bronze ribs to a full-width round socket. The flare is what lets a
> wide top rest on the narrow pillar. Its bottom must be as narrow as the apex plate and its
> top as wide as the other caps' sockets.

### 2.6 Tiered (`tiered`)
> A round stepped stone lid, two shallow tiers, exactly covering the tiered shaft's round
> top face, stepping up to the round socket.

### 2.7 Scalloped (`scalloped`)
> A four-lobed (scalloped) stone lid with bronze trim that follows the scalloped shaft's
> lobed top-face outline exactly, rising to the round socket.

### 2.8 Stump (`stump`)
> A round wooden ring-lid bound with rope and bronze that closes the open timber-frame
> shaft's top ring, with the round stone socket set into its centre.

### 2.9 Stonemound (`stonemound`)
> A ring of rough fitted fieldstones that seats over the stonemound shaft's domed top,
> levelling it off into the round socket.

## 3. Hand-off

- **Codex**: drop raw output at `assets/source/towers/caps/tower_cap_<shape>_raw.png` and
  set the row to `generated, awaiting processing`.
- **Claude Code**: alpha-cut (colour-distance against magenta, §5.2), crop to the painted
  area, save `assets/art/towers/tower_cap_<shape>.png` with the tower import preset (lossless,
  size_limit 256), measure the cap's seat line (the socket's front rim) and add it to
  `TowerInstance.LAYER_SEAT_FRACTIONS`, then re-render
  `production/qa/evidence/tower-combos-2026-10-09/` with the cap in place. No other wiring is
  needed: `with_adaptor_caps()` picks up a cap as soon as its PNG exists.
