# Per-Mission Terrain Tiles — Generation Batch, 2026-08-15 (12 tiles)

Standalone, upload-ready prompt batch for ChatGPT (or another image generator) —
meant to be handed over directly. Player-requested ("I want the environment to
have some flavour"): every mission currently renders with the exact same 5
shared terrain tiles (`assets/art/terrain/`), regardless of which mission
you're playing. This batch gives each of the 4 missions its own themed ground.

## Scope — 3 tiles per mission, 4 missions (12 total)

**Placeable, Path, and Blocked** are reskinned per mission — the 3 tile types
that dominate visible ground and carry biome identity. **Spawn and Goal stay
shared/universal across all missions** (the rift crack and the gate archway
are functional landmarks — "an entry," "the exit" — not biome-specific; this
also keeps the art scope sane: 12 tiles instead of 20).

Biome identity for each mission matches its already-shipped Mission Select
card icon (`assets/art/ui/mission_card_*.png`) — same visual language, now
extended into the actual playable ground:

| Mission | Biome |
|---|---|
| The Gap | Rocky mountain-pass canyon |
| The Foothills | Rolling hills (dried/warm-toned grass, NOT green) |
| The Hollow | Cave / crystal grotto |
| The Narrows | River canyon |

## Same shared constraints as the original terrain batch (unchanged)

Opaque, full-bleed, no background/vignette/label/border baked in — the image
should be ONLY the ground texture itself, filling the entire square frame.
Request a seamlessly tileable/repeatable texture for Placeable and Blocked
(so adjacent same-type cells don't show an obvious seam). Path needs straight
parallel borders running top-to-bottom (NOT converging to a point — see the
2026-08-14 regeneration notes in `design/art/asset-generation-prompts.md` for
why that failed once already). Terrain renders at ~70% of normal saturation.
Hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art texture
with visible brushwork, viewed from a slight oblique top-down angle.

**Do not use green anywhere, even for The Foothills' grass** — green is
reserved exclusively for heal-only VFX game-wide. Foothills' "grass" renders
as warm dried/golden-amber foliage instead, same substitution this project
has used in every other foliage-adjacent asset (tarot's The World wreath,
etc.). **Do not use purple anywhere, even for The Hollow's crystals** —
purple is reserved exclusively for boss-encounter escalation. The Hollow's
crystal glow uses Scout Blue instead (same substitution already used on the
shared Spawn tile's rift glow). **Do not use cyan** — reserved UI-only. Scout
Blue is fine for world-space blue (Narrows' river, Hollow's crystal) since
it's the one blue already approved for world use.

**Do not use red.**

---

## The Gap (rocky mountain-pass canyon)

### 1. The Gap — Placeable

```
Seamlessly tileable top-down ground texture, square format, filling the
entire frame edge-to-edge with no border or vignette — packed dry canyon
dirt with scattered angular rock fragments and hairline cracks, viewed from
a slight oblique top-down angle. Buildable ground a player places towers on
-- keep the surface calm and uncluttered, no large rocks, no path markings.

Color palette: muted fieldstone grey (#7E8590) as the dominant dry-rock
tone, warm amber-brown undertone at roughly 70% of normal saturation.
Parchment cream (#F5EDCB) as small scattered highlights on the flattest
rock fragments only. No Sanctum Amber wash, no Herald Gold, no Scout Blue.
Absolutely no green, no purple, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

### 2. The Gap — Path

```
Seamlessly tileable top-down ground texture, square format, filling the
entire frame edge-to-edge with no border or vignette — a worn canyon-floor
path, flatter and more compacted than the buildable-ground tile, viewed
from a slight oblique top-down angle. A thin decorative stone edging
border running perfectly straight along the top and bottom edges only (so
adjacent path tiles form a continuous bordered lane when placed in a
column) -- the border must NOT curve or converge to a point anywhere in
the frame. Completely flat -- no raised elements, monsters walk across
this every wave.

Color palette: muted fieldstone grey (#7E8590) as the dominant worn-path
tone. Sanctum Amber (#C8801A) used only for the thin straight stone
path-border edging. Parchment cream (#F5EDCB) as a small highlight on the
amber edging only. No Herald Gold, no Scout Blue. Absolutely no green, no
purple, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

### 3. The Gap — Blocked

```
Seamlessly tileable top-down ground texture, square format, filling the
entire frame edge-to-edge with no border or vignette — dense, jagged
canyon-wall rock completely filling the tile, viewed from a slight oblique
top-down angle. Denser and darker than the buildable-ground tile, no flat
open space visible -- this ground cannot be built on or walked across. No
stone edging or path-border details.

Color palette: muted fieldstone grey (#7E8590) as the dominant raw-rock
tone, darkened noticeably below the buildable-ground tile's value, at
roughly 60-65% of normal saturation. Parchment cream (#F5EDCB) used
extremely sparingly as a few small specular highlights on the sharpest
rock edges. No Sanctum Amber, no Herald Gold, no Scout Blue. Absolutely no
green, no purple, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

---

## The Foothills (rolling hills, dried/warm-toned grass)

### 4. The Foothills — Placeable

```
Seamlessly tileable top-down ground texture, square format, filling the
entire frame edge-to-edge with no border or vignette — packed dry hillside
earth with sparse tufts of dried, sun-bleached grass (golden-amber, NOT
green), viewed from a slight oblique top-down angle. Buildable ground a
player places towers on -- keep the surface calm and uncluttered, no
large rocks, no path markings.

Color palette: warm golden-amber (#C8801A-adjacent, dried-grass tone) as
the dominant ground color at roughly 70% of normal saturation, muted
fieldstone grey (#7E8590) as a secondary earth tone, parchment cream
(#F5EDCB) as small highlights on the driest grass tips only. No Herald
Gold, no Scout Blue. Absolutely no green anywhere -- all vegetation renders
warm golden-amber-brown, not naturalistic green. No purple, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

### 5. The Foothills — Path

```
Seamlessly tileable top-down ground texture, square format, filling the
entire frame edge-to-edge with no border or vignette — a worn dirt trail
across a hillside, flatter and more compacted than the buildable-ground
tile, viewed from a slight oblique top-down angle. A thin decorative
stone edging border running perfectly straight along the top and bottom
edges only (so adjacent path tiles form a continuous bordered lane) -- the
border must NOT curve or converge to a point anywhere in the frame.
Completely flat -- no raised elements, monsters walk across this every
wave.

Color palette: warm golden-amber dried-earth tone as the dominant worn-path
color. Sanctum Amber (#C8801A) used only for the thin straight stone
path-border edging. Parchment cream (#F5EDCB) as a small highlight on the
amber edging only. No Herald Gold, no Scout Blue. Absolutely no green, no
purple, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

### 6. The Foothills — Blocked

```
Seamlessly tileable top-down ground texture, square format, filling the
entire frame edge-to-edge with no border or vignette — a dense thicket of
tangled dried brush and gnarled low shrubs completely filling the tile,
viewed from a slight oblique top-down angle. Denser and darker than the
buildable-ground tile, no flat open space visible -- this ground cannot be
built on or walked across.

Color palette: warm golden-amber-brown as the dominant dried-brush tone,
darkened noticeably below the buildable-ground tile's value, at roughly
60-65% of normal saturation. Muted fieldstone grey (#7E8590) for any
exposed stony ground beneath the brush. Parchment cream (#F5EDCB) used
extremely sparingly as highlights on the driest twig tips only. No Sanctum
Amber, no Herald Gold, no Scout Blue. Absolutely no green anywhere, no
purple, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

---

## The Hollow (cave / crystal grotto)

### 7. The Hollow — Placeable

```
Seamlessly tileable top-down ground texture, square format, filling the
entire frame edge-to-edge with no border or vignette — packed cave-floor
stone with a few small embedded crystal flecks glinting faintly, viewed
from a slight oblique top-down angle. Buildable ground a player places
towers on -- keep the surface calm and uncluttered, no large rocks, no
path markings.

Color palette: muted fieldstone grey (#7E8590) as the dominant cave-stone
tone at roughly 70% of normal saturation, with tiny sparing flecks of
Scout Blue (#2D5F8A) as embedded crystal glints (very small, scattered,
not a wash). Parchment cream (#F5EDCB) as small highlights on the
flattest stone only. No Sanctum Amber, no Herald Gold. Absolutely no
green, no purple (even though "crystal cave" often reads as purple in
other games -- this project reserves purple exclusively for boss
encounters, use Scout Blue instead), no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

### 8. The Hollow — Path

```
Seamlessly tileable top-down ground texture, square format, filling the
entire frame edge-to-edge with no border or vignette — a worn cave-floor
trail, flatter and more compacted than the buildable-ground tile, viewed
from a slight oblique top-down angle. A thin decorative stone edging
border running perfectly straight along the top and bottom edges only (so
adjacent path tiles form a continuous bordered lane) -- the border must
NOT curve or converge to a point anywhere in the frame. Completely flat --
no raised elements, monsters walk across this every wave.

Color palette: muted fieldstone grey (#7E8590) as the dominant worn-path
tone. Sanctum Amber (#C8801A) used only for the thin straight stone
path-border edging (warm torchlight-worked stone, distinct from the cool
crystal glints elsewhere in this mission). Parchment cream (#F5EDCB) as a
small highlight on the amber edging only. No Herald Gold, no Scout Blue
here (keep the crystal glow exclusive to Placeable/Blocked so the path
itself reads as the "worked/safe" surface). Absolutely no green, no
purple, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

### 9. The Hollow — Blocked

```
Seamlessly tileable top-down ground texture, square format, filling the
entire frame edge-to-edge with no border or vignette — a dense wall of
rough cave rock with larger embedded crystal clusters glowing faintly,
completely filling the tile, viewed from a slight oblique top-down angle.
Denser and darker than the buildable-ground tile, no flat open space
visible -- this ground cannot be built on or walked across.

Color palette: muted fieldstone grey (#7E8590) as the dominant raw-rock
tone, darkened noticeably below the buildable-ground tile's value, at
roughly 60-65% of normal saturation. Scout Blue (#2D5F8A) as the crystal
clusters' glow, more prominent here than on Placeable but still not a
wash -- distinct crystal shapes, not ambient lighting. Parchment cream
(#F5EDCB) used sparingly as specular highlights on crystal facets only. No
Sanctum Amber, no Herald Gold. Absolutely no green, no purple, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

---

## The Narrows (river canyon)

### 10. The Narrows — Placeable

```
Seamlessly tileable top-down ground texture, square format, filling the
entire frame edge-to-edge with no border or vignette — packed riverbank
gravel and smooth worn stones, viewed from a slight oblique top-down
angle. Buildable ground a player places towers on -- keep the surface calm
and uncluttered, no large rocks, no path markings.

Color palette: muted fieldstone grey (#7E8590) as the dominant worn-stone
tone at roughly 70% of normal saturation, with a cool undertone (not warm)
to distinguish it from the other 3 missions' ground. Small sparing touches
of Scout Blue (#2D5F8A) in the shadowed crevices between stones, like damp
shadow, not standing water. Parchment cream (#F5EDCB) as highlights on the
smoothest, most sun-bleached stones only. No Sanctum Amber, no Herald
Gold. Absolutely no green, no purple, no cyan (Scout Blue only, not a
bright cyan), no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

### 11. The Narrows — Path

```
Seamlessly tileable top-down ground texture, square format, filling the
entire frame edge-to-edge with no border or vignette — a worn stone
walkway along a riverbank, flatter and more compacted than the
buildable-ground tile, viewed from a slight oblique top-down angle. A thin
decorative stone edging border running perfectly straight along the top
and bottom edges only (so adjacent path tiles form a continuous bordered
lane) -- the border must NOT curve or converge to a point anywhere in the
frame. Completely flat -- no raised elements, monsters walk across this
every wave.

Color palette: muted fieldstone grey (#7E8590), cool undertone, as the
dominant worn-path tone. Sanctum Amber (#C8801A) used only for the thin
straight stone path-border edging. Parchment cream (#F5EDCB) as a small
highlight on the amber edging only. No Herald Gold, no Scout Blue on the
path itself (keep the cool water-adjacent tone exclusive to Placeable/
Blocked). Absolutely no green, no purple, no cyan, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

### 12. The Narrows — Blocked

```
Seamlessly tileable top-down ground texture, square format, filling the
entire frame edge-to-edge with no border or vignette — a dense jumble of
large water-worn boulders completely filling the tile, viewed from a
slight oblique top-down angle. Denser and darker than the buildable-ground
tile, no flat open space visible -- this ground cannot be built on or
walked across.

Color palette: muted fieldstone grey (#7E8590), cool undertone, as the
dominant wet-rock tone, darkened noticeably below the buildable-ground
tile's value, at roughly 60-65% of normal saturation. Scout Blue
(#2D5F8A) sparingly in the deepest shadowed gaps between boulders only.
Parchment cream (#F5EDCB) used extremely sparingly as specular highlights
on the wettest-looking rock surfaces. No Sanctum Amber, no Herald Gold.
Absolutely no green, no purple, no cyan, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

---

## After generation

1. Drop the resulting image(s) into `assets/source/terrain/` (e.g.
   `the_gap_placeable_raw.png`, `the_gap_path_raw.png`, ...). Name files
   `[mission_id]_[cell_type]_raw.png` if generating one at a time, to keep
   the mapping unambiguous.
2. No alpha-cut needed — opaque full-bleed tiles, same as the original
   terrain batch.
3. Claude checks for visible tiling seams by rendering 2×2 test grids of
   each Placeable/Blocked tile before wiring it in (Path's seam only
   matters along one axis — top/bottom edges — given its border
   convention).
4. Wire into `grid_visual.gd`: add a `TEXTURE_BY_TYPE_BY_MISSION` lookup
   (mission_id -> {PLACEABLE, PATH, BLOCKED} textures), falling back to
   the existing shared `TEXTURE_BY_TYPE` for SPAWN/GOAL (always shared)
   and for any mission not present in the per-mission dict (graceful
   degradation, matches this project's established "content can lag
   code" tolerance). `configure()` gains a `mission_id` parameter,
   threaded from `mission_scene.gd`'s `_on_grid_initialized()` via
   `GMissionSelect.get_current_mission_id()`.
5. Live-verify via Godot MCP against each of the 4 real missions, run the
   grid/mission-scene test suite, full regression, commit.
