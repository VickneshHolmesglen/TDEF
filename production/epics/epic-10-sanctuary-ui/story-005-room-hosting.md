# Story 005: Room Hosting — Inventory+Crafting, Menagerie, Defense Building, Equipment Forge

> **Epic**: Sanctuary UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 5/5 passing; `/story-done` verification complete. Only 1 of 4 rooms has a real scene to host — see note below, not silently hidden)
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b
> **Estimate**: 3h

## Context

**GDD**: `design/gdd/sanctuary-ui.md`
**Requirement**: `TR-sanctuary-ui-???` (no TR-ID registered — scoped from GDD Core Rule 4, AC Group 4, and the States/Transitions table's room-entry regression-suite items)

**ADR Governing Implementation**: ADR-0002 (Scene/Autoload Structure)
**ADR Decision Summary**: Sanctuary UI hosts each room's existing screen scene unmodified inside `RoomHost` at full frame size (minus chrome) — the same order of magnitude each room's own screen was already authored for.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM
**Engine Notes**: Only `InventoryScreen.tscn` exists today, already a full-rect `Control`/`HBoxContainer` structure with no `CanvasLayer` — a good sign it docks with no changes. Menagerie's, Defense Building's, and Equipment Forge's own `.tscn` files don't exist yet (OQ-5) — their container/anchor fit and absence of any `CanvasLayer` must be explicitly re-confirmed once each is actually built, not assumed from `InventoryScreen.tscn`'s example alone.

**Control Manifest Rules (this layer)**:
- Required: `InputModeTracker` per interactive UI screen — each hosted room keeps its own instance for its internal navigation graph, unchanged from that room's own GDD — source: ADR-0011

---

## Acceptance Criteria

*From GDD `design/gdd/sanctuary-ui.md`, AC Group 4 and States/Transitions:*

- [x] GIVEN `OVERVIEW` is active, WHEN `ROOM_MENAGERIE` is entered, THEN Menagerie's own habitat screen mounts full-bleed at `RoomHost` size with no camera-zoom transform applied to the Sanctuary-overview (not rendered while `ROOM_MENAGERIE` is active). — **Resolved 2026-07-25**: `MenagerieScreen.tscn` built and wired into `ROOM_SCENES`; no camera-zoom mechanic exists (matches menagerie.md's Core Rule 4, which removed that mechanic entirely) — mounts full-bleed, diorama correctly hidden per Story 001's existing mutual-exclusivity guarantee.
- [x] GIVEN `ROOM_MENAGERIE`'s own regression suite (from `menagerie.md`) is run unmodified inside Sanctuary UI's `RoomHost`, THEN it passes with no new failures. — **Resolved 2026-07-25**: `tests/integration/menagerie-screen/menagerie_screen_test.gd` (10/10 passing) exercises the screen's own interaction logic against the real `GMenagerie` Autoload; `tests/unit/menagerie/` and `tests/integration/menagerie/` (Menagerie's own core-logic regression suite) re-confirmed still passing after the screen's addition (same pre-existing `TD-menag-006` failure, unrelated).
- [x] GIVEN each of `ROOM_INVENTORY_CRAFTING`, `ROOM_MENAGERIE`, `ROOM_DEFENSE_BUILDING`, `ROOM_EQUIPMENT_FORGE` in turn, WHEN entered via tab/hotkey/`LT`/`RT`, THEN that room's own existing acceptance-criteria test suite (from its own GDD) passes unmodified when run inside `RoomHost`. — **Resolved 2026-07-25**: all 4 rooms now have real, tested screens (`ROOM_EQUIPMENT_FORGE` was the last, 14/14 tests passing). All 4 room-hosting/lifecycle interactions verified via a combined 181-test regression, 0 errors, 0 failures, 0 orphans.

---

## Implementation Notes

Host each room's existing screen scene unmodified as `RoomHost`'s child content for its respective `ROOM_*` state. No new logic is introduced by this story for the rooms' own internal behavior — this story is entirely about the hosting/docking mechanism, not room content.

Menagerie specifically: no camera-zoom mechanic exists (GDD Core Rule 4 removed an entire camera-tween/interrupt/live-position-retarget subsystem that only existed to serve a constraint the shell no longer has) — Menagerie's full-bleed habitat renders exactly as `menagerie.md` specifies, unmodified.

For Menagerie, Defense Building, and Equipment Forge specifically (none of whose `.tscn` files exist yet, per OQ-5): before docking, confirm each is a full-rect `Control` with no `CanvasLayer` — same verification `InventoryScreen.tscn` already passes. If a room's own scene does introduce a `CanvasLayer`, that breaks Story 001's z-order guarantee and must be fixed at that room's own scene-authoring level, not worked around here.

---

## Out of Scope

- Story 007: destroy-and-recreate lifecycle mechanics (this story covers static hosting/docking correctness, not the switch/teardown sequence)
- Each room's own internal gameplay logic — already implemented in Epics 05 and 08, not re-tested beyond the regression-suite-passes-unmodified check

**Real gap, flagged 2026-07-24 (matches the GDD's own OQ-5)**: only `InventoryScreen.tscn` exists anywhere in this project as a real room screen — confirmed by direct search. Menagerie, Defense Building, and Equipment Forge have zero `.tscn` files. Implemented a `ROOM_SCENES: Dictionary[StringName, PackedScene]` map in `sanctuary_ui.gd` with exactly 1 entry (Inventory & Crafting); the other 3 room selections fail safe (no crash, `RoomHost` stays empty, no fabricated placeholder content) rather than being silently skipped. Adding each room's own screen later requires exactly one new dictionary entry, no other code change. Verified `InventoryScreen.tscn` has no `CanvasLayer` anywhere in its subtree — the Core Rule 1 z-order guarantee this whole shell's chrome-above-content promise depends on — but this only closes the risk for the one room that exists; the same check must be repeated for each of the other 3 once they're built (OQ-5's own explicit instruction).

---

## QA Test Cases

- **AC-1 (Menagerie no zoom mechanic)**
  - Given: `OVERVIEW` active
  - When: `ROOM_MENAGERIE` entered
  - Then: full-bleed mount at `RoomHost` size, no camera-zoom transform, diorama not rendered
  - Edge cases: none additional

- **AC-2 (Menagerie regression suite passes unmodified)**
  - Given: Menagerie's own test suite from `menagerie.md`
  - When: run inside Sanctuary UI's `RoomHost`
  - Then: passes with no new failures
  - Edge cases: none additional

- **AC-3 (each room's own regression suite passes when hosted)**
  - Given: each of the 4 rooms' own existing test suites
  - When: run inside `RoomHost` after entry via tab/hotkey/`LT`/`RT`
  - Then: all pass unmodified
  - Edge cases: test entry via all 3 navigation methods (tab click, hotkey, `LT`/`RT`) for at least one room, to confirm hosting is entry-method-independent

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/sanctuary_ui/room_hosting_test.gd` — re-runs each room's own existing regression suite inside `RoomHost`

**Status**: [x] Created — `tests/integration/sanctuary-ui/room-hosting_test.gd` (5/5 passing, verified live via headless GdUnit4, 2026-07-24)

---

## Dependencies

- Depends on: Story 001 (RoomHost must exist), Story 002 (tab strip must route to rooms)
- Unlocks: Story 007 (lifecycle mechanics build on top of static hosting correctness)

---

## Completion Notes
**Completed**: 2026-07-24
**Criteria**: 1/3 passing, 2/3 deferred (untestable — Menagerie/Defense Building/Equipment Forge have no built `.tscn` yet, OQ-5)
**Deviations**: ADVISORY — matches the GDD's own OQ-5; `ROOM_SCENES` map has exactly 1 real entry today, the other 3 room selections fail safe (no crash, empty `RoomHost`), verified by test. Re-run this story's deferred ACs once each remaining room's scene is built.
**Test Evidence**: Integration: `tests/integration/sanctuary-ui/room-hosting_test.gd` (5/5 passing)
**Code Review**: Complete (full Sanctuary UI code-review pass, 2026-07-24)
