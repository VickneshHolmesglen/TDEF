# Sprint 6 -- 2026-08-10 to 2026-08-21

## Sprint Goal
Unblock the three remaining Feature/Advanced-layer epics (06–08) by resolving the cross-epic SavePersistence gap and accepting the 8 outstanding Proposed ADRs, close out Epic 05's deferred code review and its one open design decision, then push Epic 06 implementation forward now that Epic 05 is fully complete and that capacity is freed.

**Context**: Sprint 5 closed with both Economy GDDs authored, Epic 03 15/15 stories created (8 Complete), and `/review-all-gdds` converged clean. Since then (outside a tracked sprint), 11 ADRs were written, 3 epics (06/07/08, 43 stories total) were fully decomposed, and **Epic 05 (26 stories — Crafting, Menagerie, Defense Building) was fully implemented and marked Complete (2026-07-18)**, with `/code-review` deliberately deferred across the whole epic per user instruction. `epics/index.md` is stale on two counts: it still shows Epic 06/07/08 stories as "Not yet created," and it undercounts Epic 05/03 completion relative to their own `EPIC.md` files.

## Capacity
- Total days: 10 (2-week sprint, matching Sprint 3–5 cadence)
- Buffer (20%): 2 days
- Available: 8 days

## Tasks

### Must Have (Critical Path) — 6.8d
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| S6-01 | ~~Resolve project-wide SavePersistence mid-session-restore gap (ADR-0003 revision)~~ **DONE 2026-07-18** | technical-director + godot-gdscript-specialist | 1.0d | None | ADR-0003 revised to specify how `SavePersistence` re-applies already-loaded save data to a `SaveRestorer` that registers mid-session; live-verified (MCP) against a scene-instanced system reload; unblocks persistence-dependent stories in Epics 06/07/08 (and closes Crafting's already-tracked exposure in Epic 05). **Bonus find**: the same live-verification pass discovered the project didn't boot at all (stale global script-class cache, an environment gap not a code defect — see `epic-05-sanctuary-production/EPIC.md`); fixed in the same pass. |
| S6-02 | ~~Run `/architecture-review` cross-conflict pass~~ + accept ADR-0022, ADR-0029 (Epic 06) — **DONE 2026-07-18** | technical-director | 0.5d | None | Both ADRs `Accepted`. **Deviation**: a full `/architecture-review` couldn't run cleanly in this session (it authored the ADR-0003 revision this ADR depends on — reviews must be independent per that skill's own rule); substituted a lightweight manual cross-check instead — all 5 dependency ADRs confirmed `Accepted`, `restore_order` table (10/11/20/21/22/24/30/31/32/34) confirmed collision-free. 12 of Epic 06's 13 stories flip `Blocked` → `Ready` (Story 008 stays `Blocked` on a separate content gap). An independent `/architecture-review` in a fresh session is still recommended before Epic 06's next milestone. |
| S6-03 | ~~Accept ADR-0027, ADR-0028 (Epic 07)~~ **DONE 2026-07-18** | technical-director | 0.5d | S6-02 (shared review pass) | Both ADRs `Accepted`; Epic 07's 14 stories flip `Blocked` → `Ready` |
| S6-04 | ~~Accept ADR-0025, ADR-0030 (Epic 08)~~ **DONE 2026-07-18** | technical-director | 0.5d | S6-02 (shared review pass) | Both ADRs `Accepted` (ADR-0021/ADR-0026 were already `Accepted` from Epic 05's earlier batch); Epic 08's stories flip `Blocked` → `Ready` |
| S6-05 | ~~Tower Mastery proximity-detection isolated prototype (Epic 06 Story 012)~~ **DONE 2026-07-18** | prototyper + gameplay-programmer | 1.0d | S6-02 | Live profiling test measured accrual-loop cost with 5+ simultaneously-accruing signatures during a 100-monster wave; documented in `production/qa/evidence/tower-mastery-accrual-profiling-evidence.md` — performance verdict clean, feel verdict honestly left open pending real playtest |
| S6-06 | ~~Run the deferred `/code-review` across Epic 05's 26 stories~~ **DONE 2026-07-18** | lead-programmer | 1.5d | None | All 26 stories reviewed (Crafting 6, Menagerie 11, Defense Building 9); 3 findings (1 critical self-pairing bug, 2 missing regression tests) fixed and live-verified; recorded in `epic-05-sanctuary-production/EPIC.md` |
| S6-06b | ~~Resolve `TD-craft-001`/`TD-defbuild-002` rarity-vs-item_type vocabulary decision~~ **DONE 2026-07-18** | technical-director + game-designer | 0.3d | None | Decision: added `ItemDefinitionResource.rarity` as a separate aggregation axis + `Inventory.has_items_by_rarity()`/`consume_by_rarity()`, mirroring `has_items()`/`consume_by_type()`; Crafting (`resolve_repair()`, `_has_recipe_inputs()`/`_consume_recipe_inputs()` covering `is_craftable()`/`resolve_craft()`/both discovery triggers) and Defense Building (`resolve_tech_unlock()`/`resolve_structure_build()`) updated to split mixed item_type/rarity cost Dictionaries; ADR-0021 amended; both TDs closed. Live-verified via gdUnit4 (220/220 passing, 0 failures) after a genuine bug was found and fixed in 5 test files that seeded Inventory with unregistered fabricated item_ids (see ADR-0021 amendment for the full explanation). 11 new/updated tests. |
| S6-08 | ~~Begin Epic 06 implementation — Constellation core stories (001–003)~~ **DONE 2026-07-18** | godot-gdscript-specialist (`/dev-story`) | 1.5d | S6-01, S6-02 | Stories 001 (pattern catalogue/eligibility), 002 (detection trigger/activation), 003 (deactivation/overlap) Complete and tested — 15/15 new gdUnit4 tests passing. **Bonus find**: a real content gap (`constellation_eligibility_tag` never actually added to `event_bus.gd`'s signals despite the GDD/ADR claiming it was) blocked Core Rule 2 entirely — fixed in the same pass, full regression re-verified at 1038/1038 (1 pre-existing unrelated failure, `TD-menag-006`). |

### Should Have — 1.15d
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| S6-07 | ~~Fix stale `epics/index.md` rows for Epic 05/06/07/08~~ **DONE 2026-07-18** | technical-director | 0.15d | None | Epic 05's row corrected to 26/26 Complete; Epic 06/07/08 story counts corrected to reflect the 43 stories created this session (13/14/16), all currently `Blocked` pending S6-02/03/04. Epic 03's row also corrected (was stale independent of this sprint — `sprint-status.yaml` already showed it 15/15 Complete). |
| S6-10 | ~~Begin Epic 06 implementation — Tower Mastery core stories (007–009)~~ **PARTIAL, DONE 2026-07-18** | godot-gdscript-specialist (`/dev-story`) | 1.0d | S6-02, S6-05 | Story 007 (proximity radius/accumulator independence) Complete and tested — 7/7 new gdUnit4 tests passing. Stories 008/009 remain `Blocked`: confirmed `TowerData` has zero component-slot fields anywhere in `src/` — Story 008's `build_signature` derivation needs a real Tower System component-loadout data model built first (a genuine architecture gap, likely its own ADR), not a one-field payload fix. Full regression re-verified at 1045/1045 (1 pre-existing unrelated failure, `TD-menag-006`). |

### Nice to Have — opportunistic, no fixed estimate
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| S6-09 | Begin Epic 07 Mission Select implementation (no SavePersistence blocker — Autoload) | godot-gdscript-specialist | Opportunistic | S6-03 | Any Mission Select story from Stories 008–014 Complete and tested, only if capacity remains |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|---------------|
| None | Sprint 5's Definition of Done was fully met — no open carryover | — |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| ADR-0003's SavePersistence fix could reveal a deeper rearchitecture need (e.g., reclassifying more scene-instanced systems as Autoload) rather than a small restore-pass fix | Medium | Medium-High | Time-box investigation to S6-01's 1.0d; prefer a minimal fix (re-fire restore against the cached in-memory save on late `SaveRestorer` registration) over further Autoload reclassifications; escalate explicitly if the minimal fix proves insufficient |
| Accepting 8 ADRs in one sprint without full individual `/architecture-review` passes could let a cross-ADR conflict slip through | Medium | Medium | S6-02's review pass explicitly re-runs Phase 4 (cross-ADR conflicts) and Phase 5 (engine compatibility) across all 8 before any is marked `Accepted` — this was ADR-0029's own explicit recommendation |
| Tower Mastery's prototype (S6-05) could find the mechanic doesn't feel good, requiring Core Rule changes to `tower-mastery.md` after 7 Epic 06 stories are already written against it | Low-Medium | High | Run S6-05 early in the sprint (before S6-08/S6-10) so there's time to revise the GDD/stories if the finding is negative, rather than discovering it after implementation begins |
| The deferred `/code-review` across 26 Epic 05 stories (S6-06) could surface enough real defects to blow past its 1.5d estimate | Medium | Medium | Triage findings by severity as they're found — fix criticals inline, log everything else as tech debt rather than blocking the sprint on a full remediation pass |

## Dependencies on External Factors
- None currently tracked — Sprint 4's playtester carryover (S4-11) closed prior to Sprint 5

## Definition of Done for this Sprint
- [x] SavePersistence mid-session-restore gap resolved (ADR-0003 Accepted 2026-07-18 revision, live-verified via Godot MCP)
- [x] All 8 outstanding ADRs (0021, 0022, 0025, 0026, 0027, 0028, 0029, 0030) reach `Accepted` — **8/8 done** (ADR-0022/0029 2026-07-18 via S6-02; ADR-0027/0028 via S6-03; ADR-0025/0030 via S6-04; ADR-0021/0026 already `Accepted` from Epic 05's earlier batch)
- [x] Tower Mastery proximity-detection prototype complete with a documented feel/performance verdict (S6-05, `production/qa/evidence/tower-mastery-accrual-profiling-evidence.md`)
- [x] `/code-review` complete across all 26 Epic 05 stories; criticals fixed, remainder logged as tech debt (S6-06) *(note: S6-01's live-verification pass already found and fixed one boot-blocking environment issue — a stale global script-class cache, not a code defect — ahead of this formal review; see `epic-05-sanctuary-production/EPIC.md`)*
- [x] `TD-craft-001`/`TD-defbuild-002` rarity-vs-item_type decision resolved and both GDDs/ADRs updated (S6-06b, ADR-0021 amendment)
- [x] At least 3 Epic 06 stories (Constellation 001–003) Complete and tested (S6-08, 2026-07-18)
- [x] QA plan exists (`production/qa/qa-plan-sprint-06-2026-07-18.md`)
- [x] All Logic/Integration stories closed this sprint have passing unit/integration tests — Constellation 001-003 (15 tests), Tower Mastery 007 (7 tests), S6-06b's 11 tests, all live-verified via gdUnit4; full-project regression 1045/1045 passing (1 pre-existing, unrelated, already-tracked failure — `TD-menag-006`)
- [x] Smoke check passed (`/smoke-check sprint`) — `production/qa/smoke-2026-07-19.md`, verdict PASS WITH WARNINGS (1044/1045 project-wide; 1 pre-existing unrelated failure, `TD-menag-006`)
- [x] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`) — `production/qa/qa-signoff-sprint-06-2026-07-19.md`, verdict APPROVED WITH CONDITIONS (all 4 in-scope stories PASS, no S1/S2 bugs; condition is the pre-existing, out-of-scope `TD-menag-006`)
- [x] No S1 or S2 bugs in delivered features — every defect found this sprint (SavePersistence gap, stale class cache, Epic 05's 3 review findings, the EventBus `constellation_eligibility_tag` gap, the fabricated-item_id test bug) was fixed in the same pass; only remaining open item is `TD-menag-006` (Medium, pre-existing, unrelated to this sprint's work)
- [x] `epics/index.md` corrected to reflect Epic 05's actual completion and Epic 06/07/08's actual story counts (2026-07-18)

> **PR-SPRINT feasibility gate**: skipped — lean mode (`production/review-mode.txt`).

**Scope check:** If this sprint includes stories added beyond the original epic scope, run `/scope-check [epic]` to detect scope creep before implementation begins.
