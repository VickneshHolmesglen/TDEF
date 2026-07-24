# Story 012: Launch Validation Gate

> **Epic**: Epic 07 — Cross-Cutting Flow Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-select.md`
**Requirement**: `TR-missel-001`

**ADR Governing Implementation**: ADR-0028 (Mission Select Runtime State and Retry Architecture)
**ADR Decision Summary**: Before `mission_launched` fires, Mission Select checks: Save & Persistence's restore pass has completed, a `mission_id` is actually selected, and `difficulty_tier` holds a valid value in `{1,2,3}`. If validation fails, Launch is blocked at the UI level and `mission_launched` is never emitted.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No new engine subsystem — pure guard-clause logic.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0028/mission-select.md Rule 8 directly.
- Forbidden: Never let an invalid launch attempt reach EventBus — no downstream system (Grid, Wave Manager, Mission HUD) should ever observe a blocked attempt.
- Guardrail: This validation gate is a defensive guard, not the primary prevention mechanism — the UI itself should gray out/hide Launch outside CONFIGURING; the gate exists in case that's somehow bypassed.

---

## Acceptance Criteria

*From GDD `design/gdd/mission-select.md`, scoped to this story:*

- [x] AC-20 — Launch invoked from BROWSING with no `mission_id` selected: blocked, `mission_launched` never fires, no downstream system observes the attempt
- [x] AC-21 — Save & Persistence's restore pass incomplete: `completion_records` reads empty (EC-1 equivalent), Launch blocked until restore completion signaled
- [x] AC-22 — `difficulty_tier`'s guaranteed non-empty state (Rule 3's default-to-recommended) holds in practice — validation always passes for tier, confirming the guarantee rather than exercising an unreachable failure path

---

## Implementation Notes

*Derived from ADR-0028 Implementation Guidelines:*

- Launch validation gate (Rule 8) checks, in order: (1) Save & Persistence has completed its restore pass; (2) a `mission_id` is actually selected (flow is in CONFIGURING or later); (3) `difficulty_tier` holds a valid value in `{1,2,3}` (structurally guaranteed by Rule 3's default-to-recommended behavior).
- If validation fails, the Launch action is blocked at the UI level and `mission_launched` is never emitted — the failure never reaches EventBus at all.
- EC-4 (Save & Persistence not yet restored): as a defensive guard only, if this screen is somehow reached pre-restore, `completion_records` reads as empty for every mission (equivalent to EC-1's "no data yet" state, not an error) and the gate blocks confirm until restore completion is signaled. No crash, no launch with unrestored data.
- Per `save-persistence.md`'s `restore_order` (Mission Select = 11), this screen should structurally never be reachable pre-restore — the check exists as a defensive guard only, not the primary prevention mechanism (main menu/Sanctuary flow gates entry, outside this GDD's scope).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: the flow/payload mechanics this gate sits in front of
- Story 014: EC-1's "no data yet" display treatment itself (this story only covers the gate's behavior when restore is incomplete)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-20**: No-selection block
  - Given: the flow is in BROWSING with no `mission_id` selected
  - When: a Launch action is somehow invoked (bypassing the UI's own graying-out)
  - Then: the validation gate blocks it, `mission_launched` never fires, no downstream system (Grid, Wave Manager, Mission HUD) ever observes the attempt

- **AC-21**: Pre-restore defensive guard
  - Given: Save & Persistence's restore pass has not yet completed
  - When: the player attempts to reach or use Launch
  - Then: `completion_records` reads as empty for every mission (EC-1 equivalent), the gate blocks confirm until restore completion is signaled — no crash, no launch with unrestored data

- **AC-22**: Tier guarantee holds
  - Given: `difficulty_tier` is guaranteed non-empty by Rule 3's default-to-recommended behavior
  - When: the validation gate's tier check runs
  - Then: it always passes in practice — confirms the guarantee holds, not exercising a failure path Rule 3 asserts is unreachable

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/mission-select/launch-validation-gate_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/mission-select/launch-validation-gate_test.gd` (8 tests, passing)

---

## Dependencies

- Depends on: Story 011 (the flow this gate guards)
- Unlocks: Story 013 (retry reuses this same gate's guarantees implicitly)

**Unblocked**: ADR-0028 accepted 2026-07-18 (Sprint 6, S6-03).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 3/3 passing (8 unit tests, all passing). Code review added an additional `can_launch()` guard (unresolvable mission_id) beyond the story's original 3 checks — see game_data_registry resolution check, covered by an added regression test.
**Deviations**: None (the added guard strengthens, not deviates from, Rule 8's intent).
**Test Evidence**: Logic — `tests/unit/mission-select/launch-validation-gate_test.gd`.
**Code Review**: Complete (batch review across Stories 009-014) — APPROVED WITH SUGGESTIONS, all required fixes applied.
