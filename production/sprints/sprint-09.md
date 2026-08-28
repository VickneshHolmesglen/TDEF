# Sprint 9 — 2026-08-28 to 2026-09-11

## Sprint Goal
Get the three standing human-in-the-loop items actually run or decided — the last non-autonomous gaps left before the game has no open work at all.

**Context**: Sprint 8 closed early (2026-08-28) with all its autonomous work complete: S8-02 (save_persistence_restore_test.gd fix), S8-05 (Constellation AC-30 perf methodology), and S8-07 (re-review pass) all done — the last of which flipped Damage & Status to Approved, making every one of the project's 26 GDDs Approved for the first time. Nothing autonomous remains anywhere in the project; this sprint exists purely to carry forward the three items that need Vicknesh directly.

## Capacity
- Total days: 10 (2-week sprint, matching prior cadence)
- Buffer (20%): 2 days
- Available: 8 days (all of it Vicknesh's hands-on time — nothing here is Claude-autonomous)

## Tasks

### Must Have (Critical Path) — 2.0d
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| S9-01 (carried from S8-03) | Run Epic 06 Stories 012/013 human playtest — Tower Mastery proximity feel + in-world/HUD feedback legibility | Vicknesh (playtester) + Claude (prep/evidence) | 1.0d | None | Real player answers "does standing near a tower mid-combat feel fair?"; `production/qa/evidence/tower-mastery-*-evidence.md` updated with real playtest evidence (existing evidence docs are mechanism-level/technical-verification only, not experiential); both stories flip from Partial to Complete or get concrete follow-up findings |
| S9-02 (carried from S8-04) | Run Epic 10 Story 014 human playtest — Sanctuary UI Player Fantasy, Loadout continuity, badge legibility | Vicknesh (playtester) + Claude (prep/evidence) | 1.0d | None | Story 014 flips from Ready to Complete or produces concrete UI findings |

### Should Have — opportunistic
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| S9-03 (carried from S8-06) | ~~Decide the audio content pipeline, then author real stinger content for Tower Mastery~~ **DONE 2026-08-28** | Vicknesh (decision) + Claude (content) | Opportunistic | An audio bible/content pipeline decision from Vicknesh | Pipeline decided (Option A, licensed/CC0 packs). All 3 stingers sourced (Kenney Interface Sounds), imported, and wired — `AudioCueDispatcher` also gained real `AudioStreamPlayer` playback for the first time project-wide. See `production/qa/audio-content-pipeline-decision.md`. |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|---------------|
| S8-03 → S9-01 | Needed a human playtester, unavailable during sprint 8's window | 1.0d |
| S8-04 → S9-02 | Needed a human playtester, unavailable during sprint 8's window | 1.0d |
| S8-06 → S9-03 | Needed an audio pipeline decision, not yet made | Opportunistic |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Both Must Have tasks depend entirely on Vicknesh's own hands-on time — no autonomous fallback exists for either | High | Medium | If the sprint window closes without them running, they carry forward again rather than being force-completed by any substitute (e.g. Claude self-assessing "does it feel fair" is not a valid substitute for a real player) |

## Dependencies on External Factors
- S9-01/S9-02 require a real human playtester (Vicknesh) — cannot be run autonomously
- S9-03 requires an audio pipeline decision (Vicknesh) before any content authoring can start

## Definition of Done for this Sprint
- [ ] S9-01 and S9-02 playtests run, evidence filed, stories flipped to Complete or given concrete findings
- [ ] Design documents updated for any deviations found during playtest
- [ ] S9-03 either completed or explicitly re-carried with a reason
- [ ] Code reviewed and merged for any resulting changes

> **PR-SPRINT feasibility gate**: skipped — lean mode (`production/review-mode.txt`).
> **QA plan**: not authored for this sprint — no new implementation stories are in scope, only human-playtest follow-ups against already-shipped, already-tested systems (Tower Mastery, Sanctuary UI). If S9-01/S9-02 surface real bugs, those get their own bug reports and, if non-trivial, their own QA-planned follow-up sprint.
