# Sprint 8 — 2026-08-23 to 2026-09-06 — **CLOSED EARLY 2026-08-28**

> **Closed early, 2026-08-28**: All autonomous work in this sprint is complete (S8-02, S8-05, S8-07 all done). The only remaining items — S8-03, S8-04 (human playtests), S8-06 (audio pipeline decision) — need Vicknesh directly and cannot be advanced further without that. Rather than let the sprint idle to its scheduled 2026-09-06 end date, it's closed here and those three items carry forward into `production/sprints/sprint-09.md` as S9-01/S9-02/S9-03.

## Sprint Goal
Close out the pre-existing `save_persistence_restore_test.gd` failure and clear the way for the three remaining human-playtest gates (Tower Mastery, Sanctuary UI, Tower Mastery feedback) — the game is otherwise feature-complete across all 15 epics.

**Context**: Sprint 7 closed 2026-08-23 — APPROVED WITH CONDITIONS (`production/qa/qa-signoff-sprint-07-2026-08-23.md`). All 3 of Sprint 7's own named goals (Tower System catch-up, Constellation+Tower Mastery, Tarot) shipped complete, plus 6 unplanned Mission Select stories. A roadmap sweep during this sprint's planning found nearly every epic (01-15) is already `Complete` — the only genuine remaining gaps are: 1 open bug (`save_persistence_restore_test.gd`), 3 story-level items blocked purely on a human playtester (Epic 06 Stories 012/013, Epic 10 Story 014), and 4 GDDs still `Needs Revision` (documentation-process status only, not implementation gaps). Sprint 8 is shaped around that reality rather than assuming a feature backlog exists.

**Correction during planning (2026-08-23)**: `TD-menag-006` was initially carried into this plan as a Must Have (S8-01) based on multiple recent story completion notes still citing it as "the same pre-existing unrelated failure." Direct verification (`tests/unit/menagerie/lure_acquisition_test.gd` run in isolation: 6/6 passing, 0 errors) confirmed it was actually fixed 2026-07-25, per `docs/tech-debt-register.md`'s own entry title (`TD-menag-006 ... (fixed)`) — later completion notes were copy-pasting stale boilerplate rather than re-checking. S8-01 removed from this plan's Must Have tier; see Sprint 7 retrospective's own correction note.

## Capacity
- Total days: 10 (2-week sprint, matching Sprint 3-7 cadence)
- Buffer (20%): 2 days
- Available: 8 days

## Tasks

### Must Have (Critical Path) — 1.0d
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| S8-02 | ~~File and fix the pre-existing `save_persistence_restore_test.gd` failure~~ **DONE 2026-08-23** | godot-gdscript-specialist | 1.0d | None | **Real root cause found (not the WaveManager-spawn-cell theory carried from Sprint 7)**: the test itself raced its own assertion against a real, correct production cascade. `_on_mission_launched()` writes the checkpoint synchronously as part of `.emit()` — confirmed present immediately after emit via live Godot MCP tracing. A superfluous post-emit `await get_tree().process_frame` gave the real `WaveManager` Autoload (also live in the test tree) time to fail its fake-mission `WaveConfig` load, hit 0 spawn cells, and cascade through `MISSION_COMPLETE` → `SceneManager.transition_to_sanctuary()` → `scene_transition_completed("SANCTUARY")` — which the test's own `sp` instance is independently subscribed to, correctly deleting its own just-written checkpoint per `SavePersistence`'s documented Rule 5 "normal flow" cleanup. Production code was never wrong. Fixed by removing the unneeded await (asserting immediately, matching `.emit()`'s synchronous handler invocation); same superfluous-await pattern cleaned up in a sibling test too (currently-harmless, same anti-pattern). `TD-save-003` filed and closed same session in `docs/tech-debt-register.md`. Code-reviewed by godot-gdscript-specialist: APPROVED WITH SUGGESTIONS. Verified: 14/14 in the suite, full regression 2256/2256, 0 failures. |

~~S8-01 (Fix `TD-menag-006`)~~ — removed, already fixed 2026-07-25 (see correction note above).

### Should Have — 2.5d
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| S8-03 | Prep + run Epic 06 Stories 012/013 human playtest (Tower Mastery proximity feel + in-world/HUD feedback legibility) | Vicknesh (playtester) + Claude (prep/evidence) | 1.0d | None | Real player answers "does standing near a tower mid-combat feel fair?"; evidence doc updated at `production/qa/evidence/tower-mastery-*-evidence.md`; both stories flip from Partial to Complete or get concrete follow-up findings |
| S8-04 | Prep + run Epic 10 Story 014 human playtest (Sanctuary UI — Player Fantasy, Loadout continuity, badge legibility) | Vicknesh (playtester) + Claude (prep/evidence) | 1.0d | None | Story 014 flips from Ready to Complete or produces concrete UI findings |
| S8-05 | Resolve Constellation Story 005's AC-30 perf methodology (OQ-7) — define a real measurement methodology, not the current informal ±10x tolerance smoke check | Technical Director / Claude | 0.5d | None | OQ-7 formally closed in `constellation.md`; AC-30 either reclassified as a hard gate with real methodology, or explicitly accepted as informal by a Technical Director decision (not left ambiguous) |

### Nice to Have — opportunistic, no fixed estimate
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| S8-06 | Author real audio stinger content for Tower Mastery (closes Epic 06 Story 013's remaining audio gap) | Sound Designer / Claude | Opportunistic | An audio bible/content pipeline decision | Real stinger assets wired into the already-real `AudioCueDispatcher` mechanism (mechanism itself has existed since 2026-08-13) |
| S8-07 | ~~`/design-review` re-run pass on the 4 GDDs still marked "Needs Revision" (Save & Persistence, Hero, Tower, Damage & Status)~~ **DONE 2026-08-28** | Claude | Opportunistic | None | All 4 flipped to Approved across this sprint (Save & Persistence 2026-08-27; Hero and Tower 2026-08-28 part 13; Damage & Status 2026-08-28 part 14, the last one). **Every GDD in the project is now Approved.** |

## Carryover from Previous Sprint
None — `TD-menag-006`, the only carried item under consideration, was found already fixed during this sprint's planning (see correction note above).

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Human playtest sessions (S8-03/S8-04) depend on Vicknesh's own hands-on time, not something Claude can execute autonomously | Medium | Medium | Scheduled as Should Have, not Must Have — sprint's Must Have scope (S8-01/S8-02) is fully autonomous and doesn't depend on playtester availability |
| `TD-menag-006`'s root cause (RESERVE-vs-HABITAT placement mismatch) may be deeper than a 1-day fix once actually investigated | Low-Medium | Medium | Time-box investigation to 0.5d; if the real fix requires touching Menagerie's placement architecture broadly, split into its own story rather than absorbing overrun into S8-02 |

## Dependencies on External Factors
- S8-03/S8-04 require a real human playtester (Vicknesh) — cannot be run autonomously

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-08-[date].md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

> **PR-SPRINT feasibility gate**: skipped — lean mode (`production/review-mode.txt`).
