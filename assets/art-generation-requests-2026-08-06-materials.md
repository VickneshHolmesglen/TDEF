# Material Icon Art — Generation Batch, 2026-08-06 (15 icons)

Standalone, upload-ready prompt batch for ChatGPT (or another image generator) —
meant to be handed over directly. Outcome notes get folded back into
`design/art/asset-generation-prompts.md` once each piece lands, matching the
project's established convention.

## Progress — 15/15 generated, sliced, and wired (2026-08-07)

Closes Phase 3 of the materials-icons work
(`design/quick-specs/inventory-slot-icons-2026-08-06.md` built the rendering
mechanism against a real-but-empty `icon` field on all 13
`ItemDefinitionResource` files — this batch is the content half). Once
dropped into `assets/source/items/`, each gets alpha-cut into
`assets/art/items/` and wired with a one-line `icon = ExtResource(...)`
addition to its own `.tres` file — no further code changes needed.

**Items 14-15 added 2026-08-07** (`common_scrap`, `iron_ore`) — both were
found orphaned (real `ItemDefinitionResource`s with no drop-table entry, no
recipe output, unobtainable in any playthrough) during a content-integrity
audit and wired into real drop tables (`skitterling_drops`/`goblin_drops`)
in the same session. Same icon-less gap as the original 13, folded into this
batch rather than starting a separate one.

## Critical constraints — read before generating anything

**Do not use Herald Gold (`#F5C01A`) anywhere in the icon art itself**,
even for the 6 Rare-tier materials. This is the same reservation honored by
every other art batch this session (Section 4.2: "must not appear as
ambient decoration"). Rare-tier signaling is already handled separately —
`RarityFrame` draws a Herald Gold diamond outline *around* whichever icon
art lands here, in code, per `crafting.md`'s own established convention.
Baking gold into the icon itself would double up the signal and muddy the
frame/content separation this project has kept clean everywhere else.

**Do not use green** — reserved for heal-only VFX. Any organic/plant/fungal
material (hide, spore dust) renders in warm olive/amber-brown instead, same
substitution already used for every tarot card with foliage.

**No purple** (boss-reserved), **no cyan** (UI-only).

**Shared palette for all 13** (art bible Section 4.1):
- Sanctum Amber `#C8801A` — warm backbone, the default "worked material" tone
- Parchment Cream `#F5EDCB` — highlights, bone/ivory tones
- Fieldstone Grey `#7E8590` — neutral stone/metal/shadow
- Threat Crimson `#BE2020` — sparingly, only where named below (never a wash)

**Shared composition notes for all 13:**
- Single object centered on a flat pure black (`#000000`) background for
  easy cutout — matches this project's established alpha-cut pipeline.
- No text, no numerals, no border, no frame baked in — icon art only, the
  UI renders `RarityFrame`'s own border separately (same "frame is the
  UI's job, not the art's" rule the tarot batch and gold coin already used).
- Compact, simple, readable silhouette at small size — these render at
  roughly 64×64 in Inventory's slot grid, smaller than any other art batch
  this project has generated so far. Avoid fine internal detail that would
  disappear at that size; the silhouette itself must carry the identity.
- Style: hand-painted miniature cabinet-diorama aesthetic, painterly
  pixel-art texture with visible brushwork — matches the gold coin icon and
  every other UI/prop icon generated for this project, not a flat
  vector/emoji-style icon.
- Family-friendly tone throughout — even the "grim" materials (marrow,
  ichor) render as symbolic/textural, not graphic.

---

## 1. Goblin Hide (Common — `goblin_hide.tres`)

```
Single object icon: a folded swatch of tanned leather hide with visible
stitched or torn edges, centered on a flat pure black (#000000) background
for easy cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant worn-leather tone,
parchment cream (#F5EDCB) highlight along one folded edge, muted fieldstone
grey (#7E8590) in the deepest shadow folds only. No Herald Gold, no purple,
no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## 2. Goblin Fang (Rare — `goblin_fang.tres`)

```
Single object icon: one curved, sharp goblin fang/tooth, centered on a flat
pure black (#000000) background for easy cutout. No text, no numerals, no
border, no frame (rarity is signaled by a separate UI frame, not baked into
this art). Compact, simple silhouette readable at small size.

Color palette: parchment cream (#F5EDCB) as the dominant ivory-bone tone,
Sanctum Amber (#C8801A) at the root/base where it was embedded, muted
fieldstone grey (#7E8590) in a subtle cast shadow beneath the fang only. No
Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## 3. Iron Plating (Common — `iron_plating.tres`)

```
Single object icon: one dented, worked scrap of iron armor plating, roughly
square, centered on a flat pure black (#000000) background for easy cutout.
No text, no numerals, no border, no frame. Compact, simple silhouette
readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant worked-metal
tone, Sanctum Amber (#C8801A) rim light along one edge catching warm light,
parchment cream (#F5EDCB) as a small specular highlight only. No Herald
Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## 4. Brute Core (Rare — `brute_core.tres`)

```
Single object icon: a fist-sized crystalline-mechanical core, part
organic-crystal part armored housing, faintly glowing from within, centered
on a flat pure black (#000000) background for easy cutout. No text, no
numerals, no border, no frame. Compact, simple silhouette readable at small
size.

Color palette: Sanctum Amber (#C8801A) as the dominant warm inner glow,
muted fieldstone grey (#7E8590) as the surrounding armored housing,
parchment cream (#F5EDCB) as a bright highlight at the glow's core. No
Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## 5. Lurker Ichor (Common — `lurker_ichor.tres`)

```
Single object icon: a small corked glass vial containing thick, dark,
viscous ichor, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the vial glass and cork,
Sanctum Amber (#C8801A) as the ichor's own warm-dark amber-brown tone
(explicitly not green or black-green — a bog creature's fluid rendered
warm, not toxic-looking), parchment cream (#F5EDCB) as a small glass
highlight only. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## 6. Bog Pearl (Rare — `bog_pearl.tres`)

```
Single object icon: one lustrous, softly luminous pearl, centered on a flat
pure black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Compact, simple silhouette readable at small size.

Color palette: parchment cream (#F5EDCB) as the dominant pearlescent
surface, Sanctum Amber (#C8801A) as a warm reflected-light cast on the
lower curve, muted fieldstone grey (#7E8590) as the subtle contact shadow
beneath it only. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## 7. Rift Shard (Common — `rift_shard.tres`)

```
Single object icon: one jagged, angular crystal shard, centered on a flat
pure black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant crystal
body, Sanctum Amber (#C8801A) as an inner warm glow along the shard's core
facets, parchment cream (#F5EDCB) as a sharp specular highlight at the tip.
No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## 8. Sentinel Core (Rare — `sentinel_core.tres`)

```
Single object icon: a larger, more refined and ornate crystalline energy
core than a common shard — faceted, clearly a boss-tier artifact, centered
on a flat pure black (#000000) background for easy cutout. No text, no
numerals, no border, no frame. Compact, simple silhouette readable at small
size.

Color palette: Sanctum Amber (#C8801A) as the dominant warm inner glow,
parchment cream (#F5EDCB) as bright faceted highlights across its surface,
muted fieldstone grey (#7E8590) as the outer structural edges only. No
Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## 9. Spore Dust (Common — `spore_dust.tres`, only tier — no Rare counterpart)

```
Single object icon: a small loose cluster/puff of fungal spores, drifting
together as one compact shape, centered on a flat pure black (#000000)
background for easy cutout. No text, no numerals, no border, no frame.
Compact, simple silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant warm olive-amber
spore tone (explicitly not green — fungal material rendered warm, matching
this project's established foliage substitution), parchment cream
(#F5EDCB) as scattered lighter highlight specks, muted fieldstone grey
(#7E8590) used sparingly in the shadowed core of the cluster only. No
Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## 10. Troll Hide (Common — `troll_hide.tres`)

```
Single object icon: a thick, tough, folded swatch of troll hide, coarser
and heavier-looking than the goblin hide icon, centered on a flat pure
black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant thick-hide
tone, Sanctum Amber (#C8801A) as a warm highlight along the fold's ridge,
parchment cream (#F5EDCB) used sparingly at the very brightest edge only.
No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## 11. Troll Marrow (Rare — `troll_marrow.tres`)

```
Single object icon: a single cross-cut bone fragment with visible marrow at
its core, rendered symbolic and clean rather than graphic (family-friendly
tone), centered on a flat pure black (#000000) background for easy cutout.
No text, no numerals, no border, no frame. Compact, simple silhouette
readable at small size.

Color palette: parchment cream (#F5EDCB) as the dominant bone tone, Sanctum
Amber (#C8801A) as the marrow's own warm inner color, threat crimson
(#BE2020) used only as a faint, controlled accent at the very center of the
marrow — never a wash, never covering more than a small fraction of the
icon. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## 12. Warlord Iron (Common — `warlord_iron.tres`)

```
Single object icon: a jagged scrap of worked battle-iron, rougher and more
crudely forged-looking than the iron plating icon, centered on a flat pure
black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant raw-iron
tone, Sanctum Amber (#C8801A) as a warm forge-heat rim light along one
edge, parchment cream (#F5EDCB) as a small specular highlight only. No
Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## 13. Warlord Emblem (Rare — `warlord_emblem.tres`)

```
Single object icon: one ornate carved emblem/badge, a warlord's personal
insignia, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant worked-metal emblem
tone, parchment cream (#F5EDCB) as raised-relief highlights on the carved
detail, muted fieldstone grey (#7E8590) in the recessed engraved lines
only. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## 14. Common Scrap (Common — `common_scrap.tres`)

```
Single object icon: a small jumbled pile of miscellaneous scrap metal
fragments (a bent nail, a broken buckle, a torn strip of sheet metal),
centered on a flat pure black (#000000) background for easy cutout. No
text, no numerals, no border, no frame. Compact, simple silhouette readable
at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant scrap-metal
tone, Sanctum Amber (#C8801A) as a warm rust/tarnish tint on one or two
pieces, parchment cream (#F5EDCB) as a small specular highlight only. No
Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## 15. Iron Ore (Uncommon — `iron_ore.tres`)

```
Single object icon: one rough, unrefined chunk of raw iron ore, still
embedded in stone matrix, distinct from a worked/forged metal object —
centered on a flat pure black (#000000) background for easy cutout. No
text, no numerals, no border, no frame. Compact, simple silhouette readable
at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant raw-stone
tone, Sanctum Amber (#C8801A) as a warm rusty-metallic vein/fleck running
through the rock, parchment cream (#F5EDCB) as a small specular highlight on
the ore's exposed metal facet only. No Herald Gold, no purple, no green, no
cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

---

## Next steps once generated

1. Drop the resulting image(s) into `assets/source/items/` (create the
   folder if it doesn't exist), one file per material or a single sheet —
   either works, Claude will slice/process either way. Name files after the
   material_id (e.g. `goblin_hide.png`, `iron_plating.png`, ...) if
   generating one at a time, to keep the mapping unambiguous.
2. Claude alpha-cuts each icon (flood-fill technique, per `design/art/
   asset-generation-prompts.md`'s documented method), spot-checks against a
   bright backdrop before trusting the cut, and archives the processed
   result to `assets/art/items/`.
3. Claude adds `icon = preload("res://assets/art/items/<name>.png")` to the
   matching `.tres` file under `assets/data/items/` — no other code changes
   needed, `inventory_screen.gd`'s rendering already branches correctly on
   whether `icon` is set.
4. Live-verify via Godot MCP, run the existing icon/rarity test suite, full
   regression, commit.
