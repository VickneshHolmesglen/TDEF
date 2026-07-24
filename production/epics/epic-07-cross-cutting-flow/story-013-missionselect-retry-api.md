# Story 013: `retry_current_mission()` API & `MissionRuntimeState`

> **Epic**: Epic 07 — Cross-Cutting Flow Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-select.md`
**Requirement**: `TR-missel-001`, `TR-missel-002`

**ADR Governing Implementation**: ADR-0028 (Mission Select Runtime State and Retry Architecture)
**ADR Decision Summary**: Mission Select is reclassified as **Autoload #12** — `MissionRuntimeState` must survive the SANCTUARY→MISSION scene transition itself (a scene-instanced node would be freed on scene unload), a different class of gap than Constellation/Tower Mastery's mid-session-restore concern. `retry_current_mission()` re-emits `mission_launched` with cached values and re-delivers the exact same `GridConfig` instance to Grid — never a re-fetched equivalent.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `_runtime_grid_config`'s same-instance guarantee is satisfied structurally by GDScript's reference semantics for `Resource` fields — the field is simply never `.duplicate()`'d.

**Control Manifest Rules (this layer)**:
- Required: Read API is a documented direct-call exception to EventBus-only — source: ADR-0005 (Grid's write API, `Grid.initialize(config)`, called directly per Criterion A).
- Forbidden: `retry_current_mission()` must never fall back to re-fetching a fresh `GridConfig` from the catalogue if `MissionRuntimeState` is somehow absent — this would violate Grid's Rule 10 same-instance guarantee.
- Guardrail: `retry_current_mission()` is Criterion B (ADR-0020) — a single-caller, single-callee, state-guarded direct Autoload call from Mission HUD, already named as ADR-0020's own worked example before this ADR existed.

---

## Acceptance Criteria

*From GDD `design/gdd/mission-select.md`, scoped to this story:*

- [x] AC-23 *(interface dependency flagged — new API surface)* — retry re-emits `mission_launched` with values identical to the original, same `GridConfig` instance (not re-fetched) re-delivered to Grid
- [x] AC-24 — `MISSION_COMPLETE` clears `MissionRuntimeState`, returns to `BROWSING`; retry is not armed/valid in this state
- [x] AC-25 *(EC-6 guard)* — `MissionRuntimeState` absent when retry is called: logs error, takes no action, never falls back to a fresh `GridConfig` fetch
- [x] AC-26 — retry timing: `completion_time_seconds` clock restarts from the retry's `mission_launched` re-emission, not cumulative with the original failed attempt

---

## Implementation Notes

*Derived from ADR-0028 Implementation Guidelines — this is the core reason Mission Select is reclassified Autoload:*

```gdscript
# MissionSelect (Autoload #12, implements SaveRestorer per ADR-0003)
var _runtime_mission_id: String = ""
var _runtime_grid_config: GridConfig = null
var _runtime_difficulty_tier: int = 0
var _runtime_modifiers: PackedStringArray = PackedStringArray()

func retry_current_mission() -> void:
    if _runtime_mission_id.is_empty() or _runtime_grid_config == null:
        push_error("MissionSelect.retry_current_mission() called with no armed MissionRuntimeState.")
        return   # EC-6 — never falls back to a fresh GridConfig fetch
    Grid.initialize(_runtime_grid_config)   # same instance, Criterion A — ADR-0005's actual write API name
    EventBus.mission_launched.emit(_runtime_mission_id, _runtime_modifiers, _runtime_difficulty_tier)
```

- `MissionRuntimeState` set once at initial `mission_launched`: `_runtime_mission_id`, `_runtime_grid_config` (the **exact instance reference** from `MissionEntry.grid_config` — never `.duplicate()`'d), `_runtime_difficulty_tier`, `_runtime_modifiers`. Cleared (`null`/empty) on `mission_phase_changed → MISSION_COMPLETE`; retained unchanged on `→ DEFEAT` (arms retry).
- `MissionRuntimeState` is **never persisted to save** — excluded entirely from `get_save_data()`'s payload, confirmed by a unit test checking the field's absence, not merely a null value.
- `retry_current_mission()` is callable as a bare global (`MissionSelect.retry_current_mission()`) from Mission HUD, a `MissionScene` child, with no node reference held — this is what the Autoload reclassification resolves.
- Completion timing (Formula 3): a retried run's clock restarts from the retry's `mission_launched` re-emission — not cumulative across retries.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: `CompletionLedger`'s best-time tracking itself (this story only covers the retry-timing edge of Formula 3)
- Story 011: the initial (non-retry) `mission_launched` flow this API re-triggers

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-23** `[interface dependency flagged]`: Retry re-emits identical values, same instance
  - Given: an initial `mission_launched` for `mission_id="mission_03"`, `difficulty_tier=2`, `modifiers=["extend_waves"]`, followed by `DEFEAT` and a Mission HUD-initiated `retry_current_mission()` call
  - When: the retry executes
  - Then: `mission_launched("mission_03", ["extend_waves"], 2)` re-fires with identical values, and the *same* `GridConfig` instance (object identity, not merely equal fields) is re-delivered to Grid
  - Edge cases: not testable until the Autoload method is implemented as specified — this AC is the interface this GDD introduces

- **AC-24**: `MISSION_COMPLETE` clears state
  - Given: a completed mission run (`MISSION_COMPLETE`, not `DEFEAT`)
  - When: the phase transition is observed
  - Then: `MissionRuntimeState` is cleared, state returns to `BROWSING` — `retry_current_mission()` is not armed and calling it is not a valid player-reachable path

- **AC-25**: Missing-state guard, EC-6
  - Given: `MissionRuntimeState` is somehow absent when `retry_current_mission()` is called
  - When: the call executes
  - Then: Mission Select logs an error, takes no action — never silently falls back to fetching a fresh `GridConfig` from the catalogue

- **AC-26**: Retry timing restarts the clock
  - Given: a DEFEAT-then-retry sequence via `retry_current_mission()`
  - When: `completion_time_seconds` is measured for the retried attempt
  - Then: the clock restarts from the retry's `mission_launched` re-emission — not cumulative with the original failed attempt's elapsed time

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/mission-select/retry-current-mission-api_test.gd` — must exist and pass, including an object-identity assertion (`==` on the `Resource` reference) for `_runtime_grid_config`

**Status**: [x] Created — `tests/integration/mission-select/retry-current-mission-api_test.gd` (6 tests, passing, including object-identity assertion for `_runtime_grid_config`)

---

## Dependencies

- Depends on: Story 008 (`MissionEntry`/`GridConfig`), Story 011 (initial `mission_launched` flow)
- Unlocks: None further within this epic — Mission HUD's Defeat screen consumption of this API (owned outside this GDD)

**Unblocked**: ADR-0028 accepted 2026-07-18 (Sprint 6, S6-03). Note carried forward: `ADR-0002` (Scene/Autoload structure) should still be revised to reflect Mission Select's Autoload #12 reclassification per ADR-0028's own Risks section — a documentation-consistency follow-up, not a code blocker.

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 4/4 passing (6 integration tests, all passing).
**Deviations**: None.
**Test Evidence**: Integration — `tests/integration/mission-select/retry-current-mission-api_test.gd`.
**Code Review**: Complete (batch review across Stories 009-014) — APPROVED WITH SUGGESTIONS, all required fixes applied.
