# Story 004: Blocked-Cell Highlight (PC-2)

> **Epic**: Epic 09 — Mission HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-hud.md`
**Requirement**: `TR-hud-002` — "On tower_placement_blocked, distinguish primary_blocking_cell sentinel (-1,-1) uniform-highlight case from single-cell case"

**ADR Governing Implementation**: ADR-0031 (Mission HUD Architecture)
**ADR Decision Summary**: Pure EventBus consumer, no direct Autoload call — Planning-Cluster-owned per the same subscription-ownership reasoning as Story 003's `path_invalidated`.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: None.

**Control Manifest Rules (this layer)**:
- Required: N/A.
- Forbidden: None additional beyond the universal cross-system-reference ban.
- Guardrail: No additional phase guard is needed — `tower_placement_blocked` can only fire during SCOUT/INTERMISSION (enforced upstream by Tower/Pathfinding).

---

## Acceptance Criteria

*From GDD Core Rules Group 4 (Rule 12) + Confirmed Signal Contract PC-2:*

- [x] AC-19 — on `tower_placement_blocked(blocked_cells, primary_blocking_cell)`: highlight `blocked_cells` to indicate the rejected footprint
- [x] AC-20 — if `primary_blocking_cell != Vector2i(-1, -1)`: highlight `primary_blocking_cell` distinctively (brighter/pulsing), anchoring attention to the specific load-bearing constraint cell
- [x] AC-21 — if `primary_blocking_cell == Vector2i(-1, -1)`: highlight all `blocked_cells` uniformly — no single cell is individually load-bearing
- [x] AC-22 — no phase guard implemented — the story trusts upstream enforcement, matching Rule 12's explicit "no additional guard needed" text

---

## Implementation Notes

*Derived from ADR-0031/GDD Implementation Guidelines:*

- Lives inside `PlanningCluster` (Story 002's scaffold), subscribed in its own `_ready()`.
- Two distinct visual treatments (uniform vs. primary-anchored) must be driven by the same event, branching only on the sentinel check — do not implement as two separate code paths that could drift apart; a single render function with an `if primary_blocking_cell != Vector2i(-1,-1)` branch.
- Exact color/pulse treatment is a UX Spec concern (`design/ux/mission-hud.md`) — this story implements the mechanism, not the final visual polish.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: `path_invalidated`/route-preview (separate subscription, separate visual, though both live in the same Planning Cluster)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-20/AC-21**: Sentinel branching
  - Given: `tower_placement_blocked(blocked_cells=[A,B,C], primary_blocking_cell=B)`
  - When: received
  - Then: B receives the distinct treatment, A/C receive the uniform treatment
  - Edge cases: `primary_blocking_cell=Vector2i(-1,-1)` → all of A/B/C receive uniform treatment, none receives the distinct one

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/mission-hud/blocked-cell-highlight_test.gd` — must exist and pass

**Status**: [x] Created — `tests/integration/mission-hud/blocked-cell-highlight_test.gd` (4 tests, passing)

---

## Dependencies

- Depends on: Story 002 (Phase-Gated Cluster Lifecycle)
- Unlocks: None further within this epic

---

## Completion Notes
**Completed**: 2026-07-20
**Criteria**: 4/4 passing (4 integration tests, all passing; live-MCP-verified end-to-end against the real running `the_gap.tscn` — a 2-cell `tower_placement_blocked` emission correctly produced 1 primary + 1 uniform marker, zero errors).
**Deviations**:
- `Grid`'s cell size has no public getter — used a local `CELL_SIZE_PX: float = 64.0` constant, citing `mission-select.md`'s own OQ-4 resolution (cell_size is a fixed project-wide constant, registered in `entities.yaml`) rather than a fresh arbitrary hardcode.
- Markers store their `cell`/`is_primary` state via `set_meta()` for test introspection — a lightweight approach matching this story's own "mechanism, not final visual polish" scope (exact color/pulse treatment is `design/ux/mission-hud.md`'s job).
- Same child-clearing pattern already established by Story 003 (synchronous `remove_child()` before `queue_free()`) applied here from the start — no repeat of that bug this time.
**Test Evidence**: Integration — `tests/integration/mission-hud/blocked-cell-highlight_test.gd`.
**Code Review**: Pending — deferred to a batch pass at a later Mission HUD checkpoint.
