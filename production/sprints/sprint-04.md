# Sprint 4 -- 2026-07-14 to 2026-07-25

## Sprint Goal
Assemble and playtest a complete, playable Vertical Slice ("The Gap") — implementing the
Hero critical path, the two missing Foundation Autoloads, a bootable mission scene, and
validating both performance and fun with real playtesters — to close the
Pre-Production → Production gate.

**Context**: This sprint directly responds to the 2026-07-03 gate check
(`production/gate-checks/gate-check-pre-production-2026-07-03.md`, verdict FAIL). Two
directors (Creative, Art) returned NOT READY; Technical Director and Producer both
returned CONCERNS. All four assessments converge on the same root cause: no Vertical
Slice has ever been assembled or played. This sprint is structured as an
integration-first slice per the Technical Director's and Producer's recommendations.

## Capacity
- Total days: 10 (2-week sprint, matching Sprint 3's cadence)
- Buffer (20%): 2 days
- Available: 8 days

## Tasks

### Must Have (Critical Path) — 8.0d (revised from 7.5d — S4-02 grew 0.5d during `/story-readiness`)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| S4-02 | GameDataRegistry Autoload implementation | engine-programmer | 1.5d (revised — see story) | ADR-0009 | Boots at position 5; preloads MonsterResource + TowerPerkRegistry per ADR-0002 table. Also creates the `TowerPerkRegistry` class (didn't exist) and adds `MonsterResource.validate()`. Story: `production/stories/foundation/s4-02-game-data-registry.md` |
| S4-01 | SceneManager Autoload implementation | engine-programmer | 1.0d | S4-02 (must boot at position 5 before SceneManager at position 6) | Boots at position 6; owns SANCTUARY↔MISSION scene transitions per OQ-3 resolution. Story: `production/stories/foundation/s4-01-scene-manager.md` |
| S4-03 | Hero Stat Resolution (story-001) | godot-gdscript-specialist | 0.3d | S4-02 | Per `epic-02-core-combat/story-001-hero-stat-resolution.md` — all 12 stats resolve correctly |
| S4-04 | Hero Movement & Position Tracking (story-002) | godot-gdscript-specialist | 0.4d | S4-03 | Per story-002; `CharacterBody2D` root, `move_and_slide()` in `_physics_process()` |
| S4-05 | Hero Auto-Attack (story-003) | godot-gdscript-specialist | 0.4d | S4-03 | Per story-003 |
| S4-06 | Hero Combat Formula Integration (story-004) | godot-gdscript-specialist | 0.3d | S4-04, S4-05 | Per story-004 — wires Hero into DamageStatus pipeline (ADR-0007) |
| S4-07 | Hero Lifecycle, Death & Save (story-008) | godot-gdscript-specialist | 0.6d | S4-06 | Per story-008 — ADR-0002 + ADR-0003 |
| S4-08 | Reorder `GWaveManager` to Autoload position 7 | godot-gdscript-specialist | 0.1d | S4-01, S4-02 | **Done** (2026-07-03) — `project.godot` order matches ADR-0002 exactly; closed TD-wave-001 |
| S4-09 | Assemble "The Gap" mission scene | godot-specialist | 1.5d (actual: superseded — see note) | S4-07, S4-08 | **Done** (2026-07-06) — this task's original scope was superseded entirely by `production/epics/epic-04-wave-manager/` (8 stories, Story 008 = the scene assembly itself). The 1.5d estimate assumed WaveManager was feature-complete; it wasn't (see that epic's `EPIC.md` for the real scope gap found 2026-07-04). Story 008's own integration verification found and fixed 4 previously-invisible production bugs — see `docs/tech-debt-register.md` TD-wave-002/003, TD-damage-001. |
| S4-10 | 100-agent pathfinding perf stress test (fixes TD-path-001) | technical-director + godot-gdscript-specialist | 1.0d | S4-09 (satisfied) | Ready — story file now exists: `production/stories/foundation/s4-10-pathfinding-perf-stress-test.md`. Note: this is a pure CPU-timing measurement (no rendering dependency), fully executable headlessly — not blocked by the same tooling gap as TD-perf-001. |
| S4-11 | Playtest round — 3 sessions + report | producer + qa-tester | 1.0d | S4-09 (satisfied) | Genuinely blocked on human playtester availability, not on any further engineering work. Story file now exists with prep-work items an agent can do now: `production/stories/foundation/s4-11-playtest-round.md`. |

### Should Have — 3.75d
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| S4-12 | Hero Tower Affinity (story-005) | godot-gdscript-specialist | 0.4d | S4-06 | Per story-005 |
| S4-13 | Tower-Synced Class Proximity (story-006) | godot-gdscript-specialist | 0.6d | S4-12 | Per story-006 — ADR-0010 core mechanic |
| S4-14 | Hero Skill System (story-007) | godot-gdscript-specialist | 0.4d | S4-06 | Per story-007 |
| S4-15 | Art bible Sections 7–9 + Hero character visual profile | art-director | 1.0d | None | Sections 7–9 have real content (not placeholders); real AD-ART-BIBLE sign-off recorded, not "Skipped"; Hero visual profile exists |
| S4-16 | Main menu + pause menu UX specs, `/ux-review` on `mission-hud.md` | ux-designer | 1.0d | None | Both specs exist; mission-hud.md review verdict recorded |
| S4-17 | S3-09 PLACEABLE cost design confirmation | game-designer | 0.25d | None | Carryover from Sprint 2 — value documented, advisory closed |
| S4-18 | Fix TD-monster-003 + TD-tower-002 orphan node leaks | godot-gdscript-specialist | 0.15d | None | 0 orphan warnings in monster/tower test suites |

### Nice to Have — ~1d
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| S3-07 | Godot 4.6 API annotation pass (Sprint 3 carryover) | technical-director | 1.0d | None | Per original S3-07 acceptance criteria |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|---------------|
| S3-07 Godot 4.6 API annotation pass | Deferred, Nice to Have, never started | 1.0d (unchanged) |
| S3-09 PLACEABLE cost confirmation | Sprint 2 carryover, still open | 0.25d (unchanged) |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Must Have load (8.0d, revised) now consumes the entire 8d available capacity — zero buffer | Medium→High | Medium | S4-12/13/14 (Hero enhancement stories, already Should Have) are the natural cut point — epic's own VS critical path (001→002→003→004→008) doesn't need them for a playable/playtestable slice. If any Must Have task slips even slightly, cut to those first before touching S4-09/10/11 |
| Playtest scheduling (S4-11) depends on 3 external playtesters being available within the sprint window | Medium | High | Line up playtesters in week 1 while Hero/scene work is in progress, not after |
| SceneManager/GameDataRegistry (S4-01/02) are net-new Autoloads with no prior implementation — first-assembly integration risk the Technical Director flagged | Medium | High | This is exactly why S4-09 (scene assembly) is scoped as its own Must Have task, not folded into S4-01/02 |
| 100-agent perf test (S4-10) could reveal the pathfinding budget genuinely isn't met, requiring rework | Low–Medium | High | Run early where possible — S4-10 depends only on S4-09, could run in parallel with S4-11 setup rather than strictly after |

## Dependencies on External Factors
- 3 human playtesters must be available and willing to play without developer guidance (per VS Validation checklist)

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-04-[date].md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Vertical Slice playtest report exists with all 4 VS Validation checklist items answered
- [ ] Design documents updated for any deviations

> ⚠️ **No QA Plan**: This sprint was started without a QA plan. Run `/qa-plan sprint`
> before the last story is implemented. The Production → Polish gate requires a QA
> sign-off report, which requires a QA plan.
