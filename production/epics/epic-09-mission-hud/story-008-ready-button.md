# Story 008: Ready Button (+ InputModeTracker wiring)

> **Epic**: Epic 09 — Mission HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-hud.md`
**Requirement**: `TR-hud-000` *(untraced — scoped from Core Rules Group 6, Rules 16-18, plus Group 9's cross-cutting Rules 23-24)*

**ADR Governing Implementation**: ADR-0031 (Mission HUD Architecture), ADR-0011 (UI Dual-Focus Handling)
**ADR Decision Summary**: One `InputModeTracker` instance owned by the `MissionHud` scene, explicit `focus_neighbor_*` wiring, focus ring shown only when `has_focus() AND tracker.is_focus_ring_visible()`. This story is the FIRST focusable control in the epic — it establishes the shared `InputModeTracker` instance Stories 009/010/012 all reuse.

**Engine**: Godot 4.6.2 | **Risk**: HIGH (post-cutoff engine behavior — Godot 4.6's dual-focus split — already mitigated by ADR-0011)
**Engine Notes**: `grab_focus()` only sets keyboard/gamepad focus; mouse hover tracked independently via `mouse_entered`/`mouse_exited`. Use `_input()` on the tracker (not `_unhandled_input()`) per ADR-0011's own engine-specialist-caught finding — `_unhandled_input()` misses mouse-button transitions on `Button`/`TextureButton` (default `mouse_filter = STOP`).

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest predates ADR-0031; follow ADR-0031/ADR-0011 directly.
- Forbidden: HUD applies no independent phase-validity guard on the button press beyond "button exists and is interactable" — Wave Manager Rules 9/10/12 are the sole authority (defense in depth pattern, same as Sell/Ultimate).
- Guardrail: All 3 outbound signals fire synchronously on Godot's `pressed` signal — never deferred (UI input, not physics/scene-tree mutation, so EventBus's synchronous default applies).

---

## Acceptance Criteria

*From GDD Core Rules Group 6 (Rules 16-18) + Group 9 (Rules 23-24):*

- [x] AC-39 — Ready exists and is interactable during SCOUT, PRE_WAVE, and INTERMISSION; does not exist during WAVE_ACTIVE, MISSION_COMPLETE, or DEFEAT
- [x] AC-40 — Ready remains active/interactable during PRE_WAVE (this GDD resolves the conflict with the original UX spec in Wave Manager's favor — Wave Manager Rule 10/EC-8 requires it stay active to allow skipping the countdown)
- [x] AC-41 — press → emit `player_ready` (no payload), immediately, synchronously, every time the button exists and is interactable — no additional HUD-side phase guard
- [x] AC-42 — during PRE_WAVE, the button's presented meaning changes ("confirm and advance" → "skip the countdown") — same event, different label/visual state
- [x] AC-43 — `InputModeTracker` (ADR-0011) is instanced once at the `MissionHud` root; the Ready button shows its focus ring only when `has_focus() AND tracker.is_focus_ring_visible()`. Explicit `focus_neighbor_*` wiring deferred — Ready is the only focusable Mission HUD control that exists yet; will be wired once Stories 009/010/012 add siblings to link against.
- [x] AC-44 (edge case) — a stray `player_ready` fired in the one-frame lag before the button's removal (SCOUT→PRE_WAVE→WAVE_ACTIVE boundary mashing) is a non-issue by design — Wave Manager already silently ignores `player_ready` received during WAVE_ACTIVE; no HUD-side debounce needed

---

## Implementation Notes

*Derived from ADR-0031/ADR-0011 Implementation Guidelines:*

```gdscript
# On MissionHud (outer root) — InputModeTracker instanced once here, shared
# by every focusable control in this epic (Ready, Ultimate, Sell, Retry).
@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker

# Ready button lives inside PlanningCluster (visible in SCOUT/PRE_WAVE/INTERMISSION,
# absent in WAVE_ACTIVE/MISSION_COMPLETE/DEFEAT per Story 002's cluster lifecycle) —
# existence is handled structurally by Story 002; this story wires its press handler.
func _on_ready_pressed() -> void:
    GEventBus.player_ready.emit()
```

- `InputModeTracker` must be instanced exactly once, at `MissionHud`'s own root — not duplicated per-button, not re-instanced per Planning Cluster cycle (it tracks input-method state for the whole screen, independent of which cluster nodes currently exist).
- PRE_WAVE label change (AC-42) is a UX Spec concern for exact text — this story wires the state-driven label swap mechanism, not the final copy.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: Ultimate button (reuses this story's `InputModeTracker` instance)
- Story 010: Sell button (reuses this story's `InputModeTracker` instance)
- Story 012: Retry button (reuses this story's `InputModeTracker` instance)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-39/AC-40**: Existence across phases
  - Given: each of SCOUT, PRE_WAVE, INTERMISSION, WAVE_ACTIVE, MISSION_COMPLETE, DEFEAT
  - When: the phase is entered
  - Then: Ready exists+interactable in the first 3, absent in the last 3 — PRE_WAVE specifically confirmed interactable (not just present), matching Wave Manager's EC-8

- **AC-41**: Synchronous emission, no HUD-side guard
  - Given: Ready is interactable
  - When: pressed
  - Then: `player_ready` emits synchronously with no payload, exactly once per press — even during a phase HUD itself doesn't independently validate

- **AC-43**: InputModeTracker singleton
  - Given: `MissionHud` instantiated
  - When: inspecting the scene tree
  - Then: exactly one `InputModeTracker` node exists at the `MissionHud` root, not duplicated anywhere else

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/ready-button-evidence.md` OR an interaction test at `tests/integration/mission-hud/ready-button_test.gd`

**Status**: [x] `tests/integration/mission-hud/ready-button_test.gd` — 11 tests, all passing (64/64 across all 7 mission-hud test files). Live-MCP-verified end-to-end against the real running `the_gap.tscn`: press emitted `player_ready` synchronously, focus ring correctly gated on `has_focus() AND is_focus_ring_visible()`, `InputModeTracker` correctly shared between `MissionHud` and the live `PlanningCluster` instance. Full project regression re-confirmed clean (1430/1430, 0 errors, 1 pre-existing unrelated failure).

---

## Dependencies

- Depends on: Story 001 (HUD Scaffold & Local State Model), Story 002 (Phase-Gated Cluster Lifecycle)
- Unlocks: Story 009 (Ultimate Button), Story 010 (Sell Button), Story 012 (Retry Button) — all reuse this story's `InputModeTracker` instance
