# S3-07 — Godot 4.6 API Annotation Pass (S2-09 Carryover)

**Story ID**: S3-07
**Epic**: Core
**Layer**: Core (documentation pass)
**Type**: Config/Data
**Owner**: technical-director
**Sprint**: 3
**Estimate**: 1.0 days
**Status**: Complete — **Nice to Have**
**Manifest Version**: 2026-05-16

## TR Coverage

None — documentation pass, no GDD requirement.

## ADR Governing Implementation

None — no code changes. Documentation update only.

## Background

During Sprint 2 gate check, risk register item T2 (Godot 4.4–4.6 post-cutoff API changes)
was flagged as `🟡 Watch`. This story closes that risk by annotating each MVP GDD with the
specific Godot API calls it depends on and whether those APIs changed in 4.4, 4.5, or 4.6.

## Acceptance Criteria

- [ ] Each of the 9 MVP GDDs has a post-cutoff API risk annotation block added at the top
  or in a new "Engine Risk Notes" section
- [ ] Annotation format:
  ```
  ## Engine Risk Notes (Godot 4.6.2)
  | API | Used for | Risk | Status |
  |-----|---------|------|--------|
  | FileAccess.store_32() | Save write | MEDIUM (bool return Godot 4.4+) | Handled in ADR-0003 |
  | duplicate_deep() | Tower resource copy | MEDIUM (Godot 4.5+) | Verify before S3-03 |
  ```
- [ ] `docs/engine-reference/godot/VERSION.md` updated if new API gaps discovered
- [ ] `production/risk-register/risk-register.md` T2 entry updated from `🟡 Watch`
  to `✅ Mitigated` (if no new unmitigated gaps) or `🔴 Active` with specific gaps listed

## Files to Modify

- All 9 MVP GDDs in `design/gdd/` (add Engine Risk Notes section)
- `docs/engine-reference/godot/VERSION.md` (update if new gaps found)
- `production/risk-register/risk-register.md` (update T2 status)

## Out of Scope

- No code changes
- No new ADRs (existing ADRs already address known risks; this pass discovers unknowns)

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: Smoke check — verify GDD files exist and have Engine Risk Notes sections

**Status**: [ ] Not yet verified

## Dependencies

- Depends on: None
- Unlocks: Pre-Production → Production gate (T2 risk mitigation evidence)

## Completion Notes
**Completed**: 2026-07-07
**Criteria**: 4/4 passing
**Deviations**: None (an initial interpretive error — leaving T2 at 🟡 Watch instead of escalating to 🔴 Active per AC-4's literal wording — was caught and corrected within this session)
**Test Evidence**: Config/Data — no smoke check report post-dates this work yet; ADVISORY, not blocking. Recommend running `/smoke-check` to generate current evidence.
**Code Review**: Skipped — no code was written (documentation-only Config/Data story)
