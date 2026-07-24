# Story 006: Entry Always Defaults to OVERVIEW; Player-Initiated Return

> **Epic**: Sanctuary UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 7/7 passing; `/story-done` verification complete)
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-07-13b
> **Estimate**: 3h

## Context

**GDD**: `design/gdd/sanctuary-ui.md`
**Requirement**: `TR-sanctuary-ui-???` (no TR-ID registered — scoped from GDD Core Rule 5, AC Group 5, and the States/Transitions "mounted" AC)

**ADR Governing Implementation**: ADR-0002 (Scene/Autoload Structure)
**ADR Decision Summary**: SceneManager only initiates SANCTUARY↔MISSION transitions in response to terminal mission events, never mid-wave. Sanctuary UI's sole mount trigger is `scene_transition_completed(target_context="SANCTUARY")`.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `SceneManager.transition_to_sanctuary()` always instantiates a fresh scene via `change_scene_to_packed()` — confirmed against the real shipped implementation. No room-state persistence across visits is required by construction; there is no stale-instance case to guard against.

**Control Manifest Rules (this layer)**:
- Required: connect in `_ready()`, disconnect in `_exit_tree()` — source: ADR-0001
- Forbidden: SceneManager only transitions on terminal mission events, never mid-wave — source: ADR-0002 (this story's mount trigger must respect that boundary, not invent a new one)

---

## Acceptance Criteria

*From GDD `design/gdd/sanctuary-ui.md`, AC Group 5:*

- [x] GIVEN `mission_phase_changed(new_phase="MISSION_COMPLETE")` fires and SceneManager transitions to Sanctuary, THEN Sanctuary UI mounts with `OVERVIEW` as the active state.
- [x] GIVEN the same as above but `new_phase="DEFEAT"`, THEN the same mount-to-`OVERVIEW` behavior occurs.
- [x] GIVEN a prior Sanctuary UI instance had `ROOM_EQUIPMENT_FORGE` active immediately before its scene was unloaded, WHEN the player returns via a new `scene_transition_completed(target_context="SANCTUARY")`, THEN the newly mounted instance starts at `OVERVIEW`, not `ROOM_EQUIPMENT_FORGE`.
- [x] GIVEN any `ROOM_*` state is active, WHEN the player presses tab strip entry 1 / hotkey `1`, THEN the active state becomes `OVERVIEW`.
- [x] GIVEN Sanctuary UI has just mounted, THEN the active state is `OVERVIEW` before any other input is processed.

---

## Implementation Notes

Sole mount trigger: `scene_transition_completed(target_context="SANCTUARY")`. Every mount defaults to `OVERVIEW`, regardless of which room was open on a prior visit — consistent with `save-persistence.md`'s "no UI state is ever saved" rule. This is not a special code path — it is simply the initial state assignment at construction time.

Player-initiated return: tab strip entry 1 / hotkey `1` (already wired by Story 002) reaches `OVERVIEW` from any `ROOM_*` state exactly like any other tab-strip navigation — no new mechanic, just confirming this is reachable at any time (not only on forced mission-return entry).

This story also owns the `sanctuary_structure_built`-while-not-`ROOM_DEFENSE_BUILDING` always-listening requirement (Edge Cases): the diorama subscribes and updates regardless of active state, since it's shell-owned and keeps running for the shell's whole lifetime (Story 001). The Defense Building Connection Badge fallback for this same event is Story 003's scope; this story only owns the diorama's own always-listening update.

---

## Out of Scope

- Story 001: the diorama node's own persistence across room switches (this story only covers what state it *starts* in on mount)
- Story 003: Connection Badge behavior for `sanctuary_structure_built`

---

## QA Test Cases

- **AC-1/AC-2 (mount-to-OVERVIEW on MISSION_COMPLETE and DEFEAT)**
  - Given: `mission_phase_changed` fires with `new_phase="MISSION_COMPLETE"` then separately `"DEFEAT"`
  - When: SceneManager transitions to Sanctuary
  - Then: Sanctuary UI mounts with `OVERVIEW` active, in both cases
  - Edge cases: none additional

- **AC-3 (no room-state persistence across visits)**
  - Given: prior instance had `ROOM_EQUIPMENT_FORGE` active before unload
  - When: a new `scene_transition_completed(target_context="SANCTUARY")` mounts a fresh instance
  - Then: new instance starts at `OVERVIEW`
  - Edge cases: none additional

- **AC-4 (player-initiated return)**
  - Given: any `ROOM_*` state active
  - When: tab strip entry 1 / hotkey `1` pressed
  - Then: active state becomes `OVERVIEW`
  - Edge cases: test from all 4 rooms individually

- **AC-5 (OVERVIEW before any input)**
  - Given: Sanctuary UI has just mounted
  - When: state queried immediately, before any input processed
  - Then: active state is `OVERVIEW`
  - Edge cases: none additional

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/sanctuary_ui/entry_and_return_test.gd`

**Status**: [x] Created — `tests/integration/sanctuary-ui/entry-and-return_test.gd` (7/7 passing, verified live via headless GdUnit4, 2026-07-24)

---

## Dependencies

- Depends on: Story 001 (diorama/shell structure must exist)
- Unlocks: Story 009 (Launch/Depart's own return-to-Mission-Select flow assumes this entry model)

---

## Completion Notes
**Completed**: 2026-07-24
**Criteria**: 5/5 passing
**Deviations**: None
**Test Evidence**: Logic: `tests/integration/sanctuary-ui/entry-and-return_test.gd` (7/7 passing) — placed under `tests/integration/` rather than `tests/unit/`, matching this epic's established precedent of exercising this behavior against the real shell rather than in isolation.
**Code Review**: Complete (full Sanctuary UI code-review pass, 2026-07-24)
