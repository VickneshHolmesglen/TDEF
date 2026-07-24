# Story 007: Proximity Radius & Accumulator Independence

> **Epic**: Epic 06 — Mission Combat Extensions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/tower-mastery.md`
**Requirement**: `TR-towermast-001`

**ADR Governing Implementation**: ADR-0029 (Tower Mastery Proximity-Detection Strategy)
**ADR Decision Summary**: `TOWER_MASTERY_PROXIMITY_RADIUS` is the exact same registered constant as Hero's `hero_class_proximity_radius_cells` (3 cells, Chebyshev) — not an independently-tuned value that happens to match. Tower Mastery maintains its own accumulator, entirely independent of Hero's Tower-Synced Class accumulator, even though both consume `hero_position_changed` and share the radius.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM (per ADR-0029's Engine Compatibility — live profiling of the per-frame accrual loop is still outstanding; this story covers the radius/independence contract only, not the profiling itself, see Story 012)
**Engine Notes**: Both systems must consume `Grid.get_occupied_cells_in_radius(center, radius)` (Chebyshev, O(1)) with zero new Grid API surface — no `get_occupied_cells_in_euclidean_radius()` is needed or permitted.

**Control Manifest Rules (this layer)**:
- Required: Read API is a documented direct-call exception to EventBus-only — source: ADR-0005 (`control-manifest.md` line 61).
- Forbidden: Never derive one system's progress from the other's (Rule 2) — two separate `Dictionary` structures, two separate thresholds, two separate EventBus emissions.
- Guardrail: `TOWER_MASTERY_PROXIMITY_RADIUS` must remain literally the same registered value as `hero_class_proximity_radius_cells` — no second registry entry, no divergence (Tuning Knobs).

---

## Acceptance Criteria

*From GDD `design/gdd/tower-mastery.md`, scoped to this story:*

- [ ] AC-01 — Same numeric constant and same distance metric as Hero's Tower-Synced Class radius (single source, not independently-tuned coincidence)
- [ ] AC-02 — Chebyshev metric confirmed (not Euclidean) via a boundary case where the two metrics diverge
- [ ] AC-03 — Only `Grid.get_occupied_cells_in_radius()` is invoked; no Euclidean-named Grid method exists as a dependency
- [ ] AC-04 — Hero's `proximity_time[tower_type]` and Tower Mastery's `mastery_time[build_signature]` are two independent dictionary entries, not one shared value
- [ ] AC-05 — Mutating one system's accumulator in isolation leaves the other completely unaffected (bidirectional)
- [ ] AC-06 — Hero's threshold firing at a different frame than Tower Mastery's threshold proves independently-tracked timers, not a shared gate

---

## Implementation Notes

*Derived from ADR-0029 Implementation Guidelines:*

- `TOWER_MASTERY_PROXIMITY_RADIUS` must read from the same registry constant as `hero_class_proximity_radius_cells` (`design/registry/entities.yaml`) — a test asserting `TOWER_MASTERY_PROXIMITY_RADIUS == hero_class_proximity_radius_cells` (same source, not just same literal) must pass.
- **Registry update flagged, not yet performed** (per `tower-mastery.md`'s Notes and Open Questions): `entities.yaml`'s `hero_class_proximity_radius_cells` entry needs Tower Mastery added to its `referenced_by` list. If skipped, each system could hardcode its own literal `3` and silently drift later — resolve before this story closes, not just before its own tests.
- Two fully separate `Dictionary` structures: Hero's `proximity_time[tower_type]` and Tower Mastery's `mastery_time[build_signature]`. Keyed differently (archetype vs. full 4-slot build signature) and feeding different EventBus emissions (`hero_class_unlocked` vs. `mastery_progress_updated`/`skill_unlocked`).
- No shared reference, no shared backing dictionary — implementors must not attempt to derive one system's progress from the other's, even though both subscribe to the same `hero_position_changed` signal.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: `build_signature` derivation and the event-payload extension it depends on
- Story 009: the cell-boundary-triggered recompute mechanics themselves (`_signatures_in_range`)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-01**: Single-source shared radius constant
  - Given: `hero_class_proximity_radius_cells = 3` (Chebyshev) at Hero System init
  - When: `TOWER_MASTERY_PROXIMITY_RADIUS` is read at Tower Mastery init
  - Then: value is exactly `3`, Chebyshev metric; a test asserting `TOWER_MASTERY_PROXIMITY_RADIUS == hero_class_proximity_radius_cells` (same registry constant) passes — two constants sharing only a literal value fails this AC

- **AC-02**: Chebyshev confirmed via divergent boundary case
  - Given: hero at `(5,5)`, tower at `(7,5)` (Cheb=2, Euclidean=2.0, both agree); second tower at `(5,8)` (Cheb=3, Euclidean=3.0, both agree); third tower at `(8,8)` (Cheb=3 in-range, Euclidean≈4.24 out-of-range)
  - When: both Tower Mastery and Hero's accumulator independently evaluate the third tower
  - Then: both report it in-range — proving Chebyshev, not Euclidean, is the metric actually used

- **AC-03**: No Euclidean Grid dependency
  - Given: Tower Mastery computes `signatures_in_range` for a `hero_position_changed` event
  - When: the call graph is inspected (static/dynamic trace of Grid API calls)
  - Then: only `Grid.get_occupied_cells_in_radius()` followed by `Grid.get_occupant()` is invoked; zero invocations of any Euclidean-named method

- **AC-04**: Independent dictionary entries
  - Given: hero stands within 3 Chebyshev cells of a single tower for 15 cumulative seconds during `WAVE_ACTIVE`, both accumulators subscribed to the same `hero_position_changed`
  - When: the 15 seconds elapse
  - Then: Hero's `proximity_time[tower_type]` reads `15.0` AND Tower Mastery's `mastery_time[build_signature]` independently reads `15.0` — two separate dictionary entries

- **AC-05**: Bidirectional mutation isolation
  - Given: the AC-04 setup
  - When: `mastery_time[build_signature]` is forcibly mutated (reset to `0.0` or advanced to `999.0`) without touching Hero's structures
  - Then: Hero's `proximity_time[tower_type]` is unaffected; and inverted, mutating Hero's structure leaves Tower Mastery's unaffected

- **AC-06**: Independently-tracked thresholds
  - Given: Hero's accumulator reaches its 30s `hero_class_unlocked` threshold the same physics frame Tower Mastery's (default 45s) `mastery_threshold_seconds` is still short
  - When: that frame resolves
  - Then: `hero_class_unlocked` fires AND `skill_unlocked` does NOT fire

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/tower-mastery/proximity-radius-accumulator-independence_test.gd` — must exist and pass

**Status**: [x] Complete — live-verified via gdUnit4 (2026-07-18, Sprint 6 S6-10)

---

## Dependencies

- Depends on: None (foundational story for this system, alongside Story 008)
- Unlocks: Story 009, Story 010

**Unblocked**: ADR-0029 accepted 2026-07-18 (Sprint 6, S6-02).
