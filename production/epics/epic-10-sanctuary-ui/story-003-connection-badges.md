# Story 003: Connection Badges — Cross-System Legibility on the Tab Strip

> **Epic**: Sanctuary UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 8/8 passing; `/story-done` verification complete)
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b
> **Estimate**: 3h

## Context

**GDD**: `design/gdd/sanctuary-ui.md`
**Requirement**: `TR-sanctuary-ui-???` (no TR-ID registered — scoped from GDD Core Rule 2's Connection Badge mechanic, the Tuning Knobs trigger-event table, AC Group 2's badge items, and AC Group 9's badge item)

**ADR Governing Implementation**: ADR-0001 (EventBus)
**ADR Decision Summary**: Connect to EventBus signals in `_ready()`, disconnect in `_exit_tree()` — mandatory, no exceptions. This story adds 4 new read-only subscriptions (one per room tab) to the shell.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM
**Engine Notes**: The trigger-event mapping per room (Tuning Knobs table) is a first-pass guess (OQ-6) — not confirmed against each room's own owning designer. Implement against the table as written; flag any mismatch found during implementation rather than silently reinterpreting it.

**Control Manifest Rules (this layer)**:
- Required: connect in `_ready()`, disconnect in `_exit_tree()`, no exceptions — source: ADR-0001
- Forbidden: never use untyped `Dictionary` as an EventBus signal payload — source: ADR-0001

---

## Acceptance Criteria

*From GDD `design/gdd/sanctuary-ui.md`, AC Group 2 (badge items) and AC Group 9 (badge cross-system item):*

- [x] GIVEN `ROOM_MENAGERIE` is not the active state and a creature reaches its configured `READY` badge-trigger event, THEN the Menagerie tab shows a Connection Badge; WHEN `ROOM_MENAGERIE` is then entered, THEN the badge clears immediately (same frame as entry, no delayed/animated clear). — tested against `creature_returned_from_breeding_pen`, the real substituted signal (see Implementation Notes).
- [x] GIVEN the Loadout tab, THEN it never displays a Connection Badge under any EventBus event, in any state — confirming the "no badge" carve-out holds, not just that no trigger event happens to be configured for it.
- [x] GIVEN a Connection-Badge-triggering event fires for a room other than the currently active one (e.g. `recipe_unlocked` while `ROOM_MENAGERIE` is active), THEN the corresponding tab shows a badge without any element inside the currently active room changing. — tested against `recipe_discovered`, the real substituted signal.

---

## Implementation Notes

Per-room trigger events (Tuning Knobs table, first-pass guess per OQ-6):

| Room | Trigger Event |
|---|---|
| Inventory & Crafting | `recipe_unlocked` |
| Menagerie | creature reaches `READY` state |
| Defense Building | `sanctuary_structure_built` |
| Equipment Forge | `rune_socket_unlocked` |

Badges are purely informational — icon + optional count, no unread/dismiss state to persist (matches "no persisted UI state" rule). Clear the instant their owning room is entered (no fade-out beat).

Loadout carries no badge by design (OQ-8 — a deferred choice, not an impossibility) — do not wire any trigger event to it.

Defense Building's badge has a special interaction with the diorama's own `sanctuary_structure_built` flourish (Story 006/013): when `OVERVIEW` is active at event-fire time, the diorama flourish plays instead of the badge; when a `ROOM_*` state is active, the badge is the primary feedback channel. This story implements the badge half; the flourish is Story 006's/013's scope.

**Implementation note, added 2026-07-24 (real signal substitution, per this story's own "flag any mismatch" instruction)**: 2 of the GDD's 4 first-pass-guess trigger events (`recipe_unlocked`, `rune_socket_unlocked`) and the literal "creature reaches READY state" phrasing do not exist in the real EventBus catalogue. Implemented against the closest real, already-shipped signals instead: `recipe_discovered(recipe_id, recipe_category)` for Inventory & Crafting, `creature_returned_from_breeding_pen(creature_id)` for Menagerie, `sanctuary_structure_built(structure_id, structure_type)` for Defense Building (exact match, no substitution needed), `item_rune_imbued(item_id, rune_id, rune_source)` for Equipment Forge. This is exactly the confirmation pass OQ-6 already asks for — not silently treated as settled, flagged here for whoever next reviews OQ-6.

---

## Out of Scope

- Story 002: the tab strip's own click/hotkey/trigger routing (badges attach to those entries but don't drive them)
- Story 006/013: the diorama's own `sanctuary_structure_built` flourish and its OVERVIEW-vs-room interaction with this badge

---

## QA Test Cases

- **AC-1 (badge appears and clears)**
  - Given: `ROOM_MENAGERIE` not active
  - When: a creature reaches `READY`
  - Then: Menagerie tab shows badge; entering `ROOM_MENAGERIE` clears it same-frame
  - Edge cases: badge state while already inside a different room vs. while in `OVERVIEW`

- **AC-2 (Loadout never shows a badge)**
  - Given: Loadout tab
  - When: every registered badge-trigger event fires in turn (`recipe_unlocked`, creature `READY`, `sanctuary_structure_built`, `rune_socket_unlocked`)
  - Then: no badge ever renders on Loadout
  - Edge cases: fire all 4 events in the same frame

- **AC-3 (badge fires without touching active room content)**
  - Given: `ROOM_MENAGERIE` active
  - When: `recipe_unlocked` fires (Inventory & Crafting's trigger)
  - Then: Inventory & Crafting tab shows badge; no element inside the active Menagerie room changes
  - Edge cases: repeat for each of the other 3 badge-triggering events while a different room is active

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/sanctuary_ui/connection_badges_test.gd`

**Status**: [x] Created — `tests/integration/sanctuary-ui/connection-badges_test.gd` (8/8 passing, verified live via headless GdUnit4, 2026-07-24)

---

## Dependencies

- Depends on: Story 002 (tab strip must exist to attach badges to)
- Unlocks: None (leaf story)

---

## Completion Notes
**Completed**: 2026-07-24
**Criteria**: 3/3 passing
**Deviations**: ADVISORY — 3 of the GDD's 4 first-pass-guess trigger-event names didn't exist in the real EventBus catalogue; implemented against real substituted signals (documented in Implementation Notes). OQ-6 still needs owning-designer confirmation these substitutions are the intended mapping.
**Test Evidence**: Integration: `tests/integration/sanctuary-ui/connection-badges_test.gd` (8/8 passing)
**Code Review**: Complete (full Sanctuary UI code-review pass, 2026-07-24)
