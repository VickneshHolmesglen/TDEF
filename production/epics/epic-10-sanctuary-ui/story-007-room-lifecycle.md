# Story 007: Room Lifecycle — Destroy-and-Recreate, EventBus Disconnect + Input Gate, InputModeTracker Roster

> **Epic**: Sanctuary UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 6/6 passing; `/story-done` verification complete. Implemented ahead of its own Story 005 dependency — see note below)
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-07-13b
> **Estimate**: 6h

## Context

**GDD**: `design/gdd/sanctuary-ui.md`
**Requirement**: `TR-sanctuary-ui-???` (no TR-ID registered — scoped from GDD Core Rule 6 and AC Group 6; this is the story the GDD's own 6-pass review history repeatedly found underspecified, so its test coverage is unusually load-bearing)

**ADR Governing Implementation**: ADR-0032 (Presentation Shell Hosting Pattern) + ADR-0011 (UI Dual-Focus Handling) + ADR-0001 (EventBus)
**ADR Decision Summary**: ADR-0032 (written 2026-07-24, after this story was first drafted) is now the direct architectural source for this story's teardown sequence — formalizes the destroy-and-recreate + synchronous-disconnect-before-`queue_free()` pattern this story implements. `InputModeTracker` scoped per interactive UI screen (ADR-0011); every EventBus subscription established in `_ready()` must be disconnected in `_exit_tree()`, project-wide, no exceptions (ADR-0001).

**Engine**: Godot 4.6.2 | **Risk**: HIGH
**Engine Notes**: `queue_free()`'s end-of-frame deferral means a node's own signal callbacks can still fire during the deferral window even after input is gated — gating input alone does NOT gate signal delivery. This is the exact gap the GDD's own review history found and fixed across 2 independent specialist passes — treat this story's teardown-order test as the single most important regression guard in this epic.

**Control Manifest Rules (this layer)**:
- Required: connect in `_ready()`, disconnect in `_exit_tree()`, no exceptions — source: ADR-0001; `InputModeTracker` per interactive screen, freshly constructed on each room instantiation — source: ADR-0011
- Forbidden: never assume `grab_focus()` affects mouse focus — source: ADR-0011

---

## Acceptance Criteria

*From GDD `design/gdd/sanctuary-ui.md`, AC Group 6:*

- [x] GIVEN `ROOM_MENAGERIE` is entered, THEN a fresh Menagerie room instance and a fresh `InputModeTracker` for it are constructed (not reused from any prior mount) — confirmed via instance-identity comparison against a previous mount of the same room within the same session. — tested against the stub room (real Menagerie scene doesn't exist yet, OQ-5); the generic mount/unmount mechanism this AC actually exercises is engine-agnostic to room content.
- [x] GIVEN any `ROOM_*` state is exited (via Cancel-at-root, tab/hotkey/`LT`/`RT` switch, or Launch/Depart), THEN the room's own EventBus subscriptions are disconnected, followed by `set_process_unhandled_input(false)`, both called on the outgoing room synchronously before `queue_free()` is invoked — confirmed via call-order inspection, not just eventual absence from the tree. — the shared `unmount_current_room()` call-order is directly tested; each trigger (Cancel, tab-switch, Launch/Depart) routes through this same single mechanism, verified separately by Stories 008/002/009's own suites, not duplicated here.
- [x] GIVEN `ROOM_MENAGERIE` has nested state (e.g. mid-breeding-pen-flow), WHEN the player switches to `ROOM_EQUIPMENT_FORGE` via hotkey and then back to `ROOM_MENAGERIE`, THEN Menagerie mounts fresh at its own root state, not resumed mid-flow.
- [?] GIVEN `OVERVIEW` becomes active, THEN the tab strip's `InputModeTracker` holds default focus (not `OVERVIEW`'s own structure-selection tracker) unless the player has already explicitly directed input at the diorama this state-entry. — DEFERRED: the diorama has no structure-selection UI yet (no content, Story 013's own tracked gap) — untestable until it exists.
- [x] GIVEN `ROOM_MENAGERIE`'s `InputModeTracker` had focus on a breeding-pen element, WHEN the player switches to `ROOM_EQUIPMENT_FORGE` via hotkey, THEN Equipment Forge's own `InputModeTracker` starts with its own independent default focus. — tested against 2 stub-room mounts (real Menagerie/Equipment Forge scenes don't exist yet); tracker independence is verified at the generic mechanism level.

---

## Implementation Notes

Rooms are never kept alive-but-hidden. Each `ROOM_*` entry instantiates that room's scene fresh as a child of `RoomHost`; each exit runs the outgoing room through **two synchronous cleanup steps, in order, before `queue_free()`**:
1. Disconnect every EventBus subscription the room instance itself owns — every room hosted by this shell must expose this as a callable step (whatever each room's own GDD names it).
2. Call `set_process_unhandled_input(false)` on it.

This mirrors `mission_hud.gd`'s Planning Cluster precedent exactly (chosen there for the same reason: guaranteed `_ready()` re-fire, no stale subscription risk).

Focus roster: 6 `InputModeTracker` instances total across the shell's lifetime — 4 rooms (each freshly constructed on room instantiation, never reused across mounts) + 1 persistent tab-strip tracker + 1 persistent `OVERVIEW` structure-selection tracker. Never 6 *simultaneously live* — the active room's is the only one of the 4 that exists at any moment (0 or 1), plus the 2 persistent shell trackers.

Default focus in `OVERVIEW`: tab strip's tracker holds default focus. `OVERVIEW`'s own structure-selection tracker only gains focus when the player explicitly directs input at the diorama (mouse click/hover on a structure, or gamepad/keyboard `Down` from the tab strip's bottom-most focused tab). Cancel from the diorama's structure-selection ring returns focus to the tab strip.

Nested-state discard is a direct, unavoidable consequence of this lifecycle — nothing needs to explicitly clear staged state, because the node holding it no longer exists after the switch (the toast requirement for Equipment Forge/Defense Building specifically is Story 013's scope, not this story's).

---

## Out of Scope

- Story 002: what triggers a room switch (this story only covers the teardown/mount mechanics once triggered)
- Story 010: Loadout's own extended version of this teardown sequence (reuses this story's mechanism but adds the terminal-latch ordering on top — see Story 010)
- Story 013: the "Staged changes discarded" toast UX

**Dependency deviation, flagged 2026-07-24**: this story lists Story 005 (Room Hosting) as a dependency, but Story 005 was still `Ready` (not `Complete`) when this story was implemented. Proceeded anyway — Story 007's actual scope is the GENERIC destroy-and-recreate mount/unmount mechanism (`RoomHost.mount_room()`/`unmount_current_room()`), independently testable against a stub room scene, exactly the same pattern Story 001 used for `RoomHost`'s own rect math before real content existed. Story 005's own separate job — mapping each real room scene (Inventory & Crafting, Menagerie, Defense Building, Equipment Forge) to a tab-strip selection via `mount_room()` — is unaffected and still fully open; this story does not attempt it.

---

## QA Test Cases

- **AC-1 (fresh instance and tracker per room entry)**
  - Given: `ROOM_MENAGERIE` entered once, instance/tracker IDs captured; room exited and re-entered
  - When: instance IDs compared
  - Then: new instance and new `InputModeTracker`, not reused
  - Edge cases: repeat for all 4 rooms

- **AC-2 (teardown call order, all exit triggers)**
  - Given: a room active with its own EventBus subscriptions
  - When: exited via each of Cancel-at-root, tab/hotkey/`LT`/`RT` switch, Launch/Depart in turn
  - Then: subscription-disconnect call precedes `set_process_unhandled_input(false)` call, both precede `queue_free()` — verified via call-order inspection (e.g. an ordered log/mock, not just final state)
  - Edge cases: test all listed exit triggers individually, not just one

- **AC-3 (nested state never survives a lateral switch)**
  - Given: `ROOM_MENAGERIE` mid-breeding-pen-flow
  - When: switch to `ROOM_EQUIPMENT_FORGE` via hotkey, then back to `ROOM_MENAGERIE`
  - Then: Menagerie mounts fresh at root, not resumed mid-flow
  - Edge cases: none additional

- **AC-4 (OVERVIEW default focus)**
  - Given: `OVERVIEW` becomes active, no prior explicit diorama interaction this entry
  - When: focus queried
  - Then: tab strip's tracker holds focus, not the structure-selection tracker
  - Edge cases: repeat after an explicit diorama interaction — structure-selection tracker should then hold focus instead

- **AC-5 (focus independence across room switch)**
  - Given: Menagerie's tracker focused on a breeding-pen element
  - When: switch to Equipment Forge via hotkey
  - Then: Equipment Forge's own tracker starts at its own independent default focus, no carryover
  - Edge cases: none additional

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/sanctuary_ui/room_lifecycle_test.gd` — must include an explicit call-order assertion test (AC-2), not just tree-presence checks

**Status**: [x] Created — `tests/integration/sanctuary-ui/room-lifecycle_test.gd` (6/6 passing, verified live via headless GdUnit4, 2026-07-24, including explicit call-order assertion for AC-2)

---

## Dependencies

- Depends on: Story 001 (RoomHost), Story 002 (tab strip triggers), Story 005 (rooms must be hostable)
- Unlocks: Story 008 (Cancel idiom reuses this lifecycle), Story 009 (Launch/Depart teardown), Story 010 (Loadout's extended teardown), Story 013 (staged-state-discard toast)

---

## Completion Notes
**Completed**: 2026-07-24
**Criteria**: 4/5 passing, 1/5 deferred (AC-4, OVERVIEW structure-selection tracker — no diorama content exists yet)
**Deviations**: ADVISORY — real bug found and fixed during this session's `/code-review` remediation: `RoomHost` previously injected a second, unwired decoy `InputModeTracker` into every mounted room instead of looking up the room's own real tracker; fixed to a `get_node_or_null()` lookup by conventional child name, and the stub room used by this story's own tests (`RoomLifecycleStubRoom.tscn`) was updated with a real `InputModeTracker` child to match.
**Test Evidence**: Logic: `tests/integration/sanctuary-ui/room-lifecycle_test.gd` (6/6 passing) — placed under `tests/integration/`, matching this epic's precedent.
**Code Review**: Complete (full Sanctuary UI code-review pass, 2026-07-24 — this file, `room_host.gd`, was the primary target of 2 of the review's 4 Required Changes, both remediated same session)
