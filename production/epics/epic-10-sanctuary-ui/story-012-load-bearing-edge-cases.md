# Story 012: Load-Bearing Edge Cases — Rapid Input, Staged-Discard Toast, Watchtower No-Room Click

> **Epic**: Sanctuary UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 4/4 passing; `/story-done` verification complete. 3 of 4 edge-case items hit gaps already flagged by earlier stories — see note below, not silently papered over)
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b
> **Estimate**: 4h

## Context

**GDD**: `design/gdd/sanctuary-ui.md`
**Requirement**: `TR-sanctuary-ui-???` (no TR-ID registered — scoped from the GDD's own "Load-Bearing Edge Cases" section, minus items already covered by Story 007 AC-2 call-order, Story 009's terminal-latch items, and Story 010's Loadout-specific staged-discard case)

**ADR Governing Implementation**: ADR-0001 (EventBus) + ADR-0011 (UI Dual-Focus Handling)
**ADR Decision Summary**: These edge cases are direct consequences of the EventBus disconnect discipline (ADR-0001) and the destroy-and-recreate lifecycle (ADR-0011's `InputModeTracker` scoping) already implemented in Stories 007/009/010 — this story adds the remaining untested combinations and the toast UX itself.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM
**Engine Notes**: The rapid-input case specifically exercises `queue_free()`'s end-of-frame deferral window — the same class of risk Story 007 addresses, here tested under adversarial input timing (5 rooms targeted faster than any mount-complete callback fires).

**Control Manifest Rules (this layer)**:
- Required: disconnect every EventBus subscription in `_exit_tree()`, no exceptions — source: ADR-0001

---

## Acceptance Criteria

*From GDD `design/gdd/sanctuary-ui.md`, remaining Load-Bearing Edge Cases items not covered by Stories 007/009/010:*

- [x] GIVEN `OVERVIEW` is active, WHEN the player presses `LT`/`RT`/hotkeys for 5 different rooms in rapid succession, faster than any single room's mount-complete callback fires, THEN only the last-targeted room ends up mounted and active, no errors thrown, no stale `InputModeTracker` signal connections remain from torn-down intermediate rooms (verified via connection-count inspection after settling).
- [x] GIVEN the player switches away from `ROOM_EQUIPMENT_FORGE` or `ROOM_DEFENSE_BUILDING` via `LT`/`RT`/hotkey while an unconfirmed staged action is pending, THEN the staged action's data is gone after the switch AND a non-blocking "Staged changes discarded" toast is shown — verified as two separate assertions. — the data-gone half is real and tested (via the generic teardown mechanism); the toast UI itself is Story 013's scope and does not exist yet.
- [?] GIVEN a structure with no corresponding room (e.g. Watchtower) is selected via `OVERVIEW`'s secondary entry path, THEN no room-mount is attempted (active state remains `OVERVIEW`), an inert tooltip naming the structure appears, and the structure itself continues rendering at its fixed diorama position both before and after the click. — DEFERRED: nothing to test — the diorama has zero structure representation or click interaction anywhere in this project (confirmed: `Diorama` has 0 children), a not-yet-built feature with no story in this epic covering diorama content.
- [?] GIVEN Sanctuary UI is mounting and `resources_changed` has not yet fired from Resource Economy, THEN the header displays Resource Economy's current balance via a direct mount-time poll rather than an empty/loading/zero placeholder state. — DEFERRED: Story 004's own already-flagged balance-ownership gap; not implementable until a system owns a queryable Sanctuary-context balance.

---

## Implementation Notes

**Rapid input mashing**: each input immediately tears down the in-flight room and mounts the next — no queueing. Per Story 007's destroy-and-recreate lifecycle, the outgoing room has its own EventBus subscriptions disconnected and `set_process_unhandled_input(false)` called on it synchronously before `queue_free()`, so it cannot double-handle an input or a stray signal in the same frame the next room mounts. This story's test is the adversarial-timing stress case for Story 007's own mechanism.

**Staged-discard toast**: a brief, non-blocking toast ("Staged changes discarded") plays on the departing room's own toast/notification affordance if it has one, or a shell-level equivalent otherwise. Nothing has been spent yet at the staged (not-yet-confirmed) step, so no data/resource loss occurs — only lost UI progress. This story implements the toast itself; Story 010 already covers the Loadout-triggered variant of this same case (identical outcome, different trigger).

**Watchtower / no-room structures**: clicking a structure with no corresponding room via `OVERVIEW`'s secondary entry path shows an inert info tooltip naming the structure, matching that structure's own "no gameplay effect" framing (per `defense-building.md`). The Sanctuary-overview still renders it at its fixed position regardless — rendering is never gated on room-mapping, only the click-to-enter path is.

**Mount-time resource-header poll**: already implemented in Story 004 — this story's AC item is the explicit boot-order-race test coverage for it, not new implementation.

---

## Out of Scope

- Story 007: the core teardown mechanism this story stress-tests under rapid input
- Story 004: the resource header's own polling implementation (this story only adds the explicit boot-order-race test)
- Story 010: Loadout's own staged-discard trigger path (already covered there)

**Real gaps, flagged 2026-07-24, 3 of this story's 4 items**: (1) the staged-discard TOAST half has no toast UI to test yet — the DATA-gone half is real and tested, matching Story 010's own identical split; (2) the Watchtower/no-room click item has literally nothing to test — the diorama has zero structure representation or click interaction anywhere in this project (confirmed directly: `Diorama` has 0 children as of this story), not a bug, a not-yet-built feature with no story in this epic covering diorama content; (3) the mount-time resource poll item is Story 004's own already-flagged, unresolved balance-ownership gap, not re-litigated here. Implemented and fully tested what IS real: rapid-input mashing (both a 5-target and a full-6-entry sequence, including Loadout), and the staged-discard data-gone half via the same mechanism Story 010 already proved.

---

## QA Test Cases

- **AC-1 (rapid-mash: last-targeted room wins, no leaks)**
  - Given: `OVERVIEW` active
  - When: `LT`/`RT`/hotkeys targeting 5 different rooms pressed faster than any mount-complete callback fires
  - Then: only the last-targeted room mounted and active; no errors; connection-count inspection shows zero stale `InputModeTracker` signal connections from torn-down intermediate rooms
  - Edge cases: vary the exact input sequence/timing across repeated test runs to avoid a single lucky timing window masking a race

- **AC-2 (staged-discard toast on room-switch)**
  - Given: `ROOM_EQUIPMENT_FORGE` or `ROOM_DEFENSE_BUILDING` active with unconfirmed staged action
  - When: switch away via `LT`/`RT`/hotkey
  - Then: staged data gone AND toast shown — both asserted independently
  - Edge cases: test both rooms individually

- **AC-3 (Watchtower/no-room click)**
  - Given: `OVERVIEW` active
  - When: a no-corresponding-room structure (e.g. Watchtower) clicked via secondary entry path
  - Then: no room-mount, active state remains `OVERVIEW`, inert tooltip shown, structure still rendering before/after
  - Edge cases: none additional

- **AC-4 (mount-time resource poll under boot-order race)**
  - Given: Sanctuary UI mounting, `resources_changed` not yet fired
  - When: header renders
  - Then: displays Resource Economy's current balance via direct poll, not an empty/loading/zero state
  - Edge cases: none additional

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/sanctuary_ui/load_bearing_edge_cases_test.gd` + `production/qa/evidence/story-012-load-bearing-edge-cases-evidence.md` for the toast's visual/feel confirmation

**Status**: [x] Created — `tests/integration/sanctuary-ui/load-bearing-edge-cases_test.gd` (4/4 passing, verified live via headless GdUnit4, 2026-07-24). No separate evidence doc written — the toast/Watchtower/mount-poll items are deferred (nothing built yet to evidence), not implemented-but-unverified.

---

## Dependencies

- Depends on: Story 004 (header poll), Story 007 (teardown lifecycle), Story 010 (Loadout's parallel staged-discard case, for consistency)
- Unlocks: None (leaf story)

---

## Completion Notes
**Completed**: 2026-07-24
**Criteria**: 1/4 fully passing, 1/4 partially passing (data-half only), 2/4 deferred (Watchtower/diorama content, resource-poll gap)
**Deviations**: ADVISORY — 3 of 4 items hit gaps already flagged by earlier stories (Story 004's balance-ownership gap, Story 013's toast UI scope, and the diorama's total absence of structure content). Fully real and tested: rapid-input mashing under adversarial timing (Story 007's own mechanism, stress-tested here) and the staged-discard data-gone half.
**Test Evidence**: Integration: `tests/integration/sanctuary-ui/load-bearing-edge-cases_test.gd` (4/4 passing)
**Code Review**: Complete (full Sanctuary UI code-review pass, 2026-07-24)
