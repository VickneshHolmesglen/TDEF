# Sprint 4 Playtest Report — "The Gap" Vertical Slice

> **Story**: `production/stories/foundation/s4-11-playtest-round.md`
> **Facilitator script**: `production/qa/playtest-facilitator-script-sprint-04.md` — use it; don't improvise session structure
> **Origin**: Closes the 2026-07-03 Pre-Production → Production gate-check FAIL (Creative Director finding: no Vertical Slice has ever been played by a human)
> **Sign-off required from**: creative-director, producer — do not consider this story Complete without both signatures below
>
> **STATUS: TEMPLATE ONLY — no real session data has been entered yet.**
> Do not fill this in with fabricated, estimated, or simulated data under any
> circumstance. This file exists so a human facilitator can run sessions with
> zero setup friction the moment 3 real playtesters are available.

---

## Session Log

### Session 1
- **Date**:
- **Playtester profile**: [ ] No prior context on this project  [ ] Experienced tower-defense player  [ ] Other:
- **Build/commit**:
- **Duration**:

**5-Item Checklist**
| # | Item | Result | Evidence |
|---|------|--------|----------|
| 1 | Played core loop without developer guidance | [ ] Yes [ ] No | |
| 2 | Understood what to do within first 2 minutes | [ ] Yes [ ] No | Timestamp of first tower placed: ____ / Timestamp of first SPACE ready-up: ____ |
| 3 | No critical fun-blocker bugs found | [ ] Yes [ ] No | |
| 4 | Core mechanic (tower + hero covering the gap) felt good | [ ] Yes [ ] No | Playtester's own words: |
| 5 | Independently described the "vindication beat" (Pillar 1) unprompted | [ ] Yes [ ] No | Quote (if any): |

**Bugs Found**
| # | Description | Severity | Reproducible |
|---|-------------|----------|--------------|

**Expected/Already-Tracked Reactions** (per facilitator script's Known Rough Edges list — not new bugs)

**Facilitator Notes** (free-form — think-aloud commentary, hesitations, surprises)

---

### Session 2
- **Date**:
- **Playtester profile**: [ ] No prior context on this project  [ ] Experienced tower-defense player  [ ] Other:
- **Build/commit**:
- **Duration**:

**5-Item Checklist**
| # | Item | Result | Evidence |
|---|------|--------|----------|
| 1 | Played core loop without developer guidance | [ ] Yes [ ] No | |
| 2 | Understood what to do within first 2 minutes | [ ] Yes [ ] No | Timestamp of first tower placed: ____ / Timestamp of first SPACE ready-up: ____ |
| 3 | No critical fun-blocker bugs found | [ ] Yes [ ] No | |
| 4 | Core mechanic (tower + hero covering the gap) felt good | [ ] Yes [ ] No | Playtester's own words: |
| 5 | Independently described the "vindication beat" (Pillar 1) unprompted | [ ] Yes [ ] No | Quote (if any): |

**Bugs Found**
| # | Description | Severity | Reproducible |
|---|-------------|----------|--------------|

**Expected/Already-Tracked Reactions**

**Facilitator Notes**

---

### Session 3
- **Date**:
- **Playtester profile**: [ ] No prior context on this project  [ ] Experienced tower-defense player  [ ] Other:
- **Build/commit**:
- **Duration**:

**5-Item Checklist**
| # | Item | Result | Evidence |
|---|------|--------|----------|
| 1 | Played core loop without developer guidance | [ ] Yes [ ] No | |
| 2 | Understood what to do within first 2 minutes | [ ] Yes [ ] No | Timestamp of first tower placed: ____ / Timestamp of first SPACE ready-up: ____ |
| 3 | No critical fun-blocker bugs found | [ ] Yes [ ] No | |
| 4 | Core mechanic (tower + hero covering the gap) felt good | [ ] Yes [ ] No | Playtester's own words: |
| 5 | Independently described the "vindication beat" (Pillar 1) unprompted | [ ] Yes [ ] No | Quote (if any): |

**Bugs Found**
| # | Description | Severity | Reproducible |
|---|-------------|----------|--------------|

**Expected/Already-Tracked Reactions**

**Facilitator Notes**

---

## Compiled Checklist Verdict (fill in only after all 3 sessions are complete)

*Per the story's Acceptance Criteria: each item needs real data from the sessions
above, not an inferred average. Item 5 only needs ONE session to hit "Yes."*

| # | Item | Sessions passing | Overall |
|---|------|-------------------|---------|
| 1 | Played core loop without developer guidance | __ / 3 | [ ] PASS [ ] FAIL |
| 2 | Understood what to do within first 2 minutes | __ / 3 | [ ] PASS [ ] FAIL |
| 3 | No critical fun-blocker bugs found | __ / 3 | [ ] PASS [ ] FAIL |
| 4 | Core mechanic felt good to interact with | __ / 3 | [ ] PASS [ ] FAIL |
| 5 | Vindication beat described unprompted (≥1 session) | __ / 3 | [ ] PASS [ ] FAIL |

## TD-perf-001 Capture (opportunistic — same session, real hardware)

Since real playtest sessions run on real hardware anyway, use this window to also
close `docs/tech-debt-register.md`'s `TD-perf-001` (deferred FPS/draw-call/memory
measurement from Story 008) — a genuine live-rendering measurement that cannot be
captured headlessly, unlike S4-10's pathfinding numbers.

- **Average FPS during a wave-active period**:
- **Draw calls (Debugger → Monitor, Draw Calls)**:
- **Memory usage (Debugger → Monitor, peak)**:
- **Notes** (any frame hitches observed, when):

## Findings Summary (fill in after compiling all sessions)

### Design changes needed

### Balance adjustments

### Bug reports filed (link `/bug-report` outputs)

### Polish items (non-blocking)

---

## Sign-Off

**Producer**: _________________ Date: _____
**Creative Director**: _________________ Date: _____

**Overall verdict**: [ ] All 5 checklist items PASS — re-run `/gate-check` with real data
[ ] Some items FAIL — [describe required follow-up before re-gating]
