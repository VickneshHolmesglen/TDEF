# Story 001: Structural Model — Full-Frame Diorama, RoomHost, Persistent Chrome

> **Epic**: Sanctuary UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 8/8 passing; `/story-done` verification complete)
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-07-13b
> **Estimate**: 3h

## Context

**GDD**: `design/gdd/sanctuary-ui.md`
**Requirement**: `TR-sanctuary-ui-???` (no TR-ID registered — see epic's own Untraced Requirements note; scoped directly from GDD Core Rule 1 and AC Group 1)

**ADR Governing Implementation**: ADR-0002 (Scene/Autoload Structure)
**ADR Decision Summary**: Establishes the project's scene-instanced-vs-Autoload placement convention. Sanctuary UI is scene-instanced, mounted by SceneManager on `scene_transition_completed(target_context="SANCTUARY")` — no dedicated Sanctuary-UI-architecture ADR exists yet (epic-level gap, flagged not hidden).

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM
**Engine Notes**: The z-order guarantee (shell chrome always drawn above `RoomHost`'s content) depends on no hosted room introducing its own `CanvasLayer` — verified against `InventoryScreen.tscn` today (no `CanvasLayer` present), but 3 of the 4 rooms' `.tscn` files don't exist yet (OQ-5) and must be re-checked as each is built.

**Control Manifest Rules (this layer)**:
- Required: `InputModeTracker` (reusable, scene-instanced — not an Autoload) instanced per interactive UI screen — source: ADR-0011
- Forbidden: never use `CanvasLayer` per entity/element for z-ordering — creates a new rendering context and breaks batching — source: ADR-0013 (applies here to the chrome-above-room guarantee)
- Guardrail: total scene draw calls ≤ 200/frame — source: technical-preferences.md

---

## Acceptance Criteria

*From GDD `design/gdd/sanctuary-ui.md`, AC Group 1:*

- [x] GIVEN Sanctuary UI has just mounted to `OVERVIEW`, WHEN any of the 4 rooms is entered, THEN the Sanctuary-overview diorama node itself remains present in the scene tree (shell-owned, never freed) even though not the visible content — confirmed by node-reference identity before/after.
- [x] GIVEN any `ROOM_*` state is active, THEN the active room's root `Control` bounding rect equals the shell's `RoomHost` rect exactly (frame minus tab strip width and header height) — not a percentage-of-frame margin.
- [x] GIVEN `OVERVIEW` is active, THEN the diorama's rendered bounding rect equals the frame minus the same tab strip width and header height.
- [x] GIVEN any state, THEN the Room Tab Strip and persistent resource header are both present and rendering — never absent.

---

## Implementation Notes

Build the shell as: a shell-owned diorama node (persists for the shell's whole lifetime, subscribed to `sanctuary_structure_built` regardless of visibility — see Story 006 for the entry/mount behavior), a `RoomHost` `Control` (full-rect anchored, minus chrome), and a chrome layer (tab strip + header, Stories 002–004) drawn above `RoomHost`.

Z-order: chrome must render above `RoomHost` content unconditionally. Since no hosted room currently introduces a `CanvasLayer` (verified against `InventoryScreen.tscn`), standard Control z-order (tree order) is sufficient today — do not add a `CanvasLayer` for the chrome itself, since that reintroduces the batching cost ADR-0013 warns against elsewhere in this project. If a future room does introduce a `CanvasLayer`, this becomes a real risk (OQ-5) — flag it at that room's own implementation story, not here.

`RoomHost`'s rect must be computed as frame size minus tab-strip width (Tuning Knobs, 56–96px) and header height (Tuning Knobs, 40–64px) — exact values from Story 002/004's own tuning knob stories. Do not hardcode a margin percentage.

---

## Out of Scope

- Story 002: tab strip's own navigation logic and Connection Badges
- Story 004: resource header's own data-binding
- Story 005: what each room actually renders once hosted
- Story 007: room lifecycle (destroy-and-recreate) mechanics

---

## QA Test Cases

- **AC-1 (diorama node persists across room entry)**
  - Given: Sanctuary UI mounted at `OVERVIEW`, diorama node reference captured
  - When: any of the 4 rooms is entered
  - Then: the captured diorama node reference is still valid and unchanged (`is_instance_valid` true, same instance ID)
  - Edge cases: repeat for all 4 rooms individually

- **AC-2 (room rect equals RoomHost rect)**
  - Given: any `ROOM_*` state active
  - When: room root `Control`'s global rect is queried
  - Then: rect equals frame size minus configured tab-strip width and header height, exactly (no additional margin)
  - Edge cases: test at minimum and maximum configured tab-strip/header tuning-knob values

- **AC-3 (diorama rect equals working frame)**
  - Given: `OVERVIEW` active
  - When: diorama's rendered bounding rect is queried
  - Then: equals frame minus tab-strip width and header height
  - Edge cases: none additional

- **AC-4 (chrome always present)**
  - Given: each of `OVERVIEW` and all 4 `ROOM_*` states in turn
  - When: chrome nodes (tab strip, header) are queried for visibility/tree-presence
  - Then: both present and rendering in every state
  - Edge cases: none additional

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/story-001-structural-model-evidence.md` or interaction test via Godot MCP `get_scene_tree`/`get_ui_elements`

**Status**: [x] Created — `tests/integration/sanctuary-ui/structural-model_test.gd` (8/8 passing, verified live via headless GdUnit4, 2026-07-24)

---

## Dependencies

- Depends on: None (foundational — first story in this epic)
- Unlocks: Story 002, Story 004, Story 005, Story 007

---

## Completion Notes
**Completed**: 2026-07-24
**Criteria**: 4/4 passing
**Deviations**: None
**Test Evidence**: UI: `tests/integration/sanctuary-ui/structural-model_test.gd` (8/8 passing)
**Code Review**: Complete (full Sanctuary UI code-review pass, 2026-07-24 — CHANGES REQUIRED found in room_host.gd/sanctuary_ui.gd, all remediated same session)
