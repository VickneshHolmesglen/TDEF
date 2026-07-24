# Gate Check: Systems Design → Technical Setup (Revalidation)

> **Date**: 2026-07-10
> **Verdict**: CONCERNS (gate passes with concerns)
> **Checked by**: gate-check skill (lean mode — all 4 directors)
> **Note**: Second retroactive verification of this gate. It was already formally closed
> once — see `production/gate-checks/systems-design-2026-05-22.md` (verdict CONCERNS).
> `production/stage.txt` currently reads `Pre-Production`, several stages ahead of this
> gate's target — the project has since shipped a fully-implemented, fully-tested MVP
> (650/650 tests passing as of this session). This re-run was triggered by
> `/gate-check systems-design` being invoked directly rather than via auto-detect, and is
> being recorded for completeness rather than to advance any stage. **`stage.txt` is not
> updated by this report.**

---

## Required Artifacts: 3/3 present

- [x] `design/gdd/systems-index.md` — 25 systems enumerated, 9 MVP systems, all APPROVED
- [x] All 9 MVP-tier GDDs in `design/gdd/` — EventBus, Grid, Save & Persistence, Hero,
      Tower, Monster, Damage & Status, Pathfinding, Wave Manager — all present, all
      APPROVED, all with 8/8 required sections (Overview, Player Fantasy, Detailed
      Design, Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria)
- [x] `design/gdd/gdd-cross-review-2026-05-15.md` — cross-GDD report; verdict PASS WITH
      CONCERNS, 0 blocking issues

---

## Quality Checks: 5/6 verified clean, 1 not exhaustively re-checked

- [x] All 9 MVP GDDs pass individual design review (8/8 sections; no MAJOR REVISION NEEDED)
- [x] `/review-all-gdds` verdict is not FAIL — PASS WITH CONCERNS
- [x] All cross-GDD consistency issues resolved or explicitly accepted — W1/W2 fixed
      inline at the time; Sc1 (wave-manager.md same-frame hero/boss precedence) confirmed
      resolved via ADR-0012/Story 001's `hero_died` absolute-priority handling; Sc2
      (pathfinding runtime fallback) non-blocking, addressed during implementation
- [x] System dependencies mapped bidirectionally in the systems index's Dependency Map
- [x] MVP priority tier defined (Priority Tiers table)
- [?] No stale GDD references — reasonably confident given this session's active
      maintenance (several cross-reference fixes made this session), but not
      exhaustively re-verified line-by-line against current `src/` state today

---

## Director Panel

| Director | Verdict | Key Points |
|----------|---------|------------|
| Creative Director | **CONCERNS** | Exceptional ludonarrative consonance across all 9 GDDs — every system independently converges on "mastery-as-vindication, not power." No formal `game-pillars.md` (pillars only exist as header strings, grep-reconstructable — real governance gap for future GDDs). MVP under-represents the "Endless Theorist" half of the core fantasy (lives in VS/Alpha systems — Constellation, Tarot, Crafting, Menagerie); acceptable for MVP fun-testing but not a full-fantasy demonstration. Hero MVP loop risk (positioning-only) flagged, same as 2026-05-15 cross-review D3. |
| Technical Director | **READY** | `architecture.md` is a complete layered design with module ownership, API contracts, 4 data-flow scenarios, boot-order invariant, 5 governing principles. ADR-0001/ADR-0002 Accepted, internally consistent, correctly sequenced. High-risk engine domains mapped to affected systems with a conservative-alternative principle (AStar2D over NavigationServer). Performance budgets now documented in `technical-preferences.md` (60 FPS / 16.67ms / 200 draw calls / 1GB), closing the prior OQ-2 sign-off condition. Open: `FileAccess.open()` on 4.6.2 still flagged Verification Required for Save & Persistence; TR-path-007 field-scale 100-agent perf candidate-closed by S4-10 but not confirmed to cover the movement-budget dimension specifically (only AStar pathfinding confirmed). |
| Producer | **CONCERNS** | Scope realism and dependency ordering both sound — 9 MVP systems correctly isolate the "is it fun" core loop; Foundation → Core → Feature → Presentation ordering executed without deadlock. The EventBus contract-churn risk this same gate flagged back in May **did materialize** (`wave_completed` signature change broke 2 subscribers; a duplicate `mission_phase_changed` emission bug shipped and was only caught and fixed this session as TD-hero-005) — foreseen, contained, but the single biggest recurring cost, exactly as predicted. One minor decomposition gap: Pathfinding.md referenced Mission HUD (a Presentation-layer system), forcing a skeleton-stub workaround. |
| Art Director | **CONCERNS** | Art bible substance is strong — all 9 sections complete (2026-07-06), Section 1's Visual Identity Statement gives a visual team everything needed (miniature-diorama rule, 3 pillar-tied principles, hybrid 2D/3D rationale). Structural gap: `game-concept.md`'s own Visual/Audio Requirements section was never filled in or pointed at the art bible — reads `[To be designed]` in the root vision doc a future auditor would check first. Not a rework-causing gap; no visual team was ever blocked by it. |

---

## Blockers: None

## Chain-of-Verification

5 challenge questions checked for this CONCERNS draft (per gate-check skill Section 5a):
1. Could any concern be elevated to a blocker? — No; all four are documentation/governance
   gaps or already-materialized-and-contained risks, none threaten the shipped, tested
   implementation.
2. Resolvable within the next phase, or compounding? — All four are cheap, standalone
   documentation fixes (a pillars doc, a visual-anchor pointer); the EventBus churn risk
   is now low-going-forward given the contract is mature (72 catalogued events, extensive
   test coverage).
3. Any FAIL condition softened into a CONCERN? — No; relayed director verdicts as given.
4. Unchecked artifacts that could reveal more blockers? — Directors covered
   game-concept.md, art-bible.md, architecture.md, ADR-0001/0002, systems-index.md, and
   session-state/active.md directly; no additional sweep performed today beyond that.
5. Do the concerns compound into a blocking problem together? — No; they sit in
   unrelated domains (pillars documentation, visual-anchor documentation, and a
   historical EventBus risk that already resolved).

**Verdict unchanged: CONCERNS.**

---

## Recommendations (non-blocking, cheap to close)

1. Create `design/gdd/game-pillars.md` as the single source of pillar truth (flagged in
   both the 2026-05-15 cross-review as W3 and again by this run's Creative Director).
2. Add a Visual Identity Anchor pointer in `game-concept.md`'s Visual/Audio Requirements
   section, linking to `art-bible.md` Section 1, so the root vision doc isn't misleading
   to a future reader who doesn't know to check the art bible separately.
3. Pull the S4-10 stress-test report to confirm whether it covers the 100-agent
   field-scale *movement* budget (AC-28/AC-40), not just AStar pathfinding query cost —
   Technical Director flagged this as still unconfirmed rather than resolved.

## Stage File

`production/stage.txt` **not modified** — it already reads `Pre-Production`, ahead of
this gate's target stage. Recording this report is for completeness/audit trail only.
