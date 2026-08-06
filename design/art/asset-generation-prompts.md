# Asset Generation Prompts

Reference log of prompts used with external image generators for game art,
kept so a prompt can be reused, tweaked, or regenerated later without
reconstructing the art-bible constraints from scratch each time.

> **Batch request, not yet started (0/13)**: `assets/art-generation-requests-2026-08-06-materials.md`
> is a standalone, upload-ready prompt batch for the 13 real monster-drop
> material icons (`goblin_hide`, `goblin_fang`, `iron_plating`, `brute_core`,
> `lurker_ichor`, `bog_pearl`, `rift_shard`, `sentinel_core`, `spore_dust`,
> `troll_hide`, `troll_marrow`, `warlord_iron`, `warlord_emblem`) — closes
> Phase 3 of the materials-icons work (`design/quick-specs/inventory-slot-
> icons-2026-08-06.md` built the rendering mechanism against a real-but-
> empty `icon` field on all 13, so this is content-only, no code changes
> needed once each lands). **Do not use Herald Gold in the icon art itself**
> even for the 6 Rare-tier materials — rarity is signaled separately by a
> code-drawn frame (`RarityFrame`), not baked into the icon.

> **Batch request, in progress (7/22)**: `assets/art-generation-requests-2026-08-03-tarot.md`
> is a standalone, upload-ready prompt batch for the full classic 22 Major
> Arcana (`tarot_screen.gd` currently has zero card art — text-only; only
> 12 `TarotCardResource` entries are authored today, so this batch is
> deliberately art-ahead-of-content — see the file's own scope note). 7
> cards sliced clean (`assets/art/tarot/`); 3 (Lovers, Hermit, Strength)
> came back as full card mockups with baked-in frame/text and need
> regeneration (see the file's own Progress section for exact guidance);
> 12 not yet generated. Not wired into `tarot_screen.gd` yet.

> **Batch request, partially generated**: `assets/art-generation-requests-2026-08-02.md`
> is a standalone, upload-ready prompt batch. Its Section 3 (tower
> regeneration) is now fully complete — see the Steelwood Siege Spire /
> Golden Banner Shrine entry below. Section 1 (7 monsters) is 4/7 generated;
> Section 2 (5 Menagerie companions) is not started. Kept separate from this
> log since it's meant to be handed to ChatGPT directly; outcome notes get
> folded back into this file as each piece lands, same as below.

---

## Gold Coin Icon (currency HUD icon)

**Date:** 2026-08-06
**Target:** replaces the plain "Gold: N" text in Mission HUD's `GoldLabel`
and Sanctuary's `ResourceHeader` with a coin icon + number
(`design/quick-specs/gold-currency-icon-2026-08-06.md`) — the currency data/
events are already fully implemented and tested, this closes the visual
placeholder gap for the single highest-visibility currency. Materials (13
distinct types) are explicitly out of scope, a separate future batch.
**Status:** Not yet generated.

```
Single fantasy game currency icon, a stack of gold coins (2-3 coins,
slightly overlapping, top coin showing its face with a simple engraved
sigil), centered on a flat pure black (#000000) background for easy
cutout. No text, no numerals, no border, no frame — icon only, the UI
renders any surrounding chrome separately. Compact, simple silhouette
readable at small size (this is a persistent HUD icon, not a hero prop).

Color palette: Sanctum Amber (#C8801A) as the dominant coin metal color,
parchment cream (#F5EDCB) as a bright highlight/rim catching the light on
the top coin's edge, muted fieldstone grey (#7E8590) used only in the
shadowed underside/gap between coins. Do NOT use Herald Gold (#F5C01A) or
any bright saturated yellow — this is a persistent UI element, not a
crit/achievement flash. No purple, no green, no cyan.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, consistent with this project's
existing UI icon set (matches the Menagerie species portrait icons and
tarot card art already generated for this project) — warm, carved,
tactile, not a flat vector/emoji-style coin icon.
```

**Constraint mapping** (why each clause is there):
- "Do NOT use Herald Gold... this is a persistent UI element, not a crit/
  achievement flash" → art bible §4.2's explicit reservation: Herald Gold
  "must not appear as ambient decoration," which a persistent currency icon
  is exactly the excluded case for. Sanctum Amber substituted instead,
  matching every other non-performance warm UI element in this project.
- "Compact, simple silhouette readable at small size" → art bible's
  combat-scan icon minimum note (32px effective size in a time-critical
  WAVE_ACTIVE context) — a busy/detailed design wouldn't read at that size.
- "hand-painted miniature cabinet-diorama... matches the Menagerie species
  portrait icons and tarot card art" → art bible §1 Visual Identity
  Statement; explicit cross-reference to already-generated, already-approved
  icon art from this same project so the generator has a concrete style
  anchor, not just an abstract description.
- "plain pure black background for easy cutout" → matches this project's
  established alpha-cut pipeline convention (flood-fill technique, per this
  file's own documented lessons).

---

## Steelwood Siege Spire (physical) + Golden Banner Shrine (support)

**Date:** 2026-08-02
**Target:** the two remaining mismatched tower archetypes
(`tower_physical_base.png`, `tower_support_base.png`), closing out Section 3
of `art-generation-requests-2026-08-02.md`.
**Source:** user-supplied, generated from the updated prompts (background/
shadow-contrast fix + new pedestal description baked in).
**Status:** Sliced and wired (2026-08-02). Both came back excellent —
Steelwood Siege Spire has the requested mounted crossbow/ballista (no
elemental theming, reads as plain/mechanical as asked); Golden Banner Shrine
is genuinely open (visible straight through the timber frame to the
pedestal floor, easily clears the 30% negative-space rule) with the two
flanking pennants as specified. Both had truly flat backgrounds with no
vignette and shadow values well-separated from the background color — the
fix from the two previous regeneration rounds held, and both sliced clean
on the first attempt with no interior holes. **All 4 tower archetypes now
share one consistent pixel-art style and pedestal design** — the
style-standardization goal from the original "would the towers need to be
updated to standardize the art style?" question is now fully closed.
Live-verified via Godot MCP: all 4 archetypes resolve correctly, zero
errors, screenshot confirms clean render.

---

## Rally Banner (Support archetype tower)

**Date:** 2026-08-02
**Target:** `blueprint_rally_banner.tres` (`archetype = "support"`, damage-buff
aura, radius 3 cells) — art gap identified while wiring `TowerInstance.gd`'s
archetype→texture lookup; no existing sliced asset has the open/radiating
silhouette the Support archetype requires (art bible §3.1.3 Rule 3).
**Status:** Generated, sliced, and wired (2026-08-02). Result was clean — real
alpha channel from the generator (no color-key alpha-cut needed, unlike the
sheet-sourced towers), open timber archway with visible open floor beneath the
banner (clears the 30% negative-space rule easily), soft ambient glow reads as
contained to the object once composited against a real background rather than
bleeding into it. Cropped to bbox, erased the "RALLY BANNER" plaque text (same
treatment as the other towers), saved as
`assets/art/towers/tower_support_base.png`, wired into `TowerInstance.gd`'s
`"support"` slot. Live-verified via Godot MCP — all 4 archetypes now resolve
with zero warnings.

```
Isometric fantasy game tower asset, "Rally Banner" support structure, single
object centered on a plain dark background for easy cutout. NOT a solid
enclosed tower — an open wooden-and-stone standard/banner platform: a raised
stone dais with an open timber frame archway, no walls enclosing the center,
at least 30% of the silhouette empty/negative space so it reads as
broadcasting outward rather than containing. A tall banner pole rises from
the center flying a large flowing amber-and-gold heraldic banner. Two
smaller flanking pennant poles with open trailing streamers extend outward
left and right, reinforcing an open, radiating, welcoming shape — not
symmetrical closed walls. Stone hexagonal pedestal base matching the style
of a matched tower set, with a label plaque on the front face. Soft golden
aura glow rising from the base, suggesting a buff/blessing effect emanating
outward, no particle explosion, just a warm ambient radiance.

Color palette: warm amber-gold (#C8801A) trim, muted fieldstone grey
(#7E8590) stone, parchment cream (#F5EDCB) banner highlights, Herald Gold
(#F5C01A) accents on the aura glow only. Do not use green, red, purple, or
cyan anywhere — this is a support/buff structure, not healing, damage, boss,
or UI-themed.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, fixed oblique isometric play-angle (same
angle as a tabletop miniature), chamfered/hand-carved stone edges (not
CAD-perfect), consistent with a painted fantasy tower-defense game asset
set. Single centered object, no other towers in frame, no ground clutter
beyond the pedestal base.
```

**Constraint mapping** (why each clause is there):
- "at least 30% ... negative space" → art bible §3.1.3 Rule 3 (Support
  towers, non-negotiable).
- "open ... not symmetrical closed walls" → distinguishes from the
  Defensive/Damage-Dealer/Specialist archetypes, which are all closed forms.
- "Do not use green, red, purple, or cyan" → art bible §4.2 semantic color
  vocabulary (heal/damage/boss/UI-reserved hues respectively).
- "hand-painted miniature cabinet-diorama ... fixed oblique isometric" →
  art bible §1 Visual Identity Statement + §3.4 (camera/scale register).
- "plain dark background for easy cutout" → matches this project's existing
  alpha-cut pipeline (see `tower_ranged_base.png`, `tower_physical_base.png`,
  `tower_elem_*.png` — all sliced from generated sheets the same way).

---

## Elemental Tower Collection (regeneration — replaces the 9 tower_elem_*.png)

**Date:** 2026-08-02
**Target:** all 9 unused/wired elemental tower variants
(`tower_elem_{fire,ice,lightning,poison,earth,water,wind,shadow,holy}.png`),
including the one wired to the `"elemental"` archetype slot (`tower_elem_ice.png`).
**Source:** user-supplied `assets/source/towers/elemental_tower_collection.png`
(no prompt authored by Claude for this one — user generated and dropped it in
directly). Same 5×2 grid layout/order as the original `updated_tower_set.png`
this replaces, but with blank (unlabeled) pedestal plaques — no text-erasure
step needed this time.
**Status:** Sliced and wired (2026-08-02), replacing the originals in place
(same filenames). Live-verified via Godot MCP — `"elemental"` still resolves
to `tower_elem_ice.png` with zero errors, screenshot confirms clean render.

**Slicing note — this sheet needed a different alpha-cut threshold than the
original tower sheet.** The first attempt reused the connected-component
flood-fill method at the same distance threshold that worked for
`tower_physical_base.png`/the button sheet (`dist < 30-32`), and it badly
overcut: large holes appeared in the pedestal base and lower tower body
because this sheet's ambient-occlusion shadow gradient sits much closer to
the background color (`~18,19,21`) than the equivalent areas in the original
sheet did — some shadowed stone pixels were within ~10 RGB units of pure
background. Tightening to `dist < 16` fixed it (solid interiors, thin
acceptable edge fringe); an intermediate attempt at `dist < 22` was tried to
clean up that edge fringe further and made it *worse* — it started eating
into the brick mortar lines throughout the tower body, not just the outer
silhouette. **Lesson: always spot-check a low-contrast case (Shadow tower,
or any dark VFX variant) against a bright contrasting backdrop before
committing a batch slice — the right threshold isn't transferable between
generations even when the visual style looks similar.**

---

## Elemental Tower Collection — regeneration request (shadow-gradient fix)

**Date:** 2026-08-02
**Target:** a follow-up regeneration of `elemental_tower_collection.png`
itself, addressing the root cause of the above slicing problem instead of
just compensating for it in post — the source sheet's ambient-occlusion
shadow on the pedestal/lower tower body blends too close to the background
color to cleanly threshold, forcing every future slice of this sheet to
rediscover the right threshold by trial and error.
**Status:** Generated, sliced, and wired (2026-08-02) as
`assets/source/towers/towers_remade.png`. The fix worked — no more interior
holes even at a much less aggressive alpha-cut threshold (`dist < 18` vs. the
previous sheet's fragile `dist < 16`/breaks-at-22), gap detection between
grid cells was clean/consistent on the first try (vs. the noisy inconsistent
gaps on both prior sheets), and the pedestal redesign (thicker gold-trimmed
rectangular plaque frame) is a genuine style improvement. Replaced all 9
`tower_elem_*.png` plus `tower_ranged_base.png` (the sheet's "Normal" cell) —
deliberately included Normal even though this request was scoped to
"elemental towers," since `ranged` and `elemental` share one source sheet by
design and leaving `tower_ranged_base.png` on the old pedestal style would
have reintroduced a style mismatch between them. Live-verified via Godot MCP:
all 4 archetypes resolve correctly, zero errors, screenshot confirms the new
pedestal design renders cleanly.

```
Isometric fantasy game asset sheet, 10 stone castle towers arranged in a 5×2
grid, each on its own hexagonal wood-and-stone pedestal base with a blank
(unlabeled) recessed plaque on the front face. Elemental variants
left-to-right, top row: Normal (blue banner), Fire (orange/red flames), Ice
(pale blue icicles), Lightning (violet/indigo with electric arcs), Poison
(purple spotted mushroom cap). Bottom row: Earth (brown/mossy stone), Water
(teal, flowing water), Wind (green, swirling air trails), Shadow (dark
purple/black wisping smoke), Holy (white/gold, sparkles). Same painterly
pixel-art style throughout: individually-painted brick/stone-block texture,
conical tiled roofs, small arched windows, thin flagpoles with pennants,
muted grey stone with warm amber-gold trim.

Critical technical requirement — background and shadow contrast: render the
background as a single flat, uniform, solid dark color with no soft
vignette or gradient falloff. Any shadow, ambient occlusion, or dark-side
shading painted onto the towers or pedestals (especially on the underside
of the pedestal base and the lower tower body) must stay clearly and
consistently lighter or otherwise distinguishably different in tone from
the background color — do not let a tower's own cast shadow or AO
darkening gradually fade to match the background's exact color or
brightness. There must be a hard, unambiguous boundary between "background"
and "object" at every point around each tower's silhouette, including
underneath and behind it, so each tower can be cleanly cut out from the
background with a simple color-key/background-removal tool. This applies
especially to the Shadow-element tower's smoke/wisp effects, which should
stay visibly distinct in hue or brightness from the background rather than
fading to near-identical darkness.
```

**Why phrased this way**: comparative framing ("X must differ from Y") over
absolute color instructions — image generators follow relative constraints
across a whole composition more reliably than isolated hex/brightness
targets, and naming the specific failure mode (AO fading to match
background) matters because a generic "clean background" request doesn't
reliably prevent soft ambient shadow blending, which is a separate
rendering choice from background flatness.
