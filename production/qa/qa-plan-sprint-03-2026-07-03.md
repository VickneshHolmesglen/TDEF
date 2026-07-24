# QA Plan: Sprint 3 (Core Combat Engine)

**Sprint**: 3 | **Dates**: 2026-06-30 to 2026-07-11 | **Generated**: 2026-07-03
**Stage**: Pre-Production
**Supersedes context from**: `production/qa/qa-plan-sprint-03-2026-06-30.md` (original sprint-start plan); this document reflects the actual end-of-sprint state after all Must/Should Have stories completed.

---

## Scope

9 stories in scope: S3-01 through S3-09.

## Story Classification

| Story | Type | Automated Required | Manual Required | Blocker? |
|---|---|---|---|---|
| S3-01 Save debt closure | Integration | Yes — done (21 tests) | None | No |
| S3-02 Monster system | Logic + Integration | Yes — done (33 tests) | Perf sign-off (AC-28/40/43) | No |
| S3-03 Tower system | Logic + Integration | Yes — done (53 tests, fixed 2026-07-03) | Visual perk indicator (advisory) | No |
| S3-04 Damage & Status | Logic | Yes — done (17 tests) | None | No |
| S3-05 Combat loop integration | Integration | Yes — done (6 tests) | Profiler capture (AC-4/17/24a) | **Yes — condition, not hard block** |
| S3-06 Wave Manager Phase 1 | Integration | Yes — done (26 tests) | None | No |
| S3-07 Godot 4.6 API annotation | Config/Data | No | Spot-check docs | No (Backlog, Nice to Have) |
| S3-08 Core epic scaffolds | Config/Data | No | Verify file exists | No (Backlog, Nice to Have) |
| S3-09 PLACEABLE cost confirmation | Config/Data | No | Designer sign-off | No for gate, but open Sprint 2 carryover |

## Automated Test Requirements

All Logic/Integration stories (S3-01 through S3-06) have automated test files at the expected `tests/unit/[system]/` and `tests/integration/[system]/` paths. Verified via `production/qa/smoke-2026-07-03.md`: **299/299 tests passing, 0 errors, 0 failures** across 24 suites.

## Manual QA Scope

- **S3-05**: `tests/performance/sprint-03-profiler.md` still contains unfilled template placeholders despite the Sprint DoD requiring recorded measurements. Reconcile the AC-numbering mismatch (sprint-03.md cites AC-4/17/24a; the profiler doc cites AC-8/9/10) before filling in real GUT `[PROFILER]` output.
- **S3-03**: visual perk indicator is an advisory manual item, deferred until art assets exist (not blocking).
- No traditional playtest sessions are possible or required — no playable build exists yet (no main menu, no mission scene). This is expected for a Core-layer, pre-Vertical-Slice engineering sprint.

## Out of Scope

- S3-07, S3-08 — documentation/scaffold stories, no code, no test evidence required this cycle; both remain Backlog (Nice to Have) and are not part of the Sprint 3 gate.
- S3-09 — design decision (PLACEABLE cost threshold), not a test item; tracked as an open Sprint 2 sign-off condition carried into Sprint 3, to be closed before the Vertical Slice gate rather than this QA cycle.

## Entry Criteria

- Smoke check PASS or PASS WITH WARNINGS — **met** (`production/qa/smoke-2026-07-03.md`, PASS WITH WARNINGS: 68 advisory orphan-node warnings, 0 test failures).

## Exit Criteria

- All Logic/Integration stories (S3-01–S3-06) PASS or PASS WITH NOTES.
- No S1/S2 bugs open.
- S3-05 profiler gap and S3-09 carryover documented as conditions in the sign-off report, not silently dropped.
