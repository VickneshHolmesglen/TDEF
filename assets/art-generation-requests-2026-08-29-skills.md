# Skill Icon Art — Generation Batch, 2026-08-29 (13 icons)

Standalone, upload-ready prompt batch for ChatGPT (or another image
generator). Covers all 13 items from
`design/art/missing-assets-audit-2026-08-29.md` §5 — the Hero Skill Build
catalogue (`assets/data/skills/definitions/*.tres`). Zero skill had an icon
until `SkillDefinitionResource` gained a real `icon: Texture2D` field
(committed alongside this batch) — see that class's doc comment.

**This is the exact surface two other systems are already waiting on**, not
just Mission HUD's skill-slot tiles:
- `mission_hud.gd`'s 40×40 skill-slot icon buttons (Pattern 12) currently show
  a numbered placeholder face — see its own `_build_skill_slots()` doc
  comment.
- `tower_mastery_arc.gd`'s in-world proximity arc center glyph currently draws
  a placeholder filled circle — its own doc comment says explicitly: *"no
  real per-archetype glyph asset catalogue exists yet ... swap `_draw_glyph()`'s
  body when real glyph assets land."* Once these 13 icons exist, that
  placeholder can resolve to the real per-skill icon instead of inventing a
  separate 4-archetype glyph set — same content, one less asset category.

**Wiring either consumer to actually render these icons is separate,
unscoped follow-up work** — this batch only produces and processes the art
and adds it to each skill's data file, matching this project's established
"content can lag code" tolerance (same pattern the materials-icon and
equipment-icon batches used).

## Critical constraints — read before generating anything

**Smaller render scale than any other icon batch so far** — these render at
Mission HUD's 40×40 skill-slot tiles (smaller than the ~64×64 Inventory
slot every other icon batch targets) and inside Tower Mastery's small
world-space arc glyph. **Bold, high-contrast, silhouette-first symbol
design** — simplify further than the item-icon batches' level of surface
detail; a single clean glyph shape must read correctly at both sizes and
from the game's default oblique camera distance (art bible's Play-Angle
Contract).

**Physical/Ranged/Support skills** use the same structural palette as
equipment/tower-component icons (weapon-and-armor language, not elemental):
- Fieldstone Grey `#7E8590` — metal/weapon body
- Sanctum Amber `#C8801A` — trim, warm highlight
- Parchment Cream `#F5EDCB` — specular highlight

**Elemental skills** use the already-shipped elemental-tower color language
(`elemental_tower_collection.png`'s per-element description, reused verbatim
for consistency — see `design/art/asset-generation-prompts.md`), not the
structural palette:
- Fire: warm orange (explicitly NOT deep crimson red — Threat Crimson
  `#BE2020` is reserved for damage-taken/danger)
- Frost: pale blue (explicitly NOT saturated cyan — cyan is UI-reserved)
- Poison/Venom: faint, desaturated sickly-green vapor (explicitly must not
  read as the game's reserved healing-green)
- Arcane: warm parchment-white radiant burst with amber trim, NOT purple
  (purple is boss-reserved in this project)
- Storm: pale warm white-gold electric spark, NOT cyan/blue-cyan and NOT
  Herald Gold

**Universal:** no Herald Gold (`#F5C01A`) anywhere — rarity/reward signaling
is a separate UI concern. No text, no numerals baked in.

**Shared composition:** single bold glyph/symbol, centered on a flat pure
black (`#000000`) background for easy cutout. No border, no frame. Extremely
simple, high-contrast silhouette — legible even smaller than this project's
other icon batches.

**Style:** hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, matching this project's existing
UI icon set — but simplified toward bold shape-first clarity over fine
surface detail, given the smaller render scale.

---

## Physical (3)

### 1. Cleave (`phys_cleave.tres`)

```
Single bold glyph icon: a diagonal sword-slash symbol — a single curved
blade-arc with a short motion-trail behind it, reading clearly as a wide
sweeping strike, centered on a flat pure black (#000000) background for
easy cutout. No text, no numerals, no border, no frame. Extremely simple,
bold, high-contrast silhouette, legible at very small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant blade
tone, Sanctum Amber (#C8801A) as the motion-trail accent, parchment cream
(#F5EDCB) as a thin edge highlight. No Herald Gold, no purple, no green,
no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture, bold shape-first clarity over fine detail.
```

### 2. Bulwark (`phys_bulwark.tres`)

```
Single bold glyph icon: a squared tower-shield symbol, front-facing,
simple and blocky, reading clearly as a defensive stance, centered on a
flat pure black (#000000) background for easy cutout. No text, no
numerals, no border, no frame. Extremely simple, bold, high-contrast
silhouette, legible at very small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant shield-
body tone, Sanctum Amber (#C8801A) as the rim trim, parchment cream
(#F5EDCB) as a small specular highlight. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture, bold shape-first clarity over fine detail.
```

### 3. Siegebreaker (`phys_siegebreaker.tres`)

```
Single bold glyph icon: a heavy warhammer symbol striking downward with
a small angular impact-burst at its head, reading clearly as a crushing
blow, centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame. Extremely simple,
bold, high-contrast silhouette, legible at very small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant hammer-
head tone, Sanctum Amber (#C8801A) as the haft and impact-burst accent,
parchment cream (#F5EDCB) as a small specular highlight. No Herald Gold,
no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture, bold shape-first clarity over fine detail.
```

## Ranged (2)

### 4. Piercing Shot (`rng_piercing_shot.tres`)

```
Single bold glyph icon: a single straight arrow piercing cleanly through
a small ring/target shape, reading clearly as precision penetration,
centered on a flat pure black (#000000) background for easy cutout. No
text, no numerals, no border, no frame. Extremely simple, bold, high-
contrast silhouette, legible at very small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant arrow-
shaft tone, Sanctum Amber (#C8801A) as the ring/target accent, parchment
cream (#F5EDCB) as a small specular highlight on the arrowhead. No
Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture, bold shape-first clarity over fine detail.
```

### 5. Volley (`rng_volley.tres`)

```
Single bold glyph icon: three arrows fanned outward from one common
point, reading clearly as a spread shot, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border,
no frame. Extremely simple, bold, high-contrast silhouette, legible at
very small size.

Color palette: muted fieldstone grey (#7E8590) as the dominant arrow-
shaft tone, Sanctum Amber (#C8801A) as the fletching accents, parchment
cream (#F5EDCB) as small specular highlights on the arrowheads. No
Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture, bold shape-first clarity over fine detail.
```

## Elemental (6)

### 6. Firebolt (`elem_firebolt.tres`)

```
Single bold glyph icon: one sharp, single tapered flame-bolt shape,
reading clearly as a focused fire projectile, centered on a flat pure
black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Extremely simple, bold, high-contrast silhouette,
legible at very small size.

Color palette: warm orange flame color as the dominant tone (explicitly
NOT deep crimson red — this is elemental fire flavor, not the game's
reserved damage-red), a small dull-ember glow at the base. No Herald
Gold, no purple, no green, no cyan, no saturated red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture, bold shape-first clarity over fine detail.
```

### 7. Frostbolt (`elem_frostbolt.tres`)

```
Single bold glyph icon: one sharp, single angular ice-shard bolt shape,
reading clearly as a focused frost projectile, centered on a flat pure
black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Extremely simple, bold, high-contrast silhouette,
legible at very small size.

Color palette: pale blue as the dominant ice tone (explicitly not
saturated cyan — cyan is UI-reserved), a faint cool white-blue highlight
at the tip. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture, bold shape-first clarity over fine detail.
```

### 8. Firestorm (`elem_firestorm.tres`)

```
Single bold glyph icon: a swirling radial cluster of several small
flame shapes circling one center point, reading clearly as a wider
area-of-effect burn (distinct from Firebolt's single focused bolt),
centered on a flat pure black (#000000) background for easy cutout. No
text, no numerals, no border, no frame. Extremely simple, bold, high-
contrast silhouette, legible at very small size.

Color palette: warm orange flame color as the dominant tone (explicitly
NOT deep crimson red), a small dull-ember glow at the swirl's center. No
Herald Gold, no purple, no green, no cyan, no saturated red.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture, bold shape-first clarity over fine detail.
```

### 9. Storm (`elem_storm.tres`)

```
Single bold glyph icon: one jagged lightning-bolt shape, reading
clearly as a storm/electric strike, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border,
no frame. Extremely simple, bold, high-contrast silhouette, legible at
very small size.

Color palette: pale warm white-gold electric spark as the dominant tone
(explicitly not cyan/blue-cyan and not Herald Gold — a warm-white spark,
not a cool electric-blue one), a faint amber undertone along the bolt's
edge. No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture, bold shape-first clarity over fine detail.
```

### 10. Arcane Surge (`elem_arcane.tres`)

```
Single bold glyph icon: a radiant six-point star/burst shape, reading
clearly as a surge of raw arcane energy, centered on a flat pure black
(#000000) background for easy cutout. No text, no numerals, no border,
no frame. Extremely simple, bold, high-contrast silhouette, legible at
very small size.

Color palette: warm parchment-white (#F5EDCB) as the dominant radiant
core, Sanctum Amber (#C8801A) as the outer trim/rays (explicitly NOT
purple — purple is boss-reserved in this project). No Herald Gold, no
purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture, bold shape-first clarity over fine detail.
```

### 11. Venom (`elem_venom.tres`)

```
Single bold glyph icon: a single venom droplet shape with a small
curved fang silhouette behind it, reading clearly as a poison strike,
centered on a flat pure black (#000000) background for easy cutout. No
text, no numerals, no border, no frame. Extremely simple, bold, high-
contrast silhouette, legible at very small size.

Color palette: a faint, desaturated sickly-green vapor tone as the
dominant droplet color, kept deliberately muted and desaturated — do not
let it read as the game's reserved healing-green — a small parchment
cream (#F5EDCB) highlight on the fang. No Herald Gold, no purple, no
saturated green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture, bold shape-first clarity over fine detail.
```

## Support (2)

### 12. Rally (`sup_rally.tres`)

```
Single bold glyph icon: a small triangular banner/pennant shape with a
rising arrow overlaid on it, reading clearly as a morale/buff call,
centered on a flat pure black (#000000) background for easy cutout. No
text, no numerals, no border, no frame. Extremely simple, bold, high-
contrast silhouette, legible at very small size.

Color palette: Sanctum Amber (#C8801A) as the dominant banner tone,
parchment cream (#F5EDCB) as the arrow and banner highlight, muted
fieldstone grey (#7E8590) as the pole. No Herald Gold, no purple, no
green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture, bold shape-first clarity over fine detail.
```

### 13. Barrier (`sup_barrier.tres`)

```
Single bold glyph icon: a curved protective dome/ward-arc shape,
reading clearly as a defensive shield field, centered on a flat pure
black (#000000) background for easy cutout. No text, no numerals, no
border, no frame. Extremely simple, bold, high-contrast silhouette,
legible at very small size.

Color palette: Sanctum Amber (#C8801A) as the dominant arc tone,
parchment cream (#F5EDCB) as a soft inner-glow highlight along the arc,
muted fieldstone grey (#7E8590) used sparingly at the arc's base only.
No Herald Gold, no purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture, bold shape-first clarity over fine detail.
```

---

## Next steps once generated

1. Drop the resulting image(s) into `assets/source/items/`, named after the
   skill id (e.g. `phys_cleave.png`, `elem_arcane.png`).
2. Claude alpha-cuts each icon (flood-fill technique), spot-checks against a
   bright backdrop, and archives the processed result to `assets/art/items/`
   (shared with every other icon batch — skills aren't a separate art tree).
3. Claude adds `icon = preload("res://assets/art/items/<name>.png")` to the
   matching `.tres` file under `assets/data/skills/definitions/` — the
   `icon` field already exists on `SkillDefinitionResource` (added
   2026-08-29), no further schema change needed.
4. Wiring `mission_hud.gd`'s skill-slot tiles and/or `tower_mastery_arc.gd`'s
   center glyph to actually render this icon is separate, unscoped follow-up
   work — not implied by this step.
5. Live-verify via Godot MCP if testing is in scope that pass, commit.
