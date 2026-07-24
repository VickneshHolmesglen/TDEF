# QA Sign-Off Report: Sprint 3 — Core Combat Engine

**Date**: 2026-07-01
**Sprint**: Sprint 3 (2026-06-30 to 2026-07-11)
**QA Lead sign-off**: [pending developer suite confirmation]
**Smoke check**: `production/qa/smoke-2026-07-01.md` — PASS WITH WARNINGS
**QA plan**: `production/qa/qa-plan-sprint-03-2026-06-30.md`

---

## Test Coverage Summary

| Story | Type | Auto Test | Manual QA | Result |
|-------|------|-----------|-----------|--------|
| S3-01: TD-save-001 Debt Closure | Integration | NOT RUN — PASS W/ WARNINGS (21 test functions across 2 files confirmed) | AC-8 PASS · AC-10 PASS WITH NOTES (spec corrected) · AC-12 PASS | PASS WITH NOTES |
| S3-02: Monster System | Logic + Integration | NOT RUN — PASS W/ WARNINGS (4 test files, ~40 tests confirmed) | No manual items | PASS (suite confirmation pending) |
| S3-03: Tower System | Logic + Integration | NOT RUN — PASS W/ WARNINGS (3 unit files + EventBusSpy confirmed) | No manual items | PASS WITH CONDITIONS (AC-23/24 deferred to ADR-0013) |
| S3-04: Damage & Status System | Logic | NOT RUN — PASS W/ WARNINGS (17 test functions confirmed) | Static inspection: all 3 `is_instance_valid` guards COMPLIANT | PASS |
| S3-05: Combat Loop Integration | Integration | NOT RUN — PASS W/ WARNINGS (6 test functions confirmed) | AC-7 deferred; profiler doc template unfilled | PASS WITH CONDITIONS |

---

## Bugs Found

| ID | Story | Severity | Status |
|----|-------|----------|--------|
| — | — | — | No bugs raised this cycle |

---

## Verdict: APPROVED WITH CONDITIONS

### Blocking Conditions

Both must be resolved before sprint clears for playtest hand-off.

**[1] Suite Gate**
Developer must run the full GUT suite locally in Godot 4.6.2 or confirm CI green on latest
`main` push (`.github/workflows/tests.yml`). Required confirmation:
- Total tests: ≥ 161
- Failures: 0
- Errors: 0

This closes **S3-05 AC-7** (full-suite regression) and resolves the NOT RUN status across
all Logic/Integration stories for the automated test column.

**[2] Profiler Obligation**
`tests/performance/sprint-03-profiler.md` is currently a template with no measured values.
Developer must fill actual profiler measurements at the next local GUT run:
- AC-8: `find_path()` 100-sample average (target: ≤1ms p99.9 per ADR-0004)
- AC-9: `would_block_all_paths()` 24×18 grid (target: ≤5ms p99 per ADR-0004)
- AC-10: A* baseline single cold call (reference measurement)

This closes **S3-05 AC-8, AC-9, AC-10** (profiler ACs).

---

## Advisory Notes (non-blocking)

- **S3-01 AC-10 spec drift**: Story spec referred to `save_all()` which was never implemented
  in `SavePersistence`; actual method is `save_slot(slot)`. Tests correctly exercise
  `save_slot()`. Story spec corrected during this QA cycle (2026-07-01). No functional
  impact — noted for audit purposes.

- **S3-03 AC-23/24 carry-forward**: Constellation-related ACs formally deferred pending
  ADR-0013 (Constellation system). Deferred scope is documented in the story's Completion
  Notes. Accepted carry-forward to Sprint 4, not a defect.

- **S3-05 profiler thresholds**: AC-8/9/10 are measurement-only (no pass/fail assertions
  in the test runner). QA sign-off on profiler results is a judgment call by the Technical
  Director after measurements are recorded.

---

## QA Cycle Summary

| Phase | Status |
|-------|--------|
| QA Strategy (qa-lead) | Complete |
| Test plan (existing) | `qa-plan-sprint-03-2026-06-30.md` used — no new plan needed |
| S3-01 static inspection (qa-tester) | Complete — 21 test functions confirmed; spec corrected |
| S3-04 static inspection (qa-tester) | Complete — all `is_instance_valid` guards COMPLIANT |
| S3-05 manual items | Deferred to developer (suite run + profiler fill) |
| Sign-off report (qa-lead) | This document |

---

## Next Steps

1. Developer runs full GUT suite and records pass count (closes Condition 1)
2. Developer fills `tests/performance/sprint-03-profiler.md` (closes Condition 2)
3. QA Lead countersigns this document once both conditions are confirmed
4. Run `/gate-check` to validate advancement to the next Pre-Production stage

> Producer note: the profiler session should not slip past the first playtest build.
> Schedule it as part of S3-06 (Wave Manager) implementation setup — a natural moment
> to have the full suite running locally anyway.
