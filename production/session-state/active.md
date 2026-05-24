# Session State — Sanctuary Defenders

<!-- STATUS -->
Epic: Pre-Production
Feature: Sprint 1
Task: ADR-0012 WRITTEN + ADR-0002 REVISED + prototype README done (2026-05-24). All recommended core ADRs complete. Boot order now 7 Autoloads: EventBus(1)→SavePersistence(2)→Grid(3)→Pathfinding(4)→GameDataRegistry(5)→SceneManager(6)→WaveManager(7). Coverage: 37/57 TRs (65%) estimated — pending /architecture-review confirmation. Deferred: ADR-0010 (Hero Tower-Synced), ADR-0011 (UI dual-focus). READY FOR: /architecture-review — must be run in a FRESH session (never same session as /architecture-decision).
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
| S1-09 | Vertical Slice experience target | backlog |
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
6. ADR-0006 — Monster movement: position-based over physics-driven
7. ADR-0007 — Damage pipeline: deferred dispatch + is_instance_valid guard
8. ADR-0008 — Tower placement gate: WAVE_ACTIVE block + path-integrity check
9. ADR-0009 — Resource data model for game entities

**Deferrable:**
- ADR-0010 — Hero Tower-Synced Class + Tower Affinity (pure logic, no novel APIs)
- ADR-0011 — UI dual-focus handling (defer to first Presentation GDD)
- ADR-0012 — Wave Manager FSM (recommended; covers TR-wave-001/003/005/006/007)

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
