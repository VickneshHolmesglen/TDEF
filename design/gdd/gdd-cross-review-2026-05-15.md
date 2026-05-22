# Cross-GDD Review Report

**Date:** 2026-05-15
**GDDs Reviewed:** 9 MVP system GDDs
**Game Concept:** `design/gdd/game-concept.md`
**Registry Baseline:** `/consistency-check` 2026-05-15 — PASS (0 conflicts across 26 registered entries)
**Mode:** lean (no specialist subagent spawns; inline analysis using full-session context)

---

## Systems Covered

| # | System | GDD | Status |
|---|--------|-----|--------|
| 1 | EventBus | `design/gdd/event-bus.md` | Approved (Pass 1 — 2026-05-14) |
| 2 | Grid | `design/gdd/grid-system.md` | Approved (Pass 1 — 2026-05-15) |
| 3 | Save & Persistence | `design/gdd/save-persistence.md` | Approved (Pass 1 — 2026-05-15) |
| 4 | Hero | `design/gdd/hero.md` | Approved (Pass 1 — 2026-05-14) |
| 5 | Tower | `design/gdd/tower.md` | Approved (Revision 10 — 2026-05-11; re-confirmed 2026-05-14) |
| 6 | Monster | `design/gdd/monster.md` | Approved (Pass 5 — 2026-05-14; Pass 6 clarifications) |
| 7 | Damage & Status | `design/gdd/damage-status.md` | Approved (Pass 6 lean re-review — 2026-05-14) |
| 8 | Pathfinding | `design/gdd/pathfinding.md` | Approved (Re-review — 2026-05-14) |
| 9 | Wave Manager | `design/gdd/wave-manager.md` | Approved (Re-review — 2026-05-14) |

**Pillars referenced** (no formal `game-pillars.md`): "The Sanctuary is Yours", "Placement is the Puzzle", "The Fight Must Be Worth It". Game-concept Player Fantasy frames the dual identity: **Architect-General + Endless Theorist**.

---

## Consistency Issues

### Blocking
None.

### Warnings — Applied Inline

**✅ W1 — `intermission_duration` Tuning Knobs row was stale in `game-concept.md`** *(fixed)*
Row read `20 sec | 10–30 sec`; canonical (per Rule 7, Session Length formula, Tower GDD, Wave Manager GDD) is `30 sec | 25–40 sec`. Updated.

**✅ W2 — `save-persistence.md` Rule 4 referenced phase "OUTCOME" which is not a real Wave Manager phase** *(fixed)*
Reworded to `mission_phase_changed with new_phase ∈ {MISSION_COMPLETE, DEFEAT}` for unambiguous implementation.

### Warnings — Not Applied (recommendation)

**⚠️ W3 — No formal `design/gdd/game-pillars.md` file**
Pillars are referenced as strings in individual GDD headers; full list is reconstructable only by grepping. Recommendation: create a single source of truth before pre-production. Not blocking.

---

## Game Design Issues

### Blocking
None.

### Forward-Looking Flags (Vertical Slice playtest concerns, not GDD revisions)

**ℹ️ D1 — Sanctuary-phase cognitive load (post-MVP)**
During WAVE_ACTIVE: 1 active system (hero combat). During SCOUT: 3 active systems (placement, constellation, Tarot). Both within comfortable 3–4 attention budget. **Post-MVP Sanctuary phase** has 5+ competing investment loops (Crafting, Menagerie, Defense Building, Equipment Forge, Hero Skill Build). The Player Fantasy embraces combinatorial depth, but Vertical Slice should validate new-player onboarding.

**ℹ️ D2 — Exponential reward vs linear difficulty (intentional asymmetry)**
`wave_reward_scalar` 1.00×→4.768× at wave 8 (exponential, r=0.20 default). `monster_hp_scaling` 1.00×→2.05× at wave 8 (linear). Wave Manager GDD documents the asymmetry as intentional (deterministic difficulty for budget calc, exponential reward for late-wave incentive). Calibration needs Vertical Slice playtest data — risk is either satisfying catharsis or runaway feedback into the next mission.

**ℹ️ D3 — Hero gameplay simplicity at MVP**
MVP Hero = auto-attacks with crit/lifesteal/tier bonus. Active skills, Ultimates, Skill Build System are Alpha-tier. The "Architect-General" fantasy leans heavily on the dual role, but at MVP the hero loop reduces to "be in the right place." Early prototype check: does positioning + targeting alone produce a satisfying hero loop? If not, consider promoting one MVP active ability from Alpha.

---

## Cross-System Scenario Walkthrough

**4 scenarios walked:**

1. **Mission launch → SCOUT → first spawn** — clean. `mission_launched(mission_id, modifiers)` → S&P checkpoint write → Pathfinding builds templates → emits `templates_ready` → Wave Manager gates first `monster_spawn_requested` on receipt. Synchronization explicit and complete.
2. **Hero kills BOSS during final wave** — clean. D&S → Monster `_pending_damage` buffer handles cross-frame timing; lifesteal uses `monster_hp_absorbed` (not `final_damage`) for correct overkill handling; Wave Manager's `boss_died` fast-path discards remaining spawn entries.
3. **Tower destroyed mid-wave by BOSS attack** — clean asymmetry: Hero Affinity recalcs immediately (Rule 20), Constellation deactivates immediately (game-concept EC), but Pathfinding intentionally lets templates stale until next Intermission (EC-11). Correct design — destroyed towers free cells; in-flight paths remain valid (suboptimal but not broken).
4. **Hero dies same frame BOSS dies** — see Sc1 below.

### Blockers
None.

### Warnings

**⚠️ Sc1 — Same-frame `hero_died` and `boss_died` precedence undefined**
Wave Manager state transitions: `hero_died → DEFEAT`, `boss_died → MISSION_COMPLETE`. EventBus synchronous dispatch processes events in emit order, but neither GDD specifies which event Monster System emits first when hero takes a queued lethal hit on the same frame as the hero's killing blow on the BOSS.
**Suggested resolution:** `boss_died` wins → MISSION_COMPLETE. The design intent ("kill the boss") outranks "don't die" because BOSS damage was queued before this frame, while the hero's killing blow resolved this frame.
**Action:** Wave Manager should add a Rule specifying precedence. Resolve during Wave Manager's first ADR pass — not blocking GDD approval.

### Info

**ℹ️ Sc2 — No documented runtime fallback if `templates_ready` never fires**
Pathfinding emits `templates_ready` after route templates build. If build silently fails (corrupted GridConfig, unhandled exception), Wave Manager hangs in SCOUT.
**Mitigations in place:** AC-13 (CI validator for malformed maps); `would_block_all_paths()` confirm-only trigger prevents Tower placement from creating unreachable goals.
**Recommendation:** Add a defensive Pathfinding AC for runtime timeout + diagnostic log. Not blocking — current mitigations cover realistic failure modes.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority | Status |
|-----|--------|------|----------|--------|
| `game-concept.md` | W1 stale intermission_duration | Consistency | Warning | ✅ Fixed inline |
| `save-persistence.md` | W2 OUTCOME phase reference | Consistency | Warning | ✅ Fixed inline |
| `wave-manager.md` | Sc1 same-frame hero/boss precedence | Design | Warning | Open — resolve in ADR phase |
| `pathfinding.md` | Sc2 runtime fallback for templates_ready | Design | Info | Open — defensive AC recommendation |

---

## Verdict: **PASS WITH CONCERNS**

- **0 blocking issues**
- **2 consistency fixes applied inline** (W1, W2)
- **1 design specification gap** (Sc1) — non-blocking, resolve in Wave Manager's first ADR
- **1 defensive recommendation** (Sc2) — non-blocking
- **3 forward-looking playtest flags** (D1, D2, D3) — Vertical Slice concerns, not GDD revisions

**Design strengths surfaced:**
- Per-phase attention budgets are well-controlled (SCOUT=3, WAVE_ACTIVE=1)
- Built-in anti-dominance levers: hero 1.5× ELITE/BOSS bonus, mandatory hero for boss kills, lifesteal cap, pre-placement perk only during SCOUT
- Linear-difficulty vs exponential-reward asymmetry is intentional and documented
- Cross-system event ordering (D&S pipeline, lifesteal round-trip, tower_destroyed propagation) is explicitly designed
- All 26 registered entities/formulas/constants verified consistent across all 9 GDDs

**The architecture phase can proceed safely.** Sc1 (precedence rule) should be resolved during the Wave Manager's first ADR; Sc2 (runtime watchdog) can be addressed during Pathfinding implementation.

---

## Recommended Next: `/gate-check systems-design`

All required artifacts now exist:
- Systems index — present with 9 MVP systems enumerated
- All 9 MVP GDDs — individually approved
- Cross-GDD review report — **this file**
- Consistency check — passed 2026-05-15

The gate can proceed to artifact verification and director-panel assessment.
