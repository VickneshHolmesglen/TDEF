# Story 014: Edge Cases & State Transitions

> **Epic**: Epic 07 — Cross-Cutting Flow Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-select.md`
**Requirement**: `TR-missel-003`

**ADR Governing Implementation**: ADR-0028 (Mission Select Runtime State and Retry Architecture)
**ADR Decision Summary**: The `CompletionLedger` is keyed by raw `mission_id` strings, entirely independent of whether that id currently resolves via `GameDataRegistry.get_mission_entry()` — an orphaned key is retained unconditionally, and only the catalogue UI's own iteration (which walks the loaded `MissionEntry` roster, never the ledger) determines what is ever displayed.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No new engine subsystem — pure state-machine/data-integrity logic.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0028/mission-select.md Edge Cases and States and Transitions directly.
- Forbidden: The UI must never iterate the `CompletionLedger` directly to determine what's displayable — always walk the `MissionEntry` roster and look up the ledger by a known-valid `mission_id`, never invert this ordering.
- Guardrail: Mission Select only reacts to `MISSION_COMPLETE`/`DEFEAT` on `mission_phase_changed` — it must take no action and its own state must not change for any other in-mission phase (SCOUT, PRE_WAVE, WAVE_ACTIVE, INTERMISSION).

---

## Acceptance Criteria

*From GDD `design/gdd/mission-select.md`, scoped to this story:*

- [x] AC-27 *(EC-1)* — a mission with no `completion_records` entries displays every tier as `completed:false, best_time_seconds:-1.0`, no error
- [x] AC-28 *(EC-5)* — an orphaned `completion_records` entry (unknown `mission_id`) is retained, warning logged, never surfaced in UI, load never blocks
- [x] AC-29 — every documented state transition (BROWSING↔CONFIGURING↔LAUNCHED↔DORMANT_RETRY_ARMED) fires only its documented trigger; no undocumented transition is reachable
- [x] AC-30 — phases other than `MISSION_COMPLETE`/`DEFEAT` cause no action and no state change

---

## Implementation Notes

*Derived from ADR-0028 Implementation Guidelines / mission-select.md's Edge Cases and States and Transitions sections:*

- **EC-1**: a `mission_id` with no `completion_records` entries for any tier is treated as `completed:false, best_time_seconds:-1.0` for every tier — normal state for any never-attempted mission/tier pair, no error, no content-authoring warning.
- **EC-5**: on load, if `completion_records` contains an entry keyed by a `mission_id` that matches no currently-shipped `MissionEntry`, it's restored as orphaned (not discarded — supports the mission being re-added later). Never surfaced in the catalogue UI (no `MissionEntry` to display it against), cannot be selected/launched. Log: `"Orphaned completion record for unknown mission_id '[id]' — retained, not discarded."` Load never blocks or fails.
- **State machine** (`BROWSING` → `CONFIGURING` → `LAUNCHED` → `DORMANT_RETRY_ARMED` → `LAUNCHED` [retry] → `BROWSING` [MISSION_COMPLETE]): each transition fires only its documented entry trigger. `BROWSING → LAUNCHED` directly (skipping CONFIGURING) must never be reachable.
- Mission Select subscribes to `mission_phase_changed` only to know when to clear (`MISSION_COMPLETE`) or retain (`DEFEAT`) `MissionRuntimeState` — it does not otherwise react to in-mission phase transitions (SCOUT, PRE_WAVE, WAVE_ACTIVE, INTERMISSION are entirely Wave Manager's concern).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: the happy-path completion-tracking logic these edge cases wrap
- Story 013: `retry_current_mission()`'s own EC-6 guard (a separate, already-covered edge case)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-27**: No-data-yet display, EC-1
  - Given: a `mission_id` with no `completion_records` entries for any tier
  - When: the mission card is displayed
  - Then: every tier reads as `completed:false, best_time_seconds:-1.0` with no error or content-authoring warning

- **AC-28**: Orphaned completion record, EC-5
  - Given: a loaded save whose `completion_records` contains an entry keyed by a `mission_id` matching no currently-shipped `MissionEntry`
  - When: the load completes
  - Then: the orphaned entry is retained (not discarded), a warning is logged with the exact specified text, never surfaced in the catalogue UI, cannot be selected/launched, load does not block or fail

- **AC-29**: Only documented transitions reachable
  - Given: the state machine (BROWSING, CONFIGURING, LAUNCHED, DORMANT_RETRY_ARMED)
  - When: every documented transition is exercised in sequence (BROWSING→CONFIGURING→LAUNCHED→DORMANT_RETRY_ARMED→LAUNCHED[retry]→BROWSING[MISSION_COMPLETE])
  - Then: each transition fires only its documented entry trigger; no undocumented transition (e.g. BROWSING→LAUNCHED directly) is ever reachable

- **AC-30**: No reaction to irrelevant phases
  - Given: Mission Select subscribed to `mission_phase_changed`
  - When: phases other than `MISSION_COMPLETE`/`DEFEAT` fire (SCOUT, PRE_WAVE, WAVE_ACTIVE, INTERMISSION)
  - Then: Mission Select takes no action, its own state (`LAUNCHED`/`DORMANT_RETRY_ARMED`) does not change

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/mission-select/edge-cases-state-transitions_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/mission-select/edge-cases-state-transitions_test.gd` (11 tests, passing)

---

## Dependencies

- Depends on: Story 009 (`CompletionLedger`), Story 013 (state transitions this story validates)
- Unlocks: None further within this epic

**Unblocked**: ADR-0028 accepted 2026-07-18 (Sprint 6, S6-03).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 4/4 passing (11 unit tests, all passing).
**Deviations**: This story additionally implemented `get_save_data()`/`restore_save_data()`/`reset_to_defaults()`/`get_save_key()` (full `SaveRestorer`, `restore_order=11`) — no dedicated persistence story exists elsewhere in this 14-story epic slice, and EC-5's "on load" behavior required it. Landed here since AC-28 is this story's own scope. `GSavePersistence.register()`/`unregister()` wired into `_ready()`/`_exit_tree()`.
**Test Evidence**: Logic — `tests/unit/mission-select/edge-cases-state-transitions_test.gd`.
**Code Review**: Complete (batch review across Stories 009-014) — APPROVED WITH SUGGESTIONS, all required fixes applied (see mission_select.gd's SaveRestorer leaf-validation and can_launch() fixes).

**MISSION SELECT SUB-EPIC COMPLETE: 7/7 stories (008-014) done.**
