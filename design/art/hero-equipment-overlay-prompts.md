# Hero Equipment Overlays — Codex Generation Prompts

**Created**: 2026-10-07 (Claude Code)
**Spec**: `docs/superpowers/specs/2026-10-07-hero-equipment-appearance-design.md`
**Tracker**: `production/art-overhaul-status.md` → Backlog → "Hero worn-gear overlays" batch
**Bound by**: `design/art/codex-art-overhaul.md` (division of labour §3, naming §5.3)

Gear now shows on the hero, both in the Equipment paperdoll and in missions.
Each equipped item is a transparent layer on top of a **base body**. To make
layers line up perfectly, every item is made as an **image edit of the base
body**, not as a fresh generation. Claude Code then extracts only the pixels that changed
(`tools/asset-pipeline/extract_worn_overlay.py`).

**36 images**: 1 base body + 35 item edits (7 slots × 5 items).

## 1. Step 1: the base body (do this first, everything depends on it)

Input: `assets/art/characters/hero_warden_smith.png` (1024×1536).

> Edit this image. Keep the exact same man, face, pose, proportions, camera,
> lighting, pixel-art style and 1024×1536 canvas. Remove ALL of his armour and gear:
> no helmet or hood, no shoulder plates, no chest armour or apron, no belts or tool
> pouches, no gloves or bracers, no knee plates, no greaves, no boots, and NO hammer
> or any weapon. He wears only a plain, close-fitting off-white linen undershirt with
> short sleeves and plain dark-brown close-fitting trousers, barefoot, with bare
> hands empty and relaxed in exactly the same hand positions. Short brown hair.
> Background: flat solid #FF00FF magenta, no shadow, no gradient.
> No text, no frame, no border.

Save the raw output as `assets/source/characters/hero_base_body_raw.png`.
**Stop and let the user approve it** before running step 2. Every overlay
inherits this pose, so a bad base wastes 35 generations.

## 2. Step 2: one edit per item

Input: the exact original magenta file `assets/source/characters/hero_base_body_raw.png` **and** the item's icon
`assets/art/items/<item_id>.png` (attach both, so the gear matches its icon).

Never use the processed base in `assets/art/`: the extractor compares each edit against that exact original raw image. Regenerate any edit that changes the face, pose or unrelated clothes. Notify the user when a batch is saved; Claude Code extracts, wires and checks it in the game.

Template:

> Edit the first image. Keep the exact same man, pose, proportions, camera,
> lighting, pixel-art style, background and 1024×1536 canvas; change NOTHING
> except adding one item: he now wears the {ITEM NAME} shown in the second
> image, {WHERE}. Match the second image's design, colours and materials, sized
> and fitted realistically to his body. Do not add any other armour,
> clothing or items. Background stays flat solid #FF00FF magenta.
> No text, no frame, no border.

Save the raw output as `assets/source/characters/gear/<item_id>_edit.png`.

If an edit changes the man (face, pose, other clothing), regenerate it. The
extractor keeps every changed pixel, so drift elsewhere would leak into the
overlay. Small whole-image shifts of a few pixels are fine; the tool realigns them.

### Items

**helmet**: {WHERE} = "on his head"

- `brutes_war_helm`: Brute's War-Helm
- `goblin_fang_circlet`: Goblin Fang Circlet
- `iron_helm`: Iron Helm
- `reinforced_helm`: Reinforced Helm
- `sentinel_visor`: Sentinel Visor

**chest**: {WHERE} = "as his torso armour, over the undershirt"

- `brutes_bulwark_plate`: Brute's Bulwark Plate
- `leather_jerkin`: Leather Jerkin
- `reinforced_plate`: Reinforced Plate
- `troll_hide_mantle`: Troll-Hide Mantle
- `warlords_battleplate`: Warlord's Battleplate

**gloves**: {WHERE} = "on both hands"

- `brute_gauntlets`: Brute Gauntlets
- `goblin_claw_gauntlets`: Goblin Claw Gauntlets
- `leather_gloves`: Leather Gloves
- `lurker_claw_gauntlets`: Lurker Claw Gauntlets
- `reinforced_gauntlets`: Reinforced Gauntlets

**pants**: {WHERE} = "on his legs"

- `brute_legguards`: Brute Legguards
- `goblin_raider_leggings`: Goblin Raider Leggings
- `iron_greaves`: Iron Greaves
- `leather_leggings`: Leather Leggings
- `warlords_legguards`: Warlord's Legguards

**boots**: {WHERE} = "on both feet"

- `reinforced_boots`: Reinforced Boots
- `sentinels_striders`: Sentinel's Striders
- `traveler_boots`: Traveler's Boots
- `trollhide_striders`: Trollhide Striders
- `warlords_greaves`: Warlord's Greaves

**weapon**: {WHERE} = "held in his right hand (the hand on the viewer's LEFT), at the same grip angle the reference art holds its hammer"

- `iron_sword`: Iron Sword
- `lurker_fang_blade`: Lurker Fang Blade
- `sentinels_lance`: Sentinel's Lance
- `steel_greatsword`: Steel Greatsword
- `warlords_greatblade`: Warlord's Greatblade

**offhand**: {WHERE} = "strapped to his left forearm (the arm on the viewer's RIGHT), facing the viewer"

- `iron_buckler`: Iron Buckler
- `sentinel_ward`: Sentinel Ward
- `sentinels_aegis`: Sentinel's Aegis
- `trollhide_buckler`: Trollhide Buckler
- `wooden_buckler`: Wooden Buckler

## 3. Processing (Claude Code)

```
# base body (once)
python tools/asset-pipeline/extract_worn_overlay.py --base-only \
    assets/source/characters/hero_base_body_raw.png assets/art/characters/hero_base_body.png
# each item
python tools/asset-pipeline/extract_worn_overlay.py \
    assets/source/characters/hero_base_body_raw.png \
    assets/source/characters/gear/<item_id>_edit.png \
    assets/art/characters/gear/<item_id>_worn.png --check check.png
```

Then:
- Set `assets/data/hero/hero_appearance.tres` `base_texture` to `hero_base_body.png`.
  This happens once, after the base is approved. The current baked-gear art stays the base until then.
- Set each item's `worn_texture` in `assets/data/items/<item_id>.tres`.
- In each new overlay's `.import`, set `process/size_limit=768` (same as the base
  body) and rescan. The overlay is scaled per axis to the base anyway; this only saves memory.
- Live-check in the Equipment paperdoll and in a mission (mirror, bob, hit flash).

Layer order (back to front, data in `hero_appearance.tres`): boots, pants, chest,
gloves, helmet, offhand, main_hand. If a chest piece's shoulders should cover
the gloves' cuffs (or similar), change the order rather than re-generating.
