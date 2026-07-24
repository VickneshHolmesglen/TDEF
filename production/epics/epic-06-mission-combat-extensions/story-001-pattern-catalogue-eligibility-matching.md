# Story 001: Pattern Catalogue & Eligibility Matching

> **Epic**: Epic 06 — Mission Combat Extensions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/constellation.md`
**Requirement**: `TR-const-001`, `TR-const-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0022 (Constellation Pattern-Detection Data Structure)
**ADR Decision Summary**: Detection runs per-event against a localized `Grid.get_occupied_cells_in_radius()` neighborhood, testing every catalogued shape/orientation for a valid, uniformly-tag-matched instance, canonicalizing the anchor to the lexicographically-smallest member cell.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Uses typed `Dictionary[K,V]` (4.4+, already verified working per `VERSION.md`). No new engine subsystem.

**Control Manifest Rules (this layer)**:
- Required: N/A — Feature Layer Rules in the current manifest (v2026-07-13b) only cover Wave Manager FSM and Projectile Pooling; Constellation/Tower Mastery predate this manifest revision. Follow ADR-0022 directly until the manifest is regenerated.
- Forbidden: Never call `Grid.get_all_occupied_cells()` on the hot recheck path (ADR-0022 Constraints, mirrors ADR-0005's Grid ownership rules).
- Guardrail: Grid read API is a documented direct-call exception (ADR-0020 Criterion A — read-only, high-frequency, sole-owner callee); array/Dictionary returns from Grid must be treated as copies per ADR-0005.

---

## Acceptance Criteria

*From GDD `design/gdd/constellation.md`, scoped to this story:*

- [ ] AC-1 — `triad_line` recognized at 0° (horizontal) orientation
- [ ] AC-2 — `triad_line` recognized at 45° (diagonal) orientation
- [ ] AC-3 — `l_corner` recognized in a mirrored orientation (not just a base rotation)
- [ ] AC-4 — `cross_plus` matches only its single valid orientation; a near-miss shape does not activate it
- [ ] AC-5 — Mismatched tags prevent activation despite complete shape geometry
- [ ] AC-6 — Empty eligibility tag excludes a tower from any pattern
- [ ] AC-28 — Canonicalization prevents duplicate `pattern_id` for one physical cluster regardless of read order

---

## Implementation Notes

*Derived from ADR-0022 Implementation Guidelines:*

- Maintain a per-tower tag cache: `_tag_cache: Dictionary[int, String]` populated from `tower_placed` payloads (`constellation_eligibility_tag` field, already added to `event-bus.md` 2026-07-17 — GDD's own OQ-4 is resolved), cleared on `tower_removed`/`tower_destroyed`.
- For every catalogued shape (`triad_line`, `quad_line`, `l_corner`, `cross_plus`) and every orientation (4 for line/corner shapes, 8 for `l_corner`'s rotations×mirrors, 1 for `cross_plus`), test whether the just-changed cell completes a valid instance anchored somewhere within the queried neighborhood.
- Eligibility check: every cell in the candidate shape must be occupied by a tower with a non-empty `constellation_eligibility_tag`, and all N tags must be identical.
- Canonicalize the anchor as the lexicographically smallest `Vector2i` in the shape's cell set (lowest row, then lowest column) — this must produce the same `pattern_id` regardless of which endpoint of a symmetric shape triggered the recheck (AC-28).
- `ConstellationInstance` is a plain `RefCounted` (not a `Resource`) per ADR-0016's precedent for mission-scoped runtime state — fields: `shape_id`, `anchor_cell`, `member_cells`, `member_tower_ids`, `bonus_type`, `bonus_value`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `constellation_activated` emission timing/synchronicity guarantees
- Story 003: deactivation and overlap/stacking behavior
- Story 005: localized search-radius performance bound (Formula 2, AC-17/AC-30)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode (`production/review-mode.txt`). Test cases below authored directly from the GDD's own Given/When/Then ACs, reused verbatim per this project's established lean-mode convention.*

- **AC-1**: `triad_line` recognized at 0°
  - Given: eligible towers tagged `"solar"` occupy `(2,4)`, `(3,4)`, `(4,4)`, no other shape coincidentally satisfied
  - When: the third tower's `tower_placed` fires
  - Then: `constellation_activated("triad_line@(2,4)", (2,4), bonus_type, 0.100)` emits exactly once
  - Edge cases: verify no duplicate emission if a later unrelated placement triggers another recheck

- **AC-2**: `triad_line` recognized at 45°
  - Given: eligible towers tagged `"solar"` occupy `(2,4)`, `(3,5)`, `(4,6)`
  - When: the third tower's `tower_placed` fires
  - Then: `constellation_activated` emits with `pattern_id = "triad_line@(2,4)"`

- **AC-3**: `l_corner` mirrored orientation
  - Given: eligible towers tagged `"solar"` occupy `(5,5)`, `(5,6)`, `(5,7)`, `(4,5)` (mirrored L)
  - When: the fourth tower's `tower_placed` fires
  - Then: `constellation_activated` emits with `pattern_id = "l_corner@(4,5)"`
  - Edge cases: confirm all 8 orientations (4 rotations × 2 mirrors) are matched, not only the 4 base rotations

- **AC-4**: `cross_plus` single valid orientation, near-miss rejected
  - Given: eligible towers occupy center `(6,6)` + N/E/S `(6,5)`,`(7,6)`,`(6,7)`, W `(5,6)` empty
  - When: any of the 4 `tower_placed` events fires
  - Then: no `constellation_activated` for `cross_plus`
  - Edge cases: placing the 5th tower at `(5,6)` must then emit `constellation_activated("cross_plus@(5,6)", ...)` exactly once

- **AC-5**: Mismatched tags block activation
  - Given: `(2,4)`,`(3,4)`,`(4,4)` tagged `"solar"`,`"solar"`,`"lunar"` (complete geometry, non-uniform tags)
  - When: third tower's `tower_placed` fires
  - Then: no `constellation_activated` for that cell set

- **AC-6**: Empty tag excludes tower
  - Given: `(2,4)`,`(3,4)` tagged `"solar"`, `(4,4)` tagged `""`
  - When: third tower's `tower_placed` fires
  - Then: no `constellation_activated` emitted

- **AC-28**: Canonicalization independent of read order
  - Given: a 3-cell line `(4,4)`,`(4,5)`,`(4,6)`
  - When: completing tower placed at `(4,4)` in one run, and separately at `(4,6)` in a second run
  - Then: both runs produce identical canonical `pattern_id = "triad_line@(4,4)"`, never `"triad_line@(4,6)"`, never two separate events for the same physical cluster

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/constellation/pattern-catalogue-eligibility-matching_test.gd` — must exist and pass

**Status**: [x] Complete — live-verified via gdUnit4 (2026-07-18, Sprint 6 S6-08)

---

## Dependencies

- Depends on: None (foundational story for this system)
- Unlocks: Story 002, Story 003, Story 006

**Unblocked**: ADR-0022 accepted 2026-07-18 (Sprint 6, S6-02).
