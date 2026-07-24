## QA Sign-Off Report: Sprint 2 — Foundation Layer Implementation

**Date**: 2026-06-30
**QA Lead sign-off**: APPROVED WITH CONDITIONS

---

### Test Coverage Summary

| Story | Type | Auto Test | Manual QA | Result |
|-------|------|-----------|-----------|--------|
| S2-01 EventBus | Integration | PASS — 50+ tests, 4 files | N/A | PASS |
| S2-02 Save & Persistence | Integration | PASS — 14 tests, 2 files. AC-8/AC-10/AC-12 uncovered (TD-save-001) | Accepted as open tech debt — carry to Sprint 3 | PASS WITH NOTES |
| S2-03 Grid System | Logic | PASS — 39 tests, 2 files | N/A | PASS |
| S2-04 Pathfinding | Logic | PASS — 31 tests, 3 files | Profiler obligations (AC-4, AC-17, AC-24a) deferred to Sprint 3. PLACEABLE cost advisory noted. | PASS WITH NOTES |
| S2-05 Boot-Order Integration | Integration | PASS — 7 tests, 1 file | N/A | PASS |
| S2-06 Draw-Call ADR | Config/Data | N/A | ADR-0013 Accepted; atlas strategy, z_index formula, and forbidden patterns complete. TD sign-off: GIVEN. | PASS |
| S2-07 Game Pillars | Config/Data | N/A | game-pillars.md complete: 3 pillars, design tests, interaction matrix (5 mechanics), consolidated checklist. CD sign-off: GIVEN. | PASS |
| S2-08 Min Coverage | Config/Data | N/A | 80% threshold confirmed in technical-preferences.md. | PASS |

---

### Automated Test Suite

**158 tests | 0 errors | 0 failures | 0 flaky — ALL PASS**

| Suite | Files | Tests |
|-------|-------|-------|
| tests/unit/event_bus/ | 3 | ~50+ |
| tests/unit/save_persistence/ | 2 | 14 |
| tests/unit/grid/ | 2 | 39 |
| tests/unit/pathfinding/ | 3 | 31 |
| tests/integration/event_bus/ | 1 | included in EventBus count |
| tests/integration/foundation/ | 1 | 7 |

All test suites green. No flaky tests detected.

---

### Smoke Check

**Verdict: PASS WITH WARNINGS**

Advisory only: `tests/integration/pathfinding/` directory is absent from the QA plan expected
path. All 4 intended pathfinding integration behaviors are confirmed covered by passing tests at
alternate paths. No blocking action required; advisory noted for Sprint 3 directory hygiene.

---

### Bugs Found

None. No bugs filed this sprint.

---

### Conditions Carried to Sprint 3

1. **TD-save-001 — S2-02 integration coverage gaps**: AC-8 (deferred emit timing), AC-10
   (register() direct test), and AC-12 (EventBus signal wiring) have no automated test coverage.
   Accepted as open tech debt this sprint. Must be closed in Sprint 3 before any save system
   work is marked complete.

2. **S2-04 profiler obligations**: AC-4 (100 `get_path()` calls ≤1ms p99.9), AC-17
   (`would_block_all_paths()` ≤5ms p99 on 24×18 grid), and AC-24a (fallback A* baseline
   measurement) are deferred to the first playtest session in Sprint 3. These ACs are not
   satisfied until profiler measurements are recorded.

3. **S2-04 PLACEABLE cost advisory — CLOSED (2026-07-06, S3-09)**: PLACEABLE cost is currently
   10.0 in implementation. ADR-0004 implies a monster would take >19 PATH-cell detours before
   the shortcut is preferred; however, the actual detour threshold may be lower due to A*
   heuristic behaviour. Game designer must confirm the acceptable monster shortcut threshold
   before Vertical Slice. This is a design decision, not a bug, but must not be deferred past
   the VS gate. **Resolution**: Game designer confirmed 10.0 as-is — see
   `design/gdd/pathfinding.md`'s `pathfinding_placeable_cost` Tuning Knob row for the full
   confirmation rationale and `production/stories/core/s3-09-placeable-cost-confirmation.md`
   for the closed story. No code change — `PLACEABLE_COST` in
   `src/foundation/pathfinding/pathfinding_system.gd` remains 10.0.

---

### Verdict: APPROVED WITH CONDITIONS

**Conditions**: The following must be closed before this sprint's foundation is considered
fully complete:

- TD-save-001 (AC-8, AC-10, AC-12) resolved with passing automated tests in Sprint 3
- Pathfinding profiler measurements recorded for AC-4, AC-17, and AC-24a at Sprint 3 first playtest
- Game designer confirmation on PLACEABLE cost / acceptable monster shortcut threshold logged
  before Vertical Slice gate

No S1 or S2 bugs are open. All stories are PASS or PASS WITH NOTES with documented rationale.
The sprint foundation is stable and Sprint 3 work may begin.

---

### Next Step

Carry TD-save-001 and the three S2-04 profiler obligations into the Sprint 3 backlog as explicit
tickets before sprint planning closes. Then run `/gate-check` to validate advancement to the
next project phase.
