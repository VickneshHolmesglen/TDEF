# Gate Check: Systems Design → Technical Setup

> **Date**: 2026-05-22
> **Verdict**: CONCERNS (gate passes with concerns)
> **Checked by**: gate-check skill (lean mode — all 4 directors)
> **Note**: Retroactive verification — `production/stage.txt` already shows `Pre-Production`. This report formally closes Systems Design with all 9 MVP GDDs APPROVED. Stage.txt not updated.

---

## Required Artifacts: 3/3 present

- [x] `design/gdd/systems-index.md` — 9 MVP systems enumerated; all 9 APPROVED
- [x] All 9 MVP-tier GDDs in `design/gdd/` — EventBus, Grid, Save & Persistence, Hero, Tower, Monster, Damage & Status, Pathfinding, Wave Manager — all present and APPROVED
- [x] `design/gdd/gdd-cross-review-2026-05-15.md` — cross-GDD report; verdict PASS WITH CONCERNS

---

## Quality Checks: 5/6 passing, 1 concern

- [x] All 9 MVP GDDs pass individual design review (8/8 sections; no MAJOR REVISION NEEDED)
- [x] `/review-all-gdds` verdict is not FAIL — PASS WITH CONCERNS
- [x] All cross-GDD consistency issues resolved or explicitly accepted (W1/W2 fixed; Sc1/Sc2 deferred to ADR phase)
- [x] System dependencies mapped in systems-index; bidirectionality noted per GDD
- [x] MVP priority tier defined
- [⚠️] Cross-GDD review dated 2026-05-15; Pathfinding and Wave Manager revised in 9 and 10 additional reviews after that date. Changes were implementation clarifications only — no cross-GDD contracts altered. Review substantially valid; fresh pass recommended post-Technical Setup.

---

## Director Panel

| Director | Verdict | Key Points |
|----------|---------|------------|
| Creative Director | **READY** | All 3 pillars faithfully encoded. Placement is the Puzzle strongest (10-step gate + would_block_all_paths). Sc1 recommendation: hero_died wins over boss_died (protects emotional arc). Pillar 1 thin at MVP — flag for Vertical Slice gate. |
| Technical Director | **CONCERNS** | Foundation contracts crisp; 6 Technical Setup work items (C1–C6). C1 (pathfinding perf) is HIGH — stress harness Sprint 1/2 priority. C2 (per-system budgets), C3 (ADR gap 0006/0007), C4 (Sc1/Sc2 unowned), C5 (test harness unconfigured), C6 (save versioning). |
| Producer | **READY** | MVP scope realistic for solo dev. Dependency chain flows correctly. 5 ADRs pre-existing is correct state. Flag: pathfinding spike Sprint 1/2, Equipment Forge schedule risk (7-system dep), soft internal deadline recommended. |
| Art Director | **READY** | Visual identity exceeds gate requirements. Art bible Sections 1–6 production-grade. Sections 7–9 correctly deferred. Three GDD visual contracts have palette anchoring; no rework risk before Section 7 is authored. |

---

## Blockers: None

---

## Concerns (Technical Setup work items)

1. **[C1 HIGH] Pathfinding stress prototype** — Must be Sprint 1/2 Must Have story. 100+ agents on AStar2D with GDScript virtual overrides is the highest technical risk. Gate Tower + Monster implementation on results.
2. **[C2 MED] Per-system frame budget allocations** — Draft allocation table (Pathfinding, EventBus, Damage, Wave Manager, Render, headroom) as ADR or ADR-0001 addendum.
3. **[C3 MED] ADR 0006/0007 gap** — Confirm whether slots are reserved or dropped. Document explicitly.
4. **[C4 MED] Sc1/Sc2 ownership** — Assign Sc1 (hero/boss same-frame precedence) to Wave Manager's first ADR. Assign Sc2 (templates_ready runtime timeout) as amendment to ADR-0004.
5. **[C5 LOW] GUT/gdUnit4 harness** — Stand up day one of Technical Setup with ≥1 passing test per Foundation system. Not after systems are built.
6. **[C6 LOW] ADR-0003 save versioning** — Verify migration story exists before any save data is written across builds.
7. **[REVIEW] Cross-GDD freshness** — Run targeted `/review-all-gdds` after Pathfinding + Wave Manager final states to catch any late-revision cross-GDD drift.
8. **[RISK] Equipment Forge schedule** — Add to risk register: 7-system dependency + design-last = compressed Alpha window.

---

## Chain-of-Verification

5 challenge questions checked — verdict unchanged (CONCERNS). Pathfinding perf (C1) is the most elevated concern but is already in the risk register and the project is past Technical Setup. No FAIL conditions were softened. Post-review changes to Pathfinding and Wave Manager GDDs were implementation clarifications only.

---

## Forward Gate Notes

- **Vertical Slice gate** must verify Pillar 1 expression (base building / meta-progression) — thin at MVP by design, must be scoped before Alpha
- **ADR resolution of Sc1** (precedence): Creative Director recommends `hero_died` wins
- **Section 7 (Mission HUD visual direction)** must be authored before any HUD implementation begins
- **Tower Mastery prototype** — schedule isolated prototype before Alpha begins (unproven proximity-learning mechanic)
