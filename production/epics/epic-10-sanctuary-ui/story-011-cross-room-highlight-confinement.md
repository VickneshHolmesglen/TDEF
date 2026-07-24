# Story 011: Cross-Room Highlighting Stays Confined to a Room

> **Epic**: Sanctuary UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 4/4 passing; `/story-done` verification complete. No new production code — confinement is a structural consequence of Story 007, this story only confirms it via tests)
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-07-13b
> **Estimate**: 2h

## Context

**GDD**: `design/gdd/sanctuary-ui.md`
**Requirement**: `TR-sanctuary-ui-???` (no TR-ID registered — scoped from GDD Core Rule 9 and AC Group 9's non-badge items)

**ADR Governing Implementation**: None specific — this is a behavioral scoping rule stated directly in the GDD, not an engine-API pattern. Related: ADR-0011 governs the focus/highlight mechanics each room's own existing pattern already uses internally.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: None — this story is a negative-assertion/scoping check (confirming something does NOT happen across rooms), not new mechanics.

**Control Manifest Rules (this layer)**:
- N/A — no specific manifest rule governs this behavioral scoping constraint beyond the general "rooms are mutually exclusive content" model established by Story 007.

---

## Acceptance Criteria

*From GDD `design/gdd/sanctuary-ui.md`, AC Group 9 (non-badge items — the badge item is covered in Story 003):*

- [x] GIVEN an item is selected in `ROOM_MENAGERIE` triggering its own in-room highlight, WHEN the player switches to `ROOM_INVENTORY_CRAFTING`, THEN no slot or element in Inventory+Crafting shows a highlight or pre-selected state as a result of the prior Menagerie selection. — verified via the generic destroy-and-recreate mechanism (Story 007); Menagerie's own real scene doesn't exist yet, tested against a stub.
- [?] GIVEN the existing Crafting-highlights-Inventory-slots pattern is exercised within `ROOM_INVENTORY_CRAFTING` (both panels visible simultaneously, per that room's own GDD), THEN it continues to function exactly as `inventory.md`/`crafting.md` specify. — DEFERRED: no such pattern has actually shipped yet (Crafting panel content is explicitly deferred per `inventory_screen.gd`'s own doc comment); substituted with a regression check confirming `InventoryScreen`'s existing slot grid builds identically hosted vs. standalone.

---

## Implementation Notes

The existing focus-highlight-on-selection pattern (Crafting highlighting Inventory slots on recipe-select; Equipment Forge's Craft tab reusing it) remains scoped to screens where both sides are visible simultaneously within one room. It does not extend across rooms — this is a natural consequence of Story 007's destroy-and-recreate lifecycle (a torn-down room's highlight state ceases to exist along with the room), not a separately-implemented cross-room suppression mechanism.

This story's job is to confirm the negative case holds (no cross-room bleed) and the positive in-room case is unaffected by hosting inside `RoomHost` — not to implement any new highlighting logic.

---

## Out of Scope

- The Inventory+Crafting in-room highlight mechanism itself — already implemented per `inventory.md`/`crafting.md`, only regression-verified here
- Story 003: Connection Badges (the mechanism that actually delivers cross-system legibility, at tab-strip granularity, in place of cross-room slot highlighting)

**Real gap, flagged 2026-07-24**: AC-2 (the existing Crafting-highlights-Inventory-slots pattern continues to function when hosted) cannot be tested against real content — `inventory_screen.gd`'s own doc comment confirms Crafting panel content is explicitly deferred, no such highlight pattern has actually shipped yet. Covered instead by a regression check confirming `InventoryScreen`'s own already-shipped slot grid still builds identically whether hosted here or standalone — the closest honest substitute available today.

---

## QA Test Cases

- **AC-1 (no cross-room highlight bleed)**
  - Given: an item selected in `ROOM_MENAGERIE`, triggering its own in-room highlight
  - When: switch to `ROOM_INVENTORY_CRAFTING`
  - Then: no element in Inventory+Crafting shows a highlight from the prior Menagerie selection
  - Edge cases: test with every other room pairing (Defense Building → Equipment Forge, etc.), not just Menagerie → Inventory

- **AC-2 (in-room highlighting still works when hosted)**
  - Given: Crafting-highlights-Inventory-slots pattern exercised within `ROOM_INVENTORY_CRAFTING`, hosted inside `RoomHost`
  - When: a recipe is selected
  - Then: functions identically to `inventory.md`/`crafting.md`'s own spec
  - Edge cases: none additional

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/sanctuary_ui/cross_room_highlight_confinement_test.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (room hosting), Story 007 (lifecycle — the mechanism that makes confinement automatic)
- Unlocks: None (leaf story)
