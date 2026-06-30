# Sprint 2 — 2026-05-31 to 2026-06-11

## Sprint Goal

Implement all 4 Foundation-layer autoloads (EventBus, Save & Persistence, Grid,
Pathfinding) to Vertical-Slice-playable depth, with passing unit tests for each,
so Sprint 3 can begin Core-layer implementation without Foundation uncertainty.

## Capacity

- Total days: 10
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|-------------|-------------------|
| S2-01 | EventBus autoload implementation | godot-gdscript-specialist | 1 day | ADR-0001, `design/gdd/event-bus.md` | All 61 catalogued events emit without error; batch limiter (20/frame) enforced; ≥5 unit tests pass in `tests/unit/event_bus/` |
| S2-02 | Save & Persistence autoload implementation | godot-gdscript-specialist | 1.5 days | ADR-0003, `design/gdd/save-persistence.md` | Atomic `.tmp→.dat` write succeeds; 3-slot `restore_order` verified; every `store_*` call checks bool return (Godot 4.4+ requirement); unit tests pass |
| S2-03 | Grid System autoload implementation | godot-gdscript-specialist | 1.5 days | ADR-0005, `design/gdd/grid-system.md` | 16×12 grid initialises; `get_cell_type()` returns correct values; Grid write API restricted to Tower System by convention (enforced via control manifest); unit tests pass |
| S2-04 | Pathfinding autoload implementation | godot-gdscript-specialist | 2 days | ADR-0004, `design/gdd/pathfinding.md` | `templates_ready` fires after spawn→goal pre-computation; reroute triggers on `tower_placed` EventBus event; `would_block_all_paths()` 6-step procedure correct; unit tests pass |
| S2-05 | Foundation boot-order integration test | godot-gdscript-specialist | 0.5 days | S2-01, S2-02, S2-03, S2-04 | All 4 autoloads boot in declared order (EventBus → Save → Grid → Pathfinding) with no errors; sequence validated in test harness (`tests/integration/`) |

**Must Have total**: 6.5 days

### Should Have

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|-------------|-------------------|
| S2-06 | T1 draw-call batching ADR (ADR-0013) | technical-director | 0.5 days | None | ADR-0013 Accepted; atlas/batching strategy specified; Risk T1 mitigated; Sprint 3 stacked-entity stories unblocked |
| S2-07 | Author `design/gdd/game-pillars.md` | creative-director | 0.5 days | `design/gdd/game-concept.md` | 3 named pillars + design tests written; CD sign-off; CD-flagged carry-forward resolved |
| S2-08 | S1-08 carryover — set min test coverage | technical-director | 0.25 days | None | `technical-preferences.md` `Minimum Coverage` field updated with a real threshold (e.g. 80%) |

**Should Have total**: 1.25 days

### Nice to Have

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|-------------|-------------------|
| S2-09 | S1-10 carryover — Godot 4.6 API verification pass | technical-director | 2 days | None | Each of 9 MVP GDDs annotated with any post-cutoff API risks; Pathfinding and Save GDDs covered first (highest risk); `docs/engine-reference/godot/` updated if new gaps found |

**Nice to Have total**: 2 days

---

**Total load**: 7.75 days vs 8 available — S2-09 is feasible only if Must Have finishes without surprises.

---

## Carryover from Sprint 1

| Task | Reason | New ID | New Est. |
|------|--------|--------|----------|
| S1-08 Min test coverage | Deprioritised in Sprint 1 — no implementation to cover yet | S2-08 | 0.25 days |
| S1-10 Godot 4.6 API pass | Nice to Have; deferred when Sprint 1 ran long on ADR chain | S2-09 | 2 days |

_S1-09 (VS target) completed 2026-05-25 — not a carryover._

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Pathfinding `would_block_all_paths()` complexity causes time overrun | Medium | Medium — delays S2-05 boot integration test | Time-box S2-04 to 2 days; if blocked, stub `would_block_all_paths()` as always-false and log a follow-up story before Sprint 3 |
| Godot 4.6 `FileAccess` bool-return behaviour diverges from GDD spec | Low | High — Save system broken at runtime | S2-02 author must verify every `store_*` call return; S2-09 surfaces this if reached |
| T1 draw-call ADR (S2-06) not written before Sprint 3 → Core entity stories blocked | Low | High — Sprint 3 scope cannot include stacked-sprite entity scenes | Escalate S2-06 to Must Have if Sprint 3 planning begins before S2-06 is Accepted |
| No milestone document → sprint has no formal milestone anchor | Low | Medium — definition of "done for Pre-Production" not codified | Write `production/milestones/ms-01-vertical-slice.md` in Sprint 3 as a Should Have |

---

## Dependencies on External Factors

- Godot 4.6.2 editor launchable for implementation + test runs (godot MCP)
- GUT test framework runnable via CI (`.github/workflows/tests.yml` wired in Sprint 1)

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-02.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests in `tests/`
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered Foundation autoloads
- [ ] Design documents updated for any implementation deviations
- [ ] Code reviewed and merged
