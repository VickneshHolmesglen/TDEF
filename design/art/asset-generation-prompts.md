# Asset Generation Prompts

Reference log of prompts used with external image generators for game art,
kept so a prompt can be reused, tweaked, or regenerated later without
reconstructing the art-bible constraints from scratch each time.

> **Batch request, complete (4/4, 2026-08-13)**: `assets/art-generation-requests-2026-08-13-mission-cards.md`
> is a standalone, upload-ready prompt batch for the 4 Mission Select card
> environment-motif icons (The Gap, The Foothills, The Hollow, The Narrows) —
> closed `mission-select.md`'s "no mission-card art exists" gap flagged in
> `mission_select_screen.gd`'s own doc comment. **Different style from every
> other batch in this log**: flat solid-color silhouette/pictogram icons (UI
> Parchment `#DDD4B0` only, on black for cutout), explicitly NOT the
> hand-painted diorama/pixel-art register every other asset in this project
> uses — `mission-select.md` requires this screen to read as "a clean
> operations screen," not a diorama piece. All 4 sliced, alpha-cut, wired
> into `MissionEntry.icon` and `mission_select_screen.gd`.

> **Batch request, complete (5/5, 2026-08-08)**: `assets/art-generation-requests-2026-08-07-terrain.md`
> is a standalone, upload-ready prompt batch for the 5 Mission Field terrain
> tiles (one per `Grid.CellType`: PLACEABLE/PATH/SPAWN/GOAL/BLOCKED),
> replacing `grid_visual.gd`'s flat-solid-color rendering — closed the "never
> ship flat shapes" gap for the entire 16×12 mission grid, shared across all
> 4 missions. **Different pipeline from every other batch in this log**:
> opaque full-bleed tiles, no black-background cutout, no alpha-cut step.
> All 5 generated, sliced, and wired into `grid_visual.gd`'s `TEXTURE_BY_TYPE`
> (commit `c2eabaf`); Path was regenerated once more after shipping to read
> distinct from Placeable (commit `792c502`). **2026-08-14 note**: a second,
> unrelated raw sheet was found sitting unprocessed at `assets/` root —
> its Path tile didn't tile (borders converged to a point) and its Spawn
> tile used reserved Boss Purple instead of Scout Blue. Since the real
> shipped tiles are already correct and superior to this sheet, it was not
> used to replace anything; deleted at the user's request rather than
> processed.

> **Batch request, complete (15/15, 2026-08-07)**: `assets/art-generation-requests-2026-08-06-materials.md`
> is a standalone, upload-ready prompt batch for the 15 real monster-drop
> material icons (`goblin_hide`, `goblin_fang`, `iron_plating`, `brute_core`,
> `lurker_ichor`, `bog_pearl`, `rift_shard`, `sentinel_core`, `spore_dust`,
> `troll_hide`, `troll_marrow`, `warlord_iron`, `warlord_emblem`,
> `common_scrap`, `iron_ore`) — closes Phase 3 of the materials-icons work
> (`design/quick-specs/inventory-slot-icons-2026-08-06.md` built the
> rendering mechanism against a real-but-empty `icon` field on all 13
> originals, so this is content-only, no code changes needed once each
> lands). Items 14-15 (`common_scrap`/`iron_ore`) were added 2026-08-07 after
> being found orphaned and wired into real drop tables in the same session.
> **Do not use Herald Gold in the icon art itself** even for Rare-tier
> materials — rarity is signaled separately by a code-drawn frame
> (`RarityFrame`), not baked into the icon.

> **Batch request, in progress (15/22)**: `assets/art-generation-requests-2026-08-03-tarot.md`
> is the original standalone prompt batch for the full classic 22 Major
> Arcana (only 12 `TarotCardResource` entries are authored today, so this
> batch is deliberately art-ahead-of-content — see the file's own scope
> note). 15 cards sliced, wired, and clean (`assets/art/tarot/`), 10 of the
> 12 real cards now have art. **The remaining 7** (Strength/Hermit's own
> mockup-reject issue was already resolved on retry; only The Lovers is
> still outstanding from that batch) are pulled into a fresh, standalone
> batch: `assets/art-generation-requests-2026-08-07-tarot-remaining.md`
> (The Lovers retry + Wheel of Fortune, The Devil, The Tower, The Sun,
> Judgement, The World, all not yet generated).

> **Batch request, partially generated**: `assets/art-generation-requests-2026-08-02.md`
> is a standalone, upload-ready prompt batch. Its Section 3 (tower
> regeneration) is now fully complete — see the Steelwood Siege Spire /
> Golden Banner Shrine entry below. Section 1 (7 monsters) is 4/7 generated;
> Section 2 (5 Menagerie companions) is not started. Kept separate from this
> log since it's meant to be handed to ChatGPT directly; outcome notes get
> folded back into this file as each piece lands, same as below.

---

## Hero Placeholder Sprite (2D stopgap, not the final asset)

**Date:** 2026-08-13
**Target:** replaces `src/core/hero/Hero.tscn`'s bare `PlaceholderVisual`
(a plain light-blue `ColorRect`, no silhouette at all) with a real, readable
2D sprite. **This is explicitly NOT the Hero's final asset** —
`design/art/characters/hero-visual-profile.md` specifies the Hero as the
game's one real-time 3D model (rigged idle/combat animation, 4 tower-fusion
variants, ≤6,000 tri budget), which needs an actual 3D modeling pipeline this
project does not currently have. This prompt produces a flat 2D stand-in
sprite (same ChatGPT + manual alpha-cut pipeline as monsters/structures)
purely so the Hero is visually legible on the field today — a discovered gap
where the hero was dealing real damage and killing monsters on screen while
rendering as an unstyled blue square. Swap for the real 3D asset once that
pipeline exists; do not treat this sprite as done/final.
**Status:** Not yet generated.

```
Single fantasy character, front-three-quarter view, standing idle pose,
centered on a flat pure black (#000000) background for easy cutout. A
"warden-smith" archetype — equal parts craftsperson and sentinel, not a
classical knight, not a wizard, not a rogue. No full-enclosure plate helmet,
no plumed helmet, no robes, no scrolls, no floating magic instruments, no
asymmetric hood-and-dagger silhouette, no cape.

Silhouette: lean and deliberate, not bulky — tall vertical proportions
(roughly 1.8:1 height to width), feet planted wide relative to the torso to
read as grounded and weighted. Head/crown is a clean point or rounded dome
shape (a narrow visor-ridge, or a close-wrap hardened hood), never a flat
top or wide brim.

Gear: worn hardened-leather panels as the dominant surface (shaped, visibly
stitched, edge-reinforced, tanned dark warm brown — not black, not bright),
with irregular hammer-worked plate armor at the shoulder, forearm, and shin
(smith-made, not uniform factory metal). A wrapped-cord grip on a single
carried tool-weapon (a smith's hammer or a short polearm reads better than a
sword — this is a maker who fights, not a soldier). No purely decorative
elements; every piece of kit should look functional.

Color palette: dark warm brown leather (approx. HSL 30°, 35%, 28%), plate
armor in a muted fieldstone grey (#7E8590) with lit edges shifting toward
parchment cream (#F5EDCB), wrapped grips/cords in a desaturated amber
(warmer/darker than bright gold). Skin, where visible at wrist or jaw, no
lighter than parchment cream — not bright white, not a bright saturated tan.
Do NOT use Herald Gold (#F5C01A), no purple, no green, no cyan.

Expression/posture: composed and alert, not smiling, not in a dramatic
action pose — weight resting into the legs, slight forward lean, ready but
not reacting. A hand-painted miniature figurine read, not a theatrical
fantasy hero pose.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly
pixel-art texture with visible brushwork, consistent with this project's
existing character/creature art (matches the Menagerie species portraits
and monster sprites already generated for this project) — warm, carved,
tactile, not a flat vector/anime-style character.
```

**Constraint mapping** (why each clause is there):
- "warden-smith archetype... not a classical knight/wizard/rogue" + the full
  exclusion list → `hero-visual-profile.md` §1's binding archetype rules,
  copied directly rather than paraphrased since a generator given only "not
  a knight" tends to default straight back to knight-adjacent designs.
- "1.8:1 height to width... feet planted wide" + "clean point or rounded
  dome" crown → §2's Silhouette Rules (Binding), the aspect ratio and crown
  rules that hold across every Hero state including this stopgap.
- Leather/plate/grip material list with exact color values → §3's Material
  & Color Spec table, reused verbatim so the placeholder doesn't clash with
  the real 3D asset's eventual palette when it replaces this sprite.
- "composed and alert... not a dramatic action pose" → §4's expression
  register and §5.3.1's "hand-painted figurine, not theatrical performance"
  posture philosophy.
- "matches the Menagerie species portraits and monster sprites" → same
  cross-reference-to-existing-approved-art anchor used in every other prompt
  in this log, so the generator has a concrete style target.
- Explicit "this is NOT the final asset" framing in the target note (not the
  prompt itself, which the generator never sees) → prevents this stopgap
  from silently becoming treated as done; the real Hero needs 3D production
  this project doesn't have tooling for yet.

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
