# S3-08 — Create Core Layer Epic

**Story ID**: S3-08
**Epic**: Core
**Layer**: Core (meta)
**Type**: Config/Data
**Owner**: producer
**Sprint**: 3
**Estimate**: 0.25 days
**Status**: Backlog — **Nice to Have**
**Manifest Version**: 2026-05-16

## TR Coverage

None — production scaffolding.

## ADR Governing Implementation

None — no code or design changes.

## Background

Sprint 3 creates Core layer systems (Monster, Tower, Damage & Status, Wave Manager) but has
no formal `production/epics/epic-02-core.md` to track the epic as a whole. This story
creates that file and adds story stubs for Hero and remaining Wave Manager work that will
carry into Sprint 4.

## Acceptance Criteria

- [ ] `production/epics/epic-02-core.md` exists with sections: Goal, Governing ADRs,
  GDD Requirements Table, Stories table (populated for S3-02 through S3-06 + Sprint 4 stubs)
- [ ] Story stub files for Sprint 4 Hero work: `production/stories/core/s4-hero-system.md`
  (minimal — Status: Backlog, dependencies listed)
- [ ] `production/epics/epic-02-core.md` stories table references all existing S3 core stories

## Files to Create

- `production/epics/epic-02-core.md`
- `production/stories/core/s4-hero-system.md` (stub only)

## Out of Scope

- Wave Manager Phase 2 stub (already has S3-06; Sprint 4 scope TBD by sprint planning)
- Full story decomposition for Sprint 4 (run `/create-stories core` in Sprint 4 planning)

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: Files exist (smoke check verifiable)

**Status**: [ ] Not yet created

## Dependencies

- Depends on: None
- Unlocks: Sprint 4 planning (epic exists for `/create-stories core` to expand)
