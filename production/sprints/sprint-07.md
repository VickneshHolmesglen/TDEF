# Sprint 7 -- 2026-08-22 to 2026-09-02

## Sprint Goal
Resolve the Tower System component-loadout architecture gap blocking Tower Mastery's remaining stories, finish Epic 06 (Constellation's last 3 stories + Tower Mastery's newly-unblocked stories), and begin Epic 07 (Tarot) implementation now that Epic 05 is fully complete and all Epic 06-08 ADRs are Accepted.

**Context**: Sprint 6 closed 2026-07-19 — APPROVED WITH CONDITIONS (`production/qa/qa-signoff-sprint-06-2026-07-19.md`). All 8 outstanding ADRs are now `Accepted`. Epic 06 has 4/13 stories Complete (Constellation 001-003, Tower Mastery 007); Stories 008/009 are genuinely Blocked on a confirmed architecture gap — `TowerData` has zero component-slot fields anywhere in `src/`, so `build_signature` cannot be derived from a real tower loadout. This blocks 4 of Epic 06's 13 stories (008, 009, 010, 011) and is this sprint's top-priority unblock. Epics 07/08 are fully `Ready` (all ADRs Accepted, no remaining blockers) but have zero implementation yet.

## Capacity
- Total days: 10 (2-week sprint, matching Sprint 3-6 cadence)
- Buffer (20%): 2 days
- Available: 8 days

**Capacity note (added 2026-07-19, after S7-01 was rescoped from a 1.0d ADR-authoring
task to a 3.0d real implementation task)**: Must Have alone is now 7.5d against 8
available — only 0.5d of slack remains. Should Have items (S7-07/S7-08/S7-09, 2.0d)
are realistically likely to carry into Sprint 8 rather than land this sprint; they
are kept in this plan as stretch goals in dependency order (S7-07 depends on S7-06
landing with room to spare), not as a committed scope. If S7-01 runs over 3.0d,
cut Should Have entirely before touching any Must Have story.

## Tasks

### Must Have (Critical Path) -- 7.5d
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S7-01 | ~~Resolve Tower System component-loadout data model gap~~ **DONE 2026-07-19** | godot-gdscript-specialist | 3.0d (revised from 1.0d) | None | **Finding changed the task**: this was never an open design question — ADR-0008 (Accepted 2026-05-19) already fully specified the 4-component architecture; it was simply never implemented. ADR-0008 amended in place with the exact schema (validated by godot-gdscript-specialist, MINOR NOTES). **Implementation complete**: `FoundationComponent`/`WeaponComponent`/`FocusComponent`/`PowerComponent` + `TowerBlueprintData` built; `tower_system.gd`'s 9 read sites, `game_data_registry.gd`'s loader, all `.tres` blueprint/fixture content, and 4 test files migrated; old `TowerData`/`tower_data.gd` deleted. `duplicate_deep()` isolation live-verified via Godot MCP (open since 2026-05-19, now closed). `constellation_eligibility_tag` relocated to `PowerComponent`, zero change to Constellation's consuming code. Full regression: 118/118 (tower/game_data_registry suites), 1045/1045 project-wide (1 pre-existing unrelated failure, `TD-menag-006`). Unblocks Epic 06 Story 008 (now `Ready`) and transitively 009/010/011. |
| S7-02 | Constellation Story 004 — Discovery Ledger Persistence | godot-gdscript-specialist (`/dev-story`) | 1.0d | None (Constellation core already implemented, S6-08) | `SaveRestorer` round-trip for `_discovery_ledger` verified via a real save/load cycle at `restore_order=24`, not just unit-level `get_save_data()`/`restore_save_data()` calls |
| S7-03 | Constellation Story 005 — Localized Search Scope & Performance Bound | godot-gdscript-specialist (`/dev-story`) | 1.0d | None | AC-17 (zero `get_all_occupied_cells()` calls, GridSpyDouble call-counter test) and AC-30 (recheck cost does not scale with tower count, 10 vs. 55 towers within tolerance) both passing |
| S7-04 | Constellation Story 006 — Placement-Only Formation & Edge Cases | godot-gdscript-specialist (`/dev-story`) | 1.0d | None | AC-18/AC-19/AC-27/AC-29 (removal-alone never completes a shape, `tower_destroyed` breaks instances regardless of phase, N-1-then-remove-and-replace fires no deactivation, grid-too-small produces no error) |
| S7-05 | ~~Tower Mastery Story 008 — Build Signature via Event-Payload Extension~~ **DONE 2026-07-19** | godot-gdscript-specialist (`/dev-story`) | 1.0d | S7-01 | `tower_placed` carries the 4 loadout fields per S7-01's data model; `TowerComponentEquippedEvent` created (`tower_component_equipped` promoted from 3 bare params to a 7-field Resource subclass); `TowerMastery.compute_build_signature()` derives Formula 4; `_on_tower_placed()`/`_on_tower_component_equipped()` populate `_active_signature_by_tower` for real. New test file `tests/integration/tower-mastery/build-signature-event-payload-extension_test.gd` (6 tests) covers AC-07/08/09/11/12/26 — all passing (previously `[BLOCKED]`). Full regression: 1044/1045 (1 pre-existing unrelated failure, `TD-menag-006`). Unblocks S7-06 (now `Ready`). |
| S7-06 | ~~Tower Mastery Story 009 — Cell-Boundary Proximity Tracking~~ **DONE 2026-07-19** | godot-gdscript-specialist (`/dev-story`) | 0.5d | S7-05 | `tower_mastery.gd` subscribes to `tower_removed`/`tower_destroyed` (erasing `_active_signature_by_tower` on each) alongside `tower_placed`/`tower_component_equipped`; all 4 handlers immediately recompute `_signatures_in_range` against the hero's last-known in-bounds cell via a new `_recompute_if_hero_known()` helper. New test file `tests/unit/tower-mastery/cell-boundary-proximity-tracking_test.gd` (9 tests) covers AC-24/AC-25 and the 4 lifecycle-event immediate-recompute behaviors — all passing. Full regression: 1059/1060 (1 pre-existing unrelated failure, `TD-menag-006`). Unblocks S7-07. |

### Should Have -- 2.0d
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S7-07 | ~~Tower Mastery Story 010 — Mastery Progress & Skill Unlock~~ **DONE 2026-07-19** | godot-gdscript-specialist (`/dev-story`) | 1.0d | S7-06 | **Scope note**: real skill-catalogue content remains deferred (Rule 7/ADR-0030, unchanged) — `mastery_progress_updated`/`skill_unlocked` still use the `build_signature` as a placeholder `skill_id`, now documented explicitly rather than assumed away. What actually landed: `tick()` emits `mastery_progress_updated(tower_id, skill_id, progress_percent)` every frame per accruing signature (Formula 2, clamped `[0,100]`); a new `_representative_tower_id_for()` helper supplies the correct lowest-live-tower_id for both events (`skill_unlocked` previously hardcoded `source_tower_id=0`, now fixed). AC-19/20/21/22/23 all passing (7 new tests). Full regression: 1066/1067 (1 pre-existing unrelated failure, `TD-menag-006`). |
| S7-08 | ~~Tower Mastery Story 011 — Cross-Mission Mastery Persistence~~ **DONE 2026-07-19** | godot-gdscript-specialist (`/dev-story`) | 0.5d | S7-07 | `tower_mastery.gd` implements the full `SaveRestorer` interface, registers at `RESTORE_ORDER=34` (the corrected collision-free value); `mastery_time`/`unlocked_skills` survive a full get/restore round-trip; pause-not-reset (AC-13/14/15) and DEFEAT-doesn't-reset/revoke (AC-16/17) required no special-casing — both already fell out of Stories 007/009's existing behavior; new `_has_skill_catalogue`/`_known_skill_ids`/`is_skill_unknown()` DI seam covers AC-18's orphaned-skill_id handling ahead of real catalogue content. 13 new tests, all passing. Full regression: 1079/1080 (1 pre-existing unrelated failure, `TD-menag-006`). |
| S7-09 | Begin Epic 07 Tarot implementation — first 2-3 stories | godot-gdscript-specialist (`/dev-story`) | 0.5d | None | At least the first Tarot story (whichever `/story-readiness` confirms is foundational) Complete and tested |

### Nice to Have -- opportunistic, no fixed estimate
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S7-10 | Mission Select Story 008 — Mission Catalogue & `cell_size` Resolution | godot-gdscript-specialist | Opportunistic | None | `MissionEntry` Resource + `validate()` implemented; at least 2 mission `.tres` entries exist (expanding beyond the current single `the_gap` entry) proving `cell_size` stays fixed while `grid_cols`/`grid_rows` vary (AC-2) — only attempted if capacity remains, per S6-09's own deferral note that this needs real content authoring |
| S7-11 | Fix `TD-menag-006` (Menagerie lure-creature placement bug) | godot-gdscript-specialist | Opportunistic | None | `test_lure_creature_success_full_flow` passes; root cause of the RESERVE-vs-HABITAT placement mismatch identified and fixed, not worked around |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| Tower Mastery Stories 008/009 (originally S6-10) | Blocked on the Tower System component-loadout gap confirmed during S6-10 — required a new architecture decision (S7-01) before they could be attempted | Folded into S7-05/S7-06 above |
| Mission Select implementation (originally S6-09, opportunistic) | Deferred — needs a multi-entry mission catalogue (content authoring), not just code; judged lower priority than Sprint 6's must-haves | Carried as S7-10, still opportunistic |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| S7-01's new ADR could reveal the component-loadout model needs deeper Tower System rework than a data-model addition (e.g. touching placement/combat/save logic) | Medium | Medium-High | Time-box S7-01 to 1.0d investigation + decision; if the fix requires touching `resolve_craft()`-adjacent combat/placement logic beyond the data model itself, split that into its own follow-up story rather than absorbing it into S7-05 |
| Constellation Story 005's performance bound (AC-30) has no defined measurement methodology yet (flagged as Open Question OQ-7 in `constellation.md`, same category as Tower Mastery's own OQ-7) | Medium | Low-Medium | Reuse the same ad hoc `Time.get_ticks_usec()`-based methodology already validated for Tower Mastery's S6-05 prototype rather than inventing a new one |
| Tarot implementation (S7-09) starting cold, no prototype/spike done yet unlike Tower Mastery (which had S6-05's dedicated prototype sprint task) | Low | Low | Tarot is not flagged HIGH-risk in `systems-index.md` (unlike Tower Mastery was) — no prototype step judged necessary; `/story-readiness` before the first story will catch any surprise |

## Dependencies on External Factors
- None currently tracked

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-07-[date].md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

> **PR-SPRINT feasibility gate**: skipped — lean mode (`production/review-mode.txt`).
