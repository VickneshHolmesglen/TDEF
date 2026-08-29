# Equipment Icon Art — Generation Batch, 2026-08-29 (36 icons)

Standalone, upload-ready prompt batch for ChatGPT (or another image generator).
Covers all 36 items from `design/art/missing-assets-audit-2026-08-29.md` §1 —
every crafted weapon/armor/trinket in the game, organized by slot, tier in
brackets. Zero has an icon today. Outcome notes get folded back into
`design/art/asset-generation-prompts.md` once each piece lands, matching the
project's established convention.

Reuses the exact style/format/palette precedent from
`assets/art-generation-requests-2026-08-06-materials.md` (the 15 shipped
material icons) — these render in the same Inventory slot grid at the same
scale, so they need to read as one consistent icon family, not a new visual
language.

## Critical constraints — read before generating anything

**Do not use Herald Gold (`#F5C01A`) anywhere in the icon art itself.**
Rarity/tier signaling is handled separately by `RarityFrame` drawing a border
*around* whichever icon lands here — baking gold into the icon itself would
double up the signal.

**No purple** (boss-reserved), **no cyan** (UI-only), **no green** (heal-only
VFX — any organic material renders in warm olive/amber-brown instead).

**Shared palette for all 36:**
- Sanctum Amber `#C8801A` — warm backbone, worked-material/leather tone
- Parchment Cream `#F5EDCB` — highlights, bone/ivory/silver tones
- Fieldstone Grey `#7E8590` — neutral stone/metal/shadow
- Threat Crimson `#BE2020` — sparingly, only where flagged below (never a wash)

**Shared composition for all 36:** single object centered on a flat pure
black (`#000000`) background for easy cutout. No text, no numerals, no
border, no frame baked in — rarity/tier is the UI's `RarityFrame` job, not
the art's. Compact, simple, readable silhouette at small size (~64×64
Inventory slot).

**Style for all 36:** hand-painted miniature cabinet-diorama aesthetic,
painterly pixel-art texture with visible brushwork, matching this project's
existing UI icon set.

**Tier escalation logic** (reused across every slot below, same as each
recipe's own material-tier progression): T1 = plain, worn, functional
materials, matte, minimal ornamentation. T2 = reinforced — cleaner
metalwork, riveted plates, sharper edges. T3 = named monster-material
infusion (troll hide, lurker fang/ichor, brute plating, rift shard, goblin
fang/claw) — visibly textured with that creature's material signature. T4 =
ornate boss-signature craftsmanship (Warlord's/Sentinel's/Brute's) — richer
detail, etched sigils, a subtle warm painted highlight suggesting inner glow
(painted light only, not a runtime effect).

---

## Weapon

### 1. Iron Sword (T1 — `iron_sword.tres`)

```
Single object icon: a plain, functional iron shortsword with a worn
leather-wrapped grip, unadorned blade, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border, no
frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant blade tone,
Sanctum Amber (#C8801A) as the leather-wrapped grip, parchment cream
(#F5EDCB) as a thin specular highlight along the blade edge. No Herald Gold,
no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 2. Steel Greatsword (T2 — `steel_greatsword.tres`)

```
Single object icon: a larger two-handed steel greatsword, a cleaner
tempered blade and a riveted crossguard, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border, no
frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant blade tone,
Sanctum Amber (#C8801A) as the crossguard and rivets, parchment cream
(#F5EDCB) as a specular highlight running the blade's length. No Herald
Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 3. Lurker Fang Blade (T3 — `lurker_fang_blade.tres`)

```
Single object icon: a curved blade forged around a huge embedded lurker
fang as its tip, dark ichor-stained grooves running along the edge,
centered on a flat pure black (#000000) background for easy cutout. No
text, no numerals, no border, no frame. Compact, simple silhouette readable
at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant steel tone,
Sanctum Amber (#C8801A) as the warm ichor-stain tint in the grooves
(explicitly not green), parchment cream (#F5EDCB) as the embedded fang/bone
tip. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 4. Warlord's Greatblade (T4 — `warlords_greatblade.tres`)

```
Single object icon: an ornate, battle-worn boss-signature greatsword,
etched warlord sigils running down the blade, a heavier pommel with a
subtle warm painted glow at the fuller, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border, no
frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant blade tone,
Sanctum Amber (#C8801A) as the etched sigils and painted inner-glow
accents, parchment cream (#F5EDCB) as a sharp specular highlight. No
Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## Offhand

### 5. Wooden Buckler (T1 — `wooden_buckler.tres`)

```
Single object icon: a small round wooden buckler with a plain iron rim
band and simple visible wood grain, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border, no
frame. Compact, simple silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant wood-grain tone,
muted fieldstone grey (#7E8590) as the rim band, parchment cream (#F5EDCB)
as a small specular highlight. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 6. Iron Buckler (T2 — `iron_buckler.tres`)

```
Single object icon: a small round iron-faced buckler with a riveted boss
at its center and cleanly worked metal, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border, no
frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant metal tone,
Sanctum Amber (#C8801A) as the rivet and rim trim, parchment cream
(#F5EDCB) as a small specular highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 7. Sentinel Ward (T3 — `sentinel_ward.tres`)

```
Single object icon: a crystalline-inset round shield, a fragment of rift
shard embedded at its center casting a faint inner light, centered on a
flat pure black (#000000) background for easy cutout. No text, no
numerals, no border, no frame. Compact, simple silhouette readable at
small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant shield-body
tone, Sanctum Amber (#C8801A) as the crystal's warm inner glow, parchment
cream (#F5EDCB) as sharp faceted highlights. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 8. Sentinel's Aegis (T4 — `sentinels_aegis.tres`)

```
Single object icon: an ornate boss-tier tower shield, larger and more
angular than a common ward, a bright faceted crystal core set in worked
iron with a subtle warm glow radiating outward, centered on a flat pure
black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant shield-body
tone, Sanctum Amber (#C8801A) as the crystal core's glow, parchment cream
(#F5EDCB) as bright faceted highlights across the surface. No Herald Gold,
no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## Helmet

### 9. Iron Helm (T1 — `iron_helm.tres`)

```
Single object icon: a plain rounded iron helmet with a simple nose guard
and no crest, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant metal tone,
Sanctum Amber (#C8801A) as the rim trim, parchment cream (#F5EDCB) as a
small specular highlight. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 10. Reinforced Helm (T2 — `reinforced_helm.tres`)

```
Single object icon: a riveted iron helm with an added brow-plate and
cheek guards, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant metal tone,
Sanctum Amber (#C8801A) as the rivets and trim, parchment cream (#F5EDCB)
as a small specular highlight. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 11. Sentinel Visor (T3 — `sentinel_visor.tres`)

```
Single object icon: a closed-face visored helm with a narrow glowing
eye-slit and faceted crystal accents at the temples, centered on a flat
pure black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant helm-body
tone, Sanctum Amber (#C8801A) as the glowing eye-slit, parchment cream
(#F5EDCB) as the crystal temple-accent highlights. No Herald Gold, no
purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 12. Goblin Fang Circlet (T4 — `goblin_fang_circlet.tres`)

```
Single object icon: an ornate circlet crown ringed with small curved
goblin fangs and a central worked emblem at the brow, centered on a flat
pure black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Compact, simple silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant worked-metal band,
parchment cream (#F5EDCB) as the fang/bone accents, muted fieldstone grey
(#7E8590) in the engraved recesses only. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## Chest

### 13. Leather Jerkin (T1 — `leather_jerkin.tres`)

```
Single object icon: a plain sleeveless leather jerkin/vest with simple
lacing down the front, centered on a flat pure black (#000000) background
for easy cutout. No text, no numerals, no border, no frame. Compact,
simple silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant leather tone, muted
fieldstone grey (#7E8590) as the lacing and buckle, parchment cream
(#F5EDCB) as a small stitched highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 14. Reinforced Plate (T2 — `reinforced_plate.tres`)

```
Single object icon: a leather-and-iron hybrid cuirass, riveted iron plates
layered over a leather base, centered on a flat pure black (#000000)
background for easy cutout. No text, no numerals, no border, no frame.
Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant plate tone,
Sanctum Amber (#C8801A) as the leather straps, parchment cream (#F5EDCB)
as a small specular highlight. No Herald Gold, no purple, no green, no
cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 15. Troll-Hide Mantle (T3 — `troll_hide_mantle.tres`)

```
Single object icon: a heavy troll-hide mantle draped over the shoulders
and chest, coarse thick hide with visible fold texture, centered on a flat
pure black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant thick-hide
tone, Sanctum Amber (#C8801A) as a warm highlight along the fold's ridge,
parchment cream (#F5EDCB) used sparingly at the very brightest edge only.
No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 16. Brute's Bulwark Plate (T4 — `brutes_bulwark_plate.tres`)

```
Single object icon: an ornate, heavily armored boss-tier cuirass with
layered iron plating and a brute-core fragment set into the chest as a
subtle glowing centerpiece, centered on a flat pure black (#000000)
background for easy cutout. No text, no numerals, no border, no frame.
Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant plate tone,
Sanctum Amber (#C8801A) as the core glow and trim, parchment cream
(#F5EDCB) as bright specular highlights across the plating. No Herald
Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## Gloves

### 17. Leather Gloves (T1 — `leather_gloves.tres`)

```
Single object icon: plain worn leather gloves with simple stitched
fingers, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant leather tone, muted
fieldstone grey (#7E8590) as the stitching, parchment cream (#F5EDCB) as a
small highlight. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 18. Reinforced Gauntlets (T2 — `reinforced_gauntlets.tres`)

```
Single object icon: leather gloves with riveted iron knuckle plates,
centered on a flat pure black (#000000) background for easy cutout. No
text, no numerals, no border, no frame. Compact, simple silhouette
readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant knuckle-
plate tone, Sanctum Amber (#C8801A) as the leather, parchment cream
(#F5EDCB) as a small specular highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 19. Brute Gauntlets (T3 — `brute_gauntlets.tres`)

```
Single object icon: heavy, oversized armored gauntlets scaled to a
brute's proportions, thick plating and reinforced knuckles, centered on a
flat pure black (#000000) background for easy cutout. No text, no
numerals, no border, no frame. Compact, simple silhouette readable at
small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant plate tone,
Sanctum Amber (#C8801A) as the trim and rivets, parchment cream (#F5EDCB)
as a small specular highlight. No Herald Gold, no purple, no green, no
cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 20. Goblin Claw Gauntlets (T4 — `goblin_claw_gauntlets.tres`)

```
Single object icon: ornate gauntlets tipped with curved goblin-claw
talons at each fingertip, worked leather-and-bone construction, centered
on a flat pure black (#000000) background for easy cutout. No text, no
numerals, no border, no frame. Compact, simple silhouette readable at
small size.

Color palette: Sanctum Amber (#C8801A) as the dominant leather tone,
parchment cream (#F5EDCB) as the claw/bone tips, muted fieldstone grey
(#7E8590) as the knuckle plating only. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## Pants

### 21. Leather Leggings (T1 — `leather_leggings.tres`)

```
Single object icon: plain leather leggings with simple lacing at the
sides, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant leather tone, muted
fieldstone grey (#7E8590) as the lacing, parchment cream (#F5EDCB) as a
small highlight. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 22. Iron Greaves (T2 — `iron_greaves.tres`)

```
Single object icon: leather leggings with riveted iron shin and knee
plates, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant plate tone,
Sanctum Amber (#C8801A) as the leather, parchment cream (#F5EDCB) as a
small specular highlight. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 23. Brute Legguards (T3 — `brute_legguards.tres`)

```
Single object icon: heavy armored legguards scaled to a brute's
proportions, thick layered plating, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border, no
frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant plate tone,
Sanctum Amber (#C8801A) as the trim, parchment cream (#F5EDCB) as a small
specular highlight. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 24. Warlord's Legguards (T4 — `warlords_legguards.tres`)

```
Single object icon: ornate boss-signature legguards, etched warlord
sigils on the thigh plates and a small warlord-emblem badge at the hip,
centered on a flat pure black (#000000) background for easy cutout. No
text, no numerals, no border, no frame. Compact, simple silhouette
readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant plate tone,
Sanctum Amber (#C8801A) as the etched sigils and painted glow, parchment
cream (#F5EDCB) as a sharp specular highlight. No Herald Gold, no purple,
no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## Boots

### 25. Traveler's Boots (T1 — `traveler_boots.tres`)

```
Single object icon: plain worn leather traveling boots with simple laced
cuffs, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant leather tone, muted
fieldstone grey (#7E8590) as the sole and buckle, parchment cream
(#F5EDCB) as a small highlight. No Herald Gold, no purple, no green, no
cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 26. Reinforced Boots (T2 — `reinforced_boots.tres`)

```
Single object icon: leather boots with riveted iron toe caps and ankle
plates, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant plate tone,
Sanctum Amber (#C8801A) as the leather, parchment cream (#F5EDCB) as a
small specular highlight. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 27. Warlord's Greaves (T3 — `warlords_greaves.tres`)

```
Single object icon: sturdy armored war-boots with layered shin plating
and a crude battle-worn finish, centered on a flat pure black (#000000)
background for easy cutout. No text, no numerals, no border, no frame.
Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant plate tone,
Sanctum Amber (#C8801A) as the trim, parchment cream (#F5EDCB) as a small
specular highlight. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 28. Trollhide Striders (T4 — `trollhide_striders.tres`)

```
Single object icon: ornate boots wrapped in troll-hide with bone-marrow
accent trim at the cuffs, a heavier and more refined construction than a
common hide wrap, centered on a flat pure black (#000000) background for
easy cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant hide tone,
Sanctum Amber (#C8801A) as the trim, parchment cream (#F5EDCB) as the
marrow-accent highlight, threat crimson (#BE2020) used only as a faint,
controlled accent at the very center of the marrow trim — never a wash. No
Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## Neck

### 29. Lucky Charm Trinket (T1 — `lucky_charm_trinket.tres`)

```
Single object icon: a small plain charm on a leather cord, a simple lucky
coin or four-leaf-clover shape, centered on a flat pure black (#000000)
background for easy cutout. No text, no numerals, no border, no frame.
Compact, simple silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant charm tone, muted
fieldstone grey (#7E8590) as the cord, parchment cream (#F5EDCB) as a
small highlight. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 30. Silver Pendant (T2 — `silver_pendant.tres`)

```
Single object icon: a simple polished pendant on a fine chain, centered
on a flat pure black (#000000) background for easy cutout. No text, no
numerals, no border, no frame. Compact, simple silhouette readable at
small size.

Color palette: parchment cream (#F5EDCB) as the dominant silver-toned
pendant surface, muted fieldstone grey (#7E8590) as the chain, Sanctum
Amber (#C8801A) as a small warm reflected highlight. No Herald Gold, no
purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 31. Ichor Charm (T3 — `ichor_charm.tres`)

```
Single object icon: a small corked vial of lurker ichor worn as a
pendant charm on a cord, centered on a flat pure black (#000000)
background for easy cutout. No text, no numerals, no border, no frame.
Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the vial glass and
cord, Sanctum Amber (#C8801A) as the ichor's warm amber-brown tone
(explicitly not green), parchment cream (#F5EDCB) as a small glass
highlight. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 32. Bogpearl Amulet (T4 — `bogpearl_amulet.tres`)

```
Single object icon: an ornate amulet centered on a large lustrous bog
pearl set in worked metal, centered on a flat pure black (#000000)
background for easy cutout. No text, no numerals, no border, no frame.
Compact, simple silhouette readable at small size.

Color palette: parchment cream (#F5EDCB) as the dominant pearlescent
tone, Sanctum Amber (#C8801A) as the setting and chain, muted fieldstone
grey (#7E8590) as the subtle contact shadow beneath it only. No Herald
Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

## Ring

### 33. Warding Band (T1 — `warding_band.tres`)

```
Single object icon: a plain simple metal ring band, centered on a flat
pure black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant metal
tone, Sanctum Amber (#C8801A) as a small warm highlight. No Herald Gold,
no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 34. Iron Band (T2 — `iron_band.tres`)

```
Single object icon: a slightly thicker worked iron ring with a subtle
engraved pattern, centered on a flat pure black (#000000) background for
easy cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant metal
tone, Sanctum Amber (#C8801A) as the engraving highlight, parchment cream
(#F5EDCB) as a small specular highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 35. Goblin Signet (T3 — `goblin_signet.tres`)

```
Single object icon: a signet ring with a small goblin-fang or claw motif
set into the face, centered on a flat pure black (#000000) background for
easy cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant band tone,
parchment cream (#F5EDCB) as the fang inset, muted fieldstone grey
(#7E8590) in the engraved recess only. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

### 36. Trollmarrow Band (T4 — `trollmarrow_band.tres`)

```
Single object icon: an ornate ring set with a small cross-cut bone-
marrow fragment as its centerpiece stone, rendered symbolic and clean
rather than graphic, centered on a flat pure black (#000000) background
for easy cutout. No text, no numerals, no border, no frame. Compact,
simple silhouette readable at small size.

Color palette: parchment cream (#F5EDCB) as the dominant bone tone,
Sanctum Amber (#C8801A) as the band, threat crimson (#BE2020) used only
as a faint, controlled accent at the very center of the marrow stone —
never a wash. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, matching this project's existing UI icon set.
```

---

## Next steps once generated

1. Drop the resulting image(s) into `assets/source/items/` (same folder the
   materials batch used), named after the item id (e.g. `iron_sword.png`,
   `warlords_greatblade.png`, ...).
2. Claude alpha-cuts each icon (flood-fill technique per `design/art/
   asset-generation-prompts.md`), spot-checks against a bright backdrop, and
   archives the processed result to `assets/art/items/`.
3. Claude adds `icon = preload("res://assets/art/items/<name>.png")` to the
   matching `.tres` file under `assets/data/items/` — no other code changes
   needed, `inventory_screen.gd`'s rendering already branches correctly on
   whether `icon` is set.
4. Live-verify via Godot MCP, run the existing icon/rarity test suite if
   testing is in scope that pass, commit.
