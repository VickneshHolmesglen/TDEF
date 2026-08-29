# Missing Assets Audit (2026-08-29)

> **Purpose**: A complete inventory of everything in the shipped game that
> requires a visual asset but currently has none, for use as ChatGPT's
> generation work list. Checked by grepping every real data file against its
> actual `icon`/`texture`/`sprite` field (or confirming the field doesn't
> exist at all), not assumed — see each section for the exact check used.
>
> **Not included here**: the 8 monster movement spritesheets (Spore
> Skitterling, Armored Brute, Forest Troll, Bog Lurker, Goblin Warlord, Rift
> Sentinel, Iron Colossus base+walk, Goblin Runner walk) — those already have
> their own standalone, ready-to-run request files and backlog entries as of
> 2026-08-29 (`production/art-overhaul-status.md`). Don't duplicate that work
> here; this document covers everything else.

---

## Summary

| Category | Missing | Notes |
|---|---|---|
| Equipment items (weapons/armor/trinkets) | **36** | Every crafted equipment item in the game — zero has an icon |
| Tower components (Foundation/Weapon/Focus/Power) | **13** | Every mix-and-match Tower Assembly component |
| Consumables (CraftedGood) | **9** | Food/potion/bandage items from Menagerie/Crafting recipes |
| Materials (surplus/lure) | **5** | Non-drop-table crafting materials |
| Skills (Hero Skill Build catalogue) | **13** | Zero skill has an icon; the schema itself has no `icon` field yet — a data-model gap, not just an art gap |
| Tarot cards | **13** | Zero *gameplay* card has an icon; see the callout below — real Major Arcana art exists but isn't wired to these cards |
| Menagerie species | **0 missing, but see callout** | Real art exists for all 5, but `SpeciesResource` has no field to hold it — a wiring gap, not a generation gap |
| Iron Colossus (monster) | Tracked separately | Already in the art-overhaul backlog — don't duplicate |
| Hero 3D model | Not applicable to ChatGPT | Real-time 3D model, tracked separately in `codex-art-overhaul.md`/Art Bible budgets — needs a 3D pipeline, not 2D image generation |

**Total new 2D image-generation items for ChatGPT: 76** (36 + 13 + 9 + 5 + 13).

---

## Two important callouts before generating anything

**1. Tarot: real art exists, but for the wrong cards.** `assets/art/tarot/`
already has 22 fully-painted Major Arcana pieces (`the_fool.png`,
`the_magician.png`, `death.png`, etc.) from an earlier pass. The game's
actual 13 playable Tarot cards use gameplay-named IDs instead
(`card_lucky_charm`, `card_iron_resolve`, `card_apex_predator`, etc.) that
don't correspond 1:1 to Major Arcana names, and `TarotCardResource` has no
`icon`/`texture` field at all to hold either one. **This needs a design
decision first** (map each gameplay card to a Major Arcana identity and reuse
the existing 22 pieces, or generate 13 new gameplay-specific illustrations)
before any new Tarot generation prompts are written — don't generate blind,
you'd likely duplicate art that already exists unused.

**2. Menagerie species: art exists and is complete, just not wired.** All 5
species (`aurora_stag`, `duskfang_fox`, `emberwing_moth`, `glimmer_hare`,
`mossback_toad`) already have real, finished art in `assets/art/species/`.
`SpeciesResource` simply has no field to reference it, and nothing in the
Menagerie screen renders it yet. **This is a Claude Code wiring task, not a
ChatGPT generation task** — flagging it here so it isn't miscounted as
missing art.

---

## 1. Equipment Items (36) — weapons, armor, trinkets

Every recipe's `output_item_id` in `assets/data/equipment_recipes/` maps to
an `ItemDefinitionResource` in `assets/data/items/` with `equipment_category`
set but `icon` left `null`. Organized by slot; tier in brackets.

**Weapon**: `iron_sword` [1], `steel_greatsword` [2], `lurker_fang_blade` [3], `warlords_greatblade` [4]
**Offhand**: `wooden_buckler` [1], `iron_buckler` [2], `sentinel_ward` [3], `sentinels_aegis` [4]
**Helmet**: `iron_helm` [1], `reinforced_helm` [2], `sentinel_visor` [3], `goblin_fang_circlet` [4]
**Chest**: `leather_jerkin` [1], `reinforced_plate` [2], `troll_hide_mantle` [3], `brutes_bulwark_plate` [4]
**Gloves**: `leather_gloves` [1], `reinforced_gauntlets` [2], `brute_gauntlets` [3], `goblin_claw_gauntlets` [4]
**Pants**: `leather_leggings` [1], `iron_greaves` [2], `brute_legguards` [3], `warlords_legguards` [4]
**Boots**: `traveler_boots` [1], `reinforced_boots` [2], `warlords_greaves` [3], `trollhide_striders` [4]
**Neck**: `lucky_charm_trinket` [1], `silver_pendant` [2], `ichor_charm` [3], `bogpearl_amulet` [4]
**Ring**: `warding_band` [1], `iron_band` [2], `goblin_signet` [3], `trollmarrow_band` [4]

**Suggested treatment**: item icons, not full illustrations — small
single-object silhouette icons matching this project's existing 15
monster-drop-material icons (`assets/art-generation-requests-2026-08-06-materials.md`
is the exact precedent to reuse the style/format/prompt shape from). Tier
should read visually (T1 = plain/worn materials, T4 = ornate/glowing), same
escalation logic each recipe's own material tier already implies.

---

## 2. Tower Components (13) — Foundation/Weapon/Focus/Power

`assets/data/tower_components/` + matching items in `assets/data/items/`
(`item_type = "TowerComponent"`). These are Tower Assembly's mix-and-match
pieces (`design/quick-specs/tower-assembly-2026-08-11.md`).

- `archer_foundation_component`, `iron_foundation_component`, `reinforced_foundation_component`, `foundation_surplus`
- `archer_weapon_component`, `advanced_weapon_component`, `masterwork_weapon_component`, `weapon_surplus`
- `archer_focus_component`, `basic_focus_component`, `reinforced_focus_component`, `focus_surplus`
- `archer_power_component`, `reinforced_power_component`, `masterwork_power_component`, `tier4_power_component`, `power_surplus`

**Not the same thing as** the existing, still-unresolved
`assets/art-generation-requests-2026-08-17-tower-components.md` batch
(`0/9, awaiting generation`) — that one splits already-shipped tower *body*
sprites into layered Base/Shaft/Top pieces so an assembled tower renders
correctly on the battlefield. The 13 items above are Inventory-slot *icons*
for the individual crafted components sitting in a player's bag — a
different asset (small icon vs. full tower-body layer), just a related
system. Both are real, separate gaps; don't conflate them.

**Suggested treatment**: small icon-scale, matching the existing tower base/
element sprite palette (`assets/art/towers/`) rather than a new visual
language — these represent physical pieces of an assembled tower.

---

## 3. Consumables — CraftedGood (9)

Menagerie/Crafting-produced food, potions, and field items.

`bogwater_tonic`, `goblinhide_bandage`, `healing_salve`, `hunters_draught`,
`ironplate_ration`, `riftglass_ward`, `spore_poultice`, `travelers_bedroll`,
`warlords_field_ration`

**Suggested treatment**: item icons matching the equipment-icon register
(small, single-object, plain background for cutout) — these are consumed
from Inventory slots the same way equipment is displayed there.

---

## 4. Materials — non-drop-table (5)

`focus_surplus`, `foundation_surplus`, `power_surplus`, `weapon_surplus`
(Tower Assembly's Mission-End Building Material Surplus grant,
`resource-economy.md` Formula 6), `menagerie_lure` (Menagerie's acquisition
item).

**Suggested treatment**: same icon register as the 15 already-shipped
monster-drop materials (`assets/art-generation-requests-2026-08-06-materials.md`)
— these are mechanically the same kind of object (a stackable crafting
material), just sourced differently.

---

## 5. Skills — Hero Skill Build catalogue (13)

`assets/data/skills/definitions/*.tres`. **`SkillDefinitionResource` has no
`icon` field at all** (confirmed by reading the class directly) — adding one
is a small Claude Code change that should happen before/alongside this art
lands, not purely an art-drop.

- Physical: `phys_cleave`, `phys_bulwark`, `phys_siegebreaker`
- Ranged: `rng_piercing_shot`, `rng_volley`
- Elemental: `elem_firebolt`, `elem_frostbolt`, `elem_firestorm`, `elem_storm`, `elem_arcane`, `elem_venom`
- Support: `sup_rally`, `sup_barrier`

**Suggested treatment**: small square icons (matches the "40×40 icon
buttons" skill-slot UI already shipped in `mission_hud.gd`), one glyph/symbol
per skill reading its element+archetype at a glance — this is also the exact
surface Tower Mastery's own in-world arc (`tower-mastery.md` Visual/Audio
Requirements 1a) already reuses for its center glyph, so consistency between
the two matters.

---

## 6. Tarot Cards (13) — see callout above, don't generate until the mapping question is resolved

`card_apex_predator`, `card_bountiful_harvest`, `card_cautious_advance`,
`card_golden_ticket`, `card_grim_resolve`, `card_grinding_gauntlet`,
`card_hunters_pace`, `card_iron_resolve`, `card_lucky_charm`,
`card_measured_pace`, `card_reckless_onslaught`, `card_steady_hand`,
`card_swift_current`

---

## What ChatGPT needs per item

Every existing successful batch in this project (see
`design/art/asset-generation-prompts.md`) follows the same shape: a plain
dark/black background for cutout, painterly pixel-art / hand-painted
miniature diorama style, one accent color zone + one specular highlight,
avoid pure blood-red/purple/cyan (reserved colors).

**Status as of 2026-08-29**: user chose to batch all three non-blocked
categories at once. Standalone, upload-ready request files are written and
in the backlog (`production/art-overhaul-status.md`):
- `assets/art-generation-requests-2026-08-29-equipment.md` (36 items)
- `assets/art-generation-requests-2026-08-29-tower-components-icons.md` (13 items)
- `assets/art-generation-requests-2026-08-29-consumables-materials.md` (9 + 5 items)

Skills (13) and Tarot (13) remain **not** written — both still need their
respective prerequisite decisions (a schema `icon` field for Skills, a
gameplay-card-to-Major-Arcana mapping for Tarot) before prompts can be
written without risk of wasted/duplicate generation.
