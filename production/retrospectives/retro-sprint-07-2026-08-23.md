## Retrospective: Sprint 7
Period: 2026-08-22 -- 2026-09-02 (per sprint plan header)
Generated: 2026-08-23

**Data note up front**: `sprint-status.yaml`'s `completed:` dates for every finished Sprint 7 story read `2026-07-19` — over a month *before* this sprint's own official start date (`2026-08-22`). This is not a typo in this retro; it's what the tracking data says. Two explanations are plausible: (a) the sprint plan file's own date header was never updated when work actually started, or (b) `sprint-status.yaml` carried forward stale completion dates from whenever these stories were actually implemented, without being re-stamped. Either way, this retro treats `sprint-status.yaml` as authoritative for *what* got done and *in what order*, and flags the date mismatch itself as a process finding (see Process Improvements). This is also the project's first-ever retrospective — no prior retro exists to compare against, so the Velocity Trend and Previous Action Items sections below are necessarily thin.

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Tasks (all tiers) | 11 (per `sprint-07.md`'s own table) | 17 (per `sprint-status.yaml`, which tracks 6 additional Mission Select stories not itemized in the sprint plan's own table) | +6 (unplanned scope, see below) |
| Must Have Tasks | 6 | 6 done | 0 |
| Should Have Tasks | 3 | 3 done (S7-09's "first 2-3 Tarot stories" scope was exceeded — all 7 Tarot stories in Epic 07 landed, not just the scoped subset) | 0 |
| Nice to Have Tasks | 2 listed + 6 tracked-but-unlisted | 6 done (Mission Select 008-014, minus 006-fix), 2 backlog | see note |
| Completion Rate (Must Have) | -- | 100% | -- |
| Completion Rate (all tracked tasks) | -- | 16/17 = 94% | -- |
| Estimated Effort (Must+Should Have) | 9.5d | 9.5d completed (7.5 Must + 2.0 Should, all done) | 0 |
| Unplanned Tasks Added | -- | 6 (Mission Select Stories 009-014, all logged at `estimate_days: 0` despite being real, fully-implemented, tested stories) | +6 |
| Commits (project-wide, 2026-07-19 -- 2026-08-22 window) | -- | 238 of 282 total repo commits fall in this window | -- |
| Bugs Found (this QA cycle) | -- | 0 new; 1 pre-existing (`save_persistence_restore_test.gd`, unrelated, untracked) | -- |
| Bugs Fixed | -- | 0 (none needed fixing — no new failures this cycle) | -- |

### Velocity Trend

No prior retrospective exists for this project — this is the first one. A velocity trend table cannot be produced yet. Recommend this retro's numbers become the Sprint 7 baseline row for Sprint 8's retro.

### What Went Well

- **100% Must Have completion.** All 6 Must Have stories (S7-01 through S7-06) closed, including the highest-risk item (S7-01, the Tower System component-loadout architecture catch-up) which had a 3x estimate revision (1.0d → 3.0d) built in ahead of time rather than discovered mid-sprint as a surprise.
- **Full automated test coverage carried through cleanly.** All 7 Epic 06 stories in this cycle's QA scope (004-006, 008-011) have dedicated, passing test files (54 test cases total) — confirmed independently on disk during this retro's own QA cycle, not just self-reported by the story files.
- **Real unplanned scope got delivered, not just attempted.** 6 Mission Select stories (008-014, minus the 006-equivalent) were fully implemented and marked done even though the sprint plan only listed one of them (S7-10) as "opportunistic." The team didn't just nibble at nice-to-haves — it closed out most of an entire adjacent epic (Epic 07's Mission Select track) alongside the sprint's stated goal.
- **The dependency chain held.** S7-01 → S7-05 → S7-06 → S7-07 → S7-08 was a strict unlock chain (each explicitly blocked on the prior), and every link closed in sequence with no stall — S7-01's completion is recorded as unblocking S7-05 "now Ready," and so on down the chain.
- **The sprint's third stated goal (Tarot kickoff) was not merely started but fully finished.** All 7 Tarot stories (001-007) shipped complete, per `production/epics/epic-07-cross-cutting-flow/EPIC.md` — the sprint goal only asked to "begin" implementation (S7-09 scoped "first 2-3 stories"); the actual delivery blew past that scope to close the entire Tarot slice of Epic 07, confirmed by real test files on disk (`tests/unit/tarot/`, `tests/integration/tarot/`, 65+ tests). All three of the sprint's own named goals are therefore fully achieved, not two of three as first assessed in an earlier draft of this retro (`sprint-status.yaml`'s S7-09 entry was stale — corrected during this retro pass, same class of drift as the S7-02/03/04 entries below).

### What Went Poorly

- **`sprint-status.yaml` went stale in multiple places and nobody caught it until this close-out pass.** Three Must Have stories (S7-02/03/04) were sitting at `status: ready-for-dev` despite their own story files showing `Status: Complete` since 2026-07-19. Separately, S7-09 (Tarot kickoff) was sitting at `status: backlog` despite Epic 07's own EPIC.md showing all 7 Tarot stories Complete since the same date — a genuinely misleading gap, since it made this sprint look like it missed one of its three named goals when it actually completed all three. Both were only caught incidentally during this close-out session's own checks, not by any dedicated process step — this is the single most consequential finding in this retro, since it nearly produced a wrong "what's next" recommendation for Sprint 8.
- **Estimation for "opportunistic" work is effectively not happening.** All 6 unplanned Mission Select stories carry `estimate_days: 0` despite representing real, fully-tested, multi-day implementation work by any reasonable measure. This makes "Estimated Effort" metrics for Nice-to-Have tiers meaningless — there's no way to tell from the tracking data whether opportunistic work is cheap or expensive, which undermines future capacity planning for that tier specifically.
- **One pre-existing test failure has persisted across at least two QA cycles without a tracking bug.** `save_persistence_restore_test.gd::test_mission_launched_signal_wired_after_ready_triggers_checkpoint` was flagged as pre-existing and unrelated during this sprint's own smoke check, and was *also* already known before that (referenced in earlier session state as a WaveManager spawn-cell issue) — but no `TD-` entry or bug ID exists for it yet, so it has nowhere to be tracked to resolution.

### Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| Tower Mastery Stories 008/009 blocked on missing `TowerData` component-loadout fields (ADR-0008 specified but never implemented) | Carried over from Sprint 6 into S7-01 | S7-01 rescoped from a 1.0d ADR-authoring task to a 3.0d real implementation task; fully resolved, unblocking S7-05/006/007/008 in sequence | The sprint plan's own Capacity note already shows this was anticipated *during* planning (estimate revised before work started, not after a mid-sprint surprise) — this is the prevention working as intended, worth repeating |

No other blockers are recorded in the story files or sprint-status for this cycle.

### Estimation Accuracy

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| S7-01 (Tower System component-loadout) | 1.0d (original) / 3.0d (revised) | Completed within revised estimate | 0d vs. revised, +2.0d vs. original | Original estimate assumed a design/ADR-authoring task; actual work discovered the ADR already existed and fully specified the schema — the real cost was implementation, not decision-making. Revised proactively during planning, not discovered mid-flight. |
| S7-10 through S7-17 (Mission Select 008-014) | 0d each (opportunistic, unestimated) | 6 of 7 stories fully implemented and tested | Unmeasurable — no baseline to compare against | "Opportunistic/nice-to-have" items are being tracked with zero estimates by convention, even when the resulting work is substantial. This isn't a variance so much as a missing estimate. |

**Overall estimation accuracy**: Cannot be computed as a percentage this cycle — only one estimated task (S7-01) has a real before/after estimate to compare, and it closed within its own revised bound. The more actionable finding is the *absence* of estimates for 6 of the 15 completed stories, not their accuracy.

### Carryover Analysis

**Correction (added during Sprint 8 planning, 2026-08-23)**: this table originally listed S7-11 (`TD-menag-006`) as carried-open technical debt, based on `sprint-status.yaml`'s own `backlog` status and multiple story completion notes still citing it as "the same pre-existing unrelated failure." Direct verification while building Sprint 8's plan found `TD-menag-006` was actually fixed 2026-07-25 (`docs/tech-debt-register.md`'s own entry title reads `... (fixed)`, with a resolution section) — later completion notes were copy-pasting stale boilerplate language rather than re-checking against current test state. Confirmed live: `tests/unit/menagerie/lure_acquisition_test.gd` run in isolation, 6/6 passing, 0 errors. `sprint-status.yaml`'s S7-11 entry should be marked `done`, not `backlog`.

No other carryover — S7-09 (Tarot kickoff) was found Complete during this retro pass, not incomplete as first thought (see What Went Poorly).

### Technical Debt Status
- Current TODO count: 6 (in `src/`)
- Current FIXME count: 0
- Current HACK count: 0
- Trend: Cannot be compared — no prior retrospective recorded a baseline. This retro's counts become the Sprint 7 baseline.
- No area of concentrated concern identified — 6 TODOs project-wide is low for a project of this size, and 0 FIXME/HACK suggests debt isn't being deferred under those markers.
- Separately (not a `TODO`/`FIXME`/`HACK` marker, but a real open item): the pre-existing `save_persistence_restore_test.gd` failure is real, named technical debt this scan's grep pattern doesn't surface, since it isn't marked with a code comment — worth remembering the TODO/FIXME/HACK count is not a complete debt picture for this project. (`TD-menag-006` was also in this category until this retro's own correction found it already fixed 2026-07-25 — see above.)

### Previous Action Items Follow-Up

Not applicable — this is the project's first retrospective. No prior action items exist to follow up on.

### Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | File a real tracking entry (`TD-` or bug ID) for the pre-existing `save_persistence_restore_test.gd` failure so it stops being an undocumented recurring QA footnote | Vicknesh / Claude | High | Before Sprint 8's first `/smoke-check` |
| ~~2~~ | ~~Make a real decision on `TD-menag-006`~~ — superseded: found already fixed 2026-07-25 during Sprint 8 planning, see correction note above | — | — | — |
| 3 | Give "opportunistic" stories a real (even rough) estimate once they're actually implemented, so `sprint-status.yaml`'s effort metrics stay meaningful — retroactively estimating S7-10/012-017 would help establish this sprint's true delivered-effort baseline | Claude (during `/sprint-plan`) | Low | Sprint 8 retro |
| 4 | Add a lightweight sprint-status freshness check to whatever runs first when a new session picks up work (this session found 4 stale entries — S7-02/03/04 *and* S7-09 — by accident, not by process; the S7-09 case nearly caused a wrong "what's next" call) | Claude | High | Before Sprint 8 close-out |

### Process Improvements
- **Reconcile sprint plan dates with actual work dates.** `sprint-07.md` states a window of 2026-08-22 to 2026-09-02, but every story in it completed 2026-07-19. Going forward, either the sprint plan file's own header should be updated to reflect when work genuinely started, or `sprint-status.yaml`'s `completed:` dates should be re-verified against the sprint window they're filed under — right now the two disagree by over a month and nothing catches that automatically.
- **Treat `sprint-status.yaml` as requiring the same close-out discipline as the sprint plan itself.** This sprint's stale `ready-for-dev` entries (found and fixed this session) show the tracker can silently drift from the story files it's supposed to mirror. A quick "does `sprint-status.yaml` match every in-scope story file's own `Status:` field" check at `/team-qa` or `/story-done` time would have caught this without relying on incidental discovery.

### Summary
Sprint 7 delivered all three of its named goals in full: the component-loadout catch-up (S7-01), Constellation + Tower Mastery (Epic 06), and Tarot (Epic 07) all shipped complete, plus 6 unplanned Mission Select stories on top. This is a strong sprint by delivery — the only real process failure is that `sprint-status.yaml` (and this retro's own first draft) drifted stale in enough places (S7-02/03/04, S7-09, and S7-11/`TD-menag-006`) that this sprint initially looked like it had missed a goal and left a bug open when it had actually closed both. The most important change for Sprint 8 is tracking hygiene, not velocity: file the pre-existing `save_persistence_restore_test.gd` failure properly, and don't let the status file silently drift again before the next close-out.
