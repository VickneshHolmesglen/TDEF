# Scattered Decorative Props — Generation Batch, 2026-08-15 (8 icons)

Standalone, upload-ready prompt batch for ChatGPT (or another image generator) —
meant to be handed over directly. Companion to `assets/art-generation-
requests-2026-08-15-mission-terrain.md` (same player request: "I want the
environment to have some flavour"). These are small, non-blocking decorative
props scattered across buildable (Placeable) ground for visual variety —
purely cosmetic, never interactable, never blocking tower placement or
pathfinding.

## Scope — 2 prop variants per mission, 4 missions (8 total)

Same biome identity as the terrain batch:

| Mission | Props |
|---|---|
| The Gap | Loose rock rubble, cracked stone shard cluster |
| The Foothills | Dried grass tuft, small warm-toned shrub clump |
| The Hollow | Small crystal shard cluster, tangled root growth |
| The Narrows | Smooth river stone cluster, dried reed cluster |

## Pipeline — same alpha-cut cutout process as materials icons

**Different from the terrain batch** (which is opaque full-bleed ground
texture): these are cutout icons, same pipeline as the materials-icon batch
(`assets/art-generation-requests-2026-08-06-materials.md`) — single object
centered on a flat pure black (`#000000`) background for easy alpha-cut
extraction, small enough to read clearly when scattered at roughly
quarter-cell size in-game (they decorate a cell, they don't fill it).

**Shared constraints for all 8** (same reserved-color rules as the terrain
batch): no green anywhere (Foothills' foliage renders warm golden-amber-
brown, never naturalistic green), no purple anywhere (Hollow's crystals use
Scout Blue `#2D5F8A`, never purple), no cyan (Scout Blue only for any blue),
no red. Hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art. No text, no numerals, no border, no frame baked in.

---

## The Gap

### 1. Loose Rock Rubble

```
Single object icon: a small scattered cluster of 3-4 loose angular rock
fragments of varying size, centered on a flat pure black (#000000)
background for easy cutout. No text, no numerals, no border, no frame.
Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant rock tone,
parchment cream (#F5EDCB) as small highlights on the flattest facets only.
No Sanctum Amber, no purple, no green, no cyan, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

### 2. Cracked Stone Shard Cluster

```
Single object icon: 2-3 tall thin cracked stone shards jutting up at
slightly different angles, centered on a flat pure black (#000000)
background for easy cutout. No text, no numerals, no border, no frame.
Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant tone, warm
amber-brown undertone, parchment cream (#F5EDCB) highlight along one
cracked edge. No Sanctum Amber wash, no purple, no green, no cyan, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

## The Foothills

### 3. Dried Grass Tuft

```
Single object icon: a small tuft of dried, sun-bleached grass blades
bending gently, centered on a flat pure black (#000000) background for
easy cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: warm golden-amber as the dominant dried-grass tone,
parchment cream (#F5EDCB) highlight on the driest blade tips only. No
green anywhere -- this renders as warm golden-amber-brown, not naturalistic
green. No purple, no cyan, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

### 4. Warm-Toned Shrub Clump

```
Single object icon: a small rounded shrub clump with a few tangled
twiggy branches, centered on a flat pure black (#000000) background for
easy cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: warm golden-amber-brown as the dominant tone, muted
fieldstone grey (#7E8590) for the twig structure beneath, parchment cream
(#F5EDCB) sparing highlight. No green anywhere. No purple, no cyan, no
red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

## The Hollow

### 5. Small Crystal Shard Cluster

```
Single object icon: a small cluster of 3-4 jagged crystal shards of
varying height jutting up together, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border, no
frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the crystal's base rock
tone, Scout Blue (#2D5F8A) as the crystal's own inner glow/color, parchment
cream (#F5EDCB) as a bright highlight at each shard's tip only. No purple
anywhere (this project reserves purple exclusively for boss encounters --
use Scout Blue for any "magical crystal" glow instead). No green, no
Sanctum Amber, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

### 6. Tangled Root Growth

```
Single object icon: a small tangle of pale, gnarled roots emerging from
the ground and curling together, centered on a flat pure black (#000000)
background for easy cutout. No text, no numerals, no border, no frame.
Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) and parchment cream
(#F5EDCB) as the dominant pale-root tones, no other color needed. No
purple, no green, no cyan, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

## The Narrows

### 7. Smooth River Stone Cluster

```
Single object icon: a small cluster of 3-4 smooth, rounded river stones
stacked and leaning together, centered on a flat pure black (#000000)
background for easy cutout. No text, no numerals, no border, no frame.
Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) with a cool undertone as
the dominant stone tone, parchment cream (#F5EDCB) highlight on the
smoothest, most sun-bleached stone only, a small sparing touch of Scout
Blue (#2D5F8A) in the shadowed gap between stones. No purple, no green,
no cyan (Scout Blue only), no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

### 8. Dried Reed Cluster

```
Single object icon: a small cluster of 3-4 tall thin dried reed stalks
with slightly drooping tips, centered on a flat pure black (#000000)
background for easy cutout. No text, no numerals, no border, no frame.
Compact, simple silhouette readable at small size.

Color palette: warm golden-amber-brown as the dominant dried-reed tone
(NOT green, even though reeds are naturally green -- this project reserves
green exclusively for heal-only VFX), parchment cream (#F5EDCB) highlight
on the driest tips only. No purple, no cyan, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

---

## After generation

1. Drop the resulting image(s) into `assets/source/props/` (create the
   folder if it doesn't exist). Name files `[mission_id]_[prop_name].png`
   if generating one at a time.
2. Claude alpha-cuts each (color-distance threshold, since backgrounds are
   pure black with no skin-tone/warm-content conflict risk), spot-checks
   against a bright backdrop, and archives to `assets/art/props/`.
3. Wire into `grid_visual.gd` (or a new sibling scatter layer): baked into
   the same single-Image grid texture as the terrain tiles (TD-render-001's
   established "one Image, zero per-frame draw calls" pattern) — a random
   subset of each mission's Placeable cells (roughly 15-20% density) get
   one prop stamped on top at generation time, using a seeded/injectable
   RNG for testability, matching MapGenerator's own convention. Props
   never render on PATH, SPAWN, GOAL, or BLOCKED cells, and never block
   tower placement (purely a texture blit, no gameplay-logic changes to
   Grid/GridConfig at all).
4. Live-verify via Godot MCP against each of the 4 real missions
   (confirm props are visible but don't obscure tower-placement
   readability), run the grid/mission-scene test suite, full regression,
   commit.
