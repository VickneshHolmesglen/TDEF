# Session State — Sanctuary Defenders

<!-- STATUS -->
Epic: Pre-Production → Foundation Implementation
Feature: Sprint 2 (2026-05-31 to 2026-06-11)
Task: S2-02 COMPLETE. Next: S2-03 Grid System or S2-04 Pathfinding (both ready-for-dev, no blockers).
Pending: EventBus + SavePersistence Autoloads not yet registered in project.godot — required before S2-05.
<!-- /STATUS -->

## Session Extract — /story-done S2-02 (2026-05-25)
- Verdict: COMPLETE WITH NOTES
- Story: `production/stories/foundation/s2-02-save-persistence.md` — Save & Persistence Autoload
- Tech debt logged: 1 item (TD-save-001) — integration test gaps for AC-3, AC-8, AC-10, AC-12
- Next recommended: S2-03 Grid System (`/dev-story production/stories/foundation/s2-03-*.md`) or S2-04 Pathfinding

## Session Extract — /dev-story S2-02 implementation (2026-05-25)
- Story: `production/stories/foundation/s2-02-save-persistence.md` — SavePersistence Autoload
- Files changed: `src/foundation/save_persistence/save_persistence.gd` (created), `tests/unit/save_persistence/save_persistence_write_test.gd` (created), `tests/unit/save_persistence/save_persistence_restore_test.gd` (created)
- Test written: 8 write tests + 6 restore tests = 14 total (≥8 AC met)
- Blockers: None
- Note: restore tests call `EventBus.sanctuary_state_restored.emit.call_deferred()` — EventBus must be registered Autoload for tests to run
- Next: /code-review src/foundation/save_persistence/save_persistence.gd tests/unit/save_persistence/ then /story-done production/stories/foundation/s2-02-save-persistence.md

## Session Extract — /dev-story S2-02 setup (2026-05-25)
- Story file created: `production/stories/foundation/s2-02-save-persistence.md`
- Design decisions locked:
  - `restore_save_data() -> bool` (not void) — testable error contract
  - Autosave: child Timer node, `timer.paused` for state gating (not _process accumulator)
  - Save path: `user://saves/save_slot_N.dat` (GDD Formula 1, not ADR sketch)
- Implementation files NOT yet written — agent hit session limit
- To resume: `/dev-story S2-02` (story file exists; skip to agent spawn)

## Session Extract — /story-done 2026-05-25
- Verdict: COMPLETE WITH NOTES
- Story: `production/stories/foundation/s2-01-eventbus.md` — S2-01 EventBus Autoload Implementation
- Tech debt logged: None (5 advisory items in Completion Notes)
- Next recommended: S2-02 Save & Persistence (`/dev-story S2-02`)

## 2026-05-25 — S2-01 /code-review results (CHANGES REQUIRED)

**Verdict**: CHANGES REQUIRED — 3 blocking issues.
**Review scope**: `src/foundation/event_bus/` (event_bus.gd + 7 payload Resources + 4 test files)

### Blocking fixes required

1. **`monsters_died_batch` contract conflict** — `event_bus.gd:215` declares `signal monsters_died_batch(payloads: Array)` (intent: `Array[MonsterDiedEvent]`) but `monsters_died_batch.gd` defines a `MonstersDiedBatch` Resource with a lossy schema (`count`, `positions: Array[Vector2i]`, `kill_sources`). The Resource also has a type error: `positions: Array[Vector2i]` vs `MonsterDiedEvent.world_position: Vector2`. **Fix**: delete `MonstersDiedBatch` Resource; change signal to `signal monsters_died_batch(payloads: Array[MonsterDiedEvent])`; update cascade test `_BatchBus` signal and batch test to match.

2. **Signal count assertion will FAIL** — `event_bus_signals_test.gd:170` asserts `is_equal(70)` but both `event_bus.gd` and the `_LocalBus` test double have 76 signals. Fix: update assertion to `is_equal(76)`, update comment block, update ADR validation criteria count.

3. **AC-14 (`sanctuary_health_depleted`) references a non-existent signal** — no such signal in `event_bus.gd`. DEFEAT is triggered via `mission_phase_changed(..., "DEFEAT", ...)`. Fix: update story AC-14 to reference the actual DEFEAT mechanism.

### Additional fixes (non-blocking)
- `event_bus_signals_test.gd:430`: `assert_float` on `int` field `aura_radius_cells` → change to `assert_int`
- Suggestions: type 3 untyped `Array` params; `Dictionary[int, int]` for `scatter_target_cycle`; fix weak `get_class()` inheritance guard test
<!-- /STATUS -->

## 2026-05-18 — Technical Setup → Pre-Production gate passed (CONCERNS)

**Verdict**: CONCERNS (all 4 directors). Advanced with deferred items as Sprint 1 backlog.
**Report**: `production/gate-checks/technical-setup-2026-05-18.md`
**Stage**: `Technical Setup` → `Pre-Production`

### Sprint 1 status (2026-05-19)

| ID | Task | Status |
|----|------|--------|
| S1-01 | Stacked-sprite + 3D/2D seam validation prototype | ✅ done — PROCEED verdict |
| S1-02 | Risk register — log D1/D2/D3 | ✅ done |
| S1-03 | Foundation epic document | ✅ done |
| S1-04 | ADR-0008 Tower placement gate | ✅ done |
| S1-05 | Art bible Sections 5–6 | ✅ done — Sections 5 (Character Design) + 6 (Environment Language) complete |
| S1-06 | GDD re-review — pathfinding | ✅ APPROVED (2026-05-22, review #11) — all 16 blockers resolved across B1–B16 including get_path() two-value contract, CI tool extends SceneTree fix, would_block_all_paths() 6-step procedure, Level Design Guidelines, _spawn_assignment lifecycle, _compute_cost coordinate space, fallback cap default 1, WAVE_ACTIVE rebuild guard, plus B5 .slice() type-safety fix in review #11. |
| S1-07 | GDD re-review — wave-manager | ✅ APPROVED (2026-05-22, review #10) — 0 blockers; R1 Rule 9 min-duration knob, R2 AC-41 wave_time_budget runtime AC, R3 templates_ready lifecycle note. |
| S1-08 | Min test coverage value | backlog |
| S1-09 | Vertical Slice experience target | ✅ done — `vertical-slice-target.md` ("The Gap"); risk D4 closed |
| S1-10 | Godot 4.6 API verification pass | backlog |

**Sprint files:**
- `production/sprints/sprint-01.md`
- `production/epics/epic-01-foundation.md` ✅
- `production/sprint-status.yaml`
- `production/qa/qa-plan-sprint-01-2026-05-18.md`

## Resume Point — 2026-05-16 PM session end

**`/gate-check technical-setup` COMPLETE — verdict FAIL** on 3 missing artifacts.
Resolved in-session: accessibility-requirements.md (Standard tier).
Remaining: art bible Sections 1–4, UX interaction-patterns + 1 screen spec.

Earlier this session:
- `/architecture-review` re-run → PASS WITH NOTES, 26/57 TRs, Foundation 100%
- Roadmap renumbered +1 after ADR-0005 insertion; 10 cross-ref edits across ADR-0001/0002/0003/0004/0005
- Report: `docs/architecture/architecture-review-2026-05-16-pm.md`

**First action next session:** `/ux-design mission-hud` (resolves last UX blocker — convergence point for 4 systems). Then `/art-bible` (heaviest blocker — dedicated session with art-director). Then re-run `/gate-check technical-setup`.

---

## Architecture Document Status

**File**: `docs/architecture/architecture.md`
**Version**: 1 | **Date**: 2026-05-15 | **Engine**: Godot 4.6.2 / GDScript
**GDDs covered**: 10 (game-concept + 9 MVP systems)
**TD sign-off**: APPROVED WITH CONDITIONS

### Sections complete
- Engine Knowledge Gap Summary ✅
- System Layer Map (25 systems across 5 layers) ✅
- Module Ownership (Foundation + Core full; Feature/Presentation summary) ✅
- Data Flow (4 scenarios: frame update, event/signal, save/load, init order) ✅
- API Boundaries (all Foundation + Core pseudocode contracts with invariants) ✅
- ADR Audit (57 TRs, 0 covered — all gaps mapped to 8 ADRs) ✅
- Required ADRs (8 ADRs: 4 must-have before coding, 4 system-specific, 2 deferrable) ✅
- Architecture Principles (5 principles) ✅
- Open Questions (5 OQs) ✅

---

## Required ADRs — Run Order

**Before coding starts (Foundation + Core):**
1. ✅ `/architecture-decision EventBus architecture` → ADR-0001 (Accepted 2026-05-15)
2. ✅ `/architecture-decision Scene and Autoload structure` → ADR-0002 (Accepted 2026-05-16)
3. ✅ `/architecture-decision Save file format` → ADR-0003 (Accepted 2026-05-16)
4. ✅ `/architecture-decision Pathfinding strategy` → ADR-0004 (Accepted 2026-05-16)

**Before each system is built (renumbered 2026-05-16 PM after Grid took ADR-0005):**
5. ✅ ADR-0005 — Grid system data model (Accepted 2026-05-16)
6. ✅ ADR-0006 — Monster movement: position-based over physics-driven (Accepted 2026-05-24)
7. ✅ ADR-0007 — Damage pipeline: deferred dispatch + is_instance_valid guard (Accepted 2026-05-24)
8. ADR-0008 — Tower placement gate: WAVE_ACTIVE block + path-integrity check
9. ✅ ADR-0009 — Resource data model for game entities (Accepted 2026-05-24)

**Deferrable:**
- ✅ ADR-0010 — Hero Tower-Synced Class + Tower Affinity (Accepted 2026-05-24; covers TR-hero-002/003/006)
- ADR-0011 — UI dual-focus handling (defer to first Presentation GDD)
- ✅ ADR-0012 — Wave Manager FSM (Accepted 2026-05-24; covers TR-wave-001/003/005/006/007)

---

## Open Questions (from architecture.md)

| # | Question | Blocking |
|---|----------|----------|
| OQ-1 | ~~Save format: ConfigFile vs JSON vs binary store_var~~ | ✅ Resolved by ADR-0003 (store_32 header + store_var master Dict) |
| OQ-2 | Performance budgets not configured in technical-preferences.md | Pre-Production gate |
| OQ-3 | SceneManager: which node owns SANCTUARY↔MISSION transitions | ADR-0002 |
| OQ-4 | duplicate_deep() usage policy for composite Resources | ADR-0008 |
| OQ-5 | Per-mission grid dimensions — how communicated to Grid at load | Mission Select GDD |

**TD condition**: OQ-2 must be resolved before `/gate-check pre-production`.

---

## Pre-ADR-1 Prep Queue (carry-forward from previous session)

1. [ ] **Author `design/gdd/game-pillars.md`** — 3 named pillars + design tests [CD]
2. [ ] **Add Visual Identity Anchor** to `design/gdd/game-concept.md` [CD + AD]
3. [ ] **Godot 4.6 API verification pass** on 9 MVP GDDs [TD]
4. [ ] **Create `production/risk-register/`** and log D1/D2/D3 [PR]
5. [ ] **Refresh `CLAUDE.md` "Up Next" list** [PR]
6. [ ] **Add meta-progression scope note** to `game-concept.md` [CD]
7. [ ] **Configure performance budgets** in `technical-preferences.md` [TD — resolves OQ-2]

---

## Gate Passed: Systems Design → Technical Setup (2026-05-15)
- Verdict: PASS WITH CONCERNS
- All 9 MVP GDDs approved; `docs/architecture/architecture.md` written

## After ADR-0001–ADR-0004 are written:
- ✅ `/create-control-manifest` — `docs/architecture/control-manifest.md` written (2026-05-16)
  - 4 layers: Foundation (37 req / 17 forb / 6 guardrails), Core (10/4/3), Feature (6/3/0), Presentation (engine-ref only)
  - Global: 6 naming conventions, 18 forbidden APIs, 6 cross-cutting constraints
- ✅ `/gate-check technical-setup` — ran 2026-05-16, verdict **FAIL** (8 blockers)
- ✅ `/test-setup` — `tests/` + `.github/workflows/tests.yml` created (2026-05-16)
  - Resolves 2 gate blockers: tests/ dir + CI workflow
  - ⚠ Remaining blocker: at least 1 example test file needed (`tests/unit/*/`)

## Remaining Gate Blockers (Technical Setup → Pre-Production)

| # | Blocker | Command |
|---|---------|---------|
| 1 | ✅ Example test file — `tests/unit/event_bus/event_bus_lifecycle_test.gd` (5 tests, ADR-0001 lifecycle) | done |
| 2 | ✅ Performance budgets configured — 60 FPS / 16.67ms / 200 draw calls / 1 GB RAM (resolves OQ-2) | done |
| 3 | ✅ `/architecture-review` (2026-05-16) — verdict CONCERNS, 22/57 TRs covered. Files: `architecture-review-2026-05-16.md`, `architecture-traceability.md`, `tr-registry.yaml` (v2). **New blockers found**: (a) Grid has no ADR — write one for "Grid System data model and access pattern"; (b) ADR-0004 footer claims TR-wave-003 but covers TR-wave-004 (1-line fix). | done |
| 3a | ✅ ADR-0004 TR mapping fix — `TR-wave-003` → `TR-wave-004` in footer | done |
| 3b | ✅ ADR-0005 Grid System data model — `docs/architecture/adr-0005-grid-system-data-model.md` (Accepted 2026-05-16). Covers TR-grid-001 to TR-grid-004. Traceability: 26/57 TRs covered. TR registry v3. Architecture registry updated (+2 stances, +1 contract, +2 forbidden patterns). | done |
| 3c | ✅ `/architecture-review` re-run (2026-05-16 PM) — verdict **PASS WITH NOTES**, 26/57 covered, Foundation 100%. Fixed roadmap collision: shifted Monster/Damage/Tower/Resource ADRs +1 (now ADR-0006/0007/0008/0009). 10 cross-ref edits applied to ADR-0001/0002/0003/0004/0005. Report: `architecture-review-2026-05-16-pm.md`. | done |
| 4 | ✅ Art bible (Sections 1–4) — `design/art/art-bible.md` (2026-05-18). Visual Identity Statement, Mood & Atmosphere, Shape Language, Color System. 7 palette colors with hex+HSL, semantic vocabulary, colorblind safety map. | done |
| 5 | ✅ `design/accessibility-requirements.md` — **Standard tier** committed 2026-05-16 PM. PC-only, K/M + gamepad. 7 explicit Comprehensive/Exemplary deferrals. Color-as-only-indicator audit + critical-SFX visual-backup audit + per-system matrix all populated for 9 MVP systems. | done |
| 6a | ✅ `design/ux/interaction-patterns.md` — v1 seed catalogue committed 2026-05-17. 10 patterns specced (Grid Placement Cursor, Contextual Info Panel, State-Gated Action Button, Cost-Labelled Button, Resource Counter, Contextual HP Bar, Persistent Boss Overlay, Floating Damage Number, Phase Countdown Timer, Phase Transition Banner). 9 gaps documented. Standard-tier a11y per pattern. | done |
| 6b | ✅ `design/ux/mission-hud.md` — Mission HUD UX spec complete 2026-05-17. 13 sections, 13 ACs, 7 OQs. 3 EventBus gaps flagged (`hero_hp_changed`, `hero_skill_cooldown_updated`, `tower_hp_changed`). Pending `/ux-review`. | done |

---

## Key Architectural Decisions (architecture.md confirmed)

- **Autoload boot order**: EventBus (1) → Save & Persistence (2) → Grid (3) → Pathfinding (4)
- **Pathfinding**: AStar2D (not NavigationServer) — post-cutoff avoidance decision
- **Monster scene root**: Area2D (not CharacterBody2D) — position-based movement
- **D&S deferred dispatch**: `await get_tree().process_frame` + `is_instance_valid(self)` guard
- **EventBus cascade limit**: max 2 levels; batch at 20 monster_died/frame
- **Save**: atomic .tmp → .dat; format deferred to ADR-0003
- **templates_ready gate**: Wave Manager + Monster Manager gate on _routes_ready bool
- **Tower write restriction**: Grid write API restricted to Tower System only (convention enforced)
- **WAVE_ACTIVE block**: Tower.place_tower() returns false — no queueing
- **Dual-focus HIGH RISK**: All 3 Presentation systems must test K/M + gamepad explicitly
- **FileAccess MEDIUM RISK**: Every store_* call checks bool return (4.4+)
- **duplicate_deep() policy**: Needed for nested Resources — scope defined in ADR-0008

## Session Extract — /architecture-review 2026-05-24
- Verdict: CONCERNS
- Requirements: 57 total — 49 covered, 2 partial, 6 gaps (Foundation 100%)
- New TR-IDs registered: None (all 57 confirmed active; registry last_updated bumped to 2026-05-24)
- GDD revision flags: None
- Top issues: (1) 0006→0007→0009→0012 chain all Proposed — blocks Core story authoring; Accept ADR-0006 first to cascade-unblock. (2) ADR-0002 scene hierarchy diagram still shows WaveManager inside MissionScene (contradicts Autoload #7 reclassification). (3) Accepted ADR-0002 embeds boot positions defined by Proposed ADR-0009/0012 (status inversion). (4) ADR-0001 (call_deferred) vs ADR-0007 (await process_frame) deferral-primitive divergence.
- Top ADR gaps: TR-tower-005 Scout-only perk activation (partial); TR-ds-004 status effects (post-MVP ADR); ADR-0010 Hero Tower-Synced (deferred, covers TR-hero-002/003/006)
- Engine: PASS — no deprecated APIs; post-cutoff APIs flagged. Minor: ADR-0006 should verify BOSS alpha-compositing on D3D12 (Windows default in 4.6), not only Vulkan.
- Report: docs/architecture/architecture-review-2026-05-24.md
