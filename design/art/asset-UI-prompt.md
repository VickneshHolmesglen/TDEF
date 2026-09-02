# Asset Generation Prompts — UI

Reference log of prompts used with external image generators for UI/HUD art,
kept separate from `asset-generation-prompts.md` (world/prop assets) since UI
pieces are governed by art bible §3.3 (UI Shape Grammar) and §4.4 (UI Palette)
rather than the world-space rules the other log is built around.

---

## Sanctuary_Header_Gold (screen title header bar)

**Date:** 2026-08-04
**Target:** a reusable top-of-screen title header bar for menu/hub screens
(e.g. Sanctuary hub, Tarot Deck, Bestiary) — gold-trimmed per its name, no
existing UI header asset in `assets/art/` to match against.
**Status:** Prompt drafted, not yet generated.

```
A wide horizontal UI header bar for a game menu screen, in a hand-painted
"cabinet diorama" style — stylized painterly textures with baked-in lighting,
not flat pixel art and not photorealistic. Rendered as a single asset on a
transparent background, roughly 3:1 to 4:1 aspect ratio (wide and short).

Shape: A chamfered rectangle following architectural-stone-simplified UI
grammar — top two corners cut at a 45° chamfer, bottom two corners squared,
giving a grounded, "sitting" read rather than floating. Flat, low-relief
geometry — no deep 3D bevels. A single soft drop shadow with purely vertical
offset only (no world-space cast shadow).

Base surface: UI Chrome dark blue-grey (#252D3D), the game's dedicated
UI-only base color — flat, unweathered, reads clearly as "interface," never
as a world material.

Gold ornamentation: A restrained decorative gold trim/border tracing the
panel edge and the chamfered corners — hand-painted metallic gold with warm
highlight and soft shadow modeling (not flat fill), evoking gilded
picture-frame or shrine-plaque detailing consistent with the game's warm,
lantern-lit "sanctuary" register. Use Herald Gold (#F5C01A) restrained to
the trim only, not as a fill — this is the game's reserved "something
exceptional" accent color, so keep it as a thin accent line/corner
flourish, not a dominant surface.

Composition: The center 60-70% of the bar must be flat, uninterrupted UI
Chrome surface — empty negative space reserved for a screen title label to
be placed in code afterward. No text, no icons, no characters baked into
the image.

Explicitly avoid: cyan or blue-accent highlights (reserved for UI
Accent/interactive states elsewhere in the UI), any world-space color
(greens, reds, purples), particle/glow effects, and photoreal metal
textures — keep the gold hand-painted and restrained, matching a
"precious, rare" read rather than gaudy or busy.
```

---

## Sanctuary_Header_Silver (screen title header bar, silver variant)

**Date:** 2026-08-04
**Target:** same reusable header shape as `Sanctuary_Header_Gold`, second trim
variant — identical geometry/composition, gold trim swapped for silver so the
two can be palette-swapped per screen without a shape mismatch.
**Status:** Prompt drafted, not yet generated.
**Note:** No "Silver" accent color is defined in the art bible (§4.4 only
specifies Gold/Herald Gold). Picked a cool polished-steel hex
(`#C9D2DC`) deliberately distinct from UI Disabled State (`#6B7280`) so a
silver header can never be misread as a disabled/greyed-out panel.

```
A wide horizontal UI header bar for a game menu screen, in a hand-painted
"cabinet diorama" style — stylized painterly textures with baked-in lighting,
not flat pixel art and not photorealistic. Rendered as a single asset on a
transparent background, roughly 3:1 to 4:1 aspect ratio (wide and short).
Identical shape and composition to a matching gold-trimmed variant of this
same header, so the two are drop-in swaps for each other.

Shape: A chamfered rectangle following architectural-stone-simplified UI
grammar — top two corners cut at a 45° chamfer, bottom two corners squared,
giving a grounded, "sitting" read rather than floating. Flat, low-relief
geometry — no deep 3D bevels. A single soft drop shadow with purely vertical
offset only (no world-space cast shadow).

Base surface: UI Chrome dark blue-grey (#252D3D), the game's dedicated
UI-only base color — flat, unweathered, reads clearly as "interface," never
as a world material.

Silver ornamentation: A restrained decorative silver/polished-steel trim
tracing the panel edge and the chamfered corners — hand-painted cool metallic
tone (#C9D2DC) with a crisp, brighter highlight and cooler shadow modeling
than a gold trim would use (not flat fill), evoking a chased-silver
picture-frame or shrine-plaque detail, cooler and quieter than the gold
variant's warm "reward" read — this is a secondary/standard tier, not the
"something exceptional" signal gold carries.

Composition: The center 60-70% of the bar must be flat, uninterrupted UI
Chrome surface — empty negative space reserved for a screen title label to
be placed in code afterward. No text, no icons, no characters baked into
the image.

Explicitly avoid: cyan or blue-accent highlights (reserved for UI
Accent/interactive states elsewhere in the UI), any world-space color
(greens, reds, purples), particle/glow effects, and photoreal metal
textures — keep the silver hand-painted and restrained, not gaudy or busy.
Do not let the silver read as flat grey — it must stay legibly "polished
metal," not "disabled/inactive."
```

---

## Sanctuary Room Tab Strip — 6 tab icons

**Date:** 2026-08-04
**Target:** icon glyphs for the 6 Room Tab Strip entries in
`design/ux/sanctuary-ui.md` (Component Inventory, Focus Traversal Order):
Overview, Inventory & Crafting, Menagerie, Defense Building, Equipment Forge,
Loadout. No icon set exists yet — the GDD explicitly flags "exact tab-strip
icon set" as undefined (`design/gdd/sanctuary-ui.md` line 183).
**Shared constraints (art bible §3.3):** chamfered-rectangle icon frame with
a 2px inset border; must read clearly at 24×24px minimum; active/inactive
state is filled-vs-outline, never color-only (accessibility, Standard tier)
— so each icon should be generated as a single clean, high-contrast
silhouette glyph (one flat interior fill color + one line-weight outline)
that can be cleanly re-rendered as filled or outline-only in engine, not a
fully painterly/shaded illustration like the headers above.
**Status:** Prompts drafted, not yet generated.

```
A single small UI icon glyph for a game's navigation tab strip, rendered on
a transparent background, square canvas, designed to stay legible at
24×24px. Style: a clean, high-contrast silhouette icon — one flat interior
fill color plus one consistent line-weight outline stroke, NOT a fully
painterly/shaded illustration, NOT photorealistic, no gradients, no drop
shadow, no background shape baked in (the chamfered-rectangle frame and
inset border are added separately in engine). Line weight and interior
fill must both be readable as a clean silhouette if scaled down small or
recolored as an outline-only state.

Icon subject — [SUBJECT PER ENTRY BELOW].

Color: single neutral UI Parchment tone (#DDD4B0) for the fill, UI Chrome
dark blue-grey (#252D3D) for the outline stroke — this glyph must work as a
flat, recolorable asset, not carry its own baked-in accent color (accent/
active-state color is applied in engine, not in the source art).

Explicitly avoid: cyan (#23A8D4, reserved for UI Accent/interactive
highlight), any gold/silver metallic rendering (reserved for the header
bars, not tab icons), texture/brushwork detail that won't survive
downscaling to 24px, and any text or lettering baked into the icon.
```

**Per-entry subject line** (substitute into `[SUBJECT PER ENTRY BELOW]` above):

| Tab entry | Icon subject |
|-----------|---------------|
| Overview | A simple stylized hearth/shrine silhouette — a small peaked roofline over a glowing hearth shape, reading as "home base" at a glance |
| Inventory & Crafting | A closed storage chest with a crossed hammer-and-nail motif, reading as "storage + making" |
| Menagerie | A single stylized paw print, reading as "creatures" |
| Defense Building | A simplified crenellated tower/battlement silhouette, reading as "fortification" |
| Equipment Forge | An anvil with a hammer resting against it, reading as "smithing" |
| Loadout | A single tarot card silhouette (rounded-corner card shape with a small star or sigil centered on it), reading as "deck/loadout" — matches the room's hand-off into Tarot Deck UI |
| Skills *(added 2026-09-02 — see note below)* | A single stylized five-pointed starburst/spark glyph, reading as "skill/ability" — matches this project's existing genre convention for ability icons, distinct enough from Loadout's tarot-card silhouette to avoid confusion between the two adjacent tabs |

**Follow-up, 2026-09-02**: `sanctuary-ui.md` Core Rule 11 added a 7th tab-strip entry, "Skills" (`ROOM_HERO_SKILLS`), inserted between Equipment Forge and Loadout — shipped and live in code (`tab_strip.gd`'s `TAB_TARGETS`/`TAB_ICON_TEXTURES`) since 2026-09-01, but `TAB_ICON_TEXTURES[5]` is `null` (renders text-only) because this icon set predates that addition by a month. The Skills row above extends this same batch's shared prompt template (top of this section — identical style/color/constraint block, only the subject line changes) rather than opening a new prompt style. See `production/art-overhaul-status.md`'s backlog for tracking.
