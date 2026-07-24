# Sprint 5 -- 2026-07-28 to 2026-08-08

## Sprint Goal
Design the two Core-layer Economy systems (Inventory, Resource Economy) that everything
downstream (Crafting, Menagerie, Constellation, Equipment Forge) depends on — the current
hard blocker on Epic 03 (`production/epics/index.md`: "Deferred — GDDs needed first") —
while S4-11's human playtest sessions run in parallel as an external, non-day-budgeted
carryover from Sprint 4.

**Context**: Sprint 4 closed all tracked engineering tech debt to zero open items (except
two structurally-blocked partials — `TD-hero-001`'s Skill Power half and `TD-hero-004`'s
registry-verification half, both waiting on features that don't exist yet) and fixed
`TD-project-001` (the project could not actually be run/played at all — a `project.godot`
config bug, user-confirmed fixed). The full test suite is fully green (650/650). With
engineering stable and no MVP-tier system work left undesigned, the natural next step is
GDD authoring for the next systems in dependency order — not further MVP implementation.

## Capacity
- Total days: 10 (2-week sprint, matching Sprint 3/4's cadence)
- Buffer (20%): 2 days
- Available: 8 days

## Tasks

### Must Have (Critical Path) — 4.0d
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| S5-03 | Author Inventory System GDD | game-designer (`/design-system inventory`) | 2.0d | None | 8/8 required GDD sections present; passes `/design-review`; no MAJOR REVISION NEEDED |
| S5-04 | Author Resource Economy System GDD | game-designer (`/design-system resource-economy`) | 1.0d | Sequenced after S5-03 (not run in parallel) — Resource Economy's material/gold flows likely reference Inventory's item model; no hard dependency is listed in `systems-index.md`, but designing them in series avoids rework | 8/8 required GDD sections present; passes `/design-review`; no MAJOR REVISION NEEDED |
| S5-05 | `/review-all-gdds` re-run including both new GDDs + existing 9 | creative-director + game-designer | 0.5d | S5-03, S5-04 | Verdict not FAIL; any new cross-GDD consistency issues resolved or explicitly accepted |
| S5-06 | Create Epic 03 (Core Economy) + first story batch | producer (`/create-epics layer: core`, `/create-stories`) | 0.5d | S5-05 | Epic 03 file exists with real scope (currently a one-line placeholder in `production/epics/index.md`); at least 2-3 implementation-ready stories exist for Inventory |

### Should Have — 1.15d
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| S5-07 | Fix stale epic status docs | technical-director | 0.15d | None | `production/epics/index.md`'s Epic 04 status corrected to "Complete" (its own `EPIC.md` already says Complete; the index was never updated); `epic-01-foundation.md`'s status corrected — GameDataRegistry and SceneManager are both fully implemented and tested, not "not yet implemented" as currently written |
| S5-08 | Begin Inventory System implementation (first story) | godot-gdscript-specialist (`/dev-story`) | 1.0d | S5-06 | First Inventory story from S5-06's batch implemented and tested — stretch goal, only attempted if S5-03 through S5-06 land with capacity to spare |

### Nice to Have — opportunistic, no fixed estimate
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| S5-09 | `TD-monster-004` real-profiler measurement (AC-28/AC-40) | technical-director | Opportunistic | Live Godot MCP/editor tooling availability | Real profiler evidence captured per the tech-debt entry's literal requirements — only attempt if live tooling is reachable this sprint, not worth blocking on |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|---------------|
| S4-11 Playtest round (3 sessions + report) | Genuinely blocked on human playtester availability, not sprint capacity — runs in parallel via `production/playtests/sprint-04-session-schedule.md`, not day-budgeted against Sprint 5 | 1.0d (unchanged, external) |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Resource Economy's design depends on Inventory's item/material model being settled first — designing them in parallel (not series) risks rework | Medium | Medium | Sequence S5-04 strictly after S5-03 completes, despite no hard dependency listed in `systems-index.md` |
| S4-11 playtest results could surface a fun-blocker in the MVP core loop, which would take priority over any Sprint 5 design work | Low-Medium | High | If S4-11 completes mid-sprint with a NOT READY finding, pause Economy-system design and address the core-loop finding first — the Vertical Slice gate matters more than getting ahead on Vertical-Slice-tier systems |
| Neither Inventory nor Resource Economy has been designed before — first-pass GDD authoring for entirely new systems carries normal scope-creep/estimate risk | Medium | Medium | `/design-review` gates each GDD before it's considered done; don't let scope grow past what Vertical-Slice tier actually requires |

## Dependencies on External Factors
- S4-11's 3 human playtesters (carried over from Sprint 4, unchanged)

## Definition of Done for this Sprint
- [x] Both Must Have GDDs (Inventory, Resource Economy) authored (2026-07-10/07-11) — still `Needs Revision` pending a final per-document `/design-review` re-run (documentation-process status, not blocking implementation)
- [x] `/review-all-gdds` re-run, verdict not FAIL — run 6 times across 2026-07-14/15; defect count converged to zero new findings by the final pass; verdict stayed FAIL/CONCERNS only due to 2 deliberately-deferred design-judgment items, both resolved by explicit user decision in the final sweep (2026-07-15) — see `design/gdd/gdd-cross-review-2026-07-15d.md` and its addenda
- [x] Epic 03 created (2026-07-11) with 15 stories, all Ready by 2026-07-13 (ADR-0016/ADR-0017/ADR-0018/ADR-0011 all Accepted); **8 of 15 now Complete** (2026-07-15/16 implementation pass)
- [x] QA plan exists (`production/qa/qa-plan-sprint-05-2026-07-10.md`)
- [x] Design documents updated for any deviations — two mid-implementation ADR amendments (ADR-0011's signal-dedup lesson, ADR-0017's missing `base_drop_rate` field) applied directly to the ADRs during Story 007/008
- [x] Stale epic status docs corrected (S5-07, 2026-07-13 — `epics/index.md` Epic 01/04 rows, `epic-01-foundation.md`'s GameDataRegistry/SceneManager claims; further corrected 2026-07-16 — Epic 03's own row and `EPIC.md` updated to reflect 8/15 Complete)

> **PR-SPRINT feasibility gate**: skipped — lean mode (`production/review-mode.txt`).

**Scope check:** If this sprint includes stories added beyond the original epic scope, run `/scope-check Epic-03` to detect scope creep before implementation begins.
