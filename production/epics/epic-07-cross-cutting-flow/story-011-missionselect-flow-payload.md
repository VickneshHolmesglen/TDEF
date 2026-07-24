# Story 011: Two-Step Flow & `mission_launched` Payload

> **Epic**: Epic 07 — Cross-Cutting Flow Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-select.md`
**Requirement**: `TR-missel-001`

**ADR Governing Implementation**: ADR-0028 (Mission Select Runtime State and Retry Architecture)
**ADR Decision Summary**: `mission_selected` and `mission_launched` are deliberately separate events. Selecting a mission tile in BROWSING transitions to CONFIGURING without committing any gameplay state; only pressing Launch (after the validation gate passes) emits `mission_launched` and transitions to LAUNCHED.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No new engine subsystem — pure state-machine/event-emission logic.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0028/mission-select.md Rules 6–7 directly.
- Forbidden: No event fires when backing out of CONFIGURING to BROWSING without pressing Launch — nothing was locked in, so nothing is cancelled.
- Guardrail: `mission_launched.modifiers: PackedStringArray` includes only modifiers currently at a non-`0.0` ("on") value — a modifier left at its default is omitted, not included with a zero value.

---

## Acceptance Criteria

*From GDD `design/gdd/mission-select.md`, scoped to this story:*

- [x] AC-15 — selecting a mission tile fires `mission_selected` immediately, transitions to CONFIGURING, no gameplay state changes, no `mission_launched`
- [x] AC-16 — selecting a different mission tile B directly from CONFIGURING re-fires `mission_selected("B")`, resets modifiers to `0.0` defaults and tier to B's `recommended_difficulty_tier`
- [x] AC-17 — backing out of CONFIGURING to BROWSING without pressing Launch fires no event
- [x] AC-18 *(payload inclusion rule)* — `mission_launched.modifiers` contains only non-`0.0` modifiers; a still-`0.0` modifier is omitted, not zero-valued
- [x] AC-19 — all modifiers at `0.0` defaults → `mission_launched.modifiers` is an empty `PackedStringArray()`, not omitted or null

---

## Implementation Notes

*Derived from ADR-0028 Implementation Guidelines:*

- **Two-step select → configure → launch flow (Rule 6)**: selecting a mission tile in BROWSING emits `mission_selected(mission_id)` immediately, transitions to CONFIGURING — no gameplay state (Grid, Wave Manager phase) changes yet. Pressing Launch runs the validation gate (Story 012) and, if it passes, emits `mission_launched(mission_id, modifiers, difficulty_tier)`, transitions to LAUNCHED. Selecting a different tile directly from CONFIGURING re-emits `mission_selected` with the new id and resets modifier toggles/tier to defaults. Backing out to BROWSING emits no event.
- **Payload inclusion rule (Rule 7)**: Mission Select populates `modifiers: PackedStringArray`, at launch confirm, with the `modifier_id` of every modifier currently at a non-`0.0` value. This is Mission Select's own closure of an unspecified gap in the frozen payload shape — no other GDD defines this inclusion rule (flagged assumption, tested by AC-18/AC-19).
- `MissionRuntimeState` caching itself (Rule 10) belongs to Story 013 — this story covers only the flow/payload mechanics of the initial `mission_launched` emission, not its retry-time re-emission.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 012: the Launch validation gate that must pass before `mission_launched` fires
- Story 013: `retry_current_mission()`'s re-emission of `mission_launched` with cached values

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-15**: Selection transitions without commitment
  - Given: the player selects a mission tile while in BROWSING
  - When: the selection registers
  - Then: `mission_selected(mission_id)` fires immediately, state transitions to CONFIGURING, no gameplay state (Grid, Wave Manager phase) changes, no `mission_launched` fires

- **AC-16**: Direct re-selection resets state
  - Given: the player is in CONFIGURING for mission A and selects a different tile B directly
  - When: the new selection registers
  - Then: `mission_selected(mission_id="B")` re-fires, run modifiers reset to `0.0` defaults, difficulty tier resets to B's `recommended_difficulty_tier`, state remains/re-enters CONFIGURING for B

- **AC-17**: Silent back-out
  - Given: the player backs out of CONFIGURING to BROWSING without pressing Launch
  - When: the back-out registers
  - Then: no EventBus event fires

- **AC-18**: Non-zero-only payload inclusion
  - Given: `"extend_waves"` toggled to `1.0` (on), `"difficulty_growth_boost"` left at `0.0` (off)
  - When: Launch is confirmed
  - Then: `mission_launched.modifiers` contains exactly `["extend_waves"]` — the still-`0.0` modifier is omitted, not included with a zero value

- **AC-19**: Empty array when all defaults
  - Given: all modifiers left at their `0.0` defaults
  - When: Launch is confirmed
  - Then: `mission_launched.modifiers` is an empty `PackedStringArray()`, not omitted or null

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/mission-select/two-step-flow-payload_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/mission-select/two-step-flow-payload_test.gd` (6 tests, passing)

---

## Dependencies

- Depends on: Story 010 (run modifier toggle mechanics feed this story's payload assembly)
- Unlocks: Story 012, Story 013

**Unblocked**: ADR-0028 accepted 2026-07-18 (Sprint 6, S6-03).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 5/5 passing (6 unit tests, all passing).
**Deviations**: None.
**Test Evidence**: Logic — `tests/unit/mission-select/two-step-flow-payload_test.gd`.
**Code Review**: Complete (batch review across Stories 009-014) — APPROVED WITH SUGGESTIONS, all required fixes applied.
