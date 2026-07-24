# Story 003: Route-Preview Overlay (PC-1)

> **Epic**: Epic 09 — Mission HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-hud.md`
**Requirement**: `TR-hud-001` — "On path_invalidated, call get_path() to re-derive route — never render affected_cells directly as a route line"

**ADR Governing Implementation**: ADR-0031 (Mission HUD Architecture)
**ADR Decision Summary**: `Pathfinding.get_path()` is classified ADR-0020 Criterion A (read-only direct Autoload call) — one of exactly 3 non-EventBus calls this system makes.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: None beyond ADR-0031's general Engine Compatibility notes.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest predates ADR-0031.
- Forbidden: Never render `affected_cells` (the `path_invalidated` payload) directly as a route line — it is the union of changed-walkability cells (a tower's footprint), not a path.
- Guardrail: Never re-render during WAVE_ACTIVE.

---

## Acceptance Criteria

*From GDD Core Rules Group 3 (Rules 9-11) + Confirmed Signal Contract PC-1:*

- [x] AC-13 — on `templates_ready` (subscribed independently of Wave Manager's own gate on the same event): call `PathfindingSystem.get_path(spawn_cell, 0)` once per spawn cell and render the initial route-preview overlay, before any tower is placed
- [x] AC-14 — on `path_invalidated`: call `get_path()` to obtain the updated route and re-render — never render `affected_cells` as the route itself
- [x] AC-15 — on `mission_phase_changed → WAVE_ACTIVE`: the overlay is removed entirely (handled structurally by Story 002's Planning Cluster teardown — this story only needs confirm the overlay node lives inside the Planning Cluster, not the outer root)
- [x] AC-16 — on `mission_phase_changed → INTERMISSION`: the overlay reappears showing the last-known route; it only actually changes if a `path_invalidated` arrives
- [x] AC-17 — if `path_invalidated` is received during WAVE_ACTIVE (should be structurally impossible per Wave Manager's rebuild-pending gate): discard without re-rendering, defensive
- [x] AC-18 — if `path_invalidated` arrives during PRE_WAVE: treat identically to INTERMISSION (re-render on receipt) — the overlay is still visible (non-interactive) during PRE_WAVE

---

## Implementation Notes

*Derived from ADR-0031/GDD Implementation Guidelines:*

- Lives inside `PlanningCluster` (Story 002's scaffold) — its own `_ready()`/`_exit_tree()` connect/disconnect `path_invalidated`. The `templates_ready` boot-race subscription (AC-13) lives on the outer `MissionHud` root instead (matching Rule 11a's precedent for `wave_preview_available` — it must be reliable across every cluster re-instantiation, not just the first).
- Boot-race fallback (GDD Edge Cases): if `templates_ready` fires before Mission HUD's `_ready()` finishes connecting, the mount handler additionally polls `PathfindingSystem` for already-ready templates as a fallback.
- The initial render (AC-13) happens once per mission (bound to `templates_ready`, which fires once); subsequent re-renders (AC-14) happen per `path_invalidated`, of which there may be many per SCOUT phase as the player places towers.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the Planning Cluster instantiate/teardown mechanism itself
- Story 004: PC-2 blocked-cell highlight (separate subscription, separate visual)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-14**: Re-render uses get_path(), never affected_cells
  - Given: an active route-preview overlay
  - When: `path_invalidated(affected_cells=[Vector2i(3,3)])` fires
  - Then: `PathfindingSystem.get_path()` is called and its return value drives the re-render — `affected_cells` itself is never passed to the overlay renderer

- **AC-17**: WAVE_ACTIVE discard
  - Given: `phase == WAVE_ACTIVE`
  - When: `path_invalidated` somehow fires
  - Then: discarded, no re-render, no crash

- **AC-13**: Boot-race fallback
  - Given: `templates_ready` fires before `MissionHud._ready()` completes subscription setup
  - When: the mount handler runs
  - Then: it polls `PathfindingSystem` directly and still renders the initial overlay

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/mission-hud/route-preview-overlay_test.gd` — must exist and pass

**Status**: [x] Created — `tests/integration/mission-hud/route-preview-overlay_test.gd` (6 tests, passing)

---

## Dependencies

- Depends on: Story 002 (Phase-Gated Cluster Lifecycle)
- Unlocks: None further within this epic

---

## Completion Notes
**Completed**: 2026-07-20
**Criteria**: 6/6 passing (6 integration tests, all passing; live-MCP-verified end-to-end against the real running `the_gap.tscn` — a genuine 29-cell SPAWN→GOAL route rendered as 1 `Line2D`, zero errors).
**Deviations**:
- **Real API naming drift found and used correctly, not the GDD's loose prose**: the GDD text says `PathfindingSystem.get_path(spawn_cell, 0)` — the actual shipped method is `PathfindingSystem.find_path(from_cell: Vector2i, tier: int) -> Array[Vector2i]`. Used the real name throughout, matching this project's own established "GDD prose vs. shipped API" precedent (documented repeatedly across other epics this session).
- **New small public method added to `PathfindingSystem`**: `is_templates_ready() -> bool` (read-only, ADR-0020 Criterion A) — needed for the boot-race fallback (GDD Edge Cases: `templates_ready` firing before Mission HUD finishes connecting its own subscription). No existing public accessor exposed the private `_templates_built` flag; `find_path()` itself isn't usable as a silent readiness probe since it `push_error()`s when templates aren't built yet.
- **New outer-root state field, not in the GDD's original Rule 4 list**: `_last_known_routes: Array` — needed so INTERMISSION's "reappear with the last-known route" (Rule 11) survives Planning Cluster re-instantiation, the same architectural pattern Rule 4's `_boss_telegraph_cell` already established (Story 006 will add that field's own consumer). Deliberately NOT cleared by `_reset_local_state()` — a real ordering bug was caught and fixed during implementation: clearing it at SCOUT mount would have silently discarded exactly the data the boot-race fallback exists to preserve, since the fallback can populate it before the mount handler ever runs.
- **Real bug caught and fixed before it shipped**: `PlanningCluster.render_route()`'s child-clearing used `queue_free()` alone — the identical double-connected/stale-state bug class ADR-0031's own engine-specialist review had already caught in the Planning Cluster swap sequence, just recurring in a second location. Caught by this story's own test suite (a `path_invalidated` re-render within the same frame left 3 stale children instead of 1). Fixed to synchronous `remove_child()` then `queue_free()`, matching the established pattern.
**Test Evidence**: Integration — `tests/integration/mission-hud/route-preview-overlay_test.gd`.
**Code Review**: Pending — deferred to a batch pass at a later Mission HUD checkpoint.
