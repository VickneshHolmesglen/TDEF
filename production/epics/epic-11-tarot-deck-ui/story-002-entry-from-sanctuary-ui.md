# Story 002: Entry — Sanctuary UI's Loadout Affordance

> **Epic**: Tarot Deck UI
> **Status**: Complete (2026-07-24 — implemented, tested live via GdUnit4, 3/3 passing; `/story-done` verification complete. **Updated 2026-07-25**: AC-3's phase-gate concern led to finding and fixing a real, separate bug — see note below.)
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b
> **Estimate**: 3h

## Context

**GDD**: `design/gdd/tarot-deck-ui.md`
**Requirement**: `TR-tarot-deck-ui-???` (no TR-ID registered — scoped from GDD Core Rule 3 and AC Group 2)

**ADR Governing Implementation**: ADR-0020 (Direct-Autoload-call exception pattern)
**ADR Decision Summary**: This shell's entry is the receiving end of Sanctuary UI's own Loadout hand-off (Sanctuary UI Epic 10, Story 010). **Not yet formally classified** under Criterion A/B — mirrors OQ-9 on the Sanctuary UI side.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM (unclassified ADR status, not an engine-API risk)
**Engine Notes**: This story depends on Sanctuary UI Epic 10's Story 010 being implemented first — the hand-off call must match Tarot Deck UI's own established entry point exactly, per this GDD's own Interactions table.

**Control Manifest Rules (this layer)**:
- Required: disconnect every EventBus subscription in `_exit_tree()` — source: ADR-0001 (applies once this shell is torn down on its own exit, Story 003)

---

## Acceptance Criteria

*From GDD `design/gdd/tarot-deck-ui.md`, AC Group 2:*

- [x] GIVEN the player is at any Sanctuary UI state — `OVERVIEW` or a `ROOM_*` state — WHEN the Loadout tab is selected, THEN this shell opens, defaulting to `HERO_SKILL_BUILD` (Player Fantasy's "build, then deck" ordering, flagged provisional per OQ-3). — tested against the shell's own fresh-mount default; the actual Sanctuary UI → Tarot Deck UI call is still unwired (Epic 10 Story 010's own flagged gap).
- [x] GIVEN the shell was previously exited (via Cancel or the explicit return affordance) while `TAROT_DECK` was the active state, WHEN the shell is re-entered via a fresh Loadout selection, THEN it defaults to `HERO_SKILL_BUILD` again, not the last-used screen — confirming the default is a genuine fixed default, not accidentally sticky session state.
- [x] GIVEN a mission is currently active (Tarot `LOCKED`, Hero Skill Build `LOCKED`), WHEN the player attempts to reach this shell, THEN entry is unavailable — inherited from the underlying phase gate, not a shell-specific check. — **Resolved 2026-07-25, differently than expected**: this scenario is actually structurally unreachable, not merely ungated. Sanctuary UI (and therefore its Loadout tab) can only ever be mounted via `SceneManager.transition_to_sanctuary()`, and every real caller of that method (the normal mission-complete/hero-died flow, and `pause_menu.gd`'s "Quit to Sanctuary" option) represents the player already having left mission-active state — so there is no code path where Sanctuary UI is displayed while a mission is genuinely "active." No new gate was needed. **However, investigating this surfaced a real, separate, previously-undiscovered bug**: `pause_menu.gd`'s "Quit to Sanctuary" calls `transition_to_sanctuary()` directly with no `mission_phase_changed` emission — the *only* event that cleared `tarot.gd`'s `_locked` flag — meaning a mid-mission quit left Tarot's deck permanently LOCKED in Sanctuary with no future unlock trigger, even though `hero_skill_build.gd`'s own equivalent `_is_sanctuary` flag correctly unlocks via `scene_transition_completed`. Fixed: `tarot.gd` now also subscribes to `scene_transition_completed` and unlocks on `target_context == "SANCTUARY"`, mirroring Hero Skill Build's already-correct mechanism. 2 new regression tests added to `tests/integration/tarot/state-tables-persistence_test.gd` (14/14 passing).

---

## Implementation Notes

Sole entry trigger: Sanctuary UI's Loadout tab-strip entry (Core Rule 2/10 in `sanctuary-ui.md`, redesigned 2026-07-24), selectable from **any** Sanctuary UI state, not `OVERVIEW`-only. Selecting it tears down whatever room is currently active (if any, on the Sanctuary UI side) and hands off to this shell.

Every mount defaults to `HERO_SKILL_BUILD`, regardless of which screen was active on a prior visit — no sticky session state, matching Sanctuary UI's own "no UI state persisted" rule. This default is provisional (OQ-3) — not confirmed against actual playtest behavior; flagged, not silently treated as settled.

Entry gating: inherited from the underlying phase model (Tarot `LOCKED`/Hero Skill Build `LOCKED` during an active mission) — this shell does not implement its own separate gate.

---

## Out of Scope

- Sanctuary UI Epic 10, Story 010: the sending side of this hand-off (this story only implements the receiving side)
- Story 001: the shell's own internal tab-strip navigation once mounted

**Real gap, flagged 2026-07-24**: AC-3 (entry blocked during an active mission, "inherited from the underlying phase gate, not a shell-specific check") has no actual enforcement anywhere — Sanctuary UI's own Loadout tab (Epic 10 Story 002/010) does not currently check Tarot/Hero Skill Build `LOCKED` state before allowing selection. The GDD explicitly expects this to be an external system's responsibility, not this shell's — but that external check doesn't exist in this project yet. AC-1/AC-2 (defaults to `HERO_SKILL_BUILD`, not sticky) are fully real and tested — they hold by construction from Story 001's own fresh-instantiation model.

---

## QA Test Cases

- **AC-1 (entry from any Sanctuary UI state, defaults to HERO_SKILL_BUILD)**
  - Given: player at `OVERVIEW` or any Sanctuary UI `ROOM_*` state
  - When: Loadout tab selected
  - Then: this shell opens, `HERO_SKILL_BUILD` active
  - Edge cases: test from `OVERVIEW` and from each of Sanctuary UI's 4 rooms individually

- **AC-2 (default is fixed, not sticky)**
  - Given: shell previously exited while `TAROT_DECK` was active
  - When: shell re-entered via a fresh Loadout selection
  - Then: defaults to `HERO_SKILL_BUILD` again
  - Edge cases: repeat across multiple entry/exit cycles to confirm no session-local memory accumulates

- **AC-3 (entry blocked during active mission)**
  - Given: a mission active, Tarot and Hero Skill Build both `LOCKED`
  - When: player attempts to reach this shell
  - Then: entry unavailable
  - Edge cases: none additional

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/tarot_deck_ui/entry_from_sanctuary_ui_test.gd`

**Status**: [x] Created — `tests/integration/tarot-deck-ui/entry-from-sanctuary-ui_test.gd` (3/3 passing, verified live via headless GdUnit4, 2026-07-24)

---

## Dependencies

- Depends on: Story 001 (shell must exist to mount into), Sanctuary UI Epic 10 Story 010 (sending side of the hand-off)
- Unlocks: Story 003 (exit's return path mirrors this entry model)

---

## Completion Notes
**Completed**: 2026-07-24 (AC-3 resolved 2026-07-25)
**Criteria**: 3/3 passing — AC-3 is satisfied by construction (Sanctuary UI cannot be mounted while a mission is genuinely active, per `SceneManager`'s own real callers), not by a new gate. Sanctuary UI's Loadout tab → this shell hand-off itself was wired for real in an earlier 2026-07-25 session pass (`SceneManager.transition_to_tarot_deck_ui()` + `TarotDeckUIScene.tscn`) — the "no scene-transition entry point exists" gap this note previously described is closed.
**Deviations**: None remaining. A real, separate bug was found and fixed while investigating AC-3: `tarot.gd`'s `_locked` flag could get stuck permanently `true` after a mid-mission quit via `pause_menu.gd`'s "Quit to Sanctuary" (which bypasses `mission_phase_changed`) — fixed by also unlocking on `scene_transition_completed(SANCTUARY)`, mirroring `hero_skill_build.gd`'s already-correct mechanism.
**Test Evidence**: Integration: `tests/integration/tarot-deck-ui/entry-from-sanctuary-ui_test.gd` (3/3 passing); `tests/integration/tarot/state-tables-persistence_test.gd` (14/14 passing, 2 new regression tests for the lock-state fix)
**Code Review**: Complete (full Tarot Deck UI code-review pass, 2026-07-24). The 2026-07-25 lock-state fix has NOT yet been through `/code-review` — deliberately deferred per this session's "skip reviews till the end" instruction.
