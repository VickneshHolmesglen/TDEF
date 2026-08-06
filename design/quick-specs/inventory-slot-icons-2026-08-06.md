# Quick Design Spec: Inventory Slot Icons + Rarity Shape-Frames

**Type**: Addition
**System**: Inventory (`design/gdd/inventory.md`)
**GDD Reference**: `design/gdd/crafting.md` (rarity-tier visual coding, the convention this reuses), `design/quick-specs/wire-materials-into-inventory-2026-08-06.md` (Phase 1, the data this renders)
**Date**: 2026-08-06

## Change Summary

Inventory's slot buttons render a real icon (when authored) plus a shape-
first rarity frame around it, instead of always showing plain text. Falls
back to today's exact text rendering when no icon exists yet — this ships
before any of the 13 material icons are actually generated (Phase 3, still
to come), so the mechanism must not regress the current working state.

## Motivation

Phase 1 made materials real Inventory items; they're still indistinguishable
plain-text slots. This is the actual payoff half of "build the material
icons" — but the icon art itself (Phase 3) is a separate, larger art-
generation batch not done yet. Building the rendering mechanism now, with a
correct no-icon fallback, means Phase 3 becomes "generate art + set one
`icon` field per `.tres`" with zero further code changes — matching this
project's established "mechanism real, content placeholder" sequencing
(Tarot cards, tower archetypes, and every other art batch this session
followed the identical order: build the display mechanism against
placeholder/absent content first, drop real art in after).

## Design Delta

`crafting.md` already specifies the rarity vocabulary this reuses (not
altered, just consumed for the first time by a real system):

> Shape-first, color-second... Common: circular icon frame, Fieldstone Grey
> border. Uncommon: hexagonal icon frame, Scout Blue border. Rare: diamond
> icon frame, Herald Gold border... Frame shape is the primary
> differentiator (works fully colorblind); border color is confirmatory
> only. This gives real material names... a locked visual system to slot
> into.

This spec is that "future system slotting in" — no text changes to
`crafting.md` itself.

## New Rules / Values

1. **`ItemDefinitionResource` gains `icon: Texture2D = null`** — a real,
   data-driven field (never a hardcoded UI-side `item_id -> texture`
   dictionary). Null is a fully valid, expected state (no art authored yet).
2. **New `RarityFrame` control** (`_draw()`-based, no art asset needed):
   draws an outline-only circle/hexagon/diamond around a slot, colored per
   `crafting.md`'s exact vocabulary. Renders for any occupied Material-tab
   slot with a non-empty `rarity` ("Common"/"Uncommon"/"Rare") — independent
   of whether that item has an `icon` yet, since the frame is real signal on
   its own (works even wrapping today's plain text).
3. **Slot rendering logic**: for an occupied slot, resolve the
   `ItemDefinitionResource`.
   - If `icon != null`: hide the text label, show the icon texture
     (`TextureRect`, `STRETCH_KEEP_ASPECT_CENTERED`) plus a small corner
     quantity label (`"x%d"`).
   - If `icon == null` (true for all 13 materials until Phase 3 art lands,
     and for every other item type today): render exactly as now
     (`"item_id xN"` text) — zero regression to current behavior.
   - Rarity frame renders independently of the icon/text branch above,
     whenever `rarity != ""`.
4. **Non-Material item types unaffected**: Equipment/TowerComponent/
   CraftedGood have no `rarity` authored today (empty string, per
   `ItemDefinitionResource`'s own field default) — no frame renders for
   them; they keep the current text fallback until/unless a future pass
   gives them icons too (out of this spec's scope).
5. Matches this project's existing one-time-at-build rendering convention
   (`_slot_display_text()` is already computed once per slot at screen
   mount, not live-refreshed on inventory change — a pre-existing
   limitation, not something this spec fixes or worsens).

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| `src/core/inventory/item_definition_resource.gd` | New `icon: Texture2D` field | Update script |
| `src/gameplay/ui/inventory_screen/rarity_frame.gd` (new file) | Shape-drawing Control | Create script |
| `src/gameplay/ui/inventory_screen/inventory_screen.gd` | Slot-building logic branches on icon/rarity | Update script |
| `assets/data/items/*.tres` | No change yet — `icon` stays null until Phase 3 | None this pass |
| Inventory screen tests | New tests for the fallback + frame + icon-present paths | Add tests |

## Acceptance Criteria

- [ ] A Material-tab slot with `rarity="Common"` shows a circular Fieldstone-Grey outline; `rarity="Rare"` shows a diamond Herald-Gold outline
- [ ] An item with `icon == null` renders exactly as it does today (`"item_id xN"` text) — no visual regression
- [ ] An item with `icon != null` (tested via an injected fixture, since no real icon exists yet) shows the icon + a corner quantity label, no text
- [ ] Equipment/TowerComponent/CraftedGood slots are completely unaffected (no frame, same text rendering as today)
- [ ] Empty slots unaffected (no frame, no icon)
- [ ] No regression in existing Inventory screen test suites
- [ ] Live-verified via Godot MCP screenshot, both the frame-only (no icon yet) state and an injected icon-present state

## GDD Update Required?

No — this consumes `crafting.md`'s already-specified rarity vocabulary
without changing it.
