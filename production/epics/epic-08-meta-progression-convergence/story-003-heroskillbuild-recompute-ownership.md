# Story 003: Ultimate Recompute & Ownership

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/hero-skill-build.md`
**Requirement**: `TR-heroskill-001`

**ADR Governing Implementation**: ADR-0030 (Hero Skill Build Ultimate Lookup-Table Architecture)
**ADR Decision Summary**: Hero Skill Build computes the category profile, classifies its shape, and derives the Ultimate ID entirely within its own system. It emits `ultimate_skill_changed(ultimate_id)` with the final resolved result; Hero System applies it (sets U slot, tracks cooldown) and never independently re-derives it from raw skill IDs.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Hero Skill Build is reclassified Autoload #13 specifically so `active_skill_equipped`/`ultimate_skill_changed` can be correctly re-emitted at `mission_launched` regardless of scene-transition timing — mirroring ADR-0028's `MissionRuntimeState` reasoning.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0030 directly.
- Forbidden: Hero System must never independently compute a category profile or shape from raw skill IDs — verified by confirming Hero's own code path contains no category-counting or shape-classification logic.
- Guardrail: `active_skill_equipped`/`ultimate_skill_changed` are re-emitted at `mission_launched` so a freshly-instantiated Hero (a `MissionScene` child, recreated every mission) always receives the current build.

---

## Acceptance Criteria

*From GDD `design/gdd/hero-skill-build.md`, scoped to this story:*

- [x] AC-11 — any single active-slot change (reassign, clear, swap) triggers same-frame recompute and re-emission of `ultimate_skill_changed`, even if the new value equals the previous one; the previous Ultimate's cooldown is discarded
- [x] AC-12 — Hero System sets its U-slot binding verbatim from the received `ultimate_id` and never independently recomputes a category profile or shape

---

## Implementation Notes

*Derived from ADR-0030 Implementation Guidelines:*

- Any change to an active slot's `skill_id` (assignment, reassignment, clearing) triggers an immediate recompute of the category profile and re-emission of `ultimate_skill_changed` — per `hero.md`'s existing edge case ("the Ultimate recomputes immediately... any active Ultimate cooldown timer is discarded"). This GDD does not alter that behavior, only specifies what value gets computed.
- Hero Skill Build owns the derivation entirely; Hero System applies only. This avoids two systems needing to maintain the same derivation logic.
- `active_skill_equipped`/`ultimate_skill_changed` are re-emitted at `mission_launched` (subscribing to the same event Mission Select's retry flow re-fires, ADR-0028) so a freshly-instantiated Hero always receives the current build regardless of which scene most recently held Hero Skill Build's UI.
- Ultimate cooldown is defined by the Ultimate's own data entry (`hero.md` Rule 10), not derived from the category profile — deferred content-authoring work, out of scope for this story.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the derivation formulas themselves (this story covers the recompute trigger and ownership boundary, not the math)
- Hero System's own cooldown-tracking implementation (owned by `hero.md`, outside this epic)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-11**: Same-frame recompute, cooldown discarded
  - Given: an Ultimate is currently resolved (e.g. `elemental_ascendant`) and its cooldown is mid-countdown
  - When: any one of the 4 active slots is reassigned, cleared, or swapped
  - Then: category profile, shape, and `ultimate_id` recompute within the same frame; `ultimate_skill_changed(ultimate_id)` re-emits with the new value even if identical to the previous one; the previous Ultimate's cooldown timer is discarded

- **AC-12**: Hero applies, never re-derives
  - Given: `ultimate_skill_changed(ultimate_id)` is emitted
  - When: Hero System receives it
  - Then: Hero sets its U-slot binding to the received `ultimate_id` verbatim — confirmed by Hero's own code path containing no category-counting or shape-classification logic of its own

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/hero-skill-build/ultimate-recompute-ownership_test.gd` — must exist and pass

**Status**: [x] Created — `tests/integration/hero-skill-build/ultimate-recompute-ownership_test.gd` (6 tests, passing)

---

## Dependencies

- Depends on: Story 002 (Ultimate derivation formulas)
- Unlocks: None further within this epic — Hero System/Mission HUD downstream consumption (outside this epic)

**Unblocked**: ADR-0030 accepted 2026-07-18 (Sprint 6, S6-04).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 2/2 passing (6 integration tests, all passing).
**Deviations**: **Real cross-epic architecture conflict found and resolved, surfaced to user before implementing** (not silently decided given the size of the blast radius): `hero.gd` (Epic 02) already had its own Ultimate self-derivation mechanism (`_ultimate_lookup`/`_recompute_ultimate()`, TD-hero-002's MVP stopgap), directly forbidden by this ADR's Rule 9. User chose full migration — removed the old mechanism from `hero.gd` entirely, added `_on_ultimate_skill_changed()` (verbatim-apply subscriber), narrowed `_inject_skill_data()`'s signature, and rewrote ~20 tests in `tests/unit/hero/hero_skill_system_test.gd` to match the new ownership model. Code review (later, batch pass) confirmed no leftover re-derivation path remains in `hero.gd` and fixed one real bug this migration surfaced (Hero's Ultimate-activation no-op guard didn't recognize Hero Skill Build's "EMPTY" sentinel, causing a spurious error log — fixed, regression test added).
**Test Evidence**: Integration — `tests/integration/hero-skill-build/ultimate-recompute-ownership_test.gd`.
**Code Review**: Complete (batch review across Stories 001-007) — APPROVED WITH SUGGESTIONS, required fixes applied.
