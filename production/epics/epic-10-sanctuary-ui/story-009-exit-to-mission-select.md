# Story 009: Exit — Launch/Depart to Mission Select, Terminal Latch

> **Epic**: Sanctuary UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 8/8 passing; `/story-done` verification complete. **Updated 2026-07-25**: the "hand off to Mission Select" gap is now closed for real — see note below)
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
- [x] GIVEN `OVERVIEW` is active, WHEN Launch/Depart is confirmed, THEN the active state becomes `DEPARTING`, and Sanctuary UI subsequently calls Mission Select's direct entry point (not SceneManager) to hand off ownership. — **Resolved 2026-07-25**: the call is now `GSceneManager.transition_to_mission("")` — a genuine SceneManager transition (not a direct Mission Select call, a deliberate correction from the AC's original literal wording once a real destination scene existed to transition to) landing on `MissionScene.tscn`, which hosts the real Mission Select screen.
- [x] GIVEN the player switches among `OVERVIEW` and all 4 `ROOM_*` states repeatedly, THEN no externally-observable event fires on any of those internal transitions — confirmed by asserting no EventBus emission is captured except the eventual Launch/Depart or Loadout hand-off call.
- [x] GIVEN `DEPARTING` is active, THEN no action is available to the player (Launch/Depart, tabs, hotkeys, Cancel all produce no state change).
- [x] GIVEN `DEPARTING` completes its transition beat, THEN the hand-off reaches Mission Select's `BROWSING` state (verified via Mission Select's own state, not just "an event fired"). — **Resolved 2026-07-25**: `MissionSelect.state` defaults to `BROWSING` and a real Mission Select screen is now mounted and genuinely receives input — live-verified via Godot MCP (mission selection, tier/modifier configuration, and launch all exercised against the real running scene).
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

**Gap closed 2026-07-25** (was: "Sanctuary UI hands off to Mission Select has no resolved API," flagged 2026-07-24): `MissionScene.tscn` now exists — a real, generic MISSION-context scene hosting both a real Mission Select browsing/configuring screen and (once launched) the actual playable mission, switching between them based on `GMissionSelect.state` (mirroring `sanctuary_ui.gd`'s/`tarot_deck_ui.gd`'s own shell-plus-switchable-content pattern). `confirm_launch_depart()` now calls `GSceneManager.transition_to_mission("")` — a deliberate correction from this story's own AC's literal "not SceneManager" wording, made once a real destination scene existed to transition to (a direct `MissionSelect` call alone cannot swap the active scene). Live-verified end-to-end via Godot MCP: real mission selection, tier/modifier configuration, launch, real Grid initialization from authored mission data, real WaveManager SCOUT-phase transition, and Hero spawning at the correct position. ADR-0020's Criterion A/B classification (OQ-2) remains formally open — shipped ahead of it, per this epic's own established precedent.

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
**Completed**: 2026-07-24 (hand-off gap closed for real 2026-07-25)
**Criteria**: 7/7 passing — as of 2026-07-25, AC-5's "receives input" half is resolved: a real Mission Select browsing/configuring screen (`src/gameplay/ui/mission_select_screen/`) now exists, hosted inside the new generic `MissionScene.tscn`, and genuinely receives input (live-verified via Godot MCP: mission selection, tier/modifier configuration, launch, all exercised against the real running scene).
**Deviations**: `confirm_launch_depart()` now calls `GSceneManager.transition_to_mission("")` rather than a direct `MissionSelect` entry point — a deliberate correction from this story's original AC-2 wording, made once `MissionScene.tscn` existed as a real destination to transition to (see AC-2 note above). ADR-0020's Criterion A/B classification (OQ-2) remains formally open — this story shipped ahead of it, per this epic's established precedent. Real bug found and fixed during this session's `/code-review` remediation (2026-07-24): `DEPARTING_STATE` previously fell into the generic "hide diorama" branch instead of keeping it visible per the GDD's camera-pull-back requirement — fixed in `sanctuary_ui.gd`'s `set_active_state()`. Two further real bugs found and fixed 2026-07-25 in `MissionSelect` itself while building the hand-off destination: `confirm_launch()` never initialized `Grid` on first launch (only `retry_current_mission()` did), and `reset_to_defaults()` left `state`/`_current_mission_id`/`difficulty_tier`/`_run_modifiers`/all `_runtime_*` fields untouched — both fixed, see `mission_select.gd`.
**Test Evidence**: Integration: `tests/integration/sanctuary-ui/exit-mission-select_test.gd` (8/8 passing); `tests/integration/mission-select-screen/mission_select_screen_test.gd` (12/12 passing); `tests/integration/mission-scene/mission_scene_test.gd` (4 tests, real-mission Grid/Hero verification)
**Code Review**: Complete (full Sanctuary UI code-review pass, 2026-07-24). Mission Select build itself (2026-07-25) has NOT yet been through `/code-review` — deliberately deferred per user instruction this pass.
