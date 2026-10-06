# Sanctuary Town Buildings — Codex Generation Prompts

**Created**: 2026-10-07 (Claude Code)
**Spec**: `docs/superpowers/specs/2026-10-07-sanctuary-town-buildings-design.md` §5
**Tracker**: `production/art-overhaul-status.md` → Backlog → "Sanctuary town buildings" batch (one row per building)
**Bound by**: `design/art/codex-art-overhaul.md` (division of labour §3, alpha-cut §5.2, naming §5.3, scale §5.5)

The Sanctuary OVERVIEW is a small town: one building per side-panel tab plus the
Castle. Each building has **5 tiers** that the player unlocks passively as that
tab's progress grows. The game already renders growing placeholder blocks, so
any tier that lands replaces its placeholder with no code change.

**35 images total**: 7 buildings × 5 tiers.

## 1. Shared rules (apply to every prompt)

- **Medium**: Sanctuary architecture is a 3D-asset category (codex-art-overhaul §1). Render
  each building as a **pre-rendered 3D-look illustration**: solid, dimensional,
  stylised fantasy, soft key light from the upper left, matching the existing
  `assets/art/sanctuary/habitat_tier_*.png` and `watchtower.png`.
- **Camera**: the same three-quarter top-down view for every image (about 35° down,
  facing the front, slightly turned to the right). Do not change it between tiers;
  the tiers must read as the same building growing.
- **Framing**: one building, centred, whole silhouette visible, the base resting on the
  bottom fifth of the canvas, no ground plane beyond a small footprint of
  packed earth or cobbles directly under it.
- **Background**: a flat, solid `#FF00FF` magenta background. That is a
  standalone instruction: no gradient, vignette, sky, or scenery behind the
  building. (Magenta has no overlap with the stone, wood, gold, or green palette, so the
  colour-distance alpha cut (§5.2) is clean.)
- **No text**: no text, letters, signage words, UI, frame, or border. That is a standalone sentence.
- **Canvas**: 1024×1024 square, building filling about 80% of the height at tier 5. The
  lower tiers are smaller **on the same canvas and the same ground line**, so tier
  growth is visible when they are swapped in place.
- **Tier ladder** (applies to every building):
  1. **Humble**: rough timber, thatch or plain planks, one storey, a few crates.
  2. **Established**: a stone foundation, a proper roof, one added feature.
  3. **Fortified**: mostly stone, a second storey or a wing, iron fittings.
  4. **Prosperous**: dressed stone, slate or tile roof, banners, lanterns, a garden or yard.
  5. **Grand**: towering and ornate, gold trim, heraldic banners, glowing windows,
     a signature landmark element.
- **Palette accent per building** (keep the sanctuary's warm stone base; the accent
  is how the player tells buildings apart at a glance): see each section.

## 2. Prompts

Each prompt below is the **building-specific part**. Prepend the shared rules
(§1) and the tier line from the ladder. Template:

> Stylised fantasy 3D-rendered building illustration, three-quarter top-down
> view, soft light from the upper left. {BUILDING PROMPT}. Tier {N} of 5:
> {TIER LADDER LINE}. Single building centred on a flat solid #FF00FF magenta
> background. No text, no letters, no frame, no border.

### 2.1 Castle (`castle`): the centrepiece; grows with overall progress
Accent: royal blue banners and slate roofs.
> The sanctuary's keep-castle and central landmark. Square curtain walls with a
> gatehouse at the front. Tier 1 is a wooden motte stockade with one watch platform;
> tier 5 is a multi-towered stone castle with a tall central donjon, blue-and-gold
> heraldic banners and a glowing great window.

### 2.2 Armoury (`armoury`): Inventory & Crafting
Accent: oxblood red awnings, iron racks.
> A storehouse and armoury for gear and crafting materials. Shelving visible through
> a wide doorway, weapon racks, barrels and sacks outside. Tier 1 is a lean-to shed with
> a few crates; tier 5 is a vaulted stone arsenal with banners of crossed swords
> and full weapon racks.

### 2.3 Menagerie (`menagerie`): Menagerie
Accent: moss green and living wood.
> A creature sanctuary and stable for tamed monsters. Fenced pens, a feeding trough,
> a round barn. Tier 1 is a small wattle pen with a hay pile; tier 5 is a domed
> greenhouse-stable with ivy, glowing lanterns, and several ornate enclosures.
> Do not show any creatures, only the building.

### 2.4 Keep (`keep`): Defense Building
Accent: grey granite, teal tech lanterns.
> A defensive keep and engineering workshop where towers and fortifications are
> researched. Battlements, a crane or winch, and blueprints on a lectern outside. Tier 1 is a
> log palisade with a single wooden tower; tier 5 is a massive bastion with
> crenellations, mounted ballistae and teal arcane lanterns.

### 2.5 Blacksmith (`blacksmith`): Equipment Forge
Accent: ember orange forge glow, soot black.
> A blacksmith's forge where hero equipment is made and runes are imbued. A chimney with
> smoke, an anvil and a quench barrel out front, and an orange forge glow from inside. Tier 1 is
> an open-sided hut with a stone hearth; tier 5 is a great stone foundry with twin
> chimneys, rune-carved arches glowing faintly and a gilded anvil sign (no text).

### 2.6 Training Hall (`training_hall`): Hero Skills
Accent: warm sand and cream canvas, crimson pennants.
> A training hall where the hero learns skills. A sparring yard, straw training dummies and a
> weapon stand. Tier 1 is a dirt yard with one dummy and a canvas tent; tier 5 is a
> colonnaded stone dojo-hall with crimson pennants, a training arena and a
> bronze statue of a hero.

### 2.7 Seer's Tower (`seers_tower`): Loadout (tarot cards)
Accent: deep violet and silver, starlight glow.
> A slender mystic tower where the seer reads tarot cards before each mission. An
> observatory top, star charts, candlelit windows. Tier 1 is a small wooden hut with
> a telescope on the roof; tier 5 is a tall spiralling violet-roofed tower with a
> silver armillary sphere on top and a soft starlight glow.

## 3. Deliverables and hand-off

- Codex drops raw output in `assets/source/sanctuary/town/` as
  `sanctuary_<building_id>_tier<n>.png` (for example `sanctuary_seers_tower_tier3.png`).
  One file per tier, not a combined sheet. A combined sheet is acceptable only if the 5 tiers are
  separated by clear magenta gaps.
- Then set that building's status row to `generated, awaiting processing`.
- Claude Code alpha-cuts (colour-distance from #FF00FF, then a flood-fill from the border if any
  magenta fringe remains), trims to a shared bottom-centre ground line per building, and writes
  `assets/art/sanctuary/town/<building_id>_tier_<n>.png`, matching the existing
  `habitat_tier_<n>.png` naming in `assets/art/sanctuary/`. It then fills the
  `tier_textures` slots of `assets/data/sanctuary_buildings/<building_id>.tres` and
  live-checks the scale in the Overview against each building's `footprint` (§5.5:
  always verify the scale live).
- The visual direction for final art is not locked (codex-art-overhaul §1 pilot gate), so this
  batch is placeholder-replacement art, not ship-final.
