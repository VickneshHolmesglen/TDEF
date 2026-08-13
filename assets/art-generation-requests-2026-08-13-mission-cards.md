# Mission Card Environment-Motif Icons — Generation Batch, 2026-08-13 (4 icons)

Standalone, upload-ready prompt batch for ChatGPT (or another image generator) —
meant to be handed over directly. Outcome notes get folded back into
`design/art/asset-generation-prompts.md` once each piece lands, matching the
project's established convention.

## What this closes

`design/gdd/mission-select.md`'s Visual/Audio Requirements section ("Mission
list presentation") specifies each mission card shows "a small flat
environment-motif icon (silhouette-level, not a diorama render — e.g. a
simplified tree-line glyph for a forest mission)". No art exists for this yet
— `mission_select_screen.gd`'s own doc comment flags "No mission-card art...
no art exists anywhere in this project" as an honestly-bounded scope gap. This
batch is the content half for all 4 currently-authored missions
(`assets/data/missions/entries/*.tres`): The Gap, The Foothills, The Hollow,
The Narrows.

## Critical constraint — this is a DIFFERENT style from every other art batch in this project

Every other batch generated for this project (monsters, materials, tarot,
tower components) uses the **hand-painted diorama/painterly pixel-art**
register from Art Bible Section 1 ("if it could sit inside a wizard's cabinet
as a hand-carved diorama"). **Mission card icons must NOT use that register.**

`mission-select.md` is explicit: "Mission Select is a utilitarian,
informational screen... It belongs to the Inventory/Crafting/Tarot UI-panel
visual language, not the diorama/living-world language... No mission
thumbnail, icon, or panel chrome here should read as a hand-carved diorama
piece." And: "Cards use UI Chrome/UI Parchment tones only (Sec 4.4) — no
world-saturation Sanctum Amber, Parchment Cream, Verdant Green, or Threat
Crimson at full intensity anywhere on this screen."

So for this batch specifically:
- **Flat, solid-fill silhouette/glyph style** — like a clean vector icon or
  pictogram. NOT painterly, NOT textured, NOT hand-brushed, no gradients, no
  shading, no highlights, no material rendering of any kind.
- **Single flat color only**: UI Parchment (`#DDD4B0`) fill for the silhouette
  shape itself, on a pure black (`#000000`) background for alpha-cut
  extraction (matches this project's established cutout pipeline). No other
  color anywhere in the shape.
- No Sanctum Amber, no Parchment Cream (world variant), no Verdant Green, no
  Threat Crimson, no Herald Gold, no purple, no cyan — none of the
  full-saturation world palette. Just the one UI Parchment silhouette on black.
- No text, no numerals, no border, no frame baked in — the UI applies its own
  chamfered-rectangle icon frame (Art Bible 3.3) separately, same
  frame-is-the-UI's-job convention already used for `RarityFrame`.
- Must read as a clean, simple silhouette at small size (Art Bible 3.3's
  24×24px minimum) — avoid any fine internal detail that would disappear at
  that scale. Each mission's motif must be distinguishable from the other 3
  in silhouette alone, at a glance, with no color cue to lean on.

---

## 1. The Gap (`the_gap`)

```
Flat vector-style icon: a mountain pass silhouette — two jagged, angular rock
cliff faces facing each other, leaning inward, with a narrow vertical gap or
passage between them. Single flat fill color UI Parchment (#DDD4B0), centered
on a pure black (#000000) background for easy cutout. No gradients, no
shading, no texture, no outline stroke, no text, no border, no frame. Clean
geometric silhouette, simple enough to read clearly at 24x24px.

Style: flat solid-color silhouette/pictogram icon, like a clean vector glyph
— explicitly NOT painterly, NOT hand-brushed, NOT a diorama render. No other
colors anywhere in the image besides the single UI Parchment fill on black.
```

## 2. The Foothills (`the_foothills`)

```
Flat vector-style icon: rolling foothills silhouette — three overlapping
gently-rounded hill shapes of varying size receding into the distance
(largest/closest hill in front, smaller hills layered behind). Single flat
fill color UI Parchment (#DDD4B0), centered on a pure black (#000000)
background for easy cutout. No gradients, no shading, no texture, no outline
stroke, no text, no border, no frame. Clean geometric silhouette, simple
enough to read clearly at 24x24px.

Style: flat solid-color silhouette/pictogram icon, like a clean vector glyph
— explicitly NOT painterly, NOT hand-brushed, NOT a diorama render. No other
colors anywhere in the image besides the single UI Parchment fill on black.
```

## 3. The Hollow (`the_hollow`)

```
Flat vector-style icon: a forest hollow silhouette — a simplified cluster of
3 stylized conifer tree silhouettes (simple triangular canopy shapes)
clustered above a shallow, gently-curved dip or bowl shape representing the
hollow beneath them. Single flat fill color UI Parchment (#DDD4B0), centered
on a pure black (#000000) background for easy cutout. No gradients, no
shading, no texture, no outline stroke, no text, no border, no frame. Clean
geometric silhouette, simple enough to read clearly at 24x24px.

Style: flat solid-color silhouette/pictogram icon, like a clean vector glyph
— explicitly NOT painterly, NOT hand-brushed, NOT a diorama render. No other
colors anywhere in the image besides the single UI Parchment fill on black.
```

## 4. The Narrows (`the_narrows`)

```
Flat vector-style icon: a narrow water channel silhouette — two jagged,
angular riverbank/cliff-edge shapes squeezing close together, with a thin
winding ribbon shape between them representing a narrow river or strait. The
riverbank shapes and the water ribbon are both rendered in the same single
flat fill color (do not differentiate them by color — differentiate only by
the negative-space gap between the shapes). Single flat fill color UI
Parchment (#DDD4B0), centered on a pure black (#000000) background for easy
cutout. No gradients, no shading, no texture, no outline stroke, no text, no
border, no frame. Clean geometric silhouette, simple enough to read clearly
at 24x24px.

Style: flat solid-color silhouette/pictogram icon, like a clean vector glyph
— explicitly NOT painterly, NOT hand-brushed, NOT a diorama render. No other
colors anywhere in the image besides the single UI Parchment fill on black.
```

---

## After generation

1. Drop the raw generated sheet(s) into `assets/source/ui/` (snake_case
   filename, e.g. `mission_card_the_gap.png`).
2. Alpha-cut into `assets/art/ui/` using this project's established technique
   — color-distance threshold works cleanly here since the background is
   pure black and the icon itself has zero warm/skin-tone content to
   conflict with it (no need for the edge-magnitude flood-fill fallback the
   hero sprite needed).
3. Wire into `MissionEntry` (`src/core/mission_entry.gd`) as a new
   `@export var icon: Texture2D` field (does not exist yet — this batch is
   content-first, the field needs adding alongside it) and display it in
   `mission_select_screen.gd`'s mission list card, inside the UI's own
   chamfered-rectangle icon frame per Art Bible 3.3.
