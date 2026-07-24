# Story 012: DEFEAT Retry Button

> **Epic**: Epic 09 — Mission HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-hud.md`
**Requirement**: `TR-hud-000` *(untraced — scoped from Core Rules Group 10, Rules 25-27; closes `mission-select.md`'s flagged Retry-button-ownership gap)*

**ADR Governing Implementation**: ADR-0031 (Mission HUD Architecture), ADR-0028 (Mission Select Runtime State), ADR-0011 (UI Dual-Focus Handling)
**ADR Decision Summary**: `MissionSelect.retry_current_mission()` is the ONE direct-call exception in Mission HUD's entire outbound surface — ADR-0020 Criterion B (narrow, single-caller action), legal because `MissionSelect` is Autoload #12 (ADR-0028). Reuses Story 008's `InputModeTracker` instance.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: None beyond Story 008's own dual-focus notes.

**Control Manifest Rules (this layer)**:
- Required: N/A.
- Forbidden: This is the ONLY place in Mission HUD's entire emitter surface that calls another system's Autoload directly instead of emitting through EventBus — must not be treated as precedent for any other button in this epic to also bypass EventBus.
- Guardrail: Following the call, Mission HUD does not locally predict or handle the resulting `mission_launched` re-emission — it reacts to it exactly like an initial mission launch (Story 001's Rule-4 counter reset).

---

## Acceptance Criteria

*From GDD Core Rules Group 10 (Rules 25-27):*

- [x] AC-68 — Retry button exists only in the `DEFEAT` state; does not exist in any other phase. **Real architecture gap found, see Implementation Deviation Notes** — housed pragmatically inside Mission HUD's own CanvasLayer rather than a real Outcome/Defeat screen (doesn't exist yet).
- [x] AC-69 — press → calls `MissionSelect.retry_current_mission()` directly (a direct Autoload call, NOT an EventBus event) — the one deliberate exception to Mission HUD's otherwise-universal emit-only pattern
- [x] AC-70 — following the call, Mission HUD does not locally predict or handle the resulting `mission_launched` — it reacts to it exactly like an initial mission launch (Story 001's mount/reset handler), since `retry_current_mission()`'s own contract guarantees a fresh `mission_launched` firing before any other mission-context event. **Real mount-condition bug found and fixed** — see Implementation Deviation Notes.
- [x] AC-71 — a separate "Abandon to Sanctuary" action is also present on the DEFEAT screen but is explicitly out of scope for this story — Mission HUD owns the Retry button's presence, not the Abandon action's behavior. Confirmed genuinely out of scope: no Abandon action exists anywhere in this codebase yet (n/a, nothing to avoid touching).

---

## Implementation Notes

*Derived from ADR-0031/GDD Implementation Guidelines:*

```gdscript
# On MissionHud (outer root) — DEFEAT-only, per Story 001's phase tracking
func _on_retry_pressed() -> void:
    GMissionSelect.retry_current_mission()  # ADR-0020 Criterion B — the ONE direct-call exception
    # No local handling of the resulting mission_launched — Story 001's own
    # mount/reset handler (bound to mission_phase_changed(IDLE, SCOUT)) already
    # covers this identically to an initial launch.
```

- Reuses `InputModeTracker` from Story 008 — no new instance.
- This button lives on whatever DEFEAT/outcome screen node structure the GDD's DEFEAT row already establishes (outside this epic's Planning/Combat cluster split, since both clusters have already faded out by DEFEAT per Story 001's unmount).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The "Abandon to Sanctuary" action's own behavior (per `mission-select.md`'s States table) — this story owns only the Retry button's existence/press contract
- Any local prediction of `mission_launched`'s effects — Story 001's existing mount handler already covers the reset path

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-68**: DEFEAT-only existence
  - Given: each of SCOUT/PRE_WAVE/WAVE_ACTIVE/INTERMISSION/MISSION_COMPLETE/DEFEAT
  - When: the phase is entered
  - Then: Retry exists only in DEFEAT

- **AC-69**: Direct call, not EventBus
  - Given: Retry pressed
  - When: verified via a spy on `GMissionSelect.retry_current_mission`
  - Then: called directly exactly once; no corresponding EventBus signal emission drives this action

- **AC-70**: No local mission_launched prediction
  - Given: Retry pressed, `retry_current_mission()` succeeds and re-emits `mission_launched`
  - When: `mission_launched` arrives
  - Then: Mission HUD's response is identical (same handler, same code path) to an initial mission launch — no Retry-specific branch exists

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/mission-hud/defeat-retry-button_test.gd` — must exist and pass

**Status**: [x] `tests/integration/mission-hud/defeat-retry-button_test.gd` — 7 tests, all passing (104/104 across all 9 mission-hud test files, after fixing 1 pre-existing test whose DEFEAT-hides-everything assumption this story's own visibility change invalidated). Live-MCP-verified end-to-end against the real running `the_gap.tscn`: full DEFEAT→retry→SCOUT cycle confirmed Retry's visibility, `_combat_cluster` visibility, Rule-4 state reset, and Planning Cluster respawn all correct; the direct `GMissionSelect.retry_current_mission()` call confirmed to fire `mission_launched` exactly once. Full project regression re-confirmed clean (1470/1470, 0 errors, 1 pre-existing unrelated failure).

---

## Implementation Deviation Notes

- **AC-68, real architecture gap, flagged not silently assumed**: the GDD's own DEFEAT row states a separate "outcome/Defeat screen" takes over from Mission HUD entirely on DEFEAT — that screen does not exist anywhere in this codebase (no story or epic has built it yet). Implemented as a pragmatic placeholder: `RetryButton` lives inside `MissionHud`'s own `CanvasLayer`, which now stays `visible = true` specifically during DEFEAT (previously hidden the same as MISSION_COMPLETE) while `_combat_cluster` hides. **Replace with the real Outcome/Defeat screen once that scene exists** — flagged at both the field's own doc comment and here.
- **AC-70, real mount-condition bug found and fixed**: `_on_mission_phase_changed()`'s SCOUT-mount branch originally required `previous_phase == "IDLE"` specifically (Story 001's original condition). But `WaveManager._reset_all_state()` (called from `_on_mission_launched()`) never resets its own internal `_phase` field back to `IDLE` before re-transitioning to `SCOUT` on a retry — so a retry's `mission_phase_changed` arrives as `(DEFEAT → SCOUT)`, which the original condition would silently NOT match, meaning Mission HUD's entire reset/respawn path would never run on retry. Fixed by dropping the `previous_phase` check entirely (`WaveManager`'s FSM only ever enters `SCOUT` as a mission-start transition, never mid-mission, so this is safe). This is the actual mechanism that makes AC-70 true, not just documentation of an assumption.

---

## Dependencies

- Depends on: Story 001 (HUD Scaffold & Local State Model), Story 008 (InputModeTracker instance)
- Unlocks: None further within this epic
