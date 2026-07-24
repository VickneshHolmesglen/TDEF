# S4-11 — Playtest Round: "The Gap" Vertical Slice

**Story ID**: S4-11
**Epic**: Cross-cutting (Production/QA — not owned by any single architecture layer)
**Layer**: N/A
**Type**: Visual/Feel (human-verification only — no automated test evidence is possible or appropriate for this story)
**Owner**: producer + qa-tester (sign-off also required from creative-director, per the gate-check finding this story exists to close)
**Sprint**: 4
**Estimate**: 1.0 day
**Status**: Ready — but see "Genuinely Blocked" section below before attempting to start
**Manifest Version**: 2026-05-16

## Context

**GDD**: None — this is a production/QA process deliverable, not a system implementation. Tracked as a sprint task, not against any TR-ID.

**Origin**: This story exists specifically because the 2026-07-03 Pre-Production → Production gate check (`production/gate-checks/gate-check-pre-production-2026-07-03.md`) returned FAIL, with the Creative Director's finding as the unresolved root cause: **no Vertical Slice has ever been assembled or played by a human.** Every other director's CONCERNS/NOT READY assessment converged on the same point — engineering correctness (tests passing) does not substitute for playtested fun. This story is the sprint's mechanism for actually answering that question with real data.

**What's now true that wasn't on 2026-07-03**: the Wave Manager epic (all 8 stories) closed 2026-07-06, and Story 008 assembled a real, bootable "The Gap" mission scene — the prerequisite this playtest round needs to exist. The scene has been verified headlessly (555/555 tests passing, full phase loop confirmed, real Hero combat confirmed against real spawned monsters). What it has **not** been is played by an actual human being.

**Engine**: N/A — this is a human-facilitation task, not an engineering task.

---

## Genuinely Blocked

Unlike every other story in this session, this one **cannot be executed by an AI agent under any circumstance** — not a tooling gap, a permanent one. It requires:
- 3 real human playtesters, physically or remotely present, playing the actual game
- At least one of them with no prior context on the project (per the VS Validation checklist's explicit "without developer guidance" requirement)
- A human facilitator (producer) taking written notes per session
- Human sign-off from creative-director and producer on the completed report

Do not attempt to simulate, fabricate, or approximate playtest data to close this story. The entire reason this story exists is that the Creative Director's gate-check finding was specifically about *not* accepting engineering proxies for human-verified fun — doing so here would recreate exactly the failure this sprint was structured to fix.

**What an agent picking this story up *can* legitimately do**: prepare everything needed so a human facilitator can run the sessions with zero setup friction the moment playtesters are available (see Implementation Notes below). That preparation work is genuinely useful and unblocked; the sessions themselves are not.

---

## Acceptance Criteria

*Verbatim from `production/qa/qa-plan-sprint-04-2026-07-03.md`'s own VS Validation checklist (sourced from the gate-check skill's Vertical Slice Validation section) — do not paraphrase these in a way that changes their meaning:*

- [ ] A human played through the core loop without developer guidance
- [ ] The game communicated what to do within the first 2 minutes of play
- [ ] No critical "fun blocker" bugs were found
- [ ] The core mechanic (tower + hero covering the gap) felt good to interact with
- [ ] At least one playtester independently described the "vindication beat" experience (Pillar 1) without being prompted

**Session structure** (per the QA plan): 3 sessions total — a mix of a new player (no prior context) and at least one experienced player, per the checklist's "without developer guidance" requirement.

**Sign-off requirement**: written playtest notes per session, all 5 checklist items explicitly answered with real data (not "N/A" or inferred), compiled into `production/playtests/sprint-04-the-gap-playtest.md`, reviewed and signed off by creative-director and producer before Sprint 4 can be marked complete or the gate re-run.

---

## Implementation Notes — preparation work an agent CAN do now

**Status: all 5 prep items below are DONE (2026-07-06).** The sessions themselves remain genuinely blocked on human playtester availability — nothing below changes that.

1. **DONE — scene tweak applied.** `src/gameplay/missions/the_gap/the_gap.gd` now has `@export var debug_controls_enabled: bool = false` (default off). The K-key debug-kill trigger and its HUD help-text mention are both gated behind this flag — real playtesters never see or can trigger it. Left-click (tower placement) and SPACE (ready-up) are real interactions and are never gated. A developer can flip the flag back to `true` in the Inspector for future QA needs. Verified via `tests/integration/mission_scene/mission_scene_the_gap_test.gd` (13/13 passing, 0 errors, 0 failures — that test calls `_debug_kill_hero()` directly, bypassing the input-gated flag entirely, so it is unaffected).
2. **DONE — facilitator script written**: `production/qa/playtest-facilitator-script-sprint-04.md`. Covers session roster requirements, pre-session setup checklist, verbatim opening script, a "what NOT to say" list, per-checklist-item observation guidance (including exact wording for the Pillar 1 "vindication beat" item so the facilitator doesn't accidentally prompt for it), and the known-rough-edges list from item 5 below.
3. **DONE — report template written**: `production/playtests/sprint-04-the-gap-playtest.md`. Empty per-session blocks (3), the 5-item checklist mapped per session, a compiled cross-session verdict table, a TD-perf-001 capture section (see item 4), a findings-summary section, and a sign-off block for creative-director + producer. Explicitly marked "TEMPLATE ONLY — no real session data has been entered yet" to prevent accidental fabrication.
4. **DONE — TD-perf-001 capture section added** to the report template (FPS/draw-calls/memory fields) so the facilitator captures these real numbers during the same live session rather than requiring a separate dedicated one. Not measured yet — genuinely requires the live session.
5. **DONE — known rough edges list embedded** in the facilitator script (item 2 above): scaffolding-only Mission HUD, placeholder `ColorRect` visuals, single hardcoded tower blueprint, no Mission Select screen. Facilitator is instructed to log playtester reactions to these separately from new bug reports.

---

## Out of Scope

- Any code or content changes beyond the minimal scene tweak in Implementation Note 1 (if that decision lands as "yes, hide the debug controls")
- Designing or building the real Mission HUD (separate epic, Skeleton status)
- Resolving `TD-perf-001` through any means other than real playtest-session measurement (Implementation Note 4) — no fabricated/estimated numbers

---

## Test Evidence

**Story Type**: Visual/Feel (human-verification)
**Required evidence**: `production/playtests/sprint-04-the-gap-playtest.md` — must exist, contain real per-session notes, and be signed off by creative-director + producer
**Status**: [x] Template created (2026-07-06) — empty, no real session data yet. [ ] Real session data entered — genuinely blocked on playtester availability, not on preparation work

---

## Dependencies

- Depends on: S4-09 / the Wave Manager epic (Complete 2026-07-06) — the scene this story plays must exist and function correctly, which it now does
- Depends on (external, non-negotiable): 3 human playtesters being scheduled and available
- Unlocks: Re-running the Pre-Production → Production gate check with real data to answer the Creative Director's original NOT READY finding; Sprint 4's overall Definition of Done (which explicitly requires this checklist, not just story-level DoD, per the sprint plan's own "Sprint-level exit condition" note)
