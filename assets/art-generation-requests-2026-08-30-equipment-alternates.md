# Equipment Icon Art — Alternate T3/T4 Recipes, Generation Batch 2026-08-30 (9 icons)

Standalone, upload-ready prompt batch for ChatGPT (or another image
generator). Covers 9 brand-new alternate top-tier equipment items added
2026-08-30 — one per slot, each a second named-monster-material recipe
alongside the slot's existing T3/T4 item (same pattern as the earlier
13-recipe gap-fill pass, `design/gdd/crafting.md`/Equipment Forge). Backend
`ItemDefinitionResource`/`EquipmentRecipeResource` `.tres` files for all 9
are already written and load-clean; only the icon art is missing.

Reuses the exact style/format/palette precedent from
`assets/art-generation-requests-2026-08-29-equipment.md` (the original
36-item batch) — same shared palette, composition, and tier-escalation
logic. These are all T3 or T4 items, so all render with the "monster-
material infusion" or "ornate boss-signature" treatment, never the plain
T1/T2 look.

## Critical constraints — read before generating anything

Same reservations as every icon batch this project has run: **no Herald
Gold** in the icon art itself, **no purple, no green, no cyan**.

**Shared palette:**
- Sanctum Amber `#C8801A` — warm backbone, worked-material/leather tone
- Parchment Cream `#F5EDCB` — highlights, bone/ivory tones
- Fieldstone Grey `#7E8590` — neutral stone/metal/shadow
- Threat Crimson `#BE2020` — sparingly, only where flagged (never a wash)

**Shared composition:** single object centered on a flat pure black
(`#000000`) background for easy cutout. No text, no numerals, no border,
no frame baked in. Compact, simple, readable silhouette at small size
(~64×64 Inventory slot).

**Style:** hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.

**Material identity per family** (matching this project's already-shipped
icon set for these same materials): Troll = coarse thick grey hide,
Goblin = tanned leather + curved fangs, Lurker = dark amber-brown ichor
(never green), Rift Sentinel = grey stone + warm crystal glow, Warlord =
crude battle-forged iron + emblem, Armored Brute = heavy grey plating +
glowing core.

---

## 1. Sentinel's Lance (T4 Weapon — `sentinels_lance.tres`)

```
Single object icon: an ornate polearm/lance with a rift-shard crystal
head, radiating a warm inner glow along the blade's core, centered on a
flat pure black (#000000) background for easy cutout. No text, no
numerals, no border, no frame. Compact, simple silhouette readable at
small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant shaft and
blade-body tone, Sanctum Amber (#C8801A) as the crystal's warm inner glow
and haft trim, parchment cream (#F5EDCB) as a sharp specular highlight at
the tip. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

## 2. Trollhide Buckler (T3 Offhand — `trollhide_buckler.tres`)

```
Single object icon: a small round buckler shield faced with thick,
coarse troll-hide, riveted to a worn wooden frame, centered on a flat
pure black (#000000) background for easy cutout. No text, no numerals,
no border, no frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant hide tone,
Sanctum Amber (#C8801A) as the wooden frame and rivets, parchment cream
(#F5EDCB) used sparingly at the brightest edge only. No Herald Gold, no
purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

## 3. Brute's War-Helm (T4 Helmet — `brutes_war_helm.tres`)

```
Single object icon: a heavy, ornate war-helm with layered iron plating
and a brute-core fragment set into the brow as a subtle glowing accent,
centered on a flat pure black (#000000) background for easy cutout. No
text, no numerals, no border, no frame. Compact, simple silhouette
readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant plate
tone, Sanctum Amber (#C8801A) as the core glow and trim, parchment cream
(#F5EDCB) as a sharp specular highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

## 4. Warlord's Battleplate (T4 Chest — `warlords_battleplate.tres`)

```
Single object icon: an ornate boss-signature battle cuirass, etched
warlord sigils across the chest plate and a small warlord-emblem badge at
the collar, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant plate
tone, Sanctum Amber (#C8801A) as the etched sigils and painted glow,
parchment cream (#F5EDCB) as a sharp specular highlight. No Herald Gold,
no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

## 5. Lurker Claw Gauntlets (T3 Gloves — `lurker_claw_gauntlets.tres`)

```
Single object icon: leather gauntlets stained dark amber-brown with
lurker ichor, tipped with small curved claw-like reinforcement plates at
the knuckles, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Compact, simple
silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant ichor-stained
leather tone (explicitly not green), muted fieldstone grey (#7E8590) as
the claw plates, parchment cream (#F5EDCB) as a small specular highlight.
No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

## 6. Goblin Raider Leggings (T3 Pants — `goblin_raider_leggings.tres`)

```
Single object icon: leather leggings reinforced with tanned goblin-hide
patches and a small curved fang trophy laced at the hip, centered on a
flat pure black (#000000) background for easy cutout. No text, no
numerals, no border, no frame. Compact, simple silhouette readable at
small size.

Color palette: Sanctum Amber (#C8801A) as the dominant leather tone,
parchment cream (#F5EDCB) as the fang trophy, muted fieldstone grey
(#7E8590) as the lacing and buckles. No Herald Gold, no purple, no green,
no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

## 7. Sentinel's Striders (T4 Boots — `sentinels_striders.tres`)

```
Single object icon: ornate armored boots with rift-shard crystal accents
set into the shin plating, radiating a warm inner glow, centered on a
flat pure black (#000000) background for easy cutout. No text, no
numerals, no border, no frame. Compact, simple silhouette readable at
small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant plate
tone, Sanctum Amber (#C8801A) as the crystal glow and trim, parchment
cream (#F5EDCB) as a sharp specular highlight. No Herald Gold, no purple,
no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

## 8. Warlord's Standard Amulet (T4 Neck — `warlords_standard_amulet.tres`)

```
Single object icon: an ornate amulet centered on a small warlord-emblem
medallion hung from a battle-worn iron chain, centered on a flat pure
black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Compact, simple silhouette readable at small size.

Color palette: Sanctum Amber (#C8801A) as the dominant medallion tone,
parchment cream (#F5EDCB) as raised-relief highlights on the emblem,
muted fieldstone grey (#7E8590) as the chain. No Herald Gold, no purple,
no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

## 9. Brute Core Band (T4 Ring — `brute_core_band.tres`)

```
Single object icon: a heavy worked-iron ring set with a small glowing
brute-core fragment as its centerpiece stone, centered on a flat pure
black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Compact, simple silhouette readable at small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant band tone,
Sanctum Amber (#C8801A) as the core's warm glow, parchment cream
(#F5EDCB) as a small specular highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set.
```

---

## Next steps once generated

1. Drop the resulting image(s) into `assets/source/items/`, named after the
   item id (e.g. `sentinels_lance.png`, `brute_core_band.png`).
2. Claude alpha-cuts each icon (flood-fill technique, `edge_threshold=8`
   per this project's established finding for painterly renders), spot-
   checks against a bright/magenta backdrop, and archives the processed
   result to `assets/art/items/`.
3. Claude adds `icon = preload("res://assets/art/items/<name>.png")` to
   the matching `.tres` file under `assets/data/items/` — no other code
   changes needed, all 9 backend item/recipe resources already exist and
   load-clean.
4. Live-verify via Godot MCP / run the Equipment Forge test suite if
   testing is in scope that pass, commit.
