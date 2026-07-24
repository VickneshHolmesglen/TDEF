# Story 009: Ultimate Button

> **Epic**: Epic 09 — Mission HUD
> **Status**: Complete — verified during Story 011's mission-hud suite run (98/98 passing) and reconfirmed via Story 012's full regression (1470/1470, 0 errors, 1 pre-existing unrelated failure)
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-hud.md`
**Requirement**: `TR-hud-000` *(untraced — scoped from Core Rules Group 7, Rules 19-20)*

**ADR Governing Implementation**: ADR-0031 (Mission HUD Architecture), ADR-0011 (UI Dual-Focus Handling)
**ADR Decision Summary**: Reuses Story 008's single `InputModeTracker` instance. Lives in `CombatCluster` (Story 002) — exists in all phases, unlike the Planning Cluster's phase-gated buttons.

**Engine**: Godot 4.6.2 | **Risk**: HIGH (same ADR-0011 dual-focus mitigation as Story 008)
**Engine Notes**: None beyond Story 008's own.

**Control Manifest Rules (this layer)**:
- Required: N/A.
- Forbidden: HUD does not predict or locally reset the cooldown display on press — it waits for the next `hero_skill_cooldown_updated` tick, same as every other cooldown-driven element.
- Guardrail: While on cooldown, the button consumes no input and emits nothing.

---

## Acceptance Criteria

*From GDD Core Rules Group 7 (Rules 19-20):*

- [x] AC-45 — Ultimate button exists in ALL phases (unlike Ready/Sell, no phase-gated existence) — lives in CombatCluster, owned by MissionHud's own `_ready()`, never destroyed/recreated
- [x] AC-46 — interactable only when `cooldown_remaining == 0` for `skill_slot == Hero.ULTIMATE_SLOT_INDEX` (reserved index 4), read from `hero_skill_cooldown_updated`
- [x] AC-47 — while on cooldown: button consumes no input, emits nothing (fully disabled via `Button.disabled`, not just visually dimmed)
- [x] AC-48 — press (while interactable) → emit `hero_ultimate_activated` (no payload) immediately, synchronously
- [x] AC-49 — HUD does NOT predict or locally reset the cooldown display on press — waits for the next `hero_skill_cooldown_updated` tick
- [x] AC-50 (edge case) — `hero_skill_cooldown_updated` for `skill_slot` 0-3 (out-of-scope skill buttons 1-4) is received and discarded — Ultimate reads only slot 4, other slot updates route nowhere in this story
- [x] AC-51 (edge case) — a double-press before the confirming `hero_skill_cooldown_updated` returns applies no HUD-side debounce by design — Hero System is solely responsible for rejecting/ignoring a too-soon second activation

---

## Implementation Notes

*Derived from ADR-0031/GDD Implementation Guidelines:*

```gdscript
# On CombatCluster (persistent, Story 002's scaffold)
const ULTIMATE_SLOT_INDEX: int = 4  # Hero.ULTIMATE_SLOT_INDEX, reserved

func _on_hero_skill_cooldown_updated(skill_slot: int, cooldown_remaining: float) -> void:
    if skill_slot != ULTIMATE_SLOT_INDEX:
        return  # AC-50 — discard, not routed anywhere
    _ultimate_button.disabled = cooldown_remaining > 0.0

func _on_ultimate_pressed() -> void:
    GEventBus.hero_ultimate_activated.emit()
    # NO local cooldown reset here — AC-49
```

- Reuses `InputModeTracker` from Story 008 — no second instance.
- Uses `Control.disabled` (or equivalent) to fully block input, not just a visual dim — AC-47 requires zero input consumption while on cooldown, matching "the button consumes no input" literally.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: the actual cooldown-fill visual indicator shared with skill buttons 1-4 (out of scope for the whole epic per GDD's own explicit scope note) — this story only wires the button's interactable/emit contract

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-46/AC-47**: Cooldown gating
  - Given: `hero_skill_cooldown_updated(skill_slot=4, cooldown_remaining=3.0)`
  - When: the button is pressed while `cooldown_remaining > 0`
  - Then: no `hero_ultimate_activated` emitted, no input consumed
  - Edge cases: `cooldown_remaining=0.0` → interactable, press emits

- **AC-49**: No local prediction
  - Given: Ultimate is interactable
  - When: pressed
  - Then: the button's own interactable state does NOT change immediately — it remains interactable until the next `hero_skill_cooldown_updated` arrives (even if that update sets it back to on-cooldown)

- **AC-50**: Slot filtering
  - Given: `hero_skill_cooldown_updated(skill_slot=1, cooldown_remaining=0.0)`
  - When: received
  - Then: no effect on the Ultimate button's state whatsoever

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/ultimate-button-evidence.md` OR an interaction test at `tests/integration/mission-hud/ultimate-button_test.gd`

**Status**: [x] `tests/integration/mission-hud/ultimate-button_test.gd` — 7 tests, all passing, confirmed as part of Story 011's mission-hud suite run and Story 012's full regression. (Not independently live-MCP-verified — Story 011's live-MCP pass exercised the same `CombatCluster` scene structure without incident.)

---

## Implementation Deviation Notes

- The real `hero_skill_cooldown_updated` signal is `(skill_slot: int, cooldown_remaining: float, cooldown_max: float)` — 3 params, not the story's own pseudocode's 2. Implemented against the real signature (`_cooldown_max` unused, per AC-49's "no local prediction").

---

## Dependencies

- Depends on: Story 001 (HUD Scaffold & Local State Model), Story 002 (Phase-Gated Cluster Lifecycle), Story 008 (InputModeTracker instance)
- Unlocks: None further within this epic
