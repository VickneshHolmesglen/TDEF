# Consumable & Material Icon Art — Generation Batch, 2026-08-29 (14 icons)

Standalone, upload-ready prompt batch for ChatGPT (or another image
generator). Covers both remaining categories from
`design/art/missing-assets-audit-2026-08-29.md`:

- **§3 Consumables (9)** — Menagerie/Crafting-produced food, potions, and
  field items (`item_type = "CraftedGood"`).
- **§4 Materials (5)** — the 4 Tower Assembly `*_surplus` grant materials
  (Mission-End Building Material Surplus, `resource-economy.md` Formula 6)
  plus `menagerie_lure`.

Both use the same materials-icon register as the 15 already-shipped
monster-drop materials (`assets/art-generation-requests-2026-08-06-materials.md`)
— reuse that batch's exact palette/style/composition, this is the same kind
of small stackable-item icon.

## Critical constraints — read before generating anything

**Do not use Herald Gold (`#F5C01A`)** in the icon art itself — rarity is a
separate `RarityFrame` border. **No purple, no cyan, no green** — any
organic/plant/fungal material renders in warm olive/amber-brown instead
(the same substitution the tarot and materials batches already used).

**Shared palette:**
- Sanctum Amber `#C8801A` — warm backbone tone
- Parchment Cream `#F5EDCB` — highlights
- Fieldstone Grey `#7E8590` — neutral stone/metal/shadow/binding
- Threat Crimson `#BE2020` — reserved, not used in this batch

**Shared composition:** single object (or small tied bundle) centered on a
flat pure black (`#000000`) background for easy cutout. No text, no
numerals, no border, no frame. Compact, simple silhouette readable at small
size (~64×64 Inventory slot).

**Style:** hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set. Family-friendly tone throughout.

---

## Consumables (9)

### 1. Bogwater Tonic (`bogwater_tonic.tres`)

```
Single object icon: a small corked glass vial of murky tonic liquid,
centered on a flat pure black (#000000) background for easy cutout. No
text, no numerals, no border, no frame. Compact, simple silhouette
readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the vial glass, Sanctum
Amber (#C8801A) as the tonic liquid's warm amber-brown tone (explicitly
not green or toxic-looking), parchment cream (#F5EDCB) as a small glass
highlight. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

### 2. Goblinhide Bandage (`goblinhide_bandage.tres`)

```
Single object icon: a rolled strip of tanned hide bandage wrap, centered
on a flat pure black (#000000) background for easy cutout. No text, no
numerals, no border, no frame. Compact, simple silhouette readable at
small size.

Color palette: Sanctum Amber (#C8801A) as the dominant hide tone,
parchment cream (#F5EDCB) as the wrap's lighter inner-fold highlight,
muted fieldstone grey (#7E8590) as the binding cord. No Herald Gold, no
purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

### 3. Healing Salve (`healing_salve.tres`)

```
Single object icon: a small open pot/jar of thick salve, centered on a
flat pure black (#000000) background for easy cutout. No text, no
numerals, no border, no frame. Compact, simple silhouette readable at
small size.

Color palette: muted fieldstone grey (#7E8590) as the jar, Sanctum Amber
(#C8801A) as the salve's warm tone (explicitly not green, despite its
healing function — matches this project's reserved-green rule), parchment
cream (#F5EDCB) as the lid-rim highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

### 4. Hunter's Draught (`hunters_draught.tres`)

```
Single object icon: a corked flask of draught, more refined-looking than
a common tonic vial, centered on a flat pure black (#000000) background
for easy cutout. No text, no numerals, no border, no frame. Compact,
simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the flask glass,
Sanctum Amber (#C8801A) as the draught liquid, parchment cream (#F5EDCB)
as the cork and a small glass highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

### 5. Ironplate Ration (`ironplate_ration.tres`)

```
Single object icon: a small wrapped field ration bundle (dried meat and
hardtack) tied with cord, centered on a flat pure black (#000000)
background for easy cutout. No text, no numerals, no border, no frame.
Compact, simple silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant wrap tone, muted
fieldstone grey (#7E8590) as the binding cord, parchment cream (#F5EDCB)
as a small highlight. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

### 6. Riftglass Ward (`riftglass_ward.tres`)

```
Single object icon: a small faceted rift-glass shard charm with a faint
inner glow, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant crystal
body, Sanctum Amber (#C8801A) as the inner glow, parchment cream
(#F5EDCB) as a sharp specular highlight at the tip. No Herald Gold, no
purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

### 7. Spore Poultice (`spore_poultice.tres`)

```
Single object icon: a small bundled cloth poultice wrap with visible
spore-dust flecks scattered across it, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border, no
frame. Compact, simple silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant warm olive-amber
wrap tone (explicitly not green — matches this project's established
fungal-material substitution), parchment cream (#F5EDCB) as the scattered
spore flecks, muted fieldstone grey (#7E8590) as the binding cord. No
Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

### 8. Traveler's Bedroll (`travelers_bedroll.tres`)

```
Single object icon: a small rolled bedroll bundle tied with leather
straps, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant fabric tone,
muted fieldstone grey (#7E8590) as the straps and buckle, parchment
cream (#F5EDCB) as a small highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

### 9. Warlord's Field Ration (`warlords_field_ration.tres`)

```
Single object icon: an ornate wrapped ration bundle with a small
warlord-sigil wax seal, more refined-looking than a common field ration,
centered on a flat pure black (#000000) background for easy cutout. No
text, no numerals, no border, no frame. Compact, simple silhouette
readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant wrap tone,
parchment cream (#F5EDCB) as the seal and a small highlight, muted
fieldstone grey (#7E8590) as the binding cord. No Herald Gold, no purple,
no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

---

## Materials (5)

### 10. Foundation Surplus (`foundation_surplus.tres`)

```
Single object icon: a small loose pile of stone-and-wood pedestal
offcuts and scrap, centered on a flat pure black (#000000) background for
easy cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant stone
tone, Sanctum Amber (#C8801A) as the wood scrap pieces, parchment cream
(#F5EDCB) as a small specular highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

### 11. Weapon Surplus (`weapon_surplus.tres`)

```
Single object icon: a small loose pile of wood-and-iron weapon-component
offcuts (bolt fragments, bracing scraps), centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border, no
frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant iron
tone, Sanctum Amber (#C8801A) as the wood scrap pieces, parchment cream
(#F5EDCB) as a small specular highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

### 12. Focus Surplus (`focus_surplus.tres`)

```
Single object icon: a small loose pile of broken crystal/glass lens
shards, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant shard-
body tone, Sanctum Amber (#C8801A) as a warm inner tint, parchment cream
(#F5EDCB) as small specular highlights. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

### 13. Power Surplus (`power_surplus.tres`)

```
Single object icon: a small loose pile of spent, cracked energy-core
fragments with a faint dim residual glow, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border, no
frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant housing
tone, Sanctum Amber (#C8801A) as the faint residual glow, parchment
cream (#F5EDCB) as a small specular highlight. No Herald Gold, no purple,
no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

### 14. Menagerie Lure (`menagerie_lure.tres`)

```
Single object icon: a small bundled lure charm (feathers, beads, and a
tied scent-bag) used to attract creatures, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border, no
frame. Compact, simple silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant bundle tone,
parchment cream (#F5EDCB) as the feather/bead highlights, muted
fieldstone grey (#7E8590) as the binding cord. No Herald Gold, no purple,
no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

---

## Next steps once generated

1. Drop the resulting image(s) into `assets/source/items/`, named after the
   item id (e.g. `bogwater_tonic.png`, `menagerie_lure.png`).
2. Claude alpha-cuts each icon (flood-fill technique), spot-checks against a
   bright backdrop, and archives the processed result to `assets/art/items/`.
3. Claude adds `icon = preload("res://assets/art/items/<name>.png")` to the
   matching `.tres` file under `assets/data/items/` — no other code changes
   needed.
4. Live-verify via Godot MCP if testing is in scope that pass, commit.
