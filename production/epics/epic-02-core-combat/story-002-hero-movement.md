# Story 002: Hero Movement & Position Tracking

> **Epic**: Core Combat Engine
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-05-16
> **Estimate**: 3–4 hours

## Context

**GDD**: `design/gdd/hero.md`
**Requirement**: `TR-hero-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Hero Tower-Synced Class + Tower Affinity
**ADR Decision Summary**: Hero calls `Grid.world_to_cell(global_position)` each physics frame to track grid cell. `hero_position_changed(grid_position: Vector2i)` emits via EventBus only when the hero crosses a cell boundary (not every frame). No acceleration curve at MVP — instantaneous velocity.

**Engine**: Godot 4.6.2 | **Risk**: HIGH
**Engine Notes**: `CharacterBody2D.move_and_slide()` API unchanged 4.4–4.6. `Grid.world_to_cell()` uses `floor()` per ADR-0005 — this is the correct rounding for cell snapping. 2D Area2D collision (attack hitbox) unchanged through 4.6. Physics callers must use `call_deferred` for any EventBus emissions from `_physics_process`.

**Control Manifest Rules (Core layer)**:
- Required: `hero_position_changed` emitted via `EventBus.hero_position_changed.emit.call_deferred(cell)` — physics caller
- Required: `Grid.world_to_cell()` is the only spatial conversion used — no custom floor/rounding
- Forbidden: Hero modifying Grid cell walkability — hero does not block monster paths
- Guardrail: `_physics_process` position tracking: O(1) prev_cell guard — no per-frame EventBus emission

---

## Acceptance Criteria

*From `design/gdd/hero.md`, scoped to this story:*

- [ ] Rule 26: Hero moves omnidirectionally. `velocity = direction.normalized() × move_speed` (instantaneous — no acceleration curve). Keyboard/Mouse primary; gamepad supported.
- [ ] Rule 27: Hero is blocked by BLOCKED cells and tower-occupied cells. Hero traverses PATH, PLACEABLE (empty), SPAWN, and GOAL cells freely.
- [ ] Rule 28: Each physics frame, `Grid.world_to_cell(global_position)` determines current cell. When cell changes vs. previous frame, `hero_position_changed(grid_position: Vector2i)` is emitted via EventBus (deferred — physics caller).
- [ ] AC-14 `[Visual]`: GIVEN the hero stands on a GOAL cell with no monsters present, WHEN the hero occupies that cell continuously, THEN the breach counter remains unchanged — a debug overlay confirms no `monster_breached` event fired from the hero's presence.

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines and hero.md Rules 26–28:*

```gdscript
var _prev_cell: Vector2i = Vector2i(-1, -1)

func _physics_process(delta: float) -> void:
    _handle_movement(delta)
    _update_position_tracking()

func _handle_movement(delta: float) -> void:
    var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = dir.normalized() * get_effective_stat(&"move_speed")
    move_and_slide()

func _update_position_tracking() -> void:
    var current_cell := Grid.world_to_cell(global_position)
    if current_cell != _prev_cell:
        _prev_cell = current_cell
        EventBus.hero_position_changed.emit.call_deferred(current_cell)
```

The `move_and_slide()` call naturally handles collision with `BLOCKED` cells and towers, assuming the tilemap/collision layer is configured to match Grid cell types. Hero uses collision layer 2 (hero), mask layer 1 (environment + towers).

**AC-14 (visual evidence)**: The hero scene root must NOT have an `Area2D` or body_entered handler that emits `monster_breached`. Only the Monster system's `_on_goal_cell_entered` callback may emit `monster_breached`. The debug overlay requirement is a manual QA check — confirmed in evidence doc.

---

## Out of Scope

- **Story 001**: `get_effective_stat(&"move_speed")` — stat formula implementation
- **Story 006**: Class proximity accumulation (uses hero cell from `hero_position_changed`)
- Input rebinding / gamepad axis configuration — deferred to Polish phase

---

## QA Test Cases

- **Rule 26**: Movement velocity
  - Given: Hero with `move_speed = 200.0`, directional input (right)
  - When: `_physics_process(0.016)` runs
  - Then: `velocity.x ≈ 200.0`, `velocity.y = 0.0` (normalized single-axis)
  - Edge cases: Diagonal input: `velocity.length() ≈ 200.0` (normalized, not 200×√2)

- **Rule 27**: Collision with BLOCKED cells
  - Given: Hero positioned adjacent to a BLOCKED cell
  - When: Input drives hero toward the blocked cell
  - Then: Hero stops at the cell boundary — does not enter the BLOCKED cell
  - Edge cases: Tower-occupied PLACEABLE cell also blocks movement

- **Rule 28**: Cell boundary emission
  - Given: Hero at cell (5, 5); `_prev_cell = Vector2i(5, 5)`
  - When: Hero moves to cell (6, 5) in next frame
  - Then: `hero_position_changed` fires once with `Vector2i(6, 5)`
  - Edge cases: Sub-cell movement within same cell — NO emission; hero returns to same cell next frame after going over boundary — emission on change, not on count

- **AC-14** (manual evidence check):
  - Setup: Place hero on any GOAL cell; ensure no monsters are present
  - Verify: Monitor `monster_breached` signal for 5 seconds while hero stands on GOAL cell
  - Pass condition: Zero `monster_breached` events fired; debug overlay confirms counter unchanged

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/hero/hero_movement_test.gd` — must exist and pass
- `production/qa/evidence/hero-goal-cell-evidence.md` — AC-14 visual sign-off (ADVISORY)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (stat resolution — `get_effective_stat(&"move_speed")` must exist)
- Unlocks: Story 006 (class proximity uses `hero_position_changed`)

## Completion Notes
**Completed**: 2026-07-03
**Criteria**: 4/4 passing (Rule 26, Rule 27, Rule 28, AC-14). 11/11 automated tests passing, 0 errors, 0 failures, 0 orphans.
**Deviations**: Advisory only — manual debug-overlay evidence doc deferred (explicitly ADVISORY per story's own Test Evidence section); new collision-layer convention (layer 1=environment, layer 2=hero) established and documented in a code comment, logged as TD-adr-002 recommending a formal ADR before S4-09 depends on it; `_process()`/`_physics_process()` split follows control-manifest/ADR-0002 over the story's simplified code sketch (higher-authority source, not a real deviation).
**Test Evidence**: Integration — `tests/integration/hero/hero_movement_test.gd` (11 tests, all passing)
**Code Review**: Complete — 1 Required Change found and fixed (`_process()` itself was untested — all prior tests bypassed the real `Input.get_vector()` polling path). Re-reviewed, verdict APPROVED.
