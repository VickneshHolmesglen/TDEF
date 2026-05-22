# Epic 01 — Foundation Layer

**Phase**: Pre-Production → Production
**Status**: Planned
**Owner**: Technical Director
**Target Milestone**: Vertical Slice (playable)
**Created**: 2026-05-19

## Goal

Implement the 4 Foundation autoloads (EventBus, Save & Persistence, Grid,
Pathfinding) to the depth required for the Vertical Slice to run. All Foundation
systems must be stable before any Core-layer system begins implementation.

## Scope

| System | GDD | ADRs | Status |
|--------|-----|------|--------|
| EventBus | `design/gdd/event-bus.md` | ADR-0001 | Designed |
| Save & Persistence | `design/gdd/save-persistence.md` | ADR-0003 | Designed |
| Grid System | `design/gdd/grid-system.md` | ADR-0005 | Designed |
| Pathfinding | `design/gdd/pathfinding.md` | ADR-0004 | Designed (revised, pending re-review) |

## Out of Scope

- Core layer systems (Hero, Tower, Monster, D&S, Wave Manager) — Epic 02
- UI/HUD implementation — Epic 04
- Networking — deferred post-MVP

## Acceptance Criteria

- [ ] All 4 autoloads boot in correct order (EventBus → Save → Grid → Pathfinding)
- [ ] EventBus: all 61 catalogued events emit without error in test harness
- [ ] Grid: 16×12 cell grid initialises; cell type read API returns correct values
- [ ] Pathfinding: `templates_ready` fires after spawn→goal route pre-computation
- [ ] Save: atomic write (.tmp → .dat) succeeds; 3-slot restore_order verified
- [ ] All 4 systems pass unit tests (`tests/unit/`)
- [ ] Foundation traceability: 57/57 TRs covered (currently 26/57)

## Dependencies

- ADR-0001, ADR-0003, ADR-0004, ADR-0005 — all Accepted ✅
- Pathfinding GDD re-review — Sprint 1 item (S1-06)
- Control manifest — complete ✅

## Estimated Sprints

2–3 sprints (Sprint 2–4), pending Vertical Slice target definition (S1-09).

## Stories

_To be created per system when sprint assigns them._
