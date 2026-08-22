# QA Plan: Sprint 7

**Scope**: Sprint 7 (2026-08-22 – 2026-09-02), "Sanctuary Defenders" (Godot 4.6.2)
**Date**: 2026-08-23
**Stories in scope**: 7 (Epic 06 — Constellation Stories 004/005/006, Tower Mastery Stories 008/009/010/011). Story 007 excluded (Sprint 6 work).

## Story Classification Table

| Story | Type | Automated Required | Manual Required | Blocker? |
|---|---|---|---|---|
| 004 — Discovery Ledger Persistence | Integration | Yes — `tests/integration/constellation/discovery-ledger-persistence_test.gd` (9 tests, AC-14/15/16 + save/load round-trip) | None | No |
| 005 — Localized Search Scope & Performance Bound | Integration | Yes — `tests/integration/constellation/localized-search-scope-performance-bound_test.gd` (7 tests) | AC-30 (ADVISORY) — informal ±10x tolerance smoke check; OQ-7's formal perf-harness methodology unresolved | No |
| 006 — Placement-Only Formation & Edge Cases | Logic | Yes — `tests/unit/constellation/placement-only-formation-edge-cases_test.gd` (3 tests, AC-18/19/27) | None | No |
| 008 — Build Signature via Event-Payload Extension | Integration | Yes — `tests/integration/tower-mastery/build-signature-event-payload-extension_test.gd` (6 tests, AC-07/08/09/11/12/26) | None | No |
| 009 — Cell-Boundary Proximity Tracking | Logic | Yes — `tests/unit/tower-mastery/cell-boundary-proximity-tracking_test.gd` (9 tests, AC-24/25 + 4 lifecycle-event recomputes) | None | No |
| 010 — Mastery Progress & Skill Unlock | Logic | Yes — `tests/unit/tower-mastery/mastery-progress-skill-unlock_test.gd` (7 tests, AC-19-23) | None (skill catalogue content deferred, not this story's gate) | No |
| 011 — Cross-Mission Mastery Persistence | Integration | Yes — `tests/integration/tower-mastery/cross-mission-mastery-persistence_test.gd` (13 tests, AC-10/13-18 + `RESTORE_ORDER==34`) | None | No |

All 7 test files independently verified present on disk (Glob/Bash), not taken on the story files' own self-report alone.

## Automated Test Requirements

All 7 stories are Logic/Integration type and all carry passing dedicated test files (54 test cases total across the 7 files). No missing evidence.

## Manual QA Scope

Effectively none required to close the sprint gate — full automated coverage with zero own-test failures across all in-scope stories. Two informal, non-blocking manual items carried forward as advisory, not sprint-close conditions:

1. **Story 005 AC-30** — the "recheck cost does not scale with tower count" claim is currently an informal smoke check (10 vs. 55 towers, ~10x tolerance), not a formally specified perf harness. OQ-7 (methodology: sample count, timing API, tolerance band) remains open — recommend Technical Director/QA Lead sign-off before treating this as a hard performance guarantee externally.
2. **Full mission launch → SCOUT → combat path** and a **save/load cycle exercising the Discovery Ledger (`restore_order=24`) + Tower Mastery persistence (`restore_order=34`) together** were not manually exercised in this session's smoke check (`production/qa/smoke-2026-08-22.md`) — the Launch button was confirmed to correctly no-op without a selected mission (Launch Validation Gate working as designed), but the full downstream path wasn't walked end-to-end.

## Out of Scope

- **S7-09 (Tarot kickoff)** and **S7-11 (`TD-menag-006` fix)** — no code landed for either this sprint; not part of this QA cycle.
- **Story 007** (Tower Mastery Hero-Independence) — Sprint 6 work, already signed off (`qa-signoff-sprint-06-2026-07-19.md`).
- This session's own crafting/equipment content, Epic 15 (3D Visual Presentation), and UI fixes (paperdoll alignment, diorama Castle, Assemble Towers relocation, Bases subpanel) — these landed in the same time window but are **not Sprint 7 sprint-plan items**; they were separately live-verified via Godot MCP during this session's own smoke check and are not re-litigated here.

## Entry Criteria

- [x] Smoke check PASS or PASS WITH WARNINGS report exists at `production/qa/smoke-2026-08-22.md` — confirmed, PASS WITH WARNINGS
- [x] Build is stable (no crashes on launch) — confirmed via live Godot MCP boot during smoke check
- [x] All Must Have stories have Status: done in `production/sprint-status.yaml` — confirmed (S7-01 through S7-06 all `done`; corrected from stale `ready-for-dev` entries during the smoke-check pass)

## Exit Criteria

QA cycle is complete when all 7 in-scope stories are PASS or FAIL-with-bugs-filed. Given full automated coverage with 0 own-test failures and no blockers identified in the QA strategy, all 7 stories are expected to close as PASS on the strength of their existing automated evidence — no additional manual walkthrough sessions are scheduled for this cycle.
