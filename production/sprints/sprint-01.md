# Sprint 1 — 2026-05-19 to 2026-05-30

## Sprint Goal

Establish the Pre-Production production structure, validate the highest-risk
art/technical decisions via prototypes, and close all deferred gate items so
Sprint 2 implementation tracks can begin unblocked.

## Capacity

- Total days: 10
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|-------------|-------------------|
| S1-01 | Stacked-sprite + 3D/2D seam validation prototype | Art Director | 1 day | None | Prototype exists; seam verdict documented (viable/not-viable) |
| S1-02 | Risk register — log D1/D2/D3 risks | Producer | 0.5 day | None | `production/risk-register/` exists; ≥3 risks logged with probability/impact/mitigation |
| S1-03 | Foundation epic document | Producer | 0.5 day | None | `production/epics/epic-01-foundation.md` written ✅ |
| S1-04 | ADR-0008 Tower placement gate | Tech Director | 1 day | ADR-0005 | ADR-0008 Accepted; covers duplicate_deep() policy + WAVE_ACTIVE block |
| S1-05 | Art bible Sections 5–6 (Character Design + Environment Language) | CD / Art Director | 1.5 days | Art bible Sec 1–4 ✅ | Sections appended to `design/art/art-bible.md`; character silhouette vocabulary + environment material language defined |

**Must Have total**: 4.5 days

### Should Have

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|-------------|-------------------|
| S1-06 | GDD re-review — `design/gdd/pathfinding.md` | Creative Director | 0.5 day | None | `/design-review` run; PASS or new revision logged |
| S1-07 | GDD re-review — `design/gdd/wave-manager.md` | Creative Director | 0.5 day | None | `/design-review` run; PASS or new revision logged |
| S1-08 | Set minimum test coverage value in `technical-preferences.md` | Tech Director | 0.25 day | None | `# Minimum Coverage` field updated with a real threshold (e.g. 80%) |
| S1-09 | Vertical Slice experience target — one-page scripted moment | Creative Director | 1 day | None | `production/vertical-slice-target.md` written; 1 scripted moment defined with win/fail conditions |

**Should Have total**: 2.25 days

### Nice to Have

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|-------------|-------------------|
| S1-10 | Godot 4.6 API verification pass on 9 MVP GDDs | Tech Director | 2 days | None | Each GDD annotated with any post-cutoff API risks; `docs/engine-reference/godot/` updated if gaps found |

**Nice to Have total**: 2 days

---

**Total load**: 8.75 days vs 8 available — S1-10 defers if Must Have + Should Have runs long.

---

## Carryover from Previous Sprint

_None — this is Sprint 1._

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Stacked-sprite seam validation fails — technique non-viable | Medium | HIGH — entire visual style must pivot | Day 1 priority; if fails, run `/brainstorm` on alt 2D rendering approach immediately |
| Art bible Sec 5–6 drags past sprint due to scope | Low | Medium | Time-box to 1.5 days; document what's complete, defer remainder to Sprint 2 |
| ADR-0008 reveals duplicate_deep() architecture gap requiring GDD revision | Low | Medium | ADR blocked: escalate to TD + CD; hold Sprint 2 Tower stories until resolved |

## Dependencies on External Factors

- Godot 4.6.2 editor must be launchable for prototype work (S1-01)
- ComfyUI available for any art samples needed in art bible (optional)

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed and files written
- [ ] All tasks pass their acceptance criteria
- [ ] Risk register exists at `production/risk-register/`
- [ ] Foundation epic exists at `production/epics/epic-01-foundation.md`
- [ ] Stacked-sprite verdict documented
- [ ] ADR-0008 Accepted
- [ ] No Sprint 1 tasks left in `ready-for-dev` state
