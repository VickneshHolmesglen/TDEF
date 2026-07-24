# Sprint 3 — Core Combat Engine
**Dates**: 2026-06-30 to 2026-07-11 (10 working days)

## Sprint Goal

Implement the Core layer combat engine (Monster, Tower, Damage & Status) to VS-playable
depth, close Sprint 2 QA debt, and optionally begin Wave Manager — so Sprint 4 can wire
Hero + Wave Manager into "The Gap" and reach a playable Vertical Slice.

## Capacity

- Total days: 10
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|-------------|-------------------|
| S3-01 | TD-save-001 debt closure — AC-8, AC-10, AC-12 test coverage | godot-gdscript-specialist | 0.5d | S2-02 (Complete) | Unit tests for deferred-emit timing (AC-8), `register()` direct call (AC-10), EventBus signal wiring (AC-12) pass; no new failures in existing 158-test suite |
| S3-02 | Monster system implementation | godot-gdscript-specialist | 2d | ADR-0006, `design/gdd/monster.md`, EventBus+Grid (S2) | Monsters spawn at spawn cell, walk template route, deal breach at goal cell; `monster_spawned`, `monster_damage_taken`, `monster_died` signals fire correctly; pathfinding reroute observed when tower placed; ≥80% unit test coverage |
| S3-03 | Tower system implementation | godot-gdscript-specialist | 2d | ADR-0008, `design/gdd/tower.md`, EventBus+Grid+Save (S2) | Tower placed on PLACEABLE cell, registers occupancy in Grid, auto-fires on nearest in-range monster in WAVE_ACTIVE; placement blocked during WAVE_ACTIVE; `tower_placed`, `tower_fired`, `tower_destroyed` signals fire; ≥80% coverage |
| S3-04 | Damage & Status system implementation | godot-gdscript-specialist | 1d | ADR-0007, `design/gdd/damage-status.md`, S3-02+S3-03 | Damage formula resolves `tower_fired` → HP reduction → `monster_damage_taken`; overkill clamped to 0; on-death `monster_died` fires with correct payload; ≥80% unit test coverage |
| S3-05 | Combat loop integration test | godot-gdscript-specialist | 0.5d | S3-02, S3-03, S3-04 | End-to-end: place 1 tower, spawn 1 monster at known HP, confirm tower kills it in expected shots per formula; `monster_died` fires with correct payload; full 158+ test suite still green; test in `tests/integration/core/` |

**Must Have total**: 6 days

---

### Should Have

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|-------------|-------------------|
| S3-06 | Wave Manager Phase 1 — FSM + basic spawn script | godot-gdscript-specialist | 2d | ADR-0012, `design/gdd/wave-manager.md`, S3-02 | Phase FSM: SCOUT → WAVE_ACTIVE → INTERMISSION transitions fire correct EventBus signals; single-lane spawn script delivers N monsters from config; `templates_ready` gate respected; ≥80% unit test coverage |

**Should Have total**: 2 days

---

### Nice to Have

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|-------------|-------------------|
| S3-07 | S2-09 carryover — Godot 4.6 API annotation pass | technical-director | 1d | None | Each of 9 MVP GDDs annotated with post-cutoff API risks; `docs/engine-reference/godot/` updated if new gaps found; T2 risk status updated to Mitigated |
| S3-08 | Create Core layer epic + story scaffolds | producer | 0.25d | epic-01 (Complete) | `production/epics/epic-02-core.md` exists; story stubs for Hero + Wave Manager in `production/stories/core/` |
| S3-09 | PLACEABLE cost design confirmation | game-designer | 0.25d | S2-04 (Complete) | Game designer confirms acceptable monster shortcut threshold; value documented in pathfinding GDD tuning knobs or a quick-spec; PLACEABLE cost advisory in QA sign-off closed |

**Nice to Have total**: 1.5 days

---

## Carryover from Sprint 2

| Task | Reason | New ID | New Est. |
|------|--------|--------|----------|
| TD-save-001 (AC-8, AC-10, AC-12) | Accepted as open tech debt in Sprint 2 QA sign-off — no automated test coverage | S3-01 | 0.5d |
| Godot 4.6 API annotation pass (S2-09) | Nice to Have in Sprint 2; deferred when test-fix scope ran long | S3-07 | 1d |
| PLACEABLE cost design sign-off | Design decision; must close before VS gate per QA sign-off conditions | S3-09 | 0.25d |

## Profiler Obligations (open from Sprint 2 — not a story, measured at first playtest)

S2-04 profiler ACs remain open and must be recorded at the **first integration test run
with real monsters in motion** (earliest opportunity: S3-05 combat loop integration test):

- **AC-4**: 100 `get_path()` calls ≤1ms p99.9
- **AC-17**: `would_block_all_paths()` ≤5ms p99 on 24×18 grid
- **AC-24a**: Fallback A* baseline measurement

Record profiler output in `tests/performance/` or a QA evidence doc.

---

## Risks

| Risk | Prob | Impact | Mitigation |
|------|------|--------|------------|
| Monster + Tower integration more complex than estimated | Medium | Medium | S3-05 combat integration test gates S3-06 — if it's not green, Wave Manager slips cleanly to Sprint 4 |
| Godot 4.6 signal covariance surprises in Core systems (like the `Array[Vector2i]` issue in S2) | Medium | Low | Apply dict-wrapper + untyped-Array lessons from Sprint 2; specialist reviews handler signatures before connecting |
| S3-06 Wave Manager scope creep (full FSM is large) | High | Low | S3-06 is Should Have — cuts cleanly to Sprint 4 without blocking Must Have |

---

## Dependencies on External Factors

- All Foundation autoloads (EventBus, Grid, Save, Pathfinding) — **available** (Sprint 2 Complete, 158 tests green)
- ADRs 0006 (Monster Movement), 0007 (Damage Pipeline), 0008 (Tower Placement), 0010 (Hero-Tower Synced Class), 0012 (Wave Manager FSM) — all **Accepted**
- GDDs for Monster, Tower, Damage & Status, Wave Manager — all **Approved**

---

## Definition of Done

- [x] All Must Have stories Complete (S3-01 through S3-05)
- [x] All Logic/Integration stories ≥80% unit/integration test coverage
- [x] Existing 158-test suite still passes (no regressions) — now 299 tests, 0 failures
- [x] S2-04 profiler obligations recorded at S3-05 integration test run (AC-4, AC-17, AC-24a) — recorded 2026-07-03 in `tests/performance/sprint-03-profiler.md`. AC-17 PASS (0.054ms), AC-24a recorded (30.645ms, satisfies AC-24b formula), AC-4 INVALID (test methodology gap — measures cold fallback path, not warm template lookup; tracked as TD-path-001, not a code-performance failure)
- [x] QA plan exists: `production/qa/qa-plan-sprint-03-2026-07-03.md`
- [x] Smoke check passed: `/smoke-check sprint` — PASS WITH WARNINGS (`production/qa/smoke-2026-07-03.md`)
- [x] QA sign-off: APPROVED WITH CONDITIONS (`production/qa/qa-signoff-sprint-03-2026-07-03.md`)
- [x] No S1/S2 bugs in delivered features
- [ ] Design documents updated for any deviations from GDD

---

**Total load**: 6d (Must Have) + 2d (Should Have) = 8d vs 8d available.
Wave Manager (S3-06) is the natural cut point if Must Have stories run long — carries cleanly to Sprint 4.
