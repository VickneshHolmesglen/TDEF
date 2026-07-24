# QA Evidence: Two-Panel Screen Presentation (AC-13, AC-14-focus)

**Story**: `production/epics/epic-03-core-economy/story-007-two-panel-screen-presentation.md`
**Date**: 2026-07-15
**Engine**: Godot 4.6.2.stable.official, driven live via the Godot MCP bridge (`run_project` on `src/gameplay/ui/inventory_screen/InventoryScreen.tscn`, `run_script`, `simulate_input`, `take_screenshot`)
**Status**: Primary evidence for this story — Type: UI, no automated test required per this story's own Test Evidence section.

---

## What was verified

- **AC-13**: the left inventory grid and right-hand panel are simultaneously visible with no extra navigation.
- **AC-14-focus** (new, ADR-0011): a slot's focus ring appears when keyboard/gamepad-mode input moves focus to it, independent of mouse position; the ring hides when mouse-mode input is subsequently detected, even though keyboard/gamepad focus has not moved; mouse hover is a fully separate visual signal from the focus ring.

## Method

1. Launched `InventoryScreen.tscn` standalone via the Godot MCP bridge (background mode) — the scene's own fallback `Inventory` instancing (per its `_ready()` logic) made this possible with no navigation/caller wiring.
2. **First run surfaced a real bug**, not present in the final evidence below: `_create_slot_button()` connected the same `_on_input_mode_changed` method to the shared `InputModeTracker.input_mode_changed` signal once per slot (10×). Godot's `Signal.connect()` deduplicates by `(target object, method)`, ignoring differing `.bind()` arguments — only Slot0's connection succeeded; Slots 1-9 threw "already connected" errors and never connected, confirmed via `get_debug_output`. This would have broken AC-14-focus's core scenario for 9 of 10 slots. Sent back to the implementing agent; fixed by moving to a single `_ready()`-time connection that fans out to all slots internally. Re-verified clean (0 runtime errors) after the fix — the results below are from the fixed version.
3. Also applied `TD-workflow-001`'s documented one-time fix (`godot --headless --editor --quit` rescan) before the first run — the fresh `InputModeTracker` `class_name` wasn't picked up by a bare headless boot otherwise. Environment quirk, not a code defect.
4. Took a screenshot immediately after scene load (AC-13).
5. Ran a precise, scripted verification sequence for AC-14-focus using `run_script` to read exact `has_focus()`/`FocusRing.visible`/`HoverHighlight.visible`/`InputModeTracker._current_mode` state at each step (not just visual inspection):
   - `click_element` on Slot0 (a real mouse click).
   - `key` press "Right" (a real `InputEventKey`).
   - `mouse_motion` to a position over Slot9, with no click.

## Results

### AC-13 — simultaneous two-panel visibility

| Check | Result |
|---|---|
| Screenshot immediately after scene load | Both the left grid (tab-strip placeholder + 10 slot buttons) and the right panel (Crafting placeholder label) visible in the same frame |
| Navigation required to reveal either panel | None — both are permanent `MainLayout` siblings |

**Verdict: PASS.**

### AC-14-focus — input-mode-aware focus ring, independent of hover

| Step | Input | Mode after | Slot0 | Slot1 | Slot9 |
|---|---|---|---|---|---|
| 1 | Click Slot0 (mouse) | MOUSE | `has_focus=true, ring=false` | — | — |
| 2 | Key press "Right" | KEYBOARD_GAMEPAD | `has_focus=false` | `has_focus=true, ring=true` | — |
| 3 | Mouse motion over Slot9 (no click) | MOUSE | — | `has_focus=true, ring=false` | `hover=true, has_focus=false, ring=false` |

| Check | Result |
|---|---|
| Mouse click sets focus but ring stays hidden (mode=MOUSE) | PASS (step 1) |
| Keyboard input moves focus via explicit `focus_neighbor_right` wiring and ring appears on the newly-focused slot | PASS (step 2) — confirms `focus_neighbor_*` explicit wiring, not automatic traversal |
| Mouse motion elsewhere switches mode to MOUSE and hides the ring, **with focus unchanged** (Slot1 still `has_focus=true` in step 3) | PASS — this is the exact scenario the connection bug (see Method, item 2) would have broken for any slot but Slot0; confirmed fixed on a non-Slot0 slot |
| Hover and focus are independent, simultaneously-trackable states (Slot9: hover=true, focus=false, ring=false; Slot1: hover=false, focus=true, ring=false, at the same instant) | PASS |
| Runtime errors during the full sequence (post-fix run) | 0 |

**Verdict: PASS** for the mechanism and scenario as specified.

## Notes / Known Limitation

- Keyboard input (`InputEventKey`) was used to drive the `KEYBOARD_GAMEPAD` mode branch, not a literal `InputEventJoypadButton` — the Godot MCP bridge's `simulate_input` tool has no gamepad-button input type, and no physical gamepad is attached to this environment. Both event types are handled by the identical code branch in `InputModeTracker._input()` (`InputEventKey or InputEventJoypadButton or InputEventJoypadMotion` all map to the same `KEYBOARD_GAMEPAD` detection), so this test exercises the same logic path a gamepad press would. However, ADR-0011's own **Verification Required** item #1 ("confirm `focus_entered` still fires correctly when focus moves via a gamepad `ui_down`/etc. action under 4.6's dual-focus model — signal-firing order is not documented at this level of detail") is specifically about gamepad-originated events and remains **not fully closed** by this evidence — it requires actual gamepad hardware or a more capable input-simulation tool than what's available here. Flagging honestly rather than overclaiming; risk is assessed as low given the shared code path, but this is the one item this evidence doc cannot close.
- Tab-strip labels render as raw localization keys (e.g. `INVENTORY_TAB_EQUIPMENT`) since no translation catalogue exists yet — expected and out of scope for this story (a placeholder, non-functional strip per the story's own Out of Scope section).
- Focus ring color is a placeholder (`Color(1.0, 0.85, 0.2, 1.0)`), explicitly marked TBD pending art-director input in the code's own doc comment.
