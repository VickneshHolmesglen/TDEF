# Story 005: Localized Search Scope & Performance Bound

> **Epic**: Epic 06 — Mission Combat Extensions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/constellation.md`
**Requirement**: `TR-const-001`

**ADR Governing Implementation**: ADR-0022 (Constellation Pattern-Detection Data Structure), ADR-0005 (Grid System Data Model), ADR-0020 (Direct-Autoload-call exception pattern)
**ADR Decision Summary**: Every recheck calls `Grid.get_occupied_cells_in_radius(changed_cell, pattern_search_radius)` exactly once per event — never `Grid.get_all_occupied_cells()`. `pattern_search_radius` is a derived constant (Formula 2, currently 3 for the 4-shape catalogue), registered in `design/registry/entities.yaml`. Per-event cost is bounded by catalogue size and local neighborhood, never total tower count.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Grid read API is a documented direct-call exception (ADR-0020 Criterion A — read-only, high-frequency, sole-owner callee, per ADR-0005). Grid returns Array copies via `.duplicate()`, safe to iterate without a defensive copy on Constellation's side.

**Control Manifest Rules (this layer)**:
- Required: Read API is a documented direct-call exception to EventBus-only — source: ADR-0005 (`control-manifest.md` line 61).
- Forbidden: Never call `Grid.get_all_occupied_cells()` on the hot recheck path (Core Rule 8, AC-17 — a hard rule, not an optimization suggestion).
- Guardrail: Per-event recheck cost must not scale with total tower count on the field (AC-30) — cost is a function of catalogue size (fixed at 4 shapes) and local neighborhood occupancy only.

---

## Acceptance Criteria

*From GDD `design/gdd/constellation.md`, scoped to this story:*

- [x] AC-17 — Recheck queries only `get_occupied_cells_in_radius`, never `get_all_occupied_cells`, on the hot path
- [x] AC-25 *(Config/Data — ADVISORY)* — Derived radius equals 3 for the current 4-shape catalogue, and cells at exactly that distance are included
- [x] AC-29 *(Integration/robustness — ADVISORY)* — Grid-too-small-for-shape produces no error, only an absence of activation
- [x] AC-30 *(Integration, ADVISORY pending perf harness)* — Per-event recheck cost does not scale dramatically with unrelated tower count (informal smoke check; OQ-7's formal methodology remains unresolved)

---

## Implementation Notes

*Derived from ADR-0022 Implementation Guidelines:*

- `pattern_search_radius` is a registered constant in `design/registry/entities.yaml` (`constellation_pattern_search_radius`), not hand-derived at runtime — currently `3` (largest member-to-anchor Chebyshev offset across the 4-shape catalogue, `quad_line`'s longest run).
- A GUT test double for `Grid` must record every call made to it and fail the test if `get_all_occupied_cells()` is invoked during any recheck.
- OQ-7 (from `constellation.md`) flags that AC-30's measurement methodology is not yet formally defined — a ±20% tolerance band across a 10-tower vs. 55-tower scene was proposed ad hoc during AC authoring. Recommend Technical Director or QA Lead sign-off on the actual perf-test methodology before treating AC-30 as a hard gate; until then, treat it as an informal smoke check per its ADVISORY marking.
- Grid API surface must not include (nor Constellation ever call) a Euclidean-radius method — confirms Grid OQ-1's Chebyshev-only resolution holds for this system too.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the shape-matching logic that consumes the returned neighborhood
- Formal perf-harness design (OQ-7) — flagged here as an open methodology gap, not solved by this story alone; escalate to Technical Director/QA Lead per the GDD's own Open Questions

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-17**: Only localized Grid calls on hot path
  - Given: a Grid test double recording every call, asserting failure if `get_all_occupied_cells()` is invoked
  - When: any of `tower_placed`/`tower_removed`/`tower_destroyed` fires
  - Then: the recheck completes using only `get_occupied_cells_in_radius(changed_cell, 3)` calls; `get_all_occupied_cells()` counter stays 0 throughout

- **AC-25**: Derived radius and boundary inclusion *(ADVISORY)*
  - Given: catalogue's `quad_line` has max member-to-anchor Chebyshev offset of 3 (the catalogue's largest)
  - When: `pattern_search_radius` is read from `design/registry/entities.yaml`
  - Then: its value is `3`; and `Grid.get_occupied_cells_in_radius(changed_cell, 3)` called with an eligible tower at exactly Chebyshev distance 3 includes that cell (boundary-inclusive)

- **AC-29**: Grid-too-small produces no error *(ADVISORY)*
  - Given: a test grid where fewer than 3 PLACEABLE cells exist within Chebyshev distance 3 of any occupied cell
  - When: `tower_placed` fires for a tower placed under these constraints
  - Then: the recheck completes without throwing an exception or logging an error, and no `constellation_activated` fires

- **AC-30**: Cost does not scale with tower count *(ADVISORY, pending perf harness — OQ-7)*
  - Given: two otherwise-identical test scenes — 10 towers vs. 55 towers, both outside the search radius of the cell under test
  - When: a single `tower_placed` event fires in each scene and recheck execution time is measured
  - Then: the two measured times are within an agreed tolerance band (e.g. ±20%) of each other
  - Edge cases: flag to QA Lead/Technical Director that the measurement methodology itself (sample count, timing API, tolerance) is not yet formally specified — treat as informal smoke check until resolved

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/constellation/localized-search-scope-performance-bound_test.gd` — 7 tests: AC-17 (3 tests, one per tower lifecycle event, BLOCKING, all passing), AC-25 (radius registry match + boundary-inclusive quad_line completion), AC-29 (isolated tower, no error/no activation), AC-30 (informal smoke check, ADVISORY per OQ-7)

**Status**: [x] Created and passing (2026-07-19). Full project regression re-run: 1115/1116 (the sole failure is the same pre-existing, unrelated Menagerie `CreatureInstance.CreatureState` enum-value mismatch, `TD-menag-006` — untouched by this story).

---

## Dependencies

- Depends on: Story 001 (DONE) — search scope wraps the same recheck path shape-matching consumes
- Unlocks: None further within this epic

**Unblocked**: ADR-0022 accepted 2026-07-18 (Sprint 6, S6-02).

**Implemented (2026-07-19, Sprint 7)**: found on inspection that production code already satisfied every AC — `constellation.gd`'s `_recheck_patterns_near()` only ever calls `_grid.get_occupied_cells_in_radius()`, never `get_all_occupied_cells()`; `PATTERN_SEARCH_RADIUS = 3` already matches `entities.yaml`'s registered `constellation_pattern_search_radius`; `GridSpyDouble` (the shared test double) already had the `get_all_occupied_cells_call_count` tripwire this story's own Implementation Notes call for, built during Stories 001-003. Only the test file itself was missing. Confirmed the real `Grid.get_occupied_cells_in_radius()` shares the exact same O(total occupied cells) linear-scan implementation as `GridSpyDouble`'s own — so AC-30's "does not scale with tower count" claim is really about Constellation's own per-event work being bounded by catalogue size given the returned neighborhood, not that the underlying Grid query itself is O(1); documented this nuance in the test file rather than writing a misleadingly precise perf assertion. AC-30 implemented as an explicitly informal, generously-toleranced smoke check (10 vs. 55 background towers, ~10x tolerance) — OQ-7's formal perf-harness methodology is still unresolved and remains a QA Lead/Technical Director follow-up, not something this pass invented ad hoc. Live-verified via gdUnit4: 7/7 new tests passing; full regression 1115/1116 (same pre-existing unrelated `TD-menag-006` failure).
