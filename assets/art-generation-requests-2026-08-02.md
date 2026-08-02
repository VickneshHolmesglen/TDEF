# Art Generation Requests — Batch 2026-08-02

This file is meant to be uploaded directly into ChatGPT (or pasted prompt-by-prompt).
Generate each image, save it, and drop the files into the `assets/` folder — Claude
will handle slicing, alpha-cutting, and wiring them into the game from there.

**General rules that apply to every prompt below** (already baked into each one,
listed here so you know why they're phrased this way):
- Single object, centered, on a plain dark or plain-color background — makes
  clean cutout possible. Do NOT ask for a background scene/environment.
- Painterly pixel-art style, hand-painted "miniature cabinet diorama" look —
  not flat vector, not photorealistic, not chibi/cartoon-cute.
- Fixed oblique isometric angle (same angle a tabletop miniature would be
  viewed from), consistent with every other asset already in the game.
- Reserved colors — **never** use these for anything except what's listed,
  or the asset will visually lie about what it does in-game:
  - Green → healing/restoration only
  - Red (blood-red, not warm orange/amber) → damage/danger only
  - Purple → boss-encounter escalation only
  - Cyan → UI-only, never appears in the game world

---

## 1. Monsters (7 needed — zero exist today)

Every monster in the game's data is fully designed (stats, waves, drop tables)
but has **no art at all** — the game currently runs these entirely headless.
Silhouette rules below come straight from the art bible and are what makes a
Standard/Elite/Boss readable as a threat tier at a glance, before the player
reads a health bar.

> **Batch 1 review note (2026-08-02)**: the 4 monsters generated so far all
> passed their individual tier/color rules, but came back in a soft
> painterly/concept-art render rather than the blocky pixel-art brick style
> the towers use — arguably closer to the art bible's own Bastion reference
> (§9) than the towers are, but it means there are now two different
> "acceptable" rendering registers in the project. Worth a deliberate call
> before generating more, not something to silently pick a side on.

### Standard tier (3) — compact, low, non-threatening individually; menacing in a swarm
Shape rule: shorter than tall, no protrusion above the horizontal midline of
the body, clean simple outline. Budget: silhouette + one color zone + one
specular highlight only — these get seen ×20-30 on screen at once, so they
must stay simple.

**Goblin Runner** (fast, hp-light skirmisher) — **Status: Generated ✅** (`Goblin Runner with Curved Dagger.png`, 2026-08-02)
```
Isometric fantasy game monster asset, "Goblin Runner", single creature
centered on a plain dark background for easy cutout. Small, wiry green-skinned
goblin in light leather scraps, crouched low and lunging forward mid-sprint —
built for speed, not toughness. Silhouette must be wider than it is tall, no
part of the body rising above its own shoulder line, clean simple outline
with no spikes or protrusions. One weapon (a small curved dagger) held low.
One accent color zone only (worn red-brown leather straps) plus one specular
highlight on exposed skin — no other surface detail. Painterly pixel-art,
hand-painted miniature diorama style, fixed oblique isometric angle. Avoid
pure blood-red, purple, or cyan anywhere. The creature's own skin can be
green (this is the one approved case — green as flesh tone, not as a
heal/restoration signal — keep it a muted olive-green, not a saturated
"heal" green).
```

**Spore Skitterling** (fastest standard, base_speed 2.4) — **Status: Generated ✅** (`Spore Skitterling in Pixel Art.png`, 2026-08-02)
```
Isometric fantasy game monster asset, "Spore Skitterling", single creature
centered on a plain dark background for easy cutout. A small many-legged
fungal/insectoid creature, low and scuttling, wider than tall, clean simple
outline with no protrusion above its own shoulder line. Body reads as a
mushroom-cap fused with an insect thorax — pale mottled cap-shell on top,
skittering segmented legs beneath. One accent color zone (sickly yellow-green
spore markings — muted/desaturated olive, explicitly NOT a bright healthy
green, since green is reserved for the game's heal effect) plus one specular
highlight on the cap-shell. Painterly pixel-art, hand-painted miniature
diorama style, fixed oblique isometric angle. Avoid pure blood-red, purple,
or cyan anywhere.
```

**Armored Brute** (slowest standard, base_speed 0.9 — tanky) — **Status: Generated ✅** (`Armored Orc with Spiked Mace.png`, 2026-08-02)
```
Isometric fantasy game monster asset, "Armored Brute", single creature
centered on a plain dark background for easy cutout. A squat, heavily-built
brute in crude riveted plate armor, wider than it is tall, low center of
gravity, clean simple outline with no protrusion above its own shoulder
line despite the bulk — mass reads through width, not height. One accent
color zone (dull rust-orange armor trim) plus one specular highlight on a
metal shoulder plate. Painterly pixel-art, hand-painted miniature diorama
style, fixed oblique isometric angle. Avoid pure blood-red, purple, or cyan
anywhere.
```

### Elite tier (2) — one asymmetric protrusion breaks the bounding box
Shape rule: approaching a 1:1 height:width ratio, with exactly ONE
asymmetric feature (a horn, blade, or shoulder mass) that visibly breaks the
silhouette's own bounding box. Symmetry reads as Standard — asymmetry is
what signals Elite.

**Forest Troll** (elite, regenerating brute) — **Status: Generated ✅** (`Mossbound Troll with Gnarled Claw.png`, 2026-08-02)
```
Isometric fantasy game monster asset, "Forest Troll", single creature
centered on a plain dark background for easy cutout. A tall, moss-and-bark
covered troll, roughly as wide as it is tall. Exactly ONE asymmetric
protrusion breaking its own silhouette bounding box — a single oversized
gnarled arm/claw held out to one side, larger and higher than the rest of
the body, visibly off-balance and asymmetric (not a mirrored pair of arms).
Organic, irregular, "grown not built" shape family — no straight edges, no
right angles. Muted moss-green and bark-brown palette (this creature's own
skin/bark can be green — approved exception, keep it desaturated/mossy, not
a bright saturated "heal" green). One specular highlight on a wet bark
surface. Painterly pixel-art, hand-painted miniature diorama style, fixed
oblique isometric angle. Avoid pure blood-red, purple, or cyan anywhere.
```

**Bog Lurker** (elite, fast for its tier at base_speed 1.7)
```
Isometric fantasy game monster asset, "Bog Lurker", single creature centered
on a plain dark background for easy cutout. A lean, amphibious ambush
predator, roughly 1:1 height-to-width, low crouched stance suggesting a
sudden lunge. Exactly ONE asymmetric protrusion breaking its own silhouette
bounding box — one oversized clawed forelimb raised and extended to one
side, clearly bigger/higher than its mirror limb (not symmetrical). Organic,
irregular, "grown not built" shape family. Slick dark bog-green/grey hide
(desaturated, murky — not a bright saturated "heal" green) with pale
bioluminescent throat markings as the one accent zone, one specular
highlight on wet skin. Painterly pixel-art, hand-painted miniature diorama
style, fixed oblique isometric angle. Avoid pure blood-red, purple, or cyan
anywhere.
```

### Boss tier (2) — must visually violate the grid, read as "too large" instantly
Shape rule: tall or wide beyond a single grid cell's scale, above a 1.5:1
proportion, one dominant mass plus one secondary accent — complex but still
readable at a glance, never "busy."

**Goblin Warlord** (boss, has a ranged attack — boss_attack_range_cells 3)
```
Isometric fantasy game monster asset, "Goblin Warlord" boss, single creature
centered on a plain dark background for easy cutout. A massive goblin
chieftain, deliberately oversized relative to a normal goblin — reads as
"too large to be a standard enemy" instantly, occupying a visually large
footprint (should look like it belongs across multiple grid cells even
though gameplay collision is one cell). Heavy ornate armor assembled from
scavenged/mismatched plates, one dominant mass (a huge armored torso/gut)
plus one secondary accent (a large banner or standard mounted on its back,
echoing "warlord/commander"). Since this creature has a ranged attack, give
it one held ranged weapon (a crude thrown spear or hooked javelin) as a
readable tell. Dull green skin (approved exception, muted/desaturated, not
a bright "heal" green), dark leather and scavenged bronze/iron armor.
Painterly pixel-art, hand-painted miniature diorama style, fixed oblique
isometric angle. Avoid pure blood-red, purple, or cyan anywhere — this is
NOT the purple-tinted boss-ambient-VFX moment, just the creature's own base
design, which must stay outside the reserved purple.
```

**Rift Sentinel** (boss, ranged, slowest-moving of the two bosses)
```
Isometric fantasy game monster asset, "Rift Sentinel" boss, single creature
centered on a plain dark background for easy cutout. A tall, imposing
construct/guardian entity, deliberately oversized and visually violating a
normal grid cell's scale — should read as "too large to be standard" at a
glance. One dominant mass (a towering armored torso built from dark stone
or obsidian-like material, fused with glowing cracked seams) plus one
secondary accent (a floating or orbiting secondary element — a rune-etched
ring or shard — reinforcing its "sentinel/guardian" identity). Since it has
a ranged attack, the glowing seams/cracks should visually telegraph as its
attack source. Cracked-seam glow should be a cool blue-white or amber-gold —
explicitly NOT purple (purple is reserved exclusively for the game's
boss-encounter ambient VFX layer, not the creature's own base design) and
NOT cyan (UI-reserved). Dark grey/black stone body, angular and
"constructed" rather than organic (this is a construct, not a creature).
Painterly pixel-art, hand-painted miniature diorama style, fixed oblique
isometric angle.
```

---

## 2. Menagerie Companion Creatures (5 needed — zero exist today)

These live in the Sanctuary, not the battlefield — a different emotional
register from the monsters above. Warm, "precious and knowable" (the game's
own diorama design principle), not threatening. Same plain-background/cutout
requirement, same painterly diorama style, but soft and companionable posture
instead of aggressive.

### Tier 1 — Common

**Glimmer Hare**
```
Isometric fantasy game creature asset, "Glimmer Hare", single creature
centered on a plain dark background for easy cutout. A small, gentle hare
with a soft magical shimmer — faint pale sparkles along its fur, large
expressive ears, sitting or standing in a calm, alert-but-unthreatening
pose (ears up, one paw raised, curious rather than fleeing). Soft cream and
silvery-grey fur with a subtle pale glimmer along the fur edges (keep this
sparkle white/pale-gold, not green, not cyan). Painterly pixel-art,
hand-painted miniature diorama style, fixed oblique isometric angle, warm
and inviting rather than dramatic lighting.
```

**Mossback Toad**
```
Isometric fantasy game creature asset, "Mossback Toad", single creature
centered on a plain dark background for easy cutout. A plump, friendly toad
with a living moss-and-lichen patch growing naturally across its back like
a small garden, sitting in a calm relaxed pose. Warm earthy brown-green
skin with the moss patch as a slightly brighter accent (keep the moss a
muted sage-green, not a saturated "heal" green). Painterly pixel-art,
hand-painted miniature diorama style, fixed oblique isometric angle, warm
and inviting rather than dramatic lighting.
```

### Tier 2 — Uncommon

**Emberwing Moth**
```
Isometric fantasy game creature asset, "Emberwing Moth", single creature
centered on a plain dark background for easy cutout. A large ornate moth
with wings that look like glowing embers — warm orange/amber gradient wing
patterns with faint glowing vein-lines, wings spread in a calm resting
display pose (not aggressive), soft fuzzy body. Warm amber-orange and dark
charcoal palette (this is warm ember-orange, explicitly not the game's
reserved blood-red). Painterly pixel-art, hand-painted miniature diorama
style, fixed oblique isometric angle, warm and inviting rather than
dramatic lighting.
```

**Duskfang Fox**
```
Isometric fantasy game creature asset, "Duskfang Fox", single creature
centered on a plain dark background for easy cutout. A sleek fox with a
subtle twilight/shadow theme — deep indigo-grey fur fading to darker
smoky-purple at the tips of its ears, tail, and paws, sitting alert but
calm, one ear turned as if listening. Keep any purple use restricted to
very desaturated smoky-indigo fur tips only (nowhere near the game's
saturated reserved "boss" purple — this must read as fur-color, not a
glowing boss signal). Painterly pixel-art, hand-painted miniature diorama
style, fixed oblique isometric angle, warm and inviting rather than
dramatic lighting.
```

### Tier 3 — Rare

**Aurora Stag**
```
Isometric fantasy game creature asset, "Aurora Stag", single creature
centered on a plain dark background for easy cutout. A majestic, elegant
stag with antlers that shimmer like a soft aurora — a gentle gradient of
pale blue, soft teal, and faint lavender light along translucent-looking
antler tines, standing tall and calm, regal but gentle posture (head raised,
not aggressive). Pale silvery-white coat with the aurora-antler gradient as
the one dramatic accent. Keep the antler gradient soft and pale rather than
saturated — should read as "magical light," not as the game's reserved
cyan (UI) or purple (boss) signal colors. Painterly pixel-art, hand-painted
miniature diorama style, fixed oblique isometric angle, warm and inviting
rather than dramatic lighting — this is the rarest companion, so give it a
touch more presence/detail than the other four, but keep the same overall
restraint.
```

---

## 3. Tower Regeneration — style standardization (2 needed)

**Status (2026-08-02): 2 of 4 done.** `tower_ranged_base.png` and all 9
`tower_elem_*.png` were regenerated together as a matched set (see
`design/art/asset-generation-prompts.md` — "Towers Remade") and now share one
consistent pixel-art brick style with a redesigned hexagonal pedestal (a
thicker gold-trimmed rectangular plaque frame on the front face, up from the
old plain stone panel). `tower_physical_base.png` (a different single-image
"sticker" generation with different proportions) and `tower_support_base.png`
(painterly/soft-rendered, not pixel-art) still don't match that baseline —
these two prompts bring them in line with it.

**If your generator supports image-input/edit mode** (ChatGPT's does via
GPT-image), attach `assets/art/towers/tower_ranged_base.png` alongside the
prompt and ask it to match that exact rendering style — that will get a much
closer match than the text description alone. If text-only, the style
description below is the fallback.

**Reference style to match** (describe this if no image attach available):
a rounded stone tower with visible individually-painted brick/stone-block
texture (not smooth-shaded — each block has its own light/shadow value), a
conical tiled roof, a small arched window opening, a thin flagpole with a
small pennant at the peak, muted grey (#7E8590-ish) stone with warm
amber-gold (#C8801A-ish) trim accents, standing on a hexagonal wood-and-stone
pedestal base with a **thick gold-trimmed rectangular plaque frame (left
blank, no text) recessed into the front face**, rendered on a plain flat
near-black background.

**Critical technical requirement — background and shadow contrast** (learned
the hard way slicing the last two tower batches — see
`design/art/asset-generation-prompts.md` for the full story): render the
background as a single flat, uniform, solid dark color with no soft vignette
or gradient falloff. Any shadow/ambient-occlusion shading on the tower or
pedestal — especially on the pedestal's underside and the lower tower body —
must stay clearly and consistently distinguishable in tone from the
background color. Don't let a cast shadow fade to match the background
exactly; there must be a hard boundary all the way around the silhouette,
including underneath it, so it can be cleanly cut out with a simple
color-key tool.

**Physical archetype** (`blueprint_archer` — kinetic/ballistic weapon type)
```
Isometric fantasy game tower asset, "Physical" archetype tower, single object
centered on a plain flat near-black background for easy cutout (no soft
vignette/gradient background - solid flat color only). Match this exact
rendering style: a rounded stone tower with visible individually-painted
brick/stone-block texture (each block has its own light/shadow value, not
smooth-shaded), a conical tiled roof, a small arched window opening, a thin
flagpole with a small pennant at the peak, muted grey stone with warm
amber-gold trim accents, standing on a hexagonal wood-and-stone pedestal base
with a thick gold-trimmed rectangular plaque frame recessed into the front
face (leave the plaque interior blank, no text). This tower is a
kinetic/ballistic weapon platform (no elemental theming, no magic effects) —
give it a visible mounted crossbow or light ballista on its upper platform as
the one distinguishing feature, aimed outward, reinforcing "physical/kinetic
damage" rather than magic. No glow, no particle effects, no elemental color
theming of any kind — this archetype reads as plain, sturdy, mechanical.
Any shadow or ambient-occlusion shading on the tower/pedestal must stay
clearly distinguishable in tone from the background color, with a hard
boundary around the entire silhouette (including underneath the pedestal) -
do not let shadows fade to match the background. Painterly pixel-art,
hand-painted miniature diorama style, fixed oblique isometric angle. Avoid
green, red, purple, or cyan anywhere.
```

**Support archetype** (`blueprint_rally_banner` — damage-buff aura, radius 3 cells)
```
Isometric fantasy game tower asset, "Rally Banner" support structure, single
object centered on a plain flat near-black background for easy cutout (no
soft vignette/gradient background - solid flat color only). Match this exact
rendering style: individually-painted brick/stone-block texture (each block
has its own light/shadow value, not smooth-shaded), muted grey stone with
warm amber-gold trim accents, standing on a hexagonal wood-and-stone
pedestal base with a thick gold-trimmed rectangular plaque frame recessed
into the front face (leave the plaque interior blank, no text) — same
construction material and texture language as a matched stone tower series,
NOT smooth/painterly rendering. Structurally this must NOT be a solid
enclosed tower — it's an open timber-framed banner platform: stone pedestal
base, open wooden support beams with no walls between them (at least 30% of
the silhouette must be empty/open negative space, visible straight through
the frame to the pedestal floor behind), a central raised banner pole flying
an amber-and-gold heraldic banner, two smaller flanking pennant poles with
open trailing streamers extending outward left and right. Soft warm amber
glow rising from the pedestal floor suggesting a buff/blessing aura, kept
subtle (below 30% opacity feel, atmospheric not blinding) and clearly
distinguishable from the background rather than blending into it. Any
shadow/ambient-occlusion shading must stay clearly distinguishable in tone
from the background color, with a hard boundary around the entire
silhouette (including underneath the pedestal) - do not let shadows fade to
match the background. Painterly pixel-art, hand-painted miniature diorama
style with the same blocky stone texture as the reference, fixed oblique
isometric angle. Avoid green, red, purple, or cyan anywhere.
```

---

## Not included in this batch (different pipeline, not suited to ChatGPT image gen)

- **Hero** — the game's one 3D asset (glTF/.glb model), needs an actual 3D
  DCC tool (Blender etc.), not a 2D image generator.
- **Environment/terrain tiles** — need true seamless tiling, which
  general-purpose image generators handle poorly; better suited to a
  dedicated tileset workflow.
- **VFX** (crit flash, heal burst, boss ambient push) — these are frame
  sequences/particle-driven, not single static images.
- **Habitat tier 4** — parked; no design slot exists yet (habitat expansion
  is capped at 3 tiers per current design docs).
