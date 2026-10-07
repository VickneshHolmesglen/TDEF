# Hero Equipment Appearance (worn gear shows on the hero)

**Date**: 2026-10-07
**Status**: Decisions made by the user in chat: gear shows **both** in the inventory paperdoll portrait and on the in-mission hero, and uses **fitted overlays**. Codex generates a base body plus one aligned overlay per item. Until an item's overlay lands, its icon is pinned to that slot's anchor on the body.
**Scope**: Visual only. No stat, slot, or save-format change.

## 1. Player Fantasy

What you equip is what you see. Put on a Brute's War-Helm and pick up a sword, and the warden wears them on the Equipment screen and in battle. Take them off and they're gone.

## 2. Rules

1. **Shown slots (7)**: helmet, chest, gloves, pants, boots, main_hand, offhand. Neck and the two rings are too small to read on the body and are not shown.
2. **Base body**: the hero is drawn as a base texture with gear layered on top. Today the base is the existing `hero_warden_smith.png`, which has a helmet, armour and hammer baked in. Codex will replace it with a **bare base body** (same pose, same 1024×1536 canvas, plain undershirt and trousers, empty hands) so that unequipping visibly removes gear. Swapping the base is a data change only.
3. **Fitted overlay** (`ItemDefinitionResource.worn_texture`): a transparent image on the **same canvas as the base body**, so it lines up with zero offsets. If it is set, it is drawn full-canvas over the base.
4. **Icon fallback**: an item with no `worn_texture` shows its `icon`, centred on the slot's anchor and scaled to the slot's anchor height. The anchors are data, in `HeroAppearanceResource`.
5. **Layer order** (back to front): boots, pants, chest, gloves, helmet, offhand, main_hand. This is data, so it can be changed per art needs.
6. **Updates**: rebuilt on `equipment_slot_changed` (equip, unequip, swap, double-click) and on creation (scene load or save load).
7. **In missions**: the gear layer copies the hero sprite's horizontal flip and walk-bob offset each frame. It uses the parent's material, so the hit flash and death flash tint the gear too. Modulate is inherited automatically.

## 3. Architecture

- `HeroAppearanceResource` (`assets/data/hero/hero_appearance.tres`) holds the base texture, layer order, icon anchors and icon heights.
- `HeroAppearance` (Node2D, `src/core/visual_presentation/hero_appearance.gd`) is the one component used in both places:
  - Child of the mission hero's `Sprite2D` (`Hero.tscn`).
  - Child of the paperdoll's `HeroPortrait` TextureRect. It fits itself to the rect, matching `STRETCH_KEEP_ASPECT_CENTERED`.
  - In both cases it sets its parent's texture to the configured base texture.

## 4. Art pipeline (Codex → Claude Code)

The overlays are made as **image edits** of the base body ("same character, now wearing <item>; change nothing else"). `tools/asset-pipeline/extract_worn_overlay.py` diffs each edit against the base and keeps only the changed pixels, giving an overlay that is aligned by construction. The prompts are in `design/art/hero-equipment-overlay-prompts.md`. There are 36 images: 1 base plus 35 item overlays.

## 5. Edge Cases

- An item has no icon and no worn texture: no layer, no error.
- An overlay canvas that differs from the base canvas is scaled per axis to the base size.
- An unknown item id (removed content in an old save) is skipped.
- Two-handed weapons: no special rule. A weapon overlay may cover both hands.

## 6. Acceptance Criteria

1. Equipping a shown-slot item adds a layer for that slot, in both the paperdoll and the mission hero. Unequipping removes it.
2. A `worn_texture` replaces the icon fallback with no code change.
3. Neck and ring items never add a layer.
4. In missions the gear mirrors with the hero when it faces left, bobs with the walk cycle, and flashes on hit.
5. A save that already has gear equipped shows it on first view.
