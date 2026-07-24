# Story 010: Sell Button

> **Epic**: Epic 09 — Mission HUD
> **Status**: Complete — verified during Story 011's mission-hud suite run (98/98 passing) and reconfirmed via Story 012's full regression (1470/1470, 0 errors, 1 pre-existing unrelated failure)
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-hud.md`
**Requirement**: `TR-hud-000` *(untraced — scoped from Core Rules Group 8, Rules 21-22)*

**ADR Governing Implementation**: ADR-0031 (Mission HUD Architecture), ADR-0011 (UI Dual-Focus Handling)
**ADR Decision Summary**: Reuses Story 008's single `InputModeTracker` instance. Lives in `PlanningCluster` (Story 002) — phase-gated existence, requires a currently-inspected tower.

**Engine**: Godot 4.6.2 | **Risk**: HIGH (same ADR-0011 dual-focus mitigation as Story 008)
**Engine Notes**: None beyond Story 008's own.

**Control Manifest Rules (this layer)**:
- Required: N/A.
- Forbidden: HUD does not remove the tower visually or adjust any counter until Tower System's confirming `tower_removed` event arrives — no optimistic removal beyond clearing the Info Panel selection.
- Guardrail: Multiple concurrent sell requests (different `tower_id`s) are structurally fine — Tower System's confirmation handling must key strictly off `tower_id`, never a global "sell in progress" flag (this story's own responsibility is only to emit correctly per press, not to guard against this).

---

## Acceptance Criteria

*From GDD Core Rules Group 8 (Rules 21-22):*

- [x] AC-52 — Sell button exists only when `phase in {SCOUT, INTERMISSION}` AND a tower is currently selected/inspected in the Tower Info Panel; does not exist in PRE_WAVE, WAVE_ACTIVE, MISSION_COMPLETE, or DEFEAT (WAVE_ACTIVE/MISSION_COMPLETE/DEFEAT already structurally satisfied — Planning Cluster itself doesn't exist then)
- [x] AC-53 — press → emit `tower_sell_requested(tower_id: int)` for the currently-inspected tower, immediately, synchronously
- [x] AC-54 — HUD clears the Info Panel selection optimistically but does NOT remove the tower visually or adjust any counter until `tower_removed` arrives (this story never touches rendering/counters at all — only its own `_inspected_tower_id`)
- [x] AC-55 (edge case) — if two different towers are sold before either's `tower_removed` confirms: both `tower_sell_requested` calls (different `tower_id`s) are in flight simultaneously — this is fine; no HUD-side "one sell at a time" guard
- [x] AC-56 (edge case) — if `tower_sell_requested` is rejected or its confirming `tower_removed` never arrives: accepted as a rare, acceptable-loss edge case — Info Panel stays optimistically cleared, no timeout/error-recovery path required for this story

---

## Implementation Notes

*Derived from ADR-0031/GDD Implementation Guidelines:*

```gdscript
# Inside PlanningCluster (Story 002's scaffold)
var _inspected_tower_id: int = -1  # -1 = no tower currently inspected

func _update_sell_button_existence() -> void:
    var phase_ok: bool = _current_phase in ["SCOUT", "INTERMISSION"]
    _sell_button.visible = phase_ok and _inspected_tower_id != -1

func _on_sell_pressed() -> void:
    GEventBus.tower_sell_requested.emit(_inspected_tower_id)
    _inspected_tower_id = -1  # AC-54 — clear selection optimistically, nothing else
    _update_sell_button_existence()
```

- The "currently-inspected tower" selection state (Tower Info Panel) is shared UI state this story reads but does not own the full lifecycle of — this story's scope is the Sell button's own existence/press contract, not the Info Panel's complete design (assumed to exist as part of Planning Cluster's Tower Build Panel work, tracked separately if it needs its own story).
- Reuses `InputModeTracker` from Story 008.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The full Tower Info Panel / Tower Build Panel UI (selection mechanics, panel layout) — this story only wires the Sell button's existence-gate and press-emit contract against an assumed `_inspected_tower_id` state

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-52**: Existence gate
  - Given: `phase == SCOUT`, no tower inspected
  - When: checking Sell button existence
  - Then: not visible
  - Edge cases: `phase == SCOUT` + a tower inspected → visible; `phase == PRE_WAVE` + a tower inspected → not visible (phase excludes it regardless of selection)

- **AC-53/AC-54**: Press behavior
  - Given: tower_id=7 currently inspected, Sell visible
  - When: pressed
  - Then: `tower_sell_requested(7)` emits synchronously; Info Panel selection clears immediately; the tower itself remains rendered on the grid and no counter changes until a separate `tower_removed(7)` arrives

- **AC-55**: Concurrent sells
  - Given: tower A sold, `tower_removed` for A not yet arrived
  - When: tower B (different id) is inspected and sold
  - Then: both `tower_sell_requested` calls fired successfully, no HUD-side rejection of the second

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/sell-button-evidence.md` OR an interaction test at `tests/integration/mission-hud/sell-button_test.gd`

**Status**: [x] `tests/integration/mission-hud/sell-button_test.gd` — 6 tests, all passing, confirmed as part of Story 011's mission-hud suite run and Story 012's full regression.

---

## Implementation Deviation Notes

- Moved the pre-existing `SellButtonPlaceholder` (Story 002's scaffold, previously a child of `NonReadyControls`) out to a `SellButton` sibling of `ReadyButton`/`NonReadyControls`, since AC-52 requires it to actually disappear (not just become non-interactive) during PRE_WAVE — `NonReadyControls`' group-level disable alone doesn't hide its children.
- `set_inspected_tower(tower_id: int)` added as the public seam the (not-yet-built) Tower Info Panel will call once it exists — this story only reads/holds that id, per its own Out of Scope note.

---

## Dependencies

- Depends on: Story 001 (HUD Scaffold & Local State Model), Story 002 (Phase-Gated Cluster Lifecycle), Story 008 (InputModeTracker instance)
- Unlocks: None further within this epic
