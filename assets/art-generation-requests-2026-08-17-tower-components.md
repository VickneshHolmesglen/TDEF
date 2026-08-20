# Tower Components — Base / Shaft / Top Art Split

**Why this batch exists:** Tower Assembly (`src/core/tower_assembly/tower_assembly.gd`,
shipped 2026-08-14, extended 2026-08-17 with blueprint-sourced components)
lets the player mix a Foundation/Weapon/Focus/Power from *different* source
towers into one new custom tower. The 6 existing tower sprites
(`tower_physical_base.png`, `tower_ranged_base.png`, `tower_support_base.png`,
`tower_elem_fire.png`, `tower_elem_ice.png`, `tower_elem_poison.png`) are each
one flat composite image — there is no way to render "this tower's Foundation
paired with that tower's Weapon" today. This batch produces separately
croppable **base / shaft / top** layers so a custom-assembled tower can be
rendered by stacking the right layer for each of its actual components,
instead of always falling back to one fixed archetype sprite regardless of
what it's actually built from.

**Layer mapping to game data** (why 3 layers, not 4, and why some towers
share a layer):
- **Base** = pedestal only. Every one of the 6 existing tower sprites already
  uses the *same* hexagonal wood-and-stone pedestal with a gold-trimmed
  blank plaque (confirmed by re-reading the 2026-08-02 regeneration prompts
  — "All 4 tower archetypes now share one consistent pixel-art style and
  pedestal design"). One shared, archetype-neutral Base layer is correct
  here, not six near-duplicates — it corresponds loosely to
  `FoundationComponent` existing at all, not to its specific stats.
- **Shaft** = the structural body. Physical/Ranged/all 3 Elemental variants
  already share one solid brick-tower-body template in the existing art (the
  "Reference style to match" block every 2026-08 tower prompt reused
  verbatim) — one **Solid** Shaft prompt covers all 5. Support (Rally
  Banner) is structurally different — open timber framework, not a solid
  brick body, required by art bible §3.1.3 Rule 3's 30%-negative-space rule
  — so it needs its own **Open** Shaft prompt. 2 Shaft prompts total, not 6.
- **Top** = the part that actually varies per tower today: roof shape, the
  weapon/effect feature (crossbow, blue banner flag, elemental flame/ice/
  poison topper), or the Support banner-and-pennants assembly. This is
  where `WeaponComponent.element` and each tower's distinguishing feature
  live visually — 6 separate Top prompts, one per existing tower.

**Total: 9 generations (1 Base + 2 Shafts + 6 Tops), not 18** — reuses the
real shared structure already present in this project's art instead of
redundantly regenerating identical pedestals/bodies 6 times over.

**Open technical risk, not resolved by this prompt batch — flagged, not
hidden:** independently-generated layers need a consistent anchor
convention (e.g. a fixed canvas height/width per layer, bottom-edge-aligned)
so Godot can stack Base→Shaft→Top back into one coherent tower at runtime
without per-tower manual offset tuning. This batch does not solve that —
it only produces the raw layer art. Confirm a canvas/anchor convention
before wiring these into `TowerInstance.gd`, ideally by generating and
test-compositing just the Physical set (Base + Solid Shaft + Physical Top)
first before running the rest of the batch.

**If your generator supports image-input/edit mode** (ChatGPT's does via
GPT-image), attach `assets/art/towers/tower_physical_base.png` alongside
each prompt below and ask it to match that exact rendering style, extracting
only the specified layer — this will get a much closer style/proportion
match than the text description alone. If text-only, the style description
in each prompt is the fallback.

**Critical technical requirement — background and shadow contrast** (same
lesson as every prior tower batch in `design/art/asset-generation-prompts.md`):
render the background as a single flat, uniform, solid near-black color with
no soft vignette or gradient falloff. Any shadow/ambient-occlusion shading on
the piece must stay clearly and consistently distinguishable in tone from the
background color — a hard boundary all the way around the silhouette,
including underneath it, so it can be cleanly cut out with this project's
existing color-key/flood-fill alpha-cut tooling.

**Each piece must be generated in isolation** — the specified layer only,
cropped tight, NOT shown attached to or resting on the rest of the tower.
Treat each prompt as if photographing a single detached prop piece.

---

## 1. Base (shared, all towers)

```
Isometric fantasy game asset, a single detached tower BASE/PEDESTAL only —
NOT attached to any tower body, shaft, or roof above it. A hexagonal
wood-and-stone pedestal, muted fieldstone grey (#7E8590) stone with warm
Sanctum Amber (#C8801A) trim accents, a thick gold-trimmed rectangular
plaque frame recessed into the front face (leave the plaque interior blank,
no text). Individually-painted brick/stone-block texture, each block with
its own light/shadow value, not smooth-shaded. The TOP surface of the
pedestal (where a tower shaft would normally be mounted) must be clearly
visible, flat, and unobstructed — this is a base piece meant to have other
pieces stacked on top of it later. Centered on a plain flat near-black
background for easy cutout (no soft vignette/gradient — solid flat color
only). Any shadow/ambient-occlusion shading must stay clearly distinguishable
in tone from the background, with a hard boundary around the entire
silhouette including underneath the pedestal. Painterly pixel-art,
hand-painted miniature diorama style, fixed oblique isometric angle. Avoid
green, red, purple, or cyan anywhere.
```

**Constraint mapping:**
- "hexagonal wood-and-stone... plaque frame... blank, no text" → copied
  verbatim from the 2026-08-02 regeneration prompts' shared "Reference style
  to match" block — this must be the *same* pedestal already established,
  not a redesign.
- "top surface... clearly visible, flat, unobstructed" → new for this batch;
  the whole point is other layers mount on top of this one.
- Color/style/background clauses → same rationale as every prior tower
  prompt in this log (Sanctum Amber trim, fieldstone grey stone, hard
  shadow/background contrast for alpha-cutting).

---

## 2. Shaft — Solid (Physical, Ranged, all 3 Elemental variants)

```
Isometric fantasy game asset, a single detached tower SHAFT/BODY only — NOT
attached to any pedestal below it or roof above it, and not showing a roof,
weapon, banner, or any elemental effect. A rounded stone tower trunk with
visible individually-painted brick/stone-block texture (each block has its
own light/shadow value, not smooth-shaded), a small arched window opening,
muted fieldstone grey (#7E8590) stone with warm Sanctum Amber (#C8801A) trim
accents. The BOTTOM edge must be flat and unobstructed (sits on a base
piece) and the TOP edge must also be flat and unobstructed (a roof/weapon
piece mounts here) — no taper to a point, no roof cap, no decoration at
either end. No glow, no particle effects, no elemental color theming, no
crossbow, no banner — this is a completely neutral structural piece other
pieces attach to. Centered on a plain flat near-black background for easy
cutout (no soft vignette/gradient — solid flat color only). Any shadow/
ambient-occlusion shading must stay clearly distinguishable in tone from the
background, with a hard boundary around the entire silhouette. Painterly
pixel-art, hand-painted miniature diorama style, fixed oblique isometric
angle. Avoid green, red, purple, or cyan anywhere.
```

**Constraint mapping:**
- "rounded stone tower trunk... arched window... brick texture" → the
  shared body template already used for Physical/Ranged/all 3 Elemental
  towers per the 2026-08-02 regeneration ("Reference style to match").
- "top and bottom edges flat and unobstructed... no roof cap... no
  decoration" → new for this batch; a mountable middle piece must not
  pre-bake a roof or base shape into itself.
- "no elemental color theming" → deliberately keeps the Shaft archetype-
  neutral; element (fire/frost/poison) lives on the Top layer only, matching
  `WeaponComponent.element` being a Weapon-owned field, not a Foundation one.

---

## 3. Shaft — Open (Support / Rally Banner only)

```
Isometric fantasy game asset, a single detached tower SHAFT/FRAME only — NOT
attached to any pedestal below it or banner/pennants above it. An open
wooden-and-stone support framework — NOT a solid enclosed body: open timber
support beams with no walls between them, at least 30% of the silhouette
empty/open negative space, visible straight through the frame. Same
construction material and texture language as a matched stone tower series
(muted fieldstone grey #7E8590 stone at the framework's base, warm Sanctum
Amber #C8801A trim on the timber), individually-painted brick/stone-block
texture where stone is present, not smooth/painterly rendering. The BOTTOM
edge must be flat and unobstructed (sits on a base piece) and the TOP edge
must also be flat and unobstructed (a banner/pennant piece mounts here) — no
banner, no pennants, no flag fabric of any kind in this piece, framework
only. Soft warm amber glow rising through the open framework suggesting a
buff/blessing aura, kept subtle (below 30% opacity feel, atmospheric not
blinding). Centered on a plain flat near-black background for easy cutout
(no soft vignette/gradient — solid flat color only). Any shadow/ambient-
occlusion shading must stay clearly distinguishable in tone from the
background, with a hard boundary around the entire silhouette. Painterly
pixel-art, hand-painted miniature diorama style, fixed oblique isometric
angle. Avoid green, red, purple, or cyan anywhere.
```

**Constraint mapping:**
- "at least 30% empty/open negative space" → art bible §3.1.3 Rule 3
  (Support towers, non-negotiable), copied from the existing Rally Banner
  prompt.
- "no banner, no pennants... framework only" → new for this batch; the
  banner assembly is the Support archetype's Top layer, not its Shaft.
- Amber glow clause → carried over from the existing Rally Banner prompt,
  kept subtle per art bible's existing glow-opacity rule (§ referenced in
  the original prompt's constraint mapping).

---

## 4. Top — Physical (Steelwood Siege Spire / `blueprint_archer`)

```
Isometric fantasy game asset, a single detached tower TOP/ROOF piece only —
NOT attached to any shaft or pedestal below it. A conical tiled roof cap
sized to mount on a stone tower shaft, a thin flagpole with a small pennant
at the peak, muted fieldstone grey (#7E8590) roof tiles with warm Sanctum
Amber (#C8801A) trim. Mounted on the roof's firing platform: a visible
mounted crossbow or light ballista, aimed outward, as the one distinguishing
feature — reinforcing "physical/kinetic damage," not magic. No glow, no
particle effects, no elemental color theming of any kind — reads as plain,
sturdy, mechanical. The BOTTOM edge must be flat and unobstructed (mounts on
a shaft piece). Centered on a plain flat near-black background for easy
cutout (no soft vignette/gradient — solid flat color only). Any shadow/
ambient-occlusion shading must stay clearly distinguishable in tone from the
background, with a hard boundary around the entire silhouette. Painterly
pixel-art, hand-painted miniature diorama style, fixed oblique isometric
angle. Avoid green, red, purple, or cyan anywhere.
```

## 5. Top — Ranged (`blueprint_longshot_sniper`)

```
Isometric fantasy game asset, a single detached tower TOP/ROOF piece only —
NOT attached to any shaft or pedestal below it. A conical tiled roof cap
sized to mount on a stone tower shaft, a thin flagpole flying a small plain
blue pennant at the peak, muted fieldstone grey (#7E8590) roof tiles with
warm Sanctum Amber (#C8801A) trim. No mounted weapon visible, no glow, no
particle effects, no elemental color theming — a plain roof cap with only
the blue banner as its distinguishing feature (this archetype's ranged
precision is expressed through gameplay range, not a visible weapon prop).
The BOTTOM edge must be flat and unobstructed (mounts on a shaft piece).
Centered on a plain flat near-black background for easy cutout (no soft
vignette/gradient — solid flat color only). Any shadow/ambient-occlusion
shading must stay clearly distinguishable in tone from the background, with
a hard boundary around the entire silhouette. Painterly pixel-art,
hand-painted miniature diorama style, fixed oblique isometric angle. Avoid
green, red, purple, or cyan anywhere.
```

## 6. Top — Support (Golden Banner Shrine / `blueprint_rally_banner`)

```
Isometric fantasy game asset, a single detached tower TOP piece only — NOT
attached to any shaft/frame below it. A central raised banner pole flying a
large flowing amber-and-gold heraldic banner, two smaller flanking pennant
poles with open trailing streamers extending outward left and right —
reinforcing an open, radiating, welcoming shape, not symmetrical closed
walls. Warm amber-gold (#C8801A) trim, parchment cream (#F5EDCB) banner
highlights, Herald Gold (#F5C01A) accents on the aura glow only. Soft golden
aura glow, no particle explosion, just warm ambient radiance. The BOTTOM
edge must be flat and unobstructed (mounts on an open-frame shaft piece).
Centered on a plain flat near-black background for easy cutout (no soft
vignette/gradient — solid flat color only). Any shadow/ambient-occlusion
shading must stay clearly distinguishable in tone from the background, with
a hard boundary around the entire silhouette. Painterly pixel-art,
hand-painted miniature diorama style, fixed oblique isometric angle. Avoid
green, red, purple, or cyan anywhere except the specified amber/gold/cream.
```

## 7. Top — Elemental: Fire (Firebolt Turret)

```
Isometric fantasy game asset, a single detached tower TOP/ROOF piece only —
NOT attached to any shaft or pedestal below it. A conical tiled roof cap
sized to mount on a stone tower shaft, wreathed in stylized flames rising
from the roof's peak and licking down over the tile edges — warm orange
flame color (NOT deep red — this is elemental fire flavor, not the game's
reserved damage-red), with a small dull-ember glow at the flame's base. A
thin flagpole with a small pennant may be present but is secondary to the
flame effect. The BOTTOM edge must be flat and unobstructed (mounts on a
shaft piece). Centered on a plain flat near-black background for easy
cutout (no soft vignette/gradient — solid flat color only). Any shadow/
ambient-occlusion shading must stay clearly distinguishable in tone from the
background, with a hard boundary around the entire silhouette. Painterly
pixel-art, hand-painted miniature diorama style, fixed oblique isometric
angle. Avoid purple, cyan, green, and especially deep crimson red.
```

## 8. Top — Elemental: Frost (Frostbolt Turret)

```
Isometric fantasy game asset, a single detached tower TOP/ROOF piece only —
NOT attached to any shaft or pedestal below it. A conical tiled roof cap
sized to mount on a stone tower shaft, capped in pale-blue icicles hanging
from the roof's edge and a light frost-rime dusting the tiles, a faint cool
white-blue mist wisping from the peak. A thin flagpole with a small pennant
may be present but is secondary to the ice effect. The BOTTOM edge must be
flat and unobstructed (mounts on a shaft piece). Centered on a plain flat
near-black background for easy cutout (no soft vignette/gradient — solid
flat color only). Any shadow/ambient-occlusion shading must stay clearly
distinguishable in tone from the background, with a hard boundary around
the entire silhouette. Painterly pixel-art, hand-painted miniature diorama
style, fixed oblique isometric angle. Avoid purple, red, green, and cyan
(pale blue only, not saturated cyan).
```

## 9. Top — Elemental: Poison (Venomdart Turret)

```
Isometric fantasy game asset, a single detached tower TOP/ROOF piece only —
NOT attached to any shaft or pedestal below it. A conical tiled roof cap
sized to mount on a stone tower shaft, topped with a large purple
spotted-mushroom cap growing from the peak, a faint sickly-green vapor
wisping upward from beneath it. A thin flagpole with a small pennant may be
present but is secondary to the mushroom/vapor effect. The BOTTOM edge must
be flat and unobstructed (mounts on a shaft piece). Centered on a plain flat
near-black background for easy cutout (no soft vignette/gradient — solid
flat color only). Any shadow/ambient-occlusion shading must stay clearly
distinguishable in tone from the background, with a hard boundary around
the entire silhouette. Painterly pixel-art, hand-painted miniature diorama
style, fixed oblique isometric angle. Keep the sickly-green vapor faint and
desaturated — do not let it read as the game's reserved healing-green.
```

**Constraint mapping (Tops 4-9):**
- Roof/flagpole/pennant base description → carried from the existing
  Physical/Ranged prompts verbatim (same roof silhouette family).
- Physical's crossbow/ballista, Ranged's plain blue pennant, Support's
  banner-and-pennants → each tower's one existing distinguishing feature,
  isolated into its own detachable piece instead of redescribed as part of
  a whole-tower prompt.
- Fire/Frost/Poison color specs → matches the already-generated/approved
  `elemental_tower_collection.png` sheet's per-element description ("Fire
  orange/red flames," "Ice pale blue icicles," "Poison purple spotted
  mushroom cap") — same 3 elements this project has already committed to.
- "NOT deep red" (Fire) / "not saturated cyan" (Frost) / "not... healing-
  green" (Poison) → art bible §4.2's critical constraints: Threat Crimson
  (#BE2020) is reserved for damage-taken/danger, Verdant Green (#25813A) is
  reserved for healing — decorative elemental flavor must stay visually
  distinct from those reserved meanings even when the theme is
  thematically adjacent (fire is warm/orange, poison is green-adjacent).
