# Mission Field Terrain Tiles — Generation Batch, 2026-08-07 (5 tiles)

Standalone, upload-ready prompt batch for ChatGPT (or another image generator) —
meant to be handed over directly. Closes the "never ship flat shapes" gap in
`grid_visual.gd`, which currently renders the entire 16×12 mission grid as flat
solid-color rectangles keyed by `Grid.CellType` (`assets/art/main_menu`-style
processing does NOT apply here — see the different pipeline notes below).

## Scope — one shared 5-tile set, reused across all 4 missions

One tile per `Grid.CellType` (`PLACEABLE`/`PATH`/`SPAWN`/`GOAL`/`BLOCKED`),
matching `grid_visual.gd`'s existing per-CellType structure. Not per-mission —
the same 5 tiles render everywhere `the_gap`/`the_foothills`/`the_hollow`/
`the_narrows` are played. Grounded in `design/art/art-bible.md` Section 3.2
("Environment Geometry — The Mission Field") and Section 4.1's real palette
roles — not invented ad hoc.

## Critical constraint — different pipeline from every prior art batch

These are **opaque, full-bleed background tiles**, not cutout icons/props.
**No black background, no transparency, no alpha-cut step.** Each image should
fill its entire square frame edge-to-edge with the ground texture itself — it
becomes the literal background of one 64×64 grid cell. Request a **seamlessly
tileable / repeatable texture** so adjacent same-type cells don't show a visible
seam — not guaranteed with an external generator, but ask for it explicitly;
minor seams get touched up during processing if needed.

## Critical constraint — color vocabulary

**Do not use green or red anywhere.** Both are semantically reserved
game-wide (art bible Section 4.1): green = healing only, red = damage-taken
only — "the world does not use red decoratively... if the player sees red in
the environment, a threat is expressing itself." Terrain must never
accidentally send either signal. SPAWN and GOAL are differentiated by
**iconography** (a rift motif, a gate motif) instead, using the real palette:

- **Sanctum Amber** `#C8801A` — path-border stone edging (explicitly named in
  its own palette role text), torch/gate glow
- **Fieldstone Grey** `#7E8590` — the dominant ground/stone tone (explicitly
  named as "mission-field path surfaces... and monster spawn platform")
- **Parchment Cream** `#F5EDCB` — light highlights, worn stone catching light
- **Scout Blue** `#2D5F8A` — used sparingly, only on the SPAWN tile's rift glow
  (blue = "not yet decided," fitting an unknown entry point)
- Do NOT use: Herald Gold (crit/achievement-only), Boss Purple (boss-only),
  green, red

**Terrain renders at ~70% of maximum saturation** (art bible Section 3.2,
"grid noise prevention") — noticeably more muted than a tower or monster would
be. Keep every tile visibly desaturated relative to a normal prop/character
generation in this project.

**Style**: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, viewed from a slight oblique
top-down angle (matching every other Sanctuary Defenders asset) — not a flat
vector tile, not a photo-real texture.

---

## 1. Placeable (buildable ground)

```
Seamlessly tileable top-down ground texture, square format, filling the
entire frame edge-to-edge with no border or vignette — worn, compacted
earth with scattered flat stone fragments, viewed from a slight oblique
top-down angle. A hint of low moss/root growth at ground level only
(nothing raised above a few pixels). This is buildable ground a player
places towers on, so keep the surface calm and uncluttered — no large
rocks, no path markings.

Color palette: muted fieldstone grey (#7E8590) as the dominant
worn-earth/stone tone, at roughly 70% of normal saturation — noticeably
muted, not vibrant. Parchment cream (#F5EDCB) used only as small scattered
highlights on the flattest stone fragments. No Sanctum Amber, no Herald
Gold, no Scout Blue. Absolutely no green, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

## 2. Path (monster walking lane)

```
Seamlessly tileable top-down ground texture, square format, filling the
entire frame edge-to-edge with no border or vignette — a worn dirt/stone
path surface, flatter and more compacted-looking than the buildable-ground
tile, viewed from a slight oblique top-down angle. A thin decorative stone
edging border along two opposite sides of the tile (so adjacent path tiles
form a continuous bordered lane when placed in a row). Completely flat —
no raised elements of any height, monsters walk across this every wave.

Color palette: muted fieldstone grey (#7E8590) as the dominant worn-path
tone, at roughly 70% of normal saturation. Sanctum Amber (#C8801A) used
only for the thin stone path-border edging described above — warm,
worked-stone framing, not a wash. Parchment cream (#F5EDCB) as a small
highlight on the amber edging only. No Herald Gold, no Scout Blue.
Absolutely no green, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

## 3. Spawn (monster entry point)

```
Top-down game tile illustration, square format, filling the entire frame
edge-to-edge with no border or vignette — a single cracked stone rift or
fissure in the ground, glowing faintly from within, centered in the tile,
viewed from a slight oblique top-down angle. This marks where enemies
enter the battlefield each wave — an unnatural tear in the world, not a
building or gate. Keep it low and mostly flat (a crack/glow in the ground,
not a raised structure) so it doesn't obstruct the monsters that emerge
from it.

Color palette: muted fieldstone grey (#7E8590) as the dominant surrounding
stone/ground tone, at roughly 70% of normal saturation. Scout blue
(#2D5F8A) used only as the rift's own inner glow, sparingly — a cool,
unsettling light distinct from the sanctuary's warm amber. Parchment cream
(#F5EDCB) as a thin bright highlight right at the crack's edge only. No
Sanctum Amber, no Herald Gold. Absolutely no green, no red — this is not a
healing or damage signal, it is a spawn marker.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

## 4. Goal (the defended threshold)

```
Top-down game tile illustration, square format, filling the entire frame
edge-to-edge with no border or vignette — a low stone archway or gate
threshold set into the ground, lit warmly from within as if guarding
something precious behind it, centered in the tile, viewed from a slight
oblique top-down angle. This is the point enemies are trying to reach and
breach — render it as a defended, precious threshold, not a ruin or an
opening under attack. Keep the raised archway modest in height, no taller
than roughly half a tower's base height, so it doesn't compete visually
with towers placed nearby.

Color palette: Sanctum Amber (#C8801A) as the dominant warm torchlit-stone
tone on the archway itself, muted fieldstone grey (#7E8590) as the
surrounding ground (roughly 70% of normal saturation), parchment cream
(#F5EDCB) as a warm highlight glow at the archway's center. No Herald
Gold, no Scout Blue. Absolutely no green, no red — this is a defended
objective, not a damage or danger signal.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

## 5. Blocked (impassable terrain)

```
Seamlessly tileable top-down ground texture, square format, filling the
entire frame edge-to-edge with no border or vignette — dense, rough,
unworked rock formation completely filling the tile, viewed from a slight
oblique top-down angle. Denser and darker than the buildable-ground tile,
with no flat open space visible — this ground cannot be built on or
walked across. No stone edging or path-border details (those signal
"worked/traversable," which this tile explicitly is not).

Color palette: muted fieldstone grey (#7E8590) as the dominant raw-rock
tone, darkened noticeably below the buildable-ground tile's value, at
roughly 60-65% of normal saturation (slightly more muted than the other
terrain tiles). Parchment cream (#F5EDCB) used extremely sparingly, only
as a few small specular highlights on the roughest rock edges. No Sanctum
Amber, no Herald Gold, no Scout Blue. Absolutely no green, no red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
art.
```

---

## Next steps once generated

1. Drop the resulting image(s) into `assets/source/terrain/` (create the
   folder if it doesn't exist). Name files after the cell type
   (`placeable.png`, `path.png`, `spawn.png`, `goal.png`, `blocked.png`) if
   generating one at a time.
2. **No alpha-cut needed** — these are opaque full-bleed tiles, not cutout
   icons. Claude crops each to a clean square (removing any accidental
   border/vignette the generator added) and archives the processed result to
   `assets/art/terrain/`.
3. Claude checks for visible tiling seams by rendering 2×2 test grids of each
   tile before wiring it in — touches up edges if a seam is obvious.
4. Wire into `grid_visual.gd`: replace `COLOR_BY_TYPE`'s flat-color fill with
   a `TEXTURE_BY_TYPE` texture lookup, keeping the same per-cell draw loop
   structure. `_build_grid_texture()`'s outline-blend logic may need
   adjustment once real texture edges exist instead of flat color.
5. Live-verify via Godot MCP screenshot against a real mission (e.g.
   `the_gap`), run the existing grid/mission-scene test suite, full
   regression, commit.
