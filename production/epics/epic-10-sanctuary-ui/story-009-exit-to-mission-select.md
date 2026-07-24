# Story 009: Exit — Launch/Depart to Mission Select, Terminal Latch

> **Epic**: Sanctuary UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 8/8 passing; `/story-done` verification complete. The terminal-latch state machine is fully real; the actual "hand off to Mission Select" call is a flagged placeholder — see note below)
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b
> **Estimate**: 4h

## Context

**GDD**: `design/gdd/sanctuary-ui.md`
**Requirement**: `TR-sanctuary-ui-???` (no TR-ID registered — scoped from GDD Core Rule 8, AC Group 8, States/Transitions `DEPARTING` rows, and the terminal-latch half of the Edge Cases section)

**ADR Governing Implementation**: ADR-0020 (Direct-Autoload-call exception pattern)
**ADR Decision Summary**: Governs the direct, non-EventBus call from Sanctuary UI to Mission Select's own entry point. **Not yet formally classified** under Criterion A/B — GDD's own OQ-2 flags this. Implement as a direct call per `mission-select.md`'s own established UI entry point (matching the precision Core Rule 8 itself describes), but flag the unclassified status prominently in code review — do not treat this story's completion as resolving OQ-2.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM (unclassified ADR status, not an engine-API risk)
**Engine Notes**: None beyond standard direct-call and EventBus-disconnect discipline.

**Control Manifest Rules (this layer)**:
- Required: disconnect every EventBus subscription in `_exit_tree()`/on terminal transition — source: ADR-0001
- Forbidden: never call `SceneTree.change_scene_to_file()`/`change_scene_to_packed()` directly from a gameplay system — this hand-off goes through Mission Select's own entry point, not a raw scene-tree call — source: ADR-0002

---

## Acceptance Criteria

*From GDD `design/gdd/sanctuary-ui.md`, AC Group 8 and the `DEPARTING`-specific States/Transitions and terminal-latch Edge Cases items:*

- [x] GIVEN any `ROOM_*` state is active, THEN no Launch/Depart control exists or is reachable — only present when `OVERVIEW` is active.
- [x] GIVEN `OVERVIEW` is active, WHEN Launch/Depart is confirmed, THEN the active state becomes `DEPARTING`, and Sanctuary UI subsequently calls Mission Select's direct entry point (not SceneManager) to hand off ownership. — the call itself (`GMissionSelect.back_out_to_browsing()`) is a flagged placeholder, not the resolved real entry point; see the Out of Scope gap note.
- [x] GIVEN the player switches among `OVERVIEW` and all 4 `ROOM_*` states repeatedly, THEN no externally-observable event fires on any of those internal transitions — confirmed by asserting no EventBus emission is captured except the eventual Launch/Depart or Loadout hand-off call.
- [x] GIVEN `DEPARTING` is active, THEN no action is available to the player (Launch/Depart, tabs, hotkeys, Cancel all produce no state change).
- [?] GIVEN `DEPARTING` completes its transition beat, THEN the hand-off reaches Mission Select's `BROWSING` state (verified via Mission Select's own state, not just "an event fired"). — DEFERRED: not implementable as written; no real Mission Select browsing screen/entry point exists yet (OQ-2). `back_out_to_browsing()` does correctly set `BROWSING` state (verified), but the stronger claim ("receives input") cannot be tested until a real screen exists.
- [x] GIVEN `OVERVIEW` is active, WHEN Launch/Depart is pressed twice within the same frame (simulated double-input), THEN only one `DEPARTING` entry occurs and the second press produces no additional effect, no error, no duplicate hand-off call.
- [x] GIVEN `DEPARTING` is active, WHEN `sanctuary_structure_built`, `resources_changed`, or a room-selection input arrives, THEN all are discarded with no mutation to any rendered element — verified across all three event types. AND GIVEN a `CONNECT_DEFERRED` subscription was already queued before Launch/Depart was confirmed, THEN it still does not fire after `_departing` is set.

---

## Implementation Notes

Launch/Depart is presented in `OVERVIEW` only (irreversible, ends the Sanctuary session — the "contemplative beat before a consequential action" reasoning per Core Rule 10's reachability principle). Confirming it sets active state to `DEPARTING`, then calls Mission Select's direct entry point.

**Terminal latch, shared with Story 010's Loadout hand-off**: both the Launch/Depart confirm handler and the Loadout tab-selection handler share one `_departing` flag and one disconnect routine. Whichever handler fires first: its first EventBus-touching or state-mutating statement sets the shared flag AND synchronously disconnects every EventBus subscription this instance owns — not merely flag-checking inside each handler. This closes the race where a `CONNECT_DEFERRED` subscription already queued for later in the same frame could otherwise still fire: disconnect-not-just-flag is what makes the guarantee real, mirroring `mission_hud.gd`'s `_terminal` pattern.

No reset logic is needed: `SceneManager.transition_to_sanctuary()` always instantiates a fresh scene via `change_scene_to_packed()`, so a stale, already-latched instance can never be reused.

`DEPARTING` beat (Visual/Audio, ~0.5s): shell chrome fades out first and fastest; diorama camera performs a slow pull-back/settle. This story owns the state-machine and latch mechanics; the visual pacing itself is Story 014's scope.

---

## Out of Scope

- Story 010: Loadout's own hand-off (shares this story's terminal-latch mechanism but is a structurally distinct destination)
- Story 014: the `DEPARTING` beat's visual pacing (chrome fade, camera pull-back)

**Real gap, flagged 2026-07-24 (mirrors Story 004's balance-ownership gap in severity)**: "Sanctuary UI hands off to Mission Select" has no resolved API. Checked directly: ADR-0002's own scene hierarchy defines exactly 2 top-level scenes (SanctuaryScene, MissionScene) — there is no third "Mission Select browsing" scene/screen anywhere in this project to hand off to, and `mission_select.gd` exposes no method resembling "show my browsing UI now." The GDD's own OQ-2 already flags this exact call as "not yet classified under ADR-0020's Criterion A/B framework." Implemented the full terminal-latch state machine correctly and completely (this is the real engineering content of this story, fully tested), and call `GMissionSelect.back_out_to_browsing()` as an explicitly-flagged placeholder for the hand-off itself — the closest safe, idempotent real method available, not a resolved design decision. AC-5's stronger claim ("control genuinely passes to Mission Select... receives input") is NOT implementable until a real browsing screen/scene exists. Recommend resolving OQ-2 with its own architectural decision before this AC is treated as closed.

---

## QA Test Cases

- **AC-1 (Launch/Depart only in OVERVIEW)**
  - Given: each `ROOM_*` state active in turn
  - When: Launch/Depart control queried for existence/reachability
  - Then: not present in any `ROOM_*` state
  - Edge cases: none additional

- **AC-2 (confirm → DEPARTING → Mission Select call)**
  - Given: `OVERVIEW` active
  - When: Launch/Depart confirmed
  - Then: active state becomes `DEPARTING`, Mission Select's direct entry point called (not SceneManager)
  - Edge cases: none additional

- **AC-3 (internal transitions silent)**
  - Given: repeated switching among `OVERVIEW` and all 4 rooms
  - When: EventBus emissions captured throughout
  - Then: no emission except the eventual Launch/Depart or Loadout hand-off call
  - Edge cases: none additional

- **AC-4 (DEPARTING is a pure transitional state)**
  - Given: `DEPARTING` active
  - When: Launch/Depart, tabs, hotkeys, Cancel attempted
  - Then: no state change from any of them
  - Edge cases: test each input type individually

- **AC-5 (hand-off genuinely reaches Mission Select)**
  - Given: `DEPARTING` completes its transition beat
  - Then: Mission Select's own state becomes `BROWSING` and it receives input — not merely that Sanctuary UI's state reads `DEPARTING`
  - Edge cases: none additional

- **AC-6 (double-press discarded)**
  - Given: `OVERVIEW` active
  - When: Launch/Depart pressed twice within the same frame
  - Then: only one `DEPARTING` entry, second press no-ops
  - Edge cases: none additional

- **AC-7 (terminal latch discards events, including deferred)**
  - Given: `DEPARTING` active, including a `CONNECT_DEFERRED` subscription already queued before confirm
  - When: `sanctuary_structure_built`, `resources_changed`, room-selection input arrive; queued deferred call attempts to fire
  - Then: all discarded, no mutation, deferred call does not fire
  - Edge cases: test all 3 event types individually plus the deferred-call race

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/sanctuary_ui/exit_mission_select_test.gd` — must include the `CONNECT_DEFERRED` race test (AC-7), not just flag-state checks

**Status**: [x] Created — `tests/integration/sanctuary-ui/exit-mission-select_test.gd` (8/8 passing, verified live via headless GdUnit4, 2026-07-24, including the `CONNECT_DEFERRED` race test)

---

## Dependencies

- Depends on: Story 001 (OVERVIEW state), Story 007 (room teardown feeds into DEPARTING if a room was active — though Launch/Depart is OVERVIEW-only so no room is ever active at trigger time)
- Unlocks: Story 010 (shares the terminal-latch mechanism)

---

## Completion Notes
**Completed**: 2026-07-24
**Criteria**: 6/7 passing, 1/7 deferred (AC-5's "receives input" half — no real Mission Select browsing screen exists yet, OQ-2)
**Deviations**: ADVISORY — the Mission Select hand-off call is a flagged placeholder (`GMissionSelect.back_out_to_browsing()`), not the resolved real entry point. OQ-2 needs its own architectural decision before this can close for real. Real bug found and fixed during this session's `/code-review` remediation: `DEPARTING_STATE` previously fell into the generic "hide diorama" branch instead of keeping it visible per the GDD's camera-pull-back requirement — fixed in `sanctuary_ui.gd`'s `set_active_state()`.
**Test Evidence**: Integration: `tests/integration/sanctuary-ui/exit-mission-select_test.gd` (8/8 passing)
**Code Review**: Complete (full Sanctuary UI code-review pass, 2026-07-24)
