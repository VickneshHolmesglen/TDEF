# Tower Component Icon Art — Generation Batch, 2026-08-29 (13 icons)

Standalone, upload-ready prompt batch for ChatGPT (or another image
generator). Covers all 13 items from `design/art/missing-assets-audit-2026-08-29.md`
§2 — Tower Assembly's Foundation/Weapon/Focus/Power components, the pieces
sitting in a player's Inventory bag before they're assembled into a custom
tower (`design/quick-specs/tower-assembly-2026-08-11.md`).

**Not the same thing as** `assets/art-generation-requests-2026-08-17-tower-components.md`
(the Base/Shaft/Top full-body layer split for rendering an assembled tower on
the battlefield). These are small Inventory-slot **icons** for the individual
crafted component sitting in a bag — a different asset at a different scale.
Don't conflate the two batches when generating or wiring.

**The 4 `*_surplus` items are covered separately** in
`assets/art-generation-requests-2026-08-29-consumables-materials.md` — they're
generic Mission-End grant materials, not named crafted components, so they
use the materials-icon register instead.

## Critical constraints — read before generating anything

Same reservations as every other icon batch this project has run: **no
Herald Gold** in the icon art itself (rarity is a separate `RarityFrame`
border), **no purple, no cyan, no green**.

**Palette — matches `assets/art/towers/`'s existing structural language**
(not the organic materials palette), since these represent physical pieces
of an assembled tower:
- Fieldstone Grey `#7E8590` — stone/iron, the dominant tone for all 13
- Sanctum Amber `#C8801A` — warm trim/wood accents, escalating to a painted
  glow accent at the top tier
- Parchment Cream `#F5EDCB` — highlights only

**Shared composition:** single detached prop icon, centered on a flat pure
black (`#000000`) background for easy cutout. No text, no numerals, no
border, no frame. Compact, simple silhouette readable at small size (~64×64
Inventory slot) — shown as an isolated prop, not attached to or resting on a
tower.

**Style:** hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set and the structural material language of `assets/art/towers/`.

**Tier escalation:** baseline (`archer_*`) = plain wood-and-iron
construction, minimal ornamentation. Mid tier = reinforced iron banding,
cleaner fittings. Top tier = ornate, finely worked, a subtle warm painted
highlight suggesting inner glow (painted light only, not a runtime effect).

---

## Foundation (3)

### 1. Archer Foundation (baseline — `archer_foundation_component.tres`)

```
Single detached prop icon: a small stone-and-wood pedestal fragment, a
plain hexagonal stone block chunk with a simple wood peg joint, centered
on a flat pure black (#000000) background for easy cutout. No text, no
numerals, no border, no frame. Compact, simple silhouette readable at
small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant stone
tone, Sanctum Amber (#C8801A) as the wood-peg trim, parchment cream
(#F5EDCB) as a small specular highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
tower-art structural language.
```

### 2. Iron Foundation (mid — `iron_foundation_component.tres`)

```
Single detached prop icon: the same small stone pedestal fragment,
reinforced with an iron collar/bracket wrapped around one edge, centered
on a flat pure black (#000000) background for easy cutout. No text, no
numerals, no border, no frame. Compact, simple silhouette readable at
small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant stone and
iron tone, Sanctum Amber (#C8801A) as the bracket trim, parchment cream
(#F5EDCB) as a small specular highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
tower-art structural language.
```

### 3. Reinforced Foundation (top — `reinforced_foundation_component.tres`)

```
Single detached prop icon: a heavier, more ornate pedestal fragment with
layered iron banding and a small worked plaque motif recessed into the
face, centered on a flat pure black (#000000) background for easy cutout.
No text, no numerals, no border, no frame. Compact, simple silhouette
readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant stone
tone, Sanctum Amber (#C8801A) as the banding and trim with a subtle
painted warm highlight, parchment cream (#F5EDCB) as sharp specular
highlights. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
tower-art structural language.
```

## Weapon (3)

### 4. Archer Weapon (baseline — `archer_weapon_component.tres`)

```
Single detached prop icon: a small crossbow/ballista head, plain wood-
and-iron construction, centered on a flat pure black (#000000) background
for easy cutout. No text, no numerals, no border, no frame. Compact,
simple silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant wood tone, muted
fieldstone grey (#7E8590) as the iron fittings, parchment cream (#F5EDCB)
as a small specular highlight. No Herald Gold, no purple, no green, no
cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
tower-art structural language.
```

### 5. Advanced Weapon Component (mid — `advanced_weapon_component.tres`)

```
Single detached prop icon: a similar crossbow head with reinforced iron
bracing and a tighter draw mechanism, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border, no
frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant iron
tone, Sanctum Amber (#C8801A) as the wood and trim, parchment cream
(#F5EDCB) as a small specular highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
tower-art structural language.
```

### 6. Masterwork Weapon (top — `masterwork_weapon_component.tres`)

```
Single detached prop icon: an ornate masterwork ballista head, finely
worked metal fittings, a subtle warm painted glow at the firing
mechanism, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant iron
tone, Sanctum Amber (#C8801A) as the glow accent and trim, parchment
cream (#F5EDCB) as sharp specular highlights. No Herald Gold, no purple,
no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
tower-art structural language.
```

## Focus (3)

### 7. Archer Focus (baseline — `archer_focus_component.tres`)

```
Single detached prop icon: a small plain glass/crystal lens fragment
held in a simple wood-and-iron mount, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border, no
frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant mount
tone, Sanctum Amber (#C8801A) as the wood trim, parchment cream (#F5EDCB)
as the lens highlight. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
tower-art structural language.
```

### 8. Basic Focus (mid — `basic_focus_component.tres`)

```
Single detached prop icon: a slightly larger, cleaner-cut crystal lens
held in a reinforced iron mount, centered on a flat pure black (#000000)
background for easy cutout. No text, no numerals, no border, no frame.
Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant mount
tone, Sanctum Amber (#C8801A) as the trim, parchment cream (#F5EDCB) as
the lens highlight. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
tower-art structural language.
```

### 9. Reinforced Focus (top — `reinforced_focus_component.tres`)

```
Single detached prop icon: an ornate faceted crystal lens in a heavier
worked-iron mount, a subtle warm painted inner glow, centered on a flat
pure black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant mount
tone, Sanctum Amber (#C8801A) as the inner glow, parchment cream
(#F5EDCB) as sharp faceted highlights. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
tower-art structural language.
```

## Power (4)

### 10. Archer Power (baseline — `archer_power_component.tres`)

```
Single detached prop icon: a small plain glowing energy-core fragment in
a simple iron housing, centered on a flat pure black (#000000) background
for easy cutout. No text, no numerals, no border, no frame. Compact,
simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant housing
tone, Sanctum Amber (#C8801A) as the core's faint glow, parchment cream
(#F5EDCB) as a small specular highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
tower-art structural language.
```

### 11. Reinforced Power (mid — `reinforced_power_component.tres`)

```
Single detached prop icon: a similar energy-core fragment with
reinforced iron banding around the housing, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border, no
frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant housing
tone, Sanctum Amber (#C8801A) as the core's glow and banding, parchment
cream (#F5EDCB) as a small specular highlight. No Herald Gold, no purple,
no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
tower-art structural language.
```

### 12. Masterwork Power (upper — `masterwork_power_component.tres`)

```
Single detached prop icon: an ornate faceted energy core with a
brighter warm painted glow and finely worked housing, centered on a flat
pure black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant housing
tone, Sanctum Amber (#C8801A) as the brighter core glow, parchment cream
(#F5EDCB) as sharp faceted highlights. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
tower-art structural language.
```

### 13. Tier 4 Power Component (peak — `tier4_power_component.tres`)

```
Single detached prop icon: the family's most ornate and largest energy
core, radiant warm painted glow, elaborate finely worked metal housing —
the clear peak-tier piece in this component family, centered on a flat
pure black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant housing
tone, Sanctum Amber (#C8801A) as the radiant core glow, parchment cream
(#F5EDCB) as bright faceted highlights across the housing. No Herald
Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
tower-art structural language.
```

---

## Next steps once generated

1. Drop the resulting image(s) into `assets/source/items/`, named after the
   item id (e.g. `archer_foundation_component.png`, `tier4_power_component.png`).
2. Claude alpha-cuts each icon (flood-fill technique), spot-checks against a
   bright backdrop, and archives the processed result to `assets/art/items/`.
3. Claude adds `icon = preload("res://assets/art/items/<name>.png")` to the
   matching `.tres` file under `assets/data/items/` — no other code changes
   needed.
4. Live-verify via Godot MCP if testing is in scope that pass, commit.
