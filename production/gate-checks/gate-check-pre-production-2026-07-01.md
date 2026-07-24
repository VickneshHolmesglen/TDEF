# Gate Check: Pre-Production → Production

**Date**: 2026-07-01
**Checked by**: gate-check skill
**Review mode**: Lean
**Verdict**: FAIL

---

## Required Artifacts: 8/15 present

| # | Artifact | Status |
|---|----------|--------|
| 1 | Prototype in `prototypes/` with README | ✅ `stacked-sprite-test/` + `stacked-sprite-seam/` — both with READMEs |
| 2 | First sprint plan in `production/sprints/` | ✅ sprint-01, sprint-02, sprint-03 |
| 3 | Art bible complete (all 9 sections) + AD sign-off | ❌ Sections 7–9 are PLACEHOLDER. Sign-off skipped (lean mode). |
| 4 | Character visual profiles for key characters | ❌ `design/characters/` does not exist |
| 5 | All MVP-tier GDDs complete | ✅ 10 GDDs present |
| 6 | Master architecture document | ✅ `docs/architecture/architecture.md` v2 |
| 7 | ≥3 Foundation ADRs | ✅ 12 ADRs present, all Accepted |
| 8 | Control manifest | ✅ `docs/architecture/control-manifest.md` |
| 9 | Epics — Foundation **and** Core layer | ❌ Only `epic-01-foundation.md` — Core layer epic missing |
| 10 | Vertical Slice build exists and is playable | ❌ `production/vertical-slice-target.md` is a scope document; no playable build |
| 11 | ≥3 playtest sessions documented | ❌ `production/playtests/` does not exist — 0 sessions |
| 12 | Playtest report | ❌ None |
| 13 | UX specs: main menu, core HUD, pause menu | ❌ `design/ux/mission-hud.md` approved; no main menu spec, no pause menu spec |
| 14 | HUD design document | ✅ `design/ux/mission-hud.md` — Approved 2026-05-18 |
| 15 | Key screen UX specs passed `/ux-review` | ⚠️ Mission HUD: APPROVED; others not created |

---

## Vertical Slice Validation (BLOCKING — FAIL if any NO)

| Check | Result |
|-------|--------|
| A human played the core loop without developer guidance | ❌ NO — no build exists |
| Game communicates what to do within 2 minutes | ❌ UNVERIFIABLE — no build |
| No critical fun-blocker bugs | ❌ UNVERIFIABLE — no build |
| Core mechanic feels good | ❌ UNVERIFIABLE — no build |

> Per gate rules: **any NO here → verdict is automatically FAIL, regardless of all other checks.**

---

## Director Panel Assessment

```
Creative Director:  NOT READY
  — Core fantasy asserted on paper, validated by zero minutes of play. 6/6 VS
    acceptance criteria unchecked. Art bible gaps (Sections 7–9, no character
    profiles) leave the visual identity half-finished at the exact point
    production needs it most. UX wrapper (main menu, pause menu) undefined.

Technical Director: CONCERNS
  — Foundation is production-ready (158/158 tests, OQ-2 resolved, ADR chain
    Accepted). Blocker: ADR-0006's 100–150-agent movement model has never
    been profiled; AC-28 (2 ms/frame at full monster count) is untested.
    Recommends a monster-movement profiling prototype as VS exit criterion.
    Missing Core epic is a planning gap, not an architecture blocker.

Producer:           NOT READY
  — VS unbuilt and unplayed. Wave Manager + Hero (both required for The Gap)
    not yet implemented. No Core-layer epic for scope/traceability. No
    milestones directory. Risk register stale (Pre-Production era, not updated).
    Both Sprint QA conditions still technically open.

Art Director:       CONCERNS
  — Sections 1–6 are production-quality and detailed enough for asset execution.
    Section 8 (Asset Standards — canvas sizes, naming, layer budgets) is missing
    and will cause inconsistency the moment asset production scales. Section 7
    gap blocks floating damage number color spec (interaction-patterns defers
    this to AD). Hero/world seam unvalidated by any player.
```

---

## Blockers

**[1] Vertical Slice not built** *(BLOCKING — gate auto-fails)*
Wave Manager (S3-06, Should Have, not started) and Hero system (not yet in any sprint) are both required for "The Gap." The slice cannot be assembled — let alone playtested — until both are implemented.

**[2] Zero playtests** *(BLOCKING)*
The gate requires ≥3 documented sessions. The core fantasy ("I covered the gap myself") must be validated unprompted by a real player. `production/playtests/` needs to be created and populated.

**[3] Art bible incomplete — Sections 7, 8, 9 are placeholders** *(BLOCKING)*
Section 8 (Asset Standards) is required before production asset work scales — canvas sizes, naming conventions, stacked-sprite layer budgets, and file format matrix are undocumented. Section 7 gap blocks the UI/HUD color system. Section 9 (Reference Direction) is expected for production onboarding.

**[4] Core layer epic missing** *(BLOCKING)*
`production/epics/epic-02-core.md` does not exist. Core combat stories were shipped without epic-level scope tracking. Production cannot begin without a traceable epic structure for the layer that is 100% of the remaining gameplay work.

**[5] No character visual profiles** *(BLOCKING)*
`design/characters/` does not exist. The hero is the emotional centerpiece of the Vertical Slice — the vindication beat — and production asset work cannot begin without a defined visual profile.

---

## Advisory (non-blocking)

- **Main menu + pause menu UX specs** — required before first production sprint touching UI.
- **Monster-movement profiling prototype** — TD recommends measuring AC-28 (100–150 agents @ 2 ms/frame) as a VS exit criterion before content scales up.
- **Risk register update** — current entries are Pre-Production era; log the AC-28 open performance risk and update the phase header.
- **Sprint 3 profiler doc** — `tests/performance/sprint-03-profiler.md` still needs measured values (Sprint 3 QA Condition 2).

---

## Verdict: FAIL

Two directors returned NOT READY (Creative Director, Producer). Per gate rules this makes the verdict minimum FAIL. The Vertical Slice validation — all four checks NO — independently forces FAIL regardless of director verdicts.

**The project is well-built, not unready.** Foundation is solid (158/158 tests). Combat engine largely complete. Architecture clean and traceable. Sprint velocity strong — Sprint 3's 5 Must Haves closed 10 days early. The gap is the expected gap between "systems built" and "systems assembled into a playable slice." Pre-Production exists precisely to close this gap before production commits.

---

## Path to Re-Check

1. **Sprint 3 remaining capacity** — implement S3-06 Wave Manager Phase 1 (Should Have)
2. **Sprint 4** — implement Hero system + assemble "The Gap" playable scene + run ≥3 playtests
3. **Parallel** — fill art bible Sections 7–9; create Hero character visual profile; create `epic-02-core.md`; create main menu + pause menu UX specs
4. **Before re-checking gate** — run monster-movement profiler prototype; confirm GUT suite ≥161 tests, 0 failures; fill `tests/performance/sprint-03-profiler.md`

Re-run `/gate-check` after the first playtest report exists.
